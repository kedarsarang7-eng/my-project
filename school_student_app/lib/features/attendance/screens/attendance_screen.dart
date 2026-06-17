import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attAsync = ref.watch(attendanceProvider);

    return PageScaffold(
      title: 'My Attendance',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(attendanceProvider),
        child: attAsync.when(
          loading: () => const _Skeleton(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(attendanceProvider)),
          data: (data) => _AttendanceBody(data: data),
        ),
      ),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AttendanceBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final percent = (data['percentage'] ?? 0) as num;
    final present = (data['presentDays'] ?? 0) as num;
    final absent = (data['absentDays'] ?? 0) as num;
    final total = (data['totalDays'] ?? 0) as num;
    final records = (data['records'] as List?) ?? [];
    final color = percent >= 75 ? AppTheme.success : percent >= 60 ? AppTheme.warning : AppTheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall Attendance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('${percent.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _pill('✅ $present Present', Colors.white.withValues(alpha: 0.25)),
                          const SizedBox(width: 8),
                          _pill('❌ $absent Absent', Colors.white.withValues(alpha: 0.25)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80, height: 80,
                  child: CircularProgressIndicator(
                    value: percent / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(child: StatCard(label: 'Present', value: '$present', icon: Icons.check_circle_outline, color: AppTheme.success)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Absent', value: '$absent', icon: Icons.cancel_outlined, color: AppTheme.error)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Total Days', value: '$total', icon: Icons.calendar_today_outlined, color: AppTheme.primary)),
            ],
          ),
          const SectionHeader(title: 'Attendance History'),

          if (records.isEmpty)
            const EmptyState(message: 'No attendance records found', icon: Icons.fact_check_outlined)
          else
            ...records.map((r) => _RecordTile(record: r as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
  );
}

class _RecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = (record['status'] ?? 'absent').toString();
    final isPresent = status == 'present';
    final dateStr = record['date'] ?? '';
    DateTime? date;
    try { date = DateTime.parse(dateStr); } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (isPresent ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPresent ? Icons.check_rounded : Icons.close_rounded,
                color: isPresent ? AppTheme.success : AppTheme.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date != null ? DateFormat('EEEE, d MMM yyyy').format(date) : dateStr,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  if (record['subject'] != null)
                    Text(record['subject'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            StatusBadge(
              label: status.toUpperCase(),
              color: isPresent ? AppTheme.success : AppTheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const ShimmerBox(height: 140, radius: 20),
      const SizedBox(height: 16),
      Row(children: const [
        Expanded(child: ShimmerBox(height: 90, radius: 16)),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(height: 90, radius: 16)),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(height: 90, radius: 16)),
      ]),
      const SizedBox(height: 20),
      ...List.generate(5, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: const ShimmerBox(height: 60, radius: 12))),
    ]),
  );
}
