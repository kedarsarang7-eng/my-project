import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'license_provider.dart';

/// Transaction data model
class Transaction {
  final String id;
  final String time;
  final String vehicleNumber;
  final String fuelType;
  final double liters;
  final double amount;
  final String status;
  final String badgeType;
  final String? pumpNumber;

  const Transaction({
    required this.id,
    required this.time,
    required this.vehicleNumber,
    required this.fuelType,
    required this.liters,
    required this.amount,
    required this.status,
    required this.badgeType,
    this.pumpNumber,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '#0000',
      time: json['time'] ?? '--:--',
      vehicleNumber: json['vehicleNumber'] ?? '-',
      fuelType: json['fuelType'] ?? '-',
      liters: (json['liters'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'Unknown',
      badgeType: json['badgeType'] ?? 'neutral',
      pumpNumber: json['pumpNumber'],
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String get formattedLiters => '${liters.toStringAsFixed(1)}L';
}

/// Transactions response
class TransactionsData {
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
  final List<Transaction> transactions;

  const TransactionsData({
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.transactions,
  });

  factory TransactionsData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return TransactionsData(
      total: (data['total'] ?? 0).toInt(),
      page: (data['page'] ?? 1).toInt(),
      limit: (data['limit'] ?? 10).toInt(),
      hasMore: data['hasMore'] ?? false,
      transactions: (data['data'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Transactions state
class TransactionsState {
  final List<Transaction> transactions;
  final int currentPage;
  final int totalCount;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final DateTime? selectedDate;

  const TransactionsState({
    this.transactions = const [],
    this.currentPage = 1,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedDate,
  });

  TransactionsState copyWith({
    List<Transaction>? transactions,
    int? currentPage,
    int? totalCount,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    DateTime? selectedDate,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Transactions notifier
class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super(const TransactionsState());

  Future<void> loadTransactions({DateTime? date, bool refresh = false}) async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    final targetDate = date ?? state.selectedDate ?? DateTime.now();
    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedDate: targetDate,
      currentPage: page,
    );

    try {
      final apiClient = ApiClient();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final response = await apiClient.get(
        '/transactions?stationId=${license.stationId}&date=$dateStr&page=$page&limit=10',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = TransactionsData.fromJson(response.data);

        final newTransactions = refresh || page == 1
            ? data.transactions
            : [...state.transactions, ...data.transactions];

        state = state.copyWith(
          transactions: newTransactions,
          currentPage: data.page,
          totalCount: data.total,
          hasMore: data.hasMore,
          isLoading: false,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: response.data['error'] ?? 'Failed to load transactions',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Network error: $e',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final license = _ref.read(licenseProvider).profile;
    if (license == null) return;

    try {
      final apiClient = ApiClient();
      final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate!);
      final nextPage = state.currentPage + 1;

      final response = await apiClient.get(
        '/transactions?stationId=${license.stationId}&date=$dateStr&page=$nextPage&limit=10',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = TransactionsData.fromJson(response.data);

        state = state.copyWith(
          transactions: [...state.transactions, ...data.transactions],
          currentPage: data.page,
          hasMore: data.hasMore,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          error: response.data['error'] ?? 'Failed to load more transactions',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Network error: $e',
      );
    }
  }

  void setDate(DateTime date) {
    if (date != state.selectedDate) {
      loadTransactions(date: date, refresh: true);
    }
  }

  void refresh() {
    loadTransactions(refresh: true);
  }

  void clear() {
    state = const TransactionsState();
  }
}

/// Provider for transactions
final transactionsProvider = StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  return TransactionsNotifier(ref);
});

/// Provider for current transactions list (convenience)
final currentTransactionsProvider = Provider<List<Transaction>>((ref) {
  return ref.watch(transactionsProvider).transactions;
});

/// Provider for selected date (convenience)
final selectedTransactionDateProvider = Provider<DateTime?>((ref) {
  return ref.watch(transactionsProvider).selectedDate;
});
