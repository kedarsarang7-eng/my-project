// ============================================================================
// ACADEMIC COACHING — FINANCIAL REPORTS SCREEN
// ============================================================================
// Modern financial dashboard with P&L, batch profitability, and charts

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcFinancialReportsScreen extends StatefulWidget {
  const AcFinancialReportsScreen({super.key});

  @override
  State<AcFinancialReportsScreen> createState() =>
      _AcFinancialReportsScreenState();
}

class _AcFinancialReportsScreenState extends State<AcFinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  Map<String, dynamic> _plData = {};
  Map<String, dynamic> _batchData = {};
  Map<String, dynamic> _outstandingData = {};
  bool _isLoading = true;
  String? _error;

  String _fromDate = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String()
      .split('T')[0];
  String _toDate = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = sl<AcRepository>();
    _loadAllReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [pl, batch, outstanding] = await Future.wait([
        _repository.getFinancialReports(
          reportType: 'pl',
          fromDate: _fromDate,
          toDate: _toDate,
        ),
        _repository.getFinancialReports(
          reportType: 'batch_profitability',
          fromDate: _fromDate,
          toDate: _toDate,
        ),
        _repository.getFinancialReports(reportType: 'outstanding_fees'),
      ]);

      setState(() {
        _plData = pl;
        _batchData = batch;
        _outstandingData = outstanding;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
              tabs: const [
                Tab(icon: Icon(Icons.account_balance), text: 'P&L Statement'),
                Tab(icon: Icon(Icons.pie_chart), text: 'Batch Profitability'),
                Tab(icon: Icon(Icons.hourglass_empty), text: 'Outstanding'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPLTab(fmt),
                        _buildBatchTab(fmt),
                        _buildOutstandingTab(fmt),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Financial analytics and insights',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_fromDate to $_toDate',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadAllReports,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPLTab(NumberFormat fmt) {
    final revenue = _plData['revenue'] ?? {};
    final expenses = _plData['expenses'] ?? {};
    final netProfit = _plData['netProfit'] ?? 0;
    final profitMargin = _plData['profitMargin'] ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          // Summary Cards
          if (context.isMobile)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSummaryCard(
                  'Total Revenue',
                  fmt.format(revenue['total'] ?? 0),
                  const Color(0xFF059669),
                  Icons.trending_up,
                ),
                _buildSummaryCard(
                  'Total Expenses',
                  fmt.format(expenses['total'] ?? 0),
                  const Color(0xFFDC2626),
                  Icons.trending_down,
                ),
                _buildSummaryCard(
                  'Net Profit',
                  fmt.format(netProfit),
                  netProfit >= 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                  Icons.account_balance_wallet,
                ),
                _buildSummaryCard(
                  'Profit Margin',
                  '${profitMargin.toStringAsFixed(1)}%',
                  profitMargin >= 20
                      ? const Color(0xFF059669)
                      : const Color(0xFFF59E0B),
                  Icons.percent,
                ),
              ],
            )
          else
            Row(
              children: [
                _buildSummaryCard(
                  'Total Revenue',
                  fmt.format(revenue['total'] ?? 0),
                  const Color(0xFF059669),
                  Icons.trending_up,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Total Expenses',
                  fmt.format(expenses['total'] ?? 0),
                  const Color(0xFFDC2626),
                  Icons.trending_down,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Net Profit',
                  fmt.format(netProfit),
                  netProfit >= 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                  Icons.account_balance_wallet,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Profit Margin',
                  '${profitMargin.toStringAsFixed(1)}%',
                  profitMargin >= 20
                      ? const Color(0xFF059669)
                      : const Color(0xFFF59E0B),
                  Icons.percent,
                ),
              ],
            ),
          const SizedBox(height: 24),
          // Revenue Breakdown
          _buildReportCard(
            'Revenue Breakdown',
            Column(
              children: [
                _buildReportRow(
                  'Total Revenue',
                  fmt.format(revenue['total'] ?? 0),
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Expense Breakdown
          _buildReportCard(
            'Expense Breakdown',
            Column(
              children: [
                _buildReportRow(
                  'Operational Expenses',
                  fmt.format(expenses['operational'] ?? 0),
                ),
                _buildReportRow(
                  'Faculty Payroll',
                  fmt.format(expenses['payroll'] ?? 0),
                ),
                const Divider(),
                _buildReportRow(
                  'Total Expenses',
                  fmt.format(expenses['total'] ?? 0),
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Profit Summary
          Container(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            decoration: BoxDecoration(
              color: netProfit >= 0
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: netProfit >= 0
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFCA5A5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 32,
                  color: netProfit >= 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                      style: TextStyle(
                        fontSize: 14,
                        color: netProfit >= 0
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      fmt.format(netProfit.abs()),
                      style: TextStyle(
                        fontSize: responsiveValue<double>(
                          context,
                          mobile: 22,
                          tablet: 24,
                          desktop: 28,
                        ),
                        fontWeight: FontWeight.bold,
                        color: netProfit >= 0
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchTab(NumberFormat fmt) {
    final batches = _batchData['batches'] as List<dynamic>? ?? [];
    final totalRevenue = _batchData['totalRevenue'] ?? 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4F46E5).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pie_chart, size: 48, color: Color(0xFF4F46E5)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Revenue from All Batches',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt.format(totalRevenue),
                        style: TextStyle(
                          fontSize: responsiveValue<double>(
                            context,
                            mobile: 22,
                            tablet: 24,
                            desktop: 28,
                          ),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${batches.length} batches',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildReportCard(
            'Batch Performance Ranking',
            Column(
              children: batches.asMap().entries.map((entry) {
                final index = entry.key;
                final batch = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index < 3
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF1F5F9),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index < 3
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      title: Text(batch['batchName'] ?? 'Unknown'),
                      subtitle: Text('${batch['studentCount']} students'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmt.format(batch['revenue'] ?? 0),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Avg: ${fmt.format(batch['avgRevenuePerStudent'] ?? 0)}/student',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < batches.length - 1) const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingTab(NumberFormat fmt) {
    final totalOutstanding = _outstandingData['totalOutstanding'] ?? {};
    final buckets = _outstandingData['agingBuckets'] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Outstanding',
                  fmt.format(totalOutstanding['amount'] ?? 0),
                  const Color(0xFFDC2626),
                  Icons.money_off,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Invoices Pending',
                  '${totalOutstanding['count'] ?? 0}',
                  const Color(0xFFF59E0B),
                  Icons.receipt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildReportCard(
            'Aging Analysis',
            Column(
              children: [
                _buildAgingRow(
                  'Current (Not Due)',
                  buckets['current'] ?? {},
                  const Color(0xFF059669),
                ),
                const SizedBox(height: 12),
                _buildAgingRow(
                  '1-30 Days Overdue',
                  buckets['days30'] ?? {},
                  const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 12),
                _buildAgingRow(
                  '31-60 Days Overdue',
                  buckets['days60'] ?? {},
                  const Color(0xFFFB923C),
                ),
                const SizedBox(height: 12),
                _buildAgingRow(
                  '61-90 Days Overdue',
                  buckets['days90'] ?? {},
                  const Color(0xFFF97316),
                ),
                const SizedBox(height: 12),
                _buildAgingRow(
                  '90+ Days Overdue',
                  buckets['over90'] ?? {},
                  const Color(0xFFDC2626),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.file_download),
              label: const Text('Download Detailed Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, Widget content) {
    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingRow(
    String label,
    Map<String, dynamic> bucket,
    Color color,
  ) {
    final count = bucket['count'] ?? 0;
    final amount = bucket['amount'] ?? 0;
    final totalAmount =
        (_outstandingData['totalOutstanding']?['amount'] ?? 1) as num;
    final percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
            Text(
              '₹${amount.toStringAsFixed(0)} (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count invoices',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllReports,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
