// ============================================================================
// CUSTOMER NOTIFICATIONS REPOSITORY
// ============================================================================
// Local Drift cache of notifications previously written by the legacy
// helper. Kept as a READ-ONLY cache so existing code paths that surface
// historical entries continue to work; new emits flow through the
// Unified Notification System (UNS) Shared_SDK instead.
//
// Migration: UNS task 14.5 (T-CUS-3, T-CUS-4, T-CUS-5, T-PAY-8).
// The legacy `createNotification` emit path was removed in this migration
// window per migration_status.md §1: exactly one path (legacy OR UNS) is
// active per Trigger_Point at any time. New emit sites call
// `Shared_SDK.emit(...)` (see customer_payment_screen.dart and
// customer_link_accept_screen.dart).
//
// Author: DukanX Engineering
// Version: 2.0.0 — UNS migration (read-only cache)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/di/service_locator.dart';

// ============================================================================
// MODELS
// ============================================================================

enum NotificationType {
  newInvoice,
  paymentReminder,
  paymentReceived,
  dueDateAlert,
  promotional,
  systemAlert,
}

/// Notification for customer view (cached read model only).
class CustomerNotification {
  final String id;
  final String customerId;
  final String? vendorId;
  final NotificationType notificationType;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final String? actionType;
  final String? actionId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime? expiresAt;

  CustomerNotification({
    required this.id,
    required this.customerId,
    this.vendorId,
    required this.notificationType,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    this.actionType,
    this.actionId,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.expiresAt,
  });

