import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class StockTransferItem extends Model<StockTransferItem> {
  StockTransferItem() : super(() => StockTransferItem());

  @override
  Table get table => schemaTable('stock_transfer_items', [
        foreignIdColumn('company_id'),
        foreignIdColumn('stock_transfer_id'),
        foreignIdColumn('product_id'),
        foreignIdColumn('product_variant_id', nullable: true),
        moneyColumn('quantity_requested'),
        moneyColumn('quantity_approved'),
        moneyColumn('quantity_received'),
        moneyColumn('unit_cost'),
      ]);
}
