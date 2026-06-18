import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

class InventoryHqIdentitySeeder extends Seeder {
  static const _companyName = 'InventoryHQ Demo Company';
  static const _adminEmail = 'admin@inventoryhq.local';
  static const _adminPassword = 'Admin12345';

  @override
  Future<void> run() async {
    final companyId = await _ensureCompany();
    final storeIds = await _ensureStores(companyId);
    final roleIds = await _ensureRoles(companyId);
    final permissionIds = await _ensurePermissions();
    await _ensureRolePermissions(roleIds, permissionIds);
    await _ensureAdminUser(companyId, storeIds['main_store']!, roleIds);

    Log.debug(
      'Seeded InventoryHQ identity data. Admin: $_adminEmail / $_adminPassword',
    );
  }

  Future<String> _ensureCompany() async {
    final existing = await _first(
      'SELECT id FROM companies WHERE name = ? LIMIT 1',
      [_companyName],
    );
    if (existing != null) return _asString(existing['id']);

    await DB.query(
      '''
      INSERT INTO companies
        (id, name, legal_name, email, phone, address, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        _companyName,
        _companyName,
        'hello@inventoryhq.local',
        '+2340000000000',
        'Head Office',
        'active',
      ],
    );

    final created = await _first(
      'SELECT id FROM companies WHERE name = ? LIMIT 1',
      [_companyName],
    );
    return _asString(created!['id']);
  }

  Future<Map<String, String>> _ensureStores(String companyId) async {
    final stores = {
      'main_store': ('Main Store', 'MAIN', 'main'),
      'warehouse': ('Warehouse', 'WH', 'warehouse'),
      'branch_a': ('Branch A', 'BRA', 'branch'),
      'branch_b': ('Branch B', 'BRB', 'branch'),
    };

    final ids = <String, String>{};
    for (final entry in stores.entries) {
      final (name, code, type) = entry.value;
      final existing = await _first(
        'SELECT id FROM stores WHERE company_id = ? AND code = ? LIMIT 1',
        [companyId, code],
      );
      if (existing != null) {
        ids[entry.key] = _asString(existing['id']);
        continue;
      }

      await DB.query(
        '''
        INSERT INTO stores
          (id, company_id, name, code, type, phone, email, address, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          companyId,
          name,
          code,
          type,
          '+2340000000000',
          '${code.toLowerCase()}@inventoryhq.local',
          name,
          'active',
        ],
      );

      final created = await _first(
        'SELECT id FROM stores WHERE company_id = ? AND code = ? LIMIT 1',
        [companyId, code],
      );
      ids[entry.key] = _asString(created!['id']);
    }

