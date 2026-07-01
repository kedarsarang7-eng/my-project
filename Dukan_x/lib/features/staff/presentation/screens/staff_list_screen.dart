import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../widgets/ui/futuristic_button.dart';
import '../../services/staff_service.dart'; // Changed to Service
import '../../data/models/staff_model.dart';
import 'add_staff_screen.dart';
import 'staff_attendance_screen.dart';
import 'staff_payroll_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff List Screen
///
/// Displays all staff members with quick actions for attendance and payroll.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _service = sl<StaffService>();

  List<StaffModel> _staff = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final staff = await _service.getAllStaff(
        activeOnly: true,
      ); // Service allows explicit activeOnly param
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load staff: $e');
    }
  }

  List<StaffModel> get _filteredStaff {
    return _staff.where((s) {
      final matchesSearch =
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.phone.contains(_searchQuery);
      final matchesRole = _filterRole == 'all' || s.role.name == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();
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
        title: const Text('Staff Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaffAttendanceScreen(),
                ),
              );
            },
            tooltip: 'Attendance',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffPayrollScreen()),
              );
            },
            tooltip: 'Payroll',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search staff...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterChip(isDark),
              ],
            ),
          ),

          // Staff Summary Cards
          _buildSummaryCards(isDark, theme),

          // Staff List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStaff.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadStaff,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredStaff.length,
                      itemBuilder: (_, i) =>
                          _buildStaffCard(_filteredStaff[i], isDark),
                    ),
                  ),
          ),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddStaffScreen()),
          );
          if (result == true) _loadStaff();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildFilterChip(bool isDark) {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _filterRole = v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 20,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              _filterRole == 'all' ? 'All' : _filterRole,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('All Roles')),
        const PopupMenuItem(value: 'manager', child: Text('Managers')),
        const PopupMenuItem(value: 'cashier', child: Text('Cashiers')),
        const PopupMenuItem(value: 'salesperson', child: Text('Salespersons')),
        const PopupMenuItem(value: 'delivery', child: Text('Delivery')),
      ],
    );
  }

  Widget _buildSummaryCards(bool isDark, ThemeData theme) {
    final totalStaff = _staff.length;
    final activeStaff = _staff.where((s) => s.isActive).length;
    final totalSalary = _staff.fold(0.0, (sum, s) => sum + s.baseSalary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            'Total Staff',
            totalStaff.toString(),
            Icons.people,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Active',
            activeStaff.toString(),
            Icons.check_circle,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Monthly',
            '₹${(totalSalary / 1000).toStringAsFixed(0)}K',
            Icons.currency_rupee,
            Colors.orange,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffModel staff, bool isDark) {
    final roleColor = _getRoleColor(staff.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStaffDetails(staff),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      staff.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.role.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: roleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.phone,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staff.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Salary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${staff.baseSalary.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '/${staff.salaryType.name}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                ),

                // Menu
                PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(action, staff),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'attendance',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 18),
                          SizedBox(width: 8),
                          Text('Attendance'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'salary',
                      child: Row(
                        children: [
                          Icon(Icons.payments, size: 18),
                          SizedBox(width: 8),
                          Text('Salary History'),
                        ],
                      ),
                    ),
                    if (staff.isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(Icons.person_off, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Deactivate',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No staff members yet',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first team member to get started',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(StaffRole role) {
    switch (role) {
      case StaffRole.admin:
        return Colors.purple;
      case StaffRole.manager:
        return Colors.indigo;
      case StaffRole.cashier:
        return Colors.blue;
      case StaffRole.salesperson:
        return Colors.teal;
      case StaffRole.delivery:
        return Colors.orange;
      case StaffRole.stockKeeper:
        return Colors.brown;
      case StaffRole.accountant:
        return Colors.green;
      case StaffRole.caterer:
        return Colors.pink;
    }
  }

  void _handleAction(String action, StaffModel staff) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddStaffScreen(staff: staff)),
        ).then((result) {
          if (result == true) _loadStaff();
        });
        break;
      case 'attendance':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffAttendanceScreen(staffId: staff.id),
          ),
        );
        break;
      case 'salary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffPayrollScreen(staffId: staff.id),
          ),
        );
        break;
      case 'deactivate':
        _confirmDeactivate(staff);
        break;
    }
  }

  void _showStaffDetails(StaffModel staff) {
    // Navigate to edit for now
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddStaffScreen(staff: staff)),
    ).then((result) {
      if (result == true) _loadStaff();
    });
  }

  void _confirmDeactivate(StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff?'),
        content: Text('Are you sure you want to deactivate ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FuturisticButton.danger(
            label: 'Deactivate',
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteStaff(staff.id);
                _loadStaff();
              } catch (e) {
                _showError('Failed to delete staff: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
