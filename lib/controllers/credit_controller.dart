import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/sales_realtime_service.dart';

class CreditController extends Controller {
  Future<Response> index() async {
    final storeId = _storeFilter();
    final status = req.queryParam('status');

    final where = ['credit_requests.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];
    if (storeId != null) {
      where.add('credit_requests.store_id = ?');
      params.add(storeId);
    }
    if (status != null && status.isNotEmpty) {
      where.add('credit_requests.status = ?');
      params.add(status);
    }

    final rows = await DB.query(
      '''
      SELECT
        credit_requests.*,
        stores.name AS store_name,
        customers.name AS customer_name,
        users.email AS requested_by_email
      FROM credit_requests
      INNER JOIN stores ON stores.id = credit_requests.store_id
      INNER JOIN customers ON customers.id = credit_requests.customer_id
      LEFT JOIN users ON users.id = credit_requests.requested_by
      WHERE ${where.join(' AND ')}
      ORDER BY credit_requests.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Credit requests retrieved successfully',
    ));
  }

  Future<Response> create() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({'sale_id': 'required'});
    } on ValidationException catch (e) {
      return _validationFailed(e);
    }

    final sale = await _findSale(body['sale_id']);
    if (sale == null) return _invalid('sale_id is invalid.');
    if (sale['type'] != 'credit')
      return _invalid('Sale must be a credit sale.');
    if (sale['customer_id'] == null)
      return _invalid('Credit sale requires a customer.');
    if (sale['status'] != 'pending_credit_approval') {
      return _invalid('Sale must be pending credit approval.');
    }

    final existing = await _first(
      '''
      SELECT id FROM credit_requests
      WHERE company_id = ? AND sale_id = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], sale['id']],
    );
    if (existing != null) {
      return res.status(409).json(ApiResponse.error(
            code: 'CONFLICT',
            message: 'A credit request already exists for this sale.',
          ));
    }

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
        sale['customer_id'],
        (_authContext['user'] as Map)['id'],
        sale['grand_total'],
        'pending',
        body['request_note'],
        'store_manager',
      ],
    );

    final request = await _first(
      '''
      SELECT id FROM credit_requests
      WHERE company_id = ? AND sale_id = ?
      LIMIT 1
      ''',
      [_authContext['company_id'], sale['id']],
    );

    return res.status(201).json(ApiResponse.success(
          data: await _findCreditRequest(request!['id']),
          message: 'Credit request created successfully',
        ));
  }

  Future<Response> show() async {
    final request = await _findCreditRequest(req.params['id']);
    if (request == null) return _notFound();

    return res.json(ApiResponse.success(
      data: request,
      message: 'Credit request retrieved successfully',
    ));
  }

  Future<Response> managerApprove() async {
    final request = await _findCreditRequest(req.params['id']);
    if (request == null) return _notFound();
    if (request['status'] != 'pending') {
      return _invalid('Only pending credit requests can be manager approved.');
    }
    if (_authContext['role_scope'] == 'store' &&
        request['store_id'].toString() != _authContext['store_id'].toString()) {
      return res.status(403).json(ApiResponse.error(
            code: 'FORBIDDEN',
            message: 'Store users can approve only requests from their store.',
          ));
    }

    final body = await req.json();
    await _recordApproval(
      creditRequestId: request['id'],
      decision: 'approved',
      statusBefore: request['status'],
      statusAfter: 'manager_approved',
      comments: body['comments'],
    );
    await DB.query(
      '''
      UPDATE credit_requests
      SET status = ?, current_approver_role = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'manager_approved',
        'company_admin',
        request['id'],
        _authContext['company_id'],
      ],
    );

    return res.json(ApiResponse.success(
      data: await _findCreditRequest(request['id']),
      message: 'Credit request manager approved successfully',
    ));
  }

  Future<Response> adminApprove() async {
    final request = await _findCreditRequest(req.params['id']);
    if (request == null) return _notFound();
    if (request['status'] != 'manager_approved') {
      return _invalid(
          'Only manager-approved credit requests can be admin approved.');
    }

    final sale = await _findSale(request['sale_id']);
    if (sale == null) return _invalid('Linked sale was not found.');
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
      final available = _asDouble(inventory['quantity_available']);
      final quantity = _asDouble(item['quantity']);
      if (quantity > available) {
        return res.status(409).json(ApiResponse.error(
              code: 'INSUFFICIENT_STOCK',
              message: 'Insufficient stock for credit sale item.',
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
        reason: 'credit_sale_approved',
      );
      await _recordInventoryTransaction(
        storeId: sale['store_id'],
        productId: item['product_id'],
        variantId: item['product_variant_id'],
        quantity: -quantity,
        unitCost: _asDouble(item['unit_cost']),
        before: before,
        after: after,
        saleId: sale['id'],
      );
    }

    await DB.query(
      '''
      UPDATE sales
      SET status = ?, amount_paid = ?, balance_due = ?, payment_method = ?, payment_status = ?,
          completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'completed',
        0,
        sale['grand_total'],
        'credit',
        'credit',
        sale['id'],
        _authContext['company_id'],
      ],
    );
    await DB.query(
      '''
      UPDATE customers
      SET outstanding_balance = outstanding_balance + ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        sale['grand_total'],
        sale['customer_id'],
        _authContext['company_id'],
      ],
    );

    final body = await req.json();
    await _recordApproval(
      creditRequestId: request['id'],
      decision: 'approved',
      statusBefore: request['status'],
      statusAfter: 'approved',
      comments: body['comments'],
    );
    await DB.query(
      '''
      UPDATE credit_requests
      SET status = ?, current_approver_role = NULL,
          final_decision_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['approved', request['id'], _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: await _findCreditRequest(request['id']),
      message: 'Credit request admin approved successfully',
    ));
  }

  Future<Response> reject() async {
    final request = await _findCreditRequest(req.params['id']);
    if (request == null) return _notFound();
    if ({'approved', 'rejected'}.contains(request['status'])) {
      return _invalid('Finalized credit requests cannot be changed.');
    }

    final body = await req.json();
    await _recordApproval(
      creditRequestId: request['id'],
      decision: 'rejected',
      statusBefore: request['status'],
      statusAfter: 'rejected',
      comments: body['comments'],
    );
    await DB.query(
      '''
      UPDATE credit_requests
      SET status = ?, current_approver_role = NULL,
          final_decision_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['rejected', request['id'], _authContext['company_id']],
    );
    await DB.query(
      '''
      UPDATE sales
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        'cancelled',
        request['sale_id'],
        _authContext['company_id']
      ],
    );

    return res.json(ApiResponse.success(
      data: await _findCreditRequest(request['id']),
      message: 'Credit request rejected successfully',
    ));
  }

  Future<Response> approvals() async {
    final request = await _findCreditRequest(req.params['id']);
    if (request == null) return _notFound();

    return res.json(ApiResponse.success(
      data: await _approvalHistory(req.params['id']),
      message: 'Credit approval history retrieved successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Object? _storeFilter() {
    if (_authContext['role_scope'] == 'store') return _authContext['store_id'];
    final storeId = req.queryParam('store_id');
    return storeId == null || storeId.isEmpty ? null : storeId;
  }

  Future<void> _recordApproval({
    required Object creditRequestId,
    required String decision,
    required String statusBefore,
    required String statusAfter,
    Object? comments,
  }) {
    return DB.query(
      '''
      INSERT INTO credit_approvals
        (id, company_id, credit_request_id, approver_user_id, approver_role_key,
         decision, status_before, status_after, comments, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        creditRequestId,
        (_authContext['user'] as Map)['id'],
        _authContext['role_key'],
        decision,
        statusBefore,
        statusAfter,
        comments,
      ],
    );
  }

  Future<Map<String, dynamic>?> _findCreditRequest(Object? id) async {
    final where = ['credit_requests.id = ?', 'credit_requests.company_id = ?'];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('credit_requests.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final request = await _first(
      '''
      SELECT
        credit_requests.*,
        stores.name AS store_name,
        customers.name AS customer_name,
        users.email AS requested_by_email
      FROM credit_requests
      INNER JOIN stores ON stores.id = credit_requests.store_id
      INNER JOIN customers ON customers.id = credit_requests.customer_id
      LEFT JOIN users ON users.id = credit_requests.requested_by
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      params,
    );
    if (request == null) return null;
    return {
      ...request,
      'approvals': await _approvalHistory(id),
      'sale': await _findSale(request['sale_id']),
    };
  }

  Future<List<Map<String, dynamic>>> _approvalHistory(Object? creditRequestId) {
    return DB.query(
      '''
      SELECT
        credit_approvals.*,
        users.email AS approver_email
      FROM credit_approvals
      LEFT JOIN users ON users.id = credit_approvals.approver_user_id
      WHERE credit_approvals.company_id = ?
        AND credit_approvals.credit_request_id = ?
      ORDER BY credit_approvals.created_at
      ''',
      positionalParams: [_authContext['company_id'], creditRequestId],
    );
  }

  Future<Map<String, dynamic>?> _findSale(Object? id) async {
    final sale = await _first(
      '''
      SELECT * FROM sales
      WHERE id = ?
        AND company_id = ?
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
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
        'sale',
        quantity,
        unitCost,
        before,
        after,
        'sale',
        saleId,
        'Credit sale final approval',
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
          message: 'Credit request not found.',
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