    return ids;
  }

  Future<Map<String, String>> _ensureRoles(String companyId) async {
    final roles = {
      'company_admin': ('Company Admin', 'company'),
      'store_manager': ('Store Manager', 'store'),
      'sales_staff': ('Sales Staff', 'store'),
      'inventory_officer': ('Inventory Officer', 'store'),
      'auditor': ('Auditor', 'company'),
    };

    final ids = <String, String>{};
    for (final entry in roles.entries) {
      final (name, scope) = entry.value;
      final existing = await _first(
        'SELECT id FROM roles WHERE company_id = ? AND `key` = ? LIMIT 1',
        [companyId, entry.key],
      );
      if (existing != null) {
        ids[entry.key] = _asString(existing['id']);
        continue;
      }

      await DB.query(
        '''
        INSERT INTO roles
          (id, company_id, name, `key`, scope, description, is_system, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          companyId,
          name,
          entry.key,
          scope,
          '$name system role',
          true,
        ],
      );

      final created = await _first(
        'SELECT id FROM roles WHERE company_id = ? AND `key` = ? LIMIT 1',
        [companyId, entry.key],
      );
      ids[entry.key] = _asString(created!['id']);
    }

    return ids;
  }

  Future<Map<String, String>> _ensurePermissions() async {
    const permissions = {
      'stores.view_all': ('stores', 'view_all'),
      'stores.create': ('stores', 'create'),
      'stores.update': ('stores', 'update'),
      'company.update': ('company', 'update'),
      'users.manage_all': ('users', 'manage_all'),
      'users.manage_store': ('users', 'manage_store'),
      'products.view': ('products', 'view'),
      'products.create': ('products', 'create'),
      'products.update': ('products', 'update'),
      'inventory.view': ('inventory', 'view'),
      'inventory.stock_in': ('inventory', 'stock_in'),
      'inventory.stock_out': ('inventory', 'stock_out'),
      'inventory.adjust': ('inventory', 'adjust'),
      'inventory.transfer': ('inventory', 'transfer'),
      'sales.view': ('sales', 'view'),
      'sales.create': ('sales', 'create'),
      'sales.refund': ('sales', 'refund'),
      'credit.request': ('credit', 'request'),
      'credit.manager_approve': ('credit', 'manager_approve'),
      'credit.admin_approve': ('credit', 'admin_approve'),
      'customers.view': ('customers', 'view'),
      'customers.manage': ('customers', 'manage'),
      'suppliers.view': ('suppliers', 'view'),
      'suppliers.manage': ('suppliers', 'manage'),
      'reports.view_company': ('reports', 'view_company'),
      'reports.view_store': ('reports', 'view_store'),
      'reports.export': ('reports', 'export'),
      'audit.view': ('audit', 'view'),
    };

    final ids = <String, String>{};
    for (final entry in permissions.entries) {
      final existing = await _first(
        'SELECT id FROM permissions WHERE `key` = ? LIMIT 1',
        [entry.key],
      );
      if (existing != null) {
        ids[entry.key] = _asString(existing['id']);
        continue;
      }

      final (module, action) = entry.value;
      await DB.query(
        '''
        INSERT INTO permissions
          (id, `key`, module, action, description, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          entry.key,
          module,
          action,
          '${entry.key} permission',
        ],
      );

      final created = await _first(
        'SELECT id FROM permissions WHERE `key` = ? LIMIT 1',
        [entry.key],
      );
      ids[entry.key] = _asString(created!['id']);
    }

    return ids;
  }

  Future<void> _ensureRolePermissions(
    Map<String, String> roleIds,
    Map<String, String> permissionIds,
  ) async {
    final rolePermissions = {
      'company_admin': permissionIds.keys.toSet(),
      'store_manager': {
        'users.manage_store',
        'products.view',
        'products.create',
        'products.update',
        'inventory.view',
        'inventory.stock_in',
        'inventory.stock_out',
        'inventory.adjust',
        'inventory.transfer',
        'sales.view',
        'sales.create',
        'sales.refund',
        'credit.request',
        'credit.manager_approve',
        'customers.view',
        'customers.manage',
        'suppliers.view',
        'suppliers.manage',
        'reports.view_store',
        'reports.export',
        'audit.view',
      },
      'sales_staff': {
        'products.view',
        'sales.view',
        'sales.create',
        'credit.request',
        'customers.view',
        'customers.manage',
      },
      'inventory_officer': {
        'products.view',
        'products.create',
        'products.update',
        'inventory.view',
        'inventory.stock_in',
        'inventory.stock_out',
        'inventory.adjust',
        'inventory.transfer',
        'suppliers.view',
        'suppliers.manage',
      },
      'auditor': {
        'stores.view_all',
        'products.view',
        'inventory.view',
        'sales.view',
        'customers.view',
        'suppliers.view',
        'reports.view_company',
        'reports.view_store',
        'reports.export',
        'audit.view',
      },
    };

    for (final entry in rolePermissions.entries) {
      final roleId = roleIds[entry.key]!;
      for (final permissionKey in entry.value) {
        final permissionId = permissionIds[permissionKey]!;
        final existing = await _first(
          '''
          SELECT id FROM role_permissions
          WHERE role_id = ? AND permission_id = ?
          LIMIT 1
          ''',
          [roleId, permissionId],
        );
        if (existing != null) continue;

        await DB.query(
          '''
          INSERT INTO role_permissions
            (id, role_id, permission_id, created_at)
          VALUES (?, ?, ?, CURRENT_TIMESTAMP)
          ''',
          positionalParams: [Str.uuid(), roleId, permissionId],
        );
      }
    }
  }

  Future<void> _ensureAdminUser(
    String companyId,
    String storeId,
    Map<String, String> roleIds,
  ) async {
    final existing = await _first(
      'SELECT id FROM users WHERE company_id = ? AND email = ? LIMIT 1',
      [companyId, _adminEmail],
    );
    if (existing != null) return;

    await DB.query(
      '''
      INSERT INTO users
        (id, company_id, store_id, role_id, first_name, last_name, email, phone,
         username, password_hash, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        companyId,
        storeId,
        roleIds['company_admin'],
        'Company',
        'Admin',
        _adminEmail,
        '+2340000000000',
        'admin',
        Hashing().hash(_adminPassword),
        'active',
      ],
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

  String _asString(Object? value) => value.toString();
}
