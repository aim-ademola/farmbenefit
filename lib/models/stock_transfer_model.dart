import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class StockTransfer extends Model<StockTransfer> {
  StockTransfer() : super(() => StockTransfer());

  @override
  Table get table => schemaTable('stock_transfers', [
        foreignIdColumn('company_id'),
        foreignIdColumn('source_store_id'),
        foreignIdColumn('destination_store_id'),
        stringColumn('transfer_number', length: 120),
        stringColumn('status', length: 60),
        textColumn('reason'),
        foreignIdColumn('created_by'),
        foreignIdColumn('approved_by', nullable: true),
        foreignIdColumn('received_by', nullable: true),
        dateTimeColumn('approved_at'),
        dateTimeColumn('received_at'),
      ]);
}
