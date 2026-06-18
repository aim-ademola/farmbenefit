import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';

class AuditController extends Controller {
  Future<Response> index() async {
    final action = req.queryParam('action');
    final entityType = req.queryParam('entity_type');
    final userId = req.queryParam('user_id');

    final where = ['audit_logs.company_id = ?'];
    final params = <dynamic>[_authContext['company_id']];

    if (_authContext['role_scope'] == 'store') {
      where.add('(audit_logs.store_id = ? OR audit_logs.store_id IS NULL)');
      params.add(_authContext['store_id']);
    } else {
      final storeId = req.queryParam('store_id');
      if (storeId != null && storeId.isNotEmpty) {
        where.add('audit_logs.store_id = ?');
        params.add(storeId);
      }
    }

    if (action != null && action.isNotEmpty) {
      where.add('audit_logs.action = ?');
      params.add(action);
    }
    if (entityType != null && entityType.isNotEmpty) {
      where.add('audit_logs.entity_type = ?');
      params.add(entityType);
    }
    if (userId != null && userId.isNotEmpty) {
      where.add('audit_logs.user_id = ?');
      params.add(userId);
    }

    final rows = await DB.query(
      '''
      SELECT
        audit_logs.*,
        users.email AS user_email,
        stores.name AS store_name
      FROM audit_logs
      LEFT JOIN users ON users.id = audit_logs.user_id
      LEFT JOIN stores ON stores.id = audit_logs.store_id
      WHERE ${where.join(' AND ')}
      ORDER BY audit_logs.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Audit logs retrieved successfully',
    ));
  }

  Future<Response> show() async {
    final row = await _first(
      '''
      SELECT
        audit_logs.*,
        users.email AS user_email,
        stores.name AS store_name
      FROM audit_logs
      LEFT JOIN users ON users.id = audit_logs.user_id
      LEFT JOIN stores ON stores.id = audit_logs.store_id
      WHERE audit_logs.id = ?
        AND audit_logs.company_id = ?
      LIMIT 1
      ''',
      [req.params['id'], _authContext['company_id']],
    );

    if (row == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Audit log not found.',
          ));
    }

    return res.json(ApiResponse.success(
      data: row,
      message: 'Audit log retrieved successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Map<String, dynamic>?> _first(String sql, List<dynamic> params) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }
}
