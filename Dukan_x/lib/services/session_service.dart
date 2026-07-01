import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Session Service - Manages login sessions and user persistence
/// - Stores session tokens securely
/// - Manages login/logout state
/// - Auto-redirects logged-in users
/// - Prevents repeated login requests
///
/// NOTE: Consider using SessionManager for new code.
class SessionService {
  SessionService._internal();
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;

  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _sessionTokenKey = 'session_token';
  static const String _loginTimeKey = 'login_time';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userContactKey = 'user_contact';
  static const String _ownerDocIdKey = 'owner_doc_id';
  static const String _ownerEmailKey = 'owner_email';

  SharedPreferences? _prefs;

  bool get isInitialized => _prefs != null;

  SharedPreferences get _prefsSafe {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('SessionService.init() must be called before use');
    }
    return prefs;
  }

  /// Initialize SharedPreferences (idempotent)
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    developer.log('SessionService initialized', name: 'SessionService');
  }

  /// Save user session after login
  Future<void> saveSession({
    required String userId,
    required String role,
    String? contact,
    String? sessionToken,
    String? ownerDocId,
    String? ownerEmail,
  }) async {
    if (!isInitialized) await init();
    final prefs = _prefsSafe;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final operations = <Future<bool>>[
        prefs.setString(_userIdKey, userId),
        prefs.setString(_userRoleKey, role),
        prefs.setString(_sessionTokenKey, sessionToken ?? ''),
        prefs.setInt(_loginTimeKey, timestamp),
        prefs.setBool(_isLoggedInKey, true),
      ];

      if (contact != null) {
        operations.add(prefs.setString(_userContactKey, contact));
      } else {
        operations.add(prefs.remove(_userContactKey));
      }
      if (ownerDocId != null) {
        operations.add(prefs.setString(_ownerDocIdKey, ownerDocId));
      } else {
        operations.add(prefs.remove(_ownerDocIdKey));
      }
      if (ownerEmail != null) {
        operations.add(prefs.setString(_ownerEmailKey, ownerEmail));
      } else {
        operations.add(prefs.remove(_ownerEmailKey));
      }

      await Future.wait(operations);

      developer.log(
        'Session saved for user: $userId (role: $role)',
        name: 'SessionService',
      );
    } catch (e) {
      developer.log('Error saving session: $e', name: 'SessionService');
      rethrow;
    }
  }

  /// Get current user ID
  String? getUserId() {
    return _prefs?.getString(_userIdKey);
  }

  /// Get current user role
  String? getUserRole() {
    return _prefs?.getString(_userRoleKey);
  }

  /// Get current user phone
  String? getUserPhone() {
    return _prefs?.getString(_userContactKey);
  }

  /// Get current user name (stored in contact key)
  String? getUserName() {
    return _prefs?.getString(_userContactKey);
  }

  String? getOwnerDocId() => _prefs?.getString(_ownerDocIdKey);

  String? getOwnerEmail() => _prefs?.getString(_ownerEmailKey);

  String? get currentBusinessId =>
      _prefs?.getString(_userIdKey); // For now using userId as businessId

  /// Check if user is logged in
  bool isLoggedIn() {
    return _prefs?.getBool(_isLoggedInKey) ?? false;
  }

  /// Get session token
  String? getSessionToken() {
    final token = _prefs?.getString(_sessionTokenKey);
    return token?.isNotEmpty ?? false ? token : null;
  }

  /// Get login time
  int? getLoginTime() {
    return _prefs?.getInt(_loginTimeKey);
  }

  /// Check if session is still valid (not expired)
  bool isSessionValid({Duration sessionTimeout = const Duration(hours: 24)}) {
    if (!isLoggedIn()) return false;

    final loginTime = getLoginTime();
    if (loginTime == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - loginTime;
    final timeoutMs = sessionTimeout.inMilliseconds;

    return timeDiff < timeoutMs;
  }

  /// Clear session (logout)
  Future<void> clearSession() async {
    if (!isInitialized) return;
    final prefs = _prefsSafe;
    try {
      await Future.wait([
        prefs.remove(_userIdKey),
        prefs.remove(_userRoleKey),
        prefs.remove(_userContactKey),
        prefs.remove(_sessionTokenKey),
        prefs.remove(_loginTimeKey),
        prefs.remove(_ownerDocIdKey),
        prefs.remove(_ownerEmailKey),
        prefs.setBool(_isLoggedInKey, false),
      ]);

      developer.log('Session cleared', name: 'SessionService');
    } catch (e) {
      developer.log('Error clearing session: $e', name: 'SessionService');
      rethrow;
    }
  }

  /// Refresh session timestamp
  Future<void> refreshSession() async {
    if (!isInitialized) await init();
    final prefs = _prefsSafe;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_loginTimeKey, timestamp);
      developer.log('Session refreshed', name: 'SessionService');
    } catch (e) {
      developer.log('Error refreshing session: $e', name: 'SessionService');
      rethrow;
    }
  }

  /// Get user route based on role
  String getUserRoute(String? role) {
    // All users should go through AuthGate for role-based routing
    return '/auth_gate';
  }

  /// Convenience method for login - wraps saveSession
  Future<void> login({
    required String userId,
    required String userRole,
    required String userName,
    String? ownerDocId,
    String? ownerEmail,
  }) async {
    await saveSession(
      userId: userId,
      role: userRole,
      contact: userName,
      ownerDocId: ownerDocId,
      ownerEmail: ownerEmail,
    );
  }
}

/// Global session service instance
// ignore: deprecated_member_use_from_same_package
final sessionService = SessionService();
