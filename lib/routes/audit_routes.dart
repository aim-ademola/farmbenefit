import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/audit_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class AuditRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/audit-logs';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final audit = app.controller(AuditController.new);

    audit
        .get('/', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('audit.view'));

    audit
        .get('/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('audit.view'));
  }
}
