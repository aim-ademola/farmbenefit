import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/sales_realtime_service.dart';

class InventoryController extends Controller {
  Future<Response> index() async {
    final storeId = _storeFilter();
    final productId = req.queryParam('product_id');
    final lowStock = req.queryParam('low_stock') == 'true';

    final where = [
      'inventory.company_id = ?',
    ];
    final params = <dynamic>[_authContext['company_id']];

    if (storeId != null) {
      where.add('inventory.store_id = ?');
      params.add(storeId);
    }
    if (productId != null && productId.isNotEmpty) {
      where.add('inventory.product_id = ?');
      params.add(productId);
    }
    if (lowStock) {
      where.add('inventory.quantity_available <= inventory.reorder_level');
    }

    final rows = await DB.query(
      '''
      SELECT
        inventory.*,
        stores.name AS store_name,
        products.name AS product_name,
        products.sku AS product_sku,
        product_variants.variant_name,
        product_variants.sku AS variant_sku
      FROM inventory
      INNER JOIN stores ON stores.id = inventory.store_id
      INNER JOIN products ON products.id = inventory.product_id
      LEFT JOIN product_variants ON product_variants.id = inventory.product_variant_id
      WHERE ${where.join(' AND ')}
      ORDER BY stores.name, products.name, product_variants.variant_name
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows.map(_presentInventoryRow).toList(),
      message: 'Inventory retrieved successfully',
    ));
  }

  Future<Response> show() async {
    final inventory = await _findInventory(req.params['id']);
    if (inventory == null) {
      return _notFound('Inventory row not found.');
    }

    return res.json(ApiResponse.success(
      data: _presentInventoryRow(inventory),
      message: 'Inventory row retrieved successfully',
    ));
  }

  Future<Response> stockIn() async {
    final body = await _validateMovementBody({
      'product_id': 'required',
      'quantity': 'required',
      'store_id': '',
      'product_variant_id': '',
      'unit_cost': '',
      'reorder_level': '',
      'reason': '',
    });
    if (body is Response) return body;

    final payload = body as Map<String, dynamic>;
    final storeId = await _resolveStoreId(payload['store_id']);
    if (storeId is Response) return storeId;

    final quantity = _asDouble(payload['quantity']);
    if (quantity <= 0) return _invalid('quantity must be greater than zero.');

    final product = await _findProduct(payload['product_id']);
    if (product == null) return _invalid('product_id is invalid.');

    if (payload['product_variant_id'] != null) {
      final variant = await _findVariant(
        payload['product_variant_id'],
        payload['product_id'],
      );
      if (variant == null) return _invalid('product_variant_id is invalid.');
    }

    final inventory = await _ensureInventoryRow(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      reorderLevel: payload['reorder_level'] ?? product['reorder_level'] ?? 0,
      averageCost: payload['unit_cost'] ?? product['cost_price'] ?? 0,
    );

    final before = _asDouble(inventory['quantity_on_hand']);
    final after = before + quantity;
    final reserved = _asDouble(inventory['quantity_reserved']);
    final averageCost = _nextAverageCost(
      oldQuantity: before,
      oldAverageCost: _asDouble(inventory['average_cost']),
      addedQuantity: quantity,
      addedUnitCost: _asDouble(payload['unit_cost'] ?? product['cost_price']),
    );

    await _updateInventoryQuantities(
      inventoryId: inventory['id'],
      quantityOnHand: after,
      quantityReserved: reserved,
      averageCost: averageCost,
      reorderLevel:
          _asDouble(payload['reorder_level'] ?? inventory['reorder_level']),
    );
    _emitInventoryChanged(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      inventoryId: inventory['id'],
      quantityOnHand: after,
      quantityAvailable: after - reserved,
      reason: 'stock_in',
    );

    await _recordTransaction(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      type: 'stock_in',
      quantity: quantity,
      unitCost: _asDouble(payload['unit_cost'] ?? product['cost_price']),
      before: before,
      after: after,
      reason: payload['reason'],
    );

    return res.json(ApiResponse.success(
      data: _presentInventoryRow((await _findInventory(inventory['id']))!),
      message: 'Stock added successfully',
    ));
  }

  Future<Response> stockOut() async {
    final body = await _validateMovementBody({
      'product_id': 'required',
      'quantity': 'required',
      'reason': 'required|string',
      'store_id': '',
      'product_variant_id': '',
    });
    if (body is Response) return body;

    final payload = body as Map<String, dynamic>;
    final storeId = await _resolveStoreId(payload['store_id']);
    if (storeId is Response) return storeId;

    final quantity = _asDouble(payload['quantity']);
    if (quantity <= 0) return _invalid('quantity must be greater than zero.');

    final inventory = await _findInventoryByProduct(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
    );
    if (inventory == null)
      return _invalid('No inventory row exists for this item.');

    final before = _asDouble(inventory['quantity_on_hand']);
    final reserved = _asDouble(inventory['quantity_reserved']);
    final available = before - reserved;
    if (quantity > available) {
      return res.status(409).json(ApiResponse.error(
            code: 'INSUFFICIENT_STOCK',
            message: 'Insufficient available stock.',
            details: {'available': _wholeNumber(available)},
          ));
    }

    final after = before - quantity;
    await _updateInventoryQuantities(
      inventoryId: inventory['id'],
      quantityOnHand: after,
      quantityReserved: reserved,
      averageCost: _asDouble(inventory['average_cost']),
      reorderLevel: _asDouble(inventory['reorder_level']),
    );
    _emitInventoryChanged(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      inventoryId: inventory['id'],
      quantityOnHand: after,
      quantityAvailable: after - reserved,
      reason: 'stock_out',
    );

    await _recordTransaction(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      type: 'stock_out',
      quantity: -quantity,
      unitCost: _asDouble(inventory['average_cost']),
      before: before,
      after: after,
      reason: payload['reason'],
    );

    return res.json(ApiResponse.success(
      data: _presentInventoryRow((await _findInventory(inventory['id']))!),
      message: 'Stock removed successfully',
    ));
  }

  Future<Response> adjustment() async {
    final body = await _validateMovementBody({
      'product_id': 'required',
      'quantity': 'required',
      'reason': 'required|string',
      'store_id': '',
      'product_variant_id': '',
      'unit_cost': '',
      'reorder_level': '',
    });
    if (body is Response) return body;

    final payload = body as Map<String, dynamic>;
    final storeId = await _resolveStoreId(payload['store_id']);
    if (storeId is Response) return storeId;

    final product = await _findProduct(payload['product_id']);
    if (product == null) return _invalid('product_id is invalid.');

    final newQuantity = _asDouble(payload['quantity']);
    if (newQuantity < 0) return _invalid('quantity cannot be negative.');

    final inventory = await _ensureInventoryRow(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      reorderLevel: payload['reorder_level'] ?? product['reorder_level'] ?? 0,
      averageCost: payload['unit_cost'] ?? product['cost_price'] ?? 0,
    );

    final before = _asDouble(inventory['quantity_on_hand']);
    final reserved = _asDouble(inventory['quantity_reserved']);
    if (newQuantity < reserved) {
      return _invalid('quantity cannot be lower than reserved quantity.');
    }

    await _updateInventoryQuantities(
      inventoryId: inventory['id'],
      quantityOnHand: newQuantity,
      quantityReserved: reserved,
      averageCost: _asDouble(payload['unit_cost'] ?? inventory['average_cost']),
      reorderLevel:
          _asDouble(payload['reorder_level'] ?? inventory['reorder_level']),
    );
    _emitInventoryChanged(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      inventoryId: inventory['id'],
      quantityOnHand: newQuantity,
      quantityAvailable: newQuantity - reserved,
      reason: 'adjustment',
    );

    await _recordTransaction(
      storeId: storeId,
      productId: payload['product_id'],
      variantId: payload['product_variant_id'],
      type: 'adjustment',
      quantity: newQuantity - before,
      unitCost: _asDouble(payload['unit_cost'] ?? inventory['average_cost']),
      before: before,
      after: newQuantity,
      reason: payload['reason'],
    );

    return res.json(ApiResponse.success(
      data: _presentInventoryRow((await _findInventory(inventory['id']))!),
      message: 'Inventory adjusted successfully',
    ));
  }

  Future<Response> transfers() async {
    final storeId = _storeFilter();
    final status = req.queryParam('status');

    final where = ['stock_transfers.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];

    if (storeId != null) {
      where.add(
        '(stock_transfers.source_store_id = ? OR stock_transfers.destination_store_id = ?)',
      );
      params.addAll([storeId, storeId]);
    }
    if (status != null && status.isNotEmpty) {
      where.add('stock_transfers.status = ?');
      params.add(status);
    }

    final rows = await DB.query(
      '''
      SELECT
        stock_transfers.*,
        source_stores.name AS source_store_name,
        destination_stores.name AS destination_store_name,
        creator.email AS created_by_email,
        approver.email AS approved_by_email,
        receiver.email AS received_by_email
      FROM stock_transfers
      INNER JOIN stores AS source_stores ON source_stores.id = stock_transfers.source_store_id
      INNER JOIN stores AS destination_stores ON destination_stores.id = stock_transfers.destination_store_id
      LEFT JOIN users AS creator ON creator.id = stock_transfers.created_by
      LEFT JOIN users AS approver ON approver.id = stock_transfers.approved_by
      LEFT JOIN users AS receiver ON receiver.id = stock_transfers.received_by
      WHERE ${where.join(' AND ')}
      ORDER BY stock_transfers.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Stock transfers retrieved successfully',
    ));
  }

  Future<Response> createTransfer() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'source_store_id': 'required',
        'destination_store_id': 'required',
        'items': 'required',
      });
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }

    final items = body['items'];
    if (items is! List || items.isEmpty) {
      return _invalid('items must be a non-empty array.');
    }

    final sourceStoreId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : body['source_store_id'];
    final destinationStoreId = body['destination_store_id'];
    if (sourceStoreId == destinationStoreId) {
      return _invalid('source_store_id and destination_store_id must differ.');
    }
    if (await _findStore(sourceStoreId) == null) {
      return _invalid('source_store_id is invalid.');
    }
    if (await _findStore(destinationStoreId) == null) {
      return _invalid('destination_store_id is invalid.');
    }

    for (final item in items) {
      if (item is! Map)
        return _invalid('Each transfer item must be an object.');
      if (item['product_id'] == null)
        return _invalid('product_id is required.');
      final quantity = _asDouble(item['quantity']);
      if (quantity <= 0)
        return _invalid('item quantity must be greater than zero.');
      final product = await _findProduct(item['product_id']);
      if (product == null) return _invalid('product_id is invalid.');
      if (item['product_variant_id'] != null) {
        final variant = await _findVariant(
          item['product_variant_id'],
          item['product_id'],
        );
        if (variant == null) return _invalid('product_variant_id is invalid.');
      }
    }

    final transferNumber = 'TRF-${DateTime.now().millisecondsSinceEpoch}';
    await DB.query(
      '''
      INSERT INTO stock_transfers
        (id, company_id, source_store_id, destination_store_id, transfer_number,
         status, reason, created_by, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        sourceStoreId,
        destinationStoreId,
        transferNumber,
        'pending',
        body['reason'],
        (_authContext['user'] as Map)['id'],
      ],
    );

    final transfer = await _first(
      '''
      SELECT * FROM stock_transfers
      WHERE company_id = ? AND transfer_number = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], transferNumber],
    );

    for (final item in items.cast<Map>()) {
      final product = await _findProduct(item['product_id']);
      await DB.query(
        '''
        INSERT INTO stock_transfer_items
          (id, company_id, stock_transfer_id, product_id, product_variant_id,
           quantity_requested, quantity_approved, quantity_received, unit_cost,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          _authContext['company_id'],
          transfer!['id'],
          item['product_id'],
          item['product_variant_id'],
          _asDouble(item['quantity']),
          0,
          0,
          _asDouble(item['unit_cost'] ?? product?['cost_price']),
        ],
      );
    }

    return res.status(201).json(ApiResponse.success(
          data: await _findTransfer(transfer!['id']),
          message: 'Stock transfer created successfully',
        ));
  }

  Future<Response> approveTransfer() async {
    final transferId = req.params['id'];
    final transfer = await _findTransfer(transferId);
    if (transfer == null) return _notFound('Stock transfer not found.');
    if (transfer['status'] != 'pending') {
      return _invalid('Only pending transfers can be approved.');
    }
    if (_authContext['role_scope'] == 'store' &&
        transfer['source_store_id'].toString() !=
            _authContext['store_id'].toString()) {
      return res.status(403).json(ApiResponse.error(
            code: 'FORBIDDEN',
            message: 'Store users can approve only transfers from their store.',
          ));
    }

    final items = await _transferItems(transferId);
    for (final item in items) {
      final inventory = await _findInventoryByProduct(
        storeId: transfer['source_store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
      );
      if (inventory == null) {
        return _invalid(
            'Source inventory row is missing for one or more items.');
      }
      final available = _asDouble(inventory['quantity_available']);
      final quantity = _asDouble(item['quantity_requested']);
      if (quantity > available) {
        return res.status(409).json(ApiResponse.error(
              code: 'INSUFFICIENT_STOCK',
              message: 'Insufficient source stock for transfer item.',
              details: {
                'product_id': item['product_id'],
                'product_variant_id': item['product_variant_id'],
                'available': available,
              },
            ));
      }
    }

    for (final item in items) {
      final inventory = (await _findInventoryByProduct(
        storeId: transfer['source_store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
      ))!;
      final quantity = _asDouble(item['quantity_requested']);
      final before = _asDouble(inventory['quantity_on_hand']);
      final reserved = _asDouble(inventory['quantity_reserved']);
      final after = before - quantity;

      await _updateInventoryQuantities(
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityReserved: reserved,
        averageCost: _asDouble(inventory['average_cost']),
        reorderLevel: _asDouble(inventory['reorder_level']),
      );
      await DB.query(
        '''
        UPDATE stock_transfer_items
        SET quantity_approved = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [quantity, item['id'], _authContext['company_id']],
      );
      await _recordTransaction(
        storeId: transfer['source_store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        type: 'transfer_out',
        quantity: -quantity,
        unitCost: _asDouble(inventory['average_cost']),
        before: before,
        after: after,
        referenceType: 'stock_transfer',
        referenceId: transferId,
        reason: transfer['reason'],
      );
    }

    await DB.query(
      '''
      UPDATE stock_transfers
      SET status = ?, approved_by = ?, approved_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'approved',
        (_authContext['user'] as Map)['id'],
        transferId,
        _authContext['company_id'],
      ],
    );

    return res.json(ApiResponse.success(
      data: await _findTransfer(transferId),
      message: 'Stock transfer approved successfully',
    ));
  }

  Future<Response> receiveTransfer() async {
    final transferId = req.params['id'];
    final transfer = await _findTransfer(transferId);
    if (transfer == null) return _notFound('Stock transfer not found.');
    if (transfer['status'] != 'approved') {
      return _invalid('Only approved transfers can be received.');
    }
    if (_authContext['role_scope'] == 'store' &&
        transfer['destination_store_id'].toString() !=
            _authContext['store_id'].toString()) {
      return res.status(403).json(ApiResponse.error(
            code: 'FORBIDDEN',
            message: 'Store users can receive only transfers to their store.',
          ));
    }

    final items = await _transferItems(transferId);
    for (final item in items) {
      final product = await _findProduct(item['product_id']);
      final inventory = await _ensureInventoryRow(
        storeId: transfer['destination_store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        reorderLevel: product?['reorder_level'] ?? 0,
        averageCost: item['unit_cost'],
      );
      final quantity = _asDouble(item['quantity_approved']);
      final before = _asDouble(inventory['quantity_on_hand']);
      final reserved = _asDouble(inventory['quantity_reserved']);
      final after = before + quantity;

      await _updateInventoryQuantities(
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityReserved: reserved,
        averageCost: _nextAverageCost(
          oldQuantity: before,
          oldAverageCost: _asDouble(inventory['average_cost']),
          addedQuantity: quantity,
          addedUnitCost: _asDouble(item['unit_cost']),
        ),
        reorderLevel: _asDouble(inventory['reorder_level']),
      );
      await DB.query(
        '''
        UPDATE stock_transfer_items
        SET quantity_received = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [quantity, item['id'], _authContext['company_id']],
      );
      await _recordTransaction(
        storeId: transfer['destination_store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        type: 'transfer_in',
        quantity: quantity,
        unitCost: _asDouble(item['unit_cost']),
        before: before,
        after: after,
        referenceType: 'stock_transfer',
        referenceId: transferId,
        reason: transfer['reason'],
      );
    }

    await DB.query(
      '''
      UPDATE stock_transfers
      SET status = ?, received_by = ?, received_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'received',
        (_authContext['user'] as Map)['id'],
        transferId,
        _authContext['company_id'],
      ],
    );

    return res.json(ApiResponse.success(
      data: await _findTransfer(transferId),
      message: 'Stock transfer received successfully',
    ));
  }

  Future<Response> transactions() async {
    final storeId = _storeFilter();
    final productId = req.queryParam('product_id');
    final type = req.queryParam('type');

    final where = ['inventory_transactions.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];
    if (storeId != null) {
      where.add('inventory_transactions.store_id = ?');
      params.add(storeId);
    }
    if (productId != null && productId.isNotEmpty) {
      where.add('inventory_transactions.product_id = ?');
      params.add(productId);
    }
    if (type != null && type.isNotEmpty) {
      where.add('inventory_transactions.type = ?');
      params.add(type);
    }

    final rows = await DB.query(
      '''
      SELECT
        inventory_transactions.*,
        stores.name AS store_name,
        products.name AS product_name,
        product_variants.variant_name,
        users.email AS created_by_email
      FROM inventory_transactions
      INNER JOIN stores ON stores.id = inventory_transactions.store_id
      INNER JOIN products ON products.id = inventory_transactions.product_id
      LEFT JOIN product_variants ON product_variants.id = inventory_transactions.product_variant_id
      LEFT JOIN users ON users.id = inventory_transactions.created_by
      WHERE ${where.join(' AND ')}
      ORDER BY inventory_transactions.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows.map(_presentTransactionRow).toList(),
      message: 'Inventory transactions retrieved successfully',
    ));
  }

  Future<Response> lowStock() async {
    req.raw.uri.queryParameters['low_stock'];
    final rows = await DB.query(
      '''
      SELECT
        inventory.*,
        stores.name AS store_name,
        products.name AS product_name,
        products.sku AS product_sku,
        product_variants.variant_name
      FROM inventory
      INNER JOIN stores ON stores.id = inventory.store_id
      INNER JOIN products ON products.id = inventory.product_id
      LEFT JOIN product_variants ON product_variants.id = inventory.product_variant_id
      WHERE inventory.company_id = ?
        AND inventory.quantity_available <= inventory.reorder_level
        ${_storeFilter() == null ? '' : 'AND inventory.store_id = ?'}
      ORDER BY inventory.quantity_available ASC
      ''',
      positionalParams: [
        _authContext['company_id'],
        if (_storeFilter() != null) _storeFilter(),
      ],
    );

    return res.json(ApiResponse.success(
      data: rows.map(_presentInventoryRow).toList(),
      message: 'Low-stock inventory retrieved successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Object? _storeFilter() {
    if (_authContext['role_scope'] == 'store') {
      return _authContext['store_id'];
    }
    final storeId = req.queryParam('store_id');
    return storeId == null || storeId.isEmpty ? null : storeId;
  }

  Future<Object> _resolveStoreId(Object? requestedStoreId) async {
    final auth = _authContext;
    final storeId =
        auth['role_scope'] == 'store' ? auth['store_id'] : requestedStoreId;

    if (storeId == null) {
      final store = await _first(
        '''
        SELECT id FROM stores
        WHERE company_id = ?
          AND deleted_at IS NULL
        ORDER BY created_at ASC
        LIMIT 1
        ''',
        [auth['company_id']],
      );
      if (store == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'store_id is required.',
            ));
      }
      return store['id'];
    }

    final store = await _first(
      '''
      SELECT id FROM stores
      WHERE id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [storeId, auth['company_id']],
    );
    if (store == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'store_id is invalid.',
          ));
    }

    return storeId;
  }

  Future<Object> _validateMovementBody(Map<String, String> rules) async {
    try {
      return await req.validate(rules);
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
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
      SET quantity_on_hand = ?,
          quantity_reserved = ?,
          quantity_available = ?,
          average_cost = ?,
          reorder_level = ?,
          last_movement_at = CURRENT_TIMESTAMP,
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

  Future<void> _recordTransaction({
    required Object storeId,
    required Object productId,
    required Object? variantId,
    required String type,
    required double quantity,
    required double unitCost,
    required double before,
    required double after,
    Object? reason,
    Object? referenceType,
    Object? referenceId,
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
        type,
        quantity,
        unitCost,
        before,
        after,
        referenceType,
        referenceId,
        reason,
        (_authContext['user'] as Map)['id'],
      ],
    );
  }

  Future<Map<String, dynamic>?> _findInventory(Object? id) {
    return _first(
      '''
      SELECT
        inventory.*,
        stores.name AS store_name,
        products.name AS product_name,
        products.sku AS product_sku,
        product_variants.variant_name,
        product_variants.sku AS variant_sku
      FROM inventory
      INNER JOIN stores ON stores.id = inventory.store_id
      INNER JOIN products ON products.id = inventory.product_id
      LEFT JOIN product_variants ON product_variants.id = inventory.product_variant_id
      WHERE inventory.id = ?
        AND inventory.company_id = ?
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
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

  Future<Map<String, dynamic>?> _findProduct(Object? id) {
    return _first(
      '''
      SELECT * FROM products
      WHERE id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findStore(Object? id) {
    return _first(
      '''
      SELECT id FROM stores
      WHERE id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findTransfer(Object? id) async {
    final transfer = await _first(
      '''
      SELECT
        stock_transfers.*,
        source_stores.name AS source_store_name,
        destination_stores.name AS destination_store_name
      FROM stock_transfers
      INNER JOIN stores AS source_stores ON source_stores.id = stock_transfers.source_store_id
      INNER JOIN stores AS destination_stores ON destination_stores.id = stock_transfers.destination_store_id
      WHERE stock_transfers.id = ?
        AND stock_transfers.company_id = ?
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
    if (transfer == null) return null;
    return {
      ...transfer,
      'items': await _transferItems(id),
    };
  }

  Future<List<Map<String, dynamic>>> _transferItems(Object? transferId) {
    return DB.query(
      '''
          SELECT
            stock_transfer_items.*,
            products.name AS product_name,
            products.sku AS product_sku,
            product_variants.variant_name,
            product_variants.sku AS variant_sku
          FROM stock_transfer_items
          INNER JOIN products ON products.id = stock_transfer_items.product_id
          LEFT JOIN product_variants ON product_variants.id = stock_transfer_items.product_variant_id
          WHERE stock_transfer_items.stock_transfer_id = ?
            AND stock_transfer_items.company_id = ?
          ORDER BY products.name, product_variants.variant_name
          ''',
      positionalParams: [transferId, _authContext['company_id']],
    ).then((rows) => rows.map(_presentTransferItemRow).toList());
  }

  Future<Map<String, dynamic>?> _findVariant(Object? id, Object? productId) {
    return _first(
      '''
      SELECT * FROM product_variants
      WHERE id = ?
        AND product_id = ?
        AND company_id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, productId, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _first(
    String sql,
    List<dynamic> params,
  ) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Map<String, dynamic> _presentInventoryRow(Map<String, dynamic> row) {
    return {
      ...row,
      'quantity_on_hand': _wholeNumber(row['quantity_on_hand']),
      'quantity_reserved': _wholeNumber(row['quantity_reserved']),
      'quantity_available': _wholeNumber(row['quantity_available']),
      'reorder_level': _wholeNumber(row['reorder_level']),
    };
  }

  Map<String, dynamic> _presentTransactionRow(Map<String, dynamic> row) {
    return {
      ...row,
      'quantity': _wholeNumber(row['quantity']),
      'quantity_before': _wholeNumber(row['quantity_before']),
      'quantity_after': _wholeNumber(row['quantity_after']),
    };
  }

  Map<String, dynamic> _presentTransferItemRow(Map<String, dynamic> row) {
    return {
      ...row,
      'quantity_requested': _wholeNumber(row['quantity_requested']),
      'quantity_approved': _wholeNumber(row['quantity_approved']),
      'quantity_received': _wholeNumber(row['quantity_received']),
    };
  }

  Object? _wholeNumber(Object? value) {
    if (value == null) return null;
    final parsed = num.tryParse(value.toString());
    if (parsed == null) return value;
    return parsed.truncateToDouble() == parsed ? parsed.toInt() : parsed;
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

  Future<Response> _invalid(String message) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: message,
        ));
  }

  Future<Response> _notFound(String message) {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: message,
        ));
  }

  void _emitInventoryChanged({
    required Object? storeId,
    required Object? productId,
    required Object? variantId,
    required Object? inventoryId,
    required double quantityOnHand,
    required double quantityAvailable,
    required String reason,
  }) {
    SalesRealtimeService.inventoryChanged(
      companyId: _authContext['company_id'],
      storeId: storeId,
      productId: productId,
      variantId: variantId,
      inventoryId: inventoryId,
      quantityOnHand: quantityOnHand,
      quantityAvailable: quantityAvailable,
      reason: reason,
    );
  }
}
