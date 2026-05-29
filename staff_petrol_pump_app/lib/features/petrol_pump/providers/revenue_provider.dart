import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import 'license_provider.dart';

/// Revenue segment data model
class RevenueSegment {
  final String label;
  final double value;
  final int percent;

  const RevenueSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  factory RevenueSegment.fromJson(Map<String, dynamic> json) {
    return RevenueSegment(
      label: json['label'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      percent: (json['percent'] ?? 0).toInt(),
    );
  }

  String get formattedValue {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  // Color for chart segments
  int get colorValue {
    return switch (label.toLowerCase()) {
      'petrol' => 0xFF4A90D9, // Blue
      'diesel' => 0xFFFFA726, // Orange
      'lubricants' => 0xFF66BB6A, // Green
      'shop items' => 0xFF78909C, // Gray
      _ => 0xFFBDBDBD,
    };
  }
}

/// Revenue breakdown data
class RevenueBreakdown {
  final double totalRevenue;
  final List<RevenueSegment> segments;

  const RevenueBreakdown({
    required this.totalRevenue,
    required this.segments,
  });

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return RevenueBreakdown(
      totalRevenue: (data['totalRevenue'] ?? 0).toDouble(),
      segments: (data['segments'] as List<dynamic>? ?? [])
          .map((e) => RevenueSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get formattedTotal {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(totalRevenue);
  }

  // Get segment by label
  RevenueSegment? getSegment(String label) {
    try {
      return segments.firstWhere((s) => s.label.toLowerCase() == label.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}

/// Revenue state
class RevenueState {
  final RevenueBreakdown? breakdown;
  final bool isLoading;
  final String? error;

  const RevenueState({
    this.breakdown,
    this.isLoading = false,
    this.error,
  });

  RevenueState copyWith({
    RevenueBreakdown? breakdown,
    bool? isLoading,
    String? error,
  }) {
    return RevenueState(
      breakdown: breakdown ?? this.breakdown,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Revenue notifier
class RevenueNotifier extends StateNotifier<RevenueState> {
  final Ref _ref;

  RevenueNotifier(this._ref) : super(const RevenueState());

  Future<void> loadRevenueData({DateTime? date}) async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ApiClient();
      final dateStr = DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());

      final response = await apiClient.get(
        '/dashboard/revenue-breakdown?stationId=${license.stationId}&date=$dateStr',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = RevenueBreakdown.fromJson(response.data);
        state = state.copyWith(
          breakdown: data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['error'] ?? 'Failed to load revenue data',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
    }
  }

  void refresh() {
    loadRevenueData();
  }
}

/// Provider for revenue breakdown
final revenueProvider = StateNotifierProvider<RevenueNotifier, RevenueState>((ref) {
  return RevenueNotifier(ref);
});

/// Provider for revenue segments (convenience)
final revenueSegmentsProvider = Provider<List<RevenueSegment>>((ref) {
  return ref.watch(revenueProvider).breakdown?.segments ?? [];
});

/// Provider for total revenue (convenience)
final totalRevenueProvider = Provider<String>((ref) {
  return ref.watch(revenueProvider).breakdown?.formattedTotal ?? '₹0';
});
