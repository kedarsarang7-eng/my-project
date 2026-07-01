// ============================================================================
// RestaurantOrderSnapshot — FoodOrder bridge
// ----------------------------------------------------------------------------
// Lives in a separate file so consumers that already hold a Drift-backed
// `FoodOrder` can build a `RestaurantOrderSnapshot` ergonomically, while the
// helper file (`restaurant_notification_service.dart`) stays free of any
// transitive Drift dependency.
//
// Test consumers don't import this file; production callers do.
// ============================================================================

import '../../data/models/food_order_model.dart';
import 'restaurant_notification_service.dart';

extension FoodOrderRestaurantSnapshot on FoodOrder {
  /// Convert a Drift-backed `FoodOrder` into the compact snapshot the
  /// notification helper consumes.
  RestaurantOrderSnapshot toRestaurantSnapshot() {
    return RestaurantOrderSnapshot(
      id: id,
      vendorId: vendorId,
      tableId: tableId,
      tableNumber: tableNumber,
      orderType: orderType.value,
      orderStatus: orderStatus.value,
      itemCount: items.length,
      grandTotal: grandTotal,
      orderTime: orderTime,
    );
  }
}
