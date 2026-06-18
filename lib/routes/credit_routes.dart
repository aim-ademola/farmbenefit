import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/credit_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class CreditRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/credit-requests';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final credit = app.controller(CreditController.new);

    credit
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));

    credit
        .post('/', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('credit.request'));

    credit
        .get('/:id/approvals', (c) => c.approvals())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));

    credit
        .post('/:id/manager-approve', (c) => c.managerApprove())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('credit.manager_approve'));

    credit
        .post('/:id/admin-approve', (c) => c.adminApprove())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('credit.admin_approve'));

    credit
        .post('/:id/reject', (c) => c.reject())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('credit.manager_approve'));

    credit
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.view'));
  }
}
