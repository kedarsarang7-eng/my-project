import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../providers/dashboard_v2_providers.dart';
import '../widgets/dashboard_top_bar.dart';
import '../widgets/performance_cards.dart';
import '../widgets/revenue_chart_section.dart';
import '../widgets/invoice_distribution_chart.dart';
import '../widgets/recent_invoices_table.dart';
import '../widgets/cashflow_forecast_section.dart';
import '../widgets/business_alerts_widget.dart';
import '../widgets/business_quick_actions.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DashboardV2Screen extends ConsumerStatefulWidget {
  const DashboardV2Screen({super.key});

  @override
  ConsumerState<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends ConsumerState<DashboardV2Screen> {
  @override
  Widget build(BuildContext context) {
    // Re-fetch all data when business type changes
    ref.listen(businessTypeProvider, (prev, next) {
      if (prev?.type != next.type) {
        _refreshAll();
      }
    });

    // Activate grocery real-time WebSocket subscriptions
    ref.watch(groceryWebSocketProvider);

    // License gate
    final licenseAsync = ref.watch(dashboardV2LicenseProvider);

    return Container(
      color: FuturisticColors.background,
      child: licenseAsync.when(
        data: (license) {
          if (license != null && !license.valid) {
            return _buildLicenseExpired(license.status);
          }
          return _buildDashboard();
        },
        loading: () => _buildDashboard(),
        error: (_, _) => _buildDashboard(),
      ),
    );
  }

  Widget _buildDashboard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Reset inherited text decoration to prevent underline leak from ancestors
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Column(
        children: [
          // Top bar
          const DashboardTopBar(),

          // Scrollable content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              color: FuturisticColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Performance Cards ─────────────────────────────
                    const PerformanceCards(),
                    const SizedBox(height: 24),

                    // ── Charts Row (Revenue + Distribution) ───────────
                    if (isMobile) ...[
                      const RevenueChartSection(),
                      const SizedBox(height: 16),
                      const InvoiceDistributionChart(),
                    ] else ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(
                              flex: 3,
                              child: RevenueChartSection(),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 2,
                              child: InvoiceDistributionChart(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Recent Invoices Table ─────────────────────────
                    const RecentInvoicesTable(),
                    const SizedBox(height: 24),

                    // ── Business Alerts & Quick Actions ──────────────
                    if (isMobile) ...[
                      const BusinessAlertsWidget(),
                      const SizedBox(height: 16),
                      const BusinessQuickActions(),
                      const SizedBox(height: 16),
                      const CashflowForecastSection(),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Alerts Panel
                          const Expanded(
                            flex: 1,
                            child: BusinessAlertsWidget(),
                          ),
                          const SizedBox(width: 16),
                          // Quick Actions panel
                          const Expanded(
                            flex: 1,
                            child: BusinessQuickActions(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const CashflowForecastSection(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseExpired(String status) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: FuturisticColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FuturisticColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FuturisticColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: FuturisticColors.error, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'License Expired',
              style: TextStyle(
                color: FuturisticColors.textPrimary,
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your subscription has expired. Please renew to continue using DukanX.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FuturisticColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Renew License',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    ref.invalidate(dashboardV2SummaryProvider);
    ref.invalidate(dashboardV2RevenueChartProvider);
    ref.invalidate(dashboardV2InvoiceDistributionProvider);
    ref.invalidate(dashboardV2RecentInvoicesProvider);
    ref.invalidate(dashboardV2CashflowProvider);
    ref.invalidate(dashboardV2NotificationCountProvider);
    ref.invalidate(dashboardV2LicenseProvider);
  }
}

