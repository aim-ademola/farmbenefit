import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/customer_contact_otp_service.dart';
import 'package:backend/services/sales_realtime_service.dart';

class SaleController extends Controller {
  final _otp = CustomerContactOtpService();

  Future<Response> index() async {
    final storeId = _storeFilter();
    final status = req.queryParam('status');
    final customerId = req.queryParam('customer_id');

    final where = ['sales.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];

    if (storeId != null) {
      where.add('sales.store_id = ?');
      params.add(storeId);
    }
    if (status != null && status.isNotEmpty) {
      where.add('sales.status = ?');
      params.add(status);
    }
    if (customerId != null && customerId.isNotEmpty) {
      where.add('sales.customer_id = ?');
      params.add(customerId);
    }

    final rows = await DB.query(
      '''
      SELECT
        sales.*,
        stores.name AS store_name,
        customers.name AS customer_name,
        users.email AS sold_by_email
      FROM sales
      INNER JOIN stores ON stores.id = sales.store_id
      LEFT JOIN customers ON customers.id = sales.customer_id
      LEFT JOIN users ON users.id = sales.sold_by
      WHERE ${where.join(' AND ')}
      ORDER BY sales.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Sales retrieved successfully',
    ));
  }

  Future<Response> create() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'type': 'required|string',
        'items': 'required',
      });
    } on ValidationException catch (e) {
      return _validationFailed(e);
    }

    final sale = await _createSaleFromItems(body);
    if (sale is Response) return sale;
    _emitSaleChanged('created', sale);

    return res.status(201).json(ApiResponse.success(
          data: sale,
          message: 'Sale created successfully',
        ));
  }

  Future<Object> _createSaleFromItems(Map<String, dynamic> body) async {
    final type = body['type'].toString();
    if (!{'walk_in', 'customer', 'credit'}.contains(type)) {
      return _invalid('type must be walk_in, customer, or credit.');
    }

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    if (type != 'walk_in') {
      if (body['customer_id'] == null) {
        return _invalid(
            'customer_id is required for customer and credit sales.');
      }
      final customer = await _findCustomer(body['customer_id'], storeId);
      if (customer == null) return _invalid('customer_id is invalid.');
    }

    final items = body['items'];
    if (items is! List || items.isEmpty) {
      return _invalid('items must be a non-empty array.');
    }

    final builtItems = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) return _invalid('Each sale item must be an object.');
      final built = await _buildSaleItem(item);
      if (built is Response) return built;
      builtItems.add(built as Map<String, dynamic>);
    }

    final totals = _calculateTotals(builtItems);
    final saleNumber = 'SAL-${DateTime.now().millisecondsSinceEpoch}';
    final status = type == 'credit' ? 'pending_credit_approval' : 'draft';

    await DB.query(
      '''
      INSERT INTO sales
        (id, company_id, store_id, customer_id, sale_number, type, status,
         subtotal, discount_total, tax_total, grand_total, amount_paid,
         balance_due, payment_method, payment_status, sold_by, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        body['customer_id'],
        saleNumber,
        type,
        status,
        totals['subtotal'],
        totals['discount_total'],
        totals['tax_total'],
        totals['grand_total'],
        0,
        totals['grand_total'],
        null,
        'unpaid',
        (_authContext['user'] as Map)['id'],
      ],
    );

    final sale = await _first(
      '''
      SELECT * FROM sales
      WHERE company_id = ? AND sale_number = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], saleNumber],
    );
    if (sale == null) return _invalid('Sale could not be created.');
    final saleId = sale['id'];

    await _replaceSaleItems(saleId, builtItems);

    return (await _findSale(saleId))!;
  }

  Future<Response> show() async {
    final sale = await _findSale(req.params['id']);
    if (sale == null) return _notFound();

    return res.json(ApiResponse.success(
      data: sale,
      message: 'Sale retrieved successfully',
    ));
  }

  Future<Response> update() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (!{'draft', 'pending_credit_approval'}.contains(sale['status'])) {
      return _invalid('Only draft or pending credit sales can be updated.');
    }

    final body = await req.json();
    final type = body['type']?.toString() ?? sale['type']?.toString();
    if (type == null || !{'walk_in', 'customer', 'credit'}.contains(type)) {
      return _invalid('type must be walk_in, customer, or credit.');
    }

    final storeId = body.containsKey('store_id')
        ? await _resolveStoreId(body['store_id'])
        : sale['store_id'];
    if (storeId is Response) return storeId;

    final customerId = body.containsKey('customer_id')
        ? body['customer_id']
        : sale['customer_id'];
    if (type != 'walk_in') {
      if (customerId == null) {
        return _invalid(
            'customer_id is required for customer and credit sales.');
      }
      final customer = await _findCustomer(customerId, storeId);
      if (customer == null) return _invalid('customer_id is invalid.');
    }

    final items = body['items'];
    if (items is! List || items.isEmpty) {
      return _invalid('items must be a non-empty array.');
    }

    final builtItems = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map) return _invalid('Each sale item must be an object.');
      final built = await _buildSaleItem(item);
      if (built is Response) return built;
      builtItems.add(built as Map<String, dynamic>);
    }

    final totals = _calculateTotals(builtItems);
    final status = type == 'credit' ? 'pending_credit_approval' : 'draft';

    await DB.query(
      '''
      UPDATE sales
      SET store_id = ?, customer_id = ?, type = ?, status = ?,
          subtotal = ?, discount_total = ?, tax_total = ?, grand_total = ?,
          amount_paid = ?, balance_due = ?, payment_method = ?, payment_status = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        storeId,
        type == 'walk_in' ? null : customerId,
        type,
        status,
        totals['subtotal'],
        totals['discount_total'],
        totals['tax_total'],
        totals['grand_total'],
        0,
        totals['grand_total'],
        null,
        'unpaid',
        saleId,
        _authContext['company_id'],
      ],
    );

    await _replaceSaleItems(saleId, builtItems);

    final updated = await _findSale(saleId);
    _emitSaleChanged('updated', updated);

    return res.json(ApiResponse.success(
      data: updated,
      message: 'Sale updated successfully',
    ));
  }

