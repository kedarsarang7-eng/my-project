import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/di/service_locator.dart';

/// Customer Profile State - Single source of truth for UI
class CustomerProfileState {
  final Customer? customer;
  final List<Bill> bills;
  final CustomerFinancialSnapshot financials;
  final CustomerInsights insights;
  final List<CustomerNote> notes;
  final Map<String, List<Bill>> timeGroupedBills;
  final bool isLoading;
  final String? error;

  const CustomerProfileState({
    this.customer,
    this.bills = const [],
    this.financials = const CustomerFinancialSnapshot(),
    this.insights = const CustomerInsights(),
    this.notes = const [],
    this.timeGroupedBills = const {},
    this.isLoading = false,
    this.error,
  });

  CustomerProfileState copyWith({
    Customer? customer,
    List<Bill>? bills,
    CustomerFinancialSnapshot? financials,
    CustomerInsights? insights,
    List<CustomerNote>? notes,
    Map<String, List<Bill>>? timeGroupedBills,
    bool? isLoading,
    String? error,
  }) {
    return CustomerProfileState(
      customer: customer ?? this.customer,
      bills: bills ?? this.bills,
      financials: financials ?? this.financials,
      insights: insights ?? this.insights,
      notes: notes ?? this.notes,
      timeGroupedBills: timeGroupedBills ?? this.timeGroupedBills,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  static const empty = CustomerProfileState();
}

/// Financial snapshot derived from actual transactions
class CustomerFinancialSnapshot {
  final double totalBilled;
  final double totalReceived;
  final double outstandingBalance;
  final bool hasOverdue;
  final int overdueCount;
  final int unpaidBillsCount;
  final DateTime? lastPaymentDate;
  final DateTime? lastInvoiceDate;
  final double lastInvoiceAmount;

  const CustomerFinancialSnapshot({
    this.totalBilled = 0,
    this.totalReceived = 0,
    this.outstandingBalance = 0,
    this.hasOverdue = false,
    this.overdueCount = 0,
    this.unpaidBillsCount = 0,
    this.lastPaymentDate,
    this.lastInvoiceDate,
    this.lastInvoiceAmount = 0,
  });
}

/// Customer insights derived from transaction patterns
class CustomerInsights {
  final double averagePaymentDelayDays;
  final double reliabilityScore; // 0-100
  final String spendingTrend; // "increasing" | "stable" | "decreasing"
  final double last30DaysSpend;
  final double last90DaysSpend;
  final int totalTransactions;
  final DateTime? firstTransactionDate;

  const CustomerInsights({
    this.averagePaymentDelayDays = 0,
    this.reliabilityScore = 100,
    this.spendingTrend = 'stable',
    this.last30DaysSpend = 0,
    this.last90DaysSpend = 0,
    this.totalTransactions = 0,
    this.firstTransactionDate,
  });
}

/// Customer note model
class CustomerNote {
  final String id;
  final String customerId;
  final String content;
  final DateTime createdAt;
  final String createdBy;

  const CustomerNote({
    required this.id,
    required this.customerId,
    required this.content,
    required this.createdAt,
    required this.createdBy,
  });
}

/// CustomerProfileController - Reactive state management for Customer Profile
///
/// This controller:
/// - Combines streams from CustomersRepository and BillsRepository
/// - Derives all financial metrics from actual transactions
/// - Provides time-aware transaction grouping
/// - Handles all data scoping via ownerId
class CustomerProfileController extends ChangeNotifier {
  final String customerId;
  final String ownerId;

  final CustomersRepository _customersRepo;
  final BillsRepository _billsRepo;

  CustomerProfileState _state = CustomerProfileState.empty;
  CustomerProfileState get state => _state;

  // UI Convenience Getters
  bool get isLoading => _state.isLoading;
  Customer? get customer => _state.customer;
  CustomerFinancialSnapshot get financialSnapshot => _state.financials;
  String? get error => _state.error;

  StreamSubscription<Customer?>? _customerSub;
  StreamSubscription<List<Bill>>? _billsSub;

  // In-memory notes (would be persisted to DB in full implementation)
  final List<CustomerNote> _notes = [];

  CustomerProfileController({
    required this.customerId,
    required this.ownerId,
    CustomersRepository? customersRepo,
    BillsRepository? billsRepo,
  }) : _customersRepo = customersRepo ?? sl<CustomersRepository>(),
       _billsRepo = billsRepo ?? sl<BillsRepository>() {
    _init();
  }

  void _init() {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    // Watch customer changes
    // Attempt to watch specific customer if repository supports it, otherwise watch all filtered
    _customerSub = _customersRepo
        .watchAll(userId: ownerId)
        .map((customers) {
          try {
            return customers.firstWhere((c) => c.id == customerId);
          } catch (_) {
            return null;
          }
        })
        .listen((customer) {
          if (customer != null) {
            _onCustomerUpdate(customer);
          } else {
            // Fallback: Try fetching by ID directly if stream yields nothing (e.g. initial load or filter mismatch)
            _customersRepo.getById(customerId).then((result) {
              if (result.isSuccess && result.data != null) {
                _onCustomerUpdate(result.data);
              }
            });
          }
        }, onError: _onError);

    // Watch bills for this customer
    _billsSub = _billsRepo
        .watchAll(userId: ownerId, customerId: customerId)
        .listen(_onBillsUpdate, onError: _onError);
  }

  void _onCustomerUpdate(Customer? customer) {
    _state = _state.copyWith(customer: customer, isLoading: false);
    notifyListeners();
  }

  void _onBillsUpdate(List<Bill> bills) {
    final financials = _calculateFinancials(bills);
    final insights = _deriveInsights(bills);
    final timeGrouped = _groupByTimePeriod(bills);

    _state = _state.copyWith(
      bills: bills,
      financials: financials,
      insights: insights,
      timeGroupedBills: timeGrouped,
      notes: _notes,
      isLoading: false,
    );
    notifyListeners();
  }

  void _onError(Object error) {
    debugPrint('[CustomerProfileController] Error: $error');
    _state = _state.copyWith(isLoading: false, error: error.toString());
    notifyListeners();
  }

  /// Calculate financial snapshot from actual bills
  CustomerFinancialSnapshot _calculateFinancials(List<Bill> bills) {
    if (bills.isEmpty) return const CustomerFinancialSnapshot();

    double totalBilled = 0;
    double totalReceived = 0;
    int unpaidCount = 0;
    int overdueCount = 0;
    DateTime? lastPaymentDate;
    DateTime? lastInvoiceDate;
    double lastInvoiceAmount = 0;

    final now = DateTime.now();
    final overdueThreshold = now.subtract(const Duration(days: 30));

    // Sort by date descending
    final sortedBills = List<Bill>.from(bills)
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final bill in sortedBills) {
      totalBilled += bill.grandTotal;
      totalReceived += bill.paidAmount;

      if (bill.status != 'Paid') {
        unpaidCount++;
        if (bill.date.isBefore(overdueThreshold)) {
          overdueCount++;
        }
      }

      // Track last payment (bill with paidAmount > 0)
      if (bill.paidAmount > 0 && lastPaymentDate == null) {
        lastPaymentDate = bill.date;
      }
    }

    // Last invoice
    if (sortedBills.isNotEmpty) {
      lastInvoiceDate = sortedBills.first.date;
      lastInvoiceAmount = sortedBills.first.grandTotal;
    }

    return CustomerFinancialSnapshot(
      totalBilled: totalBilled,
      totalReceived: totalReceived,
      outstandingBalance: (totalBilled - totalReceived).clamp(
        0,
        double.infinity,
      ),
      hasOverdue: overdueCount > 0,
      overdueCount: overdueCount,
      unpaidBillsCount: unpaidCount,
      lastPaymentDate: lastPaymentDate,
      lastInvoiceDate: lastInvoiceDate,
      lastInvoiceAmount: lastInvoiceAmount,
    );
  }

  /// Derive insights from transaction patterns
  CustomerInsights _deriveInsights(List<Bill> bills) {
    if (bills.isEmpty) return const CustomerInsights();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));

