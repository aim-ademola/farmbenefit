import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class ScannerSession extends Model<ScannerSession> {
  ScannerSession() : super(() => ScannerSession());

  @override
  Table get table => schemaTable('scanner_sessions', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id', nullable: true),
        foreignIdColumn('created_by'),
        stringColumn('token'),
        stringColumn('status', length: 40),
        dateTimeColumn('last_seen_at'),
        dateTimeColumn('expires_at'),
      ]);
}
