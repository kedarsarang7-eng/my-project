// ============================================================================
// Unified Notification Controller
// ============================================================================
// Handles both local notifications and AWS SNS push notification integration.
// On native mobile platforms: registers device with SNS, manages topic
// subscriptions. On web and Windows desktop: local notifications only.
//
// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
// ============================================================================

import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aws_sns_service.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';

/// SharedPreferences keys for SNS state persistence.
const String _kEndpointArn = 'sns_endpoint_arn';
const String _kSnsRetryPending = 'sns_retry_pending';

/// Unified Controller for all Notification Logic.
/// Integrates AWS SNS for push notifications on supported platforms
/// and flutter_local_notifications for local display.
class NotificationController {
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final AwsSnsService _snsService;

  /// Cached endpoint ARN for the current device registration.
  String? _endpointArn;

  NotificationController({AwsSnsService? snsService})
    : _snsService = snsService ?? AwsSnsService();

  /// Whether SNS push notifications are supported on this platform.
  /// Web and Windows desktop are excluded — local notifications only.
  bool get _isSnsSupported {
    if (kIsWeb) return false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    return true;
  }

  /// Initialize permissions, listeners, and SNS registration.
  Future<void> init() async {
    try {
      // Init Local Notifications (Native only)
      if (!kIsWeb) {
        const androidInit = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );
        const iosInit = DarwinInitializationSettings();
        const windowsInit = WindowsInitializationSettings(
          appName: 'DukanX',
          appUserModelId: 'com.dukanx.app',
          guid: '8b1d6db2-3c1a-4c28-98e3-93d39589d81d',
        );
        await _local.initialize(
          settings: const InitializationSettings(
            android: androidInit,
            iOS: iosInit,
            windows: windowsInit,
          ),
          onDidReceiveNotificationResponse: (response) {
            developer.log(
              'Local Notification Clicked: ${response.payload}',
              name: 'NotificationController',
            );
          },
        );
      }

      // Load cached endpoint ARN
      final prefs = await SharedPreferences.getInstance();
      _endpointArn = prefs.getString(_kEndpointArn);

      // Retry SNS registration if a previous attempt failed
      if (_isSnsSupported) {
        final retryPending = prefs.getBool(_kSnsRetryPending) ?? false;
        if (retryPending && _endpointArn == null) {
          developer.log(
            'Retrying SNS registration from previous failure',
            name: 'NotificationController',
          );
          await getToken();
        }
      }
    } catch (e) {
      developer.log('Init Error: $e', name: 'NotificationController');
    }
  }

  /// Get push notification token and register with AWS SNS.
  ///
  /// On supported platforms, obtains the platform push token from the
  /// local notification plugin, registers the device with the SNS backend,
  /// and stores the returned endpoint ARN for topic subscriptions.
  ///
  /// Returns the endpoint ARN on success, or `null` if not supported or
  /// registration fails.
  Future<String?> getToken({String? uid}) async {
    if (!_isSnsSupported) {
      developer.log(
        'SNS not supported on this platform (web/desktop)',
        name: 'NotificationController',
      );
      return null;
    }

    try {
      // Get platform token from local notification setup
      final platformToken = await _getPlatformToken();
      if (platformToken == null) {
        developer.log(
          'Could not obtain platform push token',
          name: 'NotificationController',
        );
        await _setRetryFlag(true);
        return null;
      }

      // Resolve user ID
      final userId = uid ?? _getCurrentUserId();
      if (userId == null) {
        developer.log(
          'No user ID available for SNS registration',
          name: 'NotificationController',
        );
        await _setRetryFlag(true);
        return null;
      }

      // Register device with SNS backend
      final endpointArn = await _snsService.registerDevice(
        platformToken,
        userId,
      );

      if (endpointArn != null) {
        _endpointArn = endpointArn;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kEndpointArn, endpointArn);
        await _setRetryFlag(false);
        developer.log(
          'SNS registration successful: $endpointArn',
          name: 'NotificationController',
        );
        return endpointArn;
      }

      // Registration failed — set retry flag for next launch
      developer.log(
        'SNS registration failed, will retry on next launch',
        name: 'NotificationController',
      );
      await _setRetryFlag(true);
      return null;
    } catch (e) {
      developer.log(
        'SNS registration error: $e',
        name: 'NotificationController',
      );
      await _setRetryFlag(true);
      return null;
    }
  }

  /// Subscribe the device endpoint to an SNS topic.
  ///
  /// Requires a prior successful [getToken] call so that [_endpointArn]
  /// is available. The [topic] parameter is the full SNS topic ARN.
  Future<void> subscribeToTopic(String topic) async {
    if (!_isSnsSupported) return;

    if (_endpointArn == null) {
      developer.log(
        'Cannot subscribe: no endpoint ARN (device not registered)',
        name: 'NotificationController',
      );
      return;
    }

    final success = await _snsService.subscribe(_endpointArn!, topic);
    if (success) {
      developer.log(
        'Subscribed to topic: $topic',
        name: 'NotificationController',
      );
    } else {
      developer.log(
        'Failed to subscribe to topic: $topic',
        name: 'NotificationController',
      );
    }
  }

  /// Unsubscribe the device endpoint from an SNS topic.
  ///
  /// The [topic] parameter is the full SNS topic ARN.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isSnsSupported) return;

    if (_endpointArn == null) {
      developer.log(
        'Cannot unsubscribe: no endpoint ARN (device not registered)',
        name: 'NotificationController',
      );
      return;
    }

    final success = await _snsService.unsubscribe(_endpointArn!, topic);
    if (success) {
      developer.log(
        'Unsubscribed from topic: $topic',
        name: 'NotificationController',
      );
    } else {
      developer.log(
        'Failed to unsubscribe from topic: $topic',
        name: 'NotificationController',
      );
    }
  }

  /// Manually show a local notification.
  Future<void> showLocal({required String title, required String body}) async {
    if (kIsWeb) return;
    try {
      const android = AndroidNotificationDetails(
        'dukanx_channel_01',
        'DukanX Alerts',
        channelDescription: 'General Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const ios = DarwinNotificationDetails();
      const detail = NotificationDetails(android: android, iOS: ios);

      await _local.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: detail,
      );
    } catch (e) {
      developer.log('Show Local Error: $e', name: 'NotificationController');
    }
  }

  /// Schedule a specific reminder (Example usage).
  Future<void> schedulePaymentReminder(
    String customerName,
    double amount,
  ) async {
    await showLocal(
      title: 'Payment Reminder',
      body:
          'Review pending dues for $customerName: ₹${amount.toStringAsFixed(0)}',
    );
  }

  // ===========================================================================
  // Private helpers
  // ===========================================================================

  /// Obtains the platform push token via a native platform channel.
  ///
  /// On Android, this retrieves the push token (FCM-compatible) from the
  /// native side via MethodChannel.
  /// On iOS, this retrieves the APNs device token from the native side.
  Future<String?> _getPlatformToken() async {
    try {
      const channel = MethodChannel('com.dukanx.app/push');
      final token = await channel.invokeMethod<String>('getToken');
      return token;
    } on MissingPluginException {
      developer.log(
        'Push token platform channel not available',
        name: 'NotificationController',
      );
      return null;
    } on PlatformException catch (e) {
      developer.log(
        'Error getting platform token: ${e.message}',
        name: 'NotificationController',
      );
      return null;
    } catch (e) {
      developer.log(
        'Error getting platform token: $e',
        name: 'NotificationController',
      );
      return null;
    }
  }

  /// Gets the current user ID from the session manager.
  String? _getCurrentUserId() {
    try {
      return sl<SessionManager>().userId;
    } catch (e) {
      developer.log(
        'Could not get user ID from session: $e',
        name: 'NotificationController',
      );
      return null;
    }
  }

  /// Sets or clears the retry flag in SharedPreferences.
  Future<void> _setRetryFlag(bool pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending) {
        await prefs.setBool(_kSnsRetryPending, true);
      } else {
        await prefs.remove(_kSnsRetryPending);
      }
    } catch (e) {
      developer.log(
        'Error setting retry flag: $e',
        name: 'NotificationController',
      );
    }
  }
}
