// ============================================================================
// ANALYTICS DASHBOARD - PREMIUM UI
// ============================================================================
// Enterprise-grade analytics dashboard with beautiful visualizations
//
// Author: DukanX Engineering
// Version: 2.0.0 (Futuristic Upgrade)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/sync/sync_manager.dart'; // Import SyncManager

import '../../core/di/service_locator.dart';
import '../../core/repository/reports_repository.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/futuristic_colors.dart';
import '../../models/daily_stats.dart';
import '../../widgets/glass_container.dart';
import '../insights/presentation/widgets/health_score_card.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedPeriod = 'This Month';

  // Repository references
  late final ReportsRepository _reportsRepository;
  late final SessionManager _sessionManager;
  StreamSubscription<DailyStats>? _statsSubscription;
  StreamSubscription<SyncHealthMetrics>?
  _syncSubscription; // Add sync subscription

  // Real-time stats from ReportsRepository
  Map<String, dynamic> _stats = {
    'todaySales': 0.0,
    'todayCollections': 0.0,
    'todayBillCount': 0,
    'monthlySales': 0.0,
    'monthlyCollections': 0.0,
    'monthlyBillCount': 0,
    'totalDues': 0.0,
    'customerCount': 0,
    'lowStockCount': 0,
    'pendingSyncCount': 0,
  };

  // Sales data from getSalesTrend
  List<Map<String, dynamic>> _weeklySales = [];

  // Category sales data from getCategorySalesBreakdown
  List<Map<String, dynamic>> _categorySales = [];

  // Top products from getProductSalesBreakdown
  List<Map<String, dynamic>> _topProducts = [];

  // Accurate today-vs-yesterday KPI trends. Each is null when there is no
  // prior-period data to compare against (in which case the badge is hidden
  // rather than showing a fabricated number).
  double? _salesTrend;
  double? _collectionsTrend;
  double? _duesTrend;
  double? _customersTrend;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Initialize repository references
    _reportsRepository = sl<ReportsRepository>();
    _sessionManager = sl<SessionManager>();

    // Start loading real data
    _initializeDataStreams();
  }

  /// Initialize data streams and load analytics data
  void _initializeDataStreams() {
    final userId = _sessionManager.ownerId;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Subscribe to real-time daily stats stream
    _statsSubscription = _reportsRepository
        .watchDailyStats(userId)
        .listen(
          (DailyStats stats) {
            if (mounted) {
              setState(() {
                _stats = {
                  'todaySales': stats.todaySales,
                  'todayCollections': stats.todayCollections,
                  'todayBillCount': stats.todayBillCount,
                  'monthlySales': stats.todaySales,
                  'monthlyCollections': stats.paidThisMonth,
                  'monthlyBillCount': stats.monthlyBillCount,
                  'totalDues': stats.totalPending,
                  'customerCount': stats.customerCount,
                  'lowStockCount': stats.lowStockCount,
                  'pendingSyncCount': 0, // Populated from sync manager below
                };
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            debugPrint('Analytics stats stream error: $error');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        );

    // Load sales trend data
    _loadSalesTrend(userId);

    // Load accurate today-vs-yesterday KPI trends
    _loadTrends(userId);

    // Load category sales data
    _loadCategorySales(userId);

    // Load top products
    _loadTopProducts(userId);

    // Subscribe to Sync Status
    _subscribeToSyncStatus();
  }

  void _subscribeToSyncStatus() {
    // Check if SyncManager is registered in SL, otherwise use instance if available or mock
    // Assuming SyncManager is a singleton or registered in SL
    try {
      final syncManager = sl<SyncManager>();
      _syncSubscription = syncManager.syncStatusStream.listen((metrics) {
        if (mounted) {
          setState(() {
            _stats['pendingSyncCount'] = metrics.pendingCount;
          });
        }
      });
      // Initial fetch
      syncManager.getHealthMetrics().then((metrics) {
        if (mounted) {
          setState(() {
            _stats['pendingSyncCount'] = metrics.pendingCount;
          });
        }
      });
    } catch (e) {
      // SyncManager might not be ready or registered yet
      debugPrint('SyncManager not ready: $e');
    }
  }

  /// Load weekly sales trend
  Future<void> _loadSalesTrend(String userId) async {
    final result = await _reportsRepository.getSalesTrend(
      userId: userId,
      days: 7,
    );

    if (result.isSuccess && result.data != null && mounted) {
      final trend = result.data!;
      final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

      // Convert to the format expected by the chart
      final Map<String, Map<String, dynamic>> dailyData = {};
      for (var entry in trend) {
        final parts = (entry['date'] as String).split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          // Only show last 7 days including today
          if (date.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
            final dayName = weekDays[date.weekday % 7];
            dailyData[dayName] = {
              'day': dayName,
              'sales': entry['value'] ?? 0.0,
              // NOTE: 'collection' intentionally omitted. The sales-trend data
              // source does not provide per-day collections, so we do not
              // fabricate one (previously this was sales * 0.85, a fake value
              // displayed as a distinct metric).
            };
          }
        }
      }

      setState(() {
        _weeklySales = dailyData.values.toList();
      });
    }
  }

  /// Load accurate today-vs-yesterday trends for the four KPI cards.
  ///
  /// All figures come straight from bill rows (see
  /// [ReportsRepository.getDailyComparison]). A trend is left null when the
  /// prior day had no comparable data, so the badge is hidden instead of
  /// inventing a number. The dues trend is inverted: a *decrease* in dues is
  /// favourable, so the sign is flipped so the badge colour reflects whether
  /// the change is good rather than raw up/down.
  Future<void> _loadTrends(String userId) async {
    final cmp = await _reportsRepository.getDailyComparison(userId);
    if (!mounted) return;

    setState(() {
      _salesTrend = trendPercent(
        current: cmp.todaySales,
        previous: cmp.yesterdaySales,
      );
      _collectionsTrend = trendPercent(
        current: cmp.todayCollections,
        previous: cmp.yesterdayCollections,
      );
      _duesTrend = trendPercent(
        current: cmp.duesEndOfToday,
        previous: cmp.duesEndOfYesterday,
        invert: true,
      );
      _customersTrend = trendPercent(
        current: cmp.customersToday.toDouble(),
        previous: cmp.customersYesterday.toDouble(),
      );
    });
  }

  /// Load category sales breakdown
  Future<void> _loadCategorySales(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final result = await _reportsRepository.getCategorySalesBreakdown(
      userId: userId,
      start: startOfMonth,
      end: now,
    );

    if (result.isSuccess && result.data != null && mounted) {
      setState(() {
        _categorySales = result.data!;
      });
    }
  }

  /// Load top selling products
  Future<void> _loadTopProducts(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final result = await _reportsRepository.getProductSalesBreakdown(
      userId: userId,
      start: startOfMonth,
      end: now,
    );

    if (result.isSuccess && result.data != null && mounted) {
      final products = result.data!
          .take(5)
          .map(
            (p) => {
              'name': p['name'] ?? 'Unknown',
              'quantity': (p['quantity'] ?? 0).toInt(),
              'revenue': p['total'] ?? 0.0,
            },
          )
          .toList();

      setState(() {
        _topProducts = products;
      });
    }
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _syncSubscription?.cancel(); // Cancel sync subscription
    _animationController.dispose();
    super.dispose();
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    if (number is double) {
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '',
        decimalDigits: 0,
      );
      return formatter.format(number);
    }
    return number.toString();
  }

  /// Formats an accurate period-over-period change for a KPI badge.
  ///
  /// Returns null (so the badge is hidden) when [trend] is null — which happens
  /// when the prior period had no comparable data. This keeps the dashboard
  /// honest: we never show a trend we cannot compute.
  String? _formatTrend(double? trend) {
    if (trend == null) return null;
    final sign = trend >= 0 ? '+' : '';
    return '$sign${trend.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    // Force dark mode logic for futuristic theme
    // final isDark = Theme.of(context).brightness == Brightness.dark;
    const isDark = true; // Dashboard is always dark/futuristic
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: FuturisticColors.darkBackgroundGradient,
        ),

        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: FuturisticColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading Analytics...',
                        style: GoogleFonts.inter(
                          color: FuturisticColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // App Bar
                      _buildAppBar(isDark),

                      // Period Selector
                      SliverToBoxAdapter(child: _buildPeriodSelector(isDark)),

                      // Stats Cards
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 4 : 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: isWide ? 1.5 : 1.2,
                              ),
                          delegate: SliverChildListDelegate([
                            _buildStatsCard(
                              'Today Sales',
                              '₹${_formatNumber(_stats['todaySales'])}',
                              Icons.trending_up,
                              FuturisticColors.success,
                              _formatTrend(_salesTrend),
                              isDark,
                            ),
                            _buildStatsCard(
                              'Collections',
                              '₹${_formatNumber(_stats['todayCollections'])}',
                              Icons.account_balance_wallet,
                              FuturisticColors.primary,
                              _formatTrend(_collectionsTrend),
                              isDark,
                            ),
                            _buildStatsCard(
                              'Total Dues',
                              '₹${_formatNumber(_stats['totalDues'])}',
                              Icons.receipt_long,
                              FuturisticColors.error,
                              _formatTrend(_duesTrend),
                              isDark,
                            ),
                            _buildStatsCard(
                              'Customers',
                              '${_stats['customerCount']}',
                              Icons.people,
                              FuturisticColors.accent2,
                              _formatTrend(_customersTrend),
                              isDark,
                            ),
                          ]),
                        ),
                      ),

                      // Charts Section
                      SliverToBoxAdapter(
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildSalesChart(isDark)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildRevenueDonutChart(isDark),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildSalesChart(isDark),
                                  const SizedBox(height: 16),
                                  _buildRevenueDonutChart(isDark),
                                ],
                              ),
                      ),

                      // Top Products Section
                      SliverToBoxAdapter(
                        child: _buildTopProductsSection(isDark),
                      ),

                      // Health Status
                      SliverToBoxAdapter(child: _buildHealthStatus(isDark)),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_rounded,
                    color: FuturisticColors.accent1,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analytics Dashboard',
                    style: GoogleFonts.outfit(
                      color: FuturisticColors.textPrimary,
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 22,
                        tablet: 24,
                        desktop: 28,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildSyncIndicator(),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: FuturisticColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Real-time business insights',
                    style: GoogleFonts.inter(
                      color: FuturisticColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    final pendingCount = _stats['pendingSyncCount'] as int;
    final isSynced = pendingCount == 0;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: BorderRadius.circular(20),
      color: isSynced ? FuturisticColors.success : FuturisticColors.warning,
      opacity: 0.1,
      border: Border.all(
        color: (isSynced ? FuturisticColors.success : FuturisticColors.warning)
            .withOpacity(0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_sync,
            color: isSynced
                ? FuturisticColors.success
                : FuturisticColors.warning,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Synced' : '$pendingCount pending',
            style: GoogleFonts.inter(
              color: isSynced
                  ? FuturisticColors.success
                  : FuturisticColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Today', 'This Week', 'This Month', 'This Year'];
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected ? FuturisticColors.primaryGradient : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.08),
                ),
                boxShadow: isSelected
                    ? FuturisticColors.neonShadow(FuturisticColors.primary)
                    : null,
              ),
              child: Text(
                period,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? Colors.white
                      : FuturisticColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String? change,
    bool isDark,
  ) {
    // Trend badge is rendered only when a real period-over-period change is
    // available. A null `change` omits the badge entirely rather than showing
    // a fabricated percentage (data-integrity rule: never display mock values).
    final isPositive = change != null && change.startsWith('+');

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isPositive
                                ? FuturisticColors.success
                                : FuturisticColors.error)
                            .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isPositive
                            ? FuturisticColors.success
                            : FuturisticColors.error,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        change,
                        style: GoogleFonts.inter(
                          color: isPositive
                              ? FuturisticColors.success
                              : FuturisticColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: FuturisticColors.textPrimary,
              fontSize: responsiveValue<double>(
                context,
                mobile: 20,
                tablet: 22,
                desktop: 26,
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: FuturisticColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(bool isDark) {
    // Handle empty data gracefully
    if (_weeklySales.isEmpty) {
      return GlassContainer(
        height: 350,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.bar_chart_outlined,
                size: 48,
                color: FuturisticColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                'No Sales Data',
                style: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassContainer(
      height: 350,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Overview',
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  _legendDot(FuturisticColors.primary, 'Sales'),
                  // 'Collection' series removed: the sales-trend source provides
                  // no per-day collection data, so we show only the real series.
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                // maxY: 35000, // Remove fixed maxY to allow dynamic scaling
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => FuturisticColors.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = _weeklySales[groupIndex]['day'];
                      return BarTooltipItem(
                        '$day\n₹${_formatNumber(rod.toY)}',
                        GoogleFonts.inter(
                          color: FuturisticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < _weeklySales.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weeklySales[value.toInt()]['day'],
                              style: GoogleFonts.inter(
                                color: FuturisticColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${(value / 1000).toStringAsFixed(0)}k',
                        style: GoogleFonts.inter(
                          color: FuturisticColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      5000, // Dynamic interval preferably, but fixed for now
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_weeklySales.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklySales[i]['sales'].toDouble(),
                        color: FuturisticColors.primary,
                        gradient: FuturisticColors.primaryGradient,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 50000,
                          /* This should be dynamic max value */
                          color: Colors.white.withOpacity(0.02),
                        ),
                      ),
                      // Collection rod removed: no real per-day collection data
                      // is available from the sales-trend source.
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: FuturisticColors.neonShadow(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: FuturisticColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueDonutChart(bool isDark) {
    return GlassContainer(
      height: 350,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Category',
            style: GoogleFonts.outfit(
              color: FuturisticColors.textPrimary,
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _categorySales.isEmpty
                ? Center(
                    child: Text(
                      'No Category Data',
                      style: GoogleFonts.inter(
                        color: FuturisticColors.textDisabled,
                        fontSize: 14,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: List.generate(_categorySales.length, (i) {
                              final category = _categorySales[i];
                              final total =
                                  _stats['monthlySales'] as double? ?? 1.0;
                              final value = category['total'] as double;
                              final percent =
                                  (value / (total == 0 ? 1 : total)) * 100;

                              // Cycle through accent colors
                              final List<Color> colors = [
                                FuturisticColors.primary,
                                FuturisticColors.accent1,
                                FuturisticColors.accent2,
                                FuturisticColors.success,
                                FuturisticColors.warning,
                              ];
                              final color = colors[i % colors.length];

                              return PieChartSectionData(
                                value: value,
                                title: '${percent.toInt()}%',
                                color: color,
                                radius: 50,
                                titleStyle: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                badgeWidget: _buildCategoryBadge(
                                  category['category'] as String,
                                ),
                                badgePositionPercentageOffset: 1.3,
                              );
                            }),
                          ),
                        ),
                      ),
                      // Legend
                      Expanded(
                        flex: 3,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(left: 16),
                          itemCount: _categorySales.take(5).length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final category = _categorySales[i];
                            final List<Color> colors = [
                              FuturisticColors.primary,
                              FuturisticColors.accent1,
                              FuturisticColors.accent2,
                              FuturisticColors.success,
                              FuturisticColors.warning,
                            ];
                            final color = colors[i % colors.length];

                            return Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category['category'],
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: FuturisticColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: FuturisticColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        category.length > 5 ? category.substring(0, 5) : category,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildTopProductsSection(bool isDark) {
    // Handle empty data gracefully
    if (_topProducts.isEmpty) {
      return GlassContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: FuturisticColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                'No Product Data',
                style: GoogleFonts.inter(
                  color: FuturisticColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Products',
                style: GoogleFonts.outfit(
                  color: FuturisticColors.textPrimary,
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/inventory'),
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    color: FuturisticColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return _buildProductItem(index + 1, product, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildProductItem(
    int rank,
    Map<String, dynamic> product,
    bool isDark,
  ) {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
      FuturisticColors.textDisabled,
      FuturisticColors.textDisabled,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors[rank - 1].withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: rank <= 3
                  ? FuturisticColors.neonShadow(colors[rank - 1])
                  : null,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: GoogleFonts.outfit(
                  color: colors[rank - 1],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${product['quantity']} units sold',
                  style: GoogleFonts.inter(
                    color: FuturisticColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${_formatNumber(product['revenue'])}',
            style: GoogleFonts.inter(
              color: FuturisticColors.success,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatus(bool isDark) {
    // Check if we have userId provided, if not use fallback or retrieve from session
    // For now, using hardcoded userId if not available in widget props
    // In production, AnalyticsDashboardScreen should receive userId
    final userId = _sessionManager.ownerId ?? 'current_user_id';

    return HealthScoreCard(userId: userId, isDark: isDark);
  }
}
