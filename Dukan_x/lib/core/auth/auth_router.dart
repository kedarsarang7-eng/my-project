// ============================================================================
// AUTH ROUTER - CENTRALIZED NAVIGATION CONTROLLER
// ============================================================================
// Single point of truth for auth-based routing.
// Ensures ZERO wrong dashboard frames.
//
// Usage: Wrap your MaterialApp home with AuthRouter
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:go_router/go_router.dart';

import 'package:dukanx/core/routing/route_paths.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';
import 'auth_intent_service.dart';

import '../../components/auth/login_page.dart';
import '../../features/dashboard/presentation/screens/dashboard_controller.dart';
import '../../features/customers/presentation/screens/customer_home_screen.dart';
import '../../features/patient/presentation/screens/patient_home_screen.dart';

/// AuthRouter - Decides which screen to show based on auth state
class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _determineRoute();
  }

  Future<void> _determineRoute() async {
    try {
      // Initialize auth intent service
      await authIntent.initialize();

      // Check Firebase auth state
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // No user logged in → show Login Page directly
        debugPrint('[AuthRouter] No user found, showing Login Page');
        _setTarget(const LoginPage());
        return;
      }

      // User exists → validate role
      final session = sl<SessionManager>();

      // Wait for session to load if not ready
      if (!session.isInitialized) {
        await session.refreshSession();
      }

      // Determine correct dashboard
      if (session.isOwner) {
        debugPrint('[AuthRouter] User is VENDOR, routing to VendorDashboard');
        _setTarget(const DashboardController());
      } else if (session.isCustomer) {
        debugPrint('[AuthRouter] User is CUSTOMER, routing to CustomerPortal');
        _setTarget(CustomerHomeScreen(customerId: session.userId ?? ''));
      } else if (session.isPatient) {
        debugPrint(
          '[AuthRouter] User is PATIENT, routing to PatientHomeScreen',
        );
        _setTarget(const PatientHomeScreen());
      } else {
        // Unknown role → clear and show LoginPage
        debugPrint('[AuthRouter] Unknown role, showing LoginPage');
        await session.signOut();
        _setTarget(const LoginPage());
      }
    } catch (e) {
      debugPrint('[AuthRouter] Error determining route: $e');
      _setTarget(const LoginPage());
    }
  }

  void _setTarget(Widget screen) {
    if (mounted) {
      setState(() {
        _targetScreen = screen;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0D1F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    return _targetScreen ?? const LoginPage();
  }
}

/// Role-based route guard widget
/// Wraps screens that require specific role access
class RoleGuard extends StatelessWidget {
  final Widget child;
  final bool requireVendor;
  final bool requireCustomer;

  const RoleGuard({
    super.key,
    required this.child,
    this.requireVendor = false,
    this.requireCustomer = false,
  });

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();

    // Check role requirements
    if (requireVendor && !session.isOwner) {
      return _AccessDeniedScreen(
        message: 'Vendor access required.',
        onBack: () => context.pushReplacement(RoutePaths.authGate),
      );
    }

    if (requireCustomer && !session.isCustomer) {
      return _AccessDeniedScreen(
        message: 'Customer access required.',
        onBack: () => context.pushReplacement(RoutePaths.authGate),
      );
    }

    return child;
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _AccessDeniedScreen({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onBack, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}
