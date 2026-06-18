import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

class FarmFeedDemoSeeder extends Seeder {
  static const _companyName = 'Green Pastures Feed Farm';
  static const _salary = 80000;
  static const _password = 'Feed12345';

  @override
  Future<void> run() async {
    final companyId = await _ensureCompany();
    final roleIds = await _ensureRoles(companyId);
    final permissionIds = await _ensurePermissions();
    await _ensureRolePermissions(roleIds, permissionIds);
    final storeIds = await _ensureStores(companyId);
    final staffIds = await _ensureStaff(companyId, storeIds, roleIds);
    await _ensureStaffCompensation(companyId, staffIds);
    final categoryId = await _ensureCategory(companyId);
    final productIds = await _ensureProducts(companyId, categoryId);
    await _ensureOpeningStock(companyId, storeIds, productIds, staffIds);

    Log.debug(
      'Seeded farm feed demo data. Staff password: $_password. Salary: NGN $_salary monthly.',
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
        'Green Pastures Feed Farm Limited',
        'hello@greenpastures.local',
        '+2348011100000',
        'Km 8 Farm Road, Abeokuta, Ogun State',
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
    const stores = {
      'farm_gate': (
        'Farm Gate Feed Store',
        'FGFS',
        'main',
        '+2348011100001',
        'farmgate@greenpastures.local',
        'Farm Gate, Km 8 Farm Road, Abeokuta'
      ),
      'town_depot': (
        'Town Depot Feed Store',
        'TDFS',
        'branch',
        '+2348011100002',
        'towndepot@greenpastures.local',
        'Market Road, Ibara, Abeokuta'
      ),
    };

    final ids = <String, String>{};
    for (final entry in stores.entries) {
      final (name, code, type, phone, email, address) = entry.value;
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
          phone,
          email,
          address,
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
    const roles = {
      'company_admin': ('Company Admin', 'company'),
      'store_manager': ('Store Manager', 'store'),
      'sales_staff': ('Sales Staff', 'store'),
      'inventory_officer': ('Inventory Officer', 'store'),
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
          '$name role for feed farm demo',
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

  Future<Map<String, Map<String, String>>> _ensureStaff(
    String companyId,
    Map<String, String> storeIds,
    Map<String, String> roleIds,
  ) async {
    final staff = <({
      String store,
      String role,
      String first,
      String last,
      String phone
    })>[
      (
        store: 'farm_gate',
        role: 'company_admin',
        first: 'Farm',
        last: 'Admin',
        phone: '+2348011100100'
      ),
      (
        store: 'farm_gate',
        role: 'store_manager',
        first: 'Grace',
        last: 'Adebayo',
        phone: '+2348011100101'
      ),
      (
        store: 'farm_gate',
        role: 'sales_staff',
        first: 'Musa',
        last: 'Bello',
        phone: '+2348011100102'
      ),
      (
        store: 'farm_gate',
        role: 'sales_staff',
        first: 'Ife',
        last: 'Okafor',
        phone: '+2348011100103'
      ),
      (
        store: 'farm_gate',
        role: 'inventory_officer',
        first: 'Daniel',
        last: 'Eze',
        phone: '+2348011100104'
      ),
      (
        store: 'town_depot',
        role: 'store_manager',
        first: 'Aminat',
        last: 'Lawal',
        phone: '+2348011100201'
      ),
      (
        store: 'town_depot',
        role: 'sales_staff',
        first: 'Peter',
        last: 'Nwankwo',
        phone: '+2348011100202'
      ),
      (
        store: 'town_depot',
        role: 'sales_staff',
        first: 'Ruth',
        last: 'Johnson',
        phone: '+2348011100203'
      ),
      (
        store: 'town_depot',
        role: 'inventory_officer',
        first: 'Tunde',
        last: 'Ojo',
        phone: '+2348011100204'
      ),
    ];

    final ids = <String, Map<String, String>>{};
    for (final person in staff) {
      final username =
          '${person.first}.${person.last}'.toLowerCase().replaceAll(' ', '');
      final email = '$username@greenpastures.local';
      final storeId =
          person.role == 'company_admin' ? null : storeIds[person.store];
      final existing = await _first(
        'SELECT id FROM users WHERE company_id = ? AND email = ? LIMIT 1',
        [companyId, email],
      );
      String userId;
      if (existing != null) {
        userId = _asString(existing['id']);
      } else {
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
            roleIds[person.role],
            person.first,
            person.last,
            email,
            person.phone,
            username,
            Hashing().hash(_password),
            'active',
          ],
        );
        final created = await _first(
          'SELECT id FROM users WHERE company_id = ? AND email = ? LIMIT 1',
          [companyId, email],
        );
        userId = _asString(created!['id']);
      }

      ids[email] = {
        'id': userId,
        'store_id': storeIds[person.store]!,
        'role': person.role,
      };
    }

    await _assignStoreManagers(companyId, ids);
    return ids;
  }

  Future<void> _assignStoreManagers(
    String companyId,
    Map<String, Map<String, String>> staffIds,
  ) async {
    for (final staff
        in staffIds.values.where((staff) => staff['role'] == 'store_manager')) {
      await DB.query(
        '''
        UPDATE stores
        SET manager_user_id = ?, updated_at = CURRENT_TIMESTAMP
        WHERE company_id = ? AND id = ?
        ''',
        positionalParams: [staff['id'], companyId, staff['store_id']],
      );
    }
  }

  Future<void> _ensureStaffCompensation(
    String companyId,
    Map<String, Map<String, String>> staffIds,
  ) async {
    for (final staff in staffIds.values) {
      final existing = await _first(
        '''
        SELECT id FROM staff_compensations
        WHERE company_id = ? AND user_id = ?
        LIMIT 1
        ''',
        [companyId, staff['id']],
      );
      if (existing != null) {
        await DB.query(
          '''
          UPDATE staff_compensations
          SET monthly_salary = ?, currency = ?, status = ?, updated_at = CURRENT_TIMESTAMP
          WHERE company_id = ? AND user_id = ?
          ''',
          positionalParams: [
            _salary,
            'NGN',
            'active',
            companyId,
            staff['id'],
          ],
        );
        continue;
      }

      await DB.query(
        '''
        INSERT INTO staff_compensations
          (id, company_id, store_id, user_id, monthly_salary, currency, status,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          companyId,
          staff['store_id'],
          staff['id'],
          _salary,
          'NGN',
          'active',
        ],
      );
    }
  }

  Future<String> _ensureCategory(String companyId) async {
    final existing = await _first(
      'SELECT id FROM categories WHERE company_id = ? AND name = ? LIMIT 1',
      [companyId, 'Animal Feeds'],
    );
    if (existing != null) return _asString(existing['id']);

    await DB.query(
      '''
      INSERT INTO categories
        (id, company_id, name, description, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        companyId,
        'Animal Feeds',
        'Finished feeds for poultry, fish, pigs, goats, and cattle.',
        'active',
      ],
    );

    final created = await _first(
      'SELECT id FROM categories WHERE company_id = ? AND name = ? LIMIT 1',
      [companyId, 'Animal Feeds'],
    );
    return _asString(created!['id']);
  }

  Future<Map<String, String>> _ensureProducts(
    String companyId,
    String categoryId,
  ) async {
    const products = {
      'GPF-BROILER-STARTER-25KG': (
        'Broiler Starter Feed 25kg',
        'Protein-rich starter feed for broiler chicks.',
        'Green Pastures',
        'bag',
        11800,
        14500,
        25
      ),
      'GPF-BROILER-FINISHER-25KG': (
        'Broiler Finisher Feed 25kg',
        'Finisher ration for fast broiler weight gain.',
        'Green Pastures',
        'bag',
        11200,
        13900,
        30
      ),
      'GPF-LAYER-MASH-25KG': (
        'Layer Mash Feed 25kg',
        'Balanced mash for egg-laying birds.',
        'Green Pastures',
        'bag',
        10800,
        13500,
        35
      ),
      'GPF-FISH-FLOATING-15KG': (
        'Floating Fish Feed 15kg',
        'Floating pellets for catfish and tilapia.',
        'AquaGrow',
        'bag',
        14500,
        18000,
        20
      ),
      'GPF-PIG-GROWER-25KG': (
        'Pig Grower Feed 25kg',
        'Grower ration for healthy pig development.',
        'Green Pastures',
        'bag',
        9800,
        12500,
        20
      ),
      'GPF-CATTLE-MEAL-40KG': (
        'Cattle Fattening Meal 40kg',
        'Energy feed for cattle finishing.',
        'PastureMax',
        'bag',
        13200,
        16500,
        15
      ),
    };

    final ids = <String, String>{};
    for (final entry in products.entries) {
      final (name, description, brand, unit, cost, selling, reorder) =
          entry.value;
      final existing = await _first(
        'SELECT id FROM products WHERE company_id = ? AND sku = ? LIMIT 1',
        [companyId, entry.key],
      );
      if (existing != null) {
        ids[entry.key] = _asString(existing['id']);
        continue;
      }

      await DB.query(
        '''
        INSERT INTO products
          (id, company_id, category_id, sku, barcode, name, description, brand,
           unit, cost_price, selling_price, reorder_level, has_variants, status,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          companyId,
          categoryId,
          entry.key,
          entry.key.replaceAll('-', ''),
          name,
          description,
          brand,
          unit,
          cost,
          selling,
          reorder,
          false,
          'active',
        ],
      );

      final created = await _first(
        'SELECT id FROM products WHERE company_id = ? AND sku = ? LIMIT 1',
        [companyId, entry.key],
      );
      ids[entry.key] = _asString(created!['id']);
    }
    return ids;
  }

  Future<void> _ensureOpeningStock(
    String companyId,
    Map<String, String> storeIds,
    Map<String, String> productIds,
    Map<String, Map<String, String>> staffIds,
  ) async {
    final inventoryOfficerByStore = <String, String>{};
    for (final staff in staffIds.values) {
      if (staff['role'] == 'inventory_officer') {
        inventoryOfficerByStore[staff['store_id']!] = staff['id']!;
      }
    }

    final stock =
        <({String store, String sku, double qty, double cost, double reorder})>[
      (
        store: 'farm_gate',
        sku: 'GPF-BROILER-STARTER-25KG',
        qty: 180,
        cost: 11800,
        reorder: 25
      ),
      (
        store: 'farm_gate',
        sku: 'GPF-BROILER-FINISHER-25KG',
        qty: 160,
        cost: 11200,
        reorder: 30
      ),
      (
        store: 'farm_gate',
        sku: 'GPF-LAYER-MASH-25KG',
        qty: 220,
        cost: 10800,
        reorder: 35
      ),
      (
        store: 'farm_gate',
        sku: 'GPF-FISH-FLOATING-15KG',
        qty: 90,
        cost: 14500,
        reorder: 20
      ),
      (
        store: 'farm_gate',
        sku: 'GPF-PIG-GROWER-25KG',
        qty: 75,
        cost: 9800,
        reorder: 20
      ),
      (
        store: 'farm_gate',
        sku: 'GPF-CATTLE-MEAL-40KG',
        qty: 60,
        cost: 13200,
        reorder: 15
      ),
      (
        store: 'town_depot',
        sku: 'GPF-BROILER-STARTER-25KG',
        qty: 120,
        cost: 11800,
        reorder: 25
      ),
      (
        store: 'town_depot',
        sku: 'GPF-BROILER-FINISHER-25KG',
        qty: 110,
        cost: 11200,
        reorder: 30
      ),
      (
        store: 'town_depot',
        sku: 'GPF-LAYER-MASH-25KG',
        qty: 150,
        cost: 10800,
        reorder: 35
      ),
      (
        store: 'town_depot',
        sku: 'GPF-FISH-FLOATING-15KG',
        qty: 70,
        cost: 14500,
        reorder: 20
      ),
      (
        store: 'town_depot',
        sku: 'GPF-PIG-GROWER-25KG',
        qty: 55,
        cost: 9800,
        reorder: 20
      ),
      (
        store: 'town_depot',
        sku: 'GPF-CATTLE-MEAL-40KG',
        qty: 40,
        cost: 13200,
        reorder: 15
      ),
    ];

    for (final item in stock) {
      final storeId = storeIds[item.store]!;
      final productId = productIds[item.sku]!;
      final existing = await _first(
        '''
        SELECT id FROM inventory
        WHERE company_id = ?
          AND store_id = ?
          AND product_id = ?
          AND product_variant_id IS NULL
        LIMIT 1
        ''',
        [companyId, storeId, productId],
      );

      if (existing == null) {
        await DB.query(
          '''
          INSERT INTO inventory
            (id, company_id, store_id, product_id, product_variant_id,
             quantity_on_hand, quantity_reserved, quantity_available,
             average_cost, reorder_level, last_movement_at, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ''',
          positionalParams: [
            Str.uuid(),
            companyId,
            storeId,
            productId,
            null,
            item.qty,
            0,
            item.qty,
            item.cost,
            item.reorder,
          ],
        );
      } else {
        await DB.query(
          '''
          UPDATE inventory
          SET quantity_on_hand = ?, quantity_reserved = ?, quantity_available = ?,
              average_cost = ?, reorder_level = ?, last_movement_at = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
          WHERE id = ? AND company_id = ?
          ''',
          positionalParams: [
            item.qty,
            0,
            item.qty,
            item.cost,
            item.reorder,
            existing['id'],
            companyId,
          ],
        );
      }

      final transactionExists = await _first(
        '''
        SELECT id FROM inventory_transactions
        WHERE company_id = ?
          AND store_id = ?
          AND product_id = ?
          AND reference_type = ?
          AND reference_id = ?
        LIMIT 1
        ''',
        [companyId, storeId, productId, 'demo_seed', item.sku],
      );
      if (transactionExists != null) continue;

      await DB.query(
        '''
        INSERT INTO inventory_transactions
          (id, company_id, store_id, product_id, product_variant_id, type,
           quantity, unit_cost, quantity_before, quantity_after, reference_type,
           reference_id, reason, created_by, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ''',
        positionalParams: [
          Str.uuid(),
          companyId,
          storeId,
          productId,
          null,
          'stock_in',
          item.qty,
          item.cost,
          0,
          item.qty,
          'demo_seed',
          item.sku,
          'Opening stock for farm feed demo',
          inventoryOfficerByStore[storeId],
        ],
      );
    }
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
