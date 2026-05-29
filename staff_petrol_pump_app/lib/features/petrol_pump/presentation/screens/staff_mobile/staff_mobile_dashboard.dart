import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/staff_repository.dart';
import '../../../providers/license_provider.dart';
import '../../../providers/staff_provider.dart';

/// Staff Mobile Dashboard
/// 
/// Modern, professional mobile-optimized dashboard for staff members.
/// Features quick actions, shift summary, and recent activity.
class StaffMobileDashboard extends ConsumerStatefulWidget {
  const StaffMobileDashboard({super.key});

  @override
  ConsumerState<StaffMobileDashboard> createState() => _StaffMobileDashboardState();
}

class _StaffMobileDashboardState extends ConsumerState<StaffMobileDashboard> {
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
    final license = ref.watch(licenseProvider).profile;
    final performanceAsync = ref.watch(staffPerformanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverToBoxAdapter(
              child: _buildModernHeader(license?.stationName ?? 'Station'),
            ),
            
            // Quick Actions Grid
            SliverToBoxAdapter(
              child: _buildQuickActionsGrid(),
            ),
            
            // Shift Summary Card
            SliverToBoxAdapter(
              child: _buildShiftSummaryCard(
              AsyncValue.data(performanceAsync.performance.isNotEmpty ? performanceAsync.performance.first : null)
            ),
            ),
            
            // Recent Activity
            SliverToBoxAdapter(
              child: _buildRecentActivitySection(),
            ),
          ],
        ),
      ),
      // Modern Bottom Navigation
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildModernHeader(String stationName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF2D5A87),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${DateTime.now().hour < 12 ? 'Morning' : DateTime.now().hour < 17 ? 'Afternoon' : 'Evening'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Staff Member',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_gas_station,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  stationName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction(
        icon: Icons.qr_code_scanner,
        label: 'Quick Pay',
        color: const Color(0xFF10B981),
        onTap: () => context.go('/staff-mobile/quick-pay'),
      ),
      _QuickAction(
        icon: Icons.receipt_long,
        label: 'Transactions',
        color: const Color(0xFF3B82F6),
        onTap: () => context.go('/staff-mobile/transactions'),
      ),
      _QuickAction(
        icon: Icons.summarize,
        label: 'Shift Summary',
        color: const Color(0xFFF59E0B),
        onTap: () => context.go('/staff-mobile/shift-summary'),
      ),
      _QuickAction(
        icon: Icons.person,
        label: 'My Profile',
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/staff-mobile/profile'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: actions.map((action) => _buildActionCard(action)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: action.color.withValues(alpha:0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummaryCard(AsyncValue<StaffPerformance?> performanceAsync) {
    return performanceAsync.when(
      data: (performance) {
        if (performance == null) {
          return _buildEmptyShiftCard();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha:0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Performance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Revenue',
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                            .format(performance.totalRevenue),
                        Icons.currency_rupee,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha:0.3),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Transactions',
                        '${performance.totalTransactions}',
                        Icons.receipt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Fuel Sold',
                        '${performance.totalFuelLiters.toStringAsFixed(1)} L',
                        Icons.local_gas_station,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha:0.3),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Avg Ticket',
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
                            .format(performance.averageTransactionValue),
                        Icons.trending_up,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => _buildEmptyShiftCard(),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyShiftCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Performance",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet today',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/staff-mobile/quick-pay'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Start First Transaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/staff-mobile/transactions'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sample recent transactions
          _buildActivityItem(
            'Petrol Sale',
            '₹2,500 • 25.5 L',
            '2 min ago',
            const Color(0xFF3B82F6),
            Icons.local_gas_station,
          ),
          _buildActivityItem(
            'Diesel Sale',
            '₹4,200 • 35.2 L',
            '15 min ago',
            const Color(0xFFF59E0B),
            Icons.local_gas_station,
          ),
          _buildActivityItem(
            'Petrol Sale',
            '₹1,800 • 18.3 L',
            '32 min ago',
            const Color(0xFF3B82F6),
            Icons.local_gas_station,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', true, () {}),
              _buildNavItem(Icons.qr_code_scanner, 'Pay', false, () => context.go('/staff-mobile/quick-pay')),
              _buildNavItem(Icons.receipt_long, 'History', false, () => context.go('/staff-mobile/transactions')),
              _buildNavItem(Icons.person_outline, 'Profile', false, () => context.go('/staff-mobile/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF1E3A5F) : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF1E3A5F) : Colors.grey[400],
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// Provider for current staff performance (today)
final currentStaffPerformanceProvider = Provider<AsyncValue<StaffPerformance?>>((ref) {
  // This would be implemented to fetch the current user's performance for today
  return const AsyncValue.data(null);
});
