// ============================================================================
// RestaurantNotificationService — UNS emit equivalence test (task 14.3)
// ----------------------------------------------------------------------------
// Validates the migration window for Trigger_Points T-RES-1..5 and T-RES-7
// (`migration_status.md` §4.7).
//
// Equivalence guarantee under REQ 10.9:
//
//   For every notify* call on the migrated helper, the canonical UNS event
//   published through the Shared_SDK MUST carry the registry-defined
//   recipient set, channel set, and payload key set.
//
// The legacy in-app channel surface (`flutter_local_notifications` desktop
// toast and the `audioplayers` cue) is preserved by the same call paths and
// is exercised live on real hardware; the test below focuses on the new
// canonical emit so the per-row equivalence claim recorded in
// `migration_status.md` §4.7 can be reproduced from source.
//
// Validates: REQ 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;
import 'package:dukanx/features/restaurant/domain/services/restaurant_notification_service.dart';

/// Captures every `emit(event)` call into a list so the test can assert
/// against the canonical envelope without touching the network.
class _CapturingSdk implements uns.NotificationsSdk {
  final List<uns.EventContract> emitted = <uns.EventContract>[];

  @override
  Future<void> emit(uns.EventContract event) async {
    emitted.add(event);
  }

  @override
  Future<List<uns.NotificationDelivery>> replay(
    String sinceIso, {
    String? appName,
  }) async => const <uns.NotificationDelivery>[];

  @override
  void Function() subscribe(
    String eventName,
    void Function(uns.NotificationDelivery delivery) handler,
  ) => () {};

  @override
  Stream<uns.NotificationDelivery> onNotification() => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> flushOutbox() async {}

  // The remaining members of NotificationsSdk are internals that the helper
  // never calls — `noSuchMethod` returns the expected sentinel for any new
  // surface added in the SDK so the test is forward-compatible.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Single capturing SDK shared across cases — each test resets `emitted`.
  late _CapturingSdk capturing;
  late RestaurantNotificationService helper;

  setUp(() {
    capturing = _CapturingSdk();
    helper = RestaurantNotificationService();
    helper.debugSetSdk(capturing);
    // Sound disabled so AudioPlayer doesn't try to load assets in test.
    helper.setSoundEnabled(false);
  });

  tearDown(() {
    helper.debugSetSdk(null);
  });

