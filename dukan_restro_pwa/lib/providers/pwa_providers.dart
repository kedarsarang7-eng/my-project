// ============================================================================
// PWA PROVIDERS — Cart state for customer
// ============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PwaCartItem {
  final String menuItemId;
  final String name;
  final double price;
  final int qty;
  final bool isVeg;
  final String? note;

  const PwaCartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.qty,
    required this.isVeg,
    this.note,
  });

  PwaCartItem copyWith({int? qty, String? note}) => PwaCartItem(
    menuItemId: menuItemId,
    name: name,
    price: price,
    qty: qty ?? this.qty,
    isVeg: isVeg,
    note: note ?? this.note,
  );
}

class PwaCartNotifier extends StateNotifier<List<PwaCartItem>> {
  PwaCartNotifier() : super([]);

  void add(PwaCartItem item) {
    // P1-06: Match by menuItemId + note signature, not by display name.
    // Same item id with different notes are distinct cart lines.
    final i = state.indexWhere(
      (e) => e.menuItemId == item.menuItemId && (e.note ?? '') == (item.note ?? ''),
    );
    if (i >= 0) {
      state = [
        for (int j = 0; j < state.length; j++)
          if (j == i) state[j].copyWith(qty: state[j].qty + 1) else state[j],
      ];
    } else {
      state = [...state, item];
    }
  }

  void remove(int index) {
    state = [
      for (int j = 0; j < state.length; j++)
        if (j != index) state[j],
    ];
  }

  void decrementById(String menuItemId) {
    final i = state.lastIndexWhere((e) => e.menuItemId == menuItemId);
    if (i < 0) return;
    if (state[i].qty <= 1) {
      state = [
        for (int j = 0; j < state.length; j++)
          if (j != i) state[j],
      ];
    } else {
      state = [
        for (int j = 0; j < state.length; j++)
          if (j == i) state[j].copyWith(qty: state[j].qty - 1) else state[j],
      ];
    }
  }

  void updateNote(int index, String note) {
    state = [
      for (int j = 0; j < state.length; j++)
        if (j == index) state[j].copyWith(note: note) else state[j],
    ];
  }

  void clear() => state = [];

  double get total => state.fold(0.0, (s, i) => s + i.price * i.qty);
  int get count => state.fold(0, (s, i) => s + i.qty);
}

final pwaCartProvider =
    StateNotifierProvider<PwaCartNotifier, List<PwaCartItem>>(
      (ref) => PwaCartNotifier(),
    );

// Active order ID after placement
final activeOrderIdProvider = StateProvider<String?>((ref) => null);
