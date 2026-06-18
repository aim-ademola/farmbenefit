import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class Sale extends Model<Sale> {
  Sale() : super(() => Sale());

  @override
  Table get table => schemaTable('sales', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id'),
        foreignIdColumn('customer_id', nullable: true),
        stringColumn('sale_number', length: 120),
        stringColumn('type', length: 40),
        stringColumn('status', length: 60),
        moneyColumn('subtotal'),
        moneyColumn('discount_total'),
        moneyColumn('tax_total'),
        moneyColumn('grand_total'),
        moneyColumn('amount_paid'),
        moneyColumn('balance_due'),
        stringColumn('payment_method', length: 40, nullable: true),
        stringColumn('payment_status', length: 60),
        foreignIdColumn('sold_by'),
        dateTimeColumn('completed_at'),
      ]);
}
