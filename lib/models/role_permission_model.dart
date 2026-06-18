import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class RolePermission extends Model<RolePermission> {
  RolePermission() : super(() => RolePermission());

  @override
  Table get table => schemaTable('role_permissions', [
        foreignIdColumn('role_id'),
        foreignIdColumn('permission_id'),
      ]);
}
