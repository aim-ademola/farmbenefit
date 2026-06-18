import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/auth_context_service.dart';

class PermissionMiddleware extends Middleware {
  final String permission;
  final _authContextService = AuthContextService();

  PermissionMiddleware(this.permission);

  @override
  Handler handle(Handler next) {
    return (Context ctx) async {
      final res = ctx.res;
      if (res == null) return null;

      var auth = ctx.req.get('auth');
      var permissions = ctx.req.get('permissions');

      if (auth == null || permissions == null) {
        final authContext =
            await _authContextService.fromBearerToken(ctx.req.bearerToken);
        if (authContext == null) {
          return res.status(401).json(ApiResponse.error(
                code: 'UNAUTHENTICATED',
                message: 'Authentication required',
              ));
        }

        ctx.req.set('auth', authContext);
        ctx.req.set('user', authContext['user']);
        ctx.req.set('permissions', authContext['permissions']);
        auth = authContext;
        permissions = authContext['permissions'];
      }

      final roleKey = auth is Map ? auth['role_key']?.toString() : null;
      final isCompanyAdmin = roleKey == 'company_admin';
      if (!isCompanyAdmin &&
          (permissions is! List || !permissions.contains(permission))) {
        return res.status(403).json(ApiResponse.error(
              code: 'FORBIDDEN',
              message: 'You do not have permission to perform this action.',
              details: {'permission': permission},
            ));
      }

      return await next(ctx);
    };
  }
}
