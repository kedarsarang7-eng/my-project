// ============================================================================
// SESSION MANAGER - CENTRALIZED AUTH STATE
// ============================================================================
// Singleton service for managing user authentication state
// Injected via DI - NEVER instantiated directly
// Consistent auth state across entire app
//
// CRITICAL: Role is IMMUTABLE after first assignment
// Role stored in: users/{uid}.role with roleLocked=true
//
import '../../models/business_type.dart';
export '../../models/business_type.dart';

// Version: 3.0.0 - Role Fix
// ============================================================================

import 'dart:async';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import '../auth/auth_intent_service.dart';
import '../di/service_locator.dart';
import '../../services/role_management_service.dart';

export '../models/user_role.dart';
export '../../services/role_management_service.dart'
    show Permission, RolePermissions;

/// Application Operation Mode
enum AppMode {
  normal, // Standard mode (Vendor can login, Customer can login)
  customerOnly, // Locked Customer Mode (Vendor login disallowed)
}

// Local storage keys
const String _kRoleKey = 'user_role';
const String _kUserIdKey = 'user_id';
const String _kAppModeKey = 'app_mode';
const String _kLockedVendorIdKey = 'locked_vendor_id';

/// User session data
class UserSession {
  final String odId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final String?
  ownerId; // For owners, same as odId. For customers, their linked owner
  final BusinessType? businessType; // Single Source of Truth for Business Type
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? metadata;
  final String? activeBusinessId; // Currently active business

  // App Mode State
  final AppMode appMode;
  final String? lockedVendorId; // If in customerOnly mode

  // RBAC Integration: Staff role and permissions loaded from business_users
  final UserRole? staffRole; // Granular role from business_users collection
  final Set<Permission> staffPermissions; // Permissions derived from staffRole

  const UserSession({
    required this.odId,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    this.ownerId,
    this.businessType,
    this.lastLoginAt,
    this.metadata,
    this.activeBusinessId,
    this.appMode = AppMode.normal,
    this.lockedVendorId,
    this.staffRole,
    this.staffPermissions = const {},
  });

  bool get isOwner => role == UserRole.owner;

  /// The effective role used for permission checks.
  /// Returns staffRole if set (staff user), otherwise falls back to role.
  UserRole get effectiveRole => staffRole ?? role;

  /// Legacy getter — always false in vendor-only app (no customer role)
  bool get isCustomer => false;

  /// Legacy getter — always false in vendor-only app (no patient role)
  bool get isPatient => false;
  bool get isAuthenticated => role != UserRole.unknown && odId.isNotEmpty;

  /// Check if the session has a specific permission.
  bool hasPermission(Permission permission) {
    return staffPermissions.contains(permission);
  }

  UserSession copyWith({
    String? odId,
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    String? ownerId,
    BusinessType? businessType,
    DateTime? lastLoginAt,
    Map<String, dynamic>? metadata,
    String? activeBusinessId,
    AppMode? appMode,
    String? lockedVendorId,
    UserRole? staffRole,
    Set<Permission>? staffPermissions,
  }) {
    return UserSession(
      odId: odId ?? this.odId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      ownerId: ownerId ?? this.ownerId,
      businessType: businessType ?? this.businessType,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      metadata: metadata ?? this.metadata,
      activeBusinessId: activeBusinessId ?? this.activeBusinessId,
      appMode: appMode ?? this.appMode,
      lockedVendorId: lockedVendorId ?? this.lockedVendorId,
      staffRole: staffRole ?? this.staffRole,
      staffPermissions: staffPermissions ?? this.staffPermissions,
    );
  }

  static const empty = UserSession(odId: '', role: UserRole.unknown);
}

