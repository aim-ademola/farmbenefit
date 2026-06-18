import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/payroll_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class PayrollRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/payroll';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final payroll = app.controller(PayrollController.new);

    payroll
        .put('/users/:id/compensation', (c) => c.upsertUserCompensation())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_store'));

    payroll
        .patch('/compensations/:id', (c) => c.updateCompensation())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('users.manage_store'));
  }
}
