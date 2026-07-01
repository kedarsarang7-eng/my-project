import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';

import '../../accounting/services/accounting_service.dart';
import 'commission_input.dart';
import 'lot_sale_entry.dart';
import 'payout_request.dart';

class BrokerBillingService {
  final AppDatabase _db;
  final ErrorHandler _errorHandler;
  final AccountingService _accountingService;

  BrokerBillingService(this._db, this._errorHandler, this._accountingService);

  // ==========================================
  // FARMER MANAGEMENT
  // ==========================================

  Future<RepositoryResult<String>> createFarmer(
    String userId,
    String name,
    String phone,
    String village,
  ) async {
    return await _errorHandler.runSafe<String>(() async {
      final id = const Uuid().v4();
      await _db
          .into(_db.farmers)
          .insert(
            FarmersCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              phone: Value(phone),
              village: Value(village),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      return id;
    }, 'createFarmer');
  }

  Stream<List<FarmerEntity>> watchFarmers(String userId) {
    return (_db.select(
      _db.farmers,
    )..where((t) => t.userId.equals(userId) & t.isActive.equals(true))).watch();
  }

  // ==========================================
  // COMMISSION LOGIC
  // ==========================================

  /// Records a sale where the broker acts as an intermediary.
  ///
  /// Commission is captured per lot/per farmer without merging or averaging.
  /// The captured value is persisted directly — no flat→%→flat round-trip.
  ///
  /// [billId]: The ID of the generic sales bill (Buyer Side).
  /// [farmerId]: The supplier who provided the goods.
  /// [saleAmount]: Total sale value collected from Buyer (integer paise).
  /// [commission]: The captured commission — either flat paise or percentage + result.
  /// [laborChargesPaise]: Labor charges in integer paise (0.00–9,999,999.99 range).
  /// [hamaliChargesPaise]: Hamali charges in integer paise (0.00–9,999,999.99 range).
  /// [weighingChargesPaise]: Weighing charges in integer paise (0.00–9,999,999.99 range).
  /// [marketFeePaise]: Market fee in integer paise (0.00–9,999,999.99 range).
  ///
  /// Returns an error string if validation fails; null on success.
  /// (Requirements 5.1, 5.2, 5.3, 5.5, 5.6, 6.1–6.5, 6.7)
  Future<String?> recordBrokerSale({
    required String userId,
    required String billId,
    required String farmerId,
    required int saleAmountPaise,
    required CommissionInput commission,
    int laborChargesPaise = 0,
    int hamaliChargesPaise = 0,
    int weighingChargesPaise = 0,
    int marketFeePaise = 0,
  }) async {
    // --- Validate commission (Requirement 5.6) ---
    final validationError = commission.validate();
    if (validationError != null) {
      return validationError;
    }

    // --- Validate deduction charges (Requirements 6.1, 6.2, 6.4) ---
    // Each charge must be >= 0 and <= 999999999 (9,999,999.99 in paise).
    const int maxChargePaise = 999999999;
    final chargeValidationError =
        _validateDeductionCharge(laborChargesPaise, 'labor', maxChargePaise) ??
        _validateDeductionCharge(
          hamaliChargesPaise,
          'hamali',
          maxChargePaise,
        ) ??
        _validateDeductionCharge(
          weighingChargesPaise,
          'weighing',
          maxChargePaise,
        ) ??
        _validateDeductionCharge(marketFeePaise, 'market fee', maxChargePaise);
    if (chargeValidationError != null) {
      return chargeValidationError;
    }

    // --- Compute net payable (Requirement 6.5) ---
    final commissionAmountPaise = commission.amountPaise;
    final totalDeductions =
        laborChargesPaise +
        hamaliChargesPaise +
        weighingChargesPaise +
        marketFeePaise;
    final netPayablePaise =
        saleAmountPaise - commissionAmountPaise - totalDeductions;

    // --- Reject when net payable < 0 (Requirement 6.7) ---
    if (netPayablePaise < 0) {
      return 'Combined commission and deduction charges exceed the sale amount';
    }

    // --- Safe farmer lookup (Requirements 9.1, 9.2, 9.5) ---
    final farmer = await (_db.select(
      _db.farmers,
    )..where((t) => t.id.equals(farmerId))).getSingleOrNull();

    if (farmer == null) {
      return 'Farmer not found: $farmerId';
    }

    final result = await _errorHandler.runSafe<void>(() async {
      final ledgerId = const Uuid().v4();
      final now = DateTime.now();
      final nowMillis = now.millisecondsSinceEpoch;

      // 1. Create Ledger Entry — persist the captured commission directly
      //    per lot/per farmer (Requirement 5.1, 5.5).
      //    Persist all deduction charges (Requirements 6.1, 6.2).
      final commissionRate = commission is PercentageCommission
          ? (commission as PercentageCommission).rate
          : null;

      await _db.customStatement(
        '''INSERT INTO commission_ledger
           (id, user_id, bill_id, farmer_id, date, sale_amount,
            commission_type, commission_rate, commission_amount,
            labor_charges, hamali_charges, weighing_charges, market_fee,
            other_expenses, net_payable_to_farmer,
            sync_state, last_modified_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unsynced', ?)''',
        [
          ledgerId,
          userId,
          billId,
          farmerId,
          nowMillis,
          saleAmountPaise,
          commission.typeString,
          commissionRate, // null for flat
          commissionAmountPaise,
          laborChargesPaise,
          hamaliChargesPaise,
          weighingChargesPaise,
          marketFeePaise,
          0, // otherExpenses — reserved for future use, always 0
          netPayablePaise,
          nowMillis,
        ],
      );

      // 2. Update Farmer Balance (all values in integer paise)
      final newSales = farmer.totalSales + saleAmountPaise;
      final newComm = farmer.totalCommissionDeducted + commissionAmountPaise;
      final newExp = farmer.totalExpensesDeducted + totalDeductions;
      final newBalance = farmer.currentBalance + netPayablePaise;

      await (_db.update(
        _db.farmers,
      )..where((t) => t.id.equals(farmerId))).write(
        FarmersCompanion(
          totalSales: Value(newSales),
          totalCommissionDeducted: Value(newComm),
          totalExpensesDeducted: Value(newExp),
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }, 'recordBrokerSale');

    if (result.isFailure) {
      return result.error ?? 'Failed to record broker sale';
    }
    return null; // Success
  }

  // ==========================================
  // MULTI-LOT BROKER SALE (Requirements 7.1–7.4)
  // ==========================================

  /// Records a multi-lot broker sale where each lot is attributed to its owning farmer.
  ///
  /// On bill save, writes one `CommissionLedger` entry per lot to the correct farmer.
  /// Validates:
  /// - Every lot has an owning farmer (Requirement 7.4)
  /// - Sum of per-lot sale amounts equals the total bill sale amount (Requirement 7.3)
  /// - Each lot's commission and charges are valid (Requirements 5.6, 6.4)
  ///
  /// [userId]: The broker (app user).
  /// [billId]: The ID of the generic sales bill (Buyer Side).
  /// [lots]: List of lot sale entries, each attributed to its owning farmer.
  /// [expectedTotalSaleAmountPaise]: The expected total sale amount for the bill.
  ///
  /// Returns an error string if validation fails; null on success.
  /// (Requirements 7.1, 7.2, 7.3, 7.4)
  Future<String?> recordMultiLotBrokerSale({
    required String userId,
    required String billId,
    required List<LotSaleEntry> lots,
    required int expectedTotalSaleAmountPaise,
  }) async {
    // --- Validate: every lot must have an owning farmer (Requirement 7.4) ---
    for (final lot in lots) {
      if (lot.owningFarmerId == null || lot.owningFarmerId!.isEmpty) {
        return 'Lot ${lot.lotId} has no owning farmer; cannot save bill';
      }
    }

    // --- Validate: sum of per-lot sale amounts must equal expected total (Requirement 7.3) ---
    int actualTotalSaleAmountPaise = 0;
    for (final lot in lots) {
      actualTotalSaleAmountPaise += lot.saleAmountPaise;
    }
    if (actualTotalSaleAmountPaise != expectedTotalSaleAmountPaise) {
      return 'Sum of per-lot sale amounts ($actualTotalSaleAmountPaise paise) '
          'does not equal expected total ($expectedTotalSaleAmountPaise paise)';
    }

    // --- Validate each lot's commission and charges ---
    const int maxChargePaise = 999999999;
    for (final lot in lots) {
      final commissionError = lot.commission.validate();
      if (commissionError != null) {
        return 'Lot ${lot.lotId}: $commissionError';
      }

      final chargeError =
          _validateDeductionCharge(
            lot.laborChargesPaise,
            'labor',
            maxChargePaise,
          ) ??
          _validateDeductionCharge(
            lot.hamaliChargesPaise,
            'hamali',
            maxChargePaise,
          ) ??
          _validateDeductionCharge(
            lot.weighingChargesPaise,
            'weighing',
            maxChargePaise,
          ) ??
          _validateDeductionCharge(
            lot.marketFeePaise,
            'market fee',
            maxChargePaise,
          );
      if (chargeError != null) {
        return 'Lot ${lot.lotId}: $chargeError';
      }

      // Compute net payable and reject if < 0 (Requirement 6.7)
      final commissionAmountPaise = lot.commission.amountPaise;
      final totalDeductions =
          lot.laborChargesPaise +
          lot.hamaliChargesPaise +
          lot.weighingChargesPaise +
          lot.marketFeePaise;
      final netPayablePaise =
          lot.saleAmountPaise - commissionAmountPaise - totalDeductions;
      if (netPayablePaise < 0) {
        return 'Lot ${lot.lotId}: combined commission and deduction charges exceed the sale amount';
      }
    }

    // --- Safe farmer lookup: verify all referenced farmers exist (Requirements 9.1, 9.2, 9.5) ---
    final uniqueFarmerIds = lots.map((l) => l.owningFarmerId!).toSet();
    for (final fId in uniqueFarmerIds) {
      final farmer = await (_db.select(
        _db.farmers,
      )..where((t) => t.id.equals(fId))).getSingleOrNull();
      if (farmer == null) {
        return 'Farmer not found: $fId';
      }
    }

    // --- All validation passed: write ledger entries in a single transaction ---
    final result = await _errorHandler.runSafe<void>(() async {
      await _db.transaction(() async {
        final now = DateTime.now();
        final nowMillis = now.millisecondsSinceEpoch;

        // Group lots by farmer to batch-update farmer balances
        final Map<String, _FarmerBalanceDelta> farmerDeltas = {};

        for (final lot in lots) {
          final farmerId = lot.owningFarmerId!;
          final commissionAmountPaise = lot.commission.amountPaise;
          final totalDeductions =
              lot.laborChargesPaise +
              lot.hamaliChargesPaise +
              lot.weighingChargesPaise +
              lot.marketFeePaise;
          final netPayablePaise =
              lot.saleAmountPaise - commissionAmountPaise - totalDeductions;

          final commissionRate = lot.commission is PercentageCommission
              ? (lot.commission as PercentageCommission).rate
              : null;

          // 1. Create one CommissionLedger entry per lot (Requirement 7.2)
          final ledgerId = const Uuid().v4();
          await _db.customStatement(
            '''INSERT INTO commission_ledger
               (id, user_id, bill_id, farmer_id, date, sale_amount,
                commission_type, commission_rate, commission_amount,
                labor_charges, hamali_charges, weighing_charges, market_fee,
                other_expenses, net_payable_to_farmer,
                sync_state, last_modified_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unsynced', ?)''',
            [
              ledgerId,
              userId,
              billId,
              farmerId,
              nowMillis,
              lot.saleAmountPaise,
              lot.commission.typeString,
              commissionRate, // null for flat
              commissionAmountPaise,
              lot.laborChargesPaise,
              lot.hamaliChargesPaise,
              lot.weighingChargesPaise,
              lot.marketFeePaise,
              0, // otherExpenses — reserved for future use
              netPayablePaise,
              nowMillis,
            ],
          );

          // 2. Accumulate balance deltas per farmer
          final delta = farmerDeltas.putIfAbsent(
            farmerId,
            () => _FarmerBalanceDelta(),
          );
          delta.totalSalesDelta += lot.saleAmountPaise;
          delta.totalCommissionDelta += commissionAmountPaise;
          delta.totalExpensesDelta += totalDeductions;
          delta.netPayableDelta += netPayablePaise;
        }

        // 3. Update each farmer's balance (Requirement 7.2)
        for (final entry in farmerDeltas.entries) {
          final farmerId = entry.key;
          final delta = entry.value;

          final farmer = await (_db.select(
            _db.farmers,
          )..where((t) => t.id.equals(farmerId))).getSingleOrNull();

          if (farmer == null) {
            throw StateError('Farmer not found: $farmerId');
          }

          final newSales = farmer.totalSales + delta.totalSalesDelta;
          final newComm =
              farmer.totalCommissionDeducted + delta.totalCommissionDelta;
          final newExp =
              farmer.totalExpensesDeducted + delta.totalExpensesDelta;
          final newBalance = farmer.currentBalance + delta.netPayableDelta;

          await (_db.update(
            _db.farmers,
          )..where((t) => t.id.equals(farmerId))).write(
            FarmersCompanion(
              totalSales: Value(newSales),
              totalCommissionDeducted: Value(newComm),
              totalExpensesDeducted: Value(newExp),
              currentBalance: Value(newBalance),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });
    }, 'recordMultiLotBrokerSale');

    if (result.isFailure) {
      return result.error ?? 'Failed to record multi-lot broker sale';
    }
    return null; // Success
  }

  /// Validates a single deduction charge field.
  /// Returns an error message if invalid, null if valid.
  /// (Requirement 6.4)
  String? _validateDeductionCharge(
    int valuePaise,
    String fieldName,
    int maxPaise,
  ) {
    if (valuePaise < 0) {
      return '$fieldName charge must not be negative (got $valuePaise paise)';
    }
    if (valuePaise > maxPaise) {
      return '$fieldName charge exceeds maximum allowed value of 9,999,999.99 (got $valuePaise paise)';
    }
    return null;
  }

  // ==========================================
  // PAYOUT LOGIC
  // ==========================================

  /// Pay the farmer using a [PayoutRequest].
  ///
  /// Validates payment mode, bank details (when mode is bank), and
  /// authorization before posting. Returns null on success, or an error
  /// string on failure.
  ///
  /// Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 9.3, 9.4, 9.5
  Future<String?> payoutFarmer(PayoutRequest request) async {
    // --- Validate the payout request (Requirements 10.1–10.6) ---
    final validationError = request.validate();
    if (validationError != null) {
      return validationError;
    }

    // --- Safe farmer lookup (Requirements 9.3, 9.4, 9.5) ---
    final farmer = await (_db.select(
      _db.farmers,
    )..where((t) => t.id.equals(request.farmerId))).getSingleOrNull();

    if (farmer == null) {
      return 'Farmer not found: ${request.farmerId}';
    }

    final result = await _errorHandler.runSafe<void>(() async {
      // Convert to integer paise for storage (round-half-away-from-zero).
      int toPaise(double rupees) {
        final raw = rupees * 100.0;
        return (rupees >= 0)
            ? (raw.abs() + 0.5).floor()
            : -(raw.abs() + 0.5).floor();
      }

      final amountPaise = toPaise(request.amount);
      final newPaid = farmer.totalPaid + amountPaise;
      final newBalance = farmer.currentBalance - amountPaise;

      await (_db.update(
        _db.farmers,
      )..where((t) => t.id.equals(request.farmerId))).write(
        FarmersCompanion(
          totalPaid: Value(newPaid),
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Log in Expenses/BankTransactions as a distinct Payout entry
      // (Requirement 10.7: post with selected mode and bank details)
      await _accountingService.createPaymentEntry(
        userId: farmer.userId,
        paymentId: const Uuid().v4(),
        vendorId: request.farmerId,
        vendorName: farmer.name,
        amount: request.amount,
        paymentMode: request.paymentModeString,
        paymentDate: DateTime.now(),
        bankAccountRef: request.paymentMode == PaymentMode.bank
            ? request.bankAccountRef
            : null,
        paymentRef: request.paymentMode == PaymentMode.bank
            ? request.paymentRef
            : null,
      );
    }, 'payoutFarmer');

    if (result.isFailure) {
      return result.error ?? 'Failed to process payout';
    }
    return null; // Success
  }
}

/// Internal helper: accumulates balance deltas for a farmer across multiple lots.
/// Used by [BrokerBillingService.recordMultiLotBrokerSale] to batch-update
/// farmer balances after all ledger entries are written.
class _FarmerBalanceDelta {
  int totalSalesDelta = 0;
  int totalCommissionDelta = 0;
  int totalExpensesDelta = 0;
  int netPayableDelta = 0;
}
