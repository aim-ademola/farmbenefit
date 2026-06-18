import 'package:flint_dart/flint_dart.dart';

import 'package:backend/controllers/product_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';
import 'package:backend/middlewares/permission_middleware.dart';

class ProductRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1';

  @override
  List<Middleware> get middlewares => [];

  @override
  void register(Flint app) {
    final products = app.controller(ProductController.new);

    products
        .get('/categories', (c) => c.categories())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.view'));

    products
        .post('/categories', (c) => c.createCategory())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.create'));

    products
        .patch('/categories/:id', (c) => c.updateCategory())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.update'));

    products
        .get('/products/barcode/:barcode', (c) => c.barcodeLookup())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.view'));

    products
        .get('/products', (c) => c.index())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.view'));

    products
        .post('/products', (c) => c.create())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.create'));

    products
        .get('/products/:id', (c) => c.show())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.view'));

    products
        .patch('/products/:id', (c) => c.update())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.update'));

    products
        .delete('/products/:id', (c) => c.delete())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.update'));

    products
        .post('/products/:id/variants', (c) => c.createVariant())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.create'));

    products
        .patch('/product-variants/:id', (c) => c.updateVariant())
        .useMiddleware(AuthMiddleware())
        .useMiddleware(PermissionMiddleware('products.update'));
  }
}
