import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class StaffCompensation extends Model<StaffCompensation> {
  StaffCompensation() : super(() => StaffCompensation());

  @override
  Table get table => schemaTable('staff_compensations', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('user_id'),
        moneyColumn('monthly_salary'),
        stringColumn('currency', length: 20),
        stringColumn('status', length: 40),
      ]);
}
