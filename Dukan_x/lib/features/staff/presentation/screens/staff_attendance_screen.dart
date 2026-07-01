import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../services/staff_service.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/attendance_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Staff Attendance Screen
///
/// Mark and view attendance for all staff members.
class StaffAttendanceScreen extends StatefulWidget {
  final String? staffId; // If provided, show single staff attendance

  const StaffAttendanceScreen({super.key, this.staffId});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  final _service = sl<StaffService>();

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _todayAttendance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);

    try {
      final attendance = await _service.getTodayAttendance();
      setState(() {
        _todayAttendance = attendance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
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
        title: const Text('Attendance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Date Selector
          _buildDateHeader(isDark, theme),

          // Summary Cards
          _buildSummaryCards(isDark),

          const SizedBox(height: 8),

          // Staff Attendance List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todayAttendance.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadAttendance,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _todayAttendance.length,
                      itemBuilder: (_, i) =>
                          _buildAttendanceCard(_todayAttendance[i], isDark),
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDateHeader(bool isDark, ThemeData theme) {
    final isToday =
        _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
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
            child: const Icon(Icons.calendar_today, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  DateFormat('dd MMMM, yyyy').format(_selectedDate),
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
                onPressed: () => _changeDate(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _selectedDate.isBefore(DateTime.now())
                    ? () => _changeDate(1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    int present = 0, absent = 0, notMarked = 0;

    for (final item in _todayAttendance) {
      final status = item['status'] as String;
      if (status == 'PRESENT' || status == AttendanceStatus.present.name) {
        present++;
      } else if (status == 'ABSENT' || status == AttendanceStatus.absent.name) {
        absent++;
      } else {
        notMarked++;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildSummaryTile(
            'Present',
            present.toString(),
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildSummaryTile('Absent', absent.toString(), Colors.red, isDark),
          const SizedBox(width: 12),
          _buildSummaryTile(
            'Not Marked',
            notMarked.toString(),
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
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> data, bool isDark) {
    final staff = data['staff'] as StaffModel;
    final status = data['status'] as String;
    final checkIn = data['checkIn'] as DateTime?;
    final checkOut = data['checkOut'] as DateTime?;

    final isMarked = status != 'NOT_MARKED';
    final statusColor = _getStatusColor(status);

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
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  staff.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                    color: statusColor,
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
                  if (isMarked && checkIn != null)
                    Row(
                      children: [
                        Icon(
                          Icons.login,
                          size: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.Hm().format(checkIn),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        if (checkOut != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.logout,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.Hm().format(checkOut),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Text(
                      'Not marked yet',
                      style: TextStyle(fontSize: 12, color: Colors.orange[400]),
                    ),
                ],
              ),
            ),

            // Action Buttons
            if (!isMarked)
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () =>
                        _markAttendance(staff, AttendanceStatus.present),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.cancel,
                    color: Colors.red,
                    onTap: () =>
                        _markAttendance(staff, AttendanceStatus.absent),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.brightness_2,
                    color: Colors.orange,
                    onTap: () =>
                        _markAttendance(staff, AttendanceStatus.halfDay),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatStatus(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No staff to mark attendance',
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
            'Add staff members first',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'PRESENT' || status == AttendanceStatus.present.name) {
      return Colors.green;
    } else if (status == 'ABSENT' || status == AttendanceStatus.absent.name) {
      return Colors.red;
    } else if (status == 'HALF_DAY' ||
        status == AttendanceStatus.halfDay.name) {
      return Colors.orange;
    } else if (status == 'LEAVE' || status == AttendanceStatus.leave.name) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  String _formatStatus(String status) {
    if (status == 'PRESENT' || status == AttendanceStatus.present.name) {
      return 'Present';
    } else if (status == 'ABSENT' || status == AttendanceStatus.absent.name) {
      return 'Absent';
    } else if (status == 'HALF_DAY' ||
        status == AttendanceStatus.halfDay.name) {
      return 'Half Day';
    } else if (status == 'LEAVE' || status == AttendanceStatus.leave.name) {
      return 'On Leave';
    }
    return status;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadAttendance();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _loadAttendance();
    }
  }

  Future<void> _markAttendance(
    StaffModel staff,
    AttendanceStatus status,
  ) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    await _service.markAttendance(
      staffId: staff.id,
      date: _selectedDate,
      status: status.name.toUpperCase(),
      checkIn: status == AttendanceStatus.present ? DateTime.now() : null,
      markedBy: userId,
    );

    _loadAttendance();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${staff.name} marked as ${_formatStatus(status.name)}',
          ),
          backgroundColor: _getStatusColor(status.name),
        ),
      );
    }
  }
}
