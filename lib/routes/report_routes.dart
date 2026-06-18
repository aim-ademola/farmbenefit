import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/report_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class ReportRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final reports = app.controller(ReportController.new);

    reports
        .get('/dashboard', (c) => c.dashboard())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/sales', (c) => c.sales())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/credits', (c) => c.credits())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/inventory', (c) => c.inventory())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/products', (c) => c.products())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/customers', (c) => c.customers())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/staff-activity', (c) => c.staffActivity())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/payroll-tax', (c) => c.payrollTax())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.view_store'));

    reports
        .get('/reports/:type/export', (c) => c.export())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('reports.export'));
  }
}
