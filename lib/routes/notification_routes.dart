import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/notification_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';

class NotificationRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/notifications';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final notifications = app.controller(NotificationController.new);

    notifications.get('/', (c) => c.index()).useMiddleware(AuthMiddleware());
    notifications
        .post('/read-all', (c) => c.markAllRead())
        .useMiddleware(AuthMiddleware());
    notifications
        .post('/:id/read', (c) => c.markRead())
        .useMiddleware(AuthMiddleware());
  }
}
