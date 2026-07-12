// ============================================================================
// TASK 7.3 — OrderType Unit Tests
// Feature: restaurant-vertical-remediation
// **Validates: Requirements 2.13, 3.4**
// ============================================================================
//
// Tests that the OrderType enum correctly parses all 4 supported string values
// (including the newly added 'DELIVERY' and 'PARCEL'), preserves existing
// behavior for 'DINE_IN' and 'TAKEAWAY', and falls back to dineIn for invalid
// inputs.
//
// Run: flutter test test/features/restaurant/order_type_test.dart
// ============================================================================

// ============================================================================
// TASK 18.1 — Exploration Test: delivery/parcel not selectable at order creation
// Feature: restaurant-audit-fixes
// **Validates: Requirements 2.11**
// ============================================================================
//
// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: The order-creation flow in customer_menu_screen.dart uses a
// ternary `widget.tableNumber != null ? OrderType.dineIn : OrderType.takeaway`
// which can ONLY produce dineIn or takeaway — delivery and parcel are never
// selectable despite being declared in the OrderType enum.
//
// No UI selector (dropdown, radio group, SegmentedButton, etc.) for order type
// exists in customer_menu_screen.dart. The user cannot choose delivery or parcel.
//
// COUNTEREXAMPLE (documented after first run):
//   customer_menu_screen.dart line ~308: the order-creation call site passes
//   `orderType: widget.tableNumber != null ? OrderType.dineIn : OrderType.takeaway`
//   — a hardcoded ternary with NO selector for delivery/parcel.
//   The file contains ZERO references to 'delivery', 'parcel', 'OrderType.delivery',
//   'OrderType.parcel', 'DropdownButton', 'SegmentedButton', or 'RadioListTile'
//   for order-type selection.
//
// Run: flutter test test/features/restaurant/order_type_test.dart
// ============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/restaurant/data/models/food_order_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Path to the customer menu screen (order-creation flow).
const String kCustomerMenuScreenPath =
    'lib/features/restaurant/presentation/screens/customer/customer_menu_screen.dart';

/// Terms indicating a UI selector for order type is present.
const List<String> kOrderTypeSelectorTerms = <String>[
  'OrderType.delivery',
  'OrderType.parcel',
  'orderTypeSelector',
  'OrderTypeSelector',
  '_orderTypeSelector',
  'SegmentedButton',
  'orderType:',
  'selectedOrderType',
  '_selectedOrderType',
];

/// Terms indicating delivery/parcel is reachable from the order-creation flow.
const List<String> kDeliveryParcelTerms = <String>[
  'OrderType.delivery',
  'OrderType.parcel',
  'delivery',
  'parcel',
];

