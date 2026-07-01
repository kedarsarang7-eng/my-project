// ============================================================================
// restaurant_alert_counts_provider.dart — Live restaurant dashboard alerts.
// ----------------------------------------------------------------------------
// StreamProvider that watches pending/active food orders and computes:
//   • activeOrders  — orders with status IN [accepted, cooking, ready, served]
//   • kitchenQueue  — orders with status IN [pending, accepted]
//   • lowIngredients — reuses the generic alertCountsProvider's lowStock count
//
// _Requirements: 2.5_
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../dashboard/v2/widgets/business_alerts_widget.dart';
import '../data/models/food_order_model.dart';
import '../data/repositories/food_order_repository.dart';

/// Snapshot of restaurant dashboard alert counts, derived from the live
/// order stream and the shared inventory alert provider.
class RestaurantAlertCounts {
  final int activeOrders;
  final int kitchenQueue;
  final int lowIngredients;

  const RestaurantAlertCounts({
    required this.activeOrders,
    required this.kitchenQueue,
    required this.lowIngredients,
  });

  static const zero = RestaurantAlertCounts(
    activeOrders: 0,
    kitchenQueue: 0,
    lowIngredients: 0,
  );
}

/// Statuses that count as "active" — orders currently being worked on or
/// awaiting pickup/delivery after preparation.
const _activeStatuses = {
  FoodOrderStatus.accepted,
  FoodOrderStatus.cooking,
  FoodOrderStatus.ready,
  FoodOrderStatus.served,
};

/// Statuses that count as "kitchen queue" — orders waiting to be prepared.
const _kitchenQueueStatuses = {
  FoodOrderStatus.pending,
  FoodOrderStatus.accepted,
};

/// StreamProvider that emits live [RestaurantAlertCounts] for the current
/// restaurant tenant. Watches `FoodOrderRepository.watchPendingOrders` for
/// order-status counts and reads `alertCountsProvider` for low-stock count.
final restaurantAlertCountsProvider =
    StreamProvider.autoDispose<RestaurantAlertCounts>((ref) async* {
      final session = sl<SessionManager>();
      final vendorId = session.currentBusinessId ?? session.userId ?? 'SYSTEM';

      final orderRepo = sl<FoodOrderRepository>();

      // Subscribe to the generic alertCountsProvider for lowStock.
      // We watch it reactively so our stream re-emits when stock data changes.
      final alertCounts = ref
          .watch(alertCountsProvider)
          .maybeWhen(data: (counts) => counts, orElse: () => <String, int>{});
      final lowIngredients = alertCounts['lowStock'] ?? 0;

      // Watch vendor orders that are in active/pending states.
      // watchPendingOrders returns orders with statuses: pending, accepted,
      // cooking, ready — which covers both our active and kitchen queue sets
      // except 'served'. We use watchVendorOrders for full coverage.
      await for (final orders in orderRepo.watchVendorOrders(vendorId)) {
        final activeOrders = orders
            .where((o) => _activeStatuses.contains(o.orderStatus))
            .length;
        final kitchenQueue = orders
            .where((o) => _kitchenQueueStatuses.contains(o.orderStatus))
            .length;

        yield RestaurantAlertCounts(
          activeOrders: activeOrders,
          kitchenQueue: kitchenQueue,
          lowIngredients: lowIngredients,
        );
      }
    });
