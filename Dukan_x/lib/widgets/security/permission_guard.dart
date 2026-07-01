// ============================================================================
// PERMISSION GUARD WIDGET
// ============================================================================
// Widget wrapper for permission-based UI control.
// Hides or disables UI elements based on user permissions.
//
// Includes "Connected" variants that auto-read the current user role
// from SessionManager via the service locator, eliminating the need for
// callers to manually pass userRole.
// ============================================================================

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';

/// Permission Guard - UI-level permission enforcement.
///
/// Wraps child widgets and controls visibility/enablement based on
/// the current user's role and permissions.
///
/// Usage:
/// ```dart
/// PermissionGuard(
///   permission: Permission.deleteBill,
///   child: IconButton(
///     icon: Icon(Icons.delete),
///     onPressed: _deleteBill,
///   ),
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  /// The permission required to show/enable the child
  final Permission permission;

  /// The child widget to conditionally show
  final Widget child;

  /// Widget to show when permission is denied (optional)
  /// If null, child is hidden entirely
  final Widget? deniedChild;

  /// Current user's role (required for checking permissions)
  final UserRole userRole;

  /// Whether to disable instead of hide when permission denied
  /// Default: false (hides the widget)
  final bool disableWhenDenied;

  /// Callback when unauthorized action is attempted
  final VoidCallback? onUnauthorizedAttempt;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    required this.userRole,
    this.deniedChild,
    this.disableWhenDenied = false,
    this.onUnauthorizedAttempt,
  });

  /// Quick check if current role has permission
  bool get hasPermission => RolePermissions.hasPermission(userRole, permission);

  @override
  Widget build(BuildContext context) {
    if (hasPermission) {
      return child;
    }

    // Permission denied
    if (disableWhenDenied) {
      return _buildDisabledChild(context);
    }

    if (deniedChild != null) {
      return deniedChild!;
    }

    // Hide completely
    return const SizedBox.shrink();
  }

  Widget _buildDisabledChild(BuildContext context) {
    // Wrap in IgnorePointer and reduce opacity
    return GestureDetector(
      onTap:
          onUnauthorizedAttempt ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You don\'t have permission for: ${permission.name}',
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
      child: IgnorePointer(child: Opacity(opacity: 0.4, child: child)),
    );
  }
}

/// Permission Gate - Alternative widget for larger sections
///
/// Shows an access denied message for entire sections.
class PermissionGate extends StatelessWidget {
  /// The permission required to access this section
  final Permission permission;

  /// The protected content
  final Widget child;

  /// Current user's role
  final UserRole userRole;

  /// Custom message when access denied
  final String? deniedMessage;

  /// Custom icon when access denied
  final IconData? deniedIcon;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    required this.userRole,
    this.deniedMessage,
    this.deniedIcon,
  });

  bool get hasPermission => RolePermissions.hasPermission(userRole, permission);

  @override
  Widget build(BuildContext context) {
    if (hasPermission) {
      return child;
    }

    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              deniedIcon ?? Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              deniedMessage ?? 'Access Restricted',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have permission to access this section.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-Permission Guard - Requires any/all of multiple permissions
class MultiPermissionGuard extends StatelessWidget {
  /// List of permissions to check
  final List<Permission> permissions;

  /// Require ALL permissions (true) or ANY permission (false)
  final bool requireAll;

  /// The child widget
  final Widget child;

  /// Current user's role
  final UserRole userRole;

  /// Widget when denied
  final Widget? deniedChild;

  const MultiPermissionGuard({
    super.key,
    required this.permissions,
    this.requireAll = false,
    required this.child,
    required this.userRole,
    this.deniedChild,
  });

  bool get hasPermission {
    if (requireAll) {
      return permissions.every(
        (p) => RolePermissions.hasPermission(userRole, p),
      );
    } else {
      return permissions.any((p) => RolePermissions.hasPermission(userRole, p));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hasPermission) {
      return child;
    }

    return deniedChild ?? const SizedBox.shrink();
  }
}

/// Role Guard - Requires specific role(s)
class RoleGuard extends StatelessWidget {
  /// Allowed roles
  final List<UserRole> allowedRoles;

  /// The child widget
  final Widget child;

  /// Current user's role
  final UserRole userRole;

  /// Widget when role not allowed
  final Widget? deniedChild;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    required this.userRole,
    this.deniedChild,
  });

  bool get hasAccess => allowedRoles.contains(userRole);

  @override
  Widget build(BuildContext context) {
    if (hasAccess) {
      return child;
    }

    return deniedChild ?? const SizedBox.shrink();
  }
}

