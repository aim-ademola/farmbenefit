import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Supplier extends Model<Supplier> {
  Supplier() : super(() => Supplier());

  @override
  Table get table => schemaTable('suppliers', [
        foreignIdColumn('company_id'),
        stringColumn('name'),
        stringColumn('contact_person', nullable: true),
        stringColumn('phone', nullable: true),
        stringColumn('email', nullable: true),
        textColumn('address'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
