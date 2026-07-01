// ============================================================================
// VENDOR NOTIFICATION REPOSITORY
// ============================================================================
// Manages vendor-side notifications for alerts, payments, stock, etc.
// Separate from CustomerNotifications which are for customer app.
//
// Notification Types:
// - LOW_STOCK: Product running low
// - EXPIRY_WARNING: Product expiring soon
// - PAYMENT_RECEIVED: Customer payment received
// - NEW_ORDER: New order placed
// - SYNC_ISSUE: Sync problems detected
// ============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../di/service_locator.dart';

/// Notification types for vendor app
enum VendorNotificationType {
  lowStock('LOW_STOCK'),
  expiryWarning('EXPIRY_WARNING'),
  paymentReceived('PAYMENT_RECEIVED'),
  newOrder('NEW_ORDER'),
  returnRequest('RETURN_REQUEST'),
  syncIssue('SYNC_ISSUE'),
  systemAlert('SYSTEM_ALERT'),
  dailySummary('DAILY_SUMMARY');

  final String value;
  const VendorNotificationType(this.value);

  static VendorNotificationType fromString(String value) {
    return VendorNotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VendorNotificationType.systemAlert,
    );
  }
}

/// Vendor notification model
class VendorNotification {
  final String id;
  final String userId;
  final VendorNotificationType type;
  final String title;
  final String message;
  final String? actionType; // VIEW_PRODUCT, VIEW_BILL, etc.
  final String? actionId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  VendorNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.actionType,
    this.actionId,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  /// Get icon for notification type
  String get iconName {
    switch (type) {
      case VendorNotificationType.lowStock:
        return 'warning_amber';
      case VendorNotificationType.expiryWarning:
        return 'schedule';
      case VendorNotificationType.paymentReceived:
        return 'payments';
      case VendorNotificationType.newOrder:
        return 'shopping_cart';
      case VendorNotificationType.returnRequest:
        return 'assignment_return';
      case VendorNotificationType.syncIssue:
        return 'cloud_off';
      case VendorNotificationType.systemAlert:
        return 'info';
      case VendorNotificationType.dailySummary:
        return 'summarize';
    }
  }

  /// Get color for notification type
  int get colorValue {
    switch (type) {
      case VendorNotificationType.lowStock:
        return 0xFFF59E0B; // Amber
      case VendorNotificationType.expiryWarning:
        return 0xFFEF4444; // Red
      case VendorNotificationType.paymentReceived:
        return 0xFF10B981; // Green
      case VendorNotificationType.newOrder:
        return 0xFF3B82F6; // Blue
      case VendorNotificationType.returnRequest:
        return 0xFFF97316; // Orange
      case VendorNotificationType.syncIssue:
        return 0xFF8B5CF6; // Purple
      case VendorNotificationType.systemAlert:
        return 0xFF6B7280; // Gray
      case VendorNotificationType.dailySummary:
        return 0xFF06B6D4; // Cyan
    }
  }
}

/// Repository for vendor notifications
class VendorNotificationRepository {
  final AppDatabase _db;

  VendorNotificationRepository({AppDatabase? db})
    : _db = db ?? sl<AppDatabase>();

  /// Create a new notification
  Future<VendorNotification> createNotification({
    required String userId,
    required VendorNotificationType type,
    required String title,
    required String message,
    String? actionType,
    String? actionId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final notification = VendorNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      actionType: actionType,
      actionId: actionId,
      isRead: false,
      createdAt: now,
    );

    // Insert into local database using CustomerNotifications table
    // (Reusing existing table structure)
    await _db
        .into(_db.customerNotifications)
        .insert(
          CustomerNotificationsCompanion(
            id: Value(id),
            customerId: Value(userId), // Using customerId field for userId
            vendorId: const Value(null),
            notificationType: Value(type.value),
            title: Value(title),
            body: Value(message),
            actionType: Value(actionType),
            actionId: Value(actionId),
            isRead: const Value(false),
            createdAt: Value(now),
          ),
        );

    return notification;
  }

