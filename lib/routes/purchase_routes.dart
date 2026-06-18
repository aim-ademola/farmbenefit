import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/purchase_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class SupplierRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/suppliers';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final purchases = app.controller(PurchaseController.new);

    purchases
        .get('/', (c) => c.suppliers())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.view'));

    purchases
        .post('/', (c) => c.createSupplier())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.manage'));

    purchases
        .patch('/:id', (c) => c.updateSupplier())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.manage'));
  }
}

class PurchaseOrderRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/purchase-orders';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final purchases = app.controller(PurchaseController.new);

    purchases
        .get('/', (c) => c.purchaseOrders())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.view'));

    purchases
        .post('/', (c) => c.createPurchaseOrder())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.manage'));

    purchases
        .post('/:id/receive', (c) => c.receivePurchaseOrder())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.stock_in'));

    purchases
        .get('/:id', (c) => c.showPurchaseOrder())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.view'));

    purchases
        .patch('/:id', (c) => c.updatePurchaseOrder())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('suppliers.manage'));
  }
}
