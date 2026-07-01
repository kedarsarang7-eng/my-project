// ============================================================================
// SUBSCRIPTION REPOSITORY
// ============================================================================
// Uses the current Subscriptions schema from tables.dart:
//   id, userId, customerId, planName, description, billingCycle,
//   customCycleDays, startDate, endDate, autoCancelDate, lastBillingDate,
//   nextBillingDate, subtotal, taxAmount, discountAmount, grandTotal,
//   autoGenerateInvoice, autoSendEmail, autoSendWhatsapp, status,
//   cancellationReason, failedAttempts, isSynced, syncOperationId,
//   createdAt, updatedAt, deletedAt, version
// ============================================================================

import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Placeholder subscription model
class Subscription {
  String id;
  String userId;
  String customerId;
  String planName;
  String? description;
  String billingCycle;
  int? customCycleDays;
  DateTime startDate;
  DateTime? endDate;
  DateTime? autoCancelDate;
  DateTime? lastBillingDate;
  DateTime? nextBillingDate;
  double subtotal;
  double taxAmount;
  double discountAmount;
  double grandTotal;
  bool autoGenerateInvoice;
  bool autoSendEmail;
  bool autoSendWhatsapp;
  String status;
  String? cancellationReason;
  int failedAttempts;
  bool isSynced;
  String? syncOperationId;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? deletedAt;
  int version;
  List<SubscriptionItem> items;

  Subscription({
    required this.id,
    required this.userId,
    required this.customerId,
    this.planName = '',
    this.description,
    this.billingCycle = 'MONTHLY',
    this.customCycleDays,
    required this.startDate,
    this.endDate,
    this.autoCancelDate,
    this.lastBillingDate,
    this.nextBillingDate,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.grandTotal = 0,
    this.autoGenerateInvoice = true,
    this.autoSendEmail = false,
    this.autoSendWhatsapp = false,
    this.status = 'ACTIVE',
    this.cancellationReason,
    this.failedAttempts = 0,
    this.isSynced = false,
    this.syncOperationId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.version = 1,
    this.items = const [],
  });
}

class SubscriptionItem {
  String id;
  String subscriptionId;
  String? productId;
  String productName;
  double quantity;
  String? unit;
  double unitPrice;
  double taxRate;
  double taxAmount;
  double discountAmount;
  double totalAmount;
  int sortOrder;
  DateTime createdAt;

  SubscriptionItem({
    required this.id,
    required this.subscriptionId,
    this.productId,
    this.productName = '',
    this.quantity = 1,
    this.unit,
    this.unitPrice = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.totalAmount = 0,
    this.sortOrder = 0,
    required this.createdAt,
  });
}

class SubscriptionRepository {
  final AppDatabase _db;

  SubscriptionRepository(this._db);

  /// Convert entity to model
  Subscription _entityToModel(SubscriptionEntity row) {
    return Subscription(
      id: row.id,
      userId: row.userId,
      customerId: row.customerId,
      planName: row.planName,
      description: row.description,
      billingCycle: row.billingCycle,
      customCycleDays: row.customCycleDays,
      startDate: row.startDate,
      endDate: row.endDate,
      autoCancelDate: row.autoCancelDate,
      lastBillingDate: row.lastBillingDate,
      nextBillingDate: row.nextBillingDate,
      subtotal: row.subtotal,
      taxAmount: row.taxAmount,
      discountAmount: row.discountAmount,
      grandTotal: row.grandTotal,
      autoGenerateInvoice: row.autoGenerateInvoice,
      autoSendEmail: row.autoSendEmail,
      autoSendWhatsapp: row.autoSendWhatsapp,
      status: row.status,
      cancellationReason: row.cancellationReason,
      failedAttempts: row.failedAttempts,
      isSynced: row.isSynced,
      syncOperationId: row.syncOperationId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      version: row.version,
    );
  }

  /// Get Subscription by ID
  Future<Subscription?> getById(String id) async {
    final row = await (_db.select(
      _db.subscriptions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    return _entityToModel(row);
  }

  /// Watch all active subscriptions for a user
  Stream<List<Subscription>> watchAllActive(String userId) {
    final query = _db.select(_db.subscriptions)
      ..where((t) => t.userId.equals(userId) & t.status.equals('ACTIVE'))
      ..orderBy([(t) => OrderingTerm.asc(t.nextBillingDate)]);

    return query.watch().map(
      (rows) => rows.map(_entityToModel).toList(),
    );
  }

  /// Get subscriptions due for billing
  Future<List<Subscription>> getDueSubscriptions(
    String userId,
    DateTime targetDate,
  ) async {
    final query = _db.select(_db.subscriptions)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.status.equals('ACTIVE') &
            t.nextBillingDate.isSmallerOrEqualValue(targetDate),
      );

    final rows = await query.get();
    return rows.map(_entityToModel).toList();
  }

  /// Save subscription
  Future<void> saveSubscription(Subscription subscription) async {
    await _db
        .into(_db.subscriptions)
        .insert(
          SubscriptionsCompanion(
            id: Value(subscription.id),
            userId: Value(subscription.userId),
            customerId: Value(subscription.customerId),
            planName: Value(subscription.planName),
            billingCycle: Value(subscription.billingCycle),
            startDate: Value(subscription.startDate),
            nextBillingDate: Value(
              subscription.nextBillingDate ?? DateTime.now(),
            ),
            endDate: Value(subscription.endDate),
            grandTotal: Value(subscription.grandTotal),
            subtotal: Value(subscription.subtotal),
            taxAmount: Value(subscription.taxAmount),
            discountAmount: Value(subscription.discountAmount),
            status: Value(subscription.status),
            autoSendEmail: Value(subscription.autoSendEmail),
            autoGenerateInvoice: Value(subscription.autoGenerateInvoice),
            autoSendWhatsapp: Value(subscription.autoSendWhatsapp),
            createdAt: Value(subscription.createdAt),
            updatedAt: Value(subscription.updatedAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Soft delete subscription
  Future<void> deleteSubscription(String id, String reason) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(
        status: const Value('CANCELLED'),
        cancellationReason: Value(reason),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Advance billing cycle
  Future<void> advanceBillingCycle(String id, DateTime nextBillingDate) async {
    await (_db.update(_db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(
        lastBillingDate: Value(DateTime.now()),
        nextBillingDate: Value(nextBillingDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
