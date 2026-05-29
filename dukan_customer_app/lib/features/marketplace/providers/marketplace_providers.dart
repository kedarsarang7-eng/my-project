// ============================================================
// Dukan Customer App - Marketplace Providers
// Riverpod state management for marketplace features
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/marketplace_models.dart';
import '../services/marketplace_api_service.dart';
import '../services/marketplace_websocket_service.dart';

// ---------- API SERVICE ----------

final marketplaceApiProvider = Provider<MarketplaceApiService>((ref) {
  return ref.watch(marketplaceApiServiceProvider);
});

// ---------- CURRENT BUSINESS ----------

final currentBusinessIdProvider = StateProvider<String?>((ref) => null);

// ---------- STORE PROFILE ----------

final storeProfileProvider = FutureProvider.family<StoreProfile, String>(
  (ref, businessId) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.getStoreProfile(businessId);
  },
);

// ---------- CONNECTION STATUS ----------

final connectionStatusProvider = FutureProvider.family<StoreConnection, String>(
  (ref, businessId) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.getConnectionStatus(businessId);
  },
);

// ---------- PRODUCTS ----------

final productFiltersProvider = StateProvider<ProductSearchFilters>(
  (ref) => const ProductSearchFilters(),
);

final productsProvider = FutureProvider.family<ProductSearchResult, String>(
  (ref, businessId) async {
    final api = ref.watch(marketplaceApiProvider);
    final filters = ref.watch(productFiltersProvider);
    return api.getProducts(businessId, filters: filters);
  },
);

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final productSearchProvider = FutureProvider.family<ProductSearchResult, String>(
  (ref, businessId) async {
    final api = ref.watch(marketplaceApiProvider);
    final query = ref.watch(productSearchQueryProvider);
    if (query.isEmpty) return const ProductSearchResult(products: []);
    return api.searchProducts(businessId, query: query);
  },
);

final selectedProductProvider = FutureProvider.family<ProductDetail, ({String businessId, String productId})>(
  (ref, params) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.getProduct(params.businessId, params.productId);
  },
);

// ---------- CART ----------

final cartProvider = StateNotifierProvider.family<CartNotifier, AsyncValue<Cart>, String>(
  (ref, businessId) => CartNotifier(ref, businessId),
);

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  final Ref _ref;
  final String _businessId;
  MarketplaceApiService? _api;

  CartNotifier(this._ref, this._businessId) : super(const AsyncValue.loading()) {
    _loadCart();
  }

  MarketplaceApiService get api {
    _api ??= _ref.read(marketplaceApiProvider);
    return _api!;
  }

  Future<void> _loadCart() async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.getCart(_businessId);
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addItem({
    required String productId,
    required int quantity,
    String? prescriptionUrl,
    String? cookingInstructions,
  }) async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.addToCart(
        _businessId,
        productId: productId,
        quantity: quantity,
        prescriptionUrl: prescriptionUrl,
        cookingInstructions: cookingInstructions,
      );
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.updateCartItem(_businessId, productId, quantity: quantity);
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeItem(String productId) async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.removeFromCart(_businessId, productId);
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> clear() async {
    try {
      state = const AsyncValue.loading();
      await api.clearCart(_businessId);
      state = const AsyncValue.data(Cart());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> applyCoupon(String code) async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.applyCoupon(_businessId, code);
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeCoupon() async {
    try {
      state = const AsyncValue.loading();
      final cart = await api.removeCoupon(_businessId);
      state = AsyncValue.data(cart);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _loadCart();
}

final cartItemCountProvider = Provider.family<int, String>(
  (ref, businessId) {
    final cartAsync = ref.watch(cartProvider(businessId));
    return cartAsync.when(
      data: (cart) => cart.itemCount,
      loading: () => 0,
      error: (_, _) => 0,
    );
  },
);

// ---------- ORDERS ----------

final ordersProvider = FutureProvider.family<List<Order>, String?>(
  (ref, businessId) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.getOrderHistory();
  },
);

final orderDetailProvider = FutureProvider.family<OrderDetail, ({String businessId, String orderId})>(
  (ref, params) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.getOrderDetails(params.businessId, params.orderId);
  },
);

final orderTrackingProvider = FutureProvider.family<OrderDetail, ({String businessId, String orderId})>(
  (ref, params) async {
    final api = ref.watch(marketplaceApiProvider);
    return api.trackOrder(params.businessId, params.orderId);
  },
);

// ---------- WEBSOCKET ----------

final marketplaceWsProvider = Provider<MarketplaceWebSocketService>((ref) {
  return MarketplaceWebSocketService();
});

final wsConnectionStatusProvider = StreamProvider<bool>((ref) {
  final ws = ref.watch(marketplaceWsProvider);
  return ws.connectionStatusStream;
});

final orderUpdatesProvider = StreamProvider.family<OrderUpdatePayload, String>(
  (ref, businessId) {
    final ws = ref.watch(marketplaceWsProvider);
    return ws.orderUpdatesStream;
  },
);

// ---------- CHECKOUT ----------

final selectedAddressIdProvider = StateProvider<String?>((ref) => null);

final paymentMethodProvider = StateProvider<PaymentMethod>((ref) => PaymentMethod.cod);

final isExpressDeliveryProvider = StateProvider<bool>((ref) => false);

final orderNotesProvider = StateProvider<String>((ref) => '');

// ---------- UI STATE ----------

final cartExpandedProvider = StateProvider<bool>((ref) => false);

final productGridViewProvider = StateProvider<bool>((ref) => true);

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ---------- REFRESH ----------

final refreshTriggerProvider = StateProvider<int>((ref) => 0);

void refreshMarketplace(Ref ref) {
  ref.read(refreshTriggerProvider.notifier).state++;
}
