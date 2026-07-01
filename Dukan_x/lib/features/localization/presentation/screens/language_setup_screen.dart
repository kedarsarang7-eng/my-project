/// LanguageSetupScreen - Visual feedback during language initialization
///
/// Shows a progress UI while:
/// 1. Loading translations
/// 2. Applying preferences
/// 3. Preparing the experience
///
/// Handles errors with retry option.
///
/// Author: DukanX Engineering
/// Version: 1.0.0
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../onboarding/vendor_onboarding_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class LanguageSetupScreen extends ConsumerStatefulWidget {
  final String selectedLocaleCode;

  const LanguageSetupScreen({super.key, required this.selectedLocaleCode});

  @override
  ConsumerState<LanguageSetupScreen> createState() =>
      _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends ConsumerState<LanguageSetupScreen>
    with SingleTickerProviderStateMixin {
  String _statusMessage = 'Initializing...';
  double _progress = 0.0;
  bool _hasError = false;
  bool _isComplete = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start setup after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSetup());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runSetup() async {
    setState(() {
      _hasError = false;
      _progress = 0.0;
      _statusMessage = 'Loading translations...';
    });

    final locale = Locale(widget.selectedLocaleCode);
    final service = LocalizationService();

    final success = await service.setupLanguage(locale, (status, progress) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
          _progress = progress;
        });
      }
    });

    if (!mounted) return;

    if (success) {
      // Update locale in Riverpod state
      ref.read(localeStateProvider.notifier).setLocale(locale);

      setState(() {
        _isComplete = true;
        _statusMessage = 'Ready!';
      });

      // Navigate to onboarding after short delay
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const VendorOnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } else {
      setState(() {
        _hasError = true;
        _statusMessage = 'Setup failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeInfo =
        LocalizationService.supportedLocales[widget.selectedLocaleCode];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: BoundedBox(
        maxWidth: 800,
        child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(responsiveValue<double>(context,
              mobile: 16,
              tablet: 20,
              desktop: 32,  // PRESERVED: Desktop uses exactly 32 as before
            )),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _hasError
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : _isComplete
                            ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                            : [
                                const Color(0xFF3B82F6),
                                const Color(0xFF8B5CF6),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_hasError
                                      ? const Color(0xFFEF4444)
                                      : _isComplete
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFF3B82F6))
                                  .withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _hasError
                          ? Icons.error_outline_rounded
                          : _isComplete
                          ? Icons.check_rounded
                          : Icons.translate_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Language name with flag
                if (localeInfo != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        localeInfo.flag,
                        style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 24.0,
                    tablet: 26.0,
                    desktop: 28.0,  // PRESERVED: Desktop uses exactly 28 as before
                  )),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localeInfo.nativeName,
                        style: GoogleFonts.notoSans(
                          fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),

                // Status message
                Text(
                  _statusMessage,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: _hasError
                        ? const Color(0xFFEF4444)
                        : isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Progress indicator
                if (!_hasError && !_isComplete) ...[
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                ],

                // Success checkmark
                if (_isComplete) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF22C55E),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Language configured successfully',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  ),
                ],

                // Retry button
                if (_hasError) ...[
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _runSetup,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
