import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';

import '../../services/staff_service.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/salary_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff Payroll Screen
///
/// View and manage salary records, generate payroll.
class StaffPayrollScreen extends StatefulWidget {
  final String? staffId;

  const StaffPayrollScreen({super.key, this.staffId});

  @override
  State<StaffPayrollScreen> createState() => _StaffPayrollScreenState();
}

class _StaffPayrollScreenState extends State<StaffPayrollScreen> {
  final _service = sl<StaffService>();

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<SalaryModel> _salaryRecords = [];
  List<StaffModel> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final staff = await _service.getAllStaff();
      final pendingSalaries = await _service.getPendingSalaries();

      setState(() {
        _staffList = staff;
        _salaryRecords = pendingSalaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }

    setState(() => _isLoading = false);
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
        title: const Text('Payroll'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _generatePayroll,
            icon: const Icon(Icons.add),
            label: const Text('Generate'),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Month Selector
          _buildMonthSelector(isDark, theme),

          // Summary Card
          _buildPayrollSummary(isDark, theme),

          // Staff Salary List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staffList.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _staffList.length,
                      itemBuilder: (_, i) =>
                          _buildStaffSalaryCard(_staffList[i], isDark),
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMonthSelector(bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.secondary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payroll Period',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  DateFormat(
                    'MMMM yyyy',
                  ).format(DateTime(_selectedYear, _selectedMonth)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousMonth,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _isCurrentMonth ? null : _nextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSummary(bool isDark, ThemeData theme) {
    double totalPayable = 0;
    double totalPaid = 0;

    for (final salary in _salaryRecords) {
      if (salary.month == _selectedMonth && salary.year == _selectedYear) {
        totalPayable += salary.netSalary;
        totalPaid += salary.paidAmount;
      }
    }

    // Estimate from staff base salaries if no records
    if (totalPayable == 0) {
      totalPayable = _staffList.fold(0.0, (sum, s) => sum + s.baseSalary);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildSummaryTile(
            'Total Payable',
            '₹${NumberFormat('#,##0').format(totalPayable)}',
            Icons.account_balance_wallet,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryTile(
            'Paid',
            '₹${NumberFormat('#,##0').format(totalPaid)}',
            Icons.check_circle,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryTile(
            'Pending',
            '₹${NumberFormat('#,##0').format(totalPayable - totalPaid)}',
            Icons.pending,
            Colors.orange,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffSalaryCard(StaffModel staff, bool isDark) {
    // Find salary record for this staff and selected month
    final salaryRecord = _salaryRecords
        .where(
          (s) =>
              s.staffId == staff.id &&
              s.month == _selectedMonth &&
              s.year == _selectedYear,
        )
        .firstOrNull;

    final netSalary = salaryRecord?.netSalary ?? staff.baseSalary;
    final paidAmount = salaryRecord?.paidAmount ?? 0;
    final isPaid = paidAmount >= netSalary;
    final isPartial = paidAmount > 0 && paidAmount < netSalary;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  staff.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
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
                      Text(
                        'Net: ₹${netSalary.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      if (isPartial) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Paid: ₹${paidAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Status & Action
            if (isPaid)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PAID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: () => _showPayDialog(staff, netSalary, paidAmount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPartial ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isPartial ? 'Pay Balance' : 'Pay'),
              ),
          ],
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
            Icons.payments_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No staff members',
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
            'Add staff to manage payroll',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          ),
        ],
      ),
    );
  }

  bool get _isCurrentMonth =>
      _selectedMonth == DateTime.now().month &&
      _selectedYear == DateTime.now().year;

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
    _loadData();
  }

  void _generatePayroll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Payroll?'),
        content: Text(
          'Generate salary records for all staff for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final staff in _staffList) {
        await _service.generateSalaryRecord(
          staffId: staff.id,
          month: _selectedMonth,
          year: _selectedYear,
        );
      }
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payroll generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showPayDialog(StaffModel staff, double netSalary, double paidAmount) {
    final remaining = netSalary - paidAmount;
    final amountController = TextEditingController(
      text: remaining.toStringAsFixed(0),
    );
    String paymentMode = 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay ${staff.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remaining: ₹${remaining.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              ],
              onChanged: (v) => paymentMode = v ?? 'CASH',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                // Find or create salary record
                final existingSalary = _salaryRecords
                    .where(
                      (s) =>
                          s.staffId == staff.id &&
                          s.month == _selectedMonth &&
                          s.year == _selectedYear,
                    )
                    .firstOrNull;

                if (existingSalary != null) {
                  await _service.markSalaryPaid(
                    id: existingSalary.id,
                    amount: amount,
                    paymentMode: paymentMode,
                  );
                }
                _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Paid ₹${amount.toStringAsFixed(0)} to ${staff.name}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }
}
