import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../services/session_service.dart';
import '../../../onboarding/onboarding_models.dart';
import '../../../onboarding/vendor_onboarding_screen.dart';
import '../../../onboarding/login_onboarding_screen.dart';
import 'owner_dashboard_screen.dart';
import '../../../customers/presentation/screens/customer_home_screen.dart';

/// Dashboard Controller
/// Routes users to the appropriate dashboard based on their role
/// Handles TWO separate onboarding flows:
/// 1. VendorOnboardingScreen - Business setup (for NEW account creation/signup)
/// 2. LoginOnboardingScreen - App intro (for FIRST login, separate from signup)
class DashboardController extends ConsumerStatefulWidget {
  const DashboardController({super.key});

  @override
  ConsumerState<DashboardController> createState() =>
      _DashboardControllerState();
}

enum _OnboardingState {
  checking,
  needsSignupOnboarding, // New account - needs business type + language setup
  needsLoginOnboarding, // First login - needs app intro onboarding
  complete, // All onboarding done - go to dashboard
}

class _DashboardControllerState extends ConsumerState<DashboardController> {
  _OnboardingState _state = _OnboardingState.checking;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final role = sessionService.getUserRole();

    // Only check onboarding for owners/vendors
    if (role == 'owner' || role == 'vendor') {
      // Check SIGNUP onboarding first (business type + language)
      final signupOnboardingService = OnboardingService();
      final isSignupOnboardingCompleted = await signupOnboardingService
          .isOnboardingCompleted();

      if (!isSignupOnboardingCompleted) {
        // New account needs signup onboarding (business setup)
        if (mounted) {
          setState(() {
            _state = _OnboardingState.needsSignupOnboarding;
          });
        }
        return;
      }

      // Signup onboarding is done, now check LOGIN onboarding (app intro)
      final loginOnboardingService = LoginOnboardingService();
      final hasSeenLoginOnboarding = await loginOnboardingService
          .hasSeenLoginOnboarding();

      if (!hasSeenLoginOnboarding) {
        // User hasn't seen the login intro screens
        if (mounted) {
          setState(() {
            _state = _OnboardingState.needsLoginOnboarding;
          });
        }
        return;
      }

      // All onboarding complete
      if (mounted) {
        setState(() {
          _state = _OnboardingState.complete;
        });
      }
    } else {
      // Customers don't need onboarding - go directly to dashboard
      if (mounted) {
        setState(() {
          _state = _OnboardingState.complete;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _OnboardingState.checking:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Setting up your account..."),
              ],
            ),
          ),
        );

      case _OnboardingState.needsSignupOnboarding:
        // NEW ACCOUNT - needs business type + language setup
        return const VendorOnboardingScreen();

      case _OnboardingState.needsLoginOnboarding:
        // FIRST LOGIN - needs app intro (Welcome, Features, Get Started)
        return const LoginOnboardingScreen();

      case _OnboardingState.complete:
        // All done - show dashboard
        return _buildDashboard(context);
    }
  }

  Widget _buildDashboard(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final role = sessionService.getUserRole();

    // Both 'owner' and 'vendor' roles should see the Owner Dashboard
    if (role == 'owner' || role == 'vendor') {
      if (settings.isOwnerDashboard) {
        return const ProfessionalOwnerDashboard();
      } else {
        // Owner/Vendor switched to Customer view
        return CustomerHomeScreen(customerId: sessionService.getUserId() ?? '');
      }
    } else {
      // Regular customer
      return CustomerHomeScreen(
        key: const ValueKey('customer_dashboard'),
        customerId: sessionService.getUserId() ?? '',
      );
    }
  }
}
