import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/business_type.dart';
import '../../../../providers/app_state_providers.dart';
import '../providers/pharmacy_dashboard_providers.dart';
import '../widgets/pharmacy/pharmacy_kpi_cards.dart';
import '../widgets/pharmacy/pharmacy_sales_performance_chart.dart';
import '../widgets/pharmacy/pharmacy_prescriptions_category_chart.dart';
import '../widgets/pharmacy/pharmacy_top_products_table.dart';
import '../widgets/pharmacy/pharmacy_inventory_status_chart.dart';
import '../widgets/pharmacy/pharmacy_low_stock_alerts.dart';
import '../widgets/pharmacy/pharmacy_recent_activity_feed.dart';
import '../widgets/pharmacy/pharmacy_patient_feedback.dart';
import '../widgets/pharmacy/pharmacy_date_range_filter.dart';
import '../../../pharmacy/screens/narcotic_register_screen.dart';
import '../../../pharmacy/screens/patient_registry_screen.dart';
import '../../../pharmacy/screens/salt_search_screen.dart';
import '../../../inventory/presentation/screens/batch_tracking_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PharmacyDashboardScreen extends ConsumerStatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  ConsumerState<PharmacyDashboardScreen> createState() =>
      _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState
    extends ConsumerState<PharmacyDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connections for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebSocket();
    });
  }

  void _initializeWebSocket() {
    // Subscribe to real-time events
    ref.read(pharmacyWebSocketProvider.notifier).connect();
  }

  @override
  void dispose() {
    // Clean up WebSocket connections
    ref.read(pharmacyWebSocketProvider.notifier).disconnect();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await ref.read(pharmacyDashboardProvider.notifier).refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth < 1200;

    // Listen for business type changes
    ref.listen(businessTypeProvider, (prev, next) {
      if (prev?.type != next.type && next.type != BusinessType.pharmacy) {
        // Redirect if business type changed away from pharmacy
        context.pushReplacement('/owner_dashboard');
      }
    });

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: Column(
        children: [
          // Top Bar with Pharmacy Branding
          _buildPharmacyTopBar(isMobile),

          // Main Dashboard Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              color: FuturisticColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Filter (Global)
                    const PharmacyDateRangeFilter(),
                    const SizedBox(height: 24),

                    // ── Row 1: KPI Cards ─────────────────────────────
                    const PharmacyKpiCards(),
                    const SizedBox(height: 24),

                    // ── Row 2: Sales Performance + Prescriptions by Category ───────────
                    if (isMobile) ...[
                      const PharmacySalesPerformanceChart(),
                      const SizedBox(height: 16),
                      const PharmacyPrescriptionsCategoryChart(),
                    ] else if (isTablet) ...[
                      const PharmacySalesPerformanceChart(),
                      const SizedBox(height: 16),
                      const PharmacyPrescriptionsCategoryChart(),
                    ] else ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(
                              flex: 2,
                              child: PharmacySalesPerformanceChart(),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 1,
                              child: PharmacyPrescriptionsCategoryChart(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Row 3: Complex Widgets Grid ─────────────────────────
                    if (isMobile) ...[
                      // Mobile: Stacked layout
                      const PharmacyInventoryStatusChart(),
                      const SizedBox(height: 16),
                      const PharmacyLowStockAlerts(),
                      const SizedBox(height: 16),
                      const PharmacyTopProductsTable(),
                      const SizedBox(height: 16),
                      const PharmacyRecentActivityFeed(),
                      const SizedBox(height: 16),
                      const PharmacyPatientFeedback(),
                    ] else if (isTablet) ...[
                      // Tablet: 2-column layout
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  PharmacyInventoryStatusChart(),
                                  SizedBox(height: 16),
                                  PharmacyLowStockAlerts(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  PharmacyTopProductsTable(),
                                  SizedBox(height: 16),
                                  PharmacyRecentActivityFeed(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const PharmacyPatientFeedback(),
                    ] else ...[
                      // Desktop: Full grid layout
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Column: Inventory Status
                            const Expanded(
                              flex: 1,
                              child: PharmacyInventoryStatusChart(),
                            ),
                            const SizedBox(width: 16),
                            // Center Column: Low Stock Alerts
                            const Expanded(
                              flex: 2,
                              child: PharmacyLowStockAlerts(),
                            ),
                            const SizedBox(width: 16),
                            // Right Column: Top Products + Activity + Feedback
                            const Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  PharmacyTopProductsTable(),
                                  SizedBox(height: 16),
                                  Expanded(child: PharmacyRecentActivityFeed()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Bottom Row: Patient Feedback (full width)
                      const PharmacyPatientFeedback(),
                    ],
                    const SizedBox(height: 32), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyTopBar(bool isMobile) {
    return Container(
      height: isMobile ? 60 : 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        child: Row(
          children: [
            // Pharmacy Icon and Name
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FuturisticColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.medical_services_rounded,
                color: FuturisticColors.primary,
                size: isMobile ? 24 : 28,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pharmacy Dashboard',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.textPrimary,
                  ),
                ),
                if (!isMobile)
                  Text(
                    'Real-time pharmacy operations overview',
                    style: TextStyle(
                      fontSize: 12,
                      color: FuturisticColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const Spacer(),

            // Quick Actions
            if (!isMobile) ...[
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PatientRegistryScreen(),
                  ),
                ),
                icon: const Icon(Icons.people_outlined),
                tooltip: 'Patient Registry',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SaltSearchScreen()),
                ),
                icon: const Icon(Icons.science_outlined),
                tooltip: 'Salt / Generic Search',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NarcoticRegisterScreen(),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined, color: Colors.red),
                tooltip: 'Narcotic / Schedule X Register',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BatchTrackingScreen(),
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                tooltip: 'Batch & Expiry Tracking',
              ),
              IconButton(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Dashboard',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
