import 'package:flint_dart/flint_dart.dart';
import 'package:backend/core/api_response.dart';
import 'package:backend/services/auth_context_service.dart';

class AuthMiddleware extends Middleware {
  final _authContextService = AuthContextService();

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final req = ctx.req;
      final res = ctx.res;
      if (res == null) return null;

      final authContext =
          await _authContextService.fromBearerToken(req.bearerToken);
      if (authContext == null) {
        return res.status(401).json(ApiResponse.error(
              code: 'UNAUTHENTICATED',
              message: 'Authentication required',
            ));
      }

      req.set('auth', authContext);
      req.set('user', authContext['user']);
      req.set('permissions', authContext['permissions']);

      return await next(ctx);
    };
  }
}
