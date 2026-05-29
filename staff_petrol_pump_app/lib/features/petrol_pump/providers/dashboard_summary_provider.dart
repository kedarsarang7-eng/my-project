import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'license_provider.dart';

/// Dashboard summary data model
class DashboardSummary {
  final TodaySales todaySales;
  final FuelSoldLiters fuelSoldLiters;
  final TotalTransactions totalTransactions;
  final InventoryLevels inventory;
  final DateTime lastUpdated;

  const DashboardSummary({
    required this.todaySales,
    required this.fuelSoldLiters,
    required this.totalTransactions,
    required this.inventory,
    required this.lastUpdated,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return DashboardSummary(
      todaySales: TodaySales.fromJson(data['todaySales'] ?? {}),
      fuelSoldLiters: FuelSoldLiters.fromJson(data['fuelSoldLiters'] ?? {}),
      totalTransactions: TotalTransactions.fromJson(data['totalTransactions'] ?? {}),
      inventory: InventoryLevels.fromJson(data['inventory'] ?? {}),
      lastUpdated: DateTime.now(),
    );
  }
}

class TodaySales {
  final double total;
  final double changePercent;

  const TodaySales({required this.total, required this.changePercent});

  factory TodaySales.fromJson(Map<String, dynamic> json) {
    return TodaySales(
      total: (json['total'] ?? 0).toDouble(),
      changePercent: (json['changePercent'] ?? 0).toDouble(),
    );
  }

  String get formattedTotal {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(total);
  }

  bool get isPositive => changePercent >= 0;
}

class FuelSoldLiters {
  final int total;
  final int petrol;
  final int diesel;

  const FuelSoldLiters({required this.total, required this.petrol, required this.diesel});

  factory FuelSoldLiters.fromJson(Map<String, dynamic> json) {
    return FuelSoldLiters(
      total: (json['total'] ?? 0).toInt(),
      petrol: (json['petrol'] ?? 0).toInt(),
      diesel: (json['diesel'] ?? 0).toInt(),
    );
  }

  String get formattedTotal => '${NumberFormat('#,##0').format(total)} L';
  String get formattedPetrol => '${NumberFormat('#,##0').format(petrol)} L';
  String get formattedDiesel => '${NumberFormat('#,##0').format(diesel)} L';
}

class TotalTransactions {
  final int count;
  final double changePercent;

  const TotalTransactions({required this.count, required this.changePercent});

  factory TotalTransactions.fromJson(Map<String, dynamic> json) {
    return TotalTransactions(
      count: (json['count'] ?? 0).toInt(),
      changePercent: (json['changePercent'] ?? 0).toDouble(),
    );
  }

  String get formattedCount => NumberFormat('#,##0').format(count);
  bool get isPositive => changePercent >= 0;
}

class FuelInventory {
  final int percent;
  final int liters;

  const FuelInventory({required this.percent, required this.liters});

  factory FuelInventory.fromJson(Map<String, dynamic> json) {
    return FuelInventory(
      percent: (json['percent'] ?? 0).toInt(),
      liters: (json['liters'] ?? 0).toInt(),
    );
  }

  String get formattedLiters => '${NumberFormat('#,##0').format(liters)}L';

  // Color coding based on percentage
  String get statusColor {
    if (percent < 35) return 'red';
    if (percent < 50) return 'yellow';
    return 'green';
  }

  bool get isLow => percent < 35;
  bool get isWarning => percent >= 35 && percent < 50;
  bool get isNormal => percent >= 50;
}

class InventoryLevels {
  final FuelInventory petrol;
  final FuelInventory diesel;

  const InventoryLevels({required this.petrol, required this.diesel});

  factory InventoryLevels.fromJson(Map<String, dynamic> json) {
    return InventoryLevels(
      petrol: FuelInventory.fromJson(json['petrol'] ?? {}),
      diesel: FuelInventory.fromJson(json['diesel'] ?? {}),
    );
  }
}

/// Dashboard summary state
class DashboardSummaryState {
  final DashboardSummary? summary;
  final bool isLoading;
  final String? error;
  final DateTime? lastRefreshAttempt;

  const DashboardSummaryState({
    this.summary,
    this.isLoading = false,
    this.error,
    this.lastRefreshAttempt,
  });

  DashboardSummaryState copyWith({
    DashboardSummary? summary,
    bool? isLoading,
    String? error,
    DateTime? lastRefreshAttempt,
  }) {
    return DashboardSummaryState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastRefreshAttempt: lastRefreshAttempt ?? this.lastRefreshAttempt,
    );
  }
}

/// Dashboard summary notifier with auto-refresh
class DashboardSummaryNotifier extends StateNotifier<DashboardSummaryState> {
  final Ref _ref;
  Timer? _refreshTimer;

  DashboardSummaryNotifier(this._ref) : super(const DashboardSummaryState()) {
    // Start auto-refresh when initialized
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      refresh();
    });
  }

  Future<void> refresh() async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ApiClient();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await apiClient.get(
        '/dashboard/summary?stationId=${license.stationId}&date=$date',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final summary = DashboardSummary.fromJson(response.data);
        state = state.copyWith(
          summary: summary,
          isLoading: false,
          lastRefreshAttempt: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['error'] ?? 'Failed to load dashboard data',
          lastRefreshAttempt: DateTime.now(),
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
        lastRefreshAttempt: DateTime.now(),
      );
    }
  }

  void forceRefresh() {
    _refreshTimer?.cancel();
    refresh().then((_) => _startAutoRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Provider for dashboard summary
final dashboardSummaryProvider = StateNotifierProvider<DashboardSummaryNotifier, DashboardSummaryState>((ref) {
  return DashboardSummaryNotifier(ref);
});

/// Provider for today's sales (convenience)
final todaySalesProvider = Provider<TodaySales?>((ref) {
  return ref.watch(dashboardSummaryProvider).summary?.todaySales;
});

/// Provider for fuel sold (convenience)
final fuelSoldProvider = Provider<FuelSoldLiters?>((ref) {
  return ref.watch(dashboardSummaryProvider).summary?.fuelSoldLiters;
});

/// Provider for inventory levels (convenience)
final inventoryProvider = Provider<InventoryLevels?>((ref) {
  return ref.watch(dashboardSummaryProvider).summary?.inventory;
});

/// Provider for last updated timestamp
final lastUpdatedProvider = Provider<String?>((ref) {
  final lastUpdated = ref.watch(dashboardSummaryProvider).summary?.lastUpdated;
  if (lastUpdated == null) return null;

  final now = DateTime.now();
  final diff = now.difference(lastUpdated);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  } else {
    return DateFormat('HH:mm').format(lastUpdated);
  }
});
