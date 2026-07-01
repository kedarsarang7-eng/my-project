// ============================================================================
// ACADEMIC COACHING — ATTENDANCE SCREEN
// ============================================================================
// Batch-based attendance marking with calendar view and student grid

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';

class AcAttendanceScreen extends StatefulWidget {
  const AcAttendanceScreen({super.key});

  @override
  State<AcAttendanceScreen> createState() => _AcAttendanceScreenState();
}

class _AcAttendanceScreenState extends State<AcAttendanceScreen> {
  late AcRepository _repository;

  // State
  List<AcBatch> _batches = [];
  List<AcStudent> _students = [];
  bool _isLoading = false;
  String? _error;

  // Selection
  AcBatch? _selectedBatch;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSubjectId;

  // Attendance records for the day
  Map<String, AttendanceStatus> _attendanceRecords = {};
  bool _hasExistingAttendance = false;

  @override
  void initState() {
    super.initState();
    _repository = AcRepository(sl<ApiClient>());
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _repository.listBatches(status: 'active');
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentsForBatch() async {
    if (_selectedBatch == null) return;

    setState(() => _isLoading = true);
    try {
      final studentsResponse = await _repository.listStudents(
        batchId: _selectedBatch!.id,
        status: 'active',
      );

      // Load existing attendance for the selected date
      final report = await _repository.getAttendanceReport(
        batchId: _selectedBatch!.id,
        fromDate: _selectedDate.toIso8601String().split('T')[0],
        toDate: _selectedDate.toIso8601String().split('T')[0],
      );

      // Parse existing attendance
      Map<String, AttendanceStatus> existingRecords = {};
      bool hasExisting = false;

      if (report is Map && report['records'] != null) {
        final records = report['records'] as Map;
        records.forEach((key, value) {
          existingRecords[key.toString()] = _parseAttendanceStatus(
            value.toString(),
          );
        });
        hasExisting = records.isNotEmpty;
      }

      setState(() {
        _students = studentsResponse.items;
        _attendanceRecords = existingRecords;
        _hasExistingAttendance = hasExisting;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  AttendanceStatus _parseAttendanceStatus(String status) {
    switch (status) {
      case 'P':
        return AttendanceStatus.present;
      case 'L':
        return AttendanceStatus.leave;
      default:
        return AttendanceStatus.absent;
    }
  }

  Future<void> _markAttendance() async {
    if (_selectedBatch == null || _students.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final attendanceData = _students
          .map(
            (s) => {
              'studentId': s.id,
              'status': _getStatusCode(
                _attendanceRecords[s.id] ?? AttendanceStatus.absent,
              ),
            },
          )
          .toList();

      await _repository.markAttendance({
        'batchId': _selectedBatch!.id,
        'subjectId': _selectedSubjectId,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'attendanceRecords': attendanceData,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        setState(() => _hasExistingAttendance = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getStatusCode(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.leave:
        return 'L';
      case AttendanceStatus.absent:
        return 'A';
    }
  }

  void _setAllStatus(AttendanceStatus status) {
    setState(() {
      for (var student in _students) {
        _attendanceRecords[student.id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  // Left Panel - Calendar & Batch Selection
                  Expanded(flex: 2, child: _buildLeftPanel()),
                  const SizedBox(width: 24),
                  // Right Panel - Student Grid
                  Expanded(flex: 3, child: _buildAttendancePanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mark and track student attendance',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/ac/attendance/report'),
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('Reports'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        // Batch Selection
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Batch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AcBatch?>(
                value: _selectedBatch,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Choose a batch',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: _batches
                    .map(
                      (batch) => DropdownMenuItem(
                        value: batch,
                        child: Text(
                          '${batch.name} (${batch.enrolledCount} students)',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedBatch = v;
                    _attendanceRecords = {};
                  });
                  _loadStudentsForBatch();
                },
              ),
              if (_selectedBatch != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: _selectedBatch!.schedule
                      .map(
                        (s) => Chip(
                          label: Text('${s.dayName} ${s.startTime}'),
                          backgroundColor: const Color(0xFFEEF2FF),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Calendar
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TableCalendar(
                    firstDay: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDay: DateTime.now(),
                    focusedDay: _selectedDate,
                    selectedDayPredicate: (day) =>
                        isSameDay(day, _selectedDate),
                    onDaySelected: (selected, focused) {
                      setState(() => _selectedDate = selected);
                      _loadStudentsForBatch();
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendancePanel() {
    if (_selectedBatch == null) {
      return _buildEmptyState(
        'Select a batch to mark attendance',
        Icons.class_outlined,
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return _buildEmptyState(
        'No students enrolled in this batch',
        Icons.people_outline,
      );
    }

    final presentCount = _attendanceRecords.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final absentCount = _attendanceRecords.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final leaveCount = _attendanceRecords.values
        .where((s) => s == AttendanceStatus.leave)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Stats
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBatch!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (_hasExistingAttendance)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Already marked',
                              style: TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quick Stats
                Row(
                  children: [
                    _buildStatChip(
                      'Present',
                      presentCount,
                      const Color(0xFF059669),
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      'Absent',
                      absentCount,
                      const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      'Leave',
                      leaveCount,
                      const Color(0xFFF59E0B),
                    ),
                    const Spacer(),
                    // Quick Actions
                    _buildQuickActionBtn(
                      'All Present',
                      const Color(0xFF059669),
                      () => _setAllStatus(AttendanceStatus.present),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionBtn(
                      'All Absent',
                      const Color(0xFFDC2626),
                      () => _setAllStatus(AttendanceStatus.absent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Student Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _students.length,
              itemBuilder: (ctx, i) {
                final student = _students[i];
                final status =
                    _attendanceRecords[student.id] ?? AttendanceStatus.absent;

                return _buildStudentCard(student, status);
              },
            ),
          ),
          const Divider(height: 1),
          // Footer Actions
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _attendanceRecords = {}),
                  child: const Text('Clear All'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _markAttendance,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Saving...' : 'Save Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(String label, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildStudentCard(AcStudent student, AttendanceStatus status) {
    return Container(
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _cycleStatus(student.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  child: Text(
                    student.firstName[0],
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.studentId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cycleStatus(String studentId) {
    setState(() {
      final current = _attendanceRecords[studentId] ?? AttendanceStatus.absent;
      AttendanceStatus next;
      switch (current) {
        case AttendanceStatus.absent:
          next = AttendanceStatus.present;
          break;
        case AttendanceStatus.present:
          next = AttendanceStatus.leave;
          break;
        case AttendanceStatus.leave:
          next = AttendanceStatus.absent;
          break;
      }
      _attendanceRecords[studentId] = next;
    });
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Color(0xFF059669);
      case AttendanceStatus.absent:
        return const Color(0xFFDC2626);
      case AttendanceStatus.leave:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.leave:
        return 'L';
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
