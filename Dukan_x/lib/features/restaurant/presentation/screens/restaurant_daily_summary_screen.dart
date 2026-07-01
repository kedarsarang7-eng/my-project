// ============================================================================
// RESTAURANT DAILY SUMMARY DASHBOARD
// ============================================================================
// Shows daily analytics and summary for restaurant owner

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/repositories/food_order_repository.dart';
import '../../data/repositories/restaurant_bill_repository.dart';
import '../../data/models/food_order_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantDailySummaryScreen extends StatefulWidget {
  final String vendorId;

  const RestaurantDailySummaryScreen({super.key, required this.vendorId});

  @override
  State<RestaurantDailySummaryScreen> createState() =>
      _RestaurantDailySummaryScreenState();
}

class _RestaurantDailySummaryScreenState
    extends State<RestaurantDailySummaryScreen> {
  final FoodOrderRepository _orderRepo = FoodOrderRepository();
  final RestaurantBillRepository _billRepo = RestaurantBillRepository();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  // Summary data
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  double _totalRevenue = 0;
  double _averageOrderValue = 0;
  int _totalCustomers = 0;
  Map<String, int> _topItems = {};
  Map<int, int> _ordersPerHour = {};
  double _avgPrepTime = 0;
  int _dineInCount = 0;
  int _takeawayCount = 0;
  int _deliveryCount = 0;
  int _parcelCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get today's orders
      final ordersResult = await _orderRepo.getOrdersByDate(
        widget.vendorId,
        _selectedDate,
      );
      if (ordersResult.success && ordersResult.data != null) {
        final orders = ordersResult.data!;
        _processOrders(orders);
      }

      // Get today's revenue
      final revenueResult = await _billRepo.getDailyRevenue(
        widget.vendorId,
        _selectedDate,
      );
      if (revenueResult.success && revenueResult.data != null) {
        _totalRevenue = revenueResult.data!;
      }
    } catch (e) {
      debugPrint('Error loading summary: $e');
    }

    setState(() => _isLoading = false);
  }

  void _processOrders(List<FoodOrder> orders) {
    _totalOrders = orders.length;
    _completedOrders = orders
        .where(
          (o) =>
              o.orderStatus == FoodOrderStatus.completed ||
              o.orderStatus == FoodOrderStatus.served,
        )
        .length;
    _cancelledOrders = orders
        .where((o) => o.orderStatus == FoodOrderStatus.cancelled)
        .length;

    _dineInCount = orders.where((o) => o.orderType == OrderType.dineIn).length;
    _takeawayCount = orders
        .where((o) => o.orderType == OrderType.takeaway)
        .length;
    _deliveryCount = orders
        .where((o) => o.orderType == OrderType.delivery)
        .length;
    _parcelCount = orders.where((o) => o.orderType == OrderType.parcel).length;

    // Calculate average order value
    if (_completedOrders > 0) {
      final completedOrders = orders.where(
        (o) =>
            o.orderStatus == FoodOrderStatus.completed ||
            o.orderStatus == FoodOrderStatus.served,
      );
      final totalValue = completedOrders.fold<double>(
        0,
        (sum, o) => sum + o.grandTotal,
      );
      _averageOrderValue = totalValue / _completedOrders;
    }

    // Count unique customers
    final customerIds = orders.map((o) => o.customerId).toSet();
    _totalCustomers = customerIds.length;

    // Top items
    final itemCounts = <String, int>{};
    for (final order in orders) {
      for (final item in order.items) {
        itemCounts[item.itemName] =
            (itemCounts[item.itemName] ?? 0) + item.quantity;
      }
    }
    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _topItems = Map.fromEntries(sortedItems.take(5));

    // Orders per hour
    _ordersPerHour = {};
    for (final order in orders) {
      final hour = order.orderTime.hour;
      _ordersPerHour[hour] = (_ordersPerHour[hour] ?? 0) + 1;
    }

    // Average prep time
    final completedWithPrepTime = orders.where(
      (o) =>
          o.acceptedAt != null &&
          o.readyAt != null &&
          (o.orderStatus == FoodOrderStatus.completed ||
              o.orderStatus == FoodOrderStatus.served),
    );
    if (completedWithPrepTime.isNotEmpty) {
      final totalPrepMinutes = completedWithPrepTime.fold<int>(0, (sum, o) {
        return sum + o.readyAt!.difference(o.acceptedAt!).inMinutes;
      });
      _avgPrepTime = totalPrepMinutes / completedWithPrepTime.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          // Date picker
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date header
                      _buildDateHeader(),

                      const SizedBox(height: 20),

                      // Key metrics
                      _buildMetricsGrid(isDark),

                      const SizedBox(height: 24),

                      // Revenue chart
                      _buildSectionTitle('Orders by Hour'),
                      const SizedBox(height: 12),
                      _buildOrdersChart(isDark),

                      const SizedBox(height: 24),

                      // Order type breakdown
                      _buildSectionTitle('Order Types'),
                      const SizedBox(height: 12),
                      _buildOrderTypeBreakdown(isDark),

                      const SizedBox(height: 24),

                      // Top selling items
                      _buildSectionTitle('Top Selling Items'),
                      const SizedBox(height: 12),
                      _buildTopItems(isDark),

                      const SizedBox(height: 24),

                      // Performance metrics
                      _buildSectionTitle('Performance'),
                      const SizedBox(height: 12),
                      _buildPerformanceCard(isDark),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final isToday =
        _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(
                    const Duration(days: 1),
                  );
                });
                _loadData();
              },
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    isToday ? 'Today' : _formatDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatFullDate(_selectedDate),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday
                  ? null
                  : () {
                      setState(() {
                        _selectedDate = _selectedDate.add(
                          const Duration(days: 1),
                        );
                      });
                      _loadData();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: responsiveValue<int>(
        context,
        mobile: 1,
        tablet: 2,
        desktop: 2,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Revenue',
          '₹${_totalRevenue.toStringAsFixed(0)}',
          Icons.currency_rupee,
          FuturisticColors.success,
          isDark,
        ),
        _buildMetricCard(
          'Total Orders',
          '$_totalOrders',
          Icons.receipt_long,
          Colors.blue,
          isDark,
        ),
        _buildMetricCard(
          'Avg Order Value',
          '₹${_averageOrderValue.toStringAsFixed(0)}',
          Icons.trending_up,
          Colors.purple,
          isDark,
        ),
        _buildMetricCard(
          'Customers',
          '$_totalCustomers',
          Icons.people,
          Colors.orange,
          isDark,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Icon(icon, color: color, size: 24)],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 18,
                      tablet: 20,
                      desktop: 24,
                    ),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOrdersChart(bool isDark) {
    if (_ordersPerHour.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Center(
            child: Text(
              'No orders today',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (_ordersPerHour.values.reduce((a, b) => a > b ? a : b) + 2)
                  .toDouble(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} orders',
                      const TextStyle(color: Colors.white),
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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${value.toInt()}:00',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _ordersPerHour.entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      color: Theme.of(context).colorScheme.primary,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeBreakdown(bool isDark) {
    final total = _dineInCount + _takeawayCount + _deliveryCount + _parcelCount;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Center(
            child: Text(
              'No orders today',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Pie chart
            SizedBox(
              width: 100,
              height: 100,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                  sections: [
                    if (_dineInCount > 0)
                      PieChartSectionData(
                        value: _dineInCount.toDouble(),
                        color: Colors.blue,
                        title: '',
                        radius: 30,
                      ),
                    if (_takeawayCount > 0)
                      PieChartSectionData(
                        value: _takeawayCount.toDouble(),
                        color: Colors.orange,
                        title: '',
                        radius: 30,
                      ),
                    if (_deliveryCount > 0)
                      PieChartSectionData(
                        value: _deliveryCount.toDouble(),
                        color: Colors.green,
                        title: '',
                        radius: 30,
                      ),
                    if (_parcelCount > 0)
                      PieChartSectionData(
                        value: _parcelCount.toDouble(),
                        color: Colors.purple,
                        title: '',
                        radius: 30,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Legend
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem(
                  'Dine-In',
                  _dineInCount,
                  ((_dineInCount / total) * 100).toStringAsFixed(0),
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildLegendItem(
                  'Takeaway',
                  _takeawayCount,
                  ((_takeawayCount / total) * 100).toStringAsFixed(0),
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildLegendItem(
                  'Delivery',
                  _deliveryCount,
                  ((_deliveryCount / total) * 100).toStringAsFixed(0),
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildLegendItem(
                  'Parcel',
                  _parcelCount,
                  ((_parcelCount / total) * 100).toStringAsFixed(0),
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    int count,
    String percent,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: $count ($percent%)'),
      ],
    );
  }

  Widget _buildTopItems(bool isDark) {
    if (_topItems.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Center(
            child: Text(
              'No items sold today',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _topItems.entries.map((entry) {
            final maxCount = _topItems.values.reduce((a, b) => a > b ? a : b);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPerformanceRow(
              'Completed Orders',
              '$_completedOrders/$_totalOrders',
              _totalOrders > 0 ? _completedOrders / _totalOrders : 0,
              FuturisticColors.success,
            ),
            const Divider(),
            _buildPerformanceRow(
              'Cancelled Orders',
              '$_cancelledOrders',
              _totalOrders > 0 ? _cancelledOrders / _totalOrders : 0,
              FuturisticColors.error,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Avg Prep Time'),
                Text(
                  '${_avgPrepTime.toStringAsFixed(0)} min',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _avgPrepTime < 20
                        ? FuturisticColors.success
                        : _avgPrepTime < 30
                        ? Colors.orange
                        : FuturisticColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceRow(
    String label,
    String value,
    double percent,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  String _formatDate(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
