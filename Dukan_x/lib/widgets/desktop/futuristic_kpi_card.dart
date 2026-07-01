import 'package:flutter/material.dart';
import '../../core/theme/futuristic_colors.dart';

/// Futuristic KPI Card
///
/// A premium KPI card matching the reference design with:
/// - Glass background with neon border
/// - Icon with glow effect
/// - Label, value, and optional trend indicator
/// - Hover animation
class FuturisticKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? trend;
  final bool? isPositive;
  final VoidCallback? onTap;
  final double? width;

  const FuturisticKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.trend,
    this.isPositive,
    this.onTap,
    this.width,
  });

  @override
  State<FuturisticKpiCard> createState() => _FuturisticKpiCardState();
}

class _FuturisticKpiCardState extends State<FuturisticKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? FuturisticColors.premiumBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FuturisticColors.surface.withOpacity(_isHovered ? 0.9 : 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(_isHovered ? 0.5 : 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 20 : 12,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Label
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: FuturisticColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icon with glow
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isHovered
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(widget.icon, size: 20, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Value — FittedBox ensures large ₹ amounts scale down
              // instead of overflowing on narrow screens.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Trend indicator
              if (widget.trend != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.isPositive != null)
                      Icon(
                        widget.isPositive!
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: widget.isPositive!
                            ? FuturisticColors.success
                            : FuturisticColors.error,
                      ),
                    if (widget.isPositive != null) const SizedBox(width: 4),
                    Text(
                      widget.trend!,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isPositive == null
                            ? FuturisticColors.textSecondary
                            : (widget.isPositive!
                                  ? FuturisticColors.success
                                  : FuturisticColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact KPI card for tighter layouts
class CompactKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const CompactKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? FuturisticColors.premiumBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FuturisticColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI Row - Displays multiple KPI cards in a row
class KpiCardRow extends StatelessWidget {
  final List<FuturisticKpiCard> cards;
  final double spacing;

  const KpiCardRow({super.key, required this.cards, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index > 0 ? spacing / 2 : 0,
              right: index < cards.length - 1 ? spacing / 2 : 0,
            ),
            child: card,
          ),
        );
      }).toList(),
    );
  }
}
