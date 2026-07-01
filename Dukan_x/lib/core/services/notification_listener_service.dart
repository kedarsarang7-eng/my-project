import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repository/vendor_notification_repository.dart';
import '../repository/customers_repository.dart';
import 'event_dispatcher.dart';

/// Notification Listener Service
///
/// Listens to [EventDispatcher] events and generates persistent
/// notifications in [VendorNotificationRepository].
///
/// This bridges the gap between ephemeral events (stock changed)
/// and persistent alerts (viewable in Notification Center).
class NotificationListenerService {
  final EventDispatcher _dispatcher;
  final VendorNotificationRepository _notificationRepo;
  final CustomersRepository _customersRepo;

  StreamSubscription? _subscription;

  NotificationListenerService({
    required EventDispatcher dispatcher,
    required VendorNotificationRepository notificationRepo,
    required CustomersRepository customersRepo,
  }) : _dispatcher = dispatcher,
       _notificationRepo = notificationRepo,
       _customersRepo = customersRepo;

  /// Initialize listeners
  void initialize() {
    if (_subscription != null) return;

    _subscription = _dispatcher.events.listen(_handleEvent);
    debugPrint('NotificationListenerService: Initialized');
  }

  /// Dispose listeners
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleEvent(BusinessEventData eventData) async {
    final userId = eventData.userId;
    if (userId == null) return;

    try {
      switch (eventData.event) {
        case BusinessEvent.stockLow:
          await _handleLowStock(eventData, userId);
          break;

        case BusinessEvent.paymentReceived:
          await _handlePaymentReceived(eventData, userId);
          break;

        case BusinessEvent.batchExpiring:
        case BusinessEvent.batchExpired:
          // Periodic expiry checks implementation pending
          // _dailySnapshot.checkExpiry(); is currently pull-based in AlertService, but can be push-based here
          break;

        default:
          // Ignore other events for now
          break;
      }
    } catch (e) {
      debugPrint(
        'NotificationListenerService: Error handling event ${eventData.event}: $e',
      );
    }
  }

  Future<void> _handleLowStock(
    BusinessEventData eventData,
    String userId,
  ) async {
    final productName = eventData.get<String>('productName');
    final productId = eventData.get<String>('productId');
    final currentQty = eventData.get<double>('currentQty');
    final lowStockLimit = eventData.get<double>('lowStockLimit');

    if (productName != null &&
        productId != null &&
        currentQty != null &&
        lowStockLimit != null) {
      await _notificationRepo.createLowStockNotification(
        userId: userId,
        productId: productId,
        productName: productName,
        currentQty: currentQty,
        lowStockLimit: lowStockLimit,
      );
    }
  }

  Future<void> _handlePaymentReceived(
    BusinessEventData eventData,
    String userId,
  ) async {
    final customerId = eventData.get<String>('customerId');
    final amount = eventData.get<double>('amount');
    final billId = eventData.get<String>('billId');

    if (customerId != null && amount != null) {
      // Fetch customer name
      String customerName = 'Customer';
      try {
        final result = await _customersRepo.getById(customerId);
        if (result.data != null) {
          customerName = result.data!.name;
        }
      } catch (e) {
        // Fallback
      }

      await _notificationRepo.createPaymentNotification(
        userId: userId,
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        billId: billId,
      );
    }
  }
}
