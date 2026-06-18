import 'package:flint_dart/schema.dart';

import 'package:backend/models/inventoryhq_models.dart';
import 'package:backend/models/user_model.dart';

final inventoryHqTables = <Table>[
  Company().table,
  Store().table,
  Role().table,
  Permission().table,
  RolePermission().table,
  User().table,
  Category().table,
  Product().table,
  ProductVariant().table,
  Inventory().table,
  InventoryTransaction().table,
  StockTransfer().table,
  StockTransferItem().table,
  Customer().table,
  Sale().table,
  SaleItem().table,
  ScannerSession().table,
  ScannerEvent().table,
  CreditRequest().table,
  CreditApproval().table,
  StaffCompensation().table,
  Supplier().table,
  PurchaseOrder().table,
  PurchaseItem().table,
  NotificationModel().table,
  AuditLog().table,
];
