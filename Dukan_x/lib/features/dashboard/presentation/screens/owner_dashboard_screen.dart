import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers & Services
import '../../../../services/backup_service.dart';

// Onboarding
import '../../../onboarding/onboarding_models.dart';
import '../../../onboarding/vendor_onboarding_screen.dart';

// Desktop Hierarchy
import '../../../../core/responsive/adaptive_shell.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ProfessionalOwnerDashboard extends ConsumerStatefulWidget {
  const ProfessionalOwnerDashboard({super.key});

  @override
  ConsumerState<ProfessionalOwnerDashboard> createState() =>
      ProfessionalOwnerDashboardState();
}

class ProfessionalOwnerDashboardState
    extends ConsumerState<ProfessionalOwnerDashboard> {
  @override
  void initState() {
    super.initState();
    // Background services initialization
    BackupService().performAutoBackup();
    _checkOnboarding();
  }

  /// Check if onboarding needs to be shown (One-time check on mount)
  Future<void> _checkOnboarding() async {
    // Small delay to ensure SharedPreferences is synced
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    try {
      final onboardingService = OnboardingService();
      final isCompleted = await onboardingService.isOnboardingCompleted();

      if (!isCompleted && mounted) {
        // Navigate to onboarding
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const VendorOnboardingScreen();
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking onboarding: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return the new static shell. Use NavigationController for screen switching.
    return const AdaptiveShell();
  }
}