  Future<Response> smart() async {
    final body = await req.json();
    final text = body['text']?.toString().trim();
    if (text == null || text.isEmpty) {
      return _invalid('text is required.');
    }

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    final parsedLines = _parseSmartSaleText(text);
    if (parsedLines.isEmpty) {
      return _invalid('Could not find any product lines in the text.');
    }

    final matches = <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];
    for (final line in parsedLines) {
      final match = await _matchSmartProduct(line['query'].toString());
      if (match == null || _asDouble(match['score']) < 0.55) {
        matches.add({
          ...line,
          'matched': false,
          'message': 'No confident product match.',
        });
        continue;
      }

      final item = {
        'product_id': match['product_id'],
        'product_variant_id': match['product_variant_id'],
        'quantity': line['quantity'],
      };
      items.add(item);
      matches.add({
        ...line,
        'matched': true,
        'confidence': match['score'],
        'product_id': match['product_id'],
        'product_variant_id': match['product_variant_id'],
        'name': match['name'],
        'sku': match['sku'],
      });
    }

    if (items.length != parsedLines.length) {
      return res.status(422).json(ApiResponse.error(
            code: 'SMART_MATCH_FAILED',
            message:
                'Some sale lines could not be matched confidently. Please edit the text or add products manually.',
            details: {'matches': matches},
          ));
    }

    final saleResponse = await _createSaleFromItems({
      'type': body['type'] ?? 'walk_in',
      'store_id': storeId,
      'customer_id': body['customer_id'],
      'items': items,
    });

