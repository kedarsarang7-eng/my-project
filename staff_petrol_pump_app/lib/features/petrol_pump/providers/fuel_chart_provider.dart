import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'license_provider.dart';

/// Fuel chart data model
class FuelChartData {
  final List<String> hours;
  final List<double> petrol;
  final List<double> diesel;

  const FuelChartData({
    required this.hours,
    required this.petrol,
    required this.diesel,
  });

  factory FuelChartData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return FuelChartData(
      hours: List<String>.from(data['hours'] ?? []),
      petrol: (data['petrol'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      diesel: (data['diesel'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  /// Get max value for chart scaling
  double get maxValue {
    final allValues = [...petrol, ...diesel];
    if (allValues.isEmpty) return 600;
    final max = allValues.reduce((a, b) => a > b ? a : b);
    return ((max / 100).ceil() * 100).toDouble();
  }

  /// Get min value (always 0 for volume)
  double get minValue => 0;

  int get dataPointCount => hours.length;
}

/// Fuel chart state
class FuelChartState {
  final FuelChartData? data;
  final bool isLoading;
  final String? error;
  final DateTime? selectedDate;

  const FuelChartState({
    this.data,
    this.isLoading = false,
    this.error,
    this.selectedDate,
  });

  FuelChartState copyWith({
    FuelChartData? data,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
  }) {
    return FuelChartState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Fuel chart notifier
class FuelChartNotifier extends StateNotifier<FuelChartState> {
  final Ref _ref;

  FuelChartNotifier(this._ref) : super(const FuelChartState());

  Future<void> loadChartData({DateTime? date}) async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    final targetDate = date ?? state.selectedDate ?? DateTime.now();

    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedDate: targetDate,
    );

    try {
      final apiClient = ApiClient();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      final response = await apiClient.get(
        '/dashboard/fuel-chart?stationId=${license.stationId}&date=$dateStr',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = FuelChartData.fromJson(response.data);
        state = state.copyWith(
          data: data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['error'] ?? 'Failed to load chart data',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
    }
  }

  void setDate(DateTime date) {
    if (date != state.selectedDate) {
      loadChartData(date: date);
    }
  }

  void refresh() {
    loadChartData();
  }
}

/// Provider for fuel chart data
final fuelChartProvider = StateNotifierProvider<FuelChartNotifier, FuelChartState>((ref) {
  return FuelChartNotifier(ref);
});

/// Provider for chart hours (convenience)
final chartHoursProvider = Provider<List<String>>((ref) {
  return ref.watch(fuelChartProvider).data?.hours ?? [];
});

/// Provider for petrol data (convenience)
final petrolDataProvider = Provider<List<double>>((ref) {
  return ref.watch(fuelChartProvider).data?.petrol ?? [];
});

/// Provider for diesel data (convenience)
final dieselDataProvider = Provider<List<double>>((ref) {
  return ref.watch(fuelChartProvider).data?.diesel ?? [];
});

/// Provider for chart max value (convenience)
final chartMaxValueProvider = Provider<double>((ref) {
  return ref.watch(fuelChartProvider).data?.maxValue ?? 600;
});
