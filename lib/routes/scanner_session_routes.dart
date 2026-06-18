import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/scanner_session_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class ScannerSessionRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/scanner-sessions';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final sessions = app.controller(ScannerSessionController.new);

    sessions
        .post('/', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sessions
        .post('/:id/join', (c) => c.join())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sessions
        .get('/:id/scans', (c) => c.scans())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sessions
        .post('/:id/scans', (c) => c.submitScan())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sessions
        .post('/:id/scans/:scan_id/consume', (c) => c.consumeScan())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));

    sessions
        .post('/:id/close', (c) => c.close())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('sales.create'));
  }
}
