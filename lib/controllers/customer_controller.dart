import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class CustomerController extends Controller {
  Future<Response> index() async {
    final query = req.queryParam('q')?.trim();
    final storeId = _storeFilter();

    final where = [
      'customers.company_id = ?',
      'customers.deleted_at IS NULL',
    ];
    final params = <dynamic>[_authContext['company_id']];

    if (storeId != null) {
      where.add('customers.store_id = ?');
      params.add(storeId);
    }

    if (query != null && query.isNotEmpty) {
      where.add(
        '(customers.name LIKE ? OR customers.phone LIKE ? OR customers.email LIKE ?)',
      );
      final like = '%$query%';
      params.addAll([like, like, like]);
    }

    final rows = await DB.query(
      '''
      SELECT
        customers.*,
        stores.name AS store_name
      FROM customers
      INNER JOIN stores ON stores.id = customers.store_id
      WHERE ${where.join(' AND ')}
      ORDER BY customers.name
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Customers retrieved successfully',
    ));
  }

  Future<Response> create() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({'name': 'required|string'});
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    await DB.query(
      '''
      INSERT INTO customers
        (id, company_id, store_id, name, phone, email, address, credit_limit,
         outstanding_balance, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        body['name'],
        body['phone'],
        body['email'],
        body['address'],
        body['credit_limit'] ?? 0,
        body['outstanding_balance'] ?? 0,
        body['status'] ?? 'active',
      ],
    );

    final customer = await _first(
      '''
      SELECT * FROM customers
      WHERE company_id = ? AND store_id = ? AND name = ? AND deleted_at IS NULL
      ORDER BY id DESC
      LIMIT 1
      ''',
      [_authContext['company_id'], storeId, body['name']],
    );

    return res.status(201).json(ApiResponse.success(
      data: customer,
      message: 'Customer created successfully',
    ));
  }

  Future<Response> show() async {
    final customer = await _findCustomer(req.params['id']);
    if (customer == null) return _notFound();

    return res.json(ApiResponse.success(
      data: customer,
      message: 'Customer retrieved successfully',
    ));
  }

  Future<Response> update() async {
    final customerId = req.params['id'];
    final customer = await _findCustomer(customerId);
    if (customer == null) return _notFound();

    final body = await req.json();
    if (body['store_id'] != null) {
      final store = await _findStore(body['store_id']);
      if (store == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'store_id is invalid.',
            ));
      }
      if (_authContext['role_scope'] == 'store' &&
          body['store_id'].toString() != _authContext['store_id'].toString()) {
        return res.status(403).json(ApiResponse.error(
              code: 'FORBIDDEN',
              message: 'Store users cannot move customers to another store.',
            ));
      }
    }

    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'status must be active or inactive.',
          ));
    }

    const allowedFields = {
      'store_id',
      'name',
      'phone',
      'email',
      'address',
      'credit_limit',
      'outstanding_balance',
      'status',
    };
    final updates = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) {
        updates[entry.key] = entry.value;
      }
    }

    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE customers
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          customerId,
          _authContext['company_id'],
        ],
      );
    }

    return res.json(ApiResponse.success(
      data: await _findCustomer(customerId),
      message: 'Customer updated successfully',
    ));
  }

  Future<Response> statement() async {
    final customer = await _findCustomer(req.params['id']);
    if (customer == null) return _notFound();

    final sales = await _customerSales(req.params['id']);
    final credits = await _customerCredits(req.params['id']);

    return res.json(ApiResponse.success(
      data: {
        'customer': customer,
        'opening_balance': 0,
        'outstanding_balance': customer['outstanding_balance'],
        'sales': sales,
        'credits': credits,
      },
      message: 'Customer statement retrieved successfully',
    ));
  }

  Future<Response> creditHistory() async {
    final customer = await _findCustomer(req.params['id']);
    if (customer == null) return _notFound();

    return res.json(ApiResponse.success(
      data: await _customerCredits(req.params['id']),
      message: 'Customer credit history retrieved successfully',
    ));
  }

  Future<Response> purchaseHistory() async {
    final customer = await _findCustomer(req.params['id']);
    if (customer == null) return _notFound();

    return res.json(ApiResponse.success(
      data: await _customerSales(req.params['id']),
      message: 'Customer purchase history retrieved successfully',
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
    final storeId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : requestedStoreId;

    if (storeId == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'store_id is required.',
          ));
    }

    final store = await _findStore(storeId);
    if (store == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'store_id is invalid.',
          ));
    }

    return storeId;
  }

  Future<Map<String, dynamic>?> _findCustomer(Object? id) {
    final where = [
      'customers.id = ?',
      'customers.company_id = ?',
      'customers.deleted_at IS NULL',
    ];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('customers.store_id = ?');
      params.add(_authContext['store_id']);
    }

    return _first(
      '''
      SELECT
        customers.*,
        stores.name AS store_name
      FROM customers
      INNER JOIN stores ON stores.id = customers.store_id
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      params,
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

  Future<List<Map<String, dynamic>>> _customerSales(Object? customerId) {
    return DB.query(
      '''
      SELECT
        sales.*,
        stores.name AS store_name,
        users.email AS sold_by_email
      FROM sales
      INNER JOIN stores ON stores.id = sales.store_id
      LEFT JOIN users ON users.id = sales.sold_by
      WHERE sales.company_id = ?
        AND sales.customer_id = ?
      ORDER BY sales.created_at DESC
      ''',
      positionalParams: [_authContext['company_id'], customerId],
    );
  }

  Future<List<Map<String, dynamic>>> _customerCredits(Object? customerId) {
    return DB.query(
      '''
      SELECT
        credit_requests.*,
        stores.name AS store_name,
        users.email AS requested_by_email
      FROM credit_requests
      INNER JOIN stores ON stores.id = credit_requests.store_id
      LEFT JOIN users ON users.id = credit_requests.requested_by
      WHERE credit_requests.company_id = ?
        AND credit_requests.customer_id = ?
      ORDER BY credit_requests.created_at DESC
      ''',
      positionalParams: [_authContext['company_id'], customerId],
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

  Future<Response> _notFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Customer not found.',
        ));
  }
}
