// Gold Scheme Repository - Full CRUD with Offline Support
// Feature 4: Gold Scheme/Chit Management
//
// Offline-first parity: VERIFIED (Phase 5, Task 10.2)
// Hive boxes: gold_schemes, scheme_templates, scheme_sync_queue
// Pattern: initialize() → Hive boxes, _addToSyncQueue(), _syncScheme(), syncAll()
// Matches jewellery_repository_offline.dart offline-first architecture.

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../models/jewellery_product_model.dart';
import '../models/gold_scheme_model.dart';

/// Repository for managing gold saving schemes (chit funds)
class GoldSchemeRepository {
  final ApiClient _client;
  final SessionManager _session;

  late Box<GoldScheme> _schemesBox;
  late Box<SchemeTemplate> _templatesBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;

  GoldSchemeRepository(this._client, this._session);

  Future<void> initialize() async {
    if (_initialized) return;

    _schemesBox = await Hive.openBox<GoldScheme>('gold_schemes');
    _templatesBox = await Hive.openBox<SchemeTemplate>('scheme_templates');
    _syncQueueBox = await Hive.openBox<Map>('scheme_sync_queue');

    // Load presets if empty
    if (_templatesBox.isEmpty) {
      await _loadPresetTemplates();
    }

    _initialized = true;
  }

  /// Load preset scheme templates
  Future<void> _loadPresetTemplates() async {
    final presets = [
      SchemeTemplates.standardMonthly11Plus1(),
      SchemeTemplates.goldAccumulation(),
      SchemeTemplates.flexibleDaily(),
    ];

    for (final template in presets) {
      await _templatesBox.put(template.id, template);
    }
  }

  // ============================================================================
  // TEMPLATE OPERATIONS
  // ============================================================================

  /// Get all scheme templates
  Future<List<SchemeTemplate>> getTemplates({
    bool includeInactive = false,
  }) async {
    await initialize();

    var templates = _templatesBox.values.where((t) {
      if (!includeInactive && !t.isActive) return false;
      return true;
    }).toList();

    templates.sort((a, b) => a.name.compareTo(b.name));
    return templates;
  }

  /// Get template by ID
  Future<SchemeTemplate?> getTemplateById(String id) async {
    await initialize();
    return _templatesBox.get(id);
  }

  /// Create custom template
  Future<SchemeTemplate> createTemplate(SchemeTemplate template) async {
    await initialize();

    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    final newTemplate = template.copyWith(id: id);

    await _templatesBox.put(id, newTemplate);

    // Sync to backend
    try {
      await _client.post(
        '/jewellery/scheme-templates',
        body: newTemplate.toJson(),
      );
    } catch (e) {
      // Template stays local
    }

    return newTemplate;
  }

  // ============================================================================
  // SCHEME CRUD OPERATIONS
  // ============================================================================

