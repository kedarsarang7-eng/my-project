import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class HomeworkScreen extends ConsumerWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hwAsync = ref.watch(homeworkProvider);

    return PageScaffold(
      title: 'Homework',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(homeworkProvider),
        child: hwAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 100, radius: 14)))),
          ),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(homeworkProvider)),
          data: (items) => items.isEmpty
              ? const EmptyState(message: 'No homework assigned', icon: Icons.assignment_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HomeworkCard(hw: items[i] as Map<String, dynamic>, ref: ref),
                  ),
                ),
        ),
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> hw;
  final WidgetRef ref;
  const _HomeworkCard({required this.hw, required this.ref});

  @override
  Widget build(BuildContext context) {
    final title = hw['title'] ?? 'Homework';
    final subject = hw['subjectName'] ?? hw['subject'] ?? '';
    final dueDateStr = hw['dueDate'] ?? '';
    final status = (hw['submissionStatus'] ?? 'pending').toString();
    final isLate = hw['isLate'] == true;

    DateTime? dueDate;
    try { dueDate = DateTime.parse(dueDateStr); } catch (_) {}
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && status == 'pending';

    Color statusColor = AppTheme.warning;
    if (status == 'submitted') statusColor = AppTheme.success;
    if (isOverdue || isLate) statusColor = AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOverdue ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.assignment_outlined, color: AppTheme.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (subject.isNotEmpty) Text(subject, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              StatusBadge(label: isOverdue ? 'OVERDUE' : status.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          if (hw['description'] != null)
            Text(hw['description'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: isOverdue ? AppTheme.error : AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                dueDate != null ? 'Due: ${DateFormat('d MMM yyyy').format(dueDate)}' : 'Due: $dueDateStr',
                style: TextStyle(fontSize: 12, color: isOverdue ? AppTheme.error : AppTheme.textSecondary),
              ),
              const Spacer(),
              if (status == 'pending' && !isOverdue)
                OutlinedButton(
                  onPressed: () => _showSubmitDialog(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Submit'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Homework'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Your answer / notes'), maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final repo = ref.read(schoolRepoProvider);
              try {
                await repo.submitHomework(hw['id'], {'textSubmission': ctrl.text});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework submitted!'), backgroundColor: AppTheme.success));
                ref.invalidate(homeworkProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
