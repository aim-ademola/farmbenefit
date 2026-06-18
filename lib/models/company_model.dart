import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Company extends Model<Company> {
  Company() : super(() => Company());

  @override
  Table get table => schemaTable('companies', [
        stringColumn('name'),
        stringColumn('app_name', nullable: true),
        stringColumn('app_tagline', nullable: true),
        stringColumn('legal_name', nullable: true),
        stringColumn('email', nullable: true),
        stringColumn('phone', nullable: true),
        textColumn('address'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
