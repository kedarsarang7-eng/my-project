// Login Onboarding - Intro screens for login flow
// Explains benefits of logging in (Cloud Sync, Multi-device, etc.)
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';
import '../../core/repository/user_repository.dart';
import '../dashboard/presentation/screens/owner_dashboard_screen.dart';

import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Service to manage login onboarding state
class LoginOnboardingService {
  static final LoginOnboardingService _instance =
      LoginOnboardingService._internal();
  factory LoginOnboardingService() => _instance;
  LoginOnboardingService._internal();

  /// Check if user has seen login onboarding
  Future<bool> hasSeenLoginOnboarding() async {
    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null || userId.isEmpty) return true; // Skip if no user

      final result = await sl<UserRepository>().getUser(userId);
      if (result.isFailure || result.data == null) return false; // New user

      return result.data?.hasSeenLoginOnboarding == true;
    } catch (e) {
      debugPrint('LoginOnboardingService: Error checking status: $e');
      return true; // On error, skip onboarding to not block user
    }
  }

  /// Mark login onboarding as seen
  Future<void> markOnboardingSeen() async {
    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null || userId.isEmpty) return;

      await sl<UserRepository>().markLoginOnboardingSeen(userId);
      debugPrint('LoginOnboardingService: Marked as seen for user $userId');
    } catch (e) {
      debugPrint('LoginOnboardingService: Error marking seen: $e');
      // Don't throw - user should proceed to dashboard
    }
  }
}

/// Main Login Onboarding Screen
class LoginOnboardingScreen extends StatefulWidget {
  const LoginOnboardingScreen({super.key});

  @override
  State<LoginOnboardingScreen> createState() => _LoginOnboardingScreenState();
}

class _LoginOnboardingScreenState extends State<LoginOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final LoginOnboardingService _service = LoginOnboardingService();

  int _currentPage = 0;
  bool _isNavigating = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _skipOnboarding() async {
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      await _service.markOnboardingSeen();
    } catch (e) {
      debugPrint('Error completing login onboarding: $e');
    }

    if (!mounted) return;
    _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ProfessionalOwnerDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: FuturisticColors.lightBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BoundedBox(
          maxWidth: 800,
          child: SafeArea(
          child: Column(
            children: [
              // Top bar with skip button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page indicators
                    Row(
                      children: List.generate(3, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          width: _currentPage == index ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? FuturisticColors.primary
                                : FuturisticColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      }),
                    ),
                    // Skip button
                    if (_currentPage < 2)
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: AppTypography.bodyMedium.copyWith(
                            color: FuturisticColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    HapticFeedback.selectionClick();
                    // Restart animations
                    _fadeController.reset();
                    _slideController.reset();
                    _fadeController.forward();
                    _slideController.forward();
                  },
                  children: [
                    _WelcomeScreen(
                      fadeController: _fadeController,
                      slideController: _slideController,
                      onNext: _nextPage,
                    ),
                    _FeaturesScreen(
                      fadeController: _fadeController,
                      slideController: _slideController,
                      onNext: _nextPage,
                    ),
                    _GetStartedScreen(
                      fadeController: _fadeController,
                      slideController: _slideController,
                      onComplete: _completeOnboarding,
                      isNavigating: _isNavigating,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Screen 1: Welcome
class _WelcomeScreen extends StatelessWidget {
  final AnimationController fadeController;
  final AnimationController slideController;
  final VoidCallback onNext;

  const _WelcomeScreen({
    required this.fadeController,
    required this.slideController,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: slideController, curve: Curves.easeOut),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FuturisticColors.primary,
                      FuturisticColors.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: FuturisticColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'DX',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(context,
                    mobile: 32.0,
                    tablet: 32.0,
                    desktop: 48.0,  // PRESERVED: Desktop uses exactly 48 as before
                  ),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title
              Text(
                'Welcome to DukanX',
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Your complete business\nmanagement solution',
                style: AppTypography.bodyLarge.copyWith(
                  color: FuturisticColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 64),

              // Next button
              SizedBox(
                width: double.infinity,
                child: EnterpriseButton(
                  onPressed: onNext,
                  label: 'Next',
                  backgroundColor: FuturisticColors.primary,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 2: Features
class _FeaturesScreen extends StatelessWidget {
  final AnimationController fadeController;
  final AnimationController slideController;
  final VoidCallback onNext;

  const _FeaturesScreen({
    required this.fadeController,
    required this.slideController,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: slideController, curve: Curves.easeOut),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'Powerful Features',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Everything you need to run your business',
                style: AppTypography.bodyMedium.copyWith(
                  color: FuturisticColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Feature cards
              _FeatureCard(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF22C55E),
                title: 'Smart Billing',
                subtitle: 'Create professional invoices in seconds',
              ),

              const SizedBox(height: 20),

              _FeatureCard(
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF3B82F6),
                title: 'Stock Management',
                subtitle: 'Track inventory with real-time updates',
              ),

              const SizedBox(height: 20),

              _FeatureCard(
                icon: Icons.insights_rounded,
                color: const Color(0xFFF59E0B),
                title: 'AI Reports',
                subtitle: 'Get smart insights about your business',
              ),

              const SizedBox(height: 48),

              // Next button
              SizedBox(
                width: double.infinity,
                child: EnterpriseButton(
                  onPressed: onNext,
                  label: 'Next',
                  backgroundColor: FuturisticColors.success,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feature card widget
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),

          const SizedBox(width: 16),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 3: Get Started
class _GetStartedScreen extends StatelessWidget {
  final AnimationController fadeController;
  final AnimationController slideController;
  final VoidCallback onComplete;
  final bool isNavigating;

  const _GetStartedScreen({
    required this.fadeController,
    required this.slideController,
    required this.onComplete,
    required this.isNavigating,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: slideController, curve: Curves.easeOut),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: FuturisticColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FuturisticColors.success.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title
              Text(
                "You're all set! 🚀",
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Start managing your business\nlike a pro',
                style: AppTypography.bodyLarge.copyWith(
                  color: FuturisticColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 64),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: EnterpriseButton(
                  onPressed: isNavigating ? () {} : onComplete,
                  label: isNavigating ? 'Loading...' : 'Continue to Dashboard',
                  icon: isNavigating ? null : Icons.check_circle,
                  backgroundColor:
                      FuturisticColors.error, // Orange for call to action
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
