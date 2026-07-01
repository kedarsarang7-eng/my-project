import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../staff/data/models/staff_member.dart';
import '../../../staff/data/models/staff_performance.dart';
import '../../../staff/providers/staff_provider.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff Detail Screen for Petrol Pump
/// 
/// Shows detailed information about a staff member
class StaffDetailScreen extends ConsumerStatefulWidget {
  final String staffId;
  
  const StaffDetailScreen({super.key, required this.staffId});

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(staffDetailsProvider.notifier).loadStaffDetails(widget.staffId);
      ref.read(staffDetailsProvider.notifier).loadStaffTransactions(widget.staffId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailsState = ref.watch(staffDetailsProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: BoundedBox(
          maxWidth: 1200,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                  child: detailsState.isLoading && detailsState.staff == null
                      ? const Center(child: CircularProgressIndicator())
                      : detailsState.error != null && detailsState.staff == null
                          ? _buildError(detailsState.error!)
                          : _buildContent(detailsState.staff!, detailsState.transactions, detailsState.performance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(StaffMember staff, List<Map<String, dynamic>> transactions, StaffPerformance? performance) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol, decimalDigits: 0);
    final isActive = staff.status == 'active';

    final profileCard = Card(
      child: Padding(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: isActive ? AppTheme.primaryColor : AppTheme.disabledColor,
              child: Text(
                staff.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              staff.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive 
                    ? AppTheme.successColor.withValues(alpha: 0.1) 
                    : AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                staff.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(staff.email, style: TextStyle(color: AppTheme.textSecondaryColor)),
            if (staff.phone != null) ...[
              const SizedBox(height: 4),
              Text(staff.phone!, style: TextStyle(color: AppTheme.textSecondaryColor)),
            ],
            const SizedBox(height: 16),
            Text('${staff.role} • Member since ${_formatDate(staff.createdAt)}'),
          ],
        ),
      ),
    );

    final actionsCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeactivateDialog(staff),
                icon: Icon(isActive ? Icons.block : Icons.check_circle),
                label: Text(isActive ? 'Deactivate' : 'Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? AppTheme.errorColor : AppTheme.successColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final statsRow = context.isMobile
        ? Column(
            children: [
              _buildStatCard('Total Revenue', currencyFormatter.format(performance?.totalRevenue ?? staff.totalRevenue ?? 0), Icons.currency_rupee, AppTheme.primaryColor),
              const SizedBox(height: 12),
              _buildStatCard('Transactions', '${performance?.totalTransactions ?? staff.transactionsCount ?? 0}', Icons.receipt_long, AppTheme.infoColor),
              const SizedBox(height: 12),
              _buildStatCard('Avg. Ticket', currencyFormatter.format(performance?.averageTransactionValue ?? 0), Icons.trending_up, AppTheme.successColor),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Revenue',
                  currencyFormatter.format(performance?.totalRevenue ?? staff.totalRevenue ?? 0),
                  Icons.currency_rupee,
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Transactions',
                  '${performance?.totalTransactions ?? staff.transactionsCount ?? 0}',
                  Icons.receipt_long,
                  AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Avg. Ticket',
                  currencyFormatter.format(performance?.averageTransactionValue ?? 0),
                  Icons.trending_up,
                  AppTheme.successColor,
                ),
              ),
            ],
          );

    final fuelBreakdown = performance != null
        ? _buildFuelBreakdownCard(performance, currencyFormatter)
        : const SizedBox();

    final recentTransactionsList = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          transactions.isEmpty
              ? _buildEmptyTransactions()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: transactions.length > 10 ? 10 : transactions.length,
                  separatorBuilder: (context, i) => const Divider(),
                  itemBuilder: (context, index) => _buildTransactionTile(transactions[index], currencyFormatter),
                ),
        ],
      ),
    );

    if (context.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(staff),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      profileCard,
                      const SizedBox(height: 16),
                      actionsCard,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right Column
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      statsRow,
                      const SizedBox(height: 16),
                      fuelBreakdown,
                      const SizedBox(height: 16),
                      Expanded(
                        child: recentTransactionsList,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile/Tablet stacked scrollable layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(staff),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                profileCard,
                const SizedBox(height: 16),
                actionsCard,
                const SizedBox(height: 16),
                statsRow,
                const SizedBox(height: 16),
                fuelBreakdown,
                const SizedBox(height: 16),
                recentTransactionsList,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(StaffMember staff) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              staff.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelBreakdownCard(StaffPerformance performance, NumberFormat formatter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Sales Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            context.isMobile
                ? Column(
                    children: [
                      _buildFuelItem(
                        'Petrol',
                        performance.petrolLiters,
                        performance.petrolRevenue,
                        formatter,
                        const Color(0xFF3B82F6),
                      ),
                      const SizedBox(height: 12),
                      _buildFuelItem(
                        'Diesel',
                        performance.dieselLiters,
                        performance.dieselRevenue,
                        formatter,
                        const Color(0xFFF59E0B),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildFuelItem(
                          'Petrol',
                          performance.petrolLiters,
                          performance.petrolRevenue,
                          formatter,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFuelItem(
                          'Diesel',
                          performance.dieselLiters,
                          performance.dieselRevenue,
                          formatter,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelItem(String fuel, double liters, double revenue, NumberFormat formatter, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fuel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${liters.toStringAsFixed(1)} L',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          Text(
            formatter.format(revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> txn, NumberFormat formatter) {
    final fuelType = txn['fuelType'] as String? ?? 'Petrol';
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final liters = (txn['liters'] as num?)?.toDouble() ?? 0;
    final createdAt = txn['createdAt'] as String? ?? '';
    final fuelColor = fuelType == 'Petrol' ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: fuelColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.local_gas_station, color: fuelColor, size: 20),
      ),
      title: Row(
        children: [
          Text('$fuelType Sale'),
          const Spacer(),
          Text(
            formatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      subtitle: Text('${liters.toStringAsFixed(1)} L • ${_formatDateTime(createdAt)}'),
    );
  }

  Widget _buildEmptyTransactions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No transactions yet',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(staffDetailsProvider.notifier).loadStaffDetails(widget.staffId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(StaffMember staff) {
    final isActive = staff.status == 'active';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Deactivate Staff' : 'Activate Staff'),
        content: Text(
          isActive
              ? 'Are you sure you want to deactivate ${staff.name}?'
              : 'Are you sure you want to reactivate ${staff.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isActive) {
                await ref.read(staffListProvider.notifier).deactivateStaff(staff.id);
              } else {
                await ref.read(staffListProvider.notifier).activateStaff(staff.id);
              }
              ref.read(staffDetailsProvider.notifier).loadStaffDetails(widget.staffId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppTheme.errorColor : AppTheme.successColor,
            ),
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
