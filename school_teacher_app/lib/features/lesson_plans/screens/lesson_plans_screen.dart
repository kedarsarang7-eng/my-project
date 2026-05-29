import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LessonPlansScreen extends ConsumerWidget {
  const LessonPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lessonPlansProvider);

    return PageScaffold(
      title: 'Lesson Plans',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Plan', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(lessonPlansProvider),
        child: async.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 90))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(lessonPlansProvider)),
          data: (plans) => plans.isEmpty
              ? EmptyState(message: 'No lesson plans yet', icon: Icons.auto_stories_outlined, actionLabel: 'Create Plan', onAction: () => _showCreateSheet(context, ref))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (_, i) {
                    final plan = plans[i] as Map<String, dynamic>;
                    final subject = plan['subject'] ?? plan['subjectName'] ?? 'Subject';
                    final topic = plan['topic'] ?? plan['title'] ?? '';
                    final batch = plan['batchName'] ?? '';
                    final date = plan['plannedDate'] ?? plan['date'] ?? '';
                    final status = (plan['status'] ?? 'draft').toString();
                    Color c = AppTheme.warning;
                    if (status == 'completed') c = AppTheme.success;
                    if (status == 'in_progress') c = AppTheme.primary;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primary, size: 18)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if (topic.isNotEmpty) Text(topic, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ])),
                            StatusBadge(label: status.replaceAll('_', ' ').toUpperCase(), color: c),
                          ]),
                          if (batch.isNotEmpty || date.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              if (batch.isNotEmpty) ...[const Icon(Icons.people_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(batch, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))],
                              if (batch.isNotEmpty && date.isNotEmpty) const Text(' · ', style: TextStyle(color: AppTheme.textSecondary)),
                              if (date.isNotEmpty) ...[const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))],
                            ]),
                          ],
                          if (plan['learningObjectives'] != null) ...[
                            const SizedBox(height: 8),
                            Text(plan['learningObjectives'].toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final subCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final objCtrl = TextEditingController();
    String? batchId;
    DateTime? date;
    final batches = ref.read(batchesProvider).value ?? [];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create Lesson Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: batchId, hint: const Text('Select Batch'),
            decoration: const InputDecoration(labelText: 'Batch'),
            items: batches.map((b) => DropdownMenuItem<String>(value: (b as Map)['id'], child: Text(b['name'] ?? b['id']))).toList(),
            onChanged: (v) => setS(() => batchId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subject *')),
          const SizedBox(height: 12),
          TextField(controller: topicCtrl, decoration: const InputDecoration(labelText: 'Topic / Title')),
          const SizedBox(height: 12),
          TextField(controller: objCtrl, decoration: const InputDecoration(labelText: 'Learning Objectives'), maxLines: 2),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now().add(const Duration(days: 60)));
              if (d != null) setS(() => date = d);
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(date != null ? DateFormat('d MMM yyyy').format(date!) : 'Planned Date'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: subCtrl.text.isEmpty ? null : () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(teacherRepoProvider).createLessonPlan({
                    'subject': subCtrl.text,
                    'topic': topicCtrl.text,
                    'learningObjectives': objCtrl.text,
                    if (batchId != null) 'batchId': batchId,
                    if (date != null) 'plannedDate': DateFormat('yyyy-MM-dd').format(date!),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson plan created!'), backgroundColor: AppTheme.success));
                  ref.invalidate(lessonPlansProvider);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
                }
              },
              child: const Text('Create Plan'),
            ),
          ),
        ]),
      )),
    );
  }
}
