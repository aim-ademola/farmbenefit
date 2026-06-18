import 'package:flint_dart/flint_dart.dart';

import 'package:backend/core/api_response.dart';

class CompanyController extends Controller {
  Future<Response> show() async {
    final company = await _company();
    if (company == null) {
      return res.status(404).json(ApiResponse.error(
            code: 'NOT_FOUND',
            message: 'Company not found.',
          ));
    }

    return res.json(ApiResponse.success(
      data: company,
      message: 'Company profile retrieved successfully',
    ));
  }

  Future<Response> update() async {
    final body = await req.json();
    const allowedFields = {
      'name',
      'app_name',
      'app_tagline',
      'legal_name',
      'email',
      'phone',
      'address',
      'status',
    };
    final updates = <String, dynamic>{};
    for (final entry in body.entries) {
      if (allowedFields.contains(entry.key)) updates[entry.key] = entry.value;
    }

    if (updates.isNotEmpty) {
      final setClause = updates.keys.map((field) => '$field = ?').join(', ');
      await DB.query(
        '''
        UPDATE companies
        SET $setClause, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        ''',
        positionalParams: [...updates.values, _authContext['company_id']],
      );
    }

    return res.json(ApiResponse.success(
      data: await _company(),
      message: 'Company profile updated successfully',
    ));
  }

  Map<String, dynamic> get _authContext =>
      Map<String, dynamic>.from(req.get('auth') as Map);

  Future<Map<String, dynamic>?> _company() async {
    final rows = await DB.query(
      '''
      SELECT *
      FROM companies
      WHERE id = ?
        AND deleted_at IS NULL
      LIMIT 1
      ''',
      positionalParams: [_authContext['company_id']],
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }
}
