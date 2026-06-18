import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Store extends Model<Store> {
  Store() : super(() => Store());

  @override
  Table get table => schemaTable('stores', [
        foreignIdColumn('company_id'),
        stringColumn('name'),
        stringColumn('code', length: 80),
        stringColumn('type', length: 40),
        stringColumn('phone', nullable: true),
        stringColumn('email', nullable: true),
        textColumn('address'),
        foreignIdColumn('manager_user_id', nullable: true),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
