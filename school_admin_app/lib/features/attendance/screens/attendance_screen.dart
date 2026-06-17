import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<AttendanceScreen> {
  String? _batchId;
  String _fromDate = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7)));
  String _toDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider);

    return PageScaffold(
      title: 'Attendance Reports',
      body: Column(children: [
        _buildFilters(batchesAsync.value ?? []),
        Expanded(child: _buildReport()),
      ]),
    );
  }

  Widget _buildFilters(List<dynamic> batches) => Container(
    color: AppTheme.cardBg,
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      // Date range
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.parse(_fromDate), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now());
            if (d != null) setState(() => _fromDate = DateFormat('yyyy-MM-dd').format(d));
          },
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text('From: ${DateFormat('d MMM').format(DateTime.parse(_fromDate))}', style: const TextStyle(fontSize: 12)),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.parse(_toDate), firstDate: DateTime.parse(_fromDate), lastDate: DateTime.now());
            if (d != null) setState(() => _toDate = DateFormat('yyyy-MM-dd').format(d));
          },
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text('To: ${DateFormat('d MMM').format(DateTime.parse(_toDate))}', style: const TextStyle(fontSize: 12)),
        )),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _batchChip(null, 'All Classes'),
          ...batches.map((b) => _batchChip((b as Map)['id'], b['name'] ?? '')),
        ]),
      ),
    ]),
  );

  Widget _batchChip(String? id, String label) {
    final sel = _batchId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _batchId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
          child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildReport() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepoProvider).getAttendanceReport(batchId: _batchId, fromDate: _fromDate, toDate: _toDate),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 80)))));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final data = snap.data ?? {};
        final avgRate = (data['averageRate'] ?? data['averageAttendance'] ?? 0) as num;
        final batchReports = (data['batches'] ?? data['batchReports'] ?? []) as List;
        final lowAttendance = (data['lowAttendanceStudents'] ?? []) as List;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Overall stat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.fact_check_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Average Attendance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${avgRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32)),
                  Text('$_fromDate → $_toDate', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ]),
            ),

            if (batchReports.isNotEmpty) ...[
              const SectionHeader(title: 'By Class'),
              ...batchReports.map((b) {
                final batch = b as Map<String, dynamic>;
                final rate = (batch['attendanceRate'] ?? batch['rate'] ?? 0) as num;
                final color = rate >= 75 ? AppTheme.success : rate >= 60 ? AppTheme.warning : AppTheme.error;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(batch['batchName'] ?? 'Class', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${rate.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: rate / 100, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
                    ]),
                  ),
                );
              }),
            ],

            if (lowAttendance.isNotEmpty) ...[
              const SectionHeader(title: 'Low Attendance Alert'),
              ...lowAttendance.take(5).map((s) {
                final student = s as Map<String, dynamic>;
                final name = '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
                final rate = (student['attendanceRate'] ?? 0) as num;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
                    child: Row(children: [
                      const Icon(Icons.warning_rounded, color: AppTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              }),
            ],
          ]),
        );
      },
    );
  }
}
