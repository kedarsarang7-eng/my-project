// ============================================================================
// CURRENCY SETTINGS SCREEN - MULTI-CURRENCY CONFIGURATION
// ============================================================================
// Allows shop owner to select their business currency.
// Uses sl<CurrencyService> for persistence and formatting.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final _currencyService = sl<CurrencyService>();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencies = _currencyService.allCurrencies
        .where(
          (c) =>
              c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.symbol.contains(_searchQuery),
        )
        .toList();

    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppGradients.secondaryGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: const Icon(
                Icons.currency_exchange,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Currency',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search currency...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                filled: true,
                fillColor: isDark
                    ? FuturisticColors.darkSurface
                    : FuturisticColors.surface,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final c = currencies[index];
                final isSelected = c.code == _currencyService.code;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ModernCard(
                    backgroundColor: isSelected
                        ? FuturisticColors.primary.withValues(alpha: 0.1)
                        : isDark
                        ? FuturisticColors.darkSurface
                        : FuturisticColors.surface,
                    onTap: () async {
                      await _currencyService.setCurrency(c.code);
                      setState(() {});
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? FuturisticColors.primary.withValues(alpha: 0.2)
                                : (isDark
                                          ? FuturisticColors.darkTextSecondary
                                          : FuturisticColors.textMuted)
                                      .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              c.symbol,
                              style: TextStyle(
                                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? FuturisticColors.primary
                                    : isDark
                                    ? FuturisticColors.darkTextPrimary
                                    : FuturisticColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: AppTypography.labelLarge.copyWith(
                                  color: isDark
                                      ? FuturisticColors.darkTextPrimary
                                      : FuturisticColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                c.code,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isDark
                                      ? FuturisticColors.darkTextSecondary
                                      : FuturisticColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: FuturisticColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
