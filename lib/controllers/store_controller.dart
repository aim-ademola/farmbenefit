import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class StoreController extends Controller {
  Future<Response> index() async {
    final auth = _authContext;
    final rows = await DB.query(
      '''
      SELECT
        stores.*,
        CONCAT(users.first_name, ' ', users.last_name) AS manager_name
      FROM stores
      LEFT JOIN users ON users.id = stores.manager_user_id
      WHERE stores.company_id = ?
        AND stores.deleted_at IS NULL
      ORDER BY stores.name
      ''',
      positionalParams: [auth['company_id']],
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Stores retrieved successfully',
    ));
  }

  Future<Response> create() async {
    final auth = _authContext;
    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'name': 'required|string',
        'code': 'required|string',
        'type': 'required|string',
      });
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
    final validationError = await _validateStoreBody(body, requireCode: true);
    if (validationError != null) return validationError;

    final existing = await _first(
      '''
      SELECT id FROM stores
      WHERE company_id = ? AND code = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [auth['company_id'], body['code']],
    );
    if (existing != null) {
      return res.status(409).json(ApiResponse.error(
        code: 'CONFLICT',
        message: 'A store with this code already exists.',
      ));
    }

    await DB.query(
      '''
      INSERT INTO stores
        (id, company_id, name, code, type, phone, email, address, status,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        auth['company_id'],
        body['name'],
        body['code'],
        body['type'],
        body['phone'],
        body['email'],
        body['address'],
        body['status'] ?? 'active',
      ],
    );

    final store = await _first(
      'SELECT * FROM stores WHERE company_id = ? AND code = ? LIMIT 1',
      [auth['company_id'], body['code']],
    );

    return res.status(201).json(ApiResponse.success(
      data: store,
      message: 'Store created successfully',
    ));
  }

  Future<Response> show() async {
    final store = await _findStore(req.params['id']);
    if (store == null) {
      return _notFound();
    }

    return res.json(ApiResponse.success(
      data: store,
      message: 'Store retrieved successfully',
    ));
  }

  Future<Response> update() async {
    final storeId = req.params['id'];
    final store = await _findStore(storeId);
    if (store == null) {
      return _notFound();
    }

    final body = await req.json();
    final validationError = await _validateStoreBody(body, partial: true);
    if (validationError != null) return validationError;

    final allowedFields = {
      'name',
      'code',
      'type',
      'phone',
      'email',
      'address',
      'status',
    };
    final updates = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) {
        updates[entry.key] = entry.value;
      }
    }

    if (updates.containsKey('code')) {
      final duplicate = await _first(
        '''
        SELECT id FROM stores
        WHERE company_id = ? AND code = ? AND id <> ? AND deleted_at IS NULL
        LIMIT 1
        ''',
        [_authContext['company_id'], updates['code'], storeId],
      );
      if (duplicate != null) {
        return res.status(409).json(ApiResponse.error(
          code: 'CONFLICT',
          message: 'A store with this code already exists.',
        ));
      }
    }

    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE stores
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updates.values,
          storeId,
          _authContext['company_id'],
        ],
      );
    }

    final updatedStore = await _findStore(storeId);
    return res.json(ApiResponse.success(
      data: updatedStore,
      message: 'Store updated successfully',
    ));
  }

  Future<Response> delete() async {
    final storeId = req.params['id'];
    final store = await _findStore(storeId);
    if (store == null) {
      return _notFound();
    }

    await DB.query(
      '''
      UPDATE stores
      SET status = ?, deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['inactive', storeId, _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      message: 'Store deactivated successfully',
    ));
  }

  Future<Response> assignManager() async {
    final storeId = req.params['id'];
    Map<String, dynamic> body;
    try {
      body = await req.validate({'user_id': 'required'});
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
    final userId = body['user_id'];

    final store = await _findStore(storeId);
    if (store == null) {
      return _notFound();
    }

    final user = await _findCompanyUser(userId);
    if (user == null) {
      return res.status(404).json(ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'User not found.',
      ));
    }

    if (user['role_key'] != 'store_manager') {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'Assigned manager must have the Store Manager role.',
      ));
    }

    await DB.query(
      '''
      UPDATE stores
      SET manager_user_id = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [userId, storeId, _authContext['company_id']],
    );

    await DB.query(
      '''
      UPDATE users
      SET store_id = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [storeId, userId, _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: await _findStore(storeId),
      message: 'Store manager assigned successfully',
    ));
  }

  Future<Response> assignStaff() async {
    final storeId = req.params['id'];
    Map<String, dynamic> body;
    try {
      body = await req.validate({'user_id': 'required'});
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
    final userId = body['user_id'];

    final store = await _findStore(storeId);
    if (store == null) {
      return _notFound();
    }

    final user = await _findCompanyUser(userId);
    if (user == null) {
      return res.status(404).json(ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'User not found.',
      ));
    }

    if (user['role_scope'] != 'store') {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'Only store-scoped users can be assigned to a store.',
      ));
    }

    await DB.query(
      '''
      UPDATE users
      SET store_id = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [storeId, userId, _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: await _findCompanyUser(userId),
      message: 'Staff assigned to store successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Map<String, dynamic>?> _findStore(Object? id) {
    return _first(
      '''
      SELECT
        stores.*,
        CONCAT(users.first_name, ' ', users.last_name) AS manager_name
      FROM stores
      LEFT JOIN users ON users.id = stores.manager_user_id
      WHERE stores.id = ?
        AND stores.company_id = ?
        AND stores.deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findCompanyUser(Object id) {
    return _first(
      '''
      SELECT
        users.id,
        users.company_id,
        users.store_id,
        users.role_id,
        users.first_name,
        users.last_name,
        users.email,
        users.username,
        users.status,
        roles.key AS role_key,
        roles.scope AS role_scope
      FROM users
      INNER JOIN roles ON roles.id = users.role_id
      WHERE users.id = ?
        AND users.company_id = ?
        AND users.deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
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

  Future<Response?> _validateStoreBody(
    Map<String, dynamic> body, {
    bool partial = false,
    bool requireCode = false,
  }) {
    final requiredFields = ['name', if (requireCode) 'code', 'type'];
    if (!partial) {
      for (final field in requiredFields) {
        if (body[field] == null || body[field].toString().trim().isEmpty) {
          return res.status(422).json(ApiResponse.error(
                code: 'VALIDATION_ERROR',
                message: '$field is required.',
              ));
        }
      }
    }

    final type = body['type']?.toString();
    if (type != null && !{'main', 'warehouse', 'branch'}.contains(type)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'type must be one of main, warehouse, branch.',
          ));
    }

    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'status must be active or inactive.',
          ));
    }

    return Future<Response?>.value();
  }

  Future<Response> _notFound() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Store not found.',
        ));
  }
}
