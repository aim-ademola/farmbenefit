import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/sales_realtime_controller.dart';

class SalesRealtimeRoutes extends RouteGroup {
  @override
  String get prefix => '';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final realtime = app.controller(SalesRealtimeController.new);

    realtime.websocket('/api/v1/ws/sales', (c) => c.connect());
  }
}
