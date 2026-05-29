import 'package:flutter/material.dart';

import '../theme/fuelpos_theme.dart';

/// KPI Card Widget - Reusable metric card for dashboard with hover lift + glow
class KpiCardWidget extends StatefulWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? changePercent;
  final IconData icon;
  final Color accentColor;
  final bool isPositiveChange;
  final VoidCallback? onTap;

  const KpiCardWidget({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.changePercent,
    required this.icon,
    this.accentColor = FuelPOSTheme.primaryBlue,
    this.isPositiveChange = true,
    this.onTap,
  });

  @override
  State<KpiCardWidget> createState() => _KpiCardWidgetState();
}

class _KpiCardWidgetState extends State<KpiCardWidget> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, isHovered, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform:
                  Matrix4.translationValues(0, isHovered ? -3.0 : 0, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor
                        .withValues(alpha: isHovered ? 0.2 : 0.13),
                    widget.accentColor
                        .withValues(alpha: isHovered ? 0.08 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.accentColor.withValues(
                      alpha: isHovered ? 0.5 : 0.2),
                  width: isHovered ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(
                        alpha: isHovered ? 0.22 : 0.06),
                    blurRadius: isHovered ? 22 : 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isHovered ? 0.3 : 0.15),
                    blurRadius: isHovered ? 16 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: isHovered
                                ? FuelPOSTheme.textPrimary
                                : FuelPOSTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accentColor
                                  .withValues(alpha: isHovered ? 0.3 : 0.15),
                              widget.accentColor
                                  .withValues(alpha: isHovered ? 0.15 : 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: widget.accentColor
                                .withValues(alpha: isHovered ? 0.45 : 0.2),
                          ),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: widget.accentColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: isHovered ? 24 : 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.value,
                    style: TextStyle(
                      color: isHovered
                          ? Colors.white
                          : FuelPOSTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        color: FuelPOSTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  if (widget.changePercent != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isPositiveChange
                                ? FuelPOSTheme.successGreen
                                    .withValues(alpha: 0.15)
                                : FuelPOSTheme.errorRed
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.isPositiveChange
                                  ? FuelPOSTheme.successGreen
                                      .withValues(alpha: 0.3)
                                  : FuelPOSTheme.errorRed
                                      .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isPositiveChange
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                color: widget.isPositiveChange
                                    ? FuelPOSTheme.successGreen
                                    : FuelPOSTheme.errorRed,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.changePercent!.abs().toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: widget.isPositiveChange
                                      ? FuelPOSTheme.successGreen
                                      : FuelPOSTheme.errorRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'vs yesterday',
                          style: TextStyle(
                            color: FuelPOSTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// KPI Row Widget - Container for 4 KPI cards
class KpiRowWidget extends StatelessWidget {
  final List<Widget> children;

  const KpiRowWidget({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((child) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: child,
                ),
              ))
          .toList(),
    );
  }
}
