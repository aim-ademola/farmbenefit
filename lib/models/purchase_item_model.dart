import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class PurchaseItem extends Model<PurchaseItem> {
  PurchaseItem() : super(() => PurchaseItem());

  @override
  Table get table => schemaTable('purchase_items', [
        foreignIdColumn('company_id'),
        foreignIdColumn('purchase_order_id'),
        foreignIdColumn('product_id'),
        foreignIdColumn('product_variant_id', nullable: true),
        moneyColumn('quantity_ordered'),
        moneyColumn('quantity_received'),
        moneyColumn('unit_cost'),
        moneyColumn('line_total'),
      ]);
}
