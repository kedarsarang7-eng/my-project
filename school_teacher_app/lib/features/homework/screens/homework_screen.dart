import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});
  @override
  ConsumerState<HomeworkScreen> createState() => _State();
}

class _State extends ConsumerState<HomeworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Homework',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Assign', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Assigned'), Tab(text: 'Submissions')],
        ),
        Expanded(
            child: TabBarView(
          controller: _tabs,
          children: [_AssignedTab(ref: ref), _SubmissionsTab(ref: ref)],
        )),
      ]),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedBatchId;
    DateTime? dueDate;

    final batchesAsync = ref.read(batchesProvider);
    final batches = batchesAsync.value ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Homework',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBatchId,
                        hint: const Text('Select Batch'),
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: batches
                            .map((b) => DropdownMenuItem<String>(
                                value: (b as Map)['id'],
                                child: Text(b['name'] ?? b['id'])))
                            .toList(),
                        onChanged: (v) => setS(() => selectedBatchId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: titleCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Title *')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Description / Instructions'),
                          maxLines: 3),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: ctx,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 30)));
                          if (d != null) setS(() => dueDate = d);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(dueDate != null
                            ? 'Due: ${DateFormat('d MMM yyyy').format(dueDate!)}'
                            : 'Set Due Date'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (titleCtrl.text.isEmpty ||
                                  selectedBatchId == null)
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await ref
                                        .read(teacherRepoProvider)
                                        .createHomework({
                                      'title': titleCtrl.text,
                                      'description': descCtrl.text,
                                      'batchId': selectedBatchId,
                                      if (dueDate != null)
                                        'dueDate': DateFormat('yyyy-MM-dd')
                                            .format(dueDate!),
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Homework assigned!'),
                                            backgroundColor: AppTheme.success));
                                    ref.invalidate(homeworkProvider);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor: AppTheme.error));
                                  }
                                },
                          child: const Text('Assign Homework'),
                        ),
                      ),
                    ]),
              )),
    );
  }
}

class _AssignedTab extends StatelessWidget {
  final WidgetRef ref;
  const _AssignedTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeworkProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(homeworkProvider),
      child: async.when(
        loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                children: List.generate(
                    3,
                    (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: const ShimmerBox(height: 90))))),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (items) => items.isEmpty
            ? const EmptyState(
                message: 'No homework assigned yet',
                icon: Icons.assignment_outlined,
                actionLabel: 'Assign Homework')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final hw = items[i] as Map<String, dynamic>;
                  final title = hw['title'] ?? 'Homework';
                  final batch = hw['batchName'] ?? '';
                  final dueDate = hw['dueDate'] ?? '';
                  final submitted = hw['submittedCount'] ?? 0;
                  final total = hw['totalStudents'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.divider)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14))),
                              StatusBadge(
                                  label: '$submitted/$total submitted',
                                  color: submitted == total
                                      ? AppTheme.success
                                      : AppTheme.warning),
                            ]),
                            const SizedBox(height: 6),
                            if (batch.isNotEmpty)
                              Text('Batch: $batch',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                            if (dueDate.isNotEmpty)
                              Text('Due: $dueDate',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                            if (total > 0) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? submitted / total : 0,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.success),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SubmissionsTab extends StatelessWidget {
  final WidgetRef ref;
  const _SubmissionsTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeworkProvider);
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(16), child: ShimmerBox(height: 200)),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (items) {
        if (items.isEmpty)
          return const EmptyState(
              message: 'No submissions yet',
              icon: Icons.assignment_turned_in_outlined);
        final hw = items.first as Map<String, dynamic>;
        return FutureBuilder<List<dynamic>>(
          future: ref
              .read(teacherRepoProvider)
              .getHomeworkSubmissions(hw['id'] ?? ''),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Padding(
                  padding: EdgeInsets.all(16), child: ShimmerBox(height: 200));
            if (snap.hasError)
              return ErrorState(message: snap.error.toString());
            final subs = snap.data ?? [];
            if (subs.isEmpty)
              return const EmptyState(
                  message: 'No submissions yet',
                  icon: Icons.assignment_turned_in_outlined);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subs.length,
              itemBuilder: (_, i) {
                final sub = subs[i] as Map<String, dynamic>;
                final student = sub['studentName'] ?? 'Student';
                // ignore: unused_local_variable
                final status = sub['status'] ?? 'submitted';
                final grade = sub['grade'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      const Icon(Icons.person_rounded,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(student,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500))),
                      if (grade != null)
                        Text('Grade: $grade',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600)),
                      if (grade == null)
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12)),
                          child: const Text('Grade'),
                        ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
