import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/company_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class CompanyRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/company';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final company = app.controller(CompanyController.new);

    company.get('/', (c) => c.show()).useMiddleware(AuthMiddleware());
    company
        .patch('/', (c) => c.update())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('company.update'));
  }
}
