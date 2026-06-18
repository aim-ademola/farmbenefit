import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class ScannerEvent extends Model<ScannerEvent> {
  ScannerEvent() : super(() => ScannerEvent());

  @override
  Table get table => schemaTable('scanner_events', [
        foreignIdColumn('company_id'),
        foreignIdColumn('scanner_session_id'),
        stringColumn('barcode', length: 160),
        stringColumn('status', length: 40),
        dateTimeColumn('consumed_at'),
      ]);
}