  /// Create new gold scheme
  Future<GoldScheme> createScheme(CreateGoldSchemeRequest request) async {
    await initialize();

    final now = DateTime.now();
    final tenantId = _session.ownerId ?? 'default';
    final userId = _session.userId ?? 'unknown';
    final id = RidGenerator.next(tenantId);

    // Generate scheme number
    final year = now.year;
    final count = _schemesBox.values.length + 1;
    final schemeNumber = 'GS-$year-${count.toString().padLeft(4, '0')}';

    // Generate payments schedule
    final payments = _generatePaymentSchedule(
      startDate: request.startDate ?? now,
      installmentAmount: request.installmentAmountPaisa,
      totalInstallments: request.totalInstallments,
      frequency: request.frequency,
    );

    // Calculate promised redemption date
    final promisedDate = payments.last.dueDate;

    final scheme = GoldScheme(
      id: id,
      tenantId: tenantId,
      schemeNumber: schemeNumber,
      customerId: request.customerId,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      customerEmail: request.customerEmail,
      customerAddress: request.customerAddress,
      schemeName:
          request.schemeName ??
          '${request.totalInstallments}-Month Gold Scheme',
      schemeDescription: request.templateId != null
          ? (await getTemplateById(request.templateId!))?.description
          : null,
      installmentAmountPaisa: request.installmentAmountPaisa,
      totalInstallments: request.totalInstallments,
      frequency: request.frequency,
      vendorBonusPaisa: request.vendorBonusPaisa,
      bonusPercentage: request.bonusPercentage,
      bonusDescription: request.bonusDescription,
      minimumInstallmentsForRedemption:
          request.minimumInstallmentsForRedemption ??
          (request.totalInstallments * 0.8).round(),
      isGoldLinked: request.isGoldLinked,
      linkedMetalType: request.linkedMetalType,
      status: SchemeStatus.active,
      startDate: request.startDate ?? now,
      promisedRedemptionDate: promisedDate,
      payments: payments,
      plannedRedemptionType: request.plannedRedemptionType,
      referredByCustomerId: request.referredByCustomerId,
      referralCode: request.referralCode,
      createdAt: now,
      createdBy: userId,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _schemesBox.put(id, scheme);
    await _addToSyncQueue('create', id);

    _syncScheme(scheme);

    return scheme;
  }

  /// Generate payment schedule
  List<SchemePayment> _generatePaymentSchedule({
    required DateTime startDate,
    required int installmentAmount,
    required int totalInstallments,
    required PaymentFrequency frequency,
  }) {
    final payments = <SchemePayment>[];

    for (int i = 1; i <= totalInstallments; i++) {
      final dueDate = startDate.add(
        Duration(days: (i - 1) * frequency.daysInterval),
      );

      payments.add(
        SchemePayment(
          id: RidGenerator.next(_session.ownerId ?? 'default'),
          installmentNumber: i,
          amountPaisa: installmentAmount,
          dueDate: dueDate,
          isPaid: false,
          isLate: false,
        ),
      );
    }

    return payments;
  }

  /// Get all schemes
  Future<List<GoldScheme>> getSchemes({
    SchemeStatus? status,
    String? customerId,
    bool? isOverdue,
    bool includeCompleted = true,
  }) async {
    await initialize();

    final tenantId = _session.ownerId;

    var schemes = _schemesBox.values.where((s) {
      if (s.tenantId != tenantId) return false;

      if (status != null && s.status != status) return false;
      if (customerId != null && s.customerId != customerId) return false;
      if (!includeCompleted &&
          (s.status == SchemeStatus.redeemed ||
              s.status == SchemeStatus.cancelled)) {
        return false;
      }

      if (isOverdue != null) {
        if (isOverdue && !s.hasOverduePayments) return false;
        if (!isOverdue && s.hasOverduePayments) return false;
      }

      return true;
    }).toList();

    // Sort: Active first, then by start date
    schemes.sort((a, b) {
      if (a.status == SchemeStatus.active && b.status != SchemeStatus.active) {
        return -1;
      }
      if (a.status != SchemeStatus.active && b.status == SchemeStatus.active) {
        return 1;
      }
      return b.startDate.compareTo(a.startDate);
    });

    return schemes;
  }

  /// Get schemes by customer
  Future<List<GoldScheme>> getCustomerSchemes(String customerId) async {
    return getSchemes(customerId: customerId);
  }

  /// Get active schemes
  Future<List<GoldScheme>> getActiveSchemes() async {
    return getSchemes(status: SchemeStatus.active);
  }

  /// Get overdue schemes
  Future<List<GoldScheme>> getOverdueSchemes() async {
    return getSchemes(isOverdue: true);
  }

  /// Get single scheme by ID
  Future<GoldScheme?> getSchemeById(String id) async {
    await initialize();
    return _schemesBox.get(id);
  }

  /// Get scheme by scheme number
  Future<GoldScheme?> getSchemeByNumber(String schemeNumber) async {
    await initialize();

    try {
      return _schemesBox.values.firstWhere(
        (s) => s.schemeNumber == schemeNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update scheme
  Future<GoldScheme> updateScheme(
    String id, {
    SchemeStatus? status,
    RedemptionType? plannedRedemptionType,
    String? notes,
  }) async {
    await initialize();

    final existing = _schemesBox.get(id);
    if (existing == null) {
      throw Exception('Scheme not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    final updated = existing.copyWith(
      status: status ?? existing.status,
      plannedRedemptionType:
          plannedRedemptionType ?? existing.plannedRedemptionType,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _schemesBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncScheme(updated);

    return updated;
  }

  // ============================================================================
  // PAYMENT OPERATIONS
  // ============================================================================

  /// Record a payment
  Future<GoldScheme> recordPayment(
    String schemeId,
    int installmentNumber, {
    required int paidAmountPaisa,
    String? paymentMode,
    String? transactionId,
    String? notes,
  }) async {
    await initialize();

    final scheme = _schemesBox.get(schemeId);
    if (scheme == null) {
      throw Exception('Scheme not found: $schemeId');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    // Find the payment
    final paymentIndex = scheme.payments.indexWhere(
      (p) => p.installmentNumber == installmentNumber,
    );

    if (paymentIndex == -1) {
      throw Exception('Installment $installmentNumber not found');
    }

    final payment = scheme.payments[paymentIndex];

    // Check if late
    final isLate = now.isAfter(payment.dueDate);
    int? lateFeePaisa;

    if (isLate) {
      // Calculate late fee (e.g., 1% of installment amount per week late)
      final daysLate = now.difference(payment.dueDate).inDays;
      final weeksLate = (daysLate / 7).ceil();
      lateFeePaisa = (payment.amountPaisa * 0.01 * weeksLate).round();
    }

    // Update payment
    final updatedPayment = payment.copyWith(
      isPaid: true,
      paidDate: now,
      paidAmountPaisa: paidAmountPaisa,
      isLate: isLate,
      lateFeePaisa: lateFeePaisa,
      paymentMode: paymentMode,
      transactionId: transactionId,
      notes: notes,
      receivedBy: userId,
    );

    // Update payments list
    final updatedPayments = [...scheme.payments];
    updatedPayments[paymentIndex] = updatedPayment;

    // Recalculate totals
    final completedInstallments = updatedPayments.where((p) => p.isPaid).length;
    final missedInstallments = updatedPayments
        .where((p) => !p.isPaid && p.dueDate.isBefore(now))
        .length;
    final lateInstallments = updatedPayments
        .where((p) => p.isPaid && p.isLate)
        .length;

    final totalPaid = updatedPayments.fold(
      0,
      (sum, p) => sum + (p.paidAmountPaisa ?? 0),
    );
    final totalLateFees = updatedPayments.fold(
      0,
      (sum, p) => sum + (p.lateFeePaisa ?? 0),
    );

    // Check if all payments completed
    SchemeStatus? newStatus;
    DateTime? endDate;
    if (completedInstallments == scheme.totalInstallments) {
      newStatus = SchemeStatus.completed;
      endDate = now;
    }

    // For gold-linked schemes, calculate gold weight
    List<GoldWeightRecord>? goldWeightHistory;
    int? accumulatedGoldWeight;

    if (scheme.isGoldLinked && scheme.linkedMetalType != null) {
      // Get current gold rate
      final goldRate = await _getCurrentGoldRate(scheme.linkedMetalType!);

      final goldWeight = paidAmountPaisa / goldRate;

      final record = GoldWeightRecord(
        date: now,
        goldRatePerGramPaisa: goldRate.toDouble(),
        goldWeightGrams: goldWeight,
        amountPaisa: paidAmountPaisa,
        notes: 'Installment $installmentNumber',
      );

      goldWeightHistory = [...?scheme.goldWeightHistory, record];

      // Recalculate total gold weight
      accumulatedGoldWeight = goldWeightHistory
          .fold(0.0, (sum, r) => sum + r.goldWeightGrams)
          .round();
    }

    final updated = scheme.copyWith(
      payments: updatedPayments,
      status: newStatus ?? scheme.status,
      completedInstallments: completedInstallments,
      missedInstallments: missedInstallments,
      lateInstallments: lateInstallments,
      totalPaidPaisa: totalPaid,
      totalLateFeesPaisa: totalLateFees,
      endDate: endDate ?? scheme.endDate,
      goldWeightHistory: goldWeightHistory ?? scheme.goldWeightHistory,
      accumulatedGoldWeightGrams:
          accumulatedGoldWeight ?? scheme.accumulatedGoldWeightGrams,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _schemesBox.put(schemeId, updated);
    await _addToSyncQueue('update', schemeId);

    _syncScheme(updated);

    return updated;
  }

  /// Get current gold rate
  Future<int> _getCurrentGoldRate(MetalType metalType) async {
    // Try to get from API
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _client.get('/jewellery/gold-rate?date=$today');

      if (response.data != null && response.data!['data'] != null) {
        final data = response.data!['data'] as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;

        switch (metalType) {
          case MetalType.gold24k:
            return ((rates['gold24KPer10gPaisa'] as int) / 10).round();
          case MetalType.gold22k:
            return ((rates['gold22KPer10gPaisa'] as int) / 10).round();
          case MetalType.gold18k:
            return ((rates['gold18KPer10gPaisa'] as int) / 10).round();
          default:
            return 600000; // Default ₹6000/g
        }
      }
    } catch (e) {
      // Use default rate
    }

    return 600000; // Default ₹6000/g
  }

  /// Record missed payment (for tracking)
  Future<GoldScheme> markPaymentMissed(
    String schemeId,
    int installmentNumber,
  ) async {
    // This is mainly for analytics - payment is automatically considered missed if not paid by due date
    return getSchemeById(schemeId).then((s) => s!);
  }

  /// Send payment reminder
  Future<void> sendPaymentReminder(
    String schemeId,
    int installmentNumber,
  ) async {
    // Implementation would integrate with notification service
    final scheme = await getSchemeById(schemeId);
    if (scheme == null) return;

    final payment = scheme.payments.firstWhere(
      (p) => p.installmentNumber == installmentNumber,
    );

    if (payment.isPaid) return;

    // Record reminder sent
    final updatedReminderDates = [
      ...?payment.reminderSentDates,
      DateTime.now().toIso8601String(),
    ];

    // Update payment with reminder record
    // This would require updating the scheme
  }

  // ============================================================================
  // REDEMPTION OPERATIONS
  // ============================================================================

  /// Redeem scheme
  Future<GoldScheme> redeemScheme(RedeemSchemeRequest request) async {
    await initialize();

    final scheme = _schemesBox.get(request.schemeId);
    if (scheme == null) {
      throw Exception('Scheme not found: ${request.schemeId}');
    }

    if (!scheme.canRedeem) {
      throw Exception(
        'Scheme is not eligible for redemption yet. Complete ${scheme.minimumInstallmentsForRedemption} installments.',
      );
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';
    final tenantId = _session.ownerId ?? 'default';

    // Calculate final amounts
    int bonusAmount = scheme.vendorBonusPaisa ?? 0;
    if (scheme.bonusPercentage != null) {
      bonusAmount = (scheme.totalPaidPaisa * (scheme.bonusPercentage! / 100))
          .round();
    }

    int finalAmount =
        request.finalAmountPaisa ??
        (scheme.totalSchemeValuePaisa + bonusAmount);

    // Create redemption record
    final redemption = SchemeRedemption(
      id: RidGenerator.next(tenantId),
      type: request.redemptionType,
      redemptionDate: now,
      totalAmountPaisa: scheme.totalSchemeValuePaisa,
      bonusAmountPaisa: bonusAmount > 0 ? bonusAmount : null,
      finalAmountPaisa: finalAmount,
      goldWeightGrams: request.goldWeightGrams,
      goldRateAtRedemptionPaisa: request.goldRatePaisa,
      purity: request.purity,
      productId: request.productId,
      productName: request.productName,
      bankAccountNumber: request.bankAccountNumber,
      bankIfsc: request.bankIfsc,
      upiId: request.upiId,
      notes: request.notes,
      processedBy: userId,
    );

    final updated = scheme.copyWith(
      status: SchemeStatus.redeemed,
      redemption: redemption,
      endDate: now,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _schemesBox.put(request.schemeId, updated);
    await _addToSyncQueue('update', request.schemeId);

    _syncScheme(updated);

    return updated;
  }

  // ============================================================================
  // FORECLOSURE & CANCELLATION
  // ============================================================================

  /// Foreclose scheme (early closure)
  Future<GoldScheme> forecloseScheme(
    String id, {
    required String reason,
    required int foreclosureChargePaisa,
  }) async {
    await initialize();

    final scheme = _schemesBox.get(id);
    if (scheme == null) {
      throw Exception('Scheme not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    // Calculate refund after charges
    final refundAmount = scheme.totalPaidPaisa - foreclosureChargePaisa;

    final updated = scheme.copyWith(
      status: SchemeStatus.cancelled,
      cancelledDate: now,
      cancellationReason: 'Foreclosure: $reason',
      cancellationChargesPaisa: foreclosureChargePaisa,
      refundAmountPaisa: refundAmount > 0 ? refundAmount : 0,
      endDate: now,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _schemesBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncScheme(updated);

    return updated;
  }

  /// Cancel scheme
  Future<GoldScheme> cancelScheme(
    String id, {
    required String reason,
    int? cancellationChargesPaisa,
  }) async {
    return forecloseScheme(
      id,
      reason: reason,
      foreclosureChargePaisa: cancellationChargesPaisa ?? 0,
    );
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  Future<GoldSchemeStatistics> getStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await initialize();

    final schemes = await getSchemes(includeCompleted: true);

    var totalSchemes = 0;
    var activeSchemes = 0;
    var completedSchemes = 0;
    var redeemedSchemes = 0;
    var defaultedSchemes = 0;
    var totalPaid = 0;
    var totalBonus = 0;
    var totalOutstanding = 0;
    var totalOverdue = 0;
    var schemesDueThisMonth = 0;
    var schemesOverdue = 0;
    final uniqueCustomers = <String>{};
    var totalDuration = 0.0;
    var completedCount = 0;

    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    for (final scheme in schemes) {
      totalSchemes++;
      uniqueCustomers.add(scheme.customerId);

      if (scheme.status == SchemeStatus.active) activeSchemes++;
      if (scheme.status == SchemeStatus.completed) completedSchemes++;
      if (scheme.status == SchemeStatus.redeemed) redeemedSchemes++;
      if (scheme.status == SchemeStatus.defaulted) defaultedSchemes++;

      totalPaid += scheme.totalPaidPaisa;
      if (scheme.vendorBonusPaisa != null) {
        totalBonus += scheme.vendorBonusPaisa!;
      }

      // Calculate outstanding
      final expectedPaid =
          scheme.completedInstallments * scheme.installmentAmountPaisa;
      if (scheme.totalPaidPaisa < expectedPaid) {
        totalOutstanding += (expectedPaid - scheme.totalPaidPaisa);
      }

      // Calculate overdue
      if (scheme.hasOverduePayments) {
        schemesOverdue++;
        for (final payment in scheme.payments) {
          if (!payment.isPaid && payment.dueDate.isBefore(now)) {
            totalOverdue += payment.amountPaisa;
          }
        }
      }

      // Check due this month
      if (scheme.status == SchemeStatus.active) {
        final hasPaymentDueThisMonth = scheme.payments.any((p) {
          if (p.isPaid) return false;
          return p.dueDate.month == now.month && p.dueDate.year == now.year;
        });
        if (hasPaymentDueThisMonth) schemesDueThisMonth++;
      }

      // Calculate duration
      if (scheme.endDate != null) {
        final duration = scheme.endDate!.difference(scheme.startDate).inDays;
        totalDuration += duration;
        completedCount++;
      }
    }

    return GoldSchemeStatistics(
      totalSchemes: totalSchemes,
      activeSchemes: activeSchemes,
      completedSchemes: completedSchemes,
      redeemedSchemes: redeemedSchemes,
      defaultedSchemes: defaultedSchemes,
      totalCustomers: uniqueCustomers.length,
      totalPaidPaisa: totalPaid,
      totalBonusPaisa: totalBonus,
      totalOutstandingPaisa: totalOutstanding,
      totalOverduePaisa: totalOverdue,
      averageSchemeDuration: completedCount > 0
          ? totalDuration / completedCount
          : 0,
      schemesDueThisMonth: schemesDueThisMonth,
      schemesOverdue: schemesOverdue,
    );
  }

  // ============================================================================
  // SYNC
  // ============================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 14.3).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same pattern:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue a corresponding sync-queue entry.
  ///   3. Fire-and-forget call to [_syncScheme] (non-blocking).
  Future<void> _addToSyncQueue(String operation, String entityId) async {
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': 'gold_scheme',
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  Future<void> _syncScheme(GoldScheme scheme) async {
    try {
      final data = {
        'id': scheme.id,
        'tenantId': scheme.tenantId,
        'schemeNumber': scheme.schemeNumber,
        'customerId': scheme.customerId,
        'customerName': scheme.customerName,
        'customerPhone': scheme.customerPhone,
        'schemeName': scheme.schemeName,
        'installmentAmountPaisa': scheme.installmentAmountPaisa,
        'totalInstallments': scheme.totalInstallments,
        'frequency': scheme.frequency.name,
        'vendorBonusPaisa': scheme.vendorBonusPaisa,
        'status': scheme.status.name,
        'startDate': scheme.startDate.toIso8601String(),
        'payments': scheme.payments.map((p) => p.toJson()).toList(),
        'totalPaidPaisa': scheme.totalPaidPaisa,
        'completedInstallments': scheme.completedInstallments,
        'createdAt': scheme.createdAt.toIso8601String(),
        'updatedAt': scheme.updatedAt.toIso8601String(),
      };

      Map<String, dynamic>? responseData;

      if (scheme.pendingOperation == 'create') {
        final response = await _client.post(
          '/jewellery/gold-schemes',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      } else {
        final response = await _client.put(
          '/jewellery/gold-schemes/${scheme.id}',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      }

      // Version-based reconciliation (Requirement 14.4)
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );
      final reconciliation = VersionReconciliation.reconcile(
        localVersion: 0, // GoldScheme has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local scheme
        final serverData = reconciliation.serverData!;
        final reconciled = scheme.copyWith(
          status:
              _parseSchemeStatus(serverData['status'] as String?) ??
              scheme.status,
          totalPaidPaisa:
              serverData['totalPaidPaisa'] as int? ?? scheme.totalPaidPaisa,
          completedInstallments:
              serverData['completedInstallments'] as int? ??
              scheme.completedInstallments,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _schemesBox.put(scheme.id, reconciled);
      } else {
        final synced = scheme.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _schemesBox.put(scheme.id, synced);
      }
    } catch (e) {
      print('[GoldSchemeRepository] Sync failed: $e');
    }
  }

  /// Parse scheme status string to enum, returns null if unrecognized.
  SchemeStatus? _parseSchemeStatus(String? status) {
    if (status == null) return null;
    try {
      return SchemeStatus.values.firstWhere((s) => s.name == status);
    } catch (_) {
      return null;
    }
  }

  /// Sync all pending schemes
  Future<void> syncAll() async {
    await initialize();

    final pending = _schemesBox.values.where((s) => !s.synced).toList();

    for (final scheme in pending) {
      await _syncScheme(scheme);
    }
  }
}
