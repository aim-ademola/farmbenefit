import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class PayrollController extends Controller {
  Future<Response> upsertUserCompensation() async {
    final user = await _findUser(req.params['id']);
    if (user == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'User not found.',
          ));
    }

    final body = await req.json();
    final monthlySalary = _asDouble(body['monthly_salary']);
    if (monthlySalary <= 0) {
      return _invalid('monthly_salary must be greater than zero.');
    }

    final storeId = await _resolveStoreId(body['store_id'] ?? user['store_id']);
    if (storeId is Response) return storeId;
    final existing = await _findCompensationByUser(user['id']);
    if (existing == null) {
      await DB.query(
        '''
        INSERT INTO staff_compensations
          (id, company_id, store_id, user_id, monthly_salary, currency, status,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          _authContext['company_id'],
          storeId,
          user['id'],
          monthlySalary,
          body['currency']?.toString() ?? 'NGN',
          body['status']?.toString() ?? 'active',
        ],
      );
    } else {
      await _updateCompensationRow(
        compensation: existing,
        monthlySalary: monthlySalary,
        currency: body['currency']?.toString(),
        status: body['status']?.toString(),
      );
    }

    return res.json(ApiResponse.success(
      data: await _findCompensationByUser(user['id']),
      message: 'Staff salary saved successfully',
    ));
  }

  Future<Response> updateCompensation() async {
    final compensation = await _findCompensation(req.params['id']);
    if (compensation == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Compensation record not found.',
          ));
    }

    final body = await req.json();
    final monthlySalary = _asDouble(body['monthly_salary']);
    if (monthlySalary <= 0) {
      return _invalid('monthly_salary must be greater than zero.');
    }

    final response = await _updateCompensationRow(
      compensation: compensation,
      monthlySalary: monthlySalary,
      currency: body['currency']?.toString(),
      status: body['status']?.toString(),
    );
    if (response != null) return response;

    return res.json(ApiResponse.success(
      data: await _findCompensation(compensation['id']),
      message: 'Staff salary updated successfully',
    ));
  }

  Future<Response?> _updateCompensationRow({
    required Map<String, dynamic> compensation,
    required double monthlySalary,
    String? currency,
    String? status,
  }) async {
    final resolvedStatus =
        status ?? compensation['status']?.toString() ?? 'active';
    if (!{'active', 'inactive'}.contains(resolvedStatus)) {
      return _invalid('status must be active or inactive.');
    }

    await DB.query(
      '''
      UPDATE staff_compensations
      SET monthly_salary = ?, currency = ?, status = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [
        monthlySalary,
        currency ?? compensation['currency'] ?? 'NGN',
        resolvedStatus,
        compensation['id'],
        _authContext['company_id'],
      ],
    );
    return null;
  }

  Future<Map<String, dynamic>?> _findCompensation(Object? id) async {
    final where = [
      'staff_compensations.id = ?',
      'staff_compensations.company_id = ?',
    ];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('staff_compensations.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final rows = await DB.query(
      '''
      SELECT
        staff_compensations.*,
        CONCAT(users.first_name, ' ', users.last_name) AS employee_name,
        users.email AS employee_email,
        stores.name AS store_name
      FROM staff_compensations
      INNER JOIN users ON users.id = staff_compensations.user_id
      INNER JOIN stores ON stores.id = staff_compensations.store_id
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      positionalParams: params,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>?> _findCompensationByUser(Object? userId) async {
    final where = [
      'staff_compensations.user_id = ?',
      'staff_compensations.company_id = ?',
    ];
    final params = <dynamic>[userId, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('staff_compensations.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final rows = await DB.query(
      '''
      SELECT * FROM staff_compensations
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      positionalParams: params,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>?> _findUser(Object? id) async {
    final where = [
      'users.id = ?',
      'users.company_id = ?',
      'users.deleted_at IS NULL',
    ];
    final params = <dynamic>[id, _authContext['company_id']];
    if (_authContext['role_scope'] == 'store') {
      where.add('users.store_id = ?');
      params.add(_authContext['store_id']);
    }

    final rows = await DB.query(
      '''
      SELECT * FROM users
      WHERE ${where.join(' AND ')}
      LIMIT 1
      ''',
      positionalParams: params,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Object> _resolveStoreId(Object? requestedStoreId) async {
    final storeId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : requestedStoreId;
    if (storeId != null) return storeId;

    final rows = await DB.query(
      '''
      SELECT id FROM stores
      WHERE company_id = ? AND deleted_at IS NULL
      ORDER BY created_at ASC
      LIMIT 1
      ''',
      positionalParams: [_authContext['company_id']],
    );
    if (rows.isEmpty) return _invalid('store_id is required.');
    return Map<String, dynamic>.from(rows.first as Map)['id'];
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Response> _invalid(String message) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: message,
        ));
  }
}
