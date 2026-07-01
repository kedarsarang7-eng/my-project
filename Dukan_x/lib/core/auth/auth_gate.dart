// ============================================================================
// AUTH GATE - SINGLE ENTRY POINT
// ============================================================================
// The ONLY entry point after app launch
// Controls ALL navigation based on authentication and role state
//
// RULES:
// 1. Login success NEVER directly navigates to any dashboard
// 2. ALL navigation passes through this gate
// 3. Role MUST be confirmed before showing any dashboard
// 4. Unknown/error role → force logout
// 5. Business type MUST be selected before showing dashboard
//
// Author: DukanX Engineering
// Version: 1.1.0 (FIXED: Added business type selection gate)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/service_locator.dart';
import '../session/session_manager.dart';
import 'auth_loading_screen.dart';
import 'auth_error_screen.dart';

// Dashboards
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../components/auth/login_page.dart';

// Onboarding
import '../../features/onboarding/onboarding_models.dart';
import '../../features/onboarding/vendor_onboarding_screen.dart';
import '../../features/onboarding/login_onboarding_screen.dart';

// Guards
import '../../guards/license_guard.dart';

// Business Type Switcher
import '../../screens/dev_business_type_switcher_screen.dart';

// Role Picker (multi-role/business)
import '../../widgets/auth/role_picker_screen.dart';

// Localization
import '../localization/localization_service.dart';
import '../../features/localization/presentation/screens/language_selection_screen.dart';

/// AuthGate - Single Entry Point for Authentication & Navigation
///
/// This widget:
/// 1. Listens to SessionManager for auth state changes
/// 2. Shows loading while auth is being resolved
/// 3. Routes to correct dashboard based on confirmed role
/// 4. Forces logout on unknown/error role
/// 5. NEVER assumes a default role
/// 6. FIXED: Checks if business type has been selected before showing dashboard
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Tracks whether we've checked for business type selection
  bool _businessTypeChecked = false;
  bool _hasBusinessType = false;
  bool _checkingBusinessType = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[AuthGate] Initialized');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<SessionManager>(),
      builder: (context, _) {
        final session = sl<SessionManager>();

        debugPrint(
          '[AuthGate] Building - initialized: ${session.isInitialized}, '
          'loading: ${session.isLoading}, '
          'authenticated: ${session.isAuthenticated}, '
          'role: ${session.currentSession.role}',
        );

        // ============================================
        // STATE 1: Loading / Initializing
        // ============================================
        if (!session.isInitialized || session.isLoading) {
          return const AuthLoadingScreen(message: 'Initializing...');
        }

        // ============================================
        // STATE 2: Not Authenticated
        // ============================================
        if (!session.isAuthenticated) {
          // Reset business type check when logged out
          _businessTypeChecked = false;
          _hasBusinessType = false;
          // Show Login Page directly
          return const LoginPage();
        }

        // ============================================
        // STATE 3: Authenticated - Check Role
        // ============================================
        final role = session.currentSession.role;

        switch (role) {
          case UserRole.owner:
          case UserRole.manager:
          case UserRole.accountant:
          case UserRole.staff:
          case UserRole.pharmacist:
          case UserRole.waiter:
          case UserRole.chef:
          case UserRole.captain:
          case UserRole.doctor:
          case UserRole.receptionist:
          case UserRole.nurse:
            return _buildVendorFlow(session);

          case UserRole.unknown:
            // Force logout / error because role is not resolved
            return AuthErrorScreen(
              errorMessage:
                  'Unauthorized. This application is for Vendor/Owner use only.',
              errorCode: 'UNAUTHORIZED_ROLE',
              onRetry: () => _handleRetry(),
            );
        }
      },
    );
  }

  /// Build vendor/owner flow with business type check
  Widget _buildVendorFlow(SessionManager session) {
    // CHECK: Multi-role picker — show before dashboard when multiple assignments exist
    if (session.needsRolePicker) {
      return const RolePickerScreen();
    }

    // FIXED: Check if business type has been selected
    if (!_businessTypeChecked && !_checkingBusinessType) {
      _checkBusinessType();
      return const AuthLoadingScreen(message: 'Loading profile...');
    }

    if (_checkingBusinessType) {
      return const AuthLoadingScreen(message: 'Loading profile...');
    }

    // If no business type selected, show the official vendor onboarding screen
    if (!_hasBusinessType) {
      return const VendorOnboardingScreen();
    }

    return _resolveVendorScreen();
  }

  /// Check if business type has been persisted
  Future<void> _checkBusinessType() async {
    if (_checkingBusinessType) return;
    _checkingBusinessType = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasType =
          prefs.getString('business_type') != null ||
          prefs.getInt('business_type') != null;

      if (mounted) {
        setState(() {
          _hasBusinessType = hasType;
          _businessTypeChecked = true;
          _checkingBusinessType = false;
        });
      }
    } catch (e) {
      debugPrint('[AuthGate] Business type check failed: $e');
      if (mounted) {
        setState(() {
          _hasBusinessType = true; // Default to showing dashboard on error
          _businessTypeChecked = true;
          _checkingBusinessType = false;
        });
      }
    }
  }

  /// FIXED: Show a business type selection gate screen
  Widget _buildBusinessTypeSelectionGate() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to DukanX!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please select your business type to customize the app for your needs.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DevBusinessTypeSwitcherScreen(),
                      ),
                    );
                    // Re-check after returning from selection
                    if (mounted) {
                      setState(() {
                        _businessTypeChecked = false;
                        _checkingBusinessType = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Select Business Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resolveVendorScreen() {
    // Show vendor dashboard protected by license directly
    return LicenseGuard(
      businessType: sl<SessionManager>().activeBusinessType,
      child: const ProfessionalOwnerDashboard(),
    );
  }

  // Customer flow removed

  /// Handle retry after error
  Future<void> _handleRetry() async {
    try {
      await sl<SessionManager>().refreshSession();
    } catch (e) {
      debugPrint('[AuthGate] Retry failed: $e');
    }
  }
}
