// ============================================================================
// RESTAURANT NOTIFICATION SERVICE
// ============================================================================
// Migrated under task 14.3 of the unified-notification-system spec.
//
// Two responsibilities now live side by side:
//
//  1. **In-app channel surface (legacy behaviour, preserved)** — desktop
//     OS-level toasts via `flutter_local_notifications` plus optional bell /
//     alert sounds via `audioplayers`. This is what the user actually sees
//     and hears on the restaurant POS / KDS / waiter screens, so we keep it
//     so cooks and waiters do not lose their existing audible cues.
//
//  2. **Canonical UNS emit (new in this migration)** — every notify* call
//     also publishes a registry-defined event through the Shared_SDK
//     (`packages/notifications-sdk`). Once delivered, the UNS Notification
//     _Service routes the event to chefs / waiters / shop owners /
//     subscribed customers across the multi-app fleet (DukanX desktop +
//     restaurant staff app + customer app) per the per-role channel matrix
//     in `phase2-event-registry.md` §7 and §8.1.
//
// Trigger_Points covered (see `migration_status.md` rows T-RES-1..5, 7):
//
//   T-RES-1 → orders.restaurant.created             (notifyNewOrder)
//   T-RES-2 → orders.restaurant_kot.{created,
//                                    status_changed,
//                                    item_cancelled} (notifyKotItem)
//   T-RES-3 → orders.restaurant_kot.item_ready       (notifyOrderReady)
//   T-RES-4 → billing.restaurant_bill.updated        (notifyBillRequested)
//   T-RES-5 → orders.restaurant_table.status_changed (notifyTableStatusChanged)
//   T-RES-7 → delivery.restaurant.dispatched         (notifyDeliveryDispatched)
//
// Validates: REQ 10.7, 10.8, 10.9, 10.9a, 19.4, 19.5
// ============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notifications_sdk/notifications_sdk.dart' as uns;
import 'package:uuid/uuid.dart';

/// Compact view over a restaurant order, containing only the fields the
/// notification helper needs.
///
/// Decouples this file from the Drift-backed `FoodOrder` model so unit tests
/// can exercise the helper without compiling the entire database layer.
/// Production callers can build a snapshot from a `FoodOrder` via the
/// extension in `restaurant_notification_snapshot.dart`.
class RestaurantOrderSnapshot {
  final String id;
  final String vendorId;
  final String? tableId;
  final String? tableNumber;
  final String orderType;
  final String orderStatus;
  final int itemCount;
  final double grandTotal;
  final DateTime orderTime;

  const RestaurantOrderSnapshot({
    required this.id,
    required this.vendorId,
    this.tableId,
    this.tableNumber,
    required this.orderType,
    required this.orderStatus,
    required this.itemCount,
    required this.grandTotal,
    required this.orderTime,
  });
}

/// Hook used by [RestaurantNotificationService] to resolve the UNS SDK.
///
/// Defaults to `null` in test contexts (no service locator) and is wired to
/// the GetIt-backed lookup at app boot via [registerRestaurantUnsBindings].
/// Tests bypass this entirely by calling
/// [RestaurantNotificationService.debugSetSdk] directly.
typedef RestaurantUnsSdkResolver = uns.NotificationsSdk? Function();

/// Hook used by the helper to resolve the current actor (signed-in user) and
/// vendor ids. Returns `null` when no session is available.
typedef RestaurantUnsActorResolver =
    ({String actorId, String vendorId})? Function();

/// One-time wiring that the app's DI bootstrap invokes after the SDK and
/// session manager have finished registering. Idempotent.
void registerRestaurantUnsBindings({
  required RestaurantUnsSdkResolver sdkResolver,
  required RestaurantUnsActorResolver actorResolver,
}) {
  RestaurantNotificationService._sdkResolver = sdkResolver;
  RestaurantNotificationService._actorResolver = actorResolver;
}

/// Restaurant KOT lifecycle stages used by [RestaurantNotificationService.notifyKotItem].
///
/// Mirrors the registry events under `orders.restaurant_kot.*` so each
/// stage maps to exactly one canonical event_name (no ambiguity).
enum RestaurantKotStage {
  /// New KOT pushed to the kitchen.
  created,