  /// Create low stock notification helper
  Future<VendorNotification> createLowStockNotification({
    required String userId,
    required String productId,
    required String productName,
    required double currentQty,
    required double lowStockLimit,
  }) {
    return createNotification(
      userId: userId,
      type: VendorNotificationType.lowStock,
      title: 'Low Stock Alert',
      message:
          '$productName is running low (${currentQty.toInt()} remaining, limit: ${lowStockLimit.toInt()})',
      actionType: 'VIEW_PRODUCT',
      actionId: productId,
    );
  }

  /// Create expiry warning notification helper
  Future<VendorNotification> createExpiryNotification({
    required String userId,
    required String productId,
    required String productName,
    required String? batchNumber,
    required DateTime expiryDate,
  }) {
    final isExpired = expiryDate.isBefore(DateTime.now());
    final batchInfo = batchNumber != null ? ' (Batch: $batchNumber)' : '';

    return createNotification(
      userId: userId,
      type: VendorNotificationType.expiryWarning,
      title: isExpired ? '⚠️ Product Expired' : '⏰ Expiring Soon',
      message:
          '$productName$batchInfo ${isExpired ? "has expired" : "expires on ${_formatDate(expiryDate)}"}',
      actionType: 'VIEW_PRODUCT',
      actionId: productId,
    );
  }

  /// Create payment received notification helper
  Future<VendorNotification> createPaymentNotification({
    required String userId,
    required String customerId,
    required String customerName,
    required double amount,
    required String? billId,
  }) {
    return createNotification(
      userId: userId,
      type: VendorNotificationType.paymentReceived,
      title: 'Payment Received',
      message: '₹${amount.toStringAsFixed(0)} received from $customerName',
      actionType: billId != null ? 'VIEW_BILL' : 'VIEW_CUSTOMER',
      actionId: billId ?? customerId,
    );
  }

  /// Watch all notifications for a user
  Stream<List<VendorNotification>> watchNotifications(String userId) {
    final query = _db.select(_db.customerNotifications)
      ..where((t) => t.customerId.equals(userId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => VendorNotification(
              id: row.id,
              userId: row.customerId,
              type: VendorNotificationType.fromString(row.notificationType),
              title: row.title,
              message: row.body,
              actionType: row.actionType,
              actionId: row.actionId,
              isRead: row.isRead,
              createdAt: row.createdAt,
              readAt: row.readAt,
            ),
          )
          .toList();
    });
  }

  /// Get unread count
  Future<int> getUnreadCount(String userId) async {
    final query = _db.select(_db.customerNotifications)
      ..where((t) => t.customerId.equals(userId) & t.isRead.equals(false));

    final results = await query.get();
    return results.length;
  }

  /// Watch unread count
  Stream<int> watchUnreadCount(String userId) {
    final query = _db.select(_db.customerNotifications)
      ..where((t) => t.customerId.equals(userId) & t.isRead.equals(false));

    return query.watch().map((rows) => rows.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    final now = DateTime.now();

    await (_db.update(
      _db.customerNotifications,
    )..where((t) => t.id.equals(id))).write(
      CustomerNotificationsCompanion(
        isRead: const Value(true),
        readAt: Value(now),
      ),
    );
  }

  /// Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final now = DateTime.now();

    await (_db.update(_db.customerNotifications)
          ..where((t) => t.customerId.equals(userId) & t.isRead.equals(false)))
        .write(
          CustomerNotificationsCompanion(
            isRead: const Value(true),
            readAt: Value(now),
          ),
        );
  }

  /// Delete old notifications (cleanup)
  Future<int> deleteOldNotifications(String userId, {int daysOld = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));

    final deleted =
        await (_db.delete(_db.customerNotifications)..where(
              (t) =>
                  t.customerId.equals(userId) &
                  t.createdAt.isSmallerThanValue(cutoff),
            ))
            .go();

    return deleted;
  }

  /// Helper to format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
