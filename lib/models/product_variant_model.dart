import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class ProductVariant extends Model<ProductVariant> {
  ProductVariant() : super(() => ProductVariant());

  @override
  Table get table => schemaTable('product_variants', [
        foreignIdColumn('company_id'),
        foreignIdColumn('product_id'),
        stringColumn('sku', length: 120),
        stringColumn('barcode', nullable: true),
        stringColumn('variant_name'),
        jsonColumn('attributes_json'),
        moneyColumn('cost_price'),
        moneyColumn('selling_price'),
        moneyColumn('reorder_level'),
        stringColumn('status', length: 40),
        deletedAtColumn(),
      ]);
}
