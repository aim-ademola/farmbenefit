import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';
import 'package:backend/services/customer_contact_otp_service.dart';

class CustomerContactVerificationController extends Controller {
  final _otp = CustomerContactOtpService();

  Future<Response> requestOtp() async {
    final body = await req.json();
    final channel = body['channel']?.toString();
    final contact = body['contact']?.toString().trim();

    if (channel == null ||
        !CustomerContactOtpService.channels.contains(channel)) {
      return _invalid('channel must be email or whatsapp.');
    }
    if (contact == null || contact.isEmpty) {
      return _invalid('contact is required.');
    }

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    final otp = await _otp.requestOtp(
      companyId: _authContext['company_id'],
      storeId: storeId,
      requestedBy: (_authContext['user'] as Map)['id'],
      channel: channel,
      contact: contact,
    );

    return res.status(202).json(ApiResponse.success(
          data: otp,
          message:
              channel == 'email' ? 'Email OTP sent.' : 'WhatsApp OTP sent.',
        ));
  }

  Future<Response> verifyOtp() async {
    final body = await req.json();
    final channel = body['channel']?.toString();
    final contact = body['contact']?.toString().trim();
    final code = body['code']?.toString().trim();

    if (channel == null ||
        !CustomerContactOtpService.channels.contains(channel)) {
      return _invalid('channel must be email or whatsapp.');
    }
    if (contact == null || contact.isEmpty || code == null || code.isEmpty) {
      return _invalid('contact and code are required.');
    }

    final storeId = await _resolveStoreId(body['store_id']);
    if (storeId is Response) return storeId;

    final verified = await _otp.verifyOtp(
      companyId: _authContext['company_id'],
      storeId: storeId,
      channel: channel,
      contact: contact,
      code: code,
    );
    if (!verified) return _invalid('OTP is invalid or expired.');

    return res.json(ApiResponse.success(
      data: {
        'channel': channel,
        'contact': _otp.normalizeContact(channel: channel, contact: contact),
        'verified': true,
      },
      message: 'Customer contact verified.',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Object> _resolveStoreId(Object? requestedStoreId) async {
    final queryStoreId = req.queryParam('store_id');
    final storeId = _authContext['role_scope'] == 'store'
        ? _authContext['store_id']
        : requestedStoreId ??
            (queryStoreId == null || queryStoreId.isEmpty
                ? null
                : queryStoreId);
    if (storeId != null) return storeId;

    final rows = await DB.query(
      '''
      SELECT id FROM stores
      WHERE company_id = ? AND deleted_at IS NULL
      ORDER BY created_at ASC
      LIMIT 1
      ''',
      positionalParams: [_authContext['company_id']],
    );
    if (rows.isEmpty) return _invalid('store_id is required.');
    return Map<String, dynamic>.from(rows.first as Map)['id'];
  }

  Future<Response> _invalid(String message) {
    return res.status(422).json(ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: message,
        ));
  }
}
