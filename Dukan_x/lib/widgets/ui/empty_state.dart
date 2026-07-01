import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_state_providers.dart';
import 'primary_button.dart';

class EmptyStateWidget extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : palette.leafGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: isDark ? Colors.white54 : palette.leafGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : palette.mutedGray,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : palette.darkGray,
                height: 1.5,
              ),
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              PrimaryButton(
                text: actionText!,
                onPressed: onActionPressed,
                type: ButtonType.primary,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
