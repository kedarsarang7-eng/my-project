// ============================================================================
// DC UI KIT — Shared modern UI components for Decoration & Catering module
// ============================================================================
import 'package:flutter/material.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
class DcColors {
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF5F3FF);
  static const purpleDark = Color(0xFF5B21B6);
  static const orange = Color(0xFFD97706);
  static const orangeLight = Color(0xFFFFFBEB);
  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFFF0FDFA);
  static const green = Color(0xFF059669);
  static const greenLight = Color(0xFFF0FDF4);
  static const red = Color(0xFFDC2626);
  static const redLight = Color(0xFFFEF2F2);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF8F9FB);
}

// ── Gradient header ───────────────────────────────────────────────────────────
class DcGradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color colorEnd;
  final List<Widget>? actions;

  const DcGradientHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    Color? colorEnd,
    this.actions,
  }) : colorEnd = colorEnd ?? color;

  @override
  Widget build(BuildContext context) {
    final gradEnd = colorEnd == color
        ? Color.lerp(color, Colors.black, 0.25)!
        : colorEnd;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, gradEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

// ── Stat chip row ─────────────────────────────────────────────────────────────
class DcStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const DcStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: DcColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class DcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = DcColors.purple,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: color.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DcColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: DcColors.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stale-data banner (Requirement 2.6 AC4-5) ─────────────────────────────────
/// Non-blocking "showing last-synced data" banner, shown while a
/// `dcBookingsProvider`/`dcInventoryProvider` fallback read is in effect
/// (see `dc_repository.dart`'s `dcBookingsStaleProvider`/
/// `dcInventoryStaleProvider`). Clears automatically once the caller stops
/// rendering it — i.e. once the corresponding stale provider flips back to
/// `false` on the next successful live fetch.
class DcStaleDataBanner extends StatelessWidget {
  const DcStaleDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DcColors.orangeLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DcColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: DcColors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Showing last-synced data — reconnecting…',
              style: TextStyle(fontSize: 12, color: DcColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class DcErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const DcErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DcColors.redLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: DcColors.red,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DcColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 12, color: DcColors.muted),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DcColors.red,
                side: const BorderSide(color: DcColors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Skeleton shimmer ──────────────────────────────────────────────────────────
class DcSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const DcSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  State<DcSkeleton> createState() => _DcSkeletonState();
}

class _DcSkeletonState extends State<DcSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (ctx, child) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFE5E7EB),
          const Color(0xFFF3F4F6),
          _anim.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

// ── Card skeleton ─────────────────────────────────────────────────────────────
class DcCardSkeleton extends StatelessWidget {
  const DcCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DcColors.border),
      ),
      // Sized off the card's own available width (LayoutBuilder), not the
      // full screen width — DcCardSkeleton is used inside narrow containers
      // (e.g. the 300px-wide vendor/profitability master-detail lists), and
      // MediaQuery-based sizing previously overflowed those narrow parents
      // (Requirement 1.1 AC5 regression discovered by DcReachabilityGateTest).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DcSkeleton(width: 40, height: 40, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DcSkeleton(width: w * 0.4, height: 13),
                        const SizedBox(height: 6),
                        DcSkeleton(width: w * 0.25, height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const DcSkeleton(width: 60, height: 22, radius: 11),
                ],
              ),
              const SizedBox(height: 12),
              DcSkeleton(width: w, height: 10),
              const SizedBox(height: 6),
              DcSkeleton(width: w * 0.65, height: 10),
            ],
          );
        },
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class DcSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const DcSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? DcColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: c.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

// ── Info badge ────────────────────────────────────────────────────────────────
class DcBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const DcBadge(
    this.label, {
    super.key,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}
