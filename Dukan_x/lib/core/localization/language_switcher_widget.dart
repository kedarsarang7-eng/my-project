// =============================================================================
// LanguageSwitcherWidget — Drop-in language selector for Settings screens
// =============================================================================
// Reads current locale from localeStateProvider (Riverpod).
// Writes selection to localeStateProvider + SharedPreferences via
// LocalizationService.quickSetLocale().
//
// Usage:
//   const LanguageSwitcherWidget()
//   LanguageSwitcherWidget(onChanged: (locale) => doSomething(locale))
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state_providers.dart';
import 'localization_service.dart';
import 'app_l10n.dart';

class LanguageSwitcherWidget extends ConsumerWidget {
  final void Function(Locale locale)? onChanged;
  final bool showTitle;

  const LanguageSwitcherWidget({
    super.key,
    this.onChanged,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeStateProvider);
    final currentCode = localeState.locale.languageCode;
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            l10n.language,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LocalizationService.supportedLocales.entries.map((entry) {
            final code = entry.key;
            final info = entry.value;
            final isSelected = code == currentCode;

            return _LocaleChip(
              info: info,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => _onSelect(context, ref, code),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _onSelect(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    HapticFeedback.selectionClick();
    final locale = Locale(code);
    await LocalizationService().quickSetLocale(locale);
    ref.read(localeStateProvider.notifier).setLocale(locale);
    onChanged?.call(locale);
  }
}

class _LocaleChip extends StatelessWidget {
  final LocaleInfo info;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _LocaleChip({
    required this.info,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              info.nativeName,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white70 : const Color(0xFF374151)),
              ),
              textDirection: info.isRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: primaryColor),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// LanguageSwitcherListTile — For use inside ListTile-based settings
// =============================================================================

class LanguageSwitcherListTile extends ConsumerWidget {
  const LanguageSwitcherListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeStateProvider);
    final currentCode = localeState.locale.languageCode;
    final info = LocalizationService.supportedLocales[currentCode];
    final l10n = context.l10n;

    return ListTile(
      leading: const Icon(Icons.translate_rounded),
      title: Text(l10n.language),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info != null) ...[
            Text(info.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              info.nativeName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
      onTap: () => _showLanguageBottomSheet(context, ref),
    );
  }

  void _showLanguageBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _LanguageBottomSheet(),
    );
  }
}

class _LanguageBottomSheet extends ConsumerWidget {
  const _LanguageBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localeState = ref.watch(localeStateProvider);
    final currentCode = localeState.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: LocalizationService.supportedLocales.entries
                  .map((entry) {
                final code = entry.key;
                final info = entry.value;
                final isSelected = code == currentCode;

                return ListTile(
                  leading: Text(
                    info.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    info.nativeName,
                    style: GoogleFonts.notoSans(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    textDirection: info.isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                  subtitle: Text(
                    info.englishName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final locale = Locale(code);
                    await LocalizationService().quickSetLocale(locale);
                    ref.read(localeStateProvider.notifier).setLocale(locale);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
          SafeArea(child: const SizedBox(height: 8)),
        ],
      ),
    );
  }
}
