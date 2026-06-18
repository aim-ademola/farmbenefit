import 'package:flint_dart/auth.dart';
import 'package:flint_dart/db.dart';

class AuthContextService {
  Future<Map<String, dynamic>?> fromBearerToken(String? token) async {
    if (token == null || token.isEmpty) return null;

    final payload = Auth.verifyToken(token);
    if (payload == null) return null;

    final userId = payload['id'];
    if (userId == null) return null;

    return fromUserId(userId);
  }

  Future<Map<String, dynamic>?> fromUserId(Object userId) async {
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
        roles.name AS role_name,
        roles.key AS role_key,
        roles.scope AS role_scope
      FROM users
      INNER JOIN roles ON roles.id = users.role_id
      WHERE users.id = ?
        AND users.deleted_at IS NULL
      LIMIT 1
      ''',
      positionalParams: [userId],
    );

    if (rows.isEmpty) return null;
    final user = Map<String, dynamic>.from(rows.first);
    if (user['status'] != 'active') return null;

    final permissions = await permissionsForRole(user['role_id']);

    return {
      'user': user,
      'permissions': permissions,
      'company_id': user['company_id'],
      'store_id': user['store_id'],
      'role_key': user['role_key'],
      'role_scope': user['role_scope'],
    };
  }

  Future<List<String>> permissionsForRole(Object roleId) async {
    final rows = await DB.query(
      '''
      SELECT permissions.key
      FROM role_permissions
      INNER JOIN permissions ON permissions.id = role_permissions.permission_id
      WHERE role_permissions.role_id = ?
      ORDER BY permissions.key
      ''',
      positionalParams: [roleId],
    );

    return rows.map((row) => row['key'].toString()).toList();
  }

  Future<bool> hasPermission(Object roleId, String permission) async {
    final permissions = await permissionsForRole(roleId);
    return permissions.contains(permission);
  }
}