/// Owner Only Guard - Quick shorthand for owner-only features
class OwnerOnlyGuard extends StatelessWidget {
  final Widget child;
  final UserRole userRole;
  final Widget? deniedChild;

  const OwnerOnlyGuard({
    super.key,
    required this.child,
    required this.userRole,
    this.deniedChild,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [UserRole.owner],
      userRole: userRole,
      deniedChild: deniedChild,
      child: child,
    );
  }
}

// ============================================================================
// CONNECTED VARIANTS — Auto-read role from SessionManager
// ============================================================================
// These convenience wrappers eliminate the need to manually pass `userRole`.
// They read the current session's effectiveRole via service locator and react
// to session changes using ListenableBuilder (SessionManager is ChangeNotifier).
//
// The original explicit-userRole widgets above remain unchanged for backward
// compatibility with existing callers.
// ============================================================================

/// Connected Permission Guard — auto-reads role from session.
///
/// Delegates to [PermissionGuard] with the resolved [UserRole] from
/// [SessionManager.currentSession.effectiveRole].
///
/// Usage:
/// ```dart
/// PermissionGuardConnected(
///   permission: Permission.deleteBill,
///   child: IconButton(icon: Icon(Icons.delete), onPressed: _deleteBill),
/// )
/// ```
class PermissionGuardConnected extends StatelessWidget {
  /// The permission required to show/enable the child
  final Permission permission;

  /// The child widget to conditionally show
  final Widget child;

  /// Widget to show when permission is denied (optional)
  final Widget? deniedChild;

  /// Whether to disable instead of hide when permission denied
  final bool disableWhenDenied;

  /// Callback when unauthorized action is attempted
  final VoidCallback? onUnauthorizedAttempt;

  const PermissionGuardConnected({
    super.key,
    required this.permission,
    required this.child,
    this.deniedChild,
    this.disableWhenDenied = false,
    this.onUnauthorizedAttempt,
  });

  @override
  Widget build(BuildContext context) {
    final sessionManager = sl<SessionManager>();
    return ListenableBuilder(
      listenable: sessionManager,
      builder: (context, _) {
        final role = sessionManager.currentSession.effectiveRole;
        return PermissionGuard(
          permission: permission,
          userRole: role,
          deniedChild: deniedChild,
          disableWhenDenied: disableWhenDenied,
          onUnauthorizedAttempt: onUnauthorizedAttempt,
          child: child,
        );
      },
    );
  }
}

/// Connected Permission Gate — auto-reads role from session.
///
/// Delegates to [PermissionGate] with the resolved [UserRole] from
/// [SessionManager.currentSession.effectiveRole].
///
/// Shows an access-denied message for entire sections when permission
/// is not granted.
class PermissionGateConnected extends StatelessWidget {
  /// The permission required to access this section
  final Permission permission;

  /// The protected content
  final Widget child;

  /// Custom message when access denied
  final String? deniedMessage;

  /// Custom icon when access denied
  final IconData? deniedIcon;

  const PermissionGateConnected({
    super.key,
    required this.permission,
    required this.child,
    this.deniedMessage,
    this.deniedIcon,
  });

  @override
  Widget build(BuildContext context) {
    final sessionManager = sl<SessionManager>();
    return ListenableBuilder(
      listenable: sessionManager,
      builder: (context, _) {
        final role = sessionManager.currentSession.effectiveRole;
        return PermissionGate(
          permission: permission,
          userRole: role,
          deniedMessage: deniedMessage,
          deniedIcon: deniedIcon,
          child: child,
        );
      },
    );
  }
}

/// Connected Multi-Permission Guard — auto-reads role from session.
///
/// Delegates to [MultiPermissionGuard] with the resolved [UserRole] from
/// [SessionManager.currentSession.effectiveRole].
class MultiPermissionGuardConnected extends StatelessWidget {
  /// List of permissions to check
  final List<Permission> permissions;

  /// Require ALL permissions (true) or ANY permission (false)
  final bool requireAll;

  /// The child widget
  final Widget child;

  /// Widget when denied
  final Widget? deniedChild;

  const MultiPermissionGuardConnected({
    super.key,
    required this.permissions,
    this.requireAll = false,
    required this.child,
    this.deniedChild,
  });

  @override
  Widget build(BuildContext context) {
    final sessionManager = sl<SessionManager>();
    return ListenableBuilder(
      listenable: sessionManager,
      builder: (context, _) {
        final role = sessionManager.currentSession.effectiveRole;
        return MultiPermissionGuard(
          permissions: permissions,
          requireAll: requireAll,
          userRole: role,
          deniedChild: deniedChild,
          child: child,
        );
      },
    );
  }
}
