import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Inventory extends Model<Inventory> {
  Inventory() : super(() => Inventory());

  @override
  Table get table => schemaTable('inventory', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('product_id'),
        foreignIdColumn('product_variant_id', nullable: true),
        moneyColumn('quantity_on_hand'),
        moneyColumn('quantity_reserved'),
        moneyColumn('quantity_available'),
        moneyColumn('average_cost'),
        moneyColumn('reorder_level'),
        dateTimeColumn('last_movement_at'),
      ]);
}
