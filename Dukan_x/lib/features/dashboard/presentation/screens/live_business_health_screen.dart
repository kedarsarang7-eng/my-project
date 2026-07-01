import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';
// import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/bank_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Live Business Health Screen
///
/// Real-time dashboard showing:
/// - Business health score
/// - Cash position
/// - Receivables vs Payables (Payables requires purchase module)
/// - Stock alerts
/// - Today's metrics
class LiveBusinessHealthScreen extends ConsumerStatefulWidget {
  const LiveBusinessHealthScreen({super.key});

  @override
  ConsumerState<LiveBusinessHealthScreen> createState() =>
      _LiveBusinessHealthScreenState();
}

class _LiveBusinessHealthScreenState
    extends ConsumerState<LiveBusinessHealthScreen> {
  bool _loading = true;

  // Health metrics
  int _healthScore = 0;
  String _healthStatus = 'Calculating...';
  Color _healthColor = Colors.grey;

  // Cash metrics
  double _cashBalance = 0;
  double _bankBalance = 0;
  double _totalLiquidity = 0;

  // Receivables
  double _totalReceivables = 0;
  double _overdueAmount = 0;
  int _overdueCount = 0;

  // Stock metrics
  int _lowStockCount = 0;
  double _stockValue = 0;

  // Today's metrics
  double _todaySales = 0;
  double _todayCollections = 0;
  int _todayInvoices = 0;

  /// True when the business has no records at all (no bills, no products, no
  /// bank accounts). In that state a health score would be misleading (it
  /// starts at 100 "Excellent" with nothing to deduct), so we render an
  /// explicit empty state instead.
  bool _hasNoData = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _hasNoData = true; // not logged in -> nothing to score
      });
      return;
    }

    try {
      // Load bills for receivables and today's metrics
      final billsRepo = sl<BillsRepository>();
      final billsResult = await billsRepo.getAll(userId: userId);
      final bills = billsResult.data ?? [];

      // Today's bills
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final todayBills = bills
          .where((b) => b.date.isAfter(startOfDay))
          .toList();

      _todaySales = todayBills.fold(0.0, (sum, b) => sum + b.grandTotal);
      _todayCollections = todayBills.fold(0.0, (sum, b) => sum + b.paidAmount);
      _todayInvoices = todayBills.length;

      // Calculate receivables (unpaid amounts)
      _totalReceivables = 0;
      _overdueAmount = 0;
      _overdueCount = 0;

      for (final bill in bills) {
        final outstanding = bill.grandTotal - bill.paidAmount;
        if (outstanding > 0) {
          _totalReceivables += outstanding;
          // Consider overdue if > 30 days old
          if (bill.date.isBefore(today.subtract(const Duration(days: 30)))) {
            _overdueAmount += outstanding;
            _overdueCount++;
          }
        }
      }

      // Load products for stock metrics
      final productsRepo = sl<ProductsRepository>();
      final productsResult = await productsRepo.getAll(userId: userId);
      final products = productsResult.data ?? [];

      _lowStockCount = products.where((p) => p.isLowStock).length;
      _stockValue = products.fold(
        0.0,
        (sum, p) => sum + (p.stockQuantity * p.costPrice),
      );

      // Load bank balances
      try {
        final bankRepo = sl<BankRepository>();
        final accountsResult = await bankRepo.getAccounts(userId: userId);
        final accounts = accountsResult.data ?? [];

        for (final account in accounts) {
          if (account.accountName.toLowerCase().contains('cash')) {
            _cashBalance += account.currentBalance;
          } else {
            _bankBalance += account.currentBalance;
          }
        }
        _totalLiquidity = _cashBalance + _bankBalance;
      } catch (e) {
        // Bank repo might not have data
      }

      // Determine whether there is any business data to score. A brand-new
      // business with no bills, no products and no bank accounts has no
      // meaningful health score — rendering "100 / Excellent" would be
      // misleading, so we flag it and show an empty state instead.
      _hasNoData = bills.isEmpty && products.isEmpty;

      if (_hasNoData) {
        setState(() => _loading = false);
        return;
      }

      // Calculate health score
      _calculateHealthScore();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      // On error we leave _hasNoData as-is; a load failure is not the same as
      // an empty business, so we do not claim "no data".
    }
  }

  void _calculateHealthScore() {
    int score = 100;

    // Deduct for overdue receivables (max -30)
    if (_totalReceivables > 0) {
      final overduePercent = _overdueAmount / _totalReceivables;
      score -= (overduePercent * 30).toInt();
    }

    // Deduct for low stock (max -20)
    score -= (_lowStockCount * 2).clamp(0, 20);

    // Deduct for low liquidity (max -20)
    if (_totalLiquidity < 10000) {
      score -= 20;
    } else if (_totalLiquidity < 50000) {
      score -= 10;
    }

    // Bonus for good collections today (max +10)
    if (_todaySales > 0 && _todayCollections / _todaySales > 0.8) {
      score += 10;
    }

    _healthScore = score.clamp(0, 100);

    if (_healthScore >= 80) {
      _healthStatus = 'Excellent';
      _healthColor = const Color(0xFF10B981);
    } else if (_healthScore >= 60) {
      _healthStatus = 'Good';
      _healthColor = const Color(0xFF06B6D4);
    } else if (_healthScore >= 40) {
      _healthStatus = 'Attention Needed';
      _healthColor = const Color(0xFFF59E0B);
    } else {
      _healthStatus = 'Critical';
      _healthColor = const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DesktopContentContainer(
      title: 'Live Business Health',
      subtitle: 'Last updated: ${DateFormat('hh:mm a').format(DateTime.now())}',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hasNoData
              ? _buildNoDataState(isDark)
              : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health Score Card
                _buildHealthScoreCard(isDark),
                const SizedBox(height: 24),

                // QuickMetrics
                _buildQuickMetrics(isDark),
                const SizedBox(height: 24),

                // Detailed Cards — stack on mobile, side-by-side on desktop
                if (context.isMobile)
                  Column(
                    children: [
                      _buildCashPositionCard(isDark),
                      const SizedBox(height: 16),
                      _buildReceivablesCard(isDark),
                      const SizedBox(height: 16),
                      _buildStockAlertsCard(isDark),
                      const SizedBox(height: 16),
                      _buildTodayMetricsCard(isDark),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildCashPositionCard(isDark),
                            const SizedBox(height: 16),
                            _buildReceivablesCard(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildStockAlertsCard(isDark),
                            const SizedBox(height: 16),
                            _buildTodayMetricsCard(isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // No-data empty state — shown when the business has no records to score.
  // A health score is meaningless without business data, so we are explicit
  // instead of rendering a misleading "100 / Excellent".
  // ---------------------------------------------------------------------------
  Widget _buildNoDataState(bool isDark) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No Business Data Available',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first bill or add a product to generate your '
              'Business Health Score.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Health Score Card — Column on mobile, Row on desktop
  // ---------------------------------------------------------------------------
  Widget _buildHealthScoreCard(bool isDark) {
    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 20,
      child: Container(
        padding: EdgeInsets.all(
          responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        child: context.isMobile
            ? Column(
                children: [
                  _buildHealthGauge(isDark),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _healthColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _healthStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _healthColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHealthIndicator('Receivables', _overdueCount == 0, isDark),
                  _buildHealthIndicator('Stock Levels', _lowStockCount == 0, isDark),
                  _buildHealthIndicator('Cash Position', _totalLiquidity > 10000, isDark),
                ],
              )
            : Row(
                children: [
                  _buildHealthGauge(isDark),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _healthColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _healthStatus,
                              style: TextStyle(
                                fontSize: responsiveValue<double>(
                                  context,
                                  mobile: 16,
                                  tablet: 18,
                                  desktop: 20,
                                ),
                                fontWeight: FontWeight.bold,
                                color: _healthColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildHealthIndicator('Receivables', _overdueCount == 0, isDark),
                        _buildHealthIndicator('Stock Levels', _lowStockCount == 0, isDark),
                        _buildHealthIndicator('Cash Position', _totalLiquidity > 10000, isDark),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHealthGauge(bool isDark) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: _healthScore / 100,
              strokeWidth: 12,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_healthColor),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_healthScore',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 32.0,
                    tablet: 32.0,
                    desktop: 36.0,
                  ),
                  fontWeight: FontWeight.bold,
                  color: _healthColor,
                ),
              ),
              Text(
                'SCORE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String label, bool isGood, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            size: 16,
            color: isGood ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Metrics — 2x2 grid on mobile, 4-across on desktop
  // ---------------------------------------------------------------------------
  Widget _buildQuickMetrics(bool isDark) {
    final metrics = [
      _buildMetricTile('Today\'s Sales', '₹${_formatAmount(_todaySales)}', Icons.trending_up, const Color(0xFF10B981), isDark),
      _buildMetricTile('Collections', '₹${_formatAmount(_todayCollections)}', Icons.payments, const Color(0xFF06B6D4), isDark),
      _buildMetricTile('Receivables', '₹${_formatAmount(_totalReceivables)}', Icons.account_balance_wallet, const Color(0xFFF59E0B), isDark),
      _buildMetricTile('Liquidity', '₹${_formatAmount(_totalLiquidity)}', Icons.savings, const Color(0xFF8B5CF6), isDark),
    ];

    if (context.isMobile) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: metrics[0]),
            const SizedBox(width: 12),
            Expanded(child: metrics[1]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: metrics[2]),
            const SizedBox(width: 12),
            Expanded(child: metrics[3]),
          ]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: metrics[0]),
        const SizedBox(width: 12),
        Expanded(child: metrics[1]),
        const SizedBox(width: 12),
        Expanded(child: metrics[2]),
        const SizedBox(width: 12),
        Expanded(child: metrics[3]),
      ],
    );
  }

  Widget _buildMetricTile(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
            ],
          ),
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

  // ---------------------------------------------------------------------------
  // Detail Cards
  // ---------------------------------------------------------------------------
  Widget _buildCashPositionCard(bool isDark) {
    return _buildCard(
      isDark,
      'Cash Position',
      Icons.account_balance,
      const Color(0xFF10B981),
      Column(
        children: [
          _buildDetailRow(
            'Cash in Hand',
            '₹${_formatAmount(_cashBalance)}',
            isDark,
          ),
          _buildDetailRow(
            'Bank Balance',
            '₹${_formatAmount(_bankBalance)}',
            isDark,
          ),
          const Divider(height: 24),
          _buildDetailRow(
            'Total Liquidity',
            '₹${_formatAmount(_totalLiquidity)}',
            isDark,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivablesCard(bool isDark) {
    return _buildCard(
      isDark,
      'Receivables',
      Icons.receipt_long,
      const Color(0xFFF59E0B),
      Column(
        children: [
          _buildDetailRow(
            'Total Outstanding',
            '₹${_formatAmount(_totalReceivables)}',
            isDark,
          ),
          _buildDetailRow(
            'Overdue (>30 days)',
            '₹${_formatAmount(_overdueAmount)}',
            isDark,
            valueColor: const Color(0xFFEF4444),
          ),
          _buildDetailRow('Overdue Invoices', '$_overdueCount', isDark),
        ],
      ),
    );
  }

  Widget _buildStockAlertsCard(bool isDark) {
    return _buildCard(
      isDark,
      'Stock Alerts',
      Icons.inventory_2,
      const Color(0xFFEF4444),
      Column(
        children: [
          _buildDetailRow(
            'Low Stock Items',
            '$_lowStockCount',
            isDark,
            valueColor: _lowStockCount > 0 ? const Color(0xFFF59E0B) : null,
          ),
          _buildDetailRow(
            'Stock Value',
            '₹${_formatAmount(_stockValue)}',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMetricsCard(bool isDark) {
    return _buildCard(
      isDark,
      'Today\'s Activity',
      Icons.today,
      const Color(0xFF06B6D4),
      Column(
        children: [
          _buildDetailRow('Invoices Created', '$_todayInvoices', isDark),
          _buildDetailRow(
            'Total Sales',
            '₹${_formatAmount(_todaySales)}',
            isDark,
          ),
          _buildDetailRow(
            'Collected',
            '₹${_formatAmount(_todayCollections)}',
            isDark,
          ),
          _buildDetailRow(
            'Collection Rate',
            _todaySales > 0
                ? '${((_todayCollections / _todaySales) * 100).toStringAsFixed(0)}%'
                : 'N/A',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    bool isDark,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
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
