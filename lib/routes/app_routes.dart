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
    // Public website routes.
    app.get('/', (Context ctx) async => _sitePage(ctx, 'Home'));
    app.get('/about-us', (Context ctx) async => _sitePage(ctx, 'About'));
    app.get('/services', (Context ctx) async => _sitePage(ctx, 'Services'));
    app.get('/products', (Context ctx) async => _sitePage(ctx, 'Products'));
    app.get(
      '/why-choose-us',
      (Context ctx) async => _sitePage(ctx, 'WhyChooseUs'),
    );
    app.get('/gallery', (Context ctx) async => _sitePage(ctx, 'Gallery'));
    app.get('/contact-us', (Context ctx) async => _sitePage(ctx, 'Contact'));
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

  Response? _sitePage(Context ctx, String component) {
    final seo = _siteSeo[component] ?? _siteSeo['Home']!;

    return ctx.res?.page(
      component,
      title: seo.title,
      meta: FlintPageMeta(
        title: seo.title,
        description: seo.description,
        siteName: 'FARMS BENEFIT LIMITED',
      ),
    );
  }
}

class _SiteSeo {
  const _SiteSeo({required this.title, required this.description});

  final String title;
  final String description;
}

const _siteSeo = {
  'Home': _SiteSeo(
    title: 'FARMS BENEFIT LIMITED | Agriculture and Farm Produce Supply',
    description:
        'FARMS BENEFIT LIMITED provides quality agricultural products, reliable farm produce supply, and sustainable agribusiness solutions.',
  ),
  'About': _SiteSeo(
    title: 'About FARMS BENEFIT LIMITED | Agribusiness Company',
    description:
        'Learn about FARMS BENEFIT LIMITED, a dependable agribusiness company focused on farming, produce supply, and food value chain support.',
  ),
  'Services': _SiteSeo(
    title: 'Agricultural Services | FARMS BENEFIT LIMITED',
    description:
        'Explore crop farming, livestock farming, farm produce supply, agro processing, consultation, investment support, and food distribution services.',
  ),
  'Products': _SiteSeo(
    title: 'Farm Produce and Agro Products | FARMS BENEFIT LIMITED',
    description:
        'Fresh vegetables, grains, livestock products, processed agro products, and seasonal farm produce supplied by FARMS BENEFIT LIMITED.',
  ),
  'WhyChooseUs': _SiteSeo(
    title: 'Why Choose FARMS BENEFIT LIMITED | Trusted Agribusiness Partner',
    description:
        'See why buyers, communities, and agribusiness partners choose FARMS BENEFIT LIMITED for quality, reliability, and market-focused agricultural value.',
  ),
  'Gallery': _SiteSeo(
    title: 'Agriculture Gallery | FARMS BENEFIT LIMITED',
    description:
        'View visual highlights of FARMS BENEFIT LIMITED crop fields, fresh harvests, livestock care, agro processing, produce supply, and distribution.',
  ),
  'Contact': _SiteSeo(
    title: 'Contact FARMS BENEFIT LIMITED | Farm Produce and Services',
    description:
        'Contact FARMS BENEFIT LIMITED for agricultural products, farm produce supply, consultation, processing, investment support, and food distribution.',
  ),
};
