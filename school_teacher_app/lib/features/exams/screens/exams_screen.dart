import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: 'Exams & Results',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExamSheet(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label:
            const Text('Schedule Exam', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ref.read(teacherRepoProvider).getExams(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    children: List.generate(
                        3,
                        (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: const ShimmerBox(height: 80)))));
          if (snap.hasError) return ErrorState(message: snap.error.toString());
          final exams = snap.data ?? [];
          if (exams.isEmpty)
            return const EmptyState(
                message: 'No exams scheduled yet', icon: Icons.quiz_outlined);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            itemBuilder: (_, i) {
              final exam = exams[i] as Map<String, dynamic>;
              final subject = exam['subjectName'] ?? exam['subject'] ?? 'Exam';
              final batch = exam['batchName'] ?? '';
              final date = exam['examDate'] ?? exam['date'] ?? '';
              final type =
                  (exam['examType'] ?? 'exam').toString().toUpperCase();
              final maxMarks = exam['maxMarks'] ?? 100;
              final resultsUploaded = exam['resultsUploaded'] == true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider)),
                  child: Row(children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.quiz_rounded,
                            color: AppTheme.warning, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(subject,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${batch.isNotEmpty ? "$batch · " : ""}$date',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          Text('Max Marks: $maxMarks · $type',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ])),
                    Column(children: [
                      StatusBadge(label: type, color: AppTheme.warning),
                      const SizedBox(height: 6),
                      if (!resultsUploaded)
                        GestureDetector(
                          onTap: () => _showResultsSheet(context, ref, exam),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('Add Results',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        )
                      else
                        const StatusBadge(
                            label: 'RESULTS UP', color: AppTheme.success),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateExamSheet(BuildContext context, WidgetRef ref) {
    final subCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final marksCtrl = TextEditingController(text: '100');
    String? batchId;
    String type = 'unit_test';
    final batches = ref.read(batchesProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schedule Exam',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: batchId,
                          hint: const Text('Batch'),
                          decoration: const InputDecoration(labelText: 'Batch'),
                          items: batches
                              .map((b) => DropdownMenuItem<String>(
                                  value: (b as Map)['id'],
                                  child: Text(b['name'] ?? b['id'])))
                              .toList(),
                          onChanged: (v) => setS(() => batchId = v)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: subCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Subject *')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: dateCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Exam Date (YYYY-MM-DD)'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                controller: marksCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Max Marks'))),
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: ['unit_test', 'mid_term', 'final', 'practice']
                              .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                      t.replaceAll('_', ' ').toUpperCase())))
                              .toList(),
                          onChanged: (v) => setS(() => type = v!)),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: subCtrl.text.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await ref
                                          .read(teacherRepoProvider)
                                          .createExam({
                                        'subject': subCtrl.text,
                                        'batchId': batchId,
                                        'examDate': dateCtrl.text,
                                        'maxMarks':
                                            int.tryParse(marksCtrl.text) ?? 100,
                                        'examType': type
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Exam scheduled!'),
                                              backgroundColor:
                                                  AppTheme.success));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor: AppTheme.error));
                                    }
                                  },
                            child: const Text('Schedule'),
                          )),
                    ]),
              )),
    );
  }

  void _showResultsSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic> exam) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results upload coming soon')));
  }
}
