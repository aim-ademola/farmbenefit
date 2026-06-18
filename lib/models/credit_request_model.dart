import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class CreditRequest extends Model<CreditRequest> {
  CreditRequest() : super(() => CreditRequest());

  @override
  Table get table => schemaTable('credit_requests', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('sale_id'),
        foreignIdColumn('customer_id'),
        foreignIdColumn('requested_by'),
        moneyColumn('amount'),
        stringColumn('status', length: 60),
        textColumn('request_note'),
        stringColumn('current_approver_role', length: 80, nullable: true),
        dateTimeColumn('final_decision_at'),
      ]);
}