/// Session Manager - Singleton for auth state
class SessionManager extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UserSession _currentSession = UserSession.empty;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<BusinessUser?>? _roleChangeSubscription;
  bool _isInitialized = false;
  bool _isLoading = false;

  /// When the authenticated user has multiple business_users assignments,
  /// this list is populated so the UI can present a role/business picker.
  /// Null means not yet resolved or single-role (auto-selected).
  List<BusinessUser>? _availableRoles;

  /// Whether the user has made a role selection (or was auto-selected).
  bool _roleSelected = false;

  SessionManager({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore {
    _initAppMode(); // Load app mode first
    _initAuthListener();
  }

  /// Load persisted App Mode
  Future<void> _initAppMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_kAppModeKey);
      final vendorId = prefs.getString(_kLockedVendorIdKey);

      if (modeStr == 'customerOnly' && vendorId != null) {
        _currentSession = _currentSession.copyWith(
          appMode: AppMode.customerOnly,
          lockedVendorId: vendorId,
        );
        debugPrint(
          '[SessionManager] App locked to Customer Mode for vendor: $vendorId',
        );
      }
    } catch (e) {
      debugPrint('[SessionManager] Error loading app mode: $e');
    }
  }

  // ============================================
  // PUBLIC GETTERS
  // ============================================

  /// Current user session
  UserSession get currentSession => _currentSession;

  /// Current user ID (Firebase UID)
  String? get userId =>
      _currentSession.isAuthenticated ? _currentSession.odId : null;

  /// Current owner ID (for Firestore paths)
  String? get ownerId => _currentSession.ownerId ?? userId;

  /// Get current Cognito User
  Future<CognitoUser?> get currentCognitoUser async {
    try {
      final userPool = sl<CognitoUserPool>();
      return await userPool.getCurrentUser();
    } catch (_) {
      return null;
    }
  }

  /// Get current business ID
  String? get currentBusinessId => _currentSession.activeBusinessId ?? userId;

  /// Get access token
  Future<String?> getAccessToken() async {
    try {
      final userPool = sl<CognitoUserPool>();
      final currentUser = await userPool.getCurrentUser();
      if (currentUser != null) {
        final session = await currentUser.getSession();
        if (session != null && session.isValid()) {
          return session.getAccessToken().getJwtToken();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Set active business ID
  Future<void> setActiveBusiness(String businessId) async {
    _currentSession = _currentSession.copyWith(activeBusinessId: businessId);
    notifyListeners();
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _currentSession.isAuthenticated;

  /// Check if user is an owner
  bool get isOwner => _currentSession.isOwner;

  /// Check if user is a customer (legacy — always false in vendor-only app)
  bool get isCustomer => false;

  /// Check if user is a patient (legacy — always false in vendor-only app)
  bool get isPatient => false;

  /// Check if session is initialized
  bool get isInitialized => _isInitialized;

  /// Check if loading
  bool get isLoading => _isLoading;

  /// Check if App is in Customer-Only Mode
  bool get isCustomerOnlyMode =>
      _currentSession.appMode == AppMode.customerOnly;

  /// Get Locked Vendor ID (if in customerOnly mode)
  String? get lockedVendorId => _currentSession.lockedVendorId;

  /// Get current Firebase user
  User? get firebaseUser => _auth.currentUser;

  /// List of available role/business assignments for multi-role users.
  /// Non-null when multiple assignments exist and user hasn't selected yet.
  List<BusinessUser>? get availableRoles => _availableRoles;

  /// Whether the user needs to pick a role before proceeding to the dashboard.
  bool get needsRolePicker =>
      _availableRoles != null && _availableRoles!.length > 1 && !_roleSelected;

  /// Select a role/business from the available assignments.
  ///
  /// Sets the active businessId, loads permissions from [RolePermissions],
  /// and notifies listeners so AuthGate can proceed to the vendor flow.
  Future<void> selectRole(BusinessUser selected) async {
    final permissions = RolePermissions.getPermissions(selected.role);
    _currentSession = _currentSession.copyWith(
      activeBusinessId: selected.businessId,
      staffRole: selected.role,
      staffPermissions: permissions,
      role: selected.role == UserRole.owner
          ? UserRole.owner
          : _currentSession.role,
      ownerId: selected.businessId,
    );
    _roleSelected = true;

    // Cache the selected role
    await _cacheRole(_currentSession.odId, selected.role.name);

    // Subscribe to real-time role changes for the selected business
    _subscribeToRoleChanges(selected.userId, businessId: selected.businessId);

    debugPrint(
      '[SessionManager] Role selected: ${selected.role.name} '
      'for business: ${selected.businessId} '
      '(${permissions.length} permissions)',
    );
    notifyListeners();
  }

  // ============================================
  // APP MODE MANAGEMENT
  // ============================================

  /// ENTER Customer-Only Mode (Locked)
  /// Triggers via Deep Link / QR Scan
  Future<void> enterCustomerMode(String vendorId) async {
    if (isCustomerOnlyMode && lockedVendorId == vendorId) return;

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAppModeKey, 'customerOnly');
      await prefs.setString(_kLockedVendorIdKey, vendorId);

      _currentSession = _currentSession.copyWith(
        appMode: AppMode.customerOnly,
        lockedVendorId: vendorId,
      );

      // If currently logged in as Owner, force logout
      if (isOwner) {
        await signOut();
      }

      debugPrint(
        '[SessionManager] Enforced Customer Mode for vendor: $vendorId',
      );
    } catch (e) {
      debugPrint('[SessionManager] Failed to set customer mode: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// EXIT Customer-Only Mode
  /// (Only accessible via Developer/Admin backdoor or clear data)
  Future<void> exitCustomerMode() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAppModeKey);
      await prefs.remove(_kLockedVendorIdKey);

      _currentSession = _currentSession.copyWith(
        appMode: AppMode.normal,
        lockedVendorId: null, // explicit null
      );

      debugPrint('[SessionManager] Exited Customer Mode');
    } catch (e) {
      debugPrint('[SessionManager] Failed to exit customer mode: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // AUTHENTICATION METHODS
  // ============================================

  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _currentSession = UserSession.empty;
        _isInitialized = true;
        notifyListeners();
      } else {
        await _loadUserSession(user);
      }
    });
  }

  /// Load user session from Firestore
  /// PRIORITY: users/{uid} → owners/{uid} → customers/{uid} → create from intent
  Future<void> _loadUserSession(User user) async {
    _isLoading = true;
    notifyListeners();

    try {
      bool sessionFound = false;
      String? cachedRole;

      // 0. Try local cache first (for offline support)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedUserId = prefs.getString(_kUserIdKey);
        if (cachedUserId == user.uid) {
          cachedRole = prefs.getString(_kRoleKey);
          debugPrint('[SessionManager] Cached role: $cachedRole');
        }
      } catch (e) {
        debugPrint('[SessionManager] Cache read error: $e');
      }

      // 1. FIRST: Check users collection (single source of truth for role)
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()?['role'] != null) {
          final data = userDoc.data()!;
          final roleStr = data['role'] as String;
          final UserRole role;
          switch (roleStr) {
            case 'owner':
              role = UserRole.owner;
            case 'manager':
              role = UserRole.manager;
            case 'staff':
            case 'cashier':
              role = UserRole.staff;
            case 'accountant':
              role = UserRole.accountant;
            case 'pharmacist':
              role = UserRole.pharmacist;
            case 'waiter':
              role = UserRole.waiter;
            case 'chef':
              role = UserRole.chef;
            case 'captain':
              role = UserRole.captain;
            case 'doctor':
              role = UserRole.doctor;
            case 'receptionist':
              role = UserRole.receptionist;
            case 'nurse':
              role = UserRole.nurse;
            default:
              role = UserRole.unknown;
          }

          _currentSession = UserSession(
            odId: user.uid,
            email: user.email,
            displayName: data['name'] ?? user.displayName,
            photoUrl: data['photoUrl'] ?? user.photoURL,
            role: role,
            ownerId: role == UserRole.owner ? user.uid : data['linkedOwnerId'],
            businessType: _parseBusinessType(data['businessType']),
            lastLoginAt: DateTime.now(),
            metadata: data,
          );
          sessionFound = true;

          // Cache role locally
          await _cacheRole(user.uid, roleStr);
          debugPrint('[SessionManager] Role from users collection: $role');
        }
      } catch (e) {
        debugPrint('[SessionManager] users collection error: $e');
      }

      // 2. Try Owners Collection (if not found in users)
      if (!sessionFound) {
        try {
          final ownerDoc = await _firestore
              .collection('owners')
              .doc(user.uid)
              .get();
          if (ownerDoc.exists) {
            final data = ownerDoc.data()!;
            _currentSession = UserSession(
              odId: user.uid,
              email: user.email,
              displayName:
                  data['businessName'] ?? data['name'] ?? user.displayName,
              photoUrl: data['photoUrl'] ?? user.photoURL,
              role: UserRole.owner,
              ownerId: user.uid,
              businessType: _parseBusinessType(data['businessType']),
              lastLoginAt: DateTime.now(),
              metadata: data,
            );
            sessionFound = true;

            // Sync to users collection for future
            await _ensureUserDocument(user.uid, 'owner');
            debugPrint('[SessionManager] Role from owners collection: owner');
          }
        } catch (e) {
          debugPrint('[SessionManager] owners collection error: $e');
        }
      }

      // ================================================================
      // RBAC INTEGRATION: Resolve staff role from business_users collection
      // ================================================================
      // After determining user is vendor/owner type, check if they have a
      // staff role assignment in the business_users collection. If they do,
      // override the session with the granular staff role and permissions.
      // Owner accounts (role=owner or no record) are unchanged.
      // ================================================================
      if (sessionFound && _currentSession.role == UserRole.owner) {
        await _resolveStaffRole(user.uid);
      } else if (sessionFound && _currentSession.role != UserRole.unknown) {
        // Non-owner role resolved from users collection — load permissions
        final permissions = RolePermissions.getPermissions(
          _currentSession.role,
        );
        _currentSession = _currentSession.copyWith(
          staffRole: _currentSession.role,
          staffPermissions: permissions,
        );
        debugPrint(
          '[SessionManager] Permissions loaded for ${_currentSession.role}: ${permissions.length} permissions',
        );
      }

      // 3. Try Customers Collection (if still not found)
      // NOTE: In vendor-only app, customer records map to unknown role
      if (!sessionFound) {
        try {
          final customerDoc = await _firestore
              .collection('customers')
              .doc(user.uid)
              .get();
          if (customerDoc.exists) {
            final data = customerDoc.data()!;
            _currentSession = UserSession(
              odId: user.uid,
              email: user.email,
              displayName: data['name'] ?? user.displayName,
              photoUrl: data['photoUrl'] ?? user.photoURL,
              role: UserRole.unknown,
              ownerId: data['linkedOwnerId'],
              businessType: _parseBusinessType(data['businessType']),
              lastLoginAt: DateTime.now(),
              metadata: data,
            );
            sessionFound = true;

            debugPrint(
              '[SessionManager] Role from customers collection: unknown (vendor-only app)',
            );
          }
        } catch (e) {
          debugPrint('[SessionManager] customers collection error: $e');
        }
      }

      // 4. New user - determine role from intent and create atomically
      if (!sessionFound) {
        debugPrint('[SessionManager] New user, checking intent...');
        await authIntent.initialize();

        String roleStr;
        UserRole role;
        String? linkedOwnerId;

        if (authIntent.isVendorIntent) {
          roleStr = 'owner';
          role = UserRole.owner;
          linkedOwnerId = user.uid;
        } else if (authIntent.isCustomerIntent) {
          // Customer intent in vendor-only app — treat as unknown
          roleStr = 'unknown';
          role = UserRole.unknown;
          linkedOwnerId = null;
        } else if (cachedRole != null) {
          // Use cached role if no intent
          roleStr = cachedRole;
          role = _parseRoleString(cachedRole);
          linkedOwnerId = role == UserRole.owner ? user.uid : null;
          debugPrint('[SessionManager] Using cached role: $role');
        } else {
          // Default to owner for new users without intent (safety)
          roleStr = 'owner';
          role = UserRole.owner;
          linkedOwnerId = user.uid;
          debugPrint('[SessionManager] No intent, defaulting to owner');
        }

        // ATOMIC WRITE - Create user document with role locked
        await _ensureUserDocument(user.uid, roleStr);

        _currentSession = UserSession(
          odId: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          role: role,
          ownerId: linkedOwnerId,
          lastLoginAt: DateTime.now(),
        );

        debugPrint('[SessionManager] Created new user with role: $role');
      }

      _isInitialized = true;
      debugPrint(
        '[SessionManager] Session loaded: ${_currentSession.role} - ${_currentSession.odId}',
      );
    } catch (e) {
      debugPrint('[SessionManager] Critical error: $e');

      // Try using cached role for offline recovery
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedUserId = prefs.getString(_kUserIdKey);
        final cachedRole = prefs.getString(_kRoleKey);

        if (cachedUserId == user.uid && cachedRole != null) {
          final role = _parseRoleString(cachedRole);
          _currentSession = UserSession(
            odId: user.uid,
            email: user.email,
            displayName: user.displayName,
            role: role,
            ownerId: role == UserRole.owner ? user.uid : null,
            lastLoginAt: DateTime.now(),
          );
          _isInitialized = true;
          debugPrint('[SessionManager] Recovered from cache: $role');
          return;
        }
      } catch (_) {}

      // Last resort - use intent if available
      try {
        await authIntent.initialize();
        final role = authIntent.isCustomerIntent
            ? UserRole.unknown
            : UserRole.owner;
        _currentSession = UserSession(
          odId: user.uid,
          email: user.email,
          displayName: user.displayName,
          role: role,
          ownerId: role == UserRole.owner ? user.uid : null,
          lastLoginAt: DateTime.now(),
        );
        _isInitialized = true;
        debugPrint('[SessionManager] Emergency fallback: $role');
      } catch (_) {
        // CRITICAL: Even in worst case, use owner role instead of unknown
        _currentSession = UserSession(
          odId: user.uid,
          email: user.email,
          role: UserRole.owner, // NEVER unknown for authenticated users
          ownerId: user.uid,
        );
        _isInitialized = true;
        debugPrint('[SessionManager] Ultimate fallback: owner');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cache role locally for offline access
  Future<void> _cacheRole(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserIdKey, uid);
      await prefs.setString(_kRoleKey, role);
      debugPrint('[SessionManager] Role cached: $role');
    } catch (e) {
      debugPrint('[SessionManager] Cache write error: $e');
    }
  }

  // ============================================================================
  // RBAC OWNER-FALLBACK REMEDIATION (review §4 — Options 1 + 3 + 4)
  // ----------------------------------------------------------------------------
  // Guiding principle: never fabricate a HIGHER privilege than last known; fail
  // to the LOWEST safe known role, not the highest. A genuine owner stays
  // available; a staff user is never silently escalated.
  // ============================================================================

  /// Option 1 — pure fallback decision used when the granular `business_users`
  /// resolution fails or is unavailable.
  ///
  /// Returns the safe fallback role given the [cachedRole] (the last-known
  /// granular role written by [_cacheRole]):
  /// - manager / staff / accountant → preserved AS-IS (never escalated to owner)
  /// - owner / unknown / null       → owner (genuine-owner availability)
  ///
  /// This guarantees a non-owner staff member who hits a transient read failure
  /// keeps only their last-known staff permissions, while a genuine owner (or a
  /// user with no usable cache) remains able to enter their shop.
  @visibleForTesting
  static UserRole resolveFallbackStaffRole(UserRole? cachedRole) {
    switch (cachedRole) {
      case UserRole.manager:
      case UserRole.staff:
      case UserRole.accountant:
      case UserRole.pharmacist:
      case UserRole.waiter:
      case UserRole.chef:
      case UserRole.captain:
      case UserRole.doctor:
      case UserRole.receptionist:
      case UserRole.nurse:
        // Last-known staff role — preserve, do NOT escalate.
        return cachedRole!;
      case UserRole.owner:
      case UserRole.unknown:
      case null:
        // Genuine owner, or no usable cache — fall back to owner for
        // availability (documented residual; shrunk by retry in Option 3).
        return UserRole.owner;
    }
  }

  /// Option 4 — pure decision for the real-time delete/deactivate events.
  ///
  /// Returns true when a removed/deactivated `business_users` assignment should
  /// REVOKE access (sign the user out) rather than escalate to owner. This is
  /// true only for known staff roles; a genuine owner ([UserRole.owner]) — or
  /// an unresolved role — is never logged out by these events.
  @visibleForTesting
  static bool shouldRevokeOnRemoval(UserRole? currentStaffRole) {
    switch (currentStaffRole) {
      case UserRole.manager:
      case UserRole.staff:
      case UserRole.accountant:
      case UserRole.pharmacist:
      case UserRole.waiter:
      case UserRole.chef:
      case UserRole.captain:
      case UserRole.doctor:
      case UserRole.receptionist:
      case UserRole.nurse:
        return true;
      case UserRole.owner:
      case UserRole.unknown:
      case null:
        return false;
    }
  }

  /// Read the cached granular role for [uid], or null if the cache belongs to a
  /// different user or is absent. Used by the Option 1 fallback so a staff user
  /// falls back to their last-known staff role rather than to owner.
  Future<UserRole?> _readCachedGranularRole(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString(_kUserIdKey);
      if (cachedUserId != uid) return null;
      final roleStr = prefs.getString(_kRoleKey);
      if (roleStr == null) return null;
      return _parseRoleString(roleStr);
    } catch (e) {
      debugPrint('[SessionManager] Cached granular role read error: $e');
      return null;
    }
  }

  /// Option 3 — bounded retry with exponential backoff (200ms, 400ms, 800ms).
  ///
  /// Retries a transient async [op] up to [attempts] times before giving up.
  /// Rethrows the last error so the caller can apply its fallback. This shrinks
  /// the failure window so most transient Firestore/network blips resolve before
  /// any fallback (escalation OR lockout) is ever applied.
  Future<T> _withRetry<T>(Future<T> Function() op, {int attempts = 3}) async {
    var delayMs = 200;
    for (var attempt = 1; ; attempt++) {
      try {
        return await op();
      } catch (e) {
        if (attempt >= attempts) rethrow;
        debugPrint(
          '[SessionManager] Transient error (attempt $attempt/$attempts), '
          'retrying in ${delayMs}ms: $e',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      }
    }
  }

  /// Option 4 — revoke access for a removed/deactivated staff member by signing
  /// them out. Never called for a genuine owner (gated by [shouldRevokeOnRemoval]).
  void _revokeAccess(String reason) {
    debugPrint('[SessionManager] Access revoked: $reason');
    unawaited(signOut());
  }

  /// Resolve staff role from business_users collection.
  ///
  /// Queries the business_users collection for the user's role assignment.
  /// - If multiple records exist, stores them for the role picker and waits.
  /// - If exactly one record exists, auto-selects it.
  /// - If a record exists with role != owner (manager/staff/accountant),
  ///   sets staffRole and loads permissions from RolePermissions.
  /// - If no record exists or role == owner, preserves full owner access.
  Future<void> _resolveStaffRole(String uid) async {
    try {
      final businessId = currentBusinessId;

      // Query ALL business_users records for this user.
      // Option 3: retry transient read failures before any fallback.
      final roleService = RoleManagementService(firestore: _firestore);
      final allAssignments = await _withRetry(
        () => roleService.getBusinessUsersForUser(uid),
      );

      if (allAssignments.length > 1) {
        // Multiple assignments — store for picker, wait for user selection
        _availableRoles = allAssignments;
        _roleSelected = false;

        // Default to owner permissions until user picks
        final ownerPermissions = RolePermissions.getPermissions(UserRole.owner);
        _currentSession = _currentSession.copyWith(
          staffRole: UserRole.owner,
          staffPermissions: ownerPermissions,
        );
        debugPrint(
          '[SessionManager] Multiple roles found (${allAssignments.length}) — '
          'awaiting user selection',
        );
        return;
      } else if (allAssignments.length == 1) {
        // Single assignment — auto-select
        final assignment = allAssignments.first;
        _availableRoles = null;
        _roleSelected = true;

        if (assignment.role != UserRole.owner &&
            assignment.role != UserRole.unknown) {
          final permissions = RolePermissions.getPermissions(assignment.role);
          _currentSession = _currentSession.copyWith(
            activeBusinessId: assignment.businessId,
            staffRole: assignment.role,
            staffPermissions: permissions,
          );
          await _cacheRole(uid, assignment.role.name);
          debugPrint(
            '[SessionManager] Single role auto-selected: ${assignment.role} '
            '(${permissions.length} permissions)',
          );

          // Subscribe to real-time role changes for this assignment
          _subscribeToRoleChanges(uid, businessId: assignment.businessId);
          return;
        }
      }

      // Fallback: Check by specific businessId (legacy behavior)
      if (businessId == null || businessId.isEmpty) {
        // Option 1: use the last-known cached granular role instead of
        // unconditionally granting owner — never escalate a staff user.
        final cached = await _readCachedGranularRole(uid);
        final resolved = resolveFallbackStaffRole(cached);
        final permissions = RolePermissions.getPermissions(resolved);
        _currentSession = _currentSession.copyWith(
          staffRole: resolved,
          staffPermissions: permissions,
        );
        _availableRoles = null;
        _roleSelected = true;
        debugPrint(
          '[SessionManager] No businessId — cached-role fallback: '
          'cached=$cached → resolved=$resolved '
          '(${permissions.length} permissions)',
        );
        return;
      }

      // Query specific business_users document.
      // Option 3: retry transient read failures before any fallback.
      final doc = await _withRetry(
        () => _firestore
            .collection('business_users')
            .doc('${businessId}_$uid')
            .get(),
      );

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final roleStr = data['role'] as String? ?? 'owner';
        final resolvedRole = _parseRoleString(roleStr);

        if (resolvedRole != UserRole.owner &&
            resolvedRole != UserRole.unknown) {
          // Staff role found — override session with granular role
          final permissions = RolePermissions.getPermissions(resolvedRole);
          _currentSession = _currentSession.copyWith(
            staffRole: resolvedRole,
            staffPermissions: permissions,
          );
          _availableRoles = null;
          _roleSelected = true;

          // Cache the staff role
          await _cacheRole(uid, roleStr);
          debugPrint(
            '[SessionManager] Staff role resolved: $resolvedRole '
            '(${permissions.length} permissions)',
          );

          // Subscribe to real-time role changes for this business
          _subscribeToRoleChanges(uid, businessId: businessId);
          return;
        }
      }

      // No business_users record or role is owner — maintain full owner access
      final ownerPermissions = RolePermissions.getPermissions(UserRole.owner);
      _currentSession = _currentSession.copyWith(
        staffRole: UserRole.owner,
        staffPermissions: ownerPermissions,
      );
      _availableRoles = null;
      _roleSelected = true;
      debugPrint('[SessionManager] Owner confirmed — full permissions granted');

      // Subscribe to real-time role changes
      _subscribeToRoleChanges(uid);
    } catch (e) {
      // Option 1 + 3: after retries are exhausted, fall back to the LAST-KNOWN
      // cached granular role rather than unconditionally granting owner. This
      // preserves owner availability without escalating a staff user.
      debugPrint('[SessionManager] Staff role resolution error: $e');
      final cached = await _readCachedGranularRole(uid);
      final resolved = resolveFallbackStaffRole(cached);
      final permissions = RolePermissions.getPermissions(resolved);
      _currentSession = _currentSession.copyWith(
        staffRole: resolved,
        staffPermissions: permissions,
      );
      _availableRoles = null;
      _roleSelected = true;
      debugPrint(
        '[SessionManager] Cached-role fallback applied after error: '
        'cached=$cached → resolved=$resolved '
        '(${permissions.length} permissions)',
      );
    }
  }

  /// Ensure user document exists with role locked
  Future<void> _ensureUserDocument(String uid, String role) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        // ATOMIC WRITE - merge: false to prevent overwrite
        await userRef.set({
          'uid': uid,
          'role': role,
          'roleLocked': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[SessionManager] Created user doc with role: $role');
      } else if (doc.data()?['role'] == null) {
        // Update only if role is missing
        await userRef.update({
          'role': role,
          'roleLocked': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[SessionManager] Updated user doc with role: $role');
      }

      // Cache role locally
      await _cacheRole(uid, role);
    } catch (e) {
      debugPrint('[SessionManager] Error ensuring user document: $e');
    }
  }

  // ============================================
  // REAL-TIME ROLE CHANGE LISTENER
  // ============================================

  /// Subscribe to real-time role changes for the current user.
  ///
  /// Uses Firestore snapshots() on the business_users document to detect
  /// when an owner changes the user's role. On change:
  /// - Updates session staffRole and staffPermissions
  /// - Calls notifyListeners() so AuthGate, sidebar, PermissionGuard rebuild
  ///
  /// Firestore snapshots auto-reconnect when the device comes back online,
  /// so offline cached role is used while offline and the listener resumes
  /// when connectivity returns (preservation requirement).
  void _subscribeToRoleChanges(String uid, {String? businessId}) {
    // Cancel any existing subscription before creating a new one
    _roleChangeSubscription?.cancel();
    _roleChangeSubscription = null;

    final effectiveBusinessId = businessId ?? currentBusinessId;
    if (effectiveBusinessId == null || effectiveBusinessId.isEmpty) {
      debugPrint(
        '[SessionManager] Cannot subscribe to role changes: no businessId',
      );
      return;
    }

    final roleService = RoleManagementService(firestore: _firestore);
    _roleChangeSubscription = roleService
        .watchBusinessUser(effectiveBusinessId, uid)
        .listen(
          (businessUser) {
            _handleRoleChange(businessUser, uid);
          },
          onError: (error) {
            // Graceful error handling — do not disrupt session
            debugPrint('[SessionManager] Role change listener error: $error');
          },
        );

    debugPrint(
      '[SessionManager] Subscribed to role changes: '
      '${effectiveBusinessId}_$uid',
    );
  }

  /// Handle a role change event from the Firestore listener.
  void _handleRoleChange(BusinessUser? businessUser, String uid) {
    final currentStaffRole = _currentSession.staffRole;

    if (businessUser == null) {
      // Option 4: Document deleted. For a STAFF member this is an explicit
      // owner intent to remove access — REVOKE it (sign out) instead of
      // escalating to owner. A genuine owner (currentStaffRole == owner) or an
      // unresolved role is never logged out here.
      if (shouldRevokeOnRemoval(currentStaffRole)) {
        _revokeAccess('Staff role document deleted (was $currentStaffRole)');
      } else {
        debugPrint(
          '[SessionManager] Role document deleted — no action '
          '(currentStaffRole=$currentStaffRole)',
        );
      }
      return;
    }

    // Option 4: If the assignment is deactivated, REVOKE staff access rather
    // than promoting to owner. Checked BEFORE the role-equality short-circuit
    // so a deactivation with an otherwise-unchanged role still revokes.
    if (!businessUser.isActive) {
      if (shouldRevokeOnRemoval(currentStaffRole)) {
        _revokeAccess('Staff member deactivated (was $currentStaffRole)');
      } else {
        debugPrint(
          '[SessionManager] User deactivated — no action '
          '(currentStaffRole=$currentStaffRole)',
        );
      }
      return;
    }

    final newRole = businessUser.role;

    // Only update if role actually changed
    if (newRole == currentStaffRole) return;

    // Role changed — update session with new role and permissions
    final newPermissions = RolePermissions.getPermissions(newRole);
    _currentSession = _currentSession.copyWith(
      staffRole: newRole,
      staffPermissions: newPermissions,
    );
    _cacheRole(uid, newRole.name);

    debugPrint(
      '[SessionManager] Real-time role change detected: '
      '$currentStaffRole → $newRole (${newPermissions.length} permissions)',
    );

    // Notify all listeners (AuthGate, sidebar, PermissionGuard will rebuild)
    notifyListeners();
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      // Cancel role change listener
      _roleChangeSubscription?.cancel();
      _roleChangeSubscription = null;

      // Clear cached role
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kRoleKey);
        await prefs.remove(_kUserIdKey);
      } catch (_) {}

      await _auth.signOut();
      _currentSession = UserSession.empty;
      _availableRoles = null;
      _roleSelected = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionManager] Error signing out: $e');
      rethrow;
    }
  }

  /// Dev Bypass Login - Forces a mock session for testing
  Future<void> devBypassLogin() async {
    _currentSession = UserSession(
      odId: 'dev-admin-id',
      email: 'admin@myvyaparmitra.com',
      displayName: 'Dev Admin',
      role: UserRole.owner,
      ownerId: 'dev-admin-id',
      lastLoginAt: DateTime.now(),
    );
    _isInitialized = true;
    notifyListeners();
  }

  /// Dev Bypass Customer Login - Forces a mock staff session for testing
  /// (Legacy: was customer, now maps to staff for vendor-only app)
  Future<void> devBypassCustomerLogin() async {
    _currentSession = UserSession(
      odId: 'dev-staff-id',
      email: 'staff@myvyaparmitra.com',
      displayName: 'Dev Staff',
      role: UserRole.staff,
      ownerId: 'dev-admin-id',
      lastLoginAt: DateTime.now(),
    );
    _isInitialized = true;
    notifyListeners();
  }

  /// Switch active shop context (legacy customer feature — now no-op in vendor-only)
  Future<void> switchShop(String newOwnerId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Update active business context
      _currentSession = _currentSession.copyWith(ownerId: newOwnerId);

      debugPrint('[SessionManager] Switched shop context to: $newOwnerId');
    } catch (e) {
      debugPrint('[SessionManager] Error switching shop: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh current session
  Future<void> refreshSession() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _loadUserSession(user);
    }
  }

  /// Update session metadata
  void updateMetadata(Map<String, dynamic> metadata) {
    _currentSession = _currentSession.copyWith(
      metadata: {...?_currentSession.metadata, ...metadata},
    );
    // If business type changed in metadata, update session
    if (metadata.containsKey('businessType')) {
      _currentSession = _currentSession.copyWith(
        businessType: _parseBusinessType(metadata['businessType']),
      );
    }
    notifyListeners();
  }

  /// PHASE 1 FIX B: Programmatic business-type setter.
  ///
  /// The Riverpod `businessTypeProvider` is the persisted source of truth for
  /// the selected business type (it writes SharedPreferences 'business_type').
  /// But several modules (LicenseGuard via AuthGate, Inventory's
  /// product_management_screen / add_edit_product_sheet) read
  /// `activeBusinessType` off this SessionManager. Previously, switching
  /// business type updated the provider but NOT this session, so those
  /// modules showed stale fields/units/license checks after a switch.
  ///
  /// This setter is called by `BusinessTypeNotifier.setBusinessType` so both
  /// stores stay in sync. It is intentionally a separate method (not folded
  /// into `updateMetadata`) so the Phase 0 trace remains explicit.
  void setBusinessType(BusinessType type) {
    if (_currentSession.businessType == type) return;
    _currentSession = _currentSession.copyWith(businessType: type);
    debugPrint('[SessionManager] Business type set: ${type.name}');
    notifyListeners();
  }

  /// Get the active Business Type (defaults to Grocery if unknown)
  BusinessType get activeBusinessType =>
      _currentSession.businessType ?? BusinessType.grocery;

  // Helper to parse business type string
  BusinessType _parseBusinessType(dynamic value) {
    if (value == null) return BusinessType.grocery;
    final str = value.toString().toLowerCase();
    for (final type in BusinessType.values) {
      if (type.name.toLowerCase() == str) return type;
    }
    return BusinessType.grocery;
  }

  /// Check if user has permission for owner-only features
  bool hasOwnerPermission() => isOwner;

  /// Parse a role string into a [UserRole].
  static UserRole _parseRoleString(String roleStr) {
    switch (roleStr) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'staff':
      case 'cashier':
        return UserRole.staff;
      case 'accountant':
        return UserRole.accountant;
      case 'pharmacist':
        return UserRole.pharmacist;
      case 'waiter':
        return UserRole.waiter;
      case 'chef':
        return UserRole.chef;
      case 'captain':
        return UserRole.captain;
      case 'doctor':
        return UserRole.doctor;
      case 'receptionist':
        return UserRole.receptionist;
      case 'nurse':
        return UserRole.nurse;
      default:
        return UserRole.unknown;
    }
  }

  /// Get Firestore path prefix for current user
  String get userCollectionPath {
    if (isOwner) {
      return 'owners/$ownerId';
    }
    // For staff roles, use same owner path with their linked ownerId
    return 'owners/$ownerId';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _roleChangeSubscription?.cancel();
    _roleChangeSubscription = null;
    super.dispose();
  }
}
