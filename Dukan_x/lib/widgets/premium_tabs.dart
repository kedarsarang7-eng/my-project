// Premium Tab Components
//
// World-class minimal tab UI inspired by Apple VisionOS / Material You.
// Small, animated, futuristic, enterprise-safe.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════════

/// Tab sizing (STRICT per spec)
const double kPremiumNavHeight = 56.0; // Overall nav height
const double kPremiumTabHeight = 36.0; // Individual tab height
const double kPremiumIconSize = 20.0;
const double kPremiumLabelSize = 11.0;
const double kPremiumIndicatorHeight = 2.5;

/// Animation timings
const Duration kTabAnimDuration = Duration(milliseconds: 150);
const Curve kTabAnimCurve = Curves.easeOutCubic;

/// Border radius
const double kPillRadius = 999.0;
const double kSoftRadius = 12.0;

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════════════

class PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PremiumNavItem> items;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? inactiveColor;

  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        backgroundColor ??
        (isDark ? const Color(0xFF0D1117) : theme.colorScheme.surface);

    final active = activeColor ?? theme.colorScheme.primary;
    final inactive =
        inactiveColor ?? (isDark ? Colors.white70 : Colors.black54);

    return Container(
      height: kPremiumNavHeight + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kPremiumNavHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  return _PremiumNavTab(
                    item: items[index],
                    isActive: index == currentIndex,
                    activeColor: active,
                    inactiveColor: inactive,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(index);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const PremiumNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class _PremiumNavTab extends StatefulWidget {
  final PremiumNavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _PremiumNavTab({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_PremiumNavTab> createState() => _PremiumNavTabState();
}

class _PremiumNavTabState extends State<_PremiumNavTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kTabAnimDuration);
    if (widget.isActive) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_PremiumNavTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final color = Color.lerp(
            widget.inactiveColor,
            widget.activeColor,
            _controller.value,
          )!;

          final scale = _isPressed ? 0.92 : (1.0 + _controller.value * 0.05);

          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kSoftRadius),
                color: widget.isActive
                    ? widget.activeColor.withOpacity(0.12)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isActive
                        ? (widget.item.activeIcon ?? widget.item.icon)
                        : widget.item.icon,
                    size: kPremiumIconSize,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      fontSize: kPremiumLabelSize,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM TAB BAR
// ═══════════════════════════════════════════════════════════════════════════

class PremiumTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<PremiumTabItem> tabs;
  final Color? activeColor;
  final Color? inactiveColor;
  final EdgeInsetsGeometry? padding;

  const PremiumTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.activeColor,
    this.inactiveColor,
    this.padding,
  });

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive =
        inactiveColor ?? (isDark ? Colors.white70 : Colors.black54);

    return Container(
      height: preferredSize.height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: _PremiumTabIndicator(color: active),
        dividerHeight: 0,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelColor: active,
        unselectedLabelColor: inactive,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: tabs.map((tab) {
          return Tab(
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tab.icon != null) ...[
                  Icon(tab.icon, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(tab.label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PremiumTabItem {
  final String label;
  final IconData? icon;

  const PremiumTabItem({required this.label, this.icon});
}

class _PremiumTabIndicator extends Decoration {
  final Color color;

  const _PremiumTabIndicator({required this.color});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PremiumIndicatorPainter(color: color);
  }
}

class _PremiumIndicatorPainter extends BoxPainter {
  final Color color;

  _PremiumIndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration config) {
    final size = config.size!;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Thin pill-shaped indicator at bottom
    final indicatorHeight = kPremiumIndicatorHeight;
    final indicatorWidth = size.width * 0.6;
    final left = offset.dx + (size.width - indicatorWidth) / 2;
    final top = offset.dy + size.height - indicatorHeight - 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, indicatorWidth, indicatorHeight),
      const Radius.circular(kPillRadius),
    );

    canvas.drawRRect(rect, paint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM SEGMENTED CONTROL
// ═══════════════════════════════════════════════════════════════════════════

class PremiumSegmentedControl<T extends Object> extends StatelessWidget {
  final Set<T> selected;
  final void Function(Set<T>) onSelectionChanged;
  final List<PremiumSegment<T>> segments;
  final Color? activeColor;

  const PremiumSegmentedControl({
    super.key,
    required this.selected,
    required this.onSelectionChanged,
    required this.segments,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = activeColor ?? theme.colorScheme.primary;

    return Container(
      height: kPremiumTabHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kSoftRadius),
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = selected.contains(segment.value);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelectionChanged({segment.value});
            },
            child: AnimatedContainer(
              duration: kTabAnimDuration,
              curve: kTabAnimCurve,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kSoftRadius - 2),
                color: isSelected ? active : Colors.transparent,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: active.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    segment.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PremiumSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const PremiumSegment({required this.value, required this.label, this.icon});
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM ACTION CHIP
// ═══════════════════════════════════════════════════════════════════════════

class PremiumActionChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const PremiumActionChip({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  State<PremiumActionChip> createState() => _PremiumActionChipState();
}

class _PremiumActionChipState extends State<PremiumActionChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = widget.activeColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: kTabAnimDuration,
          curve: kTabAnimCurve,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kPillRadius),
            color: widget.isActive
                ? active.withOpacity(0.15)
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05)),
            border: Border.all(
              color: widget.isActive ? active : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isActive
                      ? active
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: widget.isActive
                      ? active
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
