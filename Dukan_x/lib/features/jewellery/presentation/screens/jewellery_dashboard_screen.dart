// ============================================================================
// JEWELLERY DASHBOARD SCREEN
// ============================================================================
// Dedicated dashboard for jewellery vendors (Requirement 13.1, 13.2, 13.6).
// Renders KPI cards and a gold-rate ticker — every value sourced from
// repository/provider queries. No hardcoded numeric values.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../data/models/jewellery_product_model.dart';
import '../../data/models/gold_scheme_model.dart';
import '../../data/models/jewellery_repair_model.dart';
import '../../data/repositories/jewellery_repository_offline.dart';
import '../../data/repositories/gold_scheme_repository.dart';
import '../../data/repositories/jewellery_repair_repository.dart';

/// Dashboard data model — all values loaded from repositories.
class _JewelleryDashboardData {
  final GoldRateCard? latestGoldRate;
  final double totalMetalStockGrams;
  final int pendingCustomOrders;
  final int schemeCollectionsDue;
  final int repairJobsInProgress;
  final String? errorMessage;

  const _JewelleryDashboardData({
    this.latestGoldRate,
    this.totalMetalStockGrams = 0,
    this.pendingCustomOrders = 0,
    this.schemeCollectionsDue = 0,
    this.repairJobsInProgress = 0,
    this.errorMessage,
  });
}

class JewelleryDashboardScreen extends StatefulWidget {
  const JewelleryDashboardScreen({super.key});

  @override
  State<JewelleryDashboardScreen> createState() =>
      _JewelleryDashboardScreenState();
}

class _JewelleryDashboardScreenState extends State<JewelleryDashboardScreen> {
  final JewelleryRepositoryOffline _jewelleryRepo = JewelleryRepositoryOffline(
    sl(),
    sl<SessionManager>(),
  );
  final GoldSchemeRepository _schemeRepo = GoldSchemeRepository(
    sl(),
    sl<SessionManager>(),
  );
  final JewelleryRepairRepository _repairRepo = JewelleryRepairRepository(
    sl(),
    sl<SessionManager>(),
  );

  _JewelleryDashboardData _data = const _JewelleryDashboardData();
  bool _loading = true;

