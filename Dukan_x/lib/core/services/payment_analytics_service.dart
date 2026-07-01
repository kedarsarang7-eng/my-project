// ============================================================================
// PAYMENT ANALYTICS SERVICE — Real Data from Backend
// ============================================================================

import 'dart:developer' as developer;
import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/session/session_manager.dart';

class PaymentAnalyticsService {
  static final PaymentAnalyticsService _instance = PaymentAnalyticsService._internal();

  PaymentAnalyticsService._internal();
  factory PaymentAnalyticsService() => _instance;

  ApiClient get _apiClient => sl<ApiClient>();
  SessionManager get _session => sl<SessionManager>();

  /// Fetch payment analytics for date range
  Future<Map<String, dynamic>> getPaymentAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return {'error': 'No business selected'};
      }

      final response = await _apiClient.get(
        '/analytics/payments',
        queryParams: {
          'businessId': businessId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      }

      return {'error': response.error ?? 'Failed to load analytics'};
    } catch (e) {
      developer.log('Payment analytics error: $e', name: 'PaymentAnalyticsService');
      return {'error': 'Error loading analytics: $e'};
    }
  }

  /// Fetch real-time payment stats (today)
  Future<Map<String, dynamic>> getTodayStats() async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return {'error': 'No business selected'};
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await _apiClient.get(
        '/analytics/payments/today',
        queryParams: {
          'businessId': businessId,
          'date': startOfDay.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      }

      return {'error': response.error ?? 'Failed to load today stats'};
    } catch (e) {
      developer.log('Today stats error: $e', name: 'PaymentAnalyticsService');
      return {'error': 'Error loading today stats: $e'};
    }
  }

  /// Fetch refund history
  Future<List<Map<String, dynamic>>> getRefundHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return [];
      }

      final response = await _apiClient.get(
        '/analytics/refunds',
        queryParams: {
          'businessId': businessId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        final refunds = response.data!['refunds'] as List<dynamic>?;
        return refunds?.cast<Map<String, dynamic>>() ?? [];
      }

      return [];
    } catch (e) {
      developer.log('Refund history error: $e', name: 'PaymentAnalyticsService');
      return [];
    }
  }

  /// Fetch payment method breakdown
  Future<Map<String, int>> getPaymentMethodStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return {};
      }

      final response = await _apiClient.get(
        '/analytics/payment-methods',
        queryParams: {
          'businessId': businessId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        final methods = response.data!['methods'] as Map<String, dynamic>?;
        return methods?.map((key, value) => MapEntry(key, value as int)) ?? {};
      }

      return {};
    } catch (e) {
      developer.log('Payment methods error: $e', name: 'PaymentAnalyticsService');
      return {};
    }
  }

  /// Fetch failure analysis
  Future<Map<String, int>> getFailureAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return {};
      }

      final response = await _apiClient.get(
        '/analytics/failures',
        queryParams: {
          'businessId': businessId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        final failures = response.data!['failures'] as Map<String, dynamic>?;
        return failures?.map((key, value) => MapEntry(key, value as int)) ?? {};
      }

      return {};
    } catch (e) {
      developer.log('Failure analysis error: $e', name: 'PaymentAnalyticsService');
      return {};
    }
  }

  /// Fetch daily trend data
  Future<List<Map<String, dynamic>>> getDailyTrend({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final businessId = _session.currentBusinessId;
      if (businessId == null) {
        return [];
      }

      final response = await _apiClient.get(
        '/analytics/daily-trend',
        queryParams: {
          'businessId': businessId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );

      if (response.isSuccess && response.data != null) {
        final trend = response.data!['trend'] as List<dynamic>?;
        return trend?.cast<Map<String, dynamic>>() ?? [];
      }

      return [];
    } catch (e) {
      developer.log('Daily trend error: $e', name: 'PaymentAnalyticsService');
      return [];
    }
  }
}
