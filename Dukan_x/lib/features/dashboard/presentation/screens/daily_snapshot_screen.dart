import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/daily_snapshot_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Daily Snapshot Screen
///
/// Shows aggregated daily business metrics:
/// - Today's summary
/// - Comparison with yesterday
/// - Weekly trend
class DailySnapshotScreen extends ConsumerStatefulWidget {
  const DailySnapshotScreen({super.key});

  @override
  ConsumerState<DailySnapshotScreen> createState() =>
      _DailySnapshotScreenState();
}

enum Trend { up, down, neutral }

class _DailySnapshotScreenState extends ConsumerState<DailySnapshotScreen> {
  bool _loading = true;
  DailySnapshot? _todaySnapshot;

  List<DailySnapshot> _weekSnapshots = [];
  Map<String, dynamic> _comparison = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final service = DailySnapshotService();

      // Get today's snapshot
      _todaySnapshot = await service.getTodaySnapshot(userId);

      // Get comparison
      _comparison = await service.getTodayVsYesterday(userId);

      // Get last 7 days for trend
      _weekSnapshots = await service.getLastNDays(userId, 7);

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Daily Snapshot',
      subtitle: DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Summary Card
                _buildTodaySummaryCard(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                const SizedBox(height: 24),

                // Comparison Cards
                _buildComparisonSection(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                const SizedBox(height: 24),

                // Weekly Trend
                _buildWeeklyTrend(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ],
            ),
    );
  }

  Widget _buildTodaySummaryCard(bool isDark) {
    final snapshot =
        _todaySnapshot ?? DailySnapshot.empty(_formatDate(DateTime.now()));

    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 20,
      child: Container(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop: 18.0,
                    ),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: snapshot.isProfitable
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        snapshot.isProfitable
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 16,
                        color: snapshot.isProfitable
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        snapshot.isProfitable ? 'Profitable' : 'Loss',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: snapshot.isProfitable
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main metrics grid — 2x2 on mobile, 4-across on desktop
            if (context.isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildMainMetric('Total Sales', '₹${_formatAmount(snapshot.totalSales)}', Icons.trending_up, const Color(0xFF10B981), isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMainMetric('Collections', '₹${_formatAmount(snapshot.totalReceipts)}', Icons.payments, const Color(0xFF06B6D4), isDark)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMainMetric('Expenses', '₹${_formatAmount(snapshot.totalExpenses)}', Icons.receipt_long, const Color(0xFFEF4444), isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMainMetric('Net Cash Flow', '₹${_formatAmount(snapshot.netCashFlow)}', Icons.account_balance_wallet, snapshot.netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), isDark)),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildMainMetric('Total Sales', '₹${_formatAmount(snapshot.totalSales)}', Icons.trending_up, const Color(0xFF10B981), isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMainMetric('Collections', '₹${_formatAmount(snapshot.totalReceipts)}', Icons.payments, const Color(0xFF06B6D4), isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMainMetric('Expenses', '₹${_formatAmount(snapshot.totalExpenses)}', Icons.receipt_long, const Color(0xFFEF4444), isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMainMetric('Net Cash Flow', '₹${_formatAmount(snapshot.netCashFlow)}', Icons.account_balance_wallet, snapshot.netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), isDark)),
                ],
              ),

            const SizedBox(height: 20),

            // Secondary metrics — Wrap for mobile safety
            Wrap(
              spacing: 24,
              runSpacing: 12,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildSecondaryMetric('Invoices', '${snapshot.invoiceCount}', isDark),
                _buildSecondaryMetric('Customers', '${snapshot.customerCount}', isDark),
                _buildSecondaryMetric('Avg Invoice', '₹${snapshot.avgInvoiceValue.toStringAsFixed(0)}', isDark),
                _buildSecondaryMetric('Outstanding Added', '₹${snapshot.outstandingAdded.toStringAsFixed(0)}', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetric(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: responsiveValue<double>(context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection(bool isDark) {
    final salesChange = _comparison['salesChange'] ?? 0.0;
    final salesChangePercent = _comparison['salesChangePercent'] ?? 0.0;
    final receiptsChange = _comparison['receiptsChange'] ?? 0.0;
    final invoiceChange = _comparison['invoiceCountChange'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'vs Yesterday',
          style: TextStyle(
            fontSize: responsiveValue<double>(context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildComparisonCard(
                'Sales',
                salesChange,
                salesChangePercent,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildComparisonCard(
                'Collections',
                receiptsChange,
                null,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildComparisonCard(
                'Invoices',
                invoiceChange.toDouble(),
                null,
                isDark,
                isCount: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonCard(
    String label,
    double change,
    double? percent,
    bool isDark, {
    bool isCount = false,
  }) {
    final isPositive = change >= 0;
    final color = isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isCount
                      ? '${change.abs().toInt()}'
                      : '₹${_formatAmount(change.abs())}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop: 18.0,
                    ),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: 4),
            Text(
              '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyTrend(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 7 Days',
          style: TextStyle(
            fontSize: responsiveValue<double>(context,
              mobile: 14.0,
              tablet: 16.0,
              desktop: 18.0,
            ),
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: _weekSnapshots.isEmpty
              ? Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weekSnapshots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final snapshot = entry.value;
                    final maxSales = _weekSnapshots
                        .map((s) => s.totalSales)
                        .reduce((a, b) => a > b ? a : b);
                    final height = maxSales > 0
                        ? (snapshot.totalSales / maxSales) * 140
                        : 0.0;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_formatAmount(snapshot.totalSales)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: height.clamp(8.0, 140.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    const Color(0xFF06B6D4),
                                    const Color(0xFF06B6D4).withOpacity(0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getDayLabel(index),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  String _getDayLabel(int index) {
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    if (index == 6) return 'Today';
    if (index == 5) return 'Yest';
    return DateFormat('E').format(date);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
