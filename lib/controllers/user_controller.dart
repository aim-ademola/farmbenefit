import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class UserController extends Controller {
  Future<Response> index() async {
    final rows = await DB.query(
      '''
      SELECT
        users.id,
        users.company_id,
        users.store_id,
        users.role_id,
        users.first_name,
        users.last_name,
        users.email,
        users.phone,
        users.username,
        users.status,
        users.last_login_at,
        users.created_at,
        users.updated_at,
        roles.name AS role_name,
        roles.key AS role_key,
        stores.name AS store_name
      FROM users
      INNER JOIN roles ON roles.id = users.role_id
      LEFT JOIN stores ON stores.id = users.store_id
      WHERE users.company_id = ?
        AND users.deleted_at IS NULL
      ORDER BY users.first_name, users.last_name
      ''',
      positionalParams: [_authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Users retrieved successfully',
    ));
  }

  Future<Response> show() async {
    final user = await _findUser(req.params['id']);
    if (user == null) {
      return _notFound();
    }

    return res.json(ApiResponse.success(
      data: user,
      message: 'User retrieved successfully',
    ));
  }

  Future<Response> create() async {
    Map<String, dynamic> body;
    try {
      body = await req.validate({
        'role_id': 'required',
        'first_name': 'required|string',
        'last_name': 'required|string',
        'email': 'required|email',
        'username': 'required|string',
        'password': 'required|string',
      });
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }

    final duplicate = await _first(
      '''
      SELECT id FROM users
      WHERE company_id = ?
        AND deleted_at IS NULL
        AND (email = ? OR username = ?)
      LIMIT 1
      ''',
      [_authContext['company_id'], body['email'], body['username']],
    );
    if (duplicate != null) {
      return res.status(409).json(ApiResponse.error(
            code: 'CONFLICT',
            message: 'A user with this email or username already exists.',
          ));
    }

    final role = await _findRole(body['role_id']);
    if (role == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'role_id is invalid.',
          ));
    }

    final storeId = body['store_id'];
    if (role['scope'] == 'store') {
      if (storeId == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'store_id is required for store-scoped roles.',
            ));
      }
      final store = await _findStore(storeId);
      if (store == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'store_id is invalid.',
            ));
      }
    }

    await DB.query(
      '''
      INSERT INTO users
        (id, company_id, store_id, role_id, first_name, last_name, email, phone,
         username, password_hash, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _authContext['company_id'],
        storeId,
        body['role_id'],
        body['first_name'],
        body['last_name'],
        body['email'],
        body['phone'],
        body['username'],
        Hashing().hash(body['password']),
        body['status'] ?? 'active',
      ],
    );

    final user = await _first(
      '''
      SELECT id FROM users
      WHERE company_id = ? AND email = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [_authContext['company_id'], body['email']],
    );

    return res.status(201).json(ApiResponse.success(
          data: await _findUser(user!['id']),
          message: 'User created successfully',
        ));
  }

  Future<Response> update() async {
    final userId = req.params['id'];
    final existing = await _findUser(userId);
    if (existing == null) {
      return _notFound();
    }

    final body = await req.json();
    final validationError = await _validateUpdateBody(body);
    if (validationError != null) return validationError;

    const allowedFields = {
      'store_id',
      'role_id',
      'first_name',
      'last_name',
      'email',
      'phone',
      'username',
      'status',
    };
    final updateData = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) {
        updateData[entry.key] = entry.value;
      }
    }
    final password = body['password']?.toString();
    if (password != null && password.isNotEmpty) {
      updateData['password_hash'] = Hashing().hash(password);
    }

    if (updateData.isNotEmpty) {
      final setClause = updateData.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE users
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND company_id = ?
        ''',
        positionalParams: [
          ...updateData.values,
          userId,
          _authContext['company_id'],
        ],
      );
    }

    return res.json(ApiResponse.success(
      data: await _findUser(userId),
      message: 'User updated successfully',
    ));
  }

  Future<Response> delete() async {
    final userId = req.params['id'];
    final existing = await _findUser(userId);
    if (existing == null) {
      return _notFound();
    }

    await DB.query(
      '''
      UPDATE users
      SET status = ?, deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['inactive', userId, _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      message: 'User deactivated successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Response?> _validateUpdateBody(Map<String, dynamic> body) async {
    final status = body['status']?.toString();
    if (status != null && !{'active', 'inactive'}.contains(status)) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'status must be active or inactive.',
          ));
    }

    if (body['email'] != null || body['username'] != null) {
      final duplicate = await _first(
        '''
        SELECT id FROM users
        WHERE company_id = ?
          AND id <> ?
          AND deleted_at IS NULL
          AND (email = ? OR username = ?)
        LIMIT 1
        ''',
        [
          _authContext['company_id'],
          req.params['id'],
          body['email'],
          body['username'],
        ],
      );
      if (duplicate != null) {
        return res.status(409).json(ApiResponse.error(
              code: 'CONFLICT',
              message: 'A user with this email or username already exists.',
            ));
      }
    }

    if (body['role_id'] != null) {
      final role = await _findRole(body['role_id']);
      if (role == null) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'role_id is invalid.',
            ));
      }
      if (role['scope'] == 'store' && body['store_id'] == null) {
        final existing = await _findUser(req.params['id']);
        if (existing?['store_id'] == null) {
          return res.status(422).json(ApiResponse.error(
                code: 'VALIDATION_ERROR',
                message: 'store_id is required for store-scoped roles.',
              ));
        }
      }
    }

    if (body['store_id'] != null &&
        await _findStore(body['store_id']) == null) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'store_id is invalid.',
          ));
    }

    return Future<Response?>.value();
  }

  Future<Map<String, dynamic>?> _findUser(Object? id) {
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
        users.phone,
        users.username,
        users.status,
        users.last_login_at,
        users.created_at,
        users.updated_at,
        roles.name AS role_name,
        roles.key AS role_key,
        roles.scope AS role_scope,
        stores.name AS store_name
      FROM users
      INNER JOIN roles ON roles.id = users.role_id
      LEFT JOIN stores ON stores.id = users.store_id
      WHERE users.id = ?
        AND users.company_id = ?
        AND users.deleted_at IS NULL
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<Map<String, dynamic>?> _findRole(Object? id) {
    return _first(
      '''
      SELECT * FROM roles
      WHERE id = ?
        AND (company_id = ? OR company_id IS NULL)
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
          message: 'User not found',
        ));
  }
}
