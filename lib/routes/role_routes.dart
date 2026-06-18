import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/role_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class RoleRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final roles = app.controller(RoleController.new);

    roles
        .get('/roles', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));

    roles
        .post('/roles', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));

    roles
        .get('/permissions', (c) => c.permissions())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));

    roles
        .put('/roles/:id/permissions', (c) => c.replacePermissions())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_all'));
  }
}
