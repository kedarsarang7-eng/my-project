// Business Settings Screen
// Change business type, language, and other preferences
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../onboarding/onboarding_models.dart';
import '../../providers/app_state_providers.dart';
import '../../models/business_type.dart';
import '../../core/theme/futuristic_colors.dart';
import '../pharmacy/widgets/drug_license_field.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends ConsumerState<BusinessSettingsScreen>
    with SingleTickerProviderStateMixin {
  final OnboardingService _onboardingService = OnboardingService();

  BusinessType _selectedBusinessType = BusinessType.other;
  AppLanguage _selectedLanguage = AppLanguage.english;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isLocked = false; // New lock state

  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
  }

  void _initAnimations() {
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _saveButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeOut),
    );
  }

  Future<void> _loadSettings() async {
    try {
      final results = await Future.wait([
        _onboardingService.getBusinessType(),
        _onboardingService.getLanguage(),
        _onboardingService.isBusinessTypeLocked(), // Check lock status
      ]);

      if (mounted) {
        setState(() {
          _selectedBusinessType = results[0] as BusinessType;
          _selectedLanguage = results[1] as AppLanguage;
          _isLocked = results[2] as bool; // Set lock state
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onBusinessTypeChanged(BusinessType type) {
    if (_isLocked) return; // Prevent change if locked

    if (type != _selectedBusinessType) {
      setState(() {
        _selectedBusinessType = type;
        _hasChanges = true;
      });
      _saveButtonController.forward();
      HapticFeedback.selectionClick();
    }
  }

  void _onLanguageChanged(AppLanguage language) {
    if (language != _selectedLanguage) {
      setState(() {
        _selectedLanguage = language;
        _hasChanges = true;
      });
      _saveButtonController.forward();
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _saveSettings() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _onboardingService.saveBusinessType(_selectedBusinessType);
      await _onboardingService.saveLanguage(_selectedLanguage);

      if (!mounted) return;

      // Update locale provider
      try {
        final langConfig = LanguageConfig.all.firstWhere(
          (l) => l.language == _selectedLanguage,
        );
        ref
            .read(localeStateProvider.notifier)
            .setLocale(Locale(langConfig.code));
      } catch (_) {
        // LocaleNotifier might not be available or internal error
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Settings saved successfully!',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      _saveButtonController.reverse();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _saveButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.background
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.background
            : const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Business Settings',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF3B82F6),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Business Info Card
                    _buildCurrentBusinessCard(isDark),
                    const SizedBox(height: 24),

                    // Business Type Section
                    _buildSectionHeader('Business Type', isDark),
                    const SizedBox(height: 12),
                    _buildBusinessTypeSelector(isDark),
                    const SizedBox(height: 24),

                    // Language Section
                    _buildSectionHeader('App Language', isDark),
                    const SizedBox(height: 12),
                    _buildLanguageSelector(isDark),
                    const SizedBox(height: 24),

                    // Drug License Number (pharmacy only, R14). Surfaced only for
                    // the pharmacy business type; other verticals are unchanged.
                    if (_selectedBusinessType == BusinessType.pharmacy) ...[
                      _buildSectionHeader('Drug License Number', isDark),
                      const SizedBox(height: 12),
                      DrugLicenseField(isDark: isDark),
                      const SizedBox(height: 24),
                    ],

                    // Bill Preview
                    _buildSectionHeader('Bill Preview', isDark),
                    const SizedBox(height: 12),
                    _buildBillPreview(isDark),
                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
      ),

      floatingActionButton: _buildSaveButton(isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _buildCurrentBusinessCard(bool isDark) {
    final config = BusinessTypeConfig.getConfig(_selectedBusinessType);
    final langConfig = LanguageConfig.all.firstWhere(
      (l) => l.language == _selectedLanguage,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [config.primaryColor, config.primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: config.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(config.emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: TextStyle(
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22,
                        ),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(langConfig.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  langConfig.nativeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Type Locked',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type cannot be changed because transactions exist. This protects your data integrity.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: BusinessTypeConfig.all.asMap().entries.map((entry) {
              final index = entry.key;
              final config = entry.value;
              final isSelected = _selectedBusinessType == config.type;
              final isLast = index == BusinessTypeConfig.all.length - 1;

              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLocked
                          ? () {
                              HapticFeedback.heavyImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Business Type is locked due to existing data.',
                                  ),
                                  backgroundColor: Colors.red.shade800,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : () => _onBusinessTypeChanged(config.type),
                      borderRadius: BorderRadius.vertical(
                        top: index == 0
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottom: isLast
                            ? const Radius.circular(16)
                            : Radius.zero,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? config.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          border: isSelected
                              ? Border(
                                  left: BorderSide(
                                    color: config.primaryColor,
                                    width: 4,
                                  ),
                                )
                              : null,
                        ),
                        child: Opacity(
                          opacity: _isLocked && !isSelected ? 0.5 : 1.0,
                          child: Row(
                            children: [
                              // Emoji
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: config.secondaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    config.emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name & Description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      config.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? config.primaryColor
                                            : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1F2937)),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      config.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Selection indicator
                              if (_isLocked && isSelected)
                                const Icon(
                                  Icons.lock,
                                  size: 20,
                                  color: Colors.grey,
                                )
                              else
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? config.primaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? config.primaryColor
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 80,
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: LanguageConfig.all.map((lang) {
          final isSelected = _selectedLanguage == lang.language;

          return GestureDetector(
            onTap: () => _onLanguageChanged(lang.language),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBillPreview(bool isDark) {
    final config = BusinessTypeConfig.getConfig(_selectedBusinessType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(config.icon, color: config.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Bill Columns for ${config.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: config.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Column chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: config.billColumns.map((col) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: config.secondaryColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: config.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  col,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: config.primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your bills will use these columns. You can customize individual bills later.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSaveButton(bool isDark) {
    if (!_hasChanges) return null;

    return FadeTransition(
      opacity: _saveButtonAnimation,
      child: ScaleTransition(
        scale: _saveButtonAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Changes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF10B981).withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
