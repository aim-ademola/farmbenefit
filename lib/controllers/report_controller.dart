import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';

class ReportController extends Controller {
  Future<Response> dashboard() async {
    final storeClause = _storeClause('sales.store_id');
    final inventoryStoreClause = _storeClause('inventory.store_id');

    final todaysSales = await _scalar(
      '''
      SELECT COALESCE(SUM(grand_total), 0) AS value
      FROM sales
      WHERE company_id = ?
        AND status = 'completed'
        AND DATE(created_at) = CURRENT_DATE
        $storeClause
      ''',
      _paramsWithStore(),
    );

    final monthlySales = await _scalar(
      '''
      SELECT COALESCE(SUM(grand_total), 0) AS value
      FROM sales
      WHERE company_id = ?
        AND status = 'completed'
        AND YEAR(created_at) = YEAR(CURRENT_DATE)
        AND MONTH(created_at) = MONTH(CURRENT_DATE)
        $storeClause
      ''',
      _paramsWithStore(),
    );

    final inventoryValue = await _scalar(
      '''
      SELECT COALESCE(SUM(quantity_on_hand * average_cost), 0) AS value
      FROM inventory
      WHERE company_id = ?
        $inventoryStoreClause
      ''',
      _paramsWithStore(),
    );

    final outstandingCredits = await _scalar(
      '''
      SELECT COALESCE(SUM(outstanding_balance), 0) AS value
      FROM customers
      WHERE company_id = ?
        AND deleted_at IS NULL
        ${_storeClause('store_id')}
      ''',
      _paramsWithStore(),
    );

    final topProducts = await DB.query(
      '''
      SELECT
        sale_items.product_id,
        sale_items.name_snapshot,
        SUM(sale_items.quantity) AS quantity_sold,
        SUM(sale_items.line_total) AS sales_total
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      WHERE sales.company_id = ?
        AND sales.status = 'completed'
        $storeClause
      GROUP BY sale_items.product_id, sale_items.name_snapshot
      ORDER BY quantity_sold DESC
      LIMIT 5
      ''',
      positionalParams: _paramsWithStore(),
    );

    final lowStock = await DB.query(
      '''
      SELECT
        inventory.*,
        stores.name AS store_name,
        products.name AS product_name,
        products.sku AS product_sku
      FROM inventory
      INNER JOIN stores ON stores.id = inventory.store_id
      INNER JOIN products ON products.id = inventory.product_id
      WHERE inventory.company_id = ?
        AND inventory.quantity_available <= inventory.reorder_level
        $inventoryStoreClause
      ORDER BY inventory.quantity_available ASC
      LIMIT 10
      ''',
      positionalParams: _paramsWithStore(),
    );

    return res.json(ApiResponse.success(
      data: {
        'todays_sales': todaysSales,
        'monthly_sales': monthlySales,
        'total_inventory_value': inventoryValue,
        'outstanding_credits': outstandingCredits,
        'top_products': topProducts,
        'low_stock_products': lowStock,
      },
      message: 'Dashboard metrics retrieved successfully',
    ));
  }

  Future<Response> sales() async {
    final filters = _dateFilters('sales.created_at');
    final rows = await DB.query(
      '''
      SELECT
        sales.*,
        stores.name AS store_name,
        customers.name AS customer_name,
        users.email AS sold_by_email
      FROM sales
      INNER JOIN stores ON stores.id = sales.store_id
      LEFT JOIN customers ON customers.id = sales.customer_id
      LEFT JOIN users ON users.id = sales.sold_by
      WHERE sales.company_id = ?
        ${_storeClause('sales.store_id')}
        ${filters.sql}
      ORDER BY sales.created_at DESC
      ''',
      positionalParams: [..._paramsWithStore(), ...filters.params],
    );

    return _report('Sales report retrieved successfully', rows);
  }

