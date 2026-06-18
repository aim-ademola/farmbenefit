import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class AuditLog extends Model<AuditLog> {
  AuditLog() : super(() => AuditLog());

  @override
  Table get table => schemaTable('audit_logs', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id', nullable: true),
        foreignIdColumn('user_id', nullable: true),
        stringColumn('action', length: 120),
        stringColumn('entity_type', length: 120),
        foreignIdColumn('entity_id', nullable: true),
        jsonColumn('before_data_json'),
        jsonColumn('after_data_json'),
        stringColumn('ip_address', length: 80, nullable: true),
        textColumn('user_agent'),
      ]);
}
