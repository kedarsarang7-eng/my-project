import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff Transaction History Screen (Owner View)
///
/// Displays all staff sale transactions with filtering and summary cards.
/// Used by petrol pump owners/admins to monitor staff activity.
class StaffTransactionHistoryScreen extends StatefulWidget {
  const StaffTransactionHistoryScreen({super.key});

  @override
  State<StaffTransactionHistoryScreen> createState() =>
      _StaffTransactionHistoryScreenState();
}

class _StaffTransactionHistoryScreenState
    extends State<StaffTransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedFilter = 'today';

  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic> _summary = {};

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final api = sl<ApiClient>();
      final summaryRes = await api.get(
        '/api/v1/staff/transactions/summary',
        queryParameters: {'filter': _selectedFilter},
      );
      final listRes = await api.get(
        '/api/v1/staff/transactions',
        queryParameters: {'filter': _selectedFilter},
      );

      if (summaryRes.isSuccess && listRes.isSuccess) {
        final summaryData = summaryRes.data ?? <String, dynamic>{};
        final rawList = (listRes.data?['items'] as List<dynamic>?) ??
            (listRes.data?['transactions'] as List<dynamic>?) ??
            const <dynamic>[];
        if (mounted) {
          setState(() {
            _summary = summaryData;
            _transactions = rawList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _summary = {};
          _transactions = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = {};
        _transactions = [];
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Staff Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Date filter chips
                  SliverToBoxAdapter(child: _buildDateFilters(isDark)),

                  // Summary cards
                  SliverToBoxAdapter(child: _buildSummaryCards(isDark, theme)),

                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 20,
                        bottom: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            '${_transactions.length} records',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction list
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final txn = _transactions[index];
                      return _buildTransactionCard(txn, isDark, theme, index);
                    }, childCount: _transactions.length),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildDateFilters(bool isDark) {
    final filters = [
      {'key': 'today', 'label': 'Today'},
      {'key': 'week', 'label': 'This Week'},
      {'key': 'month', 'label': 'This Month'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = filters[i];
            final isSelected = f['key'] == _selectedFilter;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = f['key']!);
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[300]!,
                        ),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.grey[700]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark, ThemeData theme) {
    final totalAmount = (_summary['totalAmount'] ?? 0) / 100;
    final cashAmount = (_summary['cashAmountCents'] ?? 0) / 100;
    final onlineAmount = (_summary['onlineAmountCents'] ?? 0) / 100;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main total card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.9),
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Sales',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: responsiveValue<double>(context,
                    mobile: 28.0,
                    tablet: 30.0,
                    desktop: 32.0,  // PRESERVED: Desktop uses exactly 32 as before
                  ),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_summary['totalTransactions'] ?? 0} transactions',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniSummary(
                  'Cash',
                  '₹${cashAmount.toStringAsFixed(2)}',
                  '${_summary['cashCount'] ?? 0} txns',
                  Icons.money,
                  Colors.green,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniSummary(
                  'Online',
                  '₹${onlineAmount.toStringAsFixed(2)}',
                  '${_summary['onlineCount'] ?? 0} txns',
                  Icons.qr_code_2,
                  Colors.blue,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummary(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> txn,
    bool isDark,
    ThemeData theme,
    int index,
  ) {
    final amountCents = (txn['amountCents'] ?? txn['amount_cents'] ?? 0) as num;
    final amount = amountCents / 100;
    final paymentMode = (txn['paymentMode'] ?? txn['payment_mode'] ?? '').toString().toLowerCase();
    final productType = (txn['productType'] ?? txn['product_type'] ?? '').toString().toLowerCase();
    final isCash = paymentMode == 'cash';
    final isPetrol = productType == 'petrol';
    final createdAt = (txn['createdAt'] ?? txn['created_at'])?.toString();
    final time = createdAt != null ? DateTime.tryParse(createdAt) ?? DateTime.now() : DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction details not available yet.'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isPetrol ? Colors.orange : Colors.amber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_gas_station,
                    size: 20,
                    color: isPetrol ? Colors.orange : Colors.amber[700],
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            txn['staffName'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: (isCash ? Colors.green : Colors.blue)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCash ? 'CASH' : 'UPI',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isCash ? Colors.green : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${txn['vehicleNumber']} • ${txn['productType']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount + time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
