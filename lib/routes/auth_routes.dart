import 'package:flint_dart/flint_dart.dart';
import 'package:backend/controllers/auth_controller.dart';
import 'package:backend/middlewares/auth_middleware.dart';

/// Auth API routes
class AuthRoutes extends RouteGroup {
  @override
  String get prefix => '/api/v1/auth';

  @override
  List<Middleware> get middlewares =>
      []; // optional global middleware for this group

  @override
  void register(Flint app) {
    final auth = app.controller(AuthController.new);

    /// @summary Register a new user
    /// @auth bearer
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    /// @body {"field1": "string", "field2": "string"}
    auth.post('/register', (c) => c.register());

    /// @summary Login user
    /// @auth bearer
    /// @response 200 Success response description
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    /// @body {"field1": "string", "field2": "string"}
    auth.post('/login', (c) => c.login());

    /// @summary Refresh access token
    /// @auth bearer
    auth.post('/refresh', (c) => c.refresh());

    /// @summary Request password reset
    auth.post('/forgot-password', (c) => c.forgotPassword());

    /// @summary Reset password
    auth.post('/reset-password', (c) => c.resetPassword());

    /// @summary Revoke refresh token
    /// @auth bearer
    auth.post('/logout', (c) => c.logout()).useMiddleware(AuthMiddleware());

    /// @summary Get current user profile and permissions
    /// @auth bearer
    auth.get('/me', (c) => c.me()).useMiddleware(AuthMiddleware());

    /// @summary Login with Google
    /// @auth bearer
    /// @response 200 Resource created successfully
    /// @response 400 Bad request
    /// @response 401 Unauthorized
    /// @response 500 Internal server error
    /// @body {"example": "string"}
    auth.post('/login-with-google', (c) => c.loginWithGoogle());
  }
}
