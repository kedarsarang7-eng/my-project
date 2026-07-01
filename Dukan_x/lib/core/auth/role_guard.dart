// ============================================================================
// ROLE GUARD - ROUTE PROTECTION
// ============================================================================
// Guards that prevent unauthorized access to role-specific screens
// Auto-redirects to AuthGate if role mismatch
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';
import 'auth_loading_screen.dart';

/// Guard that only allows vendor/owner role access
///
/// If user is not authenticated or not a vendor:
/// - Shows loading while checking
/// - Redirects to AuthGate for re-routing
class VendorRoleGuard extends StatelessWidget {
  final Widget child;
  final String? requiredPermission;

  const VendorRoleGuard({
    super.key,
    required this.child,
    this.requiredPermission,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<SessionManager>(),
      builder: (context, _) {
        final session = sl<SessionManager>();

        // Still loading
        if (session.isLoading || !session.isInitialized) {
          return const AuthLoadingScreen(message: 'Verifying access...');
        }

        // Not authenticated
        if (!session.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(message: 'Redirecting...');
        }

        // Not a vendor/owner OR App is in Customer Only Mode
        if (!session.isOwner || session.isCustomerOnlyMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(
            message: 'Access denied. Redirecting...',
          );
        }

        // Authorized
        return child;
      },
    );
  }
}

/// Guard that only allows customer role access
///
/// If user is not authenticated or not a customer:
/// - Shows loading while checking
/// - Redirects to AuthGate for re-routing
class CustomerRoleGuard extends StatelessWidget {
  final Widget child;

  const CustomerRoleGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<SessionManager>(),
      builder: (context, _) {
        final session = sl<SessionManager>();

        // Still loading
        if (session.isLoading || !session.isInitialized) {
          return const AuthLoadingScreen(message: 'Verifying access...');
        }

        // Not authenticated
        if (!session.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(message: 'Redirecting...');
        }

        // Not a customer
        if (!session.isCustomer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(
            message: 'Access denied. Redirecting...',
          );
        }

        // Authorized
        return child;
      },
    );
  }
}

/// Guard that requires any authenticated user (vendor OR customer)
class AuthenticatedGuard extends StatelessWidget {
  final Widget child;

  const AuthenticatedGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<SessionManager>(),
      builder: (context, _) {
        final session = sl<SessionManager>();

        // Still loading
        if (session.isLoading || !session.isInitialized) {
          return const AuthLoadingScreen(message: 'Verifying access...');
        }

        // Not authenticated
        if (!session.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RoutePaths.splash);
          });
          return const AuthLoadingScreen(message: 'Redirecting to login...');
        }

        // Authorized
        return child;
      },
    );
  }
}