  Future<Response> credits() async {
    final filters = _dateFilters('credit_requests.created_at');
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
      WHERE credit_requests.company_id = ?
        ${_storeClause('credit_requests.store_id')}
        ${filters.sql}
      ORDER BY credit_requests.created_at DESC
      ''',
      positionalParams: [..._paramsWithStore(), ...filters.params],
    );

    return _report('Credit report retrieved successfully', rows);
  }

  Future<Response> inventory() async {
    final rows = await DB.query(
      '''
      SELECT
        inventory.*,
        stores.name AS store_name,
        products.name AS product_name,
        products.sku AS product_sku,
        product_variants.variant_name
      FROM inventory
      INNER JOIN stores ON stores.id = inventory.store_id
      INNER JOIN products ON products.id = inventory.product_id
      LEFT JOIN product_variants ON product_variants.id = inventory.product_variant_id
      WHERE inventory.company_id = ?
        ${_storeClause('inventory.store_id')}
      ORDER BY stores.name, products.name
      ''',
      positionalParams: _paramsWithStore(),
    );

    return _report('Inventory report retrieved successfully', rows);
  }

  Future<Response> products() async {
    final rows = await DB.query(
      '''
      SELECT
        products.*,
        categories.name AS category_name,
        COALESCE(SUM(inventory.quantity_on_hand), 0) AS total_quantity_on_hand,
        COALESCE(SUM(inventory.quantity_on_hand * inventory.average_cost), 0) AS inventory_value
      FROM products
      LEFT JOIN categories ON categories.id = products.category_id
      LEFT JOIN inventory ON inventory.product_id = products.id
        ${_storeFilter() == null ? '' : 'AND inventory.store_id = ?'}
      WHERE products.company_id = ?
        AND products.deleted_at IS NULL
      GROUP BY products.id, categories.name
      ORDER BY products.name
      ''',
      positionalParams: [
        if (_storeFilter() != null) _storeFilter(),
        _authContext['company_id'],
      ],
    );

    return _report('Product report retrieved successfully', rows);
  }

  Future<Response> customers() async {
    final rows = await DB.query(
      '''
      SELECT
        customers.*,
        stores.name AS store_name
      FROM customers
      INNER JOIN stores ON stores.id = customers.store_id
      WHERE customers.company_id = ?
        AND customers.deleted_at IS NULL
        ${_storeClause('customers.store_id')}
      ORDER BY customers.outstanding_balance DESC, customers.name
      ''',
      positionalParams: _paramsWithStore(),
    );

    return _report('Customer report retrieved successfully', rows);
  }

  Future<Response> staffActivity() async {
    final filters = _dateFilters('audit_logs.created_at');
    final rows = await DB.query(
      '''
      SELECT
        audit_logs.*,
        users.email AS user_email,
        stores.name AS store_name
      FROM audit_logs
      LEFT JOIN users ON users.id = audit_logs.user_id
      LEFT JOIN stores ON stores.id = audit_logs.store_id
      WHERE audit_logs.company_id = ?
        ${_storeClause('audit_logs.store_id')}
        ${filters.sql}
      ORDER BY audit_logs.created_at DESC
      ''',
      positionalParams: [..._paramsWithStore(), ...filters.params],
    );

    return _report('Staff activity report retrieved successfully', rows);
  }

  Future<Response> payrollTax() async {
    final employerTaxRate = _queryRate('employer_tax_rate', 0);
    final filters = _dateFilters('sales.completed_at');

    final staffRows = await DB.query(
      '''
      SELECT
        staff_compensations.id,
        COALESCE(staff_compensations.monthly_salary, 0) AS monthly_salary,
        COALESCE(staff_compensations.currency, 'NGN') AS currency,
        COALESCE(staff_compensations.status, users.status) AS status,
        users.id AS user_id,
        COALESCE(staff_compensations.store_id, users.store_id) AS store_id,
        CONCAT(users.first_name, ' ', users.last_name) AS employee_name,
        users.email AS employee_email,
        roles.name AS role_name,
        COALESCE(stores.name, 'All Stores') AS store_name
      FROM users
      INNER JOIN roles ON roles.id = users.role_id
      LEFT JOIN staff_compensations
        ON staff_compensations.user_id = users.id
        AND staff_compensations.company_id = users.company_id
      LEFT JOIN stores ON stores.id = COALESCE(staff_compensations.store_id, users.store_id)
      WHERE users.company_id = ?
        AND users.deleted_at IS NULL
        AND users.status = 'active'
        ${_storeClause('COALESCE(staff_compensations.store_id, users.store_id)')}
      ORDER BY stores.name, users.first_name, users.last_name
      ''',
      positionalParams: _paramsWithStore(),
    );

    final productTaxRows = await DB.query(
      '''
      SELECT
        sale_items.product_id,
        sale_items.name_snapshot AS product_name,
        stores.name AS store_name,
        SUM(sale_items.line_total) AS taxable_sales,
        SUM(sale_items.tax_amount) AS product_tax_payable
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      INNER JOIN stores ON stores.id = sales.store_id
      WHERE sales.company_id = ?
        AND sales.status = 'completed'
        ${_storeClause('sales.store_id')}
        ${filters.sql}
      GROUP BY sale_items.product_id, sale_items.name_snapshot, stores.name
      ORDER BY product_tax_payable DESC, product_name
      ''',
      positionalParams: [..._paramsWithStore(), ...filters.params],
    );

    final purchaseTaxRows = await DB.query(
      '''
      SELECT
        purchase_orders.store_id,
        stores.name AS store_name,
        SUM(purchase_orders.subtotal) AS taxable_purchases,
        SUM(purchase_orders.tax_total) AS purchase_tax
      FROM purchase_orders
      INNER JOIN stores ON stores.id = purchase_orders.store_id
      WHERE purchase_orders.company_id = ?
        ${_storeClause('purchase_orders.store_id')}
        ${_dateFilters('purchase_orders.created_at').sql}
      GROUP BY purchase_orders.store_id, stores.name
      ORDER BY stores.name
      ''',
      positionalParams: [
        ..._paramsWithStore(),
        ..._dateFilters('purchase_orders.created_at').params,
      ],
    );

    final rows = <Map<String, dynamic>>[];
    var totalSalary = 0.0;
    var totalEmployeeTax = 0.0;
    var totalEmployerTax = 0.0;

    for (final raw in staffRows) {
      final staff = Map<String, dynamic>.from(raw as Map);
      final salary = _asDouble(staff['monthly_salary']);
      final annualSalary = salary * 12;
      final annualPaye = _annualPayeTax(annualSalary);
      final employeeTax = annualPaye / 12;
      final employerTax = salary * employerTaxRate;
      totalSalary += salary;
      totalEmployeeTax += employeeTax;
      totalEmployerTax += employerTax;

      rows.add({
        'id': staff['id'],
        'user_id': staff['user_id'],
        'type': 'Employee payroll',
        'name': staff['employee_name'],
        'store_name': staff['store_name'],
        'role_name': staff['role_name'],
        'monthly_salary': salary,
        'annual_salary': annualSalary,
        'annual_paye_tax': annualPaye,
        'tax_free_threshold': 800000,
        'employee_tax_scheme': 'Nigeria PAYE 2026',
        'employee_tax_payable': employeeTax,
        'employer_tax_rate': employerTaxRate,
        'employer_tax_payable': employerTax,
        'tax_payable': employeeTax + employerTax,
        'company_payable': salary + employerTax,
        'status': staff['status'],
      });
    }

    var totalProductTax = 0.0;
    for (final raw in productTaxRows) {
      final product = Map<String, dynamic>.from(raw as Map);
      final productTax = _asDouble(product['product_tax_payable']);
      totalProductTax += productTax;
      rows.add({
        'type': 'Product sales tax',
        'name': product['product_name'],
        'store_name': product['store_name'],
        'taxable_amount': _asDouble(product['taxable_sales']),
        'tax_payable': productTax,
        'company_payable': productTax,
        'status': productTax > 0 ? 'Payable' : 'No tax',
      });
    }

    var totalPurchaseTax = 0.0;
    for (final raw in purchaseTaxRows) {
      final purchase = Map<String, dynamic>.from(raw as Map);
      final purchaseTax = _asDouble(purchase['purchase_tax']);
      totalPurchaseTax += purchaseTax;
      rows.add({
        'type': 'Purchase tax',
        'name': 'Purchases',
        'store_name': purchase['store_name'],
        'taxable_amount': _asDouble(purchase['taxable_purchases']),
        'tax_payable': purchaseTax,
        'company_payable': purchaseTax,
        'status': purchaseTax > 0 ? 'Payable' : 'No tax',
      });
    }

    rows.insert(0, {
      'type': 'Company tax summary',
      'name': 'Total company payable',
      'store_name': _storeFilter() == null ? 'All Stores' : 'Current Store',
      'monthly_salary': totalSalary,
      'employee_tax_scheme': 'Nigeria PAYE 2026',
      'tax_free_threshold': 800000,
      'employee_tax_payable': totalEmployeeTax,
      'employer_tax_payable': totalEmployerTax,
      'product_tax_payable': totalProductTax,
      'purchase_tax_payable': totalPurchaseTax,
      'tax_payable': totalEmployeeTax +
          totalEmployerTax +
          totalProductTax +
          totalPurchaseTax,
      'company_payable':
          totalSalary + totalEmployerTax + totalProductTax + totalPurchaseTax,
      'status': 'Ready',
    });

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Payroll and tax report retrieved successfully',
    ));
  }

  Future<Response> export() async {
    final type = req.params['type'] ?? 'unknown';
    return res.json(ApiResponse.success(
      data: {
        'type': type,
        'format': req.queryParam('format') ?? 'json',
        'generated_at': DateTime.now().toIso8601String(),
        'message':
            'PDF and Excel generation will be added in the deployment/reporting phase.',
      },
      message: 'Report export payload generated successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Object? _storeFilter() {
    if (_authContext['role_scope'] == 'store') return _authContext['store_id'];
    final storeId = req.queryParam('store_id');
    return storeId == null || storeId.isEmpty ? null : storeId;
  }

  String _storeClause(String column) =>
      _storeFilter() == null ? '' : 'AND $column = ?';

  List<dynamic> _paramsWithStore() => [
        _authContext['company_id'],
        if (_storeFilter() != null) _storeFilter(),
      ];

  _DateFilter _dateFilters(String column) {
    final params = <dynamic>[];
    final clauses = <String>[];
    final dateFrom = req.queryParam('date_from');
    final dateTo = req.queryParam('date_to');
    if (dateFrom != null && dateFrom.isNotEmpty) {
      clauses.add('AND $column >= ?');
      params.add(dateFrom);
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      clauses.add('AND $column <= ?');
      params.add(dateTo);
    }
    return _DateFilter(clauses.join(' '), params);
  }

  Future<double> _scalar(String sql, List<dynamic> params) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return 0;
    final value = rows.first['value'];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _queryRate(String key, double fallback) {
    final value = double.tryParse(req.queryParam(key) ?? '');
    if (value == null || value < 0) return fallback;
    return value > 1 ? value / 100 : value;
  }

  double _annualPayeTax(double annualIncome) {
    var remaining = annualIncome;
    var tax = 0.0;
    for (final band in _payeBands) {
      if (remaining <= 0) break;
      final taxable = band.limit == null
          ? remaining
          : remaining > band.limit!
              ? band.limit!
              : remaining;
      tax += taxable * band.rate;
      remaining -= taxable;
    }
    return tax;
  }

  double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Response> _report(String message, List<Map<String, dynamic>> rows) {
    return res.json(ApiResponse.success(
      data: {
        'rows': rows,
        'count': rows.length,
      },
      message: message,
    ));
  }
}

const _payeBands = [
  _TaxBand(800000, 0),
  _TaxBand(2200000, 0.15),
  _TaxBand(9000000, 0.18),
  _TaxBand(13000000, 0.21),
  _TaxBand(25000000, 0.23),
  _TaxBand(null, 0.25),
];

class _TaxBand {
  const _TaxBand(this.limit, this.rate);

  final double? limit;
  final double rate;
}

class _DateFilter {
  final String sql;
  final List<dynamic> params;

  _DateFilter(this.sql, this.params);
}