  /// KOT status updated (e.g. pending → preparing → served).
  statusChanged,

  /// One or more KOT line items cancelled before serving.
  itemCancelled,
}

/// Service that surfaces restaurant order events on the local desktop AND
/// publishes the canonical event through the UNS Shared_SDK.
class RestaurantNotificationService {
  RestaurantNotificationService._internal();

  static final RestaurantNotificationService _instance =
      RestaurantNotificationService._internal();

  factory RestaurantNotificationService() => _instance;

  /// Wired by [registerRestaurantUnsBindings] at app boot. Test code uses
  /// [debugSetSdk] instead and never touches this.
  static RestaurantUnsSdkResolver? _sdkResolver;
  static RestaurantUnsActorResolver? _actorResolver;

  // --------------------------------------------------------------------------
  // Local-notification rendering (legacy in-app channel surface).
  // --------------------------------------------------------------------------

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Lazily constructed so headless test environments (no audio platform
  /// channel) don't crash when the helper singleton is built.
  AudioPlayer? _audioPlayerInstance;
  AudioPlayer get _audioPlayer => _audioPlayerInstance ??= AudioPlayer();

  bool _isInitialized = false;
  bool _soundEnabled = true;

  // --------------------------------------------------------------------------
  // UNS Shared_SDK plumbing.
  // --------------------------------------------------------------------------

  final Uuid _uuid = const Uuid();

  /// Cached lookup of the UNS SDK from the service locator.
  ///
  /// Resolved lazily because the SDK is registered with [registerSingletonAsync]
  /// and may not be ready at the moment the helper is constructed (the helper
  /// itself is built during early bootstrap). Callers don't await this; emit
  /// calls fire-and-forget, and a brief startup window where the SDK is not
  /// yet ready simply means the very first event is dropped client-side —
  /// the in-app local toast still surfaces, so the operator never misses the
  /// audible cue for a fresh order.
  uns.NotificationsSdk? _cachedSdk;

  /// Test seam: production code resolves this through `sl<NotificationsSdk>()`.
  /// Tests inject a fake SDK directly via [debugSetSdk].
  uns.NotificationsSdk? _injectedSdk;

  @visibleForTesting
  // ignore: use_setters_to_change_properties
  void debugSetSdk(uns.NotificationsSdk? sdk) {
    _injectedSdk = sdk;
    _cachedSdk = sdk;
  }

  /// Best-effort SDK lookup. Returns `null` when the SDK has not finished
  /// async-registration yet, when registration was skipped (test mode), or
  /// when the lookup throws because GetIt is not ready.
  uns.NotificationsSdk? _resolveSdk() {
    if (_injectedSdk != null) return _injectedSdk;
    if (_cachedSdk != null) return _cachedSdk;
    final resolver = _sdkResolver;
    if (resolver == null) return null;
    try {
      _cachedSdk = resolver();
      return _cachedSdk;
    } catch (_) {
      // Resolver wasn't ready (registerSingletonAsync still resolving) or
      // GetIt threw because the binding isn't installed yet. Try later.
      return null;
    }
  }

  /// Initialize the local notifications plugin. Idempotent.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'DukanX',
        appUserModelId: 'com.dukanx.app',
        guid: '8b1d6db2-3c1a-4c28-98e3-93d39589d81d',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        windows: windowsSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error initializing local notifications: $e\n$stack');
      }
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Hook for future deep-linking. Payload format: "order:{orderId}" or
    // "table:{tableId}". UNS subscribers can also wire navigation through
    // `Shared_SDK.subscribe(...)` once the in-app drawer/bell ships.
  }

  /// Toggle sound alerts (used by the staff-app settings screen).
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  bool get isSoundEnabled => _soundEnabled;

  // ==========================================================================
  // VENDOR / KITCHEN / WAITER NOTIFICATIONS
  // ==========================================================================

  /// New order arrived — vendor + kitchen + waiter cue.
  ///
  /// UNS event: `orders.restaurant.created` (T-RES-1, registry §7.1).
  Future<void> notifyNewOrder(RestaurantOrderSnapshot order) async {
    await _showNotification(
      id: order.id.hashCode,
      title: '🔔 New Order!',
      body:
          'Table ${order.tableNumber ?? 'Takeaway'} - ${order.itemCount} items',
      channelId: 'new_orders',
      channelName: 'New Orders',
      sound: 'order_bell',
      importance: Importance.high,
      payload: 'order:${order.id}',
    );
    if (_soundEnabled) {
      await _playOrderBell();
    }

    await _emit(
      eventName: 'orders.restaurant.created',
      category: uns.EventCategory.orders,
      subCategory: 'restaurant_order',
      priority: uns.EventPriority.high,
      targetId: order.id,
      payload: <String, dynamic>{
        'order_id': order.id,
        'vendor_id': order.vendorId,
        'table_id': order.tableId,
        'table_number': order.tableNumber,
        'order_type': order.orderType,
        'order_status': order.orderStatus,
        'item_count': order.itemCount,
        'grand_total': order.grandTotal,
        'order_time': order.orderTime.toUtc().toIso8601String(),
      },
      // Per registry §7.1: chef + kitchen_staff + waiter (in_app + push).
      recipients: <uns.Recipient>[
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.shopOwner,
          targetId: order.id,
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.chef,
          targetId: order.id,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ],
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.kitchenStaff,
          targetId: order.id,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ],
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.waiter,
          targetId: order.id,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
          ],
        ),
      ],
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: const <String>['order_id'],
    );
  }

  /// Customer requested the bill at a table.
  ///
  /// UNS event: `billing.restaurant_bill.updated` (T-RES-4, registry §4.11).
  Future<void> notifyBillRequested(String tableNumber, String orderId) async {
    await _showNotification(
      id: orderId.hashCode,
      title: '📄 Bill Requested',
      body: 'Table $tableNumber is ready to pay',
      channelId: 'bill_requests',
      channelName: 'Bill Requests',
      importance: Importance.high,
      payload: 'order:$orderId',
    );
    if (_soundEnabled) {
      await _playNotificationSound();
    }

    await _emit(
      eventName: 'billing.restaurant_bill.updated',
      category: uns.EventCategory.billing,
      subCategory: 'restaurant_bill',
      priority: uns.EventPriority.high,
      targetId: orderId,
      payload: <String, dynamic>{
        'order_id': orderId,
        'table_number': tableNumber,
        'action': 'bill_requested',
      },
      recipients: <uns.Recipient>[
        uns.Recipient(
          userId: _currentVendorId(),
          role: uns.RecipientRole.shopOwner,
          targetId: orderId,
        ),
        uns.Recipient(
          userId: _currentVendorId(),
          role: uns.RecipientRole.cashier,
          targetId: orderId,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ],
        ),
        uns.Recipient(
          userId: _currentVendorId(),
          role: uns.RecipientRole.waiter,
          targetId: orderId,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
          ],
        ),
      ],
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: const <String>['order_id', 'action'],
    );
  }

  /// Order is taking too long — alerts the floor.
  ///
  /// No registry-level event exists for this surface today; we keep the
  /// local cue and emit it as a `status_changed` KOT event with an
  /// `escalation` action so existing subscribers see it without us inventing
  /// a new event type outside the registry.
  Future<void> notifyOrderDelay(
    RestaurantOrderSnapshot order,
    int minutesWaiting,
  ) async {
    await _showNotification(
      id: order.id.hashCode + 1000,
      title: '⚠️ Order Delayed',
      body:
          'Table ${order.tableNumber ?? 'Takeaway'} waiting $minutesWaiting min',
      channelId: 'order_delays',
      channelName: 'Order Delays',
      importance: Importance.high,
      payload: 'order:${order.id}',
    );
    if (_soundEnabled) {
      await _playAlertSound();
    }

    await _emit(
      eventName: 'orders.restaurant_kot.status_changed',
      category: uns.EventCategory.orders,
      subCategory: 'restaurant_kot',
      priority: uns.EventPriority.high,
      targetId: order.id,
      payload: <String, dynamic>{
        'order_id': order.id,
        'kot_id': order.id,
        'vendor_id': order.vendorId,
        'table_id': order.tableId,
        'table_number': order.tableNumber,
        'minutes_waiting': minutesWaiting,
        'action': 'delay_alert',
      },
      recipients: <uns.Recipient>[
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.chef,
          targetId: order.id,
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.kitchenStaff,
          targetId: order.id,
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.waiter,
          targetId: order.id,
        ),
        uns.Recipient(
          userId: order.vendorId,
          role: uns.RecipientRole.shopOwner,
          targetId: order.id,
        ),
      ],
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: const <String>['order_id', 'action'],
    );
  }

  /// KOT lifecycle update — used by the kitchen display screen.
  ///
  /// Maps to one of `orders.restaurant_kot.created`,
  /// `orders.restaurant_kot.status_changed`, or
  /// `orders.restaurant_kot.item_cancelled` per the registry §7.2..7.4 (T-RES-2).
  ///
  /// Local notification rendering is best-effort (the kitchen display is the
  /// primary surface), but the audible bell still rings on `created`.
  Future<void> notifyKotItem({
    required RestaurantKotStage stage,
    required String kotId,
    required String orderId,
    required String vendorId,
    String? tableNumber,
    String? newStatus,
    String? itemName,
    String? cancellationReason,
  }) async {
    final String channelId;
    final String channelLabel;
    final String title;
    final String body;
    switch (stage) {
      case RestaurantKotStage.created:
        channelId = 'kot_created';
        channelLabel = 'New KOTs';
        title = '🍳 New KOT';
        body =
            'Order ${tableNumber != null ? 'Table $tableNumber' : orderId} - new ticket';
        break;
      case RestaurantKotStage.statusChanged:
        channelId = 'kot_status';
        channelLabel = 'KOT Status';
        title = '🔄 KOT ${newStatus ?? 'updated'}';
        body =
            'Order ${tableNumber != null ? 'Table $tableNumber' : orderId} - ${newStatus ?? 'status changed'}';
        break;
      case RestaurantKotStage.itemCancelled:
        channelId = 'kot_cancelled';
        channelLabel = 'KOT Cancellations';
        title = '🚫 KOT item cancelled';
        body = itemName != null
            ? 'Cancelled: $itemName'
            : 'A KOT item was cancelled';
        break;
    }

    await _showNotification(
      id: ('$kotId|${stage.name}').hashCode,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelLabel,
      importance: Importance.high,
      payload: 'kot:$kotId',
    );

    if (stage == RestaurantKotStage.created && _soundEnabled) {
      await _playOrderBell();
    }

    final String eventName;
    switch (stage) {
      case RestaurantKotStage.created:
        eventName = 'orders.restaurant_kot.created';
        break;
      case RestaurantKotStage.statusChanged:
        eventName = 'orders.restaurant_kot.status_changed';
        break;
      case RestaurantKotStage.itemCancelled:
        eventName = 'orders.restaurant_kot.item_cancelled';
        break;
    }

    final payload = <String, dynamic>{
      'kot_id': kotId,
      'order_id': orderId,
      'vendor_id': vendorId,
      'table_number': ?tableNumber,
      'new_status': ?newStatus,
      'item_name': ?itemName,
      'cancellation_reason': ?cancellationReason,
    };

    final recipients = <uns.Recipient>[
      uns.Recipient(
        userId: vendorId,
        role: uns.RecipientRole.chef,
        targetId: kotId,
      ),
      uns.Recipient(
        userId: vendorId,
        role: uns.RecipientRole.kitchenStaff,
        targetId: kotId,
      ),
      uns.Recipient(
        userId: vendorId,
        role: uns.RecipientRole.waiter,
        targetId: kotId,
      ),
      uns.Recipient(
        userId: vendorId,
        role: uns.RecipientRole.shopOwner,
        targetId: kotId,
      ),
    ];

    await _emit(
      eventName: eventName,
      category: uns.EventCategory.orders,
      subCategory: 'restaurant_kot',
      priority: uns.EventPriority.high,
      targetId: kotId,
      payload: payload,
      recipients: recipients,
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: <String>[
        'kot_id',
        if (newStatus != null) 'new_status',
        if (itemName != null) 'item_name',
      ],
    );
  }

  /// Restaurant table changed status (free / seated / billed / settled).
  ///
  /// UNS event: `orders.restaurant_table.status_changed` (T-RES-5, registry §7.6).
  Future<void> notifyTableStatusChanged({
    required String vendorId,
    required String tableId,
    required String tableNumber,
    required String newStatus,
    String? previousStatus,
  }) async {
    await _showNotification(
      id: ('table:$tableId|$newStatus').hashCode,
      title: '🪑 Table $tableNumber',
      body: previousStatus != null
          ? '$previousStatus → $newStatus'
          : 'Status: $newStatus',
      channelId: 'table_status',
      channelName: 'Table Status',
      payload: 'table:$tableId',
    );

    await _emit(
      eventName: 'orders.restaurant_table.status_changed',
      category: uns.EventCategory.orders,
      subCategory: 'restaurant_table',
      priority: uns.EventPriority.normal,
      targetId: tableId,
      payload: <String, dynamic>{
        'vendor_id': vendorId,
        'table_id': tableId,
        'table_number': tableNumber,
        'new_status': newStatus,
        'previous_status': ?previousStatus,
      },
      recipients: <uns.Recipient>[
        uns.Recipient(
          userId: vendorId,
          role: uns.RecipientRole.shopOwner,
          targetId: tableId,
        ),
        uns.Recipient(
          userId: vendorId,
          role: uns.RecipientRole.waiter,
          targetId: tableId,
        ),
        uns.Recipient(
          userId: vendorId,
          role: uns.RecipientRole.cashier,
          targetId: tableId,
        ),
      ],
      channels: const <uns.NotificationChannel>[uns.NotificationChannel.inApp],
      dedupScopeFields: const <String>['table_id', 'new_status'],
    );
  }

  /// Restaurant delivery dispatched to an agent.
  ///
  /// UNS event: `delivery.restaurant.dispatched` (T-RES-7, registry §8.1).
  Future<void> notifyDeliveryDispatched({
    required String vendorId,
    required String orderId,
    required String agentId,
    String? agentName,
    String? customerId,
  }) async {
    await _showNotification(
      id: ('delivery:$orderId').hashCode,
      title: '🛵 Delivery dispatched',
      body: agentName != null
          ? 'Order $orderId assigned to $agentName'
          : 'Order $orderId dispatched',
      channelId: 'delivery_dispatch',
      channelName: 'Restaurant Delivery',
      importance: Importance.high,
      payload: 'order:$orderId',
    );

    await _emit(
      eventName: 'delivery.restaurant.dispatched',
      category: uns.EventCategory.delivery,
      subCategory: 'restaurant_delivery',
      priority: uns.EventPriority.high,
      targetId: orderId,
      payload: <String, dynamic>{
        'order_id': orderId,
        'vendor_id': vendorId,
        'agent_id': agentId,
        'agent_name': ?agentName,
        'customer_id': ?customerId,
      },
      recipients: <uns.Recipient>[
        uns.Recipient(
          userId: vendorId,
          role: uns.RecipientRole.shopOwner,
          targetId: orderId,
        ),
        uns.Recipient(
          userId: agentId,
          role: uns.RecipientRole.deliveryAgent,
          targetId: orderId,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ],
        ),
        if (customerId != null)
          uns.Recipient(
            userId: customerId,
            role: uns.RecipientRole.customer,
            targetId: orderId,
            channels: const <uns.NotificationChannel>[
              uns.NotificationChannel.inApp,
              uns.NotificationChannel.push,
            ],
          ),
      ],
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: const <String>['order_id'],
    );
  }

  // ==========================================================================
  // CUSTOMER NOTIFICATIONS
  // ==========================================================================

  /// Customer-side acceptance toast. No registry event today (the
  /// `restaurant.created` event already carries the same intent at a
  /// vendor level), so this stays as a local-only cue.
  Future<void> notifyOrderAccepted(String orderId, String? tableNumber) async {
    await _showNotification(
      id: orderId.hashCode,
      title: '✅ Order Accepted',
      body: 'Your order is being prepared',
      channelId: 'order_updates',
      channelName: 'Order Updates',
      payload: 'order:$orderId',
    );
  }

  /// Order ready for pickup / serving.
  ///
  /// UNS event: `orders.restaurant_kot.item_ready` (T-RES-3, registry §7.5).
  Future<void> notifyOrderReady(
    String orderId,
    String? tableNumber, {
    String? vendorId,
    String? customerId,
  }) async {
    await _showNotification(
      id: orderId.hashCode,
      title: '🍽️ Order Ready!',
      body: 'Your delicious food is ready to serve',
      channelId: 'order_updates',
      channelName: 'Order Updates',
      importance: Importance.high,
      payload: 'order:$orderId',
    );
    if (_soundEnabled) {
      await _playNotificationSound();
    }

    final resolvedVendor = vendorId ?? _currentVendorId();
    final recipients = <uns.Recipient>[
      uns.Recipient(
        userId: resolvedVendor,
        role: uns.RecipientRole.waiter,
        targetId: orderId,
        channels: const <uns.NotificationChannel>[
          uns.NotificationChannel.inApp,
        ],
      ),
      uns.Recipient(
        userId: resolvedVendor,
        role: uns.RecipientRole.shopOwner,
        targetId: orderId,
      ),
      if (customerId != null)
        uns.Recipient(
          userId: customerId,
          role: uns.RecipientRole.customer,
          targetId: orderId,
          channels: const <uns.NotificationChannel>[
            uns.NotificationChannel.inApp,
            uns.NotificationChannel.push,
          ],
        ),
    ];

    await _emit(
      eventName: 'orders.restaurant_kot.item_ready',
      category: uns.EventCategory.orders,
      subCategory: 'restaurant_kot',
      priority: uns.EventPriority.high,
      targetId: orderId,
      payload: <String, dynamic>{
        'order_id': orderId,
        'vendor_id': resolvedVendor,
        'table_number': ?tableNumber,
        'customer_id': ?customerId,
      },
      recipients: recipients,
      channels: const <uns.NotificationChannel>[
        uns.NotificationChannel.inApp,
        uns.NotificationChannel.push,
      ],
      dedupScopeFields: const <String>['order_id'],
    );
  }

  /// Customer-side served toast — no registry event (covered by KOT served
  /// status which is emitted by the kitchen display screen separately).
  Future<void> notifyOrderServed(String orderId) async {
    await _showNotification(
      id: orderId.hashCode,
      title: '🎉 Enjoy Your Meal!',
      body: 'Your order has been served. Bon appétit!',
      channelId: 'order_updates',
      channelName: 'Order Updates',
      payload: 'order:$orderId',
    );
  }

  // ==========================================================================
  // SOUND EFFECTS
  // ==========================================================================

  Future<void> _playOrderBell() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/order_bell.mp3'));
    } catch (_) {
      await _playSystemSound();
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {
      await _playSystemSound();
    }
  }

  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
    } catch (_) {
      await _playSystemSound();
    }
  }

  Future<void> _playSystemSound() async {
    try {
      await _audioPlayer.play(
        UrlSource('https://www.soundjay.com/button/beep-07.wav'),
      );
    } catch (_) {
      // Silent fallback.
    }
  }

  /// Public entry point used by tests / settings screens to fire the bell.
  Future<void> playOrderBell() async {
    if (_soundEnabled) {
      await _playOrderBell();
    }
  }

  // ==========================================================================
  // UNS EMIT HELPER
  // ==========================================================================

  /// Build the canonical Event_Contract envelope and hand it to the SDK.
  ///
  /// Failures are swallowed at this boundary: an SDK outage MUST NOT block
  /// the local notification rendering or downstream POS flow. The SDK's own
  /// outbox handles transient unavailability (REQ 8.8); only schema or
  /// permanent client errors are logged, after which they are dropped on the
  /// floor for this surface.
  Future<void> _emit({
    required String eventName,
    required uns.EventCategory category,
    required uns.EventPriority priority,
    required String targetId,
    required Map<String, dynamic> payload,
    required List<uns.Recipient> recipients,
    required List<uns.NotificationChannel> channels,
    String? subCategory,
    List<String>? dedupScopeFields,
  }) async {
    final sdk = _resolveSdk();
    if (sdk == null) {
      // SDK not yet ready (very early bootstrap) or running in a test
      // context that didn't wire it. Local rendering already happened —
      // there's nothing more to do.
      return;
    }

    try {
      final eventId = _uuid.v4();
      final actorId = _currentActorId();
      final dedupKey = _buildDedupKey(
        eventName: eventName,
        actorId: actorId,
        targetId: targetId,
        scopeFields: dedupScopeFields,
        payload: payload,
      );

      final event = uns.EventContract(
        id: eventId,
        eventName: eventName,
        category: category,
        subCategory: subCategory,
        priority: priority,
        actorId: actorId,
        targetId: targetId,
        recipients: recipients,
        payload: payload,
        channels: channels,
        sourceModule:
            'Dukan_x/lib/features/restaurant/domain/services/restaurant_notification_service.dart',
        sourceApp: uns.SourceApp.dukanxDesktop,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        dedupKey: dedupKey,
        dedupScopeFields: dedupScopeFields,
      );

      await sdk.emit(event);
    } catch (e, stack) {
      debugPrint(
        '[RestaurantNotificationService] UNS emit "$eventName" failed: $e\n$stack',
      );
    }
  }

  /// Best-effort actor id — falls back to a synthetic id when the session
  /// resolver hasn't surfaced a concrete user id yet.
  String _currentActorId() {
    try {
      final actor = _actorResolver?.call();
      if (actor != null && actor.actorId.isNotEmpty) return actor.actorId;
    } catch (_) {
      // Resolver not registered (unit tests) — fall through.
    }
    return 'restaurant-pos';
  }

  /// Best-effort vendor id — used for recipients when the caller didn't
  /// supply one (e.g. legacy `notifyBillRequested(...)` two-arg signature).
  String _currentVendorId() {
    try {
      final actor = _actorResolver?.call();
      if (actor != null && actor.vendorId.isNotEmpty) return actor.vendorId;
    } catch (_) {
      // ignored
    }
    return 'restaurant-vendor';
  }

  /// Deduplication key derivation matching design.md / registry semantics:
  /// `(event_name, actor_id, target_id, dedup_scope_fields → values)`.
  String _buildDedupKey({
    required String eventName,
    required String actorId,
    required String targetId,
    required List<String>? scopeFields,
    required Map<String, dynamic> payload,
  }) {
    final buffer = StringBuffer()
      ..write(eventName)
      ..write(':')
      ..write(actorId)
      ..write(':')
      ..write(targetId);
    if (scopeFields != null && scopeFields.isNotEmpty) {
      for (final field in scopeFields) {
        buffer
          ..write(':')
          ..write(field)
          ..write('=')
          ..write(payload[field]?.toString() ?? '');
      }
    }
    return buffer.toString();
  }

  // ==========================================================================
  // LOCAL NOTIFICATION HELPER (preserved legacy surface)
  // ==========================================================================

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? sound,
    Importance importance = Importance.defaultImportance,
    String? payload,
  }) async {
    // Local rendering is best-effort: a missing platform implementation
    // (test harness, headless desktop, sandboxed Linux container) MUST NOT
    // prevent the canonical UNS emit on the same flow. We swallow any
    // failure and let the caller continue.
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: importance == Importance.high
            ? Priority.high
            : Priority.defaultPriority,
        playSound: sound != null,
        enableVibration: true,
        ticker: title,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
        '[RestaurantNotificationService] local notification "$title" '
        'skipped: $e',
      );
    }
  }

  /// Cancel a specific notification.
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {
      // Plugin not initialised — nothing to cancel.
    }
  }

  /// Cancel all notifications.
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {
      // Plugin not initialised — nothing to cancel.
    }
  }

  /// Dispose resources.
  void dispose() {
    _audioPlayerInstance?.dispose();
    _audioPlayerInstance = null;
  }
}
