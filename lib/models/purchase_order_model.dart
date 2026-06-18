import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class PurchaseOrder extends Model<PurchaseOrder> {
  PurchaseOrder() : super(() => PurchaseOrder());

  @override
  Table get table => schemaTable('purchase_orders', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('supplier_id'),
        stringColumn('po_number', length: 120),
        stringColumn('status', length: 60),
        moneyColumn('subtotal'),
        moneyColumn('tax_total'),
        moneyColumn('discount_total'),
        moneyColumn('grand_total'),
        dateTimeColumn('expected_delivery_date'),
        foreignIdColumn('created_by'),
      ]);
}
