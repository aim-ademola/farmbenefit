import 'package:flint_dart/flint_dart.dart';

class SalesRealtimeService {
  static const namespace = '/api/v1/ws/sales';
  static const changedEvent = 'sales.changed';
  static const inventoryChangedEvent = 'inventory.changed';
  static const productsChangedEvent = 'products.changed';

  static String companyRoom(Object? companyId) => 'company:$companyId';

  static void saleChanged({
    required String action,
    required Object? companyId,
    required Object? saleId,
    Object? storeId,
  }) {
    if (companyId == null) return;

    WebSocketManager.instance.emitToPathRoom(
      namespace,
      companyRoom(companyId),
      changedEvent,
      {
        'action': action,
        'sale_id': saleId,
        'company_id': companyId,
        'store_id': storeId,
        'at': DateTime.now().toIso8601String(),
      },
    );
  }

  static void inventoryChanged({
    required Object? companyId,
    required Object? storeId,
    required Object? productId,
    Object? variantId,
    Object? inventoryId,
    Object? quantityAvailable,
    Object? quantityOnHand,
    Object? reason,
  }) {
    if (companyId == null) return;

    WebSocketManager.instance.emitToPathRoom(
      namespace,
      companyRoom(companyId),
      inventoryChangedEvent,
      {
        'company_id': companyId,
        'store_id': storeId,
        'product_id': productId,
        'product_variant_id': variantId,
        'inventory_id': inventoryId,
        'quantity_available': quantityAvailable,
        'quantity_on_hand': quantityOnHand,
        'reason': reason,
        'at': DateTime.now().toIso8601String(),
      },
    );
  }

  static void productChanged({
    required String action,
    required Object? companyId,
    required Object? productId,
    Object? variantId,
  }) {
    if (companyId == null) return;

    WebSocketManager.instance.emitToPathRoom(
      namespace,
      companyRoom(companyId),
      productsChangedEvent,
      {
        'action': action,
        'company_id': companyId,
        'product_id': productId,
        'product_variant_id': variantId,
        'at': DateTime.now().toIso8601String(),
      },
    );
  }
}
