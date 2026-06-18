import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Category extends Model<Category> {
  Category() : super(() => Category());

  @override
  Table get table => schemaTable('categories', [
        foreignIdColumn('company_id'),
        foreignIdColumn('parent_id', nullable: true),
        stringColumn('name'),
        textColumn('description'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