void main() {
  group('OrderType', () {
    group('fromString — new enum values (Requirement 2.13)', () {
      test('fromString("DELIVERY") returns OrderType.delivery', () {
        expect(OrderType.fromString('DELIVERY'), equals(OrderType.delivery));
      });

      test('fromString("PARCEL") returns OrderType.parcel', () {
        expect(OrderType.fromString('PARCEL'), equals(OrderType.parcel));
      });
    });

    group('fromString — preserved existing behavior (Requirement 3.4)', () {
      test('fromString("DINE_IN") still returns OrderType.dineIn', () {
        expect(OrderType.fromString('DINE_IN'), equals(OrderType.dineIn));
      });

      test('fromString("TAKEAWAY") still returns OrderType.takeaway', () {
        expect(OrderType.fromString('TAKEAWAY'), equals(OrderType.takeaway));
      });

      test('fromString("INVALID") falls back to OrderType.dineIn', () {
        expect(OrderType.fromString('INVALID'), equals(OrderType.dineIn));
      });
    });

    group('enum completeness (Requirement 2.13)', () {
      test('OrderType.values.length == 4', () {
        expect(OrderType.values.length, equals(4));
      });
    });
  });

  // ===========================================================================
  // TASK 18.1 — Bug Condition Exploration: delivery/parcel not selectable
  // ===========================================================================
  group(
    'Exploration: delivery/parcel selectable at order creation (Req 2.11)',
    () {
      late String customerMenuSource;

      setUpAll(() {
        final file = File(kCustomerMenuScreenPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'customer_menu_screen.dart must exist',
        );
        customerMenuSource = file.readAsStringSync();
      });

      // -----------------------------------------------------------------------
      // Structural assertion 1: the order-creation flow MUST reference
      // OrderType.delivery or OrderType.parcel (not just dineIn/takeaway).
      //
      // On UNFIXED code: FAILS — only dineIn/takeaway are referenced.
      // -----------------------------------------------------------------------
      test('customer_menu_screen.dart references OrderType.delivery', () {
        final hasDelivery = customerMenuSource.contains('OrderType.delivery');

        expect(
          hasDelivery,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Req 2.11): customer_menu_screen.dart does NOT '
              'reference OrderType.delivery anywhere.\n\n'
              'Current behavior: the order-creation call site uses a hardcoded '
              'ternary:\n'
              '  orderType: widget.tableNumber != null\n'
              '      ? OrderType.dineIn\n'
              '      : OrderType.takeaway\n'
              'which can only ever produce dineIn or takeaway.\n\n'
              'Expected behavior: a UI selector allows the customer/staff to '
              'choose delivery as an order type when creating an order.',
        );
      });

      test('customer_menu_screen.dart references OrderType.parcel', () {
        final hasParcel = customerMenuSource.contains('OrderType.parcel');

        expect(
          hasParcel,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Req 2.11): customer_menu_screen.dart does NOT '
              'reference OrderType.parcel anywhere.\n\n'
              'Current behavior: the order-creation call site only produces '
              'dineIn or takeaway via a ternary on tableNumber.\n\n'
              'Expected behavior: a UI selector allows the customer/staff to '
              'choose parcel as an order type when creating an order.',
        );
      });

      // -----------------------------------------------------------------------
      // Structural assertion 2: a UI selector widget for order type MUST exist
      // in the customer menu screen (dropdown, segmented button, radio, etc.).
      //
      // On UNFIXED code: FAILS — no such selector exists.
      // -----------------------------------------------------------------------
      test('customer_menu_screen.dart has an order-type selector widget', () {
        final hasSelector = kOrderTypeSelectorTerms.any(
          (term) => customerMenuSource.contains(term),
        );

        expect(
          hasSelector,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Req 2.11): customer_menu_screen.dart contains '
              'NO order-type selector widget (no SegmentedButton, '
              'DropdownButton, RadioListTile, or equivalent for choosing '
              'among dineIn/takeaway/delivery/parcel).\n\n'
              'Current behavior: order type is implicitly determined by the '
              'ternary `tableNumber != null ? dineIn : takeaway` — the user '
              'has no way to select delivery or parcel.\n\n'
              'Expected behavior: an explicit order-type selector is rendered '
              'in the order-creation flow allowing selection of all 4 types.',
        );
      });

      // -----------------------------------------------------------------------
      // Structural assertion 3: the order-creation call site must NOT be a
      // simple ternary that hard-codes only dineIn/takeaway.
      //
      // On UNFIXED code: FAILS — the ternary IS the only logic.
      // -----------------------------------------------------------------------
      test(
        'order-creation call is NOT a hardcoded dineIn/takeaway ternary',
        () {
          // The bug: the ONLY order-type assignment is this ternary pattern
          final hasBuggyTernary =
              customerMenuSource.contains('tableNumber != null') &&
              customerMenuSource.contains('OrderType.dineIn') &&
              customerMenuSource.contains('OrderType.takeaway') &&
              !customerMenuSource.contains('OrderType.delivery') &&
              !customerMenuSource.contains('OrderType.parcel');

          expect(
            hasBuggyTernary,
            isFalse,
            reason:
                'COUNTEREXAMPLE (Req 2.11): customer_menu_screen.dart uses a '
                'hardcoded ternary:\n'
                '  orderType: widget.tableNumber != null\n'
                '      ? OrderType.dineIn\n'
                '      : OrderType.takeaway\n'
                'without any reference to OrderType.delivery or '
                'OrderType.parcel.\n\n'
                'The OrderType enum declares all 4 values (dineIn, takeaway, '
                'delivery, parcel) but the order-creation UI only ever '
                'produces 2 of them.\n\n'
                'Expected: the call site uses a user-selected order type that '
                'can be any of the 4 declared enum values.',
          );
        },
      );

      // -----------------------------------------------------------------------
      // PBT: for any of the 4 OrderType enum values, the order-creation source
      // MUST structurally support passing that value. On unfixed code this
      // FAILS for delivery and parcel.
      // -----------------------------------------------------------------------
      test(
        'PBT: all 4 OrderType values are passable from order-creation flow',
        () {
          final allOrderTypes = OrderType.values.map((t) => t.name).toList();

          final held = forAll(
            (int typeIdx) {
              final typeName = allOrderTypes[typeIdx % allOrderTypes.length];
              // For each OrderType value, the source must reference it
              return customerMenuSource.contains('OrderType.$typeName');
            },
            [Gen.interval(0, 3)],
            numRuns: 20,
          );

          expect(
            held,
            isTrue,
            reason:
                'COUNTEREXAMPLE (PBT, Req 2.11): customer_menu_screen.dart '
                'does NOT reference all 4 OrderType values.\n\n'
                'The file only references OrderType.dineIn and '
                'OrderType.takeaway. OrderType.delivery and OrderType.parcel '
                'are declared in the enum but NEVER appear in the '
                'order-creation flow source.\n\n'
                'For ANY of the 4 declared OrderType values, it should be '
                'possible to create an order with that type from the UI.\n\n'
                'Expected: customer_menu_screen.dart references all 4 '
                'OrderType values as selectable options in the order-creation '
                'flow.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // TASK 18.2 — Preservation Test: existing dineIn/takeaway orders unaffected
  // **Validates: Requirements 3.8**
  // ===========================================================================
  // **Property 10: Preservation** - OrderType Round-Trips and Daily-Summary
  // Bucketing Is a Partition (existing dineIn/takeaway clause)
  //
  // Observations:
  //   - OrderType.fromString('DINE_IN') == OrderType.dineIn ✓
  //   - OrderType.fromString('TAKEAWAY') == OrderType.takeaway ✓
  //   - Both round-trip correctly (enum already declares delivery/parcel —
  //     only UI exposure is missing)
  //
  // PBT: for randomized sets of orders using only dineIn/takeaway, daily-summary
  // per-type counts sum to the total order count, unaffected by adding a UI
  // selector for delivery/parcel.
  //
  // Should PASS on unfixed code (preservation test).
  // ===========================================================================
  group(
    'Property 10 Preservation: dineIn/takeaway round-trip & partition (Req 3.8)',
    () {
      // -----------------------------------------------------------------------
      // Helper: simulates the daily-summary bucketing logic from
      // restaurant_daily_summary_screen.dart — counts orders by OrderType.
      // -----------------------------------------------------------------------
      Map<OrderType, int> bucketOrders(List<FoodOrder> orders) {
        return {
          OrderType.dineIn: orders
              .where((o) => o.orderType == OrderType.dineIn)
              .length,
          OrderType.takeaway: orders
              .where((o) => o.orderType == OrderType.takeaway)
              .length,
          OrderType.delivery: orders
              .where((o) => o.orderType == OrderType.delivery)
              .length,
          OrderType.parcel: orders
              .where((o) => o.orderType == OrderType.parcel)
              .length,
        };
      }

      /// Helper: builds a FoodOrder with the given OrderType.
      FoodOrder buildOrder(String id, OrderType type) {
        final now = DateTime(2024, 6, 15, 12, 0);
        return FoodOrder(
          id: id,
          vendorId: 'vendor_test',
          customerId: 'cust_001',
          orderType: type,
          orderStatus: FoodOrderStatus.completed,
          items: const [],
          itemCount: 1,
          subtotal: 100.0,
          grandTotal: 100.0,
          orderTime: now,
          createdAt: now,
          updatedAt: now,
        );
      }

      // -----------------------------------------------------------------------
      // Unit test: fromString round-trip for dineIn and takeaway
      // -----------------------------------------------------------------------
      test('OrderType.fromString round-trips dineIn correctly', () {
        expect(OrderType.fromString(OrderType.dineIn.value), OrderType.dineIn);
        expect(OrderType.dineIn.value, 'DINE_IN');
      });

      test('OrderType.fromString round-trips takeaway correctly', () {
        expect(
          OrderType.fromString(OrderType.takeaway.value),
          OrderType.takeaway,
        );
        expect(OrderType.takeaway.value, 'TAKEAWAY');
      });

      // -----------------------------------------------------------------------
      // PBT: OrderType.fromString(type.value) == type for dineIn/takeaway
      // -----------------------------------------------------------------------
      test(
        'PBT: fromString(type.value) == type for dineIn/takeaway (round-trip)',
        () {
          // Generator: 0 = dineIn, 1 = takeaway
          final held = forAll(
            (int typeIdx) {
              final type = typeIdx == 0 ? OrderType.dineIn : OrderType.takeaway;
              return OrderType.fromString(type.value) == type;
            },
            [Gen.interval(0, 1)],
            numRuns: 100,
          );

          expect(
            held,
            isTrue,
            reason:
                'OrderType.fromString(type.value) must equal type for both '
                'dineIn and takeaway — this is the round-trip invariant.',
          );
        },
      );

      // -----------------------------------------------------------------------
      // PBT: for randomized sets of orders using only dineIn/takeaway,
      // per-type counts sum to the total order count (partition property).
      //
      // Generator produces a bitmask representing a list of up to 20 orders,
      // each bit determining dineIn (0) or takeaway (1).
      // -----------------------------------------------------------------------
      test(
        'PBT: daily-summary per-type counts sum to total for dineIn/takeaway sets',
        () {
          // Generator: tuple of [orderCount (1..20), bitmask seed (0..1048575)]
          // The bitmask assigns each order to dineIn or takeaway.
          final held = forAll(
            (int orderCount, int bitmask) {
              // Clamp order count to 1..20
              final count = (orderCount % 20) + 1;

              // Build randomized order list using only dineIn/takeaway
              final orders = List.generate(count, (i) {
                final isDineIn = ((bitmask >> (i % 20)) & 1) == 0;
                final type = isDineIn ? OrderType.dineIn : OrderType.takeaway;
                return buildOrder('order_$i', type);
              });

              // Bucket the orders (same logic as daily summary screen)
              final buckets = bucketOrders(orders);

              // Partition property: sum of all bucket counts == total orders
              final totalBucketed = buckets.values.fold<int>(
                0,
                (a, b) => a + b,
              );
              if (totalBucketed != orders.length) return false;

              // For dineIn/takeaway-only sets, delivery and parcel must be 0
              if (buckets[OrderType.delivery] != 0) return false;
              if (buckets[OrderType.parcel] != 0) return false;

              // Per-type counts must be non-negative
              if (buckets[OrderType.dineIn]! < 0) return false;
              if (buckets[OrderType.takeaway]! < 0) return false;

              return true;
            },
            [Gen.interval(0, 19), Gen.interval(0, 1048575)],
            numRuns: 200,
          );

          expect(
            held,
            isTrue,
            reason:
                'For any set of orders using only dineIn/takeaway, the '
                'daily-summary per-type counts must sum to the total order '
                'count. delivery/parcel buckets must be 0. This ensures '
                'adding delivery/parcel UI does not affect existing order '
                'bucketing (Preservation Req 3.8).',
          );
        },
      );

      // -----------------------------------------------------------------------
      // PBT: existing persisted order type strings ('DINE_IN', 'TAKEAWAY')
      // correctly deserialize even in the presence of the new enum values.
      // Simulates orders persisted prior to delivery/parcel being added.
      // -----------------------------------------------------------------------
      test(
        'PBT: legacy persisted strings DINE_IN/TAKEAWAY still deserialize correctly',
        () {
          // Simulates Drift column text values that existed before migration
          final legacyValues = ['DINE_IN', 'TAKEAWAY'];

          final held = forAll(
            (int idx) {
              final value = legacyValues[idx % legacyValues.length];
              final parsed = OrderType.fromString(value);

              // Must map to the correct enum value
              if (value == 'DINE_IN' && parsed != OrderType.dineIn)
                return false;
              if (value == 'TAKEAWAY' && parsed != OrderType.takeaway) {
                return false;
              }

              // .value must produce the original string (round-trip)
              return parsed.value == value;
            },
            [Gen.interval(0, 1)],
            numRuns: 100,
          );

          expect(
            held,
            isTrue,
            reason:
                'Legacy persisted strings DINE_IN/TAKEAWAY must still '
                'correctly deserialize to their respective OrderType enum '
                'values after delivery/parcel are added to the enum '
                '(Preservation Req 3.8).',
          );
        },
      );

      // -----------------------------------------------------------------------
      // PBT: the bucketing function is a true partition — no order is
      // double-counted or dropped regardless of the mix of dineIn/takeaway.
      // Uses a randomized count per type.
      // -----------------------------------------------------------------------
      test(
        'PBT: bucketing is a partition — dineIn + takeaway counts == total',
        () {
          final held = forAll(
            (int dineInCount, int takeawayCount) {
              // Clamp to reasonable sizes
              final di = dineInCount % 15;
              final ta = takeawayCount % 15;
              final total = di + ta;

              // Build the order list
              final orders = <FoodOrder>[
                ...List.generate(
                  di,
                  (i) => buildOrder('di_$i', OrderType.dineIn),
                ),
                ...List.generate(
                  ta,
                  (i) => buildOrder('ta_$i', OrderType.takeaway),
                ),
              ];

              // Shuffle to ensure bucketing is order-independent
              orders.shuffle(math.Random(dineInCount ^ takeawayCount));

              final buckets = bucketOrders(orders);

              // Partition: dineIn + takeaway == total; delivery + parcel == 0
              final sum =
                  buckets[OrderType.dineIn]! +
                  buckets[OrderType.takeaway]! +
                  buckets[OrderType.delivery]! +
                  buckets[OrderType.parcel]!;

              if (sum != total) return false;
              if (buckets[OrderType.dineIn] != di) return false;
              if (buckets[OrderType.takeaway] != ta) return false;
              if (buckets[OrderType.delivery] != 0) return false;
              if (buckets[OrderType.parcel] != 0) return false;

              return true;
            },
            [Gen.interval(0, 14), Gen.interval(0, 14)],
            numRuns: 200,
          );

          expect(
            held,
            isTrue,
            reason:
                'Bucketing must be a true partition: for any mix of dineIn '
                'and takeaway orders, per-type counts must exactly match the '
                'input distribution, and delivery/parcel buckets must be 0 '
                '(Preservation Req 3.8).',
          );
        },
      );
    },
  );
}
