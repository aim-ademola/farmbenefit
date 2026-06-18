import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class CustomerContactVerification extends Model<CustomerContactVerification> {
  CustomerContactVerification() : super(() => CustomerContactVerification());

  @override
  Table get table => schemaTable('customer_contact_verifications', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('requested_by'),
        stringColumn('channel', length: 40),
        stringColumn('contact'),
        stringColumn('code_hash'),
        intColumn('attempts'),
        dateTimeColumn('verified_at'),
        dateTimeColumn('expires_at', nullable: false),
      ]);
}
