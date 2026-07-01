import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? comparisonText;
  final double? trendPercentage;
  final String? trendLabel;
  final IconData? icon;
  final Color? statusColor;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.comparisonText,
    this.trendPercentage,
    this.trendLabel,
    this.icon,
    this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = statusColor ?? colorScheme.primary;
    final trendColor = trendPercentage == null
        ? colorScheme.onSurfaceVariant
        : trendPercentage! >= 0
            ? colorScheme.tertiary
            : colorScheme.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (trendPercentage != null)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: trendColor.withValues(alpha: 0.12),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trendPercentage! >= 0
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 14,
                                color: trendColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${trendPercentage!.abs().toStringAsFixed(1)}%',
                                style: textTheme.labelMedium?.copyWith(
                                  color: trendColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (trendLabel != null)
                        Text(
                          trendLabel!,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (comparisonText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      comparisonText!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (compact) const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