  // Gold-rate ticker state
  Timer? _tickerTimer;
  List<GoldRateCard> _rateHistory = [];
  int _tickerIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);

    try {
      // All values sourced from repository queries (Requirement 13.6)
      final results = await Future.wait([
        _jewelleryRepo.getTodayGoldRate(), // KPI: gold rate
        _loadMetalStock(), // KPI: metal stock by weight
        _jewelleryRepo.getOrders(status: 'PENDING'), // KPI: pending orders
        _loadSchemeCollectionsDue(), // KPI: scheme collections due
        _loadRepairJobsInProgress(), // KPI: repair jobs in progress
        _jewelleryRepo.getGoldRateHistory(days: 7), // Ticker data
      ]);

      final goldRate = results[0] as GoldRateCard?;
      final metalStock = results[1] as double;
      final pendingOrders = results[2] as List<JewelleryOrder>;
      final schemeDue = results[3] as int;
      final repairsInProgress = results[4] as int;
      final rateHistory = results[5] as List<GoldRateCard>;

      if (mounted) {
        setState(() {
          _data = _JewelleryDashboardData(
            latestGoldRate: goldRate,
            totalMetalStockGrams: metalStock,
            pendingCustomOrders: pendingOrders.length,
            schemeCollectionsDue: schemeDue,
            repairJobsInProgress: repairsInProgress,
          );
          _rateHistory = rateHistory;
          _loading = false;
        });

        _startTicker();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = _JewelleryDashboardData(errorMessage: e.toString());
          _loading = false;
        });
      }
    }
  }

  /// Calculate total metal stock by weight from all active products.
  Future<double> _loadMetalStock() async {
    final products = await _jewelleryRepo.getProducts();
    double total = 0;
    for (final p in products) {
      if (p.isActive && !p.isDeleted) {
        total += p.metalWeightGrams * p.stockQuantity;
      }
    }
    return total;
  }

  /// Count scheme enrollments with overdue/due payments.
  Future<int> _loadSchemeCollectionsDue() async {
    final schemes = await _schemeRepo.getOverdueSchemes();
    return schemes.length;
  }

  /// Count repair jobs currently in progress.
  Future<int> _loadRepairJobsInProgress() async {
    final repairs = await _repairRepo.getRepairs(
      status: RepairStatus.inProgress,
    );
    return repairs.length;
  }

  /// Start a gold-rate ticker that cycles through recent rate history.
  void _startTicker() {
    _tickerTimer?.cancel();
    if (_rateHistory.isEmpty) return;

    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _rateHistory.isNotEmpty) {
        setState(() {
          _tickerIndex = (_tickerIndex + 1) % _rateHistory.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeDesktop = screenWidth >= 1440;
    final isDesktop = screenWidth >= 1024;

    final horizontalPadding = isLargeDesktop ? 32.0 : (isDesktop ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: _loading
          ? _buildLoadingSkeleton()
          : _data.errorMessage != null
          ? _buildErrorWidget()
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildGoldRateTicker(),
                    const SizedBox(height: 24),
                    _buildKpiCards(isDesktop: isDesktop),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.diamond_outlined, color: FuturisticColors.primary, size: 28),
        const SizedBox(width: 12),
        Text(
          'Jewellery Dashboard',
          style: TextStyle(
            fontSize: responsiveValue<double>(
              context,
              mobile: 20,
              tablet: 24,
              desktop: 28,
            ),
            fontWeight: FontWeight.bold,
            color: FuturisticColors.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadDashboardData,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // GOLD RATE TICKER (Requirement 13.2)
  // Sourced from live GoldRateCard data via JewelleryRepositoryOffline
  // --------------------------------------------------------------------------
  Widget _buildGoldRateTicker() {
    final rate = _data.latestGoldRate;
    if (rate == null && _rateHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade700),
            const SizedBox(width: 12),
            Text(
              'No gold rate data available. Set today\'s rate to see the ticker.',
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ],
        ),
      );
    }

    // Use the ticker index to show cycling rates from history
    final tickerRate = _rateHistory.isNotEmpty
        ? _rateHistory[_tickerIndex]
        : rate!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade700, Colors.amber.shade900],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Gold Rates',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${tickerRate.date})',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          _buildTickerItem(
            '24K',
            _formatRatePer10g(tickerRate.gold24KPer10gPaisa),
          ),
          const SizedBox(width: 20),
          _buildTickerItem(
            '22K',
            _formatRatePer10g(tickerRate.gold22KPer10gPaisa),
          ),
          const SizedBox(width: 20),
          _buildTickerItem(
            '18K',
            _formatRatePer10g(tickerRate.gold18KPer10gPaisa),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // KPI CARDS (Requirement 13.1)
  // All values from repository queries — no hardcoded values (Req 13.6)
  // --------------------------------------------------------------------------
  Widget _buildKpiCards({required bool isDesktop}) {
    final rate = _data.latestGoldRate;

    final kpis = <_KpiCardData>[
      _KpiCardData(
        title: 'Gold 24K (per 10g)',
        value: rate != null ? _formatRatePer10g(rate.gold24KPer10gPaisa) : '—',
        icon: Icons.grade,
        color: Colors.amber,
      ),
      _KpiCardData(
        title: 'Gold 22K (per 10g)',
        value: rate != null ? _formatRatePer10g(rate.gold22KPer10gPaisa) : '—',
        icon: Icons.grade_outlined,
        color: Colors.orange,
      ),
      _KpiCardData(
        title: 'Gold 18K (per 10g)',
        value: rate != null ? _formatRatePer10g(rate.gold18KPer10gPaisa) : '—',
        icon: Icons.star_border,
        color: Colors.deepOrange,
      ),
      _KpiCardData(
        title: 'Metal Stock',
        value: '${_data.totalMetalStockGrams.toStringAsFixed(2)} g',
        icon: Icons.inventory_2_outlined,
        color: Colors.blue,
      ),
      _KpiCardData(
        title: 'Pending Custom Orders',
        value: _data.pendingCustomOrders.toString(),
        icon: Icons.assignment_outlined,
        color: Colors.purple,
      ),
      _KpiCardData(
        title: 'Scheme Collections Due',
        value: _data.schemeCollectionsDue.toString(),
        icon: Icons.savings_outlined,
        color: Colors.green,
      ),
      _KpiCardData(
        title: 'Repairs In Progress',
        value: _data.repairJobsInProgress.toString(),
        icon: Icons.build_outlined,
        color: Colors.teal,
      ),
    ];

    if (isDesktop) {
      // Desktop: wrap in responsive rows
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: kpis
            .map((kpi) => SizedBox(width: 220, child: _buildKpiCard(kpi)))
            .toList(),
      );
    }

    // Tablet/Mobile: 2-column grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.6,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) => _buildKpiCard(kpis[index]),
    );
  }

  Widget _buildKpiCard(_KpiCardData kpi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kpi.icon, color: kpi.color, size: 24),
          const SizedBox(height: 8),
          Text(
            kpi.title,
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            kpi.value,
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 18,
                desktop: 20,
              ),
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------

  /// Format a paise-per-10g value to a rupee display string.
  String _formatRatePer10g(int paisa) {
    final rupees = paisa / 100;
    return '₹${rupees.toStringAsFixed(0)}';
  }

  Widget _buildLoadingSkeleton() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: FuturisticColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _data.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FuturisticColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal data class for KPI card rendering.
class _KpiCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
