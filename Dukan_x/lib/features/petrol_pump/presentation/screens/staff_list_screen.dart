import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../staff/data/models/staff_member.dart';
import '../../../staff/providers/staff_provider.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff List Screen for Petrol Pump Owners/Managers
///
/// Desktop-optimized staff management with sidebar navigation
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(staffListProvider.notifier).loadStaffList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StaffMember> _getFilteredStaff(List<StaffMember> staff) {
    return staff.where((s) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final matchesSearch =
            s.name.toLowerCase().contains(query) ||
            s.email.toLowerCase().contains(query) ||
            (s.phone?.toLowerCase().contains(query) ?? false);
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_statusFilter != 'all') {
        if (_statusFilter == 'active' && s.status != 'active') return false;
        if (_statusFilter == 'inactive' && s.status != 'inactive') return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final staffState = ref.watch(staffListProvider);
    final filteredStaff = _getFilteredStaff(staffState.staff);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: BoundedBox(
          maxWidth: 1200,
          child: Row(
            children: [
              Expanded(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildSummaryCards(staffState),
                      const SizedBox(height: 24),
                      _buildSearchAndFilters(staffState),
                      const SizedBox(height: 16),
                      Expanded(
                        child: staffState.isLoading && staffState.staff.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : staffState.error != null &&
                                  staffState.staff.isEmpty
                            ? _buildError(staffState.error!)
                            : filteredStaff.isEmpty
                            ? _buildEmpty()
                            : _buildStaffList(filteredStaff),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Staff Management',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your petrol pump staff members',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryColor),
        ),
      ],
    );

    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/petrol-pump/staff/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        title,
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => context.push('/petrol-pump/staff/add'),
          icon: const Icon(Icons.add),
          label: const Text('Add Staff'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(StaffState state) {
    final totalStaff = state.staff.length;
    final activeStaff = state.staff.where((s) => s.status == 'active').length;
    final inactiveStaff = state.staff
        .where((s) => s.status == 'inactive')
        .length;

    final totalRevenue = state.staff.fold<double>(
      0,
      (sum, s) => sum + (s.totalRevenue ?? 0),
    );
    final totalTransactions = state.staff.fold<int>(
      0,
      (sum, s) => sum + (s.transactionsCount ?? 0),
    );

    final cards = [
      _buildSummaryCard(
        'Total Staff',
        totalStaff.toString(),
        Icons.people,
        AppTheme.primaryColor,
      ),
      _buildSummaryCard(
        'Active',
        activeStaff.toString(),
        Icons.check_circle,
        AppTheme.successColor,
      ),
      _buildSummaryCard(
        'Inactive',
        inactiveStaff.toString(),
        Icons.cancel,
        AppTheme.errorColor,
      ),
      _buildSummaryCard(
        'Total Revenue',
        NumberFormat.currency(
          locale: 'en_IN',
          symbol: sl<CurrencyService>().symbol,
          decimalDigits: 0,
        ).format(totalRevenue),
        Icons.currency_rupee,
        AppTheme.secondaryColor,
      ),
      _buildSummaryCard(
        'Transactions',
        NumberFormat.compact().format(totalTransactions),
        Icons.receipt_long,
        AppTheme.infoColor,
      ),
    ];

    if (context.isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: cards,
      );
    } else if (context.isTablet) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: cards,
      );
    }

    return Row(children: cards.map((c) => Expanded(child: c)).toList());
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(StaffState state) {
    if (context.isMobile) {
      return Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search staff...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _statusFilter = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => ref.read(staffListProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),
        const SizedBox(width: 16),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _statusFilter,
            isDense: true,
            borderRadius: BorderRadius.circular(8),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _statusFilter = value);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => ref.read(staffListProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildStaffList(List<StaffMember> staff) {
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: staff.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) => _buildStaffTile(staff[index]),
      ),
    );
  }

  Widget _buildStaffTile(StaffMember staff) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 0,
    );
    final isActive = staff.status == 'active';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive
            ? AppTheme.primaryColor
            : AppTheme.disabledColor,
        child: Text(
          staff.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Row(
        children: [
          Text(staff.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.successColor.withValues(alpha: 0.1)
                  : AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              staff.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(staff.email),
          if (staff.phone != null) Text(staff.phone!),
          const SizedBox(height: 4),
          Text(
            '${staff.role} • ${staff.transactionsCount ?? 0} transactions • ${currencyFormatter.format(staff.totalRevenue ?? 0)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => context.push('/petrol-pump/staff/${staff.id}'),
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'View Details',
          ),
          IconButton(
            onPressed: () => _showDeactivateDialog(staff),
            icon: Icon(
              isActive ? Icons.block : Icons.check_circle,
              color: isActive ? AppTheme.errorColor : AppTheme.successColor,
            ),
            tooltip: isActive ? 'Deactivate' : 'Activate',
          ),
        ],
      ),
      onTap: () => context.push('/petrol-pump/staff/${staff.id}'),
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
              ? 'Are you sure you want to deactivate ${staff.name}? They will no longer be able to log in.'
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
                await ref
                    .read(staffListProvider.notifier)
                    .deactivateStaff(staff.id);
              } else {
                await ref
                    .read(staffListProvider.notifier)
                    .activateStaff(staff.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? AppTheme.errorColor
                  : AppTheme.successColor,
            ),
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No staff members found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search'
                : 'Add your first staff member to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/petrol-pump/staff/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add Staff'),
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
            onPressed: () => ref.read(staffListProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
