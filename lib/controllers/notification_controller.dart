import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';

class NotificationController extends Controller {
  Future<Response> index() async {
    final unreadOnly = req.queryParam('unread') == 'true';
    final where = [
      'notifications.company_id = ?',
      'notifications.user_id = ?',
    ];
    final params = <dynamic>[
      _authContext['company_id'],
      (_authContext['user'] as Map)['id'],
    ];

    if (unreadOnly) {
      where.add('notifications.read_at IS NULL');
    }

    final rows = await DB.query(
      '''
      SELECT
        notifications.*,
        stores.name AS store_name
      FROM notifications
      LEFT JOIN stores ON stores.id = notifications.store_id
      WHERE ${where.join(' AND ')}
      ORDER BY notifications.created_at DESC
      ''',
      positionalParams: params,
    );

    return res.json(ApiResponse.success(
      data: rows,
      message: 'Notifications retrieved successfully',
    ));
  }

  Future<Response> markRead() async {
    await DB.query(
      '''
      UPDATE notifications
      SET read_at = CURRENT_TIMESTAMP
      WHERE id = ?
        AND company_id = ?
        AND user_id = ?
      ''',
      positionalParams: [
        req.params['id'],
        _authContext['company_id'],
        (_authContext['user'] as Map)['id'],
      ],
    );

    return res.json(ApiResponse.success(
      message: 'Notification marked as read',
    ));
  }

  Future<Response> markAllRead() async {
    await DB.query(
      '''
      UPDATE notifications
      SET read_at = CURRENT_TIMESTAMP
      WHERE company_id = ?
        AND user_id = ?
        AND read_at IS NULL
      ''',
      positionalParams: [
        _authContext['company_id'],
        (_authContext['user'] as Map)['id'],
      ],
    );

    return res.json(ApiResponse.success(
      message: 'All notifications marked as read',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);
}
