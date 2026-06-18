import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/store_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class StoreRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/stores';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final stores = app.controller(StoreController.new);

    stores
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('stores.view_all'));

    stores
        .post('/', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('stores.create'));

    stores
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('stores.view_all'));

    stores
        .patch('/:id', (c) => c.update())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('stores.update'));

    stores
        .delete('/:id', (c) => c.delete())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('stores.update'));

    stores
        .post('/:id/assign-manager', (c) => c.assignManager())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));

    stores
        .post('/:id/assign-staff', (c) => c.assignStaff())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));
  }
}
