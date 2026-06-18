// src/routes/app_routes.dart
import 'package:flint_dart/flint_dart.dart';
import 'package:backend/core/api_response.dart';
import 'audit_routes.dart';
import 'auth_routes.dart';
import 'company_routes.dart';
import 'credit_routes.dart';
import 'customer_routes.dart';
import 'inventory_routes.dart';
import 'notification_routes.dart';
import 'payroll_routes.dart';
import 'product_routes.dart';
import 'purchase_routes.dart';
import 'report_routes.dart';
import 'role_routes.dart';
import 'sale_routes.dart';
import 'sales_realtime_routes.dart';
import 'scanner_session_routes.dart';
import 'store_routes.dart';
import 'user_routes.dart';

/// Main route group for the entire app
class AppRoutes extends RouteGroup {
  @override
  String get prefix => ''; // root

  @override
  List<Middleware> get middlewares => []; // optional global middlewares

  @override
  void register(Flint app) {
    // Home route
    app.get('/', (Context ctx) async => ctx.res?.view('welcome'));
    app.get(
      '/api/v1/health',
      (Context ctx) async => ctx.res?.json(
        ApiResponse.success(
          data: {'status': 'ok'},
          message: 'InventoryHQ API is running',
        ),
      ),
    );

    // Auth routes
    app.routes(AuditRoutes());
    app.routes(AuthRoutes());
    app.routes(CompanyRoutes());
    app.routes(CreditRoutes());
    app.routes(CustomerRoutes());
    app.routes(InventoryRoutes());
    app.routes(NotificationRoutes());
    app.routes(PayrollRoutes());
    app.routes(ProductRoutes());
    app.routes(PurchaseOrderRoutes());
    app.routes(ReportRoutes());
    app.routes(RoleRoutes());
    app.routes(SaleRoutes());
    app.routes(SalesRealtimeRoutes());
    app.routes(ScannerSessionRoutes());
    app.routes(StoreRoutes());
    app.routes(SupplierRoutes());

    // User routes with optional middleware
    app.routes(
      UserRoutes(),
      children: [],
    );
  }
}
