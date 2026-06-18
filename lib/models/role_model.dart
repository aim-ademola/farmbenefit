import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Role extends Model<Role> {
  Role() : super(() => Role());

  @override
  Table get table => schemaTable('roles', [
        foreignIdColumn('company_id', nullable: true),
        stringColumn('name'),
        stringColumn('key', length: 80),
        stringColumn('scope', length: 40),
        textColumn('description'),
        boolColumn('is_system'),
      ]);
}
