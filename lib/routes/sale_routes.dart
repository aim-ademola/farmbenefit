import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/sale_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class SaleRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/sales';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final sales = app.controller(SaleController.new);

    sales
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));

    sales
        .post('/', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .post('/smart', (c) => c.smart())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .patch('/:id', (c) => c.update())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .post('/:id/complete', (c) => c.complete())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .post('/:id/cancel', (c) => c.cancel())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .delete('/:id', (c) => c.delete())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sales
        .post('/:id/refund', (c) => c.refund())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.refund'));

    sales
        .post('/:id/return', (c) => c.returnSale())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.refund'));

    sales
        .get('/:id/invoice', (c) => c.invoice())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));

    sales
        .get('/:id/receipt', (c) => c.receipt())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));

    sales
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));
  }
}
