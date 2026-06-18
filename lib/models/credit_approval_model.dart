import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class CreditApproval extends Model<CreditApproval> {
  CreditApproval() : super(() => CreditApproval());

  @override
  Table get table => schemaTable('credit_approvals', [
        foreignIdColumn('company_id'),
        foreignIdColumn('credit_request_id'),
        foreignIdColumn('approver_user_id'),
        stringColumn('approver_role_key', length: 80),
        stringColumn('decision', length: 40),
        stringColumn('status_before', length: 60),
        stringColumn('status_after', length: 60),
        textColumn('comments'),
      ]);
}
