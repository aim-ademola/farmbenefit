import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/inventory_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class InventoryRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/inventory';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final inventory = app.controller(InventoryController.new);

    inventory
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.view'));

    inventory
        .get('/transactions', (c) => c.transactions())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.view'));

    inventory
        .get('/low-stock', (c) => c.lowStock())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.view'));

    inventory
        .get('/transfers', (c) => c.transfers())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.view'));

    inventory
        .post('/transfers', (c) => c.createTransfer())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.transfer'));

    inventory
        .post('/transfers/:id/approve', (c) => c.approveTransfer())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.transfer'));

    inventory
        .post('/transfers/:id/receive', (c) => c.receiveTransfer())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.transfer'));

    inventory
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.view'));

    inventory
        .post('/stock-in', (c) => c.stockIn())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.stock_in'));

    inventory
        .post('/stock-out', (c) => c.stockOut())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.stock_out'));

    inventory
        .post('/adjustments', (c) => c.adjustment())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('inventory.adjust'));
  }
}
