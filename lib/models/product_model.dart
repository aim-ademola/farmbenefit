import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Product extends Model<Product> {
  Product() : super(() => Product());

  @override
  Table get table => schemaTable('products', [
        foreignIdColumn('company_id'),
        foreignIdColumn('category_id', nullable: true),
        stringColumn('sku', length: 120),
        stringColumn('barcode', nullable: true),
        stringColumn('name'),
        textColumn('description'),
        stringColumn('brand', nullable: true),
        stringColumn('unit', nullable: true),
        moneyColumn('cost_price'),
        moneyColumn('selling_price'),
        moneyColumn('reorder_level'),
        boolColumn('has_variants'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
