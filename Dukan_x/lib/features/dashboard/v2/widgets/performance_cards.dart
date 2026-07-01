import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../config/dashboard_business_config.dart';
import '../models/dashboard_v2_models.dart';
import '../providers/dashboard_v2_providers.dart';
import '../utils/indian_number_formatter.dart';

class PerformanceCards extends ConsumerWidget {
  const PerformanceCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardV2SummaryProvider);
    final config = ref.watch(dashboardBusinessConfigProvider);

    return summaryAsync.when(
      data: (summary) => _buildCards(context, summary, config),
      loading: () => _buildLoading(),
      // AUDIT FIX #4: Show error state with retry, not silent empty
      error: (e, _) => _buildError(ref),
    );
  }

  Widget _buildCards(
    BuildContext context,
    DashboardSummary s,
    DashboardBusinessConfig config,
  ) {
    // Build the four KPI cards once, then arrange them responsively:
    //   • mobile  → a 2×2 grid (each card gets enough width to render ₹ values)
    //   • tablet+ → a single row of four (the original desktop layout)
    // On narrow phones four equal columns leave ~80dp each, which forces ₹
    // amounts to overflow/wrap even at the default text scale.
    final cards = <Widget>[
      _KpiCard(
        title: config.revenueCardLabel,
        value: IndianNumberFormatter.formatCentsToInr(s.totalRevenueCents),
        changePercent: s.revenueChangePercent,
        badge: s.revenueBadge,
        badgeColor: _badgeColor(s.revenueBadge),
        icon: Icons.account_balance_wallet_rounded,
        iconColor: FuturisticColors.success,
        isEmpty: s.isEmpty,
      ),
      _KpiCard(
        title: config.kpi2Label,
        value: s.overdueCount.toString(),
        subtitle: IndianNumberFormatter.formatCentsToInr(s.overdueAmountCents),
        badge: s.overdueBadge,
        badgeColor: _badgeColor(s.overdueBadge),
        icon: Icons.warning_amber_rounded,
        iconColor: FuturisticColors.error,
        isEmpty: s.isEmpty,
      ),
      _KpiCard(
        title: config.kpi3Label,
        value: s.pendingCount.toString(),
        subtitle: IndianNumberFormatter.formatCentsToInr(s.pendingAmountCents),
        badge: s.pendingBadge,
        badgeColor: _badgeColor(s.pendingBadge),
        icon: Icons.pending_actions_rounded,
        iconColor: FuturisticColors.warning,
        isEmpty: s.isEmpty,
      ),
      _KpiCard(
        title: 'Avg Collection Period',
        value: '${s.avgCollectionDays} days',
        changePercent: s.collectionChangePercent,
        icon: Icons.timer_outlined,
        iconColor: FuturisticColors.accent1,
        isEmpty: s.isEmpty,
        invertChange: true,
      ),
    ];

    // 2×2 grid on phones; single 4-up row on tablet/desktop.
    if (context.isMobile) {
      return _MobileKpiGrid(cards: cards);
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
            child: Shimmer.fromColors(
              baseColor: FuturisticColors.surface,
              highlightColor: FuturisticColors.border.withValues(alpha: 0.6),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: FuturisticColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 80, height: 12, color: FuturisticColors.border),
                    Container(width: 120, height: 24, color: FuturisticColors.border),
                    Container(width: 60, height: 10, color: FuturisticColors.border),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// AUDIT FIX #4: Error state with retry
  Widget _buildError(WidgetRef ref) {
    return Container(
      height: 130,
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FuturisticColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              color: FuturisticColors.error.withValues(alpha: 0.5), size: 28),
          const SizedBox(width: 12),
          Text(
            'Failed to load summary',
            style: TextStyle(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => ref.invalidate(dashboardV2SummaryProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: FuturisticColors.primary,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _badgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'healthy':
        return FuturisticColors.success;
      case 'critical':
      case 'urgent':
        return FuturisticColors.error;
      default:
        return FuturisticColors.textSecondary;
    }
  }
}

/// Lays out the four KPI cards as a 2×2 grid on phones so each card gets enough
/// width to render ₹ values without overflowing. Replaces the 4-up single row
/// that cramped each card to ~80dp on narrow screens.
class _MobileKpiGrid extends StatelessWidget {
  final List<Widget> cards;

  const _MobileKpiGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    // Two rows of two Expanded cards; each row shares the full width so a card
    // is roughly half-screen wide instead of a quarter.
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? changePercent;
  final String? badge;
  final Color? badgeColor;
  final IconData icon;
  final Color iconColor;
  final bool isEmpty;
  final bool invertChange;

  const _KpiCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.changePercent,
    this.badge,
    this.badgeColor,
    required this.icon,
    required this.iconColor,
    this.isEmpty = false,
    this.invertChange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FuturisticColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: icon + badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? FuturisticColors.textSecondary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor ?? FuturisticColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),

          // Value — scale down (never wrap/overflow) so large ₹ amounts fit the
          // card width at any text scale.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isEmpty ? '—' : value,
              maxLines: 1,
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                decoration: TextDecoration.none,
              ),
            ),
          ),

          // Subtitle or change
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          if (changePercent != null && !isEmpty) ...[
            const SizedBox(height: 6),
            _ChangeIndicator(
              percent: changePercent!,
              invertChange: invertChange,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeIndicator extends StatelessWidget {
  final double percent;
  final bool invertChange;

  const _ChangeIndicator({
    required this.percent,
    this.invertChange = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = percent >= 0;
    // For collection period, lower is better
    final isGood = invertChange ? !isPositive : isPositive;
    final color = isGood ? FuturisticColors.success : FuturisticColors.error;
    final icon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        // The percent value must never be dropped; keep it fixed-width.
        Text(
          IndianNumberFormatter.formatPercent(percent),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 4),
        // The descriptive label is the first thing to truncate if the card is
        // narrow, so the percent + arrow always remain visible.
        Flexible(
          child: Text(
            'vs last month',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
