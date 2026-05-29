import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});
  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon
  final _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final ttAsync = ref.watch(timetableProvider);

    return PageScaffold(
      title: 'My Timetable',
      body: ttAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [ShimmerBox(height: 60), SizedBox(height: 12), ShimmerBox(height: 300, radius: 16)]),
        ),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(timetableProvider)),
        data: (slots) => Column(
          children: [
            _DaySelector(days: _days, selected: _selectedDay, onSelect: (i) => setState(() => _selectedDay = i)),
            Expanded(child: _TimetableGrid(slots: slots, dayIndex: _selectedDay)),
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final List<String> days;
  final int selected;
  final ValueChanged<int> onSelect;
  const _DaySelector({required this.days, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(days.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  days[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  final List<dynamic> slots;
  final int dayIndex;
  const _TimetableGrid({required this.slots, required this.dayIndex});

  @override
  Widget build(BuildContext context) {
    final daySlots = slots.where((s) {
      final d = (s as Map<String, dynamic>)['dayOfWeek'];
      return (d is int ? d : int.tryParse(d?.toString() ?? '') ?? 0) == dayIndex + 1;
    }).toList();

    if (daySlots.isEmpty) {
      return const EmptyState(message: 'No classes scheduled for this day', icon: Icons.event_available_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: daySlots.length,
      itemBuilder: (_, i) => _SlotCard(slot: daySlots[i] as Map<String, dynamic>),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _SlotCard({required this.slot});

  static const _colors = [AppTheme.primary, AppTheme.secondary, AppTheme.success, AppTheme.warning, AppTheme.accent];

  @override
  Widget build(BuildContext context) {
    final subject = slot['subjectName'] ?? slot['subject'] ?? 'Class';
    final teacher = slot['facultyName'] ?? slot['teacher'] ?? '';
    final room = slot['room'] ?? slot['roomNo'] ?? '';
    final start = slot['startTime'] ?? '';
    final end = slot['endTime'] ?? '';
    final index = subject.hashCode % _colors.length;
    final color = _colors[index.abs()];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          if (teacher.isNotEmpty) Text(teacher, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          if (room.isNotEmpty) Text('Room $room', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(start, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('to', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        Text(end, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
