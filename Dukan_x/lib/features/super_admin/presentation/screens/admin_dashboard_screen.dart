import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/super_admin_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Admin Dashboard Screen - System Overview
///
/// Shows super admin metrics:
/// - Total/Active Tenants
/// - Total/Active Users
/// - Revenue statistics
/// - Recent system activities
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingStats = true;
  bool _isLoadingActivities = true;
  String? _statsError;
  String? _activitiesError;

  final SuperAdminRepository _repository = SuperAdminRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadStats(), _loadRecentActivities()]);
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      final stats = await _repository.getSystemStats();
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _statsError = 'Failed to load stats: $e';
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadRecentActivities() async {
    setState(() {
      _isLoadingActivities = true;
      _activitiesError = null;
    });

    try {
      final activities = await _repository.getRecentActivities(limit: 20);
      setState(() {
        _recentActivities = activities;
        _isLoadingActivities = false;
      });
    } catch (e) {
      setState(() {
        _activitiesError = 'Failed to load activities: $e';
        _isLoadingActivities = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent Activities
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activities',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildRecentActivities(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Quick Actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActions(),
                      ],
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

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_statsError != null) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(_statsError!, style: TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadStats, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No stats available')),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );

    return GridView.count(
      crossAxisCount: responsiveValue<int>(
        context,
        mobile: 1,
        tablet: 2,
        desktop: 3,
      ),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          title: 'Total Tenants',
          value: (_stats!['totalTenants'] ?? 0).toString(),
          icon: Icons.business,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Active Tenants',
          value: (_stats!['activeTenants'] ?? 0).toString(),
          icon: Icons.business_center,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Total Users',
          value: (_stats!['totalUsers'] ?? 0).toString(),
          icon: Icons.people,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Active Users',
          value: (_stats!['activeUsers'] ?? 0).toString(),
          icon: Icons.people_alt,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'Total Revenue',
          value: currencyFormatter.format(_stats!['totalRevenue'] ?? 0),
          icon: Icons.currency_rupee,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Monthly Revenue',
          value: currencyFormatter.format(_stats!['monthlyRevenue'] ?? 0),
          icon: Icons.trending_up,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    if (_isLoadingActivities) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_activitiesError != null) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _activitiesError!,
                style: TextStyle(color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRecentActivities,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentActivities.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No recent activities')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivities.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = _recentActivities[index];
          return ListTile(
            leading: _getActivityIcon(activity['type'] ?? ''),
            title: Text(activity['message'] ?? 'Unknown activity'),
            subtitle: Text(activity['timestamp'] ?? ''),
            dense: true,
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _QuickActionButton(
          title: 'Manage Tenants',
          icon: Icons.business,
          onPressed: () => context.push('/super-admin/tenants'),
        ),
        const SizedBox(height: 12),
        _QuickActionButton(
          title: 'Manage Licenses',
          icon: Icons.card_membership,
          onPressed: () => context.push('/super-admin/licenses'),
        ),
        const SizedBox(height: 12),
        _QuickActionButton(
          title: 'Audit Logs',
          icon: Icons.history,
          onPressed: () => context.push('/super-admin/audit'),
        ),
        const SizedBox(height: 12),
        _QuickActionButton(
          title: 'Usage Dashboard',
          icon: Icons.analytics,
          onPressed: () => context.push('/super-admin/usage'),
        ),
      ],
    );
  }

  Widget _getActivityIcon(String type) {
    switch (type) {
      case 'tenant_created':
        return const Icon(Icons.business, color: Colors.blue);
      case 'user_invited':
        return const Icon(Icons.person_add, color: Colors.green);
      case 'subscription_cancelled':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'tenant_suspended':
        return const Icon(Icons.block, color: Colors.orange);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
