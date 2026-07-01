// ============================================================
// Dukan Billing Software - Business Marketplace Providers
// Riverpod providers for order management state
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../providers/app_state_providers.dart';
import '../models/business_order_models.dart';
import '../services/business_marketplace_api.dart';

// ---------- API ----------

final businessMarketplaceApiProvider = Provider<BusinessMarketplaceApi>((ref) {
  return BusinessMarketplaceApi(sl<SessionManager>());
});

// ---------- ORDER FILTERS ----------

final orderFiltersProvider = StateProvider<OrderFilters>(
  (ref) => const OrderFilters(),
);

// ---------- ORDERS ----------

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, AsyncValue<PaginatedOrders>>(
      (ref) => OrdersNotifier(ref),
    );

class OrdersNotifier extends StateNotifier<AsyncValue<PaginatedOrders>> {
  final Ref _ref;
  late final BusinessMarketplaceApi _api = _ref.read(
    businessMarketplaceApiProvider,
  );

  OrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadOrders();
  }

  BusinessMarketplaceApi get api => _api;

  Future<void> loadOrders({int page = 1, int limit = 50}) async {
    try {
      state = const AsyncValue.loading();
      final filters = _ref.read(orderFiltersProvider);
      final result = await api.getOrders(
        filters: filters,
        page: page,
        limit: limit,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => loadOrders();

  Future<void> updateOrderStatus(
    String orderId, {
    required BusinessOrderStatus status,
    String? note,
    String? assignedPartnerId,
  }) async {
    try {
      await api.updateOrderStatus(
        orderId,
        status: status,
        note: note,
        assignedPartnerId: assignedPartnerId,
      );

      // Refresh orders to reflect the update
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> assignDeliveryPartner(String orderId, String partnerId) async {
    try {
      await api.assignDeliveryPartner(orderId, partnerId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

// ---------- SELECTED ORDER ----------

final selectedOrderIdProvider = StateProvider<String?>((ref) => null);

final selectedOrderProvider =
    FutureProvider.family<BusinessOrderDetail, String>((ref, orderId) async {
      final api = ref.watch(businessMarketplaceApiProvider);
      return api.getOrderDetails(orderId);
    });

// ---------- ORDER STATS ----------

final orderStatsProvider = FutureProvider<OrderStats>((ref) async {
  final api = ref.watch(businessMarketplaceApiProvider);
  return api.getOrderStats();
});

// ---------- DELIVERY PARTNERS ----------

final deliveryPartnersProvider = FutureProvider<List<DeliveryPartnerInfo>>((
  ref,
) async {
  final api = ref.watch(businessMarketplaceApiProvider);
  return api.getDeliveryPartners(isActive: true);
});

// ---------- REAL-TIME ORDER UPDATES ----------

final newOrderStreamProvider = StreamProvider<BusinessOrder>((ref) {
  // This would connect to WebSocket and listen for new orders
  return Stream.empty();
});

// ---------- INVENTORY SYNC ----------

final inventorySyncProvider =
    StateNotifierProvider<InventorySyncNotifier, AsyncValue<void>>(
      (ref) => InventorySyncNotifier(ref),
    );

class InventorySyncNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  late final BusinessMarketplaceApi _api = _ref.read(
    businessMarketplaceApiProvider,
  );

  InventorySyncNotifier(this._ref) : super(const AsyncValue.data(null));

  BusinessMarketplaceApi get api => _api;

  Future<void> syncProducts(List<InventorySyncItem> products) async {
    try {
      state = const AsyncValue.loading();
      await api.syncInventory(products);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStock(String productId, int newStock) async {
    try {
      await api.updateProductStock(productId, newStock);
    } catch (e) {
      rethrow;
    }
  }
}

// ---------- MARKETPLACE ENABLED ----------

final allowedMarketplaceCategories = [
  'grocery',
  'hardware',
  'pharmacy',
  'restaurant',
  'mobile_shop',
  'computer_shop',
];

final isMarketplaceEnabledProvider = Provider<bool>((ref) {
  final businessType = ref.watch(businessTypeProvider).type.name;
  return allowedMarketplaceCategories.contains(businessType);
});

// ---------- UI STATE ----------

final orderViewModeProvider = StateProvider<OrderViewMode>(
  (ref) => OrderViewMode.grid,
);

enum OrderViewMode { list, grid, kanban }

final showExpressOnlyProvider = StateProvider<bool>((ref) => false);

final orderSearchQueryProvider = StateProvider<String>((ref) => '');

// ---------- COMPUTED ----------

final filteredOrdersProvider = Provider<AsyncValue<List<BusinessOrder>>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final showExpressOnly = ref.watch(showExpressOnlyProvider);
  final searchQuery = ref.watch(orderSearchQueryProvider).toLowerCase();

  return ordersAsync.when(
    data: (paginated) {
      var orders = paginated.orders;

      if (showExpressOnly) {
        orders = orders.where((o) => o.isExpress == true).toList();
      }

      if (searchQuery.isNotEmpty) {
        orders = orders
            .where(
              (o) =>
                  o.orderId.toLowerCase().contains(searchQuery) ||
                  o.customer.name.toLowerCase().contains(searchQuery) ||
                  o.customer.phone.contains(searchQuery),
            )
            .toList();
      }

      return AsyncValue.data(orders);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ---------- PENDING ACTIONS COUNT ----------

final pendingActionsCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(ordersProvider);

  return ordersAsync.when(
    data: (paginated) => paginated.orders
        .where(
          (o) =>
              o.status == BusinessOrderStatus.placed ||
              o.status == BusinessOrderStatus.accepted ||
              o.status == BusinessOrderStatus.preparing,
        )
        .length,
    loading: () => 0,
    error: (e, _) => 0,
  );
});