    double last30DaysSpend = 0;
    double last90DaysSpend = 0;
    int paidBillsCount = 0;
    double totalPaymentDelay = 0;

    DateTime? firstTransaction;

    for (final bill in bills) {
      // First transaction
      if (firstTransaction == null || bill.date.isBefore(firstTransaction)) {
        firstTransaction = bill.date;
      }

      // Spending trends
      if (bill.date.isAfter(thirtyDaysAgo)) {
        last30DaysSpend += bill.grandTotal;
      }
      if (bill.date.isAfter(ninetyDaysAgo)) {
        last90DaysSpend += bill.grandTotal;
      }

      // Payment delay calculation (simplified: assume paid bills were paid within 7 days average)
      if (bill.status == 'Paid' || bill.status == 'Partial') {
        paidBillsCount++;
        final paymentDate = bill.updatedAt ?? DateTime.now();
        final diff = paymentDate.difference(bill.date).inDays;
        totalPaymentDelay += diff > 0 ? diff : 0;
      }
    }

    // Calculate reliability score
    final paidRatio = bills.isEmpty ? 1.0 : paidBillsCount / bills.length;
    final reliabilityScore = (paidRatio * 100).clamp(0.0, 100.0);

    // Determine spending trend
    String spendingTrend = 'stable';
    final avgMonthlyLast90 = last90DaysSpend / 3;
    if (last30DaysSpend > avgMonthlyLast90 * 1.2) {
      spendingTrend = 'increasing';
    } else if (last30DaysSpend < avgMonthlyLast90 * 0.8) {
      spendingTrend = 'decreasing';
    }

