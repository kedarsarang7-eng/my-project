// ============================================================================
// AUTH INTENT SERVICE - PERSISTENT LOGIN INTENT
// ============================================================================
// Manages user's login intent (vendor/customer) with persistence.
// Survives: app restart, kill, offline, crash.
//
// CRITICAL: Intent MUST be set before authentication.
// CRITICAL: Intent MUST match database role on login.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User's intended login role
enum AuthIntent { vendor, customer, none }

/// Result of role validation against intent
enum RoleValidationResult {
  /// Role matches intent - proceed
  match,

  /// Role does NOT match intent - block login
  mismatch,

  /// New user - no existing role in database
  newUser,
}

/// Service for managing persistent auth intent
class AuthIntentService {
  static const String _intentKey = 'auth_intent';

  static AuthIntentService? _instance;
  static AuthIntentService get instance => _instance ??= AuthIntentService._();

  AuthIntentService._();

  SharedPreferences? _prefs;
  AuthIntent _cachedIntent = AuthIntent.none;

  /// Initialize the service (must be called before use)
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadCachedIntent();
    debugPrint('[AuthIntentService] Initialized with intent: $_cachedIntent');
  }

  void _loadCachedIntent() {
    final stored = _prefs?.getString(_intentKey);
    if (stored == 'vendor') {
      _cachedIntent = AuthIntent.vendor;
    } else if (stored == 'customer') {
      _cachedIntent = AuthIntent.customer;
    } else {
      _cachedIntent = AuthIntent.none;
    }
  }

  /// Get current intent (from memory cache)
  AuthIntent get currentIntent => _cachedIntent;

  /// Check if intent is set
  bool get hasIntent => _cachedIntent != AuthIntent.none;

  /// Check if intent is vendor
  bool get isVendorIntent => _cachedIntent == AuthIntent.vendor;

  /// Check if intent is customer
  bool get isCustomerIntent => _cachedIntent == AuthIntent.customer;

  /// Save vendor intent (persists to storage)
  Future<void> setVendorIntent() async {
    await _saveIntent(AuthIntent.vendor);
  }

  /// Save customer intent (persists to storage)
  Future<void> setCustomerIntent() async {
    await _saveIntent(AuthIntent.customer);
  }

  /// Save intent to persistent storage
  Future<void> _saveIntent(AuthIntent intent) async {
    if (_prefs == null) await initialize();

    final value = intent == AuthIntent.vendor
        ? 'vendor'
        : intent == AuthIntent.customer
        ? 'customer'
        : '';

    await _prefs!.setString(_intentKey, value);
    _cachedIntent = intent;

    debugPrint('[AuthIntentService] Intent saved: $intent');
  }

  /// Clear intent (after successful login or logout)
  Future<void> clearIntent() async {
    if (_prefs == null) await initialize();

    await _prefs!.remove(_intentKey);
    _cachedIntent = AuthIntent.none;

    debugPrint('[AuthIntentService] Intent cleared');
  }

  /// Validate database role against current intent
  ///
  /// [dbRole] - Role from Firestore ('vendor', 'owner', 'customer')
  /// Returns validation result for flow control
  RoleValidationResult validateRole(String? dbRole) {
    if (dbRole == null || dbRole.isEmpty) {
      return RoleValidationResult.newUser;
    }

    final normalizedRole = dbRole.toLowerCase();

    // Check if role matches intent
    if (_cachedIntent == AuthIntent.vendor) {
      // Vendor intent accepts 'vendor' or 'owner' (legacy)
      if (normalizedRole == 'vendor' || normalizedRole == 'owner') {
        return RoleValidationResult.match;
      } else {
        return RoleValidationResult.mismatch;
      }
    } else if (_cachedIntent == AuthIntent.customer) {
      if (normalizedRole == 'customer') {
        return RoleValidationResult.match;
      } else {
        return RoleValidationResult.mismatch;
      }
    }

    // No intent set - this shouldn't happen in normal flow
    return RoleValidationResult.newUser;
  }

  /// Get user-friendly error message for role mismatch
  String getMismatchErrorMessage(String? dbRole) {
    final normalizedRole = (dbRole ?? '').toLowerCase();

    if (normalizedRole == 'vendor' || normalizedRole == 'owner') {
      return 'This account is registered as a Vendor. Please use Vendor Login.';
    } else if (normalizedRole == 'customer') {
      return 'This account is registered as a Customer. Please use Customer Login.';
    }

    return 'Account type mismatch. Please use the correct login portal.';
  }
}

/// Global instance for easy access
AuthIntentService get authIntent => AuthIntentService.instance;
