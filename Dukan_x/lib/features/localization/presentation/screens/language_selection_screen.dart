/// LanguageSelectionScreen - First-time blocking language selection
///
/// This screen is shown to NEW users immediately after login,
/// BEFORE business type selection. User CANNOT skip this step.
///
/// Features:
/// - Displays all 11 languages with native script names
/// - Flag emoji for regional identity
/// - Accessibility-friendly tap targets (min 48px)
/// - RTL-ready for Urdu
/// - Confirmation message about Settings
///
/// Author: DukanX Engineering
/// Version: 1.0.0
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/localization_service.dart';
import 'language_setup_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedLocaleCode;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(String code) {
    HapticFeedback.selectionClick();
    setState(() => _selectedLocaleCode = code);
  }

  void _onConfirm() {
    if (_selectedLocaleCode == null) return;

    HapticFeedback.mediumImpact();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LanguageSetupScreen(selectedLocaleCode: _selectedLocaleCode!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.05, 0),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final locales = LocalizationService.supportedLocales.values.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: BoundedBox(
        maxWidth: 800,
        child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Language icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title - hardcoded is OK here since language not yet selected
                    Text(
                      'Choose Your Language',
                      style: GoogleFonts.outfit(
                        fontSize: responsiveValue<double>(context, mobile: 20, tablet: 22, desktop: 26),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Select your preferred language for the app',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Language grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: locales.length,
                    itemBuilder: (context, index) {
                      final locale = locales[index];
                      final isSelected = _selectedLocaleCode == locale.code;

                      return _LanguageCard(
                        locale: locale,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => _onLanguageSelected(locale.code),
                      );
                    },
                  ),
                ),
              ),

              // Confirmation message
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You can change this later in Settings',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _selectedLocaleCode != null ? 1.0 : 0.5,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedLocaleCode != null
                          ? _onConfirm
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: _selectedLocaleCode != null ? 4 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: GoogleFonts.outfit(
                              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
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
}

/// Individual language card widget
class _LanguageCard extends StatelessWidget {
  final LocaleInfo locale;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.locale,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE))
          : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Flag
              Text(locale.flag, style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 22.0,
                    tablet: 24.0,
                    desktop: 26.0,  // PRESERVED: Desktop uses exactly 26 as before
                  ))),
              const SizedBox(width: 12),

              // Language name in native script
              Expanded(
                child: Text(
                  locale.nativeName,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                  textDirection: locale.isRtl
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ),

              // Checkmark
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
