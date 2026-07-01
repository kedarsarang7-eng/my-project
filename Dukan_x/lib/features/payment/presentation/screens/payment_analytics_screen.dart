// ============================================================================
// PAYMENT ANALYTICS DASHBOARD
// ============================================================================
// Comprehensive payment analytics showing success rates, failure analysis,
// refund tracking, and payment method breakdown.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/payment_analytics_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PaymentAnalyticsScreen extends StatefulWidget {
  const PaymentAnalyticsScreen({super.key});

  @override
  State<PaymentAnalyticsScreen> createState() => _PaymentAnalyticsScreenState();
}

class _PaymentAnalyticsScreenState extends State<PaymentAnalyticsScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = false;
  String? _errorMessage;

  // Real data from backend
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _refundHistory = [];
  List<Map<String, dynamic>> _dailyTrend = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final analyticsService = PaymentAnalyticsService();

      // Fetch all analytics data in parallel
      final results = await Future.wait([
        analyticsService.getPaymentAnalytics(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
        ),
        analyticsService.getRefundHistory(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
        ),
        analyticsService.getDailyTrend(
          startDate: _dateRange.start,
          endDate: _dateRange.end,
        ),
      ]);

      final analytics = results[0] as Map<String, dynamic>;
      final refunds = results[1] as List<Map<String, dynamic>>;
      final trend = results[2] as List<Map<String, dynamic>>;

      if (mounted) {
        if (analytics.containsKey('error')) {
          setState(() {
            _errorMessage = analytics['error'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _analyticsData = analytics;
            _refundHistory = refunds;
            _dailyTrend = trend;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load analytics: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      await _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Analytics'),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
          ),
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnalytics,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _analyticsData.isEmpty
          ? const Center(
              child: Text('No data available for selected date range'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Display
                  _buildDateRangeCard(),
                  const SizedBox(height: 16),

                  // Key Metrics
                  _buildKeyMetricsGrid(),
                  const SizedBox(height: 24),

                  // Success Rate Chart
                  _buildSuccessRateChart(),
                  const SizedBox(height: 24),

                  // Payment Methods
                  _buildPaymentMethodsChart(),
                  const SizedBox(height: 24),

                  // Failure Analysis
                  _buildFailureAnalysis(),
                  const SizedBox(height: 24),

                  // Recent Refunds
                  _buildRecentRefundsCard(),
                  const SizedBox(height: 24),

                  // Daily Trend
                  if (_dailyTrend.isNotEmpty) _buildDailyTrendChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            Text(
              '${_formatDate(_dateRange.start)} - ${_formatDate(_dateRange.end)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    final data = _analyticsData;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMetricCard(
          'Total Transactions',
          data['totalTransactions']?.toString() ?? '0',
          Icons.receipt_long,
          Colors.blue,
        ),
        _buildMetricCard(
          'Success Rate',
          '${data['successRate']?.toStringAsFixed(1) ?? 0}%',
          Icons.check_circle,
          Colors.green,
        ),
        _buildMetricCard(
          'Total Volume',
          '₹${(data['totalVolume'] ?? 0).toStringAsFixed(0)}',
          Icons.account_balance_wallet,
          Colors.purple,
        ),
        _buildMetricCard(
          'Avg. Transaction',
          '₹${(data['averageTransactionValue'] ?? 0).toStringAsFixed(0)}',
          Icons.trending_up,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessRateChart() {
    final data = _analyticsData;
    final successRate = (data['successRate'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Success Rate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            context.isMobile
                ? Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: successRate,
                                color: Colors.green,
                                title: '${successRate.toStringAsFixed(1)}%',
                                radius: 45,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              PieChartSectionData(
                                value: 100 - successRate,
                                color: Colors.red.shade300,
                                title: '',
                                radius: 45,
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          _buildLegendItem(
                            'Successful',
                            data['successfulPayments']?.toString() ?? '0',
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            'Failed',
                            data['failedPayments']?.toString() ?? '0',
                            Colors.red.shade300,
                          ),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            'Refunded',
                            data['refundedTransactions']?.toString() ?? '0',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  )
                : SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: successRate,
                                  color: Colors.green,
                                  title: '${successRate.toStringAsFixed(1)}%',
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: 100 - successRate,
                                  color: Colors.red.shade300,
                                  title: '',
                                  radius: 60,
                                ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendItem(
                                'Successful',
                                data['successfulPayments']?.toString() ?? '0',
                                Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _buildLegendItem(
                                'Failed',
                                data['failedPayments']?.toString() ?? '0',
                                Colors.red.shade300,
                              ),
                              const SizedBox(height: 8),
                              _buildLegendItem(
                                'Refunded',
                                data['refundedTransactions']?.toString() ?? '0',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label: $value'),
      ],
    );
  }

  Widget _buildPaymentMethodsChart() {
    final methods =
        (_analyticsData['paymentMethods'] as Map<String, dynamic>?) ?? {};
    final total = methods.values.fold<int>(0, (sum, v) => sum + (v as int));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Methods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...methods.entries.map((entry) {
              final percentage = (entry.value / total) * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${percentage.toStringAsFixed(1)}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPaymentMethodColor(entry.key),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return Colors.blue;
      case 'card':
        return Colors.purple;
      case 'cash':
        return Colors.green;
      case 'wallet':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFailureAnalysis() {
    final failures =
        (_analyticsData['failureReasons'] as Map<String, dynamic>?) ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Failure Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...failures.entries.map((entry) {
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 20,
                ),
                title: Text(entry.key),
                trailing: Chip(
                  label: Text(entry.value.toString()),
                  backgroundColor: Colors.red.shade50,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRefundsCard() {
    final refundCount = _refundHistory.length;
    final refundVolume = _analyticsData['refundVolume'] ?? 0.0;
    final totalTransactions = _analyticsData['totalTransactions'] ?? 0;
    final refundRate = totalTransactions > 0
        ? (refundCount / totalTransactions) * 100
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Refund Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('₹${refundVolume.toStringAsFixed(0)}'),
                  backgroundColor: Colors.orange.shade100,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.undo, color: Colors.orange),
              title: const Text('Total Refunds'),
              trailing: Text('$refundCount transactions'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.percent, color: Colors.green),
              title: const Text('Refund Rate'),
              trailing: Text('${refundRate.toStringAsFixed(1)}%'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.access_time, color: Colors.blue),
              title: const Text('Avg. Processing Time'),
              trailing: const Text('N/A'),
            ),
            if (_refundHistory.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Recent Refunds',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._refundHistory.take(3).map((refund) {
                return ListTile(
                  dense: true,
                  title: Text(
                    'Bill #${refund['billId']?.toString().substring(0, 8) ?? 'N/A'}',
                  ),
                  subtitle: Text(refund['reason'] ?? 'Customer request'),
                  trailing: Text(
                    '₹${(refund['amount'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    final spots = <FlSpot>[];
    final labels = <int, String>{};

    for (var i = 0; i < _dailyTrend.length; i++) {
      final entry = _dailyTrend[i];
      final successful = (entry['successful'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), successful));
      final dateStr = entry['date'] as String? ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final d = DateTime.parse(dateStr);
          labels[i] = DateFormat('d/M').format(d);
        } catch (_) {
          labels[i] = dateStr;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Transaction Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Color(0xFFE0E0E0), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (_dailyTrend.length / 5).ceilToDouble().clamp(
                          1,
                          double.infinity,
                        ),
                        getTitlesWidget: (value, meta) {
                          final label = labels[value.toInt()];
                          return label != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Successful transactions per day',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