    if (saleResponse is Response) return saleResponse;
    _emitSaleChanged('created', saleResponse);
    return res.status(201).json(ApiResponse.success(
          data: {
            'sale': saleResponse,
            'matches': matches,
          },
          message: 'Smart sale draft created successfully',
        ));
  }

  Future<Response> complete() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (sale['status'] == 'completed')
      return _invalid('Sale is already completed.');
    if (sale['status'] == 'pending_credit_approval') {
      return _invalid(
          'Credit sales must be completed through credit approval.');
    }
    if (sale['status'] == 'cancelled')
      return _invalid('Cancelled sale cannot be completed.');

    final body = await req.json();
    final paymentMethod = body['payment_method']?.toString() ?? 'cash';
    if (!{'cash', 'transfer', 'credit'}.contains(paymentMethod)) {
      return _invalid('payment_method must be cash, transfer, or credit.');
    }
    final requestedCustomerId = body['customer_id'];

    if (paymentMethod == 'credit') {
      final customer = requestedCustomerId == null
          ? await _findOrCreateCheckoutCustomer(
              sale: sale,
              customerData: body['customer'],
              requireVerifiedContact: true,
            )
          : await _findCustomer(requestedCustomerId, sale['store_id']);
      if (customer is Response) return customer;
      if (customer == null) return _invalid('customer_id is invalid.');
      final customerMap = customer as Map<String, dynamic>;
      final outstanding = _asDouble(customerMap['outstanding_balance']);
      await _markSaleForCreditApproval(
        sale: sale,
        customer: customerMap,
        requestNote: outstanding > 0
            ? 'Customer has an outstanding balance and must be reviewed by the boss before sale approval.'
            : 'New credit sale requires boss approval before stock moves.',
      );
      final pendingSale = await _findSale(saleId);
      _emitSaleChanged('credit_pending', pendingSale);
      return res.status(202).json(ApiResponse.success(
            data: {
              'sale': pendingSale,
              'customer': customerMap,
              'requires_approval': true,
              'blocked': outstanding > 0,
              'message': outstanding > 0
                  ? 'Customer has outstanding balance. Sale sent to boss for approval.'
                  : 'Credit sale sent to boss for approval.',
            },
            message: outstanding > 0
                ? 'Customer has outstanding balance. Sale sent to boss for approval.'
                : 'Credit sale sent to boss for approval.',
          ));
    }

    Object? checkoutCustomerId = sale['customer_id'];
    if (requestedCustomerId != null) {
      final customer =
          await _findCustomer(requestedCustomerId, sale['store_id']);
      if (customer == null) return _invalid('customer_id is invalid.');
      checkoutCustomerId = customer['id'];
    } else if (body['customer'] is Map) {
      final customer = await _findOrCreateCheckoutCustomer(
        sale: sale,
        customerData: body['customer'],
        requireVerifiedContact: false,
      );
      if (customer is Response) return customer;
      checkoutCustomerId = (customer as Map<String, dynamic>)['id'];
    }

    final items = (sale['items'] as List).cast<Map<String, dynamic>>();
    for (final item in items) {
      final inventory = await _findInventoryForSaleItem(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
      );
      if (inventory == null)
        return _invalid('Inventory row is missing for one or more sale items.');
      final available = _asDouble(inventory['quantity_available']);
      final quantity = _asDouble(item['quantity']);
      if (quantity > available) {
        return res.status(409).json(ApiResponse.error(
              code: 'INSUFFICIENT_STOCK',
              message: 'Insufficient stock for sale item.',
              details: {
                'product_id': item['product_id'],
                'product_variant_id': item['product_variant_id'],
                'available': available,
              },
            ));
      }
    }

    for (final item in items) {
      final inventory = (await _findInventoryForSaleItem(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
      ))!;
      final before = _asDouble(inventory['quantity_on_hand']);
      final reserved = _asDouble(inventory['quantity_reserved']);
      final quantity = _asDouble(item['quantity']);
      final after = before - quantity;

      await _updateInventory(
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityReserved: reserved,
        averageCost: _asDouble(inventory['average_cost']),
        reorderLevel: _asDouble(inventory['reorder_level']),
      );
      _emitInventoryChanged(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityAvailable: after - reserved,
        reason: 'sale_completed',
      );
      await _recordInventoryTransaction(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        quantity: -quantity,
        unitCost: _asDouble(item['unit_cost']),
        before: before,
        after: after,
        saleId: saleId,
      );
    }

    final amountPaid = _asDouble(body['amount_paid'] ?? sale['grand_total']);
    final grandTotal = _asDouble(sale['grand_total']);
    final balanceDue = grandTotal - amountPaid;
    final paymentStatus = balanceDue <= 0
        ? 'paid'
        : amountPaid <= 0
            ? 'unpaid'
            : 'partial';

    await DB.query(
      '''
      UPDATE sales
      SET status = ?, customer_id = ?, type = ?, amount_paid = ?, balance_due = ?,
          payment_method = ?, payment_status = ?,
          completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'completed',
        checkoutCustomerId,
        checkoutCustomerId == null ? sale['type'] : 'customer',
        amountPaid,
        balanceDue,
        paymentMethod,
        paymentStatus,
        saleId,
        _authContext['company_id'],
      ],
    );

    final completed = await _findSale(saleId);
    _emitSaleChanged('completed', completed);

    return res.json(ApiResponse.success(
      data: completed,
      message: 'Sale completed successfully',
    ));
  }

  Future<Response> cancel() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (sale['status'] == 'completed') {
      return _invalid(
          'Completed sale cannot be cancelled. Use refund or return.');
    }

    await DB.query(
      '''
      UPDATE sales
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['cancelled', saleId, _authContext['company_id']],
    );

    final cancelled = await _findSale(saleId);
    _emitSaleChanged('cancelled', cancelled);

    return res.json(ApiResponse.success(
      data: cancelled,
      message: 'Sale cancelled successfully',
    ));
  }

  Future<Response> delete() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (!{'draft', 'pending_credit_approval'}.contains(sale['status'])) {
      return _invalid('Only draft or pending credit sales can be deleted.');
    }

    await DB.query(
      '''
      DELETE FROM sale_items
      WHERE company_id = ? AND sale_id = ?
      ''',
      positionalParams: [_authContext['company_id'], saleId],
    );
    await DB.query(
      '''
      DELETE FROM sales
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [saleId, _authContext['company_id']],
    );

    _emitSaleChanged('deleted', sale);

    return res.json(ApiResponse.success(
      data: {'id': saleId},
      message: 'Draft sale deleted successfully',
    ));
  }

  Future<Response> refund() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (sale['status'] != 'completed') {
      return _invalid('Only completed sales can be refunded.');
    }

    final body = await req.json();
    await DB.query(
      '''
      UPDATE sales
      SET status = ?, amount_paid = ?, balance_due = ?, payment_status = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'refunded',
        0,
        _asDouble(sale['grand_total']),
        'refunded',
        saleId,
        _authContext['company_id'],
      ],
    );

    await _recordAudit(
      action: 'sales.refund',
      entityType: 'sale',
      entityId: saleId,
      beforeData: sale,
      afterData: {
        'status': 'refunded',
        'reason': body['reason'],
      },
    );

    final refunded = await _findSale(saleId);
    _emitSaleChanged('refunded', refunded);

    return res.json(ApiResponse.success(
      data: refunded,
      message: 'Sale refunded successfully',
    ));
  }

  Future<Response> returnSale() async {
    final saleId = req.params['id'];
    final sale = await _findSale(saleId);
    if (sale == null) return _notFound();
    if (sale['status'] != 'completed') {
      return _invalid('Only completed sales can be returned.');
    }

    final items = (sale['items'] as List).cast<Map<String, dynamic>>();
    for (final item in items) {
      final inventory = await _findInventoryForSaleItem(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
      );
      if (inventory == null) {
        return _invalid('Inventory row is missing for one or more sale items.');
      }

      final before = _asDouble(inventory['quantity_on_hand']);
      final reserved = _asDouble(inventory['quantity_reserved']);
      final quantity = _asDouble(item['quantity']);
      final after = before + quantity;

      await _updateInventory(
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityReserved: reserved,
        averageCost: _asDouble(inventory['average_cost']),
        reorderLevel: _asDouble(inventory['reorder_level']),
      );
      _emitInventoryChanged(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        inventoryId: inventory['id'],
        quantityOnHand: after,
        quantityAvailable: after - reserved,
        reason: 'sale_return',
      );
      await _recordInventoryTransaction(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        quantity: quantity,
        unitCost: _asDouble(item['unit_cost']),
        before: before,
        after: after,
        saleId: saleId,
        type: 'return',
        reason: 'Sale return',
      );
    }

    final body = await req.json();
    await DB.query(
      '''
      UPDATE sales
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['returned', saleId, _authContext['company_id']],
    );

    await _recordAudit(
      action: 'sales.return',
      entityType: 'sale',
      entityId: saleId,
      beforeData: sale,
      afterData: {
        'status': 'returned',
        'reason': body['reason'],
      },
    );

    final returned = await _findSale(saleId);
    _emitSaleChanged('returned', returned);

    return res.json(ApiResponse.success(
      data: returned,
      message: 'Sale returned successfully',
    ));
  }

  Future<Response> invoice() => _document('invoice');

  Future<Response> receipt() => _document('receipt');

  Future<Response> _document(String type) async {
    final sale = await _findSale(req.params['id']);
    if (sale == null) return _notFound();

    return res.json(ApiResponse.success(
      data: {
        'document_type': type,
        'sale': sale,
      },
      message:
          '${type[0].toUpperCase()}${type.substring(1)} data retrieved successfully',
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
    if (storeId == null) {
      final store = await _first(
        '''
        SELECT id FROM stores
        WHERE company_id = ? AND deleted_at IS NULL
        ORDER BY created_at ASC
        LIMIT 1
        ''',
        [_authContext['company_id']],
      );
      if (store == null) return _invalid('store_id is required.');
      return store['id'];
    }
    final store = await _first(
      '''
      SELECT id FROM stores
      WHERE id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [storeId, _authContext['company_id']],
    );
    if (store == null) return _invalid('store_id is invalid.');
    return storeId;
  }

  Future<Object> _buildSaleItem(Map item) async {
    if (item['product_id'] == null) return _invalid('product_id is required.');
    final quantity = _asDouble(item['quantity']);
    if (quantity <= 0)
      return _invalid('item quantity must be greater than zero.');

    final product = await _findProduct(item['product_id']);
    if (product == null) return _invalid('product_id is invalid.');

    Map<String, dynamic>? variant;
    if (item['product_variant_id'] != null) {
      variant =
          await _findVariant(item['product_variant_id'], item['product_id']);
      if (variant == null) return _invalid('product_variant_id is invalid.');
    }

    final unitPrice = _asDouble(
      item['unit_price'] ??
          variant?['selling_price'] ??
          product['selling_price'],
    );
    final unitCost = _asDouble(
      item['unit_cost'] ?? variant?['cost_price'] ?? product['cost_price'],
    );
    final discount = _asDouble(item['discount_amount']);
    final tax = _asDouble(item['tax_amount']);
    final lineTotal = (quantity * unitPrice) - discount + tax;

    return {
      'product_id': item['product_id'],
      'product_variant_id': item['product_variant_id'],
      'sku_snapshot': variant?['sku'] ?? product['sku'],
      'name_snapshot': variant == null
          ? product['name']
          : '${product['name']} - ${variant['variant_name']}',
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'discount_amount': discount,
      'tax_amount': tax,
      'line_total': lineTotal,
    };
  }

  List<Map<String, dynamic>> _parseSmartSaleText(String text) {
    final chunks = text
        .split(RegExp(r'[\n,;]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final parsed = <Map<String, dynamic>>[];

    for (final chunk in chunks) {
      var line = chunk
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\bx\b', caseSensitive: false), ' ');
      var quantity = 1.0;
      var query = line;

      final leading = RegExp(r'^(\d+(?:\.\d+)?)\s+(.+)$').firstMatch(line);
      final trailing = RegExp(r'^(.+?)\s+(\d+(?:\.\d+)?)$').firstMatch(line);
      if (leading != null) {
        quantity = _asDouble(leading.group(1));
        query = leading.group(2) ?? '';
      } else if (trailing != null) {
        quantity = _asDouble(trailing.group(2));
        query = trailing.group(1) ?? '';
      }

      query = query.trim();
      if (quantity > 0 && query.isNotEmpty) {
        parsed.add({
          'raw': chunk,
          'quantity': quantity,
          'query': query,
        });
      }
    }

    return parsed;
  }

  Future<Map<String, dynamic>?> _matchSmartProduct(String query) async {
    final candidates = await DB.query(
      '''
      SELECT
        'product' AS match_type,
        products.id AS product_id,
        NULL AS product_variant_id,
        products.name AS name,
        products.sku AS sku,
        products.barcode AS barcode,
        products.brand AS brand
      FROM products
      WHERE products.company_id = ?
        AND products.deleted_at IS NULL
        AND products.status = 'active'
      UNION ALL
      SELECT
        'variant' AS match_type,
        products.id AS product_id,
        product_variants.id AS product_variant_id,
        products.name || ' - ' || product_variants.variant_name AS name,
        product_variants.sku AS sku,
        product_variants.barcode AS barcode,
        products.brand AS brand
      FROM product_variants
      INNER JOIN products ON products.id = product_variants.product_id
      WHERE product_variants.company_id = ?
        AND product_variants.deleted_at IS NULL
        AND product_variants.status = 'active'
        AND products.deleted_at IS NULL
      ''',
      positionalParams: [
        _authContext['company_id'],
        _authContext['company_id']
      ],
    );

    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final row in candidates) {
      final candidate = Map<String, dynamic>.from(row as Map);
      final score = _smartScore(query, [
        candidate['name'],
        candidate['sku'],
        candidate['barcode'],
        candidate['brand'],
      ]);
      if (score > bestScore) {
        bestScore = score;
        best = {
          ...candidate,
          'score': score,
        };
      }
    }
    return best;
  }

  double _smartScore(String query, List<Object?> fields) {
    final queryTokens = _tokens(query);
    if (queryTokens.isEmpty) return 0;
    final haystack = fields
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .join(' ');
    if (haystack.trim().isEmpty) return 0;

    final haystackTokens = _tokens(haystack);
    var matched = 0;
    for (final token in queryTokens) {
      if (haystackTokens.contains(token) ||
          haystackTokens.any((candidate) => candidate.contains(token))) {
        matched++;
      }
    }

    var score = matched / queryTokens.length;
    final normalizedQuery = queryTokens.join(' ');
    if (haystack.contains(normalizedQuery)) score += 0.25;
    return score > 1 ? 1 : score;
  }

  Set<String> _tokens(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length > 1)
        .toSet();
  }

  Map<String, double> _calculateTotals(List<Map<String, dynamic>> items) {
    var subtotal = 0.0;
    var discountTotal = 0.0;
    var taxTotal = 0.0;
    var grandTotal = 0.0;
    for (final item in items) {
      subtotal += _asDouble(item['quantity']) * _asDouble(item['unit_price']);
      discountTotal += _asDouble(item['discount_amount']);
      taxTotal += _asDouble(item['tax_amount']);
      grandTotal += _asDouble(item['line_total']);
    }
    return {
      'subtotal': subtotal,
      'discount_total': discountTotal,
      'tax_total': taxTotal,
      'grand_total': grandTotal,
    };
  }

  Future<void> _replaceSaleItems(
    Object? saleId,
    List<Map<String, dynamic>> items,
  ) async {
    await DB.query(
      '''
      DELETE FROM sale_items
      WHERE company_id = ? AND sale_id = ?
      ''',
      positionalParams: [_authContext['company_id'], saleId],
    );

    for (final item in items) {
      await DB.query(
        '''
        INSERT INTO sale_items
          (id, company_id, sale_id, product_id, product_variant_id, sku_snapshot,
           name_snapshot, quantity, unit_price, unit_cost, discount_amount,
           tax_amount, line_total, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          _authContext['company_id'],
          saleId,
          item['product_id'],
          item['product_variant_id'],
          item['sku_snapshot'],
          item['name_snapshot'],
          item['quantity'],
          item['unit_price'],
          item['unit_cost'],
          item['discount_amount'],
          item['tax_amount'],
          item['line_total'],
        ],
      );
    }
  }

  Future<Map<String, dynamic>?> _findSale(Object? id) async {
    final where = ['sales.id = ?', 'sales.company_id = ?'];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('sales.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final sale = await _first(
      '''
      SELECT
        sales.*,
        stores.name AS store_name,
        customers.name AS customer_name,
        users.email AS sold_by_email
      FROM sales
      INNER JOIN stores ON stores.id = sales.store_id
      LEFT JOIN customers ON customers.id = sales.customer_id
      LEFT JOIN users ON users.id = sales.sold_by
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      params,
    );
    if (sale == null) return null;

    return {
      ...sale,
      'items': await DB.query(
        '''
        SELECT * FROM sale_items
        WHERE company_id = ? AND sale_id = ?
        ORDER BY id
        ''',
        positionalParams: [_authContext['company_id'], id],
      ),
    };
  }

  Future<Map<String, dynamic>?> _findCustomer(Object? id, Object? storeId) {
    return _first(
      '''
      SELECT * FROM customers
      WHERE id = ? AND company_id = ? AND store_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id'], storeId],
    );
  }

  Future<Object> _findOrCreateCheckoutCustomer({
    required Map<String, dynamic> sale,
    required Object? customerData,
    required bool requireVerifiedContact,
  }) async {
    final data = customerData is Map
        ? Map<String, dynamic>.from(customerData)
        : <String, dynamic>{};
    final name = data['name']?.toString().trim();
    final phone = data['phone']?.toString().trim();
    final email = data['email']?.toString().trim();
    final address = data['address']?.toString().trim();

    if ((name == null || name.isEmpty) &&
        (phone == null || phone.isEmpty) &&
        (email == null || email.isEmpty)) {
      return _invalid('Customer full name, phone, or email is required.');
    }

    final existing = await _findCustomerForCheckout(
      storeId: sale['store_id'],
      phone: phone,
      email: email,
    );
    if (existing != null) {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (phone != null && phone.isNotEmpty) {
        final normalizedPhone =
            _otp.normalizeContact(channel: 'whatsapp', contact: phone);
        if (existing['phone']?.toString() != normalizedPhone) {
          if (requireVerifiedContact &&
              !await _hasVerifiedCheckoutContact(
                sale: sale,
                channel: 'whatsapp',
                contact: normalizedPhone,
              )) {
            return _invalid(
              'Verify the customer WhatsApp number before credit sale.',
            );
          }
          updates['phone'] = normalizedPhone;
          updates['phone_verified'] = requireVerifiedContact ? 1 : 0;
          if (requireVerifiedContact) {
            updates['phone_verified_at'] = 'CURRENT_TIMESTAMP';
          }
        }
      }
      if (email != null && email.isNotEmpty) {
        final normalizedEmail =
            _otp.normalizeContact(channel: 'email', contact: email);
        if (existing['email']?.toString() != normalizedEmail) {
          if (requireVerifiedContact &&
              !await _hasVerifiedCheckoutContact(
                sale: sale,
                channel: 'email',
                contact: normalizedEmail,
              )) {
            return _invalid(
              'Verify the customer email before credit sale.',
            );
          }
          updates['email'] = normalizedEmail;
          updates['email_verified'] = requireVerifiedContact ? 1 : 0;
          if (requireVerifiedContact) {
            updates['email_verified_at'] = 'CURRENT_TIMESTAMP';
          }
        }
      }
      if (address != null && address.isNotEmpty) updates['address'] = address;
      if (updates.isNotEmpty) {
        final fields = <String>[];
        final values = <dynamic>[];
        for (final entry in updates.entries) {
          if (entry.value == 'CURRENT_TIMESTAMP') {
            fields.add('${entry.key} = CURRENT_TIMESTAMP');
          } else {
            fields.add('${entry.key} = ?');
            values.add(entry.value);
          }
        }
        final setClause = fields.join(', ');
        await DB.query(
          '''
          UPDATE customers
          SET $setClause, updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND company_id = ?
          ''',
          positionalParams: [
            ...values,
            existing['id'],
            _authContext['company_id'],
          ],
        );
      }
      return (await _findCustomer(existing['id'], sale['store_id']))!;
    }

    final normalizedPhone = phone == null || phone.isEmpty
        ? null
        : _otp.normalizeContact(channel: 'whatsapp', contact: phone);
    final normalizedEmail = email == null || email.isEmpty
        ? null
        : _otp.normalizeContact(channel: 'email', contact: email);
    if (requireVerifiedContact) {
      final phoneVerified = normalizedPhone != null &&
          await _hasVerifiedCheckoutContact(
            sale: sale,
            channel: 'whatsapp',
            contact: normalizedPhone,
          );
      final emailVerified = normalizedEmail != null &&
          await _hasVerifiedCheckoutContact(
            sale: sale,
            channel: 'email',
            contact: normalizedEmail,
          );
      if (!phoneVerified && !emailVerified) {
        return _invalid(
          'Verify the customer email or WhatsApp before credit sale.',
        );
      }
    }

    await DB.query(
      '''
      INSERT INTO customers
        (id, company_id, store_id, name, phone, email, address, credit_limit,
         outstanding_balance, status, phone_verified, email_verified,
         phone_verified_at, email_verified_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
              CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        sale['store_id'],
        name == null || name.isEmpty ? (phone ?? email ?? 'Customer') : name,
        normalizedPhone,
        normalizedEmail,
        address,
        0,
        0,
        'active',
        requireVerifiedContact && normalizedPhone != null ? 1 : 0,
        requireVerifiedContact && normalizedEmail != null ? 1 : 0,
        requireVerifiedContact && normalizedPhone != null
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        requireVerifiedContact && normalizedEmail != null
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      ],
    );

    return (await _findCustomerForCheckout(
      storeId: sale['store_id'],
      phone: normalizedPhone,
      email: normalizedEmail,
    ))!;
  }

  Future<bool> _hasVerifiedCheckoutContact({
    required Map<String, dynamic> sale,
    required String channel,
    required String contact,
  }) {
    return _otp.hasVerifiedContact(
      companyId: _authContext['company_id'],
      storeId: sale['store_id'],
      channel: channel,
      contact: contact,
    );
  }

  Future<Map<String, dynamic>?> _findCustomerForCheckout({
    required Object? storeId,
    String? phone,
    String? email,
  }) {
    final clauses = <String>[];
    final params = <dynamic>[_authContext['company_id'], storeId];
    if (phone != null && phone.isNotEmpty) {
      clauses.add('phone = ?');
      params.add(_otp.normalizeContact(channel: 'whatsapp', contact: phone));
    }
    if (email != null && email.isNotEmpty) {
      clauses.add('email = ?');
      params.add(_otp.normalizeContact(channel: 'email', contact: email));
    }
    if (clauses.isEmpty) return Future.value(null);

    return _first(
      '''
      SELECT *
      FROM customers
      WHERE company_id = ?
        AND store_id = ?
        AND deleted_at IS NULL
        AND (${clauses.join(' OR ')})
      ORDER BY updated_at DESC
      LIMIT 1
      ''',
      params,
    );
  }

  Future<void> _markSaleForCreditApproval({
    required Map<String, dynamic> sale,
    required Map<String, dynamic> customer,
    required String requestNote,
  }) async {
    await DB.query(
      '''
      UPDATE sales
      SET type = ?, status = ?, customer_id = ?, amount_paid = ?, balance_due = ?,
          payment_method = ?, payment_status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'credit',
        'pending_credit_approval',
        customer['id'],
        0,
        sale['grand_total'],
        'credit',
        'credit_pending',
        sale['id'],
        _authContext['company_id'],
      ],
    );

    final existing = await _first(
      '''
      SELECT id FROM credit_requests
      WHERE company_id = ? AND sale_id = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], sale['id']],
    );
    if (existing != null) return;

    await DB.query(
      '''
      INSERT INTO credit_requests
        (id, company_id, store_id, sale_id, customer_id, requested_by, amount,
         status, request_note, current_approver_role, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        sale['store_id'],
        sale['id'],
        customer['id'],
        (_authContext['user'] as Map)['id'],
        sale['grand_total'],
        'manager_approved',
        requestNote,
        'company_admin',
      ],
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

  Future<Map<String, dynamic>?> _findInventoryForSaleItem({
    required Object? storeId,
    required Object? productId,
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

  Future<void> _updateInventory({
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
    required Object? storeId,
    required Object? productId,
    required Object? variantId,
    required double quantity,
    required double unitCost,
    required double before,
    required double after,
    required Object? saleId,
    String type = 'sale',
    Object? reason = 'Sale completion',
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
        'sale',
        saleId,
        reason,
        (_authContext['user'] as Map)['id'],
      ],
    );
  }

  Future<void> _recordAudit({
    required String action,
    required String entityType,
    required Object? entityId,
    Object? beforeData,
    Object? afterData,
  }) {
    return DB.query(
      '''
      INSERT INTO audit_logs
        (id, company_id, store_id, user_id, action, entity_type, entity_id,
         before_data_json, after_data_json, ip_address, user_agent, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        _authContext['store_id'],
        (_authContext['user'] as Map)['id'],
        action,
        entityType,
        entityId,
        beforeData?.toString(),
        afterData?.toString(),
        req.ipAddress,
        req.headers['user-agent'] ?? req.headers['User-Agent'],
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

  void _emitSaleChanged(String action, Object? sale) {
    final saleMap = sale is Map ? Map<String, dynamic>.from(sale) : null;
    SalesRealtimeService.saleChanged(
      action: action,
      companyId: _authContext['company_id'],
      storeId: saleMap?['store_id'],
      saleId: saleMap?['id'],
    );
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

  Future<Response> _notFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Sale not found.',
        ));
  }
}
