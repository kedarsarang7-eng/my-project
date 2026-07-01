// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';
import '../../../../../../utils/currency_formatter.dart';
import '../../../../pharmacy/utils/tenant_scope.dart';

class PharmacyKpiCards extends ConsumerWidget {
  const PharmacyKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(pharmacyKpiProvider);

    return kpiAsync.when(
      data: (kpiData) => _buildKpiCards(context, kpiData),
      loading: () => _buildKpiCardsLoading(),
      error: (error, _) => _buildKpiCardsError(ref, error),
    );
  }

  Widget _buildKpiCards(BuildContext context, PharmacyKpiData kpiData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth < 1200;

    // Responsive grid
    int crossAxisCount = 4;
    if (isMobile) {
      crossAxisCount = 2;
    } else if (isTablet)
      crossAxisCount = 2;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.2 : 1.4,
      children: [
        _TotalRevenueCard(kpi: kpiData.totalRevenue),
        _NewPatientsCard(kpi: kpiData.newPatients),
        _PrescriptionsFilledCard(kpi: kpiData.prescriptionsFilled),
        _LowStockItemsCard(kpi: kpiData.lowStockItems),
      ],
    );
  }

  Widget _buildKpiCardsLoading() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: List.generate(4, (index) => _KpiCardSkeleton()),
    );
  }

  Widget _buildKpiCardsError(WidgetRef ref, Object error) {
    // R12.4: when the failure is a missing tenant scope, the KPI request was
    // skipped entirely. Surface a distinct "tenant context unavailable" state
    // with no retry (retrying cannot resolve a missing tenant here).
    final isTenantUnavailable =
        error is TenantScopeError &&
        error.kind == TenantScopeErrorKind.missingTenant;

    if (isTenantUnavailable) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 48,
              color: FuturisticColors.warning,
            ),
            const SizedBox(height: 8),
            Text(
              'Tenant context unavailable',
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'KPIs cannot be loaded without an active business.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // R12.3: service error or 10s timeout — show an error indication plus a
    // retry action. Retry re-runs the KPI request in place without navigating
    // away from the dashboard.
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: FuturisticColors.error),
          const SizedBox(height: 8),
          Text(
            'Unable to load KPI data',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(pharmacyKpiProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Individual KPI Cards ─────────────────────────────────────────────────────

class _TotalRevenueCard extends StatelessWidget {
  final TotalRevenueKpi kpi;

  const _TotalRevenueCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return _KpiCard(
      title: 'Total Revenue',
      value: CurrencyFormatter.format(kpi.totalCents),
      changePercent: kpi.changePercent,
      trend: kpi.trend,
      icon: Icons.attach_money_rounded,
      color: FuturisticColors.success,
      isEmpty: kpi.isEmpty,
    );
  }
}

class _NewPatientsCard extends StatelessWidget {
  final NewPatientsKpi kpi;

  const _NewPatientsCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return _KpiCard(
      title: 'New Patients',
      value: kpi.count.toString(),
      changePercent: kpi.changePercent,
      trend: kpi.changePercent > 0
          ? 'up'
          : (kpi.changePercent < 0 ? 'down' : 'neutral'),
      icon: Icons.person_add_rounded,
      color: FuturisticColors.primary,
      isEmpty: kpi.isEmpty,
    );
  }
}

class _PrescriptionsFilledCard extends StatelessWidget {
  final PrescriptionsFilledKpi kpi;

  const _PrescriptionsFilledCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return _KpiCard(
      title: 'Prescriptions Filled',
      value: kpi.count.toString(),
      changePercent: kpi.changePercent,
      trend: kpi.changePercent > 0
          ? 'up'
          : (kpi.changePercent < 0 ? 'down' : 'neutral'),
      icon: Icons.medication_rounded,
      color: FuturisticColors.info,
      isEmpty: kpi.isEmpty,
    );
  }
}

class _LowStockItemsCard extends StatelessWidget {
  final LowStockItemsKpi kpi;

  const _LowStockItemsCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    if (kpi.severity == 'alert') {
      cardColor = FuturisticColors.error;
    } else if (kpi.severity == 'warning') {
      cardColor = FuturisticColors.warning;
    } else {
      cardColor = FuturisticColors.success;
    }

    return _KpiCard(
      title: 'Low Stock Items',
      value: kpi.count.toString(),
      changePercent: 0, // No change percent for stock alerts
      trend: 'neutral',
      icon: Icons.inventory_2_rounded,
      color: cardColor,
      isEmpty: kpi.isEmpty,
      showTrend: false,
    );
  }
}

// ── Base KPI Card Widget ─────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final double changePercent;
  final String trend;
  final IconData icon;
  final Color color;
  final bool isEmpty;
  final bool showTrend;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.changePercent,
    required this.trend,
    required this.icon,
    required this.color,
    required this.isEmpty,
    this.showTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return _KpiCardEmpty(title: title, icon: icon, color: color);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (showTrend && changePercent != 0) _buildTrendIndicator(),
            ],
          ),
          const SizedBox(height: 16),

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: FuturisticColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Change indicator (if not showing in header)
          if (showTrend && changePercent == 0) ...[
            const SizedBox(height: 8),
            Text(
              'No change',
              style: TextStyle(
                fontSize: 12,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendIndicator() {
    Color trendColor;
    IconData trendIcon;

    if (trend == 'up') {
      trendColor = FuturisticColors.success;
      trendIcon = Icons.trending_up_rounded;
    } else if (trend == 'down') {
      trendColor = FuturisticColors.error;
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendColor = FuturisticColors.textSecondary;
      trendIcon = Icons.trending_flat_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 16, color: trendColor),
          const SizedBox(width: 4),
          Text(
            '${changePercent.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: trendColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State Card ─────────────────────────────────────────────────────────

class _KpiCardEmpty extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _KpiCardEmpty({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: FuturisticColors.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FuturisticColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: FuturisticColors.textSecondary, size: 20),
          ),
          const SizedBox(height: 16),

          // Empty value
          Text(
            '--',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textSecondary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: FuturisticColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'No data',
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading Skeleton Card ─────────────────────────────────────────────────────

class _KpiCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Value skeleton
          Container(
            width: double.infinity,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),

          // Title skeleton
          Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
