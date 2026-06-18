import 'dart:isolate';

import 'package:flint_dart/schema.dart';
import 'package:backend/database/inventoryhq_tables.dart';

void main(_, SendPort? sendPort) {
  runTableRegistry(inventoryHqTables, _, sendPort);
}
