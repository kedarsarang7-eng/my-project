import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/revenue_repository.dart';
import '../../../../providers/app_state_providers.dart';
// import '../../../../models/bill.dart'; // Unnecessary
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Revenue Overview Screen
///
/// Analytics dashboard for revenue metrics:
/// - Total sales, collections, outstanding
/// - Returns and refunds
/// - Trends and charts
class RevenueOverviewScreen extends ConsumerStatefulWidget {
  const RevenueOverviewScreen({super.key});

  @override
  ConsumerState<RevenueOverviewScreen> createState() =>
      _RevenueOverviewScreenState();
}

class _RevenueOverviewScreenState extends ConsumerState<RevenueOverviewScreen> {
  bool _loading = true;
  String _selectedPeriod = 'This Month';

  // Metrics
  double _totalSales = 0;
  double _totalCollections = 0;
  double _totalOutstanding = 0;
  double _totalReturns = 0;
  int _invoiceCount = 0;
  int _paidInvoices = 0;
  int _partialInvoices = 0;
  int _unpaidInvoices = 0;

  List<Bill> _recentBills = [];

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
      final billsRepo = sl<BillsRepository>();
      final result = await billsRepo.getAll(userId: userId);
      final bills = result.data ?? [];

      // Filter by period
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'This Year':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
      }

      final filteredBills = bills
          .where((b) => b.date.isAfter(startDate))
          .toList();

      // Calculate metrics
      _totalSales = 0;
      _totalCollections = 0;
      _invoiceCount = filteredBills.length;
      _paidInvoices = 0;
      _partialInvoices = 0;
      _unpaidInvoices = 0;

      for (final bill in filteredBills) {
        _totalSales += bill.grandTotal;
        _totalCollections += bill.paidAmount;

        if (bill.paidAmount >= bill.grandTotal) {
          _paidInvoices++;
        } else if (bill.paidAmount > 0) {
          _partialInvoices++;
        } else {
          _unpaidInvoices++;
        }
      }

      _totalOutstanding = _totalSales - _totalCollections;

      // Get returns from revenue repo
      try {
        final revenueRepo = sl<RevenueRepository>();
        // Get snapshot of returns
        final returns = await revenueRepo.watchReturns(userId).first;

        // Filter returns by selected period
        final filteredReturns = returns
            .where((r) => r.date.isAfter(startDate))
            .toList();

        _totalReturns = filteredReturns.fold(
          0,
          (sum, item) => sum + item.totalReturnAmount,
        );
      } catch (e) {
        debugPrint('Error loading returns: $e');
        _totalReturns = 0;
      }

      // Recent bills
      _recentBills = filteredBills.take(10).toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Revenue Overview',
      subtitle: '$_invoiceCount invoices in $_selectedPeriod',
      actions: [
        // Period Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPeriod,
              dropdownColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
              items: [
                'Today',
                'This Week',
                'This Month',
                'This Year',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPeriod = value);
                  _loadData();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
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
                _buildMetricsCards(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                const SizedBox(height: 24),
                _buildInvoiceBreakdown(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                const SizedBox(height: 24),
                _buildRecentInvoices(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ],
            ),
    );
  }

  Widget _buildMetricsCards(bool isDark) {
    // Build the four metric cards once, then arrange them responsively:
    //   • mobile  → 2×2 grid (each card wide enough to render ₹ values)
    //   • tablet+ → single row of four (original layout)
    // On narrow phones four equal columns leave ~80dp each, forcing ₹ amounts
    // to overflow/wrap even at the default text scale.
    final cards = <Widget>[
      _buildMetricCard(
        'Total Sales',
        '₹${_formatAmount(_totalSales)}',
        Icons.trending_up,
        const Color(0xFF10B981),
        isDark,
      ),
      _buildMetricCard(
        'Collections',
        '₹${_formatAmount(_totalCollections)}',
        Icons.payments,
        const Color(0xFF06B6D4),
        isDark,
      ),
      _buildMetricCard(
        'Outstanding',
        '₹${_formatAmount(_totalOutstanding)}',
        Icons.account_balance_wallet,
        const Color(0xFFF59E0B),
        isDark,
      ),
      _buildMetricCard(
        'Returns',
        '₹${_formatAmount(_totalReturns)}',
        Icons.assignment_return,
        const Color(0xFFEF4444),
        isDark,
      ),
    ];

    if (context.isMobile) {
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

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return GlassMorphism(
      blur: 10,
      opacity: 0.1,
      borderRadius: 16, // Fixed: double
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            // Value scales down (never wraps/overflows) so large ₹ amounts fit
            // the card width at any text scale.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceBreakdown(bool isDark) {
    final total = _paidInvoices + _partialInvoices + _unpaidInvoices;

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
          Text(
            'Invoice Status',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Paid',
                  _paidInvoices,
                  total,
                  const Color(0xFF10B981),
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  'Partial',
                  _partialInvoices,
                  total,
                  const Color(0xFFF59E0B),
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  'Unpaid',
                  _unpaidInvoices,
                  total,
                  const Color(0xFFEF4444),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    String label,
    int count,
    int total,
    Color color,
    bool isDark,
  ) {
    final percent = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percent / 100,
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  Widget _buildRecentInvoices(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Invoices',
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to sales register
              },
              child: const Text('View All →'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
            ),
          ),
          child: _recentBills.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(responsiveValue<double>(context,
              mobile: 16,
              tablet: 20,
              desktop: 32,  // PRESERVED: Desktop uses exactly 32 as before
            )),
                  child: Center(
                    child: Text(
                      'No invoices found',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentBills.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final bill = _recentBills[index];
                    return _buildInvoiceRow(bill, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceRow(Bill bill, bool isDark) {
    final isPaid = bill.paidAmount >= bill.grandTotal;
    final isPartial = bill.paidAmount > 0 && bill.paidAmount < bill.grandTotal;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              (isPaid
                      ? const Color(0xFF10B981)
                      : isPartial
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444))
                  .withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPaid
              ? Icons.check_circle
              : isPartial
              ? Icons.timelapse
              : Icons.pending,
          color: isPaid
              ? const Color(0xFF10B981)
              : isPartial
              ? const Color(0xFFF59E0B)
              : const Color(0xFFEF4444),
        ),
      ),
      title: Text(
        bill.invoiceNumber,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        '${bill.customerName.isEmpty ? 'Walk-in' : bill.customerName} • ${DateFormat('dd MMM').format(bill.date)}',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.grey[600],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${bill.grandTotal.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (!isPaid)
            Text(
              'Due: ₹${(bill.grandTotal - bill.paidAmount).toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