  factory CustomerNotification.fromEntity(CustomerNotificationEntity e) {
    Map<String, dynamic>? data;
    if (e.dataJson != null) {
      try {
        data = jsonDecode(e.dataJson!) as Map<String, dynamic>;
      } catch (_) {}
    }

    return CustomerNotification(
      id: e.id,
      customerId: e.customerId,
      vendorId: e.vendorId,
      notificationType: _parseNotificationType(e.notificationType),
      title: e.title,
      body: e.body,
      imageUrl: e.imageUrl,
      data: data,
      actionType: e.actionType,
      actionId: e.actionId,
      isRead: e.isRead,
      readAt: e.readAt,
      createdAt: e.createdAt,
      expiresAt: e.expiresAt,
    );
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type.toUpperCase()) {
      case 'NEW_INVOICE':
        return NotificationType.newInvoice;
      case 'PAYMENT_REMINDER':
        return NotificationType.paymentReminder;
      case 'PAYMENT_RECEIVED':
        return NotificationType.paymentReceived;
      case 'DUE_DATE_ALERT':
        return NotificationType.dueDateAlert;
      case 'PROMOTIONAL':
        return NotificationType.promotional;
      case 'SYSTEM_ALERT':
        return NotificationType.systemAlert;
      default:
        return NotificationType.systemAlert;
    }
  }

  String get notificationTypeString {
    switch (notificationType) {
      case NotificationType.newInvoice:
        return 'NEW_INVOICE';
      case NotificationType.paymentReminder:
        return 'PAYMENT_REMINDER';
      case NotificationType.paymentReceived:
        return 'PAYMENT_RECEIVED';
      case NotificationType.dueDateAlert:
        return 'DUE_DATE_ALERT';
      case NotificationType.promotional:
        return 'PROMOTIONAL';
      case NotificationType.systemAlert:
        return 'SYSTEM_ALERT';
    }
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  CustomerNotification copyWith({bool? isRead, DateTime? readAt}) {
    return CustomerNotification(
      id: id,
      customerId: customerId,
      vendorId: vendorId,
      notificationType: notificationType,
      title: title,
      body: body,
      imageUrl: imageUrl,
      data: data,
      actionType: actionType,
      actionId: actionId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

// ============================================================================
// REPOSITORY (READ-ONLY CACHE LAYER)
// ============================================================================

/// Read-only cache layer over the legacy `customer_notifications` Drift
/// table. After UNS task 14.5 the repository no longer accepts new emits —
/// every caller that previously invoked `createNotification` now goes
/// through `Shared_SDK.emit(...)` and the canonical Notification_Service
/// path. The methods that remain are pure read/cache operations preserved
/// so historical entries already on-disk stay viewable until cold-storage
/// archival kicks in.
class CustomerNotificationsRepository {
  final AppDatabase database;
  final ErrorHandler errorHandler;

  CustomerNotificationsRepository({
    required this.database,
    required this.errorHandler,
  });

  // ============================================
  // CACHED READS
  // ============================================

  /// Get all cached notifications for a customer.
  Future<RepositoryResult<List<CustomerNotification>>> getNotifications(
    String customerId, {
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    return errorHandler.runSafe(() async {
      var query = database.select(database.customerNotifications)
        ..where((t) => t.customerId.equals(customerId));

      if (unreadOnly) {
        query = query..where((t) => t.isRead.equals(false));
      }

      query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      query.limit(limit);

      final entities = await query.get();
      return entities
          .map(CustomerNotification.fromEntity)
          .where((n) => !n.isExpired)
          .toList();
    }, 'getNotifications');
  }

  /// Watch cached notifications stream.
  Stream<List<CustomerNotification>> watchNotifications(
    String customerId, {
    bool unreadOnly = false,
  }) {
    var query = database.select(database.customerNotifications)
      ..where((t) => t.customerId.equals(customerId));

    if (unreadOnly) {
      query = query..where((t) => t.isRead.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    query.limit(100);

    return query.watch().map(
      (entities) => entities
          .map(CustomerNotification.fromEntity)
          .where((n) => !n.isExpired)
          .toList(),
    );
  }

  /// Get unread count from the cache.
  Future<RepositoryResult<int>> getUnreadCount(String customerId) async {
    return errorHandler.runSafe(() async {
      final count =
          await (database.select(database.customerNotifications)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.isRead.equals(false)))
              .get();

      return count.length;
    }, 'getUnreadCount');
  }

  /// Watch unread count from the cache.
  Stream<int> watchUnreadCount(String customerId) {
    return (database.select(database.customerNotifications)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.isRead.equals(false)))
        .watch()
        .map((list) => list.length);
  }

  /// Mark a cached notification as read locally. The canonical
  /// `markAsRead` for UNS-delivered items lives on
  /// `NotificationsUiClient.markAsRead` and is invoked by the shared
  /// drawer widget; this method only touches the legacy cache rows that
  /// pre-date the migration.
  Future<RepositoryResult<bool>> markAsRead(String notificationId) async {
    return errorHandler.runSafe(() async {
      final now = DateTime.now();

      await (database.update(
        database.customerNotifications,
      )..where((t) => t.id.equals(notificationId))).write(
        CustomerNotificationsCompanion(
          isRead: const Value(true),
          readAt: Value(now),
        ),
      );

      return true;
    }, 'markAsRead');
  }

  /// Mark all cached notifications as read locally.
  Future<RepositoryResult<int>> markAllAsRead(String customerId) async {
    return errorHandler.runSafe(() async {
      final now = DateTime.now();

      final updated =
          await (database.update(database.customerNotifications)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.isRead.equals(false)))
              .write(
                CustomerNotificationsCompanion(
                  isRead: const Value(true),
                  readAt: Value(now),
                ),
              );

      return updated;
    }, 'markAllAsRead');
  }

  /// Delete old cached notifications (cleanup).
  Future<RepositoryResult<int>> deleteOldNotifications(
    String customerId, {
    int daysOld = 30,
  }) async {
    return errorHandler.runSafe(() async {
      final cutoff = DateTime.now().subtract(Duration(days: daysOld));

      final deleted =
          await (database.delete(database.customerNotifications)
                ..where((t) => t.customerId.equals(customerId))
                ..where((t) => t.createdAt.isSmallerThanValue(cutoff))
                ..where((t) => t.isRead.equals(true)))
              .go();

      return deleted;
    }, 'deleteOldNotifications');
  }
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Provider for the read-only cache repository. The legacy emit path
/// previously exposed here was removed in UNS task 14.5; callers that
/// need to emit MUST use `notificationsSdkProvider` from
/// `lib/core/notifications/uns_providers.dart` instead.
final customerNotificationsRepositoryProvider =
    Provider<CustomerNotificationsRepository>((ref) {
      return CustomerNotificationsRepository(
        database: AppDatabase.instance,
        errorHandler: sl<ErrorHandler>(),
      );
    });

/// Provider for cached notifications list.
final customerNotificationsProvider =
    StreamProvider.family<List<CustomerNotification>, String>((
      ref,
      customerId,
    ) {
      final repo = ref.watch(customerNotificationsRepositoryProvider);
      return repo.watchNotifications(customerId);
    });

/// Provider for cached unread count.
final customerUnreadNotificationsCountProvider =
    StreamProvider.family<int, String>((ref, customerId) {
      final repo = ref.watch(customerNotificationsRepositoryProvider);
      return repo.watchUnreadCount(customerId);
    });
