// ============================================================================
// Trial Subscription Service — Repository pattern
// ============================================================================
// Fetches trial state from /tenant/subscription API
// Handles upgrade flow via /tenant/upgrade
// No business logic in this layer — pure data access
// ============================================================================

import 'package:dio/dio.dart';
import '../../../config/api_config.dart';
import '../../models/trial_subscription_state.dart';

class TrialSubscriptionService {
  final Dio _dio;
  final String _baseUrl;

  TrialSubscriptionService({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// GET /tenant/subscription
  Future<TrialSubscriptionState> getSubscriptionState() async {
    try {
      final response = await _dio.get('$_baseUrl/tenant/subscription');

      if (response.statusCode == 200) {
        final data = response.data;
        // Handle both wrapped and unwrapped responses
        final payload = data is Map && data.containsKey('data')
            ? data['data']
            : data;
        return TrialSubscriptionState.fromJson(
            payload as Map<String, dynamic>);
      }

      throw TrialServiceException(
        message: 'Failed to fetch subscription state',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /tenant/upgrade
  Future<TrialSubscriptionState> upgradePlan({
    required String planId,
    required String paymentReference,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/tenant/upgrade',
        data: {
          'planId': planId,
          'paymentReference': paymentReference,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final payload = data is Map && data.containsKey('data')
            ? data['data']
            : data;
        return TrialSubscriptionState.fromJson(
            payload as Map<String, dynamic>);
      }

      throw TrialServiceException(
        message: response.data?['message'] ?? 'Upgrade failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  TrialServiceException _handleDioError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      return TrialServiceException(
        message: data?['message'] ?? error.message ?? 'Network error',
        statusCode: error.response!.statusCode,
        code: data?['error'],
      );
    }
    return TrialServiceException(
      message: error.message ?? 'Network error',
      code: 'NETWORK_ERROR',
    );
  }
}

class TrialServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  TrialServiceException({
    required this.message,
    this.statusCode,
    this.code,
  });

  @override
  String toString() => 'TrialServiceException: $message (code: $code)';
}

/// Singleton instance
final trialSubscriptionService = TrialSubscriptionService();
