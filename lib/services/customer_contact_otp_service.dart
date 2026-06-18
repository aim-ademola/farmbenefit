import 'dart:math';

import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/helper.dart';

class CustomerContactOtpService {
  static const channels = {'email', 'whatsapp'};

  String normalizeContact({
    required String channel,
    required String contact,
  }) {
    final trimmed = contact.trim();
    if (channel == 'email') return trimmed.toLowerCase();
    return trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<Map<String, dynamic>> requestOtp({
    required Object? companyId,
    required Object? storeId,
    required Object? requestedBy,
    required String channel,
    required String contact,
  }) async {
    final normalized = normalizeContact(channel: channel, contact: contact);
    final code = _code();

    var delivery = 'pending_provider';
    if (channel == 'email') {
      try {
        await Mail()
            .to(normalized)
            .subject('InventoryHQ customer verification code')
            .text(
                'Your InventoryHQ verification code is $code. It expires in 10 minutes.')
            .sendMail();
        delivery = 'sent';
      } catch (_) {
        delivery = 'dev_fallback';
      }
    }

    await DB.query(
      '''
      INSERT INTO customer_contact_verifications
        (id, company_id, store_id, requested_by, channel, contact, code_hash,
         attempts, expires_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 10 MINUTE),
              CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ''',
      positionalParams: [
        Str.uuid(),
        companyId,
        storeId,
        requestedBy,
        channel,
        normalized,
        code,
        0,
      ],
    );

    return {
      'channel': channel,
      'contact': normalized,
      'expires_in_seconds': 600,
      'delivery': delivery,
      'dev_code': code,
    };
  }

  Future<bool> verifyOtp({
    required Object? companyId,
    required Object? storeId,
    required String channel,
    required String contact,
    required String code,
  }) async {
    final normalized = normalizeContact(channel: channel, contact: contact);
    final rows = await DB.query(
      '''
      SELECT *
      FROM customer_contact_verifications
      WHERE company_id = ?
        AND store_id = ?
        AND channel = ?
        AND contact = ?
        AND verified_at IS NULL
        AND expires_at > CURRENT_TIMESTAMP
      ORDER BY created_at DESC
      LIMIT 1
      ''',
      positionalParams: [companyId, storeId, channel, normalized],
    );
    if (rows.isEmpty) return false;

    final verification = Map<String, dynamic>.from(rows.first as Map);
    final attempts =
        int.tryParse(verification['attempts']?.toString() ?? '') ?? 0;
    if (attempts >= 5) return false;

    await DB.query(
      '''
      UPDATE customer_contact_verifications
      SET attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [verification['id'], companyId],
    );

    if (verification['code_hash']?.toString() != code.trim()) return false;

    await DB.query(
      '''
      UPDATE customer_contact_verifications
      SET verified_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND company_id = ?
      ''',
      positionalParams: [verification['id'], companyId],
    );
    return true;
  }

  Future<bool> hasVerifiedContact({
    required Object? companyId,
    required Object? storeId,
    required String channel,
    required String contact,
  }) async {
    final normalized = normalizeContact(channel: channel, contact: contact);
    final rows = await DB.query(
      '''
      SELECT id
      FROM customer_contact_verifications
      WHERE company_id = ?
        AND store_id = ?
        AND channel = ?
        AND contact = ?
        AND verified_at IS NOT NULL
      ORDER BY verified_at DESC
      LIMIT 1
      ''',
      positionalParams: [companyId, storeId, channel, normalized],
    );
    return rows.isNotEmpty;
  }

  String _code() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
