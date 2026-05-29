import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/staff_repository.dart';
import '../../../providers/staff_provider.dart';

/// Staff Shift Summary Screen
/// 
/// Modern mobile-optimized shift summary for staff members.
/// Shows detailed breakdown of their shift performance.
class StaffShiftSummaryScreen extends ConsumerStatefulWidget {
  const StaffShiftSummaryScreen({super.key});

  @override
  ConsumerState<StaffShiftSummaryScreen> createState() => _StaffShiftSummaryScreenState();
}

class _StaffShiftSummaryScreenState extends ConsumerState<StaffShiftSummaryScreen> {
  String _selectedPeriod = 'Today';
  final List<String> _periods = ['Today', 'Yesterday', 'This Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(staffPerformanceProvider.notifier).loadPerformance(
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final performanceAsync = ref.watch(staffPerformanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go('/staff-mobile'),
        ),
        title: const Text(
          'Shift Summary',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: performanceAsync.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : performanceAsync.error != null
              ? _buildError()
              : _buildContent(performanceAsync.performance.isNotEmpty ? performanceAsync.performance.first : null),
    );
  }

  Widget _buildContent(StaffPerformance? performance) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          _buildPeriodSelector(),
          const SizedBox(height: 20),

          // Total Revenue Card
          _buildRevenueCard(
            performance?.totalRevenue ?? 0,
            0.0, // revenueChangePercent - using default value
            currencyFormatter,
          ),
          const SizedBox(height: 20),

          // Stats Grid
          _buildStatsGrid(performance, currencyFormatter),
          const SizedBox(height: 24),

          // Fuel Breakdown
          _buildFuelBreakdownCard(performance, currencyFormatter),
          const SizedBox(height: 24),

          // Recent Transactions Button
          _buildViewTransactionsButton(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        itemBuilder: (context, index) {
          final period = _periods[index];
          final isSelected = period == _selectedPeriod;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPeriod = period;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
                ),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueCard(double revenue, double changePercent, NumberFormat formatter) {
    final isPositive = changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2D5A87),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Revenue',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(revenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive 
                  ? const Color(0xFF10B981).withValues(alpha:0.2)
                  : const Color(0xFFEF4444).withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'vs last period',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(StaffPerformance? performance, NumberFormat formatter) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Transactions',
          '${performance?.totalTransactions ?? 0}',
          Icons.receipt_long,
          const Color(0xFF3B82F6),
        ),
        _buildStatCard(
          'Fuel Sold',
          '${(performance?.totalFuelLiters ?? 0).toStringAsFixed(1)} L',
          Icons.local_gas_station,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Avg Ticket',
          formatter.format(performance?.averageTransactionValue ?? 0),
          Icons.trending_up,
          const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          'Best Hour',
          '10 AM',
          Icons.access_time,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuelBreakdownCard(StaffPerformance? performance, NumberFormat formatter) {
    final petrolLiters = performance?.petrolLiters ?? 0;
    final dieselLiters = performance?.dieselLiters ?? 0;
    final totalLiters = petrolLiters + dieselLiters;
    final petrolPercent = (totalLiters > 0 ? (petrolLiters / totalLiters) * 100 : 50).toDouble();
    final dieselPercent = (totalLiters > 0 ? (dieselLiters / totalLiters) * 100 : 50).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fuel Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: petrolPercent.toInt(),
                  child: Container(
                    height: 8,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                Expanded(
                  flex: dieselPercent.toInt(),
                  child: Container(
                    height: 8,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Petrol Stats
          _buildFuelStatRow(
            'Petrol',
            '${petrolLiters.toStringAsFixed(1)} L',
            formatter.format(performance?.totalRevenue ?? 0),
            const Color(0xFF3B82F6),
            petrolPercent,
          ),
          const SizedBox(height: 16),
          
          // Diesel Stats
          _buildFuelStatRow(
            'Diesel',
            '${dieselLiters.toStringAsFixed(1)} L',
            formatter.format(performance?.totalRevenue ?? 0),
            const Color(0xFFF59E0B),
            dieselPercent,
          ),
        ],
      ),
    );
  }

  Widget _buildFuelStatRow(String fuel, String liters, String revenue, Color color, double percent) {
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fuel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    liters,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    revenue,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewTransactionsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.go('/staff-mobile/transactions'),
        icon: const Icon(Icons.receipt_long),
        label: const Text(
          'View All Transactions',
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load shift summary',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(staffPerformanceProvider.notifier).loadPerformance(
              startDate: DateTime.now().subtract(const Duration(days: 1)),
              endDate: DateTime.now(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
