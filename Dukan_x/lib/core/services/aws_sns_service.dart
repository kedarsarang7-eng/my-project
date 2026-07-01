// ============================================================================
// AWS SNS Service — Push Notification Backend Integration
// ============================================================================
// Wraps HTTP calls to backend Lambda endpoints that handle actual AWS SNS
// operations (CreatePlatformEndpoint, Subscribe, Unsubscribe).
//
// This service does NOT call AWS SNS SDK directly — all SNS operations are
// performed server-side via API Gateway → Lambda.
//
// Requirements: 1.1, 1.2, 1.3
// ============================================================================

import 'dart:developer' as developer;

import '../api/api_client.dart';
import '../di/service_locator.dart';

/// Service for managing AWS SNS push notification registration and
/// topic subscriptions via backend API endpoints.
class AwsSnsService {
  final ApiClient _apiClient;

  AwsSnsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? sl<ApiClient>();

  /// Registers a device with the backend for push notifications.
  ///
  /// The backend creates an SNS platform endpoint and returns the
  /// endpoint ARN for use in subsequent subscribe/unsubscribe calls.
  ///
  /// Returns the endpoint ARN on success, or `null` on failure.
  Future<String?> registerDevice(String platformToken, String userId) async {
    try {
      final response = await _apiClient.post(
        '/notifications/register',
        body: {'platformToken': platformToken, 'userId': userId},
      );

      if (response.isSuccess && response.data != null) {
        final endpointArn = response.data!['endpointArn'] as String?;
        developer.log(
          'Device registered successfully: $endpointArn',
          name: 'AwsSnsService',
        );
        return endpointArn;
      }

      developer.log(
        'Device registration failed: ${response.error}',
        name: 'AwsSnsService',
      );
      return null;
    } catch (e) {
      developer.log('Device registration error: $e', name: 'AwsSnsService');
      return null;
    }
  }

  /// Subscribes a device endpoint to an SNS topic.
  ///
  /// The backend creates the SNS subscription linking the endpoint ARN
  /// to the specified topic ARN.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> subscribe(String endpointArn, String topicArn) async {
    try {
      final response = await _apiClient.post(
        '/notifications/subscribe',
        body: {'endpointArn': endpointArn, 'topicArn': topicArn},
      );

      if (response.isSuccess) {
        developer.log('Subscribed to topic: $topicArn', name: 'AwsSnsService');
        return true;
      }

      developer.log(
        'Subscribe failed: ${response.error}',
        name: 'AwsSnsService',
      );
      return false;
    } catch (e) {
      developer.log('Subscribe error: $e', name: 'AwsSnsService');
      return false;
    }
  }

  /// Unsubscribes a device endpoint from an SNS topic.
  ///
  /// The backend removes the SNS subscription for the endpoint ARN
  /// from the specified topic ARN.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> unsubscribe(String endpointArn, String topicArn) async {
    try {
      final response = await _apiClient.post(
        '/notifications/unsubscribe',
        body: {'endpointArn': endpointArn, 'topicArn': topicArn},
      );

      if (response.isSuccess) {
        developer.log(
          'Unsubscribed from topic: $topicArn',
          name: 'AwsSnsService',
        );
        return true;
      }

      developer.log(
        'Unsubscribe failed: ${response.error}',
        name: 'AwsSnsService',
      );
      return false;
    } catch (e) {
      developer.log('Unsubscribe error: $e', name: 'AwsSnsService');
      return false;
    }
  }
}