    final double avgDelay = paidBillsCount > 0
        ? totalPaymentDelay / paidBillsCount
        : 0.0;

    return CustomerInsights(
      averagePaymentDelayDays: avgDelay,
      reliabilityScore: reliabilityScore,
      spendingTrend: spendingTrend,
      last30DaysSpend: last30DaysSpend,
      last90DaysSpend: last90DaysSpend,
      totalTransactions: bills.length,
      firstTransactionDate: firstTransaction,
    );
  }

  /// Group bills by time of day
  Map<String, List<Bill>> _groupByTimePeriod(List<Bill> bills) {
    final Map<String, List<Bill>> grouped = {
      'Morning': [],
      'Afternoon': [],
      'Evening': [],
      'Night': [],
    };

    for (final bill in bills) {
      final hour = bill.date.hour;
      String period;
      if (hour >= 5 && hour < 12) {
        period = 'Morning';
      } else if (hour >= 12 && hour < 17) {
        period = 'Afternoon';
      } else if (hour >= 17 && hour < 21) {
        period = 'Evening';
      } else {
        period = 'Night';
      }
      grouped[period]!.add(bill);
    }

    return grouped;
  }

  // ============================================
  // ACTIONS
  // ============================================

  /// Record a payment for this customer
  Future<bool> recordPayment({
    required double amount,
    String paymentMode = 'Cash',
  }) async {
    if (amount <= 0) return false;

    try {
      final result = await _customersRepo.recordPayment(
        customerId: customerId,
        amount: amount,
        userId: ownerId,
      );
      return result.isSuccess;
    } catch (e) {
      debugPrint('[CustomerProfileController] Payment error: $e');
      return false;
    }
  }

  /// Add a note for this customer
  void addNote(String content) {
    if (content.trim().isEmpty) return;

    final note = CustomerNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: customerId,
      content: content.trim(),
      createdAt: DateTime.now(),
      createdBy: ownerId,
    );

    _notes.add(note);
    _state = _state.copyWith(notes: List.from(_notes));
    notifyListeners();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    // Streams will automatically provide fresh data
    // This is a placeholder for manual refresh if needed
    await Future.delayed(const Duration(milliseconds: 500));

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  /// Alias for refresh to match UI calls
  Future<void> fetchData() => refresh();

  @override
  void dispose() {
    _customerSub?.cancel();
    _billsSub?.cancel();
    super.dispose();
  }
}
