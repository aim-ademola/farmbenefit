import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/customer_contact_verification_controller.dart';
import 'package:backend/controllers/customer_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class CustomerRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/customers';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final customers = app.controller(CustomerController.new);
    final verification =
        app.controller(CustomerContactVerificationController.new);

    verification
        .post('/verify-contact/request', (c) => c.requestOtp())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    verification
        .post('/verify-contact/confirm', (c) => c.verifyOtp())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    customers
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.view'));

    customers
        .post('/', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.manage'));

    customers
        .get('/:id/statement', (c) => c.statement())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.view'));

    customers
        .get('/:id/credit-history', (c) => c.creditHistory())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.view'));

    customers
        .get('/:id/purchase-history', (c) => c.purchaseHistory())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.view'));

    customers
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.view'));

    customers
        .patch('/:id', (c) => c.update())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('customers.manage'));
  }
}
