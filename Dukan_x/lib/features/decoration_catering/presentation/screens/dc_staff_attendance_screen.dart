// ============================================================================
// DC Staff Attendance Screen
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import '../widgets/dc_ui_kit.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcStaffAttendanceScreen extends ConsumerStatefulWidget {
  const DcStaffAttendanceScreen({super.key});

  @override
  ConsumerState<DcStaffAttendanceScreen> createState() => _DcStaffAttendanceScreenState();
}

class _DcStaffAttendanceScreenState extends ConsumerState<DcStaffAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, StaffAttendance> _attendance = {};
  bool _saving = false;

  static const _teal = Color(0xFF0D9488);

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(dcStaffProvider);

    return Scaffold(
      backgroundColor: DcColors.tealLight,
      body: BoundedBox(
        maxWidth: 800,
        child: Column(children: [
        DcGradientHeader(
          icon: Icons.how_to_reg,
          title: 'Staff Attendance',
          subtitle: 'Mark daily attendance for event staff',
          color: _teal,
        ),
        _buildDateSelector(),
        Expanded(
          child: staffAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => DcErrorState(error: e, onRetry: () => ref.invalidate(dcStaffProvider)),
            data: (staff) => _buildStaffList(staff),
          ),
        ),
        _buildSaveButton(),
      ]),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: _teal),
        const SizedBox(width: 12),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 7)),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Change'),
        ),
      ]),
    );
  }

  Widget _buildStaffList(List<DcStaff> staff) {
    if (staff.isEmpty) {
      return const Center(child: Text('No staff members found', style: TextStyle(color: Color(0xFF9CA3AF))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staff.length,
      itemBuilder: (_, i) {
        final s = staff[i];
        final attendance = _attendance[s.id] ?? StaffAttendance.present;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: s.roleColor.withValues(alpha: 0.2),
              child: Icon(Icons.person, color: s.roleColor),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(s.roleLabel, style: TextStyle(fontSize: 12, color: s.roleColor)),
              Text('₹${NumberFormat('#,##,###').format(s.dailyWage.round())}/day', 
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ])),
            _buildAttendanceToggle(s.id, attendance),
          ]),
        );
      },
    );
  }

  Widget _buildAttendanceToggle(String staffId, StaffAttendance current) {
    return SegmentedButton<StaffAttendance>(
      segments: const [
        ButtonSegment(value: StaffAttendance.present, label: Text('Present'), icon: Icon(Icons.check_circle)),
        ButtonSegment(value: StaffAttendance.halfDay, label: Text('Half'), icon: Icon(Icons.timelapse)),
        ButtonSegment(value: StaffAttendance.absent, label: Text('Absent'), icon: Icon(Icons.cancel)),
      ],
      selected: {current},
      onSelectionChanged: (Set<StaffAttendance> selected) {
        setState(() => _attendance[staffId] = selected.first);
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            if (current == StaffAttendance.present) return Colors.green.withValues(alpha: 0.2);
            if (current == StaffAttendance.halfDay) return Colors.orange.withValues(alpha: 0.2);
            return Colors.red.withValues(alpha: 0.2);
          }
          return null;
        }),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _saveAttendance,
          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving...' : 'Save Attendance'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_attendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance changes to save')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(dcRepositoryProvider);
      final dateStr = _selectedDate.toIso8601String().split('T').first;
      await repo.markAttendance(date: dateStr, attendance: _attendance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
