import 'dart:math';

import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

import 'package:backend/core/api_response.dart';

class ScannerSessionController extends Controller {
  Future<Response> create() async {
    final body = await req.json();
    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    final sessionId = Str.uuid();
    final token = _token();
    final expiresAt =
        _sqlDateTime(DateTime.now().add(const Duration(minutes: 30)));
    await DB.query(
      '''
      INSERT INTO scanner_sessions
        (id, company_id, store_id, created_by, token, status, last_seen_at,
         expires_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP,
              ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        sessionId,
        _authContext['company_id'],
        storeId,
        (_authContext['user'] as Map)['id'],
        token,
        'active',
        expiresAt,
      ],
    );

    return res.status(201).json(ApiResponse.success(
          data: {
            'id': sessionId,
            'token': token,
            'store_id': storeId,
            'join_url': 'inventoryhq://scanner/$sessionId?token=$token',
          },
          message: 'Scanner session created successfully',
        ));
  }

  Future<Response> join() async {
    final session = await _activeSession(req.params['id']);
    if (session == null) return _notFoundOrExpired();

    final body = await req.json();
    if (body['token']?.toString() != session['token']?.toString()) {
      return _invalid('Scanner token is invalid.');
    }

    await _touch(session['id']);
    return res.json(ApiResponse.success(
      data: _publicSession(session),
      message: 'Scanner session joined successfully',
    ));
  }

  Future<Response> scans() async {
    final session = await _activeSession(req.params['id']);
    if (session == null) return _notFoundOrExpired();
    if (!_tokenMatches(session, req.queryParam('token'))) {
      return _invalid('Scanner token is invalid.');
    }

    final after = req.queryParam('after');
    final where = [
      'company_id = ?',
      'scanner_session_id = ?',
      'status = ?',
    ];
    final params = <dynamic>[
      _authContext['company_id'],
      session['id'],
      'pending',
    ];
    if (after != null && after.isNotEmpty) {
      where.add('created_at > ?');
      params.add(after);
    }

    final rows = await DB.query(
      '''
      SELECT * FROM scanner_events
      WHERE ${where.join(' AND ')}
      ORDER BY created_at ASC
      ''',
      positionalParams: params,
    );

    await _touch(session['id']);
    return res.json(ApiResponse.success(
      data: rows,
      message: 'Scanner events retrieved successfully',
    ));
  }

  Future<Response> submitScan() async {
    final session = await _activeSession(req.params['id']);
    if (session == null) return _notFoundOrExpired();

    final body = await req.json();
    if (!_tokenMatches(session, body['token'])) {
      return _invalid('Scanner token is invalid.');
    }

    final barcode = body['barcode']?.toString().trim();
    if (barcode == null || barcode.isEmpty) {
      return _invalid('barcode is required.');
    }

    final eventId = Str.uuid();
    await DB.query(
      '''
      INSERT INTO scanner_events
        (id, company_id, scanner_session_id, barcode, status, consumed_at,
         created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        eventId,
        _authContext['company_id'],
        session['id'],
        barcode,
        'pending',
      ],
    );

    await _touch(session['id']);
    return res.status(201).json(ApiResponse.success(
          data: {'id': eventId, 'barcode': barcode},
          message: 'Barcode submitted successfully',
        ));
  }

  Future<Response> consumeScan() async {
    final session = await _activeSession(req.params['id']);
    if (session == null) return _notFoundOrExpired();

    final body = await req.json();
    if (!_tokenMatches(session, body['token'])) {
      return _invalid('Scanner token is invalid.');
    }

    await DB.query(
      '''
      UPDATE scanner_events
      SET status = ?, consumed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND scanner_session_id = ? AND company_id = ?
      ''',
      positionalParams: [
        'consumed',
        req.params['scan_id'],
        session['id'],
        _authContext['company_id'],
      ],
    );

    return res.json(ApiResponse.success(
      message: 'Scanner event consumed successfully',
    ));
  }

  Future<Response> close() async {
    final session = await _activeSession(req.params['id']);
    if (session == null) return _notFoundOrExpired();

    final body = await req.json();
    if (!_tokenMatches(session, body['token'])) {
      return _invalid('Scanner token is invalid.');
    }

    await DB.query(
      '''
      UPDATE scanner_sessions
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: ['closed', session['id'], _authContext['company_id']],
    );

    return res.json(ApiResponse.success(
      message: 'Scanner session closed successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Object> _resolveStoreId(Object? requestedStoreId) async {
    final storeId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : requestedStoreId ?? _authContext['store_id'];
    if (storeId == null) {
      final store = await _first(
        '''
        SELECT id FROM stores
        WHERE company_id = ? AND deleted_at IS NULL
        ORDER BY created_at ASC
        LIMIT 1
        ''',
        [_authContext['company_id']],
      );
      if (store == null) return _invalid('store_id is required.');
      return store['id'];
    }

    final store = await _first(
      '''
      SELECT id FROM stores
      WHERE id = ? AND company_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      [storeId, _authContext['company_id']],
    );
    if (store == null) return _invalid('store_id is invalid.');
    return storeId;
  }

  Future<Map<String, dynamic>?> _activeSession(Object? id) async {
    final session = await _first(
      '''
      SELECT * FROM scanner_sessions
      WHERE id = ?
        AND company_id = ?
        AND status = 'active'
        AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
      LIMIT 1
      ''',
      [id, _authContext['company_id']],
    );
    if (session == null) return null;
    if (_authContext['role_scope'] == 'store' &&
        session['store_id']?.toString() !=
            _authContext['store_id']?.toString()) {
      return null;
    }
    return session;
  }

  Future<Map<String, dynamic>?> _first(String sql, List<dynamic> params) async {
    final rows = await DB.query(sql, positionalParams: params);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> _touch(Object? sessionId) {
    return DB.query(
      '''
      UPDATE scanner_sessions
      SET last_seen_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [sessionId, _authContext['company_id']],
    );
  }

  Map<String, dynamic> _publicSession(Map<String, dynamic> session) {
    return {
      'id': session['id'],
      'store_id': session['store_id'],
      'status': session['status'],
      'expires_at': session['expires_at'],
    };
  }

  bool _tokenMatches(Map<String, dynamic> session, Object? token) {
    return token?.toString() == session['token']?.toString();
  }

  Future<Response> _invalid(String message) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: message,
        ));
  }

  Future<Response> _notFoundOrExpired() {
    return res.status(404).json(ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Scanner session was not found or has expired.',
        ));
  }

  String _token() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      40,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sqlDateTime(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }
}
