// ============================================================================
// ACCESS CONTROL SERVICE
// ============================================================================
// Unified permission checking service with caching and audit logging.
// Provides both userId-based (legacy) and session-based (new) permission APIs.
//
// Session-integrated API (preferred):
//   - canPerform(Permission) → reads effectiveRole from SessionManager
//   - enforcePermission(Permission) → throws AccessDeniedException if denied
//
// Legacy API (backward-compatible):
//   - hasPermission(userId, Permission) → checks role cache
//   - checkPermission(...) → checks + logs denial
// ============================================================================

import 'package:flutter/foundation.dart';

import '../repository/audit_repository.dart';
import '../session/session_manager.dart';
import '../security/services/fraud_detection_service.dart';

/// Access Control Service - Unified permission and role management.
///
/// Features:
/// - Session-integrated permission checking (canPerform / enforcePermission)
/// - Permission checking with role-based access (legacy userId-based)
/// - Role abuse detection and logging
/// - Business-specific access control
/// - Audit trail for permission denials
class AccessControlService {
  final SessionManager _sessionManager;
  final AuditRepository _auditRepository;
  final FraudDetectionService? _fraudService;

  /// Cache of user roles by userId (legacy support)
  final Map<String, UserRole> _roleCache = {};

  AccessControlService({
    required SessionManager sessionManager,
    required AuditRepository auditRepository,
    FraudDetectionService? fraudService,
  }) : _sessionManager = sessionManager,
       _auditRepository = auditRepository,
       _fraudService = fraudService;

  // ==========================================================================
  // SESSION-INTEGRATED API (preferred for CRUD enforcement)
  // ==========================================================================

  /// Check if the current user can perform the given action.
  ///
  /// Reads the effective role from [SessionManager.currentSession] and
  /// evaluates against [RolePermissions.hasPermission].
  ///
  /// Returns `true` if allowed, `false` if denied.
  bool canPerform(Permission action) {
    final session = _sessionManager.currentSession;
    if (!session.isAuthenticated) return false;

    final effectiveRole = session.effectiveRole;

    // Owner always has full access
    if (effectiveRole == UserRole.owner) return true;

    return RolePermissions.hasPermission(effectiveRole, action);
  }

  /// Enforce that the current user has permission for the given action.
  ///
  /// Reads the effective role from [SessionManager.currentSession].
  /// Throws [AccessDeniedException] if the user does not have the permission.
  /// Also logs the denial for audit purposes.
  Future<void> enforcePermission(Permission action) async {
    if (canPerform(action)) return;

    final session = _sessionManager.currentSession;
    final effectiveRole = session.effectiveRole;

    // Log the denial
    await _logPermissionDenial(
      userId: session.odId,
      businessId: session.activeBusinessId ?? session.ownerId ?? '',
      permission: action,
      role: effectiveRole,
      context: 'enforcePermission',
    );

    // Check for potential role abuse
    await _fraudService?.checkRoleAbuseAttempt(
      businessId: session.activeBusinessId ?? session.ownerId ?? '',
      userId: session.odId,
      attemptedAction: action.name,
      userRole: effectiveRole.name,
    );

    throw AccessDeniedException(permission: action, role: effectiveRole);
  }

  /// Synchronous enforcement — throws immediately without logging.
  ///
  /// Use when async logging is not possible (e.g., in synchronous builders).
  /// Prefer [enforcePermission] when async is available.
  void enforcePermissionSync(Permission action) {
    if (canPerform(action)) return;

    final session = _sessionManager.currentSession;
    throw AccessDeniedException(
      permission: action,
      role: session.effectiveRole,
    );
  }

  // ==========================================================================
  // LEGACY USER-ID BASED API (backward-compatible)
  // ==========================================================================

  /// Check if user has a specific permission (by userId cache)
  bool hasPermission(String userId, Permission permission) {
    final role = _roleCache[userId];
    if (role == null) {
      debugPrint('AccessControlService: No role cached for user $userId');
      return false;
    }
    return RolePermissions.hasPermission(role, permission);
  }

  /// Check permission and log denial if not authorized
  Future<bool> checkPermission({
    required String userId,
    required String businessId,
    required Permission permission,
    String? context,
  }) async {
    final role = _roleCache[userId] ?? UserRole.unknown;
    final hasAccess = RolePermissions.hasPermission(role, permission);

    if (!hasAccess) {
      await _logPermissionDenial(
        userId: userId,
        businessId: businessId,
        permission: permission,
        role: role,
        context: context,
      );

      await _fraudService?.checkRoleAbuseAttempt(
        businessId: businessId,
        userId: userId,
        attemptedAction: permission.name,
        userRole: role.name,
      );
    }

    return hasAccess;
  }

  /// Set user role (from auth/login)
  void setUserRole(String userId, UserRole role) {
    _roleCache[userId] = role;
    debugPrint('AccessControlService: Set role for $userId to ${role.name}');
  }

  /// Get user role
  UserRole? getUserRole(String userId) => _roleCache[userId];

  /// Check if user is owner
  bool isOwner(String userId) {
    return _roleCache[userId] == UserRole.owner;
  }

  /// Check if user is accountant (CA Safe Mode)
  bool isAccountant(String userId) {
    return _roleCache[userId] == UserRole.accountant;
  }

  /// Check if user can modify data (not read-only)
  bool canModify(String userId) {
    final role = _roleCache[userId];
    return role != null && role != UserRole.unknown;
  }

  /// Check multiple permissions (any)
  bool hasAnyPermission(String userId, List<Permission> permissions) {
    return permissions.any((p) => hasPermission(userId, p));
  }

  /// Check multiple permissions (all)
  bool hasAllPermissions(String userId, List<Permission> permissions) {
    return permissions.every((p) => hasPermission(userId, p));
  }

  /// Get all permissions for a user
  Set<Permission> getUserPermissions(String userId) {
    final role = _roleCache[userId];
    if (role == null) return {};
    return RolePermissions.getPermissions(role);
  }

  /// Clear cache for user (on logout)
  void clearUserCache(String userId) {
    _roleCache.remove(userId);
  }

  /// Clear all cache
  void clearAllCache() {
    _roleCache.clear();
  }

  // ==========================================================================
  // INTERNAL
  // ==========================================================================

  Future<void> _logPermissionDenial({
    required String userId,
    required String businessId,
    required Permission permission,
    required UserRole role,
    String? context,
  }) async {
    try {
      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'permission_denial',
        recordId: businessId,
        action: 'DENIED',
        newValueJson:
            '''{
          "permission": "${permission.name}",
          "role": "${role.name}",
          "context": ${context != null ? '"$context"' : 'null'}
        }''',
      );
    } catch (e) {
      debugPrint('AccessControlService: Failed to log denial: $e');
    }
  }
}

/// Exception thrown when a permission check fails.
///
/// Contains the [permission] that was denied and the [role] that attempted it.
class AccessDeniedException implements Exception {
  final Permission permission;
  final UserRole role;
  final String? message;

  AccessDeniedException({
    required this.permission,
    required this.role,
    this.message,
  });

  @override
  String toString() =>
      'AccessDeniedException: Role [${role.name}] '
      'cannot perform [${permission.name}]'
      '${message != null ? ' — $message' : ''}';
}

/// Legacy alias for backward compatibility
typedef PermissionDeniedException = AccessDeniedException;