  group('T-RES-3 — orders.restaurant_kot.item_ready', () {
    test(
      'notifyOrderReady emits canonical event with item_ready event_name',
      () async {
        await helper.notifyOrderReady(
          'order-1',
          '7',
          vendorId: 'vendor-1',
          customerId: 'cust-1',
        );

        expect(capturing.emitted, hasLength(1));
        final event = capturing.emitted.single;
        expect(event.eventName, equals('orders.restaurant_kot.item_ready'));
        expect(event.category, equals(uns.EventCategory.orders));
        expect(event.subCategory, equals('restaurant_kot'));
        expect(event.priority, equals(uns.EventPriority.high));
        expect(event.targetId, equals('order-1'));
        expect(event.payload['order_id'], equals('order-1'));
        expect(event.payload['vendor_id'], equals('vendor-1'));
        expect(event.payload['table_number'], equals('7'));
        expect(event.payload['customer_id'], equals('cust-1'));
        expect(event.sourceApp, equals(uns.SourceApp.dukanxDesktop));

        final roles = event.recipients.map((r) => r.role).toSet();
        expect(roles, contains(uns.RecipientRole.waiter));
        expect(roles, contains(uns.RecipientRole.shopOwner));
        expect(roles, contains(uns.RecipientRole.customer));

        // Channels declared on the envelope mirror the registry §7.5 default.
        expect(
          event.channels,
          unorderedEquals(<uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ]),
        );
      },
    );
  });

  group('T-RES-1 — orders.restaurant.created', () {
    test(
      'notifyNewOrder emits canonical event with restaurant.created',
      () async {
        final order = RestaurantOrderSnapshot(
          id: 'order-new-1',
          vendorId: 'vendor-1',
          tableId: 'tbl-1',
          tableNumber: '4',
          orderType: 'DINE_IN',
          orderStatus: 'PENDING',
          itemCount: 3,
          grandTotal: 599.0,
          orderTime: DateTime.utc(2026, 5, 4, 12, 0),
        );

        await helper.notifyNewOrder(order);

        expect(capturing.emitted, hasLength(1));
        final event = capturing.emitted.single;
        expect(event.eventName, equals('orders.restaurant.created'));
        expect(event.category, equals(uns.EventCategory.orders));
        expect(event.subCategory, equals('restaurant_order'));
        expect(event.priority, equals(uns.EventPriority.high));
        expect(event.targetId, equals('order-new-1'));
        expect(event.payload['order_id'], equals('order-new-1'));
        expect(event.payload['vendor_id'], equals('vendor-1'));
        expect(event.payload['table_number'], equals('4'));
        expect(event.payload['item_count'], equals(3));
        expect(event.payload['grand_total'], equals(599.0));
        expect(event.payload['order_time'], equals('2026-05-04T12:00:00.000Z'));

        final roles = event.recipients.map((r) => r.role).toSet();
        expect(roles, contains(uns.RecipientRole.chef));
        expect(roles, contains(uns.RecipientRole.kitchenStaff));
        expect(roles, contains(uns.RecipientRole.waiter));
        expect(roles, contains(uns.RecipientRole.shopOwner));
      },
    );

    test('notifyOrderDelay emits orders.restaurant_kot.status_changed with '
        'delay_alert action', () async {
      final order = RestaurantOrderSnapshot(
        id: 'order-late',
        vendorId: 'vendor-1',
        tableNumber: '7',
        orderType: 'DINE_IN',
        orderStatus: 'COOKING',
        itemCount: 2,
        grandTotal: 299.0,
        orderTime: DateTime.utc(2026, 5, 4, 12, 0),
      );

      await helper.notifyOrderDelay(order, 25);

      final event = capturing.emitted.single;
      expect(event.eventName, equals('orders.restaurant_kot.status_changed'));
      expect(event.payload['minutes_waiting'], equals(25));
      expect(event.payload['action'], equals('delay_alert'));
    });
  });

  group('T-RES-2 — orders.restaurant_kot.* (KOT lifecycle)', () {
    test(
      'notifyKotItem(created) emits orders.restaurant_kot.created',
      () async {
        await helper.notifyKotItem(
          stage: RestaurantKotStage.created,
          kotId: 'kot-1',
          orderId: 'order-1',
          vendorId: 'vendor-1',
          tableNumber: '7',
        );

        expect(
          capturing.emitted.single.eventName,
          equals('orders.restaurant_kot.created'),
        );
        expect(capturing.emitted.single.targetId, equals('kot-1'));
        expect(capturing.emitted.single.payload['kot_id'], equals('kot-1'));
        expect(capturing.emitted.single.payload['order_id'], equals('order-1'));
        expect(
          capturing.emitted.single.payload['vendor_id'],
          equals('vendor-1'),
        );
        expect(capturing.emitted.single.payload['table_number'], equals('7'));
      },
    );

    test(
      'notifyKotItem(statusChanged) emits orders.restaurant_kot.status_changed',
      () async {
        await helper.notifyKotItem(
          stage: RestaurantKotStage.statusChanged,
          kotId: 'kot-2',
          orderId: 'order-2',
          vendorId: 'vendor-1',
          newStatus: 'preparing',
        );

        expect(
          capturing.emitted.single.eventName,
          equals('orders.restaurant_kot.status_changed'),
        );
        expect(
          capturing.emitted.single.payload['new_status'],
          equals('preparing'),
        );
        // `new_status` is part of the dedup scope so duplicate transitions are
        // collapsed but a real status change re-emits.
        expect(
          capturing.emitted.single.dedupScopeFields,
          contains('new_status'),
        );
      },
    );

    test(
      'notifyKotItem(itemCancelled) emits orders.restaurant_kot.item_cancelled',
      () async {
        await helper.notifyKotItem(
          stage: RestaurantKotStage.itemCancelled,
          kotId: 'kot-3',
          orderId: 'order-3',
          vendorId: 'vendor-1',
          itemName: 'Paneer Tikka',
          cancellationReason: 'customer changed mind',
        );

        expect(
          capturing.emitted.single.eventName,
          equals('orders.restaurant_kot.item_cancelled'),
        );
        expect(
          capturing.emitted.single.payload['item_name'],
          equals('Paneer Tikka'),
        );
        expect(
          capturing.emitted.single.payload['cancellation_reason'],
          equals('customer changed mind'),
        );
      },
    );

    test(
      'all KOT events target chef + kitchen_staff + waiter + shop_owner',
      () async {
        for (final stage in RestaurantKotStage.values) {
          capturing.emitted.clear();
          await helper.notifyKotItem(
            stage: stage,
            kotId: 'kot-x',
            orderId: 'order-x',
            vendorId: 'vendor-x',
            newStatus: stage == RestaurantKotStage.statusChanged
                ? 'preparing'
                : null,
          );
          final roles = capturing.emitted.single.recipients
              .map((r) => r.role)
              .toSet();
          expect(roles, contains(uns.RecipientRole.chef));
          expect(roles, contains(uns.RecipientRole.kitchenStaff));
          expect(roles, contains(uns.RecipientRole.waiter));
          expect(roles, contains(uns.RecipientRole.shopOwner));
        }
      },
    );
  });

  group('T-RES-4 — billing.restaurant_bill.updated', () {
    test('notifyBillRequested emits canonical billing event', () async {
      await helper.notifyBillRequested('5', 'order-bill-1');

      expect(capturing.emitted, hasLength(1));
      final event = capturing.emitted.single;
      expect(event.eventName, equals('billing.restaurant_bill.updated'));
      expect(event.category, equals(uns.EventCategory.billing));
      expect(event.subCategory, equals('restaurant_bill'));
      expect(event.targetId, equals('order-bill-1'));
      expect(event.payload['table_number'], equals('5'));
      expect(event.payload['action'], equals('bill_requested'));

      final roles = event.recipients.map((r) => r.role).toSet();
      expect(roles, contains(uns.RecipientRole.shopOwner));
      expect(roles, contains(uns.RecipientRole.cashier));
      expect(roles, contains(uns.RecipientRole.waiter));
    });
  });

  group('T-RES-5 — orders.restaurant_table.status_changed', () {
    test('notifyTableStatusChanged emits canonical table event', () async {
      await helper.notifyTableStatusChanged(
        vendorId: 'vendor-1',
        tableId: 'tbl-3',
        tableNumber: '3',
        newStatus: 'seated',
        previousStatus: 'free',
      );

      final event = capturing.emitted.single;
      expect(event.eventName, equals('orders.restaurant_table.status_changed'));
      expect(event.category, equals(uns.EventCategory.orders));
      expect(event.subCategory, equals('restaurant_table'));
      expect(event.targetId, equals('tbl-3'));
      expect(event.payload['new_status'], equals('seated'));
      expect(event.payload['previous_status'], equals('free'));
      expect(
        event.dedupScopeFields,
        unorderedEquals(<String>['table_id', 'new_status']),
      );

      final roles = event.recipients.map((r) => r.role).toSet();
      expect(roles, contains(uns.RecipientRole.shopOwner));
      expect(roles, contains(uns.RecipientRole.waiter));
      expect(roles, contains(uns.RecipientRole.cashier));
    });
  });

  group('T-RES-7 — delivery.restaurant.dispatched', () {
    test('notifyDeliveryDispatched emits canonical delivery event', () async {
      await helper.notifyDeliveryDispatched(
        vendorId: 'vendor-1',
        orderId: 'order-9',
        agentId: 'agent-1',
        agentName: 'Ravi',
        customerId: 'cust-9',
      );

      final event = capturing.emitted.single;
      expect(event.eventName, equals('delivery.restaurant.dispatched'));
      expect(event.category, equals(uns.EventCategory.delivery));
      expect(event.subCategory, equals('restaurant_delivery'));
      expect(event.targetId, equals('order-9'));
      expect(event.payload['agent_id'], equals('agent-1'));
      expect(event.payload['agent_name'], equals('Ravi'));
      expect(event.payload['customer_id'], equals('cust-9'));

      final roles = event.recipients.map((r) => r.role).toSet();
      expect(roles, contains(uns.RecipientRole.shopOwner));
      expect(roles, contains(uns.RecipientRole.deliveryAgent));
      expect(roles, contains(uns.RecipientRole.customer));
    });

    test(
      'notifyDeliveryDispatched omits customer recipient when customerId is null',
      () async {
        await helper.notifyDeliveryDispatched(
          vendorId: 'vendor-1',
          orderId: 'order-10',
          agentId: 'agent-2',
        );
        final roles = capturing.emitted.single.recipients
            .map((r) => r.role)
            .toSet();
        expect(roles, isNot(contains(uns.RecipientRole.customer)));
      },
    );
  });

  group('UNS emit hygiene', () {
    test(
      'every emitted event carries a non-empty dedup_key and source_module',
      () async {
        await helper.notifyOrderReady('order-x', '1', vendorId: 'v1');
        final e = capturing.emitted.single;
        expect(e.dedupKey, isNotEmpty);
        expect(
          e.sourceModule,
          contains('restaurant_notification_service.dart'),
        );
      },
    );

    test('emit is a no-op when the SDK has not been wired', () async {
      helper.debugSetSdk(null);
      // Should not throw despite the absence of an SDK.
      await helper.notifyOrderReady('order-x', '1', vendorId: 'v1');
      expect(capturing.emitted, isEmpty);
    });
  });
}
