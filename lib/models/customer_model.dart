import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Customer extends Model<Customer> {
  Customer() : super(() => Customer());

  @override
  Table get table => schemaTable('customers', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        stringColumn('name'),
        stringColumn('phone', nullable: true),
        stringColumn('email', nullable: true),
        boolColumn('phone_verified'),
        boolColumn('email_verified'),
        dateTimeColumn('phone_verified_at'),
        dateTimeColumn('email_verified_at'),
        textColumn('address'),
        moneyColumn('credit_limit'),
        moneyColumn('outstanding_balance'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
