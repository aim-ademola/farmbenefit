import 'package:flint_dart/model.dart';
import 'package:flint_dart/schema.dart';

import 'package:backend/database/schema_helpers.dart';

class NotificationModel extends Model<NotificationModel> {
  NotificationModel() : super(() => NotificationModel());

  @override
  Table get table => schemaTable('notifications', [
        foreignIdColumn('company_id'),
        foreignIdColumn('store_id', nullable: true),
        foreignIdColumn('user_id'),
        stringColumn('type', length: 100),
        stringColumn('channel', length: 40),
        stringColumn('title'),
        textColumn('message', nullable: false),
        jsonColumn('data_json'),
        dateTimeColumn('read_at'),
        dateTimeColumn('sent_at'),
      ]);
}
