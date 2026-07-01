// ============================================================================
// EVENT DISPATCHER - CENTRAL EVENT BUS
// ============================================================================
// Cross-module event communication for DukanX.
// Enables loose coupling between features while maintaining data consistency.
//
// Events:
// - InvoiceCreated → Updates dashboard, notifications, analytics
// - PaymentReceived → Updates ledger, reduces outstanding, triggers reminders
// - StockChanged → Low stock alerts, inventory analytics
// - ReturnProcessed → Stock restoration, credit notes, ledger adjustments
// - PurchaseOrderCreated → Procurement tracking, supplier ledger
// - SupplierBillAdded → Payables update, accounting entries
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Business events that trigger cross-module updates
enum BusinessEvent {
  // Sales Events
  invoiceCreated,
  invoiceUpdated,
  invoiceCancelled,

  // Payment Events
  paymentReceived,
  paymentDeleted,
  advancePaymentReceived,

  // Stock Events
  stockChanged,
  stockLow,
  stockDepleted,
  batchExpiring,
  batchExpired,

  // Return Events
  returnProcessed,
  creditNoteIssued,

  // Procurement Events
  purchaseOrderCreated,
  purchaseOrderCompleted,
  supplierBillAdded,
  supplierPaymentMade,

  // System Events
  dailySnapshotGenerated,
  syncCompleted,
  syncFailed,

  // Service Events
  jobStatusChanged,

  // Stock Restoration Events
  stockRestored,
}

/// Data payload for business events
class BusinessEventData {
  final BusinessEvent event;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? userId;

  BusinessEventData({
    required this.event,
    required this.data,
    required this.timestamp,
    this.userId,
  });

  /// Get a typed value from data
  T? get<T>(String key) {
    final value = data[key];
    if (value is T) return value;
    return null;
  }

  @override
  String toString() =>
      'BusinessEventData(event: $event, data: $data, timestamp: $timestamp)';
}

/// Central event dispatcher for cross-module communication
///
/// Usage:
/// ```dart
/// // Subscribe to events
/// EventDispatcher.instance.events.listen((event) {
///   if (event.event == BusinessEvent.invoiceCreated) {
///     // Handle invoice created
///   }
/// });
///
/// // Dispatch events
/// EventDispatcher.instance.dispatch(
///   BusinessEvent.invoiceCreated,
///   {'billId': bill.id, 'amount': bill.grandTotal},
///   userId: currentUserId,
/// );
/// ```
class EventDispatcher {
  // Singleton instance
  static final EventDispatcher _instance = EventDispatcher._internal();
  static EventDispatcher get instance => _instance;

  EventDispatcher._internal();

  // Broadcast stream controller for events
  final _controller = StreamController<BusinessEventData>.broadcast();

  /// Stream of all business events
  Stream<BusinessEventData> get events => _controller.stream;

  /// Filter events by type
  Stream<BusinessEventData> where(BusinessEvent event) {
    return _controller.stream.where((e) => e.event == event);
  }

  /// Filter events by multiple types
  Stream<BusinessEventData> whereAny(List<BusinessEvent> events) {
    return _controller.stream.where((e) => events.contains(e.event));
  }

  /// Dispatch a business event
  ///
  /// [event] - The type of event
  /// [data] - Event payload (IDs, amounts, etc.)
  /// [userId] - Optional user context
  void dispatch(
    BusinessEvent event,
    Map<String, dynamic> data, {
    String? userId,
  }) {
    final eventData = BusinessEventData(
      event: event,
      data: data,
      timestamp: DateTime.now(),
      userId: userId,
    );

    _controller.add(eventData);

    // Debug logging in development
    assert(() {
      debugPrint('[EventDispatcher] ${event.name}: $data');
      return true;
    }());
  }

  /// Dispatch invoice created event
  void invoiceCreated({
    required String billId,
    required String? customerId,
    required double amount,
    required String userId,
  }) {
    dispatch(BusinessEvent.invoiceCreated, {
      'billId': billId,
      'customerId': customerId,
      'amount': amount,
    }, userId: userId);
  }

  /// Dispatch payment received event
  void paymentReceived({
    required String receiptId,
    required String? billId,
    required String customerId,
    required double amount,
    required String paymentMode,
    required String userId,
  }) {
    dispatch(BusinessEvent.paymentReceived, {
      'receiptId': receiptId,
      'billId': billId,
      'customerId': customerId,
      'amount': amount,
      'paymentMode': paymentMode,
    }, userId: userId);
  }

  /// Dispatch stock changed event
  void stockChanged({
    required String productId,
    required double oldQty,
    required double newQty,
    required String reason,
    required String userId,
  }) {
    dispatch(BusinessEvent.stockChanged, {
      'productId': productId,
      'oldQty': oldQty,
      'newQty': newQty,
      'reason': reason,
    }, userId: userId);
  }

  /// Dispatch low stock alert event
  void stockLow({
    required String productId,
    required String productName,
    required double currentQty,
    required double lowStockLimit,
    required String userId,
  }) {
    dispatch(BusinessEvent.stockLow, {
      'productId': productId,
      'productName': productName,
      'currentQty': currentQty,
      'lowStockLimit': lowStockLimit,
    }, userId: userId);
  }

  /// Dispatch return processed event
  void returnProcessed({
    required String returnId,
    required String? billId,
    required String customerId,
    required double amount,
    required List<Map<String, dynamic>> items,
    required String userId,
  }) {
    dispatch(BusinessEvent.returnProcessed, {
      'returnId': returnId,
      'billId': billId,
      'customerId': customerId,
      'amount': amount,
      'items': items,
    }, userId: userId);
  }

  /// Dispatch purchase order created event
  void purchaseOrderCreated({
    required String purchaseId,
    required String? vendorId,
    required double amount,
    required String userId,
  }) {
    dispatch(BusinessEvent.purchaseOrderCreated, {
      'purchaseId': purchaseId,
      'vendorId': vendorId,
      'amount': amount,
    }, userId: userId);
  }

  /// Dispose resources
  void dispose() {
    _controller.close();
  }
}
