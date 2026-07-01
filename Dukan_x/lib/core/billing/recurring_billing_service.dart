// ============================================================================
// RECURRING BILLING SERVICE
// ============================================================================
// Processes due subscriptions and auto-generates invoices (Bills).
// Designed to run on app startup, periodic timer, or manual trigger.
//
// Architecture:
//   SubscriptionRepository (Drift) -> RecurringBillingService -> BillsRepository
// ============================================================================

import 'package:uuid/uuid.dart';
import '../repository/subscription_repository.dart';
import '../repository/bills_repository.dart';
import '../repository/customers_repository.dart';

class RecurringBillingService {
  final SubscriptionRepository _subscriptionRepo;
  final BillsRepository _billsRepo;
  final CustomersRepository _customersRepo;
  final Uuid _uuid = const Uuid();

  RecurringBillingService({
    required SubscriptionRepository subscriptionRepo,
    required BillsRepository billsRepo,
    required CustomersRepository customersRepo,
  }) : _subscriptionRepo = subscriptionRepo,
       _billsRepo = billsRepo,
       _customersRepo = customersRepo;

  /// Process all due subscriptions for a specific user/business up to the given date.
  /// Typically called by a background task, cron job, or upon user login.
  /// Returns the count of successfully processed subscriptions.
  Future<int> processDueSubscriptions(
    String userId, {
    DateTime? upToDate,
  }) async {
    final targetDate = upToDate ?? DateTime.now();
    final dueSubscriptions = await _subscriptionRepo.getDueSubscriptions(
      userId,
      targetDate,
    );

    int processedCount = 0;

    for (final subscription in dueSubscriptions) {
      final success = await _processSingleSubscription(
        subscription,
        targetDate,
      );
      if (success) {
        processedCount++;
      }
    }

    return processedCount;
  }

  Future<bool> _processSingleSubscription(
    Subscription subscription,
    DateTime processingDate,
  ) async {
    try {
      // 1. Fetch related customer for the latest details
      final customerResult = await _customersRepo.getById(
        subscription.customerId,
      );
      final customer = customerResult.data;
      if (customer == null) {
        // Customer might have been deleted — skip this subscription
        return false;
      }

      // 2. Generate Invoice Items from subscription line items
      final billItems = subscription.items.map((subItem) {
        return BillItem(
          productId: subItem.productId ?? '',
          productName: subItem.productName,
          qty: subItem.quantity,
          unit: subItem.unit ?? '',
          price: subItem.unitPrice,
          gstRate: subItem.taxRate,
          cgst: subItem.taxAmount / 2,
          sgst: subItem.taxAmount / 2,
          discount: subItem.discountAmount,
        );
      }).toList();

      // 3. Create Bill object
      final invoice = Bill(
        id: _uuid.v4(),
        invoiceNumber: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone ?? '',
        customerAddress: customer.address ?? '',
        date: processingDate,
        items: billItems,
        subtotal: subscription.subtotal,
        totalTax: subscription.taxAmount,
        grandTotal: subscription.grandTotal,
        status: 'Unpaid',
        paymentType: 'Pending',
        ownerId: subscription.userId,
        source: 'AUTO_SUBSCRIPTION',
      );

      // 4. Save the Bill using existing repository (handles ledger, stock, audit)
      if (subscription.autoGenerateInvoice) {
        await _billsRepo.createBill(invoice);
      }

      // 5. Calculate next billing date and advance
      final nextDate = _calculateNextCycle(
        subscription.nextBillingDate ?? DateTime.now(),
        subscription.billingCycle,
        subscription.customCycleDays,
      );

      await _subscriptionRepo.advanceBillingCycle(subscription.id, nextDate);

      return true;
    } catch (e) {
      // Log error — in production, increment failedAttempts for dunning
      print('Error processing subscription ${subscription.id}: $e');
      return false;
    }
  }

  /// Calculate the next billing date based on the current cycle type.
  DateTime _calculateNextCycle(
    DateTime currentDate,
    String cycle,
    int? customDays,
  ) {
    switch (cycle.toUpperCase()) {
      case 'DAILY':
        return currentDate.add(const Duration(days: 1));
      case 'WEEKLY':
        return currentDate.add(const Duration(days: 7));
      case 'MONTHLY':
        int nextMonth = currentDate.month == 12 ? 1 : currentDate.month + 1;
        int nextYear = currentDate.month == 12
            ? currentDate.year + 1
            : currentDate.year;
        int nextDay = currentDate.day;
        int daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (nextDay > daysInNextMonth) nextDay = daysInNextMonth;
        return DateTime(
          nextYear,
          nextMonth,
          nextDay,
          currentDate.hour,
          currentDate.minute,
        );
      case 'YEARLY':
        int nextYear = currentDate.year + 1;
        int nextDay = currentDate.day;
        if (currentDate.month == 2 && nextDay == 29) {
          bool isLeap =
              (nextYear % 4 == 0 && nextYear % 100 != 0) ||
              (nextYear % 400 == 0);
          if (!isLeap) nextDay = 28;
        }
        return DateTime(
          nextYear,
          currentDate.month,
          nextDay,
          currentDate.hour,
          currentDate.minute,
        );
      case 'CUSTOM':
        return currentDate.add(Duration(days: customDays ?? 30));
      default:
        return currentDate.add(const Duration(days: 30));
    }
  }
}
