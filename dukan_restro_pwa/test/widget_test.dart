// ============================================================================
// PWA Smoke Tests — Phase 4
// Tests that do NOT require a network/backend. Covers cart logic, token cache,
// and provider state correctness.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukan_restro_pwa/providers/pwa_providers.dart';

void main() {
  // --------------------------------------------------------------------------
  // Cart — add / increment / decrement / remove / clear
  // --------------------------------------------------------------------------
  group('PwaCartNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    PwaCartItem item({
      String id = 'item-1',
      String name = 'Butter Chicken',
      double price = 250.0,
      String? note,
    }) =>
        PwaCartItem(
          menuItemId: id,
          name: name,
          price: price,
          qty: 1,
          isVeg: false,
          note: note,
        );

    test('CART-01: add new item increments count', () {
      container.read(pwaCartProvider.notifier).add(item());
      expect(container.read(pwaCartProvider).length, 1);
    });

    test('CART-02: adding same menuItemId bumps qty', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item());
      notifier.add(item());
      final cart = container.read(pwaCartProvider);
      expect(cart.length, 1);
      expect(cart.first.qty, 2);
    });

    test('CART-03: same name different menuItemId are distinct lines', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item(id: 'item-1', name: 'Pepsi'));
      notifier.add(item(id: 'item-2', name: 'Pepsi'));
      expect(container.read(pwaCartProvider).length, 2);
    });

    test('CART-04: same menuItemId different note are distinct lines', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item(note: 'less spicy'));
      notifier.add(item(note: 'extra spicy'));
      expect(container.read(pwaCartProvider).length, 2);
    });

    test('CART-05: decrementById below 1 removes the line', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item());
      notifier.decrementById('item-1');
      expect(container.read(pwaCartProvider).isEmpty, isTrue);
    });

    test('CART-06: clear empties the cart', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item());
      notifier.add(item(id: 'item-2'));
      notifier.clear();
      expect(container.read(pwaCartProvider).isEmpty, isTrue);
    });

    test('CART-07: total is sum of price * qty', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item(price: 100));
      notifier.add(item(price: 100));
      final total = container.read(pwaCartProvider.notifier).total;
      expect(total, 200.0);
    });

    test('CART-08: count reflects total qty across all lines', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item(id: 'a', price: 50));
      notifier.add(item(id: 'a', price: 50)); // bumps qty to 2
      notifier.add(item(id: 'b', price: 80));
      // 2 of 'a' + 1 of 'b' = 3
      expect(container.read(pwaCartProvider.notifier).count, 3);
    });

    test('CART-09: updateNote sets note on correct line', () {
      final notifier = container.read(pwaCartProvider.notifier);
      notifier.add(item());
      notifier.updateNote(0, 'no onion');
      expect(container.read(pwaCartProvider).first.note, 'no onion');
    });
  });

  // --------------------------------------------------------------------------
  // activeOrderIdProvider
  // --------------------------------------------------------------------------
  group('activeOrderIdProvider', () {
    test('AOID-01: initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(activeOrderIdProvider), isNull);
    });

    test('AOID-02: can be set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeOrderIdProvider.notifier).state = 'order-xyz';
      expect(container.read(activeOrderIdProvider), 'order-xyz');
    });
  });
}
