import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class InventoryTransaction extends Model<InventoryTransaction> {
  InventoryTransaction() : super(() => InventoryTransaction());

  @override
  Table get table => schemaTable('inventory_transactions', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('product_id'),
        foreignIdColumn('product_variant_id', nullable: true),
        stringColumn('type', length: 80),
        moneyColumn('quantity'),
        moneyColumn('unit_cost'),
        moneyColumn('quantity_before'),
        moneyColumn('quantity_after'),
        stringColumn('reference_type', nullable: true),
        foreignIdColumn('reference_id', nullable: true),
        textColumn('reason'),
        foreignIdColumn('created_by'),
      ]);
}
