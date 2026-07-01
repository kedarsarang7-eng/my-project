import 'package:flutter/material.dart';

class IllustratedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (ctaLabel != null && onCtaPressed != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCtaPressed,
                  icon: const Icon(Icons.add),
                  label: Text(ctaLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
