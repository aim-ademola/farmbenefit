import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class SaleItem extends Model<SaleItem> {
  SaleItem() : super(() => SaleItem());

  @override
  Table get table => schemaTable('sale_items', [
        foreignIdColumn('company_id'),
        foreignIdColumn('sale_id'),
        foreignIdColumn('product_id'),
        foreignIdColumn('product_variant_id', nullable: true),
        stringColumn('sku_snapshot', length: 120),
        stringColumn('name_snapshot'),
        moneyColumn('quantity'),
        moneyColumn('unit_price'),
        moneyColumn('unit_cost'),
        moneyColumn('discount_amount'),
        moneyColumn('tax_amount'),
        moneyColumn('line_total'),
      ]);
}
