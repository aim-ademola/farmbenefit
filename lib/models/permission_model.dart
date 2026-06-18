import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Permission extends Model<Permission> {
  Permission() : super(() => Permission());

  @override
  Table get table => schemaTable('permissions', [
        stringColumn('key', length: 120),
        stringColumn('module', length: 80),
        stringColumn('action', length: 80),
        textColumn('description'),
      ]);
}
