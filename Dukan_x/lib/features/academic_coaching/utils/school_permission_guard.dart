// ============================================================================
// SCHOOL PERMISSION GUARD — ROUTE PROTECTION FOR /ac/* ROUTES
// ============================================================================
// Guards that prevent unauthorized access to school-specific screens based on
// the scoped SchoolPermission layer.
//
// Replaces generic retail permission guards (viewInvoices, viewClients, etc.)
// for all /ac/* routes (Phase 3 — Requirement 6.3–6.7).
//
// Behavior:
// - A holder of the required SchoolPermission sees the child screen (6.4).
// - A non-holder is blocked, renders no part of the screen, is redirected to
//   the default authorized landing screen, and sees an access-denied
//   indication (6.5).
// - If no permission mapping is defined (null permission), access is denied
//   and the user is redirected (6.6).
// - Scoped to schoolErp routes only — no other business type is affected (6.7).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/auth/auth_loading_screen.dart';
import 'school_permissions.dart';

/// Guard that gates access to a school screen via [SchoolPermission].
///
/// Wraps the existing [VendorRoleGuard] pattern but checks
/// [hasSchoolPermission] against the user's effective role instead of
/// generic retail permissions.
///
/// Usage (inside a route builder, nested inside BusinessGuard):
/// ```dart
/// SchoolPermissionGuard(
///   permission: SchoolPermission.viewStudents,
///   child: const AcStudentsScreen(),
/// )
/// ```
class SchoolPermissionGuard extends StatelessWidget {
  /// The school-specific permission required to access the child screen.
  final SchoolPermission permission;

  /// The screen to render when the permission is held.
  final Widget child;

  const SchoolPermissionGuard({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<SessionManager>(),
      builder: (context, _) {
        final session = sl<SessionManager>();

        // Still loading — show loading indicator.
        if (session.isLoading || !session.isInitialized) {
          return const AuthLoadingScreen(message: 'Verifying access...');
        }

        // Not authenticated — redirect to splash.
        if (!session.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(message: 'Redirecting...');
        }

        // Not a vendor/owner — redirect to splash.
        if (!session.isOwner || session.isCustomerOnlyMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(
            message: 'Access denied. Redirecting...',
          );
        }

        // Check school-specific permission against effective role.
        final effectiveRole = session.currentSession.effectiveRole;
        final hasPermission = hasSchoolPermission(effectiveRole, permission);

        if (hasPermission) {
          // Authorized — render the child screen.
          return child;
        }

        // Access denied — redirect to the default authorized landing screen
        // and show an access-denied indication.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _showAccessDeniedSnackBar(context);
            context.go('/home');
          }
        });
        return const AuthLoadingScreen(
          message: 'Access denied. Redirecting...',
        );
      },
    );
  }

  /// Shows an access-denied snackbar indication.
  void _showAccessDeniedSnackBar(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Access denied: You do not have the "${permission.name}" permission for this school feature.',
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
