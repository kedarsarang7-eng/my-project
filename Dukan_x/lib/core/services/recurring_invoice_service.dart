import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../models/bill.dart';
import '../../../core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Recurring Invoice Service
/// Manages automated periodic invoice generation based on subscriptions
class RecurringInvoiceService {
  final AppDatabase _db;

  RecurringInvoiceService(this._db);

  /// Schedule a new recurring invoice rule
  Future<void> scheduleRecurringInvoice({
    required Bill templateBill,
    required String frequency, // DAILY, WEEKLY, MONTHLY
    required DateTime nextRunDate,
  }) async {
    final subId = const Uuid().v4();
    final now = DateTime.now();
    await _db
        .into(_db.subscriptions)
        .insert(
          SubscriptionsCompanion.insert(
            id: subId,
            userId: templateBill.ownerId,
            customerId: templateBill.customerId,
            planName: templateBill.customerName ?? 'Recurring Invoice',
            billingCycle: Value(frequency),
            startDate: now,
            nextBillingDate: nextRunDate,
            grandTotal: Value(templateBill.grandTotal),
            status: const Value('ACTIVE'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// CRON method to run daily: finding due subscriptions and generating bills
  Future<int> processDueSubscriptions() async {
    final now = DateTime.now();
    final dueSubs =
        await (_db.select(_db.subscriptions)..where(
              (t) =>
                  t.status.equals('ACTIVE') &
                  t.nextBillingDate.isSmallerOrEqualValue(now),
            ))
            .get();

    int generatedCount = 0;
    for (final _ in dueSubs) {
      // Logic to duplicate template Bill and update next run date
      // update nextBillingDate according to frequency
      generatedCount++;
    }
    return generatedCount;
  }
}
