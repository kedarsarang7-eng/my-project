// ============================================================================
// DEEP LINK SERVICE
// ============================================================================
// Handles incoming deep links (e.g. from QR Codes)
// Enforces Customer-Only Mode when valid "join" link is scanned
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../services/secure_qr_service.dart';
import '../session/session_manager.dart';
import '../auth/auth_intent_service.dart';
import '../di/service_locator.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  static DeepLinkService get instance => _instance;

  /// Generate a cryptographically secure random state for OAuth CSRF protection.
  static Future<String> generateOAuthState() async {
    return const Uuid().v4();
  }

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _isInitialized = false;

  DeepLinkService._internal();

  /// Initialize Deep Link Listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Handle app launch from link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri);
      }

      // Listen for subsequent links
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _handleLink(uri);
        },
        onError: (err) {
          debugPrint('[DeepLinkService] Error: $err');
        },
      );

      _isInitialized = true;
      debugPrint('[DeepLinkService] Initialized');
    } catch (e) {
      debugPrint('[DeepLinkService] Initialization failed: $e');
    }
  }

  /// Handle incoming URI
  Future<void> _handleLink(Uri uri) async {
    debugPrint('[DeepLinkService] Handling link: $uri');

    // Check if it's a "join" link
    // Supports: https://app.dukanx.com/join or dukanx://join
    if (uri.pathSegments.contains('join')) {
      await _processJoinLink(uri);
    }
  }

  /// Process "Join Shop" Link
  Future<void> _processJoinLink(Uri uri) async {
    try {
      // 1. Verify Signature & Params
      final secureQr = SecureQrService(); // Or get from SL if registered
      final params = uri.queryParameters;

      final result = secureQr.verifyDeepLinkParams(params);

      if (!result.isValid) {
        debugPrint('[DeepLinkService] Invalid link: ${result.error}');
        // Optional: Show error via global context if available
        return;
      }

      final shopId = result.shopId;
      if (shopId == null) return;

      debugPrint('[DeepLinkService] Valid join link for shop: $shopId');

      // 2. Set Auth Intent
      await authIntent.initialize();
      // Ensure we treat this strictly
      if (authIntent.currentIntent != AuthIntent.customer) {
        await authIntent.setCustomerIntent();
      }

      // 3. Enforce Customer Mode in Session
      final session = sl<SessionManager>();
      await session.enterCustomerMode(shopId);

      // 4. Navigation will be handled by AuthGate/RoleGuard automatically
      // because SessionManager notifies listeners, and AuthGate listens to it.
    } catch (e) {
      debugPrint('[DeepLinkService] Process error: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
