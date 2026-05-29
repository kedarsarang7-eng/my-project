// ============================================================================
// POS APP — PROVIDERS
// ============================================================================
// Cart, active session, vendor config — all state managed via Riverpod
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/vendor_session.dart';

// ── Vendor session ────────────────────────────────────────────────────────────

class VendorSessionNotifier extends Notifier<VendorSession?> {
  @override
  VendorSession? build() {
    _loadPersistedSession();
    return null;
  }

  Future<void> _loadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getString('pos_vendor_id');
    final staffName = prefs.getString('pos_staff_name') ?? 'Staff';
    if (vendorId != null) {
      state = VendorSession(
        vendorId: vendorId,
        staffName: staffName,
        loginAt: DateTime.now(),
      );
    }
  }

  Future<void> login({
    required String vendorId,
    required String staffName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_vendor_id', vendorId);
    await prefs.setString('pos_staff_name', staffName);
    state = VendorSession(
      vendorId: vendorId,
      staffName: staffName,
      loginAt: DateTime.now(),
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pos_vendor_id');
    await prefs.remove('pos_staff_name');
    state = null;
  }
}

final vendorSessionProvider =
    NotifierProvider<VendorSessionNotifier, VendorSession?>(
      VendorSessionNotifier.new,
    );

// ── Cart ──────────────────────────────────────────────────────────────────────

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addItem(CartItem item) {
    final existing = state.indexWhere(
      (e) =>
          e.menuItemId == item.menuItemId &&
          e.variationName == item.variationName,
    );
    if (existing >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existing)
            state[i].copyWith(qty: state[i].qty + item.qty)
          else
            state[i],
      ];
    } else {
      state = [...state, item];
    }
  }

  void removeItem(int index) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i],
    ];
  }

  void updateQty(int index, int qty) {
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(qty: qty) else state[i],
    ];
  }

  void updateNote(int index, String note) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(specialInstructions: note)
        else
          state[i],
    ];
  }

  void clear() => state = [];

  double get total =>
      state.fold(0, (sum, item) => sum + (item.price * item.qty));

  int get itemCount => state.fold(0, (sum, item) => sum + item.qty);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

// Derived
final cartTotalProvider = Provider<double>(
  (ref) => ref.watch(cartProvider.notifier).total,
);
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider.notifier).itemCount,
);

// ── Active table ──────────────────────────────────────────────────────────────

class _ActiveTableIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

class _ActiveTableNumberNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

final activeTableIdProvider =
    NotifierProvider<_ActiveTableIdNotifier, String?>(
      _ActiveTableIdNotifier.new,
    );
final activeTableNumberProvider =
    NotifierProvider<_ActiveTableNumberNotifier, String?>(
      _ActiveTableNumberNotifier.new,
    );
