// Vendor Onboarding Flow - Main Screen Controller
// 3-Step animated onboarding with business type, language, and congratulations
// Only shown to NEW users (first time login)
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'onboarding_models.dart';
import '../../models/business_type.dart';
import '../../core/di/service_locator.dart' hide sessionService;
import '../../core/services/logger_service.dart';
import '../../core/services/module_loader_service.dart';
import '../../services/session_service.dart';
import '../dashboard/v2/screens/dashboard_v2_screen.dart';

import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../generated/app_localizations.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VendorOnboardingScreen extends StatefulWidget {
  const VendorOnboardingScreen({super.key});

  @override
  State<VendorOnboardingScreen> createState() => _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();

  int _currentPage = 0;
  BusinessType? _selectedBusinessType;
  // Language selected globally via LocalizationService

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Ensure business type has a default
    _selectedBusinessType ??= BusinessType.grocery;
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      // Reduced from 2 to 1 (2 pages total: Business, Congrats)
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() async {
    // Set defaults
    if (_selectedBusinessType == null) {
      _selectedBusinessType = BusinessType.grocery;
      await _onboardingService.saveBusinessType(BusinessType.grocery);
    }
    await _onboardingService.completeOnboarding();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
    } catch (_) {}
    if (!mounted) return;
    _goToDashboard();
  }

  Future<void> _completeOnboarding() async {
    try {
      await _onboardingService.completeOnboarding();
    } catch (e) {
      // Log error but continue - don't block navigation
      LoggerService.d('VendorOnboarding', 'Error completing onboarding: $e');
    }
    // Persist flag locally so login flow knows onboarding is done
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
    } catch (_) {
      // Non-blocking — flag absence just re-shows onboarding on next cold start
    }
    if (!mounted) return;
    _goToDashboard();
  }

  void _goToDashboard() {
    context.go(RoutePaths.authGate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page indicator
                      Row(
                        children: List.generate(2, (index) {
                          // Reduced from 3 to 2
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      // Skip button
                      if (_currentPage < 1) // Only show on first page
                        TextButton(
                          onPressed: _skipOnboarding,
                          child: Text(
                            l10n?.onboarding_skip ?? 'Skip',
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
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      // Reset animations for new page
                      _fadeController.reset();
                      _slideController.reset();
                      _fadeController.forward();
                      _slideController.forward();
                    },
                    children: [
                      _BusinessTypeScreen(
                        selectedType: _selectedBusinessType,
                        onTypeSelected: (type) async {
                          setState(() => _selectedBusinessType = type);
                          HapticFeedback.mediumImpact();
                          await _onboardingService.saveBusinessType(type);
                        },
                        onContinue: _nextPage,
                        fadeAnimation: _fadeAnimation,
                        slideAnimation: _slideAnimation,
                      ),
                      _CongratulationsScreen(
                        businessType:
                            _selectedBusinessType ?? BusinessType.grocery,
                        onComplete: _completeOnboarding,
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

/// Step 1: Business Type Selection Screen with Swipeable Cards
class _BusinessTypeScreen extends StatefulWidget {
  final BusinessType? selectedType;
  final Function(BusinessType) onTypeSelected;
  final VoidCallback onContinue;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const _BusinessTypeScreen({
    required this.selectedType,
    required this.onTypeSelected,
    required this.onContinue,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  State<_BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<_BusinessTypeScreen> {
  late PageController _cardController;
  int _currentCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _cardController = PageController(viewportFraction: 0.75, initialPage: 0);
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Widget _buildCard(
    BusinessTypeConfig config,
    bool isSelected,
    bool isCurrent,
  ) {
    return AnimatedScale(
      scale: isCurrent
          ? (isSelected ? 1.03 : 1.0) // Selected cards pop slightly more
          : 0.88,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isCurrent ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          onTap: () => widget.onTypeSelected(config.type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              // Gradient background when selected
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        config.secondaryColor.withValues(alpha: 0.3),
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(
                isSelected ? 28 : 24, // More prominent corners when selected
              ),
              border: Border.all(
                color: isSelected ? config.primaryColor : Colors.grey.shade200,
                width: isSelected ? 3.5 : 1, // Thicker border when selected
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? config.primaryColor.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: isSelected ? 28 : 10,
                  spreadRadius: isSelected
                      ? 2
                      : 0, // Spread for elevation effect
                  offset: Offset(0, isSelected ? 10 : 6),
                ),
                if (isSelected)
                  BoxShadow(
                    color: config.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: -5,
                    offset: const Offset(0, 20),
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Main content column
                Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Business illustration/image placeholder
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 165 : 160,
                          height: isSelected ? 145 : 140,
                          decoration: BoxDecoration(
                            color: config.secondaryColor,
                            borderRadius: BorderRadius.circular(
                              isSelected ? 22 : 20,
                            ),
                            border: isSelected
                                ? Border.all(
                                    color: config.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background pattern
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    isSelected ? 20 : 18,
                                  ),
                                  child: _buildBusinessIllustration(config),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Business name with animated styling
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: isSelected ? 23 : 22,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.bold,
                            color: isSelected
                                ? config.primaryColor
                                : FuturisticColors.textPrimary,
                          ),
                          child: Text(config.name, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            config.description,
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 13,
                              color: isSelected
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade600,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Selected indicator with animation
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: isSelected
                              ? Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.elasticOut,
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              config.primaryColor,
                                              config.primaryColor.withValues(
                                                alpha: 0.85,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: config.primaryColor
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.onboarding_selected,
                                              style: AppTypography.labelLarge
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-right checkmark badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: config.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: config.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final ml = sl<ModuleLoaderService>();
    List<BusinessTypeConfig> configs = BusinessTypeConfig.all;
    if (ml.isInitialized && ml.activeModules.isNotEmpty) {
      configs = configs.where((c) => ml.isModuleEnabled(c.type.name)).toList();
    }
    if (configs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Text(
            'No business categories are enabled for your license. '
            'Re-validate your license key or contact support.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: FuturisticColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final allowedTypes = configs.map((c) => c.type).toSet();
    if (widget.selectedType != null &&
        !allowedTypes.contains(widget.selectedType)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTypeSelected(configs.first.type);
      });
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = context.isMobile;

    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: SlideTransition(
        position: widget.slideAnimation,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)?.onboarding_business_title ??
                        'Select Business Type',
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: FuturisticColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(
                          context,
                        )?.onboarding_business_subtitle ??
                        'Choose your business type',
                    style: AppTypography.bodyLarge.copyWith(
                      color: FuturisticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (isMobile) ...[
              // Swipeable business cards - Fixed with proper height constraint
              SizedBox(
                height: screenHeight * 0.48,
                child: PageView.builder(
                  controller: _cardController,
                  itemCount: configs.length,
                  padEnds: true,
                  clipBehavior: Clip.none,
                  onPageChanged: (index) {
                    setState(() => _currentCardIndex = index);
                    HapticFeedback.selectionClick();
                  },
                  itemBuilder: (context, index) {
                    final config = configs[index];
                    final isSelected = widget.selectedType == config.type;
                    final isCurrent = _currentCardIndex == index;
                    return _buildCard(config, isSelected, isCurrent);
                  },
                ),
              ),

              // Card indicators - Clickable dots for navigation
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(configs.length, (index) {
                    // REQUIREMENT: Clicking a dot must animate to that card
                    return GestureDetector(
                      onTap: () {
                        _cardController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        );
                        HapticFeedback.selectionClick();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentCardIndex == index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentCardIndex == index
                              ? const Color(0xFF1E3A8A)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ] else ...[
              // Grid View for Tablet and Desktop (Windows, MacOS, Web, etc.)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: configs.length,
                    itemBuilder: (context, index) {
                      final config = configs[index];
                      final isSelected = widget.selectedType == config.type;
                      return _buildCard(config, isSelected, true);
                    },
                  ),
                ),
              ),
            ],

            if (isMobile) const Spacer(),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: widget.selectedType != null ? 1.0 : 0.5,
                child: SizedBox(
                  width: double.infinity,
                  child: EnterpriseButton(
                    onPressed: widget.selectedType != null
                        ? widget.onContinue
                        : () {}, // Empty callback when disabled, opacity handles visual
                    label:
                        AppLocalizations.of(context)?.onboarding_continue ??
                        'Continue',
                    backgroundColor: FuturisticColors.primary,
                    textColor: Colors.white,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessIllustration(BusinessTypeConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: config.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Try to load asset image first
          Image.asset(
            config.assetImage,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to emoji/icon design if asset not found
              return Stack(
                children: [
                  // Background decorative elements
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: config.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -10,
                    top: -10,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: config.primaryColor.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  // Main emoji/icon
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          config.emoji,
                          style: TextStyle(
                            fontSize: responsiveValue<double>(
                              context,
                              mobile: 32.0,
                              tablet: 32.0,
                              desktop:
                                  56.0, // PRESERVED: Desktop uses exactly 56 as before
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          config.icon,
                          size: 24,
                          color: config.primaryColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// _LanguageScreen removed

/// Step 3: Congratulations Screen with Boy Celebration Animation
class _CongratulationsScreen extends StatefulWidget {
  final BusinessType businessType;
  final VoidCallback onComplete;

  const _CongratulationsScreen({
    required this.businessType,
    required this.onComplete,
  });

  @override
  State<_CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<_CongratulationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _bounceController;
  late AnimationController _textController;

  final List<_ConfettiParticle> _confetti = [];
  bool _showContent = false;
  bool _isNavigating = false;
  String _celebrationImage = 'assets/images/onboarding/celebration_boy.png';
  String _emojiFallback = '🙋‍♂️';

  @override
  void initState() {
    super.initState();
    _determineCelebrationImage();
    _initAnimations();
    _generateConfetti();
  }

  void _determineCelebrationImage() {
    final name = sessionService.getUserName() ?? '';
    if (_isLikelyFemale(name)) {
      _celebrationImage = 'assets/images/onboarding/celebration_girl.png';
      _emojiFallback = '🙋‍♀️';
    }
  }

  bool _isLikelyFemale(String name) {
    if (name.isEmpty) return false;
    final lowerName = name.trim().toLowerCase();
    // Simple heuristic for checking if name sounds female
    // Ends with 'a', 'i', 'e' are common indicators in many cultures
    // This is not 100% accurate but serves the simplified requirement
    return lowerName.endsWith('a') ||
        lowerName.endsWith('i') ||
        lowerName.endsWith('e') ||
        lowerName.endsWith('y') || // Mary, Amy
        lowerName.endsWith('n'); // Lynn, Ann? (Also John...) -> maybe skip 'n'
    // Let's stick to vowel endings which are statistically more female in many languages
  }

  void _initAnimations() {
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Delay content animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showContent = true);
        _textController.forward();
      }
    });
  }

  void _generateConfetti() {
    final random = math.Random();
    for (int i = 0; i < 60; i++) {
      _confetti.add(
        _ConfettiParticle(
          x: random.nextDouble(),
          y: random.nextDouble() * -1,
          color: [
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.yellow,
            Colors.purple,
            Colors.orange,
            Colors.pink,
            Colors.cyan,
            Colors.amber,
            Colors.teal,
          ][random.nextInt(10)],
          speed: 0.4 + random.nextDouble() * 0.6,
          rotation: random.nextDouble() * 2 * math.pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _bounceController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessConfig = BusinessTypeConfig.getConfig(widget.businessType);

    return Stack(
      children: [
        // Confetti background
        AnimatedBuilder(
          animation: _confettiController,
          builder: (context, child) {
            return CustomPaint(
              painter: _ConfettiPainter(
                particles: _confetti,
                progress: _confettiController.value,
              ),
              size: Size.infinite,
            );
          },
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Party emoji at top
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _bounceController,
                  curve: Curves.elasticOut,
                ),
                child: Text(
                  '🎉',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 32.0,
                      tablet: 32.0,
                      desktop:
                          48.0, // PRESERVED: Desktop uses exactly 48 as before
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Congratulations title
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _showContent ? 1 : 0,
                child: Text(
                  AppLocalizations.of(
                        context,
                      )?.onboarding_congratulations_title ??
                      'Congratulations!',
                  style: AppTypography.headlineLarge.copyWith(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 28.0,
                      tablet: 30.0,
                      desktop:
                          32.0, // PRESERVED: Desktop uses exactly 32 as before
                    ),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Success message
              AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                offset: _showContent ? Offset.zero : const Offset(0, 0.3),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _showContent ? 1 : 0,
                  child: Text(
                    AppLocalizations.of(
                          context,
                        )?.onboarding_congratulations_subtitle ??
                        'Success',
                    style: AppTypography.bodyLarge.copyWith(
                      color: FuturisticColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Celebration boy illustration
              AnimatedSlide(
                duration: const Duration(milliseconds: 600),
                offset: _showContent ? Offset.zero : const Offset(0, 0.5),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _showContent ? 1 : 0,
                  child: _buildCelebrationIllustration(),
                ),
              ),

              const SizedBox(height: 24),

              // Personalization info card
              AnimatedSlide(
                duration: const Duration(milliseconds: 700),
                offset: _showContent ? Offset.zero : const Offset(0, 0.5),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: _showContent ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ModernCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        // Reused or simplified message if needed. Using business name dynamically is fine.
                        "You're all set to manage your\n${businessConfig.name}!",
                        style: AppTypography.bodyMedium.copyWith(
                          color: FuturisticColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Go to Dashboard button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _showContent ? 1 : 0,
                  child: SizedBox(
                    width: double.infinity,
                    child: EnterpriseButton(
                      onPressed: _isNavigating
                          ? () {}
                          : () {
                              setState(() => _isNavigating = true);
                              widget.onComplete();
                            },
                      label: _isNavigating
                          ? 'Opening Dashboard...'
                          : AppLocalizations.of(context)?.onboarding_lets_go ??
                                "Let's Go",
                      icon: _isNavigating ? null : Icons.rocket_launch,
                      backgroundColor:
                          FuturisticColors.error, // Orange for call to action
                      textColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationIllustration() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floating emojis around
          ..._buildFloatingEmojis(),

          // Central boy/girl figure
          Image.asset(
            _celebrationImage,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if image not found
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji version
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.orange.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Character emoji
                      Text(
                        _emojiFallback,
                        style: TextStyle(
                          fontSize: responsiveValue<double>(
                            context,
                            mobile: 32.0,
                            tablet: 32.0,
                            desktop:
                                72.0, // PRESERVED: Desktop uses exactly 72 as before
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingEmojis() {
    return [
      // Rocket
      Positioned(
        right: 40,
        top: 10,
        child: _FloatingEmoji(emoji: '🚀', delay: 0),
      ),
      // Star
      Positioned(
        left: 60,
        top: 30,
        child: _FloatingEmoji(emoji: '⭐', delay: 100),
      ),
      // Party hat
      Positioned(
        left: 30,
        bottom: 40,
        child: _FloatingEmoji(emoji: '🎊', delay: 200),
      ),
      // Smiley
      Positioned(
        right: 30,
        bottom: 30,
        child: _FloatingEmoji(emoji: '😊', delay: 300),
      ),
      // Gift
      Positioned(
        left: 50,
        bottom: 0,
        child: _FloatingEmoji(emoji: '🎁', delay: 400),
      ),
      // Megaphone
      Positioned(
        right: 60,
        top: 60,
        child: _FloatingEmoji(emoji: '📢', delay: 150),
      ),
    ];
  }
}

/// Floating emoji with bounce animation
class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final int delay;

  const _FloatingEmoji({required this.emoji, required this.delay});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -8 * math.sin(_controller.value * math.pi)),
          child: Text(
            widget.emoji,
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 24.0,
                tablet: 26.0,
                desktop: 28.0, // PRESERVED: Desktop uses exactly 28 as before
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Confetti particle model
class _ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double speed;
  double rotation;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.speed,
    required this.rotation,
  });
}

/// Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update position
      final y = (particle.y + progress * particle.speed * 2) % 1.3;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(particle.x * size.width, y * size.height);
      canvas.rotate(particle.rotation + progress * 4);

      // Draw different shapes
      final shapeType = (particle.color.value % 3);
      if (shapeType == 0) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 10, height: 10),
          paint,
        );
      } else if (shapeType == 1) {
        canvas.drawCircle(Offset.zero, 5, paint);
      } else {
        // Triangle
        final path = Path()
          ..moveTo(0, -6)
          ..lineTo(6, 6)
          ..lineTo(-6, 6)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
