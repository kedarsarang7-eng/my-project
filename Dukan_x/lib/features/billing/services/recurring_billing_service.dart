import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';

class RecurringBillingService {
  final AppDatabase _db;
  // potentially inject BillingRepository if available to reuse "Create Bill" logic

  RecurringBillingService(this._db);

  /// Check for due subscriptions and generate invoices
  /// specificUserId: Optional, to run for a specific user (e.g. on login)
  Future<int> checkAndGenerateInvoices({String? specificUserId}) async {
    final now = DateTime.now();

    // Query Active Subscriptions due for billing
    var query = _db.select(_db.subscriptions)
      ..where(
        (t) =>
            t.status.equals('ACTIVE') &
            t.nextBillingDate.isSmallerOrEqualValue(now),
      );

    if (specificUserId != null) {
      query = query..where((t) => t.userId.equals(specificUserId));
    }

    final dueSubscriptions = await query.get();
    int generatedCount = 0;

    for (final sub in dueSubscriptions) {
      await _generateBillForSubscription(sub);
      generatedCount++;
    }

    return generatedCount;
  }

  Future<void> _generateBillForSubscription(SubscriptionEntity sub) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      final billId = const Uuid().v4();

      // Calculate next billing date based on cycle
      DateTime nextDate;
      switch (sub.billingCycle) {
        case 'WEEKLY':
          nextDate = sub.nextBillingDate.add(const Duration(days: 7));
          break;
        case 'QUARTERLY':
          nextDate = DateTime(
            sub.nextBillingDate.year,
            sub.nextBillingDate.month + 3,
            sub.nextBillingDate.day,
          );
          break;
        case 'YEARLY':
          nextDate = DateTime(
            sub.nextBillingDate.year + 1,
            sub.nextBillingDate.month,
            sub.nextBillingDate.day,
          );
          break;
        case 'MONTHLY':
        default:
          nextDate = DateTime(
            sub.nextBillingDate.year,
            sub.nextBillingDate.month + 1,
            sub.nextBillingDate.day,
          );
          break;
      }

      // Update Subscription with next billing date
      await (_db.update(
        _db.subscriptions,
      )..where((t) => t.id.equals(sub.id))).write(
        SubscriptionsCompanion(
          nextBillingDate: Value(nextDate),
          lastBillingDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Look up customer name for the bill
      String? customerName;
      if (sub.customerId.isNotEmpty) {
        final customer = await (_db.select(_db.customers)
              ..where((c) => c.id.equals(sub.customerId)))
            .getSingleOrNull();
        customerName = customer?.name;
      }

      final invoiceNumber =
          'SUB-${now.millisecondsSinceEpoch}'; // Temporary generator

      // Build items JSON from subscription items
      final subItems = await (_db.select(_db.subscriptionItems)
            ..where((i) => i.subscriptionId.equals(sub.id)))
          .get();

      final itemsJsonStr = subItems.isNotEmpty
          ? subItems.map((i) => '{"productName":"${i.productName}","quantity":${i.quantity},"unitPrice":${i.unitPrice},"totalAmount":${i.totalAmount}}').join(',')
          : '[]';

      final bill = BillEntity(
        id: billId,
        userId: sub.userId,
        customerId: sub.customerId,
        customerName: customerName,
        billDate: now,
        invoiceNumber: invoiceNumber,
        status: 'DRAFT',
        itemsJson: '[$itemsJsonStr]',
        grandTotal: sub.grandTotal,
        source: 'SUBSCRIPTION',
        createdAt: now,
        updatedAt: now,
        businessType: 'service', // Default to service/generic
        subtotal: sub.subtotal,
        taxAmount: sub.taxAmount,
        paidAmount: 0.0,
        discountAmount: sub.discountAmount,
        version: 1,
        cashPaid: 0.0,
        onlinePaid: 0.0,
        serviceCharge: 0.0,
        costOfGoodsSold: 0.0,
        grossProfit: 0.0,
        printCount: 0,
        isSynced: false,
        marketCess: 0.0,
        commissionAmount: 0.0,
      );

      // Use BillingService if injected, else insert directly (drafts don't need stock deduction yet)
      // Since Recurring Invoice is usually Auto-Generated as DRAFT for review, we just insert.
      await _db.into(_db.bills).insert(bill);
    });
  }
}
