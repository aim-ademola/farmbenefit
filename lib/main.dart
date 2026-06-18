import 'package:flint_dart/flint_dart.dart';
import 'package:backend/routes/app_routes.dart';

void main() {
  final app = Flint(
    withDefaultMiddleware: true,
    autoConnectDb: true,
    enableSwaggerDocs: true,
  );

  app.use(CorsMiddleware());

  // Mount the main AppRoutes
  app.routes(AppRoutes());
  // Start the server
  app.listen(hotReload: true);
}
