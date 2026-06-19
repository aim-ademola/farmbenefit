import 'dart:async';

import 'package:flint_dart/flint_dart.dart';

import 'package:backend/services/auth_context_service.dart';
import 'package:backend/services/sales_realtime_service.dart';

class SalesRealtimeController extends Controller {
  final _authContextService = AuthContextService();

  void connect() {
    final request = req;
    final client = socket;

    unawaited(_connect(request, client));
  }

  Future<void> _connect(Request request, FlintWebSocket client) async {
    final auth = await _authContextService.fromBearerToken(
      request.queryParam('token') ?? request.bearerToken,
    );
    if (auth == null) {
      client.emit('sales.error', {'message': 'Authentication required'});
      return;
    }

    final roleKey = auth['role_key']?.toString();
    final permissions = auth['permissions'];
    final permissionList = permissions is List ? permissions : const [];
    final canUseRealtime = roleKey == 'company_admin' ||
        permissionList.contains('sales.view') ||
        permissionList.contains('products.view') ||
        permissionList.contains('inventory.view');
    if (!canUseRealtime) {
      client.emit('sales.error', {
        'message': 'You do not have permission to view realtime updates.',
      });
      return;
    }

    final companyId = auth['company_id'];
    client.join(SalesRealtimeService.companyRoom(companyId));
    client.on('ping', (_) => client.emit('pong', {}));
    client.emit('sales.connected', {
      'company_id': companyId,
      'store_id': auth['store_id'],
    });
  }
}
