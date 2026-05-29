import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/offline/attendance_offline_queue.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _selectedBatchId;
  String? _selectedBatchName;
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, String> _statusMap = {}; // studentId → present/absent/leave
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider);

    return PageScaffold(
      title: 'Mark Attendance',
      body: batchesAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: ShimmerBox(height: 200)),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (batches) => Column(children: [
          _buildHeader(batches),
          if (_selectedBatchId != null) Expanded(child: _buildStudentList()),
          if (_selectedBatchId == null) const Expanded(child: Center(child: Text('Select a batch to mark attendance', style: TextStyle(color: AppTheme.textSecondary)))),
        ]),
      ),
    );
  }

  Widget _buildHeader(List<dynamic> batches) {
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedBatchId,
              hint: const Text('Select Batch'),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: batches.map((b) {
                final batch = b as Map<String, dynamic>;
                return DropdownMenuItem<String>(value: batch['id'], child: Text(batch['name'] ?? batch['id']));
              }).toList(),
              onChanged: (v) {
                final batch = batches.firstWhere((b) => (b as Map)['id'] == v) as Map;
                setState(() { _selectedBatchId = v; _selectedBatchName = batch['name']; _statusMap = {}; });
              },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
              if (d != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(d));
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('d MMM').format(DateTime.parse(_date))),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStudentList() {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(teacherRepoProvider).getStudents(batchId: _selectedBatchId),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 60), SizedBox(height: 8), ShimmerBox(height: 60)]));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final students = snap.data ?? [];
        if (students.isEmpty) return const EmptyState(message: 'No students in this batch', icon: Icons.people_outlined);

        // Initialize all as present if not yet set
        for (final s in students) {
          final id = (s as Map)['id'] as String;
          _statusMap.putIfAbsent(id, () => 'present');
        }

        return Column(children: [
          // Summary row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(children: [
              _summaryChip('Present', _statusMap.values.where((v) => v == 'present').length, AppTheme.success),
              const SizedBox(width: 8),
              _summaryChip('Absent', _statusMap.values.where((v) => v == 'absent').length, AppTheme.error),
              const SizedBox(width: 8),
              _summaryChip('Leave', _statusMap.values.where((v) => v == 'leave').length, AppTheme.warning),
              const Spacer(),
              TextButton(onPressed: () => setState(() => _statusMap = {for (final s in students) (s as Map)['id'] as String: 'present'}), child: const Text('All Present')),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: students.length,
              itemBuilder: (_, i) {
                final s = students[i] as Map<String, dynamic>;
                final id = s['id'] as String;
                final name = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
                final rollNo = s['studentId'] ?? '';
                final status = _statusMap[id] ?? 'present';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor(status)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18, backgroundColor: AppTheme.primary.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(rollNo, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ])),
                      _AttendanceToggle(status: status, onChanged: (v) => setState(() => _statusMap[id] = v)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(students),
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Attendance'),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Color _borderColor(String status) {
    if (status == 'present') return AppTheme.success.withOpacity(0.3);
    if (status == 'absent') return AppTheme.error.withOpacity(0.3);
    return AppTheme.warning.withOpacity(0.3);
  }

  Widget _summaryChip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Text('$count $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Future<void> _submit(List<dynamic> students) async {
    setState(() => _submitting = true);
    try {
      final records = students.map((s) {
        final id = (s as Map)['id'] as String;
        return {'studentId': id, 'status': _statusMap[id] ?? 'present', 'batchId': _selectedBatchId, 'date': _date};
      }).toList();

      // Check connectivity — save offline if no internet
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        await AttendanceOfflineQueue.enqueue(records.cast<Map<String, dynamic>>());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved offline — will sync when internet is restored'),
          backgroundColor: AppTheme.warning,
          duration: Duration(seconds: 4),
        ));
      } else {
        await ref.read(teacherRepoProvider).markAttendance({
          'batchId': _selectedBatchId,
          'date': _date,
          'records': records,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance submitted!'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      // On failure, also queue offline
      final records = students.map((s) {
        final id = (s as Map)['id'] as String;
        return {'studentId': id, 'status': _statusMap[id] ?? 'present', 'batchId': _selectedBatchId, 'date': _date};
      }).toList();
      await AttendanceOfflineQueue.enqueue(records.cast<Map<String, dynamic>>());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved offline — will retry automatically'), backgroundColor: AppTheme.warning));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AttendanceToggle extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;
  const _AttendanceToggle({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _btn('P', 'present', AppTheme.success),
      const SizedBox(width: 4),
      _btn('A', 'absent', AppTheme.error),
      const SizedBox(width: 4),
      _btn('L', 'leave', AppTheme.warning),
    ]);
  }

  Widget _btn(String label, String value, Color color) {
    final sel = status == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30, height: 30,
        decoration: BoxDecoration(color: sel ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700))),
      ),
    );
  }
}
