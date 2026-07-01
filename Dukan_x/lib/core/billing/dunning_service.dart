// ============================================================================
// DUNNING SERVICE - AUTOMATED PAYMENT REMINDERS
// ============================================================================

import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../repository/bills_repository.dart';
import '../repository/customers_repository.dart';
import '../../features/marketing/data/services/whatsapp_service.dart';

class DunningService {
  final AppDatabase _db;
  final BillsRepository _billsRepo;
  final WhatsAppService _whatsAppService;
  final Uuid _uuid = const Uuid();

  DunningService({
    required AppDatabase db,
    required BillsRepository billsRepo,
    required CustomersRepository customersRepo,
    required WhatsAppService whatsAppService,
  })  : _db = db,
        _billsRepo = billsRepo,
        _whatsAppService = whatsAppService;

  // ============================================
  // DUNNING RULE CRUD
  // ============================================

  /// Get all active dunning rules for a user, ordered by escalation sequence.
  Future<List<DunningRuleEntity>> getRules(String userId) async {
    return (await (_db.select(_db.dunningRules)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get());
  }

  /// Save (create or update) a dunning rule.
  Future<void> saveRule(DunningRulesCompanion rule) async {
    await _db.into(_db.dunningRules).insertOnConflictUpdate(rule);
  }

  /// Delete a dunning rule by ID.
  Future<void> deleteRule(String id) async {
    await (_db.delete(_db.dunningRules)..where((t) => t.id.equals(id))).go();
  }

  /// Seed default dunning rules for a new user.
  Future<void> seedDefaultRules(String userId) async {
    final now = DateTime.now();
    final defaults = [
      DunningRulesCompanion(
        id: Value(_uuid.v4()),
        userId: Value(userId),
        name: const Value('Gentle Reminder'),
        daysAfterDue: const Value(3),
        sortOrder: const Value(3),
        sendWhatsapp: const Value(true),
        sendNotification: const Value(true),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      DunningRulesCompanion(
        id: Value(_uuid.v4()),
        userId: Value(userId),
        name: const Value('Strong Reminder'),
        daysAfterDue: const Value(7),
        sortOrder: const Value(7),
        sendWhatsapp: const Value(true),
        sendNotification: const Value(true),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    ];
    for (final rule in defaults) {
      await saveRule(rule);
    }
  }

  // ============================================
  // DUNNING PROCESSING ENGINE
  // ============================================

  /// Process all overdue bills for a user and send appropriate reminders.
  /// Returns the number of reminders sent.
  Future<int> processOverdueBills(String userId) async {
    final rules = await getRules(userId);
    if (rules.isEmpty) return 0;

    // Get all unpaid/partial bills
    final allBillsResult = await _billsRepo.getAll(userId: userId);
    final allBills = allBillsResult.data ?? [];
    final overdueBills = allBills
        .where(
          (b) =>
              b.status != 'Paid' &&
              b.status != 'Draft' &&
              b.pendingAmount > 0.01,
        )
        .toList();

    if (overdueBills.isEmpty) return 0;

    int remindersSent = 0;
    final now = DateTime.now();

    for (final bill in overdueBills) {
      final daysOverdue = now.difference(bill.date).inDays;
      if (daysOverdue < 0) continue;

      for (final rule in rules) {
        if (daysOverdue >= rule.daysAfterDue) {
          final alreadySent = await _hasAlreadySent(bill.id, rule.id);
          if (alreadySent) continue;

          final success = await _sendReminder(bill, rule, daysOverdue);
          if (success) remindersSent++;

          if (rule.autoEscalate && rule.escalateToStatus != null) {
            await _billsRepo.updateBillStatus(
              billId: bill.id,
              status: rule.escalateToStatus!,
              paidAmount: bill.paidAmount,
            );
          }
        }
      }
    }

    return remindersSent;
  }

  /// Check if a specific dunning rule was already applied to a bill.
  Future<bool> _hasAlreadySent(String billId, String ruleId) async {
    final query = await (_db.select(_db.dunningLogs)
          ..where((t) => t.billId.equals(billId) & t.dunningRuleId.equals(ruleId))
          ..limit(1))
        .get();
    return query.isNotEmpty;
  }

  /// Send a reminder for a specific bill using the given rule.
  Future<bool> _sendReminder(
    Bill bill,
    DunningRuleEntity rule,
    int daysOverdue,
  ) async {
    String status = 'FAILED';

    try {
      final templateValues = {
        'customer_name': bill.customerName.isEmpty
            ? 'Customer'
            : bill.customerName,
        'shop_name': bill.shopName,
        'amount': bill.pendingAmount.toStringAsFixed(2),
        'invoice_number': bill.invoiceNumber,
        'due_date': '${bill.date.day}/${bill.date.month}/${bill.date.year}',
      };

      if (rule.sendWhatsapp && bill.customerPhone.isNotEmpty) {
        final template =
            rule.whatsappTemplate ??
            _whatsAppService.createPaymentReminder(
              customerName: templateValues['customer_name']!,
              shopName: templateValues['shop_name']!,
              amount: bill.pendingAmount,
              dueDate: bill.date,
            );

        final message = _whatsAppService.fillTemplate(
          template: template,
          values: templateValues,
        );

        final sent = await _whatsAppService.sendMessage(
          phoneNumber: bill.customerPhone,
          message: message,
        );
        status = sent ? 'SENT' : 'FAILED';
      } else if (rule.sendNotification) {
        status = 'SENT';
      } else {
        status = 'SKIPPED';
      }
    } catch (e) {
      status = 'FAILED';
    }

    // Log to dunningLogs table
    try {
      await _db.into(_db.dunningLogs).insert(
            DunningLogsCompanion.insert(
              id: _uuid.v4(),
              billId: bill.id,
              customerId: Value(bill.customerId),
              dunningRuleId: rule.id,
              channel: rule.sendWhatsapp ? 'WHATSAPP' : 'NOTIFICATION',
              status: status,
              createdAt: DateTime.now(),
              amountDue: bill.pendingAmount,
              daysOverdue: daysOverdue,
              billAmount: bill.grandTotal,
            ),
          );
    } catch (e) {
      developer.log('Failed to log dunning activity: $e', name: 'DunningService');
    }

    return status == 'SENT';
  }

  // ============================================
  // DUNNING LOG QUERIES
  // ============================================

  /// Get recent dunning activity logs.
  Future<List<DunningLogEntity>> getRecentLogs(
    String userId, {
    int limit = 50,
  }) async {
    return (await (_db.select(_db.dunningLogs)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .get());
  }

  /// Get dunning history for a specific bill.
  Future<List<DunningLogEntity>> getLogsForBill(String billId) async {
    return (await (_db.select(_db.dunningLogs)
          ..where((t) => t.billId.equals(billId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get());
  }
}
