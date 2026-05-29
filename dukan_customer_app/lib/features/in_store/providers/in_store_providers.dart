// ============================================================================
// In-Store Self Scan & Checkout — Riverpod Providers
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/in_store_models.dart';
import '../services/in_store_api_service.dart';
import '../services/cart_cache_service.dart';

// ── Session state ─────────────────────────────────────────────────────────────

const _kSessionCacheKey = 'in_store_active_session';

final activeSessionProvider =
    StateNotifierProvider<ActiveSessionNotifier, AsyncValue<InStoreSession?>>(
  (ref) => ActiveSessionNotifier(ref),
);

class ActiveSessionNotifier
    extends StateNotifier<AsyncValue<InStoreSession?>> {
  final Ref _ref;
  Timer? _syncTimer;
  final _cartCache = CartCacheService();

  ActiveSessionNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _restoreSession();
  }

  InStoreApiService get _api => _ref.read(inStoreApiServiceProvider);

  // ── Session lifecycle ─────────────────────────────────────────────────────

  Future<void> startSession(String storeId, String tenantId) async {
    state = const AsyncValue.loading();
    try {
      final session = await _api.startSession(
        storeId: storeId,
        tenantId: tenantId,
      );
      state = AsyncValue.data(session);
      await _persistSession(session.sessionId, storeId, tenantId);
      _startSyncTimer();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> abandonSession() async {
    final session = state.valueOrNull;
    if (session == null) return;
    try {
      await _api.abandonSession(session.sessionId);
    } catch (_) {}
    _syncTimer?.cancel();
    state = const AsyncValue.data(null);
    await _clearPersistedSession();
    await _cartCache.clearCart();
  }

  // ── Cart management ───────────────────────────────────────────────────────

  Future<void> addOrIncrementItem(ScannedProduct product) async {
    final session = state.valueOrNull;
    if (session == null) return;

    final existing = session.cartItems
        .where((i) => i.barcode == product.barcode)
        .firstOrNull;

    List<CartItem> newItems;
    if (existing != null) {
      newItems = session.cartItems
          .map((i) => i.barcode == product.barcode
              ? i.withQuantity(i.quantity + 1)
              : i)
          .toList();
    } else {
      newItems = [...session.cartItems, CartItem.fromScannedProduct(product)];
    }

    await _syncCart(session, newItems);
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    final session = state.valueOrNull;
    if (session == null) return;

    if (quantity <= 0) {
      await removeItem(productId);
      return;
    }

    final newItems = session.cartItems
        .map((i) => i.productId == productId ? i.withQuantity(quantity) : i)
        .toList();

    await _syncCart(session, newItems);
  }

  Future<void> removeItem(String productId) async {
    final session = state.valueOrNull;
    if (session == null) return;

    final newItems =
        session.cartItems.where((i) => i.productId != productId).toList();

    await _syncCart(session, newItems);
  }

  Future<void> _syncCart(
      InStoreSession session, List<CartItem> newItems) async {
    // Optimistic update
    state = AsyncValue.data(session.copyWith(cartItems: newItems));

    // Persist to Hive so cart survives app kill
    await _cartCache.saveCart(
      sessionId: session.sessionId,
      storeId: session.storeId,
      items: newItems,
    );

    try {
      final summary = await _api.updateCart(session.sessionId, newItems);
      state = AsyncValue.data(session.copyWith(
        cartItems: newItems,
        summary: summary,
      ));
    } catch (_) {
      // On sync failure: keep optimistic state, will retry on next timer tick
    }
  }

  // ── Session recovery ───────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kSessionCacheKey);
      if (cached == null) return;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      final sessionId = data['sessionId'] as String?;
      if (sessionId == null) return;

      // Try to reload from server
      try {
        final session = await _api.getSession(sessionId);
        if (session.isActive) {
          state = AsyncValue.data(session);
          _startSyncTimer();
        } else {
          await _clearPersistedSession();
        }
      } catch (_) {
        await _clearPersistedSession();
      }
    } catch (_) {}
  }

  Future<void> _persistSession(
      String sessionId, String storeId, String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSessionCacheKey,
        jsonEncode({
          'sessionId': sessionId,
          'storeId': storeId,
          'tenantId': tenantId,
        }));
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionCacheKey);
  }

  // ── Periodic server sync (fallback when WS disconnected) ─────────────────

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final session = state.valueOrNull;
      if (session == null || !session.isActive) {
        _syncTimer?.cancel();
        return;
      }
      try {
        final fresh = await _api.getSession(session.sessionId);
        if (mounted) state = AsyncValue.data(fresh);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

// ── Convenience selectors ─────────────────────────────────────────────────────

final cartItemsProvider = Provider<List<CartItem>>((ref) {
  return ref.watch(activeSessionProvider).valueOrNull?.cartItems ?? [];
});

final cartSummaryProvider = Provider<CartSummary?>((ref) {
  final session = ref.watch(activeSessionProvider).valueOrNull;
  if (session == null || session.cartItems.isEmpty) return null;

  // Local calculation while server sync is in flight
  return session.summary ?? _localCartSummary(session.cartItems);
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartItemsProvider).fold(0, (sum, i) => sum + i.quantity);
});

