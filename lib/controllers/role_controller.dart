import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class RoleController extends Controller {
  Future<Response> index() async {
    final rows = await DB.query(
      '''
      SELECT roles.*
      FROM roles
      WHERE roles.company_id = ?
         OR roles.company_id IS NULL
      ORDER BY roles.is_system DESC, roles.name
      ''',
      positionalParams: [_authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Roles retrieved successfully',
    ));
  }

  Future<Response> create() async {
    try {
      final body = await req.validate({
        'name': 'required|string',
        'key': 'required|string',
        'scope': 'required|string',
      });

      final scope = body['scope'].toString();
      if (!{'company', 'store'}.contains(scope)) {
        return res.status(422).json(ApiResponse.error(
              code: 'VALIDATION_ERROR',
              message: 'scope must be company or store.',
            ));
      }

      final duplicate = await _first(
        '''
        SELECT id FROM roles
        WHERE company_id = ? AND `key` = ?
        LIMIT 1
        ''',
        [_authContext['company_id'], body['key']],
      );
      if (duplicate != null) {
        return res.status(409).json(ApiResponse.error(
              code: 'CONFLICT',
              message: 'A role with this key already exists.',
            ));
      }

      await DB.query(
        '''
        INSERT INTO roles
          (id, company_id, name, `key`, scope, description, is_system,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          _authContext['company_id'],
          body['name'],
          body['key'],
          scope,
          body['description'],
          false,
        ],
      );

      final role = await _first(
        '''
        SELECT * FROM roles
        WHERE company_id = ? AND `key` = ?
        LIMIT 1
        ''',
        [_authContext['company_id'], body['key']],
      );

      return res.status(201).json(ApiResponse.success(
            data: role,
            message: 'Role created successfully',
          ));
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }
  }

  Future<Response> permissions() async {
    final rows = await DB.query(
      '''
      SELECT *
      FROM permissions
      ORDER BY module, action
      ''',
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Permissions retrieved successfully',
    ));
  }

  Future<Response> replacePermissions() async {
    final roleId = req.params['id'];
    final role = await _findRole(roleId);
    if (role == null) {
      return res.status(404).json(ApiResponse.error(
        code: 'NOT_FOUND',
        message: 'Role not found.',
      ));
    }

    if (role['is_system'] == true || role['is_system'] == 1) {
      return res.status(422).json(ApiResponse.error(
        code: 'VALIDATION_ERROR',
        message: 'System role permissions cannot be replaced.',
      ));
    }

    Map<String, dynamic> body;
    try {
      body = await req.validate({'permissions': 'required'});
    } on ValidationException catch (e) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: e.errors,
          ));
    }

    final permissionKeys = body['permissions'];
    if (permissionKeys is! List) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'permissions must be an array of keys.',
          ));
    }

    await DB.query(
      'DELETE FROM role_permissions WHERE role_id = ?',
      positionalParams: [roleId],
    );

    if (permissionKeys.isEmpty) {
      return res.json(ApiResponse.success(
        data: [],
        message: 'Role permissions updated successfully',
      ));
    }

    final permissionRows = await DB.query(
      '''
      SELECT id, `key`
      FROM permissions
      WHERE `key` IN (${List.filled(permissionKeys.length, '?').join(', ')})
      ''',
      positionalParams: permissionKeys,
    );

    if (permissionRows.length != permissionKeys.length) {
      return res.status(422).json(ApiResponse.error(
            code: 'VALIDATION_ERROR',
            message: 'One or more permissions are invalid.',
          ));
    }

    for (final permission in permissionRows) {
      await DB.query(
        '''
        INSERT INTO role_permissions (id, role_id, permission_id, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [Str.uuid(), roleId, permission['id']],
      );
    }

    return res.json(ApiResponse.success(
      data: await _rolePermissions(roleId),
      message: 'Role permissions updated successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Map<String, dynamic>?> _findRole(Object? id) {
    return _first(
      '''
      SELECT * FROM roles
      WHERE id = ?
        AND company_id = ?
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
  }

  Future<List<Map<String, dynamic>>> _rolePermissions(Object? roleId) {
    return DB.query(
      '''
      SELECT permissions.*
      FROM role_permissions
      INNER JOIN permissions ON permissions.id = role_permissions.permission_id
      WHERE role_permissions.role_id = ?
      ORDER BY permissions.module, permissions.action
      ''',
      positionalParams: [roleId],
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

}
