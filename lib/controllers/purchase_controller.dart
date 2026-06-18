import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class PurchaseController extends Controller {
  Future<Response> suppliers() async {
    final query = req.queryParam('q')?.trim();
    final where = ['company_id = ?', 'deleted_at IS NULL'];
    final params = <dynamic>[_authContext['company_id']];

    if (query != null && query.isNotEmpty) {
      where.add('(name LIKE ? OR contact_person LIKE ? OR phone LIKE ? OR email LIKE ?)');
      final like = '%$query%';
      params.addAll([like, like, like, like]);
    }

    final rows = await DB.query(
      '''
      SELECT *
      FROM suppliers
      WHERE ${where.join(' AND ')}
      ORDER BY name
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Suppliers retrieved successfully',
    ));
  }

  Future<Response> createSupplier() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({'name': 'required|string'});
    } on ValidationException catch (e) {
      return _validationFailed(e);
    }

    await DB.query(
      '''
      INSERT INTO suppliers
        (id, company_id, name, contact_person, phone, email, address, status,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        body['name'],
        body['contact_person'],
        body['phone'],
        body['email'],
        body['address'],
        body['status'] ?? 'active',
      ],
    );

    final supplier = await _first(
      '''
      SELECT *
      FROM suppliers
      WHERE company_id = ? AND name = ? AND deleted_at IS NULL
      ORDER BY id DESC
      LIMIT 1
      ''',
      [_authContext['company_id'], body['name']],
    );

    return res.status(201).json(ApiResponse.success(
      data: supplier,
      message: 'Supplier created successfully',
    ));
  }

  Future<Response> updateSupplier() async {
    final supplierId = req.params['id'];
    final supplier = await _findSupplier(supplierId);
    if (supplier == null) return _supplierNotFound();

    final body = await req.json();
    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return _invalid('status must be active or inactive.');
    }

    const allowedFields = {
      'name',
      'contact_person',
      'phone',
      'email',
      'address',
      'status',
    };
    final updates = _allowedUpdates(body, allowedFields);
    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE suppliers
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          supplierId,
          _authContext['company_id'],
        ],
      );
    }

    return res.json(ApiResponse.success(
      data: await _findSupplier(supplierId),
      message: 'Supplier updated successfully',
    ));
  }

  Future<Response> purchaseOrders() async {
    final storeId = _storeFilter();
    final status = req.queryParam('status');
    final supplierId = req.queryParam('supplier_id');

    final where = ['purchase_orders.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];

    if (storeId != null) {
      where.add('purchase_orders.store_id = ?');
      params.add(storeId);
    }
    if (status != null && status.isNotEmpty) {
      where.add('purchase_orders.status = ?');
      params.add(status);
    }
    if (supplierId != null && supplierId.isNotEmpty) {
      where.add('purchase_orders.supplier_id = ?');
      params.add(supplierId);
    }

    final rows = await DB.query(
      '''
      SELECT
        purchase_orders.*,
        suppliers.name AS supplier_name,
        stores.name AS store_name,
        users.email AS created_by_email
      FROM purchase_orders
      INNER JOIN suppliers ON suppliers.id = purchase_orders.supplier_id
      INNER JOIN stores ON stores.id = purchase_orders.store_id
      LEFT JOIN users ON users.id = purchase_orders.created_by
      WHERE ${where.join(' AND ')}
      ORDER BY purchase_orders.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Purchase orders retrieved successfully',
    ));
  }

  Future<Response> createPurchaseOrder() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'supplier_id': 'required',
        'items': 'required',
      });
    } on ValidationException catch (e) {
      return _validationFailed(e);
    }

    final supplier = await _findSupplier(body['supplier_id']);
    if (supplier == null) return _invalid('supplier_id is invalid.');

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    final items = body['items'];
    if (items is! List || items.isEmpty) {
      return _invalid('items must be a non-empty array.');
    }

    final builtItems = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) return _invalid('Each purchase item must be an object.');
      final built = await _buildPurchaseItem(item);
      if (built is Response) return built;
      builtItems.add(built as Map<String, dynamic>);
    }

    final totals = _calculateTotals(builtItems);
    final poNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';

    await DB.query(
      '''
      INSERT INTO purchase_orders
        (id, company_id, store_id, supplier_id, po_number, status, subtotal,
         tax_total, discount_total, grand_total, expected_delivery_date,
         created_by, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        body['supplier_id'],
        poNumber,
        body['status'] ?? 'draft',
        totals['subtotal'],
        totals['tax_total'],
        totals['discount_total'],
        totals['grand_total'],
        body['expected_delivery_date'],
        (_authContext['user'] as Map)['id'],
      ],
    );

    final order = await _first(
      '''
      SELECT * FROM purchase_orders
      WHERE company_id = ? AND po_number = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], poNumber],
    );

    for (final item in builtItems) {
      await DB.query(
        '''
        INSERT INTO purchase_items
          (id, company_id, purchase_order_id, product_id, product_variant_id,
           quantity_ordered, quantity_received, unit_cost, line_total,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          _authContext['company_id'],
          order!['id'],
          item['product_id'],
          item['product_variant_id'],
          item['quantity_ordered'],
          0,
          item['unit_cost'],
          item['line_total'],
        ],
      );
    }

    return res.status(201).json(ApiResponse.success(
      data: await _findPurchaseOrder(order!['id']),
      message: 'Purchase order created successfully',
    ));
  }

  Future<Response> showPurchaseOrder() async {
    final order = await _findPurchaseOrder(req.params['id']);
    if (order == null) return _purchaseOrderNotFound();

    return res.json(ApiResponse.success(
      data: order,
      message: 'Purchase order retrieved successfully',
    ));
  }

  Future<Response> updatePurchaseOrder() async {
    final orderId = req.params['id'];
    final order = await _findPurchaseOrder(orderId);
    if (order == null) return _purchaseOrderNotFound();
    if ({'received', 'cancelled'}.contains(order['status'])) {
      return _invalid('Received or cancelled purchase orders cannot be updated.');
    }

    final body = await req.json();
    if (body['supplier_id'] != null && await _findSupplier(body['supplier_id']) == null) {
      return _invalid('supplier_id is invalid.');
    }
    if (body['store_id'] != null && await _findStore(body['store_id']) == null) {
      return _invalid('store_id is invalid.');
    }

    const allowedFields = {
      'store_id',
      'supplier_id',
      'status',
      'expected_delivery_date',
    };
    final updates = _allowedUpdates(body, allowedFields);
    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE purchase_orders
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          orderId,
          _authContext['company_id'],
        ],
      );
    }

    return res.json(ApiResponse.success(
      data: await _findPurchaseOrder(orderId),
      message: 'Purchase order updated successfully',
    ));
  }

  Future<Response> receivePurchaseOrder() async {
    final orderId = req.params['id'];
    final order = await _findPurchaseOrder(orderId);
    if (order == null) return _purchaseOrderNotFound();
    if (order['status'] == 'received' || order['status'] == 'cancelled') {
      return _invalid('This purchase order cannot be received.');
    }

    final items = (order['items'] as List).cast<Map<String, dynamic>>();
    var allReceived = true;

    for (final item in items) {
      final remaining = _asDouble(item['quantity_ordered']) -
          _asDouble(item['quantity_received']);
      if (remaining <= 0) continue;

      final inventory = await _ensureInventoryRow(
        storeId: order['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        reorderLevel: 0,
        averageCost: item['unit_cost'],
      );
      final before = _asDouble(inventory['quantity_on_hand']);
      final reserved = _asDouble(inventory['quantity_reserved']);
      final after = before + remaining;
      final averageCost = _nextAverageCost(
        oldQuantity: before,
        oldAverageCost: _asDouble(inventory['average_cost']),
        addedQuantity: remaining,
        addedUnitCost: _asDouble(item['unit_cost']),
      );

      await _updateInventoryQuantities(
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityReserved: reserved,
        averageCost: averageCost,
        reorderLevel: _asDouble(inventory['reorder_level']),
      );
      await DB.query(
        '''
        UPDATE purchase_items
        SET quantity_received = quantity_ordered,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [item['id'], _authContext['company_id']],
      );
      await _recordInventoryTransaction(
        storeId: order['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        quantity: remaining,
        unitCost: _asDouble(item['unit_cost']),
        before: before,
        after: after,
        purchaseOrderId: orderId,
      );
    }

    final refreshedItems = await _purchaseItems(orderId);
    for (final item in refreshedItems) {
      if (_asDouble(item['quantity_received']) < _asDouble(item['quantity_ordered'])) {
        allReceived = false;
      }
    }

    await DB.query(
      '''
      UPDATE purchase_orders
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        allReceived ? 'received' : 'partially_received',
        orderId,
        _authContext['company_id'],
      ],
    );

    return res.json(ApiResponse.success(
      data: await _findPurchaseOrder(orderId),
      message: 'Purchase order received successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Object? _storeFilter() {
    if (_authContext['role_scope'] == 'store') return _authContext['store_id'];
    final storeId = req.queryParam('store_id');
    return storeId == null || storeId.isEmpty ? null : storeId;
  }

  Future<Object> _resolveStoreId(Object? requestedStoreId) async {
    final storeId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : requestedStoreId;
    if (storeId == null) return _invalid('store_id is required.');
    final store = await _findStore(storeId);
    if (store == null) return _invalid('store_id is invalid.');
    return storeId;
  }

  Future<Object> _buildPurchaseItem(Map item) async {
    if (item['product_id'] == null) return _invalid('product_id is required.');
    final product = await _findProduct(item['product_id']);
    if (product == null) return _invalid('product_id is invalid.');

    if (item['product_variant_id'] != null) {
      final variant = await _findVariant(item['product_variant_id'], item['product_id']);
      if (variant == null) return _invalid('product_variant_id is invalid.');
    }

    final quantity = _asDouble(item['quantity_ordered'] ?? item['quantity']);
    if (quantity <= 0) return _invalid('quantity_ordered must be greater than zero.');

    final unitCost = _asDouble(item['unit_cost'] ?? product['cost_price']);
    return {
      'product_id': item['product_id'],
      'product_variant_id': item['product_variant_id'],
      'quantity_ordered': quantity,
      'unit_cost': unitCost,
      'line_total': quantity * unitCost,
    };
  }

  Map<String, double> _calculateTotals(List<Map<String, dynamic>> items) {
    var subtotal = 0.0;
    for (final item in items) {
      subtotal += _asDouble(item['line_total']);
    }
    return {
      'subtotal': subtotal,
      'tax_total': 0,
      'discount_total': 0,
      'grand_total': subtotal,
    };
  }

  Map<String, dynamic> _allowedUpdates(
    Map<String, dynamic> body,
    Set<String> allowedFields,
  ) {
    final updates = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) updates[entry.key] = entry.value;
    }
    return updates;
  }

  Future<Map<String, dynamic>?> _findSupplier(Object? id) {
    return _first(
      '''
      SELECT *
      FROM suppliers
      WHERE id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findStore(Object? id) {
    return _first(
      '''
      SELECT id FROM stores
      WHERE id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findProduct(Object? id) {
    return _first(
      '''
      SELECT * FROM products
      WHERE id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findVariant(Object? id, Object? productId) {
    return _first(
      '''
      SELECT * FROM product_variants
      WHERE id = ? AND product_id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, productId, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findPurchaseOrder(Object? id) async {
    final where = ['purchase_orders.id = ?', 'purchase_orders.company_id = ?'];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('purchase_orders.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final order = await _first(
      '''
      SELECT
        purchase_orders.*,
        suppliers.name AS supplier_name,
        stores.name AS store_name,
        users.email AS created_by_email
      FROM purchase_orders
      INNER JOIN suppliers ON suppliers.id = purchase_orders.supplier_id
      INNER JOIN stores ON stores.id = purchase_orders.store_id
      LEFT JOIN users ON users.id = purchase_orders.created_by
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      params,
    );
    if (order == null) return null;
    return {
      ...order,
      'items': await _purchaseItems(id),
    };
  }

  Future<List<Map<String, dynamic>>> _purchaseItems(Object? orderId) {
    return DB.query(
      '''
      SELECT
        purchase_items.*,
        products.name AS product_name,
        products.sku AS product_sku,
        product_variants.variant_name,
        product_variants.sku AS variant_sku
      FROM purchase_items
      INNER JOIN products ON products.id = purchase_items.product_id
      LEFT JOIN product_variants ON product_variants.id = purchase_items.product_variant_id
      WHERE purchase_items.company_id = ?
        AND purchase_items.purchase_order_id = ?
      ORDER BY products.name, product_variants.variant_name
      ''',
      positionalParams: [_authContext['company_id'], orderId],
    );
  }

  Future<Map<String, dynamic>> _ensureInventoryRow({
    required Object storeId,
    required Object productId,
    required Object? variantId,
    required Object reorderLevel,
    required Object averageCost,
  }) async {
    final existing = await _findInventoryByProduct(
      storeId: storeId,
      productId: productId,
      variantId: variantId,
    );
    if (existing != null) return existing;

    await DB.query(
      '''
      INSERT INTO inventory
        (id, company_id, store_id, product_id, product_variant_id, quantity_on_hand,
         quantity_reserved, quantity_available, average_cost, reorder_level,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        productId,
        variantId,
        0,
        0,
        0,
        averageCost,
        reorderLevel,
      ],
    );

    return (await _findInventoryByProduct(
      storeId: storeId,
      productId: productId,
      variantId: variantId,
    ))!;
  }

  Future<Map<String, dynamic>?> _findInventoryByProduct({
    required Object storeId,
    required Object productId,
    required Object? variantId,
  }) {
    return _first(
      '''
      SELECT * FROM inventory
      WHERE company_id = ?
        AND store_id = ?
        AND product_id = ?
        AND ${variantId == null ? 'product_variant_id IS NULL' : 'product_variant_id = ?'}
      LIMIT 1
      ''',
      [
        _authContext['company_id'],
        storeId,
        productId,
        if (variantId != null) variantId,
      ],
    );
  }

  Future<void> _updateInventoryQuantities({
    required Object inventoryId,
    required double quantityOnHand,
    required double quantityReserved,
    required double averageCost,
    required double reorderLevel,
  }) {
    return DB.query(
      '''
      UPDATE inventory
      SET quantity_on_hand = ?, quantity_reserved = ?, quantity_available = ?,
          average_cost = ?, reorder_level = ?, last_movement_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        quantityOnHand,
        quantityReserved,
        quantityOnHand - quantityReserved,
        averageCost,
        reorderLevel,
        inventoryId,
        _authContext['company_id'],
      ],
    );
  }

  Future<void> _recordInventoryTransaction({
    required Object storeId,
    required Object productId,
    required Object? variantId,
    required double quantity,
    required double unitCost,
    required double before,
    required double after,
    required Object? purchaseOrderId,
  }) {
    return DB.query(
      '''
      INSERT INTO inventory_transactions
        (id, company_id, store_id, product_id, product_variant_id, type, quantity,
         unit_cost, quantity_before, quantity_after, reference_type,
         reference_id, reason, created_by, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        productId,
        variantId,
        'purchase_receive',
        quantity,
        unitCost,
        before,
        after,
        'purchase_order',
        purchaseOrderId,
        'Purchase order receiving',
        (_authContext['user'] as Map)['id'],
      ],
    );
  }

  Future<Map<String, dynamic>?> _first(String sql, List<dynamic> params) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _nextAverageCost({
    required double oldQuantity,
    required double oldAverageCost,
    required double addedQuantity,
    required double addedUnitCost,
  }) {
    final newQuantity = oldQuantity + addedQuantity;
    if (newQuantity <= 0) return addedUnitCost;
    return ((oldQuantity * oldAverageCost) + (addedQuantity * addedUnitCost)) /
        newQuantity;
  }

  Future<Response> _validationFailed(ValidationException e) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Validation failed',
          details: e.errors,
        ));
  }

  Future<Response> _invalid(String message) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: message,
        ));
  }

  Future<Response> _supplierNotFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Supplier not found.',
        ));
  }

  Future<Response> _purchaseOrderNotFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Purchase order not found.',
        ));
  }
}