CartSummary _localCartSummary(List<CartItem> items) {
  int subtotal = 0;
  int discount = 0;
  int gstTotal = 0;
  int count = 0;
  for (final item in items) {
    subtotal += item.sellingPrice * item.quantity;
    discount += (item.mrp - item.sellingPrice) * item.quantity;
    gstTotal += item.gstAmountCents * item.quantity;
    count += item.quantity;
  }
  return CartSummary(
    subtotalCents: subtotal,
    discountCents: discount,
    gstBreakup: const [],
    totalGstCents: gstTotal,
    totalCents: subtotal,
    itemCount: count,
  );
}

// ── Checkout ──────────────────────────────────────────────────────────────────

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, AsyncValue<CheckoutResponse?>>(
  (ref) => CheckoutNotifier(ref),
);

class CheckoutNotifier
    extends StateNotifier<AsyncValue<CheckoutResponse?>> {
  final Ref _ref;
  final _cartCache = CartCacheService();

  CheckoutNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<CheckoutResponse?> checkout() async {
    final session =
        _ref.read(activeSessionProvider).valueOrNull;
    if (session == null) return null;

    state = const AsyncValue.loading();
    try {
      final result =
          await _ref.read(inStoreApiServiceProvider).checkout(session.sessionId);
      state = AsyncValue.data(result);
      await _cartCache.clearCart();
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

// ── Exit QR ───────────────────────────────────────────────────────────────────

final exitQRProvider =
    StateNotifierProvider<ExitQRNotifier, ExitQRData?>(
  (ref) => ExitQRNotifier(ref),
);

class ExitQRNotifier extends StateNotifier<ExitQRData?> {
  final Ref _ref;
  Timer? _expiryTimer;

  ExitQRNotifier(this._ref) : super(null);

  void setFromWsPayload(String exitQRJson) {
    try {
      final qr = ExitQRData.fromJson(exitQRJson);
      state = qr;
      _scheduleExpiryRefresh(qr);
    } catch (_) {}
  }

  Future<void> refresh() async {
    final session =
        _ref.read(activeSessionProvider).valueOrNull;
    if (session == null) return;
    try {
      final rawJson =
          await _ref.read(inStoreApiServiceProvider).refreshExitQR(
                session.sessionId,
              );
      final qr = ExitQRData.fromJson(rawJson);
      state = qr;
      _scheduleExpiryRefresh(qr);
    } catch (_) {}
  }

  void _scheduleExpiryRefresh(ExitQRData qr) {
    _expiryTimer?.cancel();
    final remaining = qr.timeRemaining;
    if (remaining.isNegative) return;
    // Auto-refresh 30s before expiry
    final refreshIn = remaining - const Duration(seconds: 30);
    if (refreshIn.isNegative) return;
    _expiryTimer = Timer(refreshIn, refresh);
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

// ── Scanning state ────────────────────────────────────────────────────────────

enum ScanState { idle, scanning, loading, success, notFound, outOfStock, error }

final scanStateProvider =
    StateProvider<ScanState>((ref) => ScanState.idle);

final lastScannedProductProvider =
    StateProvider<ScannedProduct?>((ref) => null);
