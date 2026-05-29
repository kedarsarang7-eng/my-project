import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../services/report_card_pdf_service.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('My Results'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
      body: examsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 90)))),
        ),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(examsProvider)),
        data: (exams) {
          if (exams.isEmpty) return const Center(child: Text('No results yet'));
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: exams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final exam = exams[i] as Map<String, dynamic>;
              return _ExamCard(exam: exam, ref: ref);
            },
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final WidgetRef ref;
  const _ExamCard({required this.exam, required this.ref});

  @override
  Widget build(BuildContext context) {
    final name = exam['examName'] ?? 'Exam';
    final subjects = (exam['subjects'] as List? ?? []).cast<Map<String, dynamic>>();
    final totalMarks = subjects.fold<num>(0, (s, e) => s + ((e['marks'] ?? 0) as num));
    final maxMarks = subjects.fold<num>(0, (s, e) => s + ((e['maxMarks'] ?? 100) as num));
    final pct = maxMarks > 0 ? (totalMarks / maxMarks * 100) : 0.0;
    final grade = _grade(pct);
    final gradeColor = _gradeColor(grade);
    final fmt = NumberFormat('##0.0');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.05), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text('${exam['examDate'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: gradeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ]),
        ),

        // Subject marks
        if (subjects.isNotEmpty) ...[
          const Divider(height: 1),
          ...subjects.take(5).map((s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Text(s['subject']?.toString() ?? '-', style: const TextStyle(fontSize: 13))),
              Text('${s['marks']} / ${s['maxMarks']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )),
          if (subjects.length > 5) Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text('+${subjects.length - 5} more', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
        ],

        // Footer
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$totalMarks / $maxMarks', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('${fmt.format(pct)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])),
            TextButton.icon(
              onPressed: () => _downloadPdf(context, exam),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download PDF'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _printPdf(context, exam),
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.secondary),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _downloadPdf(BuildContext context, Map<String, dynamic> exam) async {
    try {
      final profile = await ref.read(profileProvider.future);
      await ReportCardPdfService.generate(student: profile, results: exam, examName: exam['examName'] ?? 'Exam', print: false);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report card saved!'), backgroundColor: Color(0xFF16A34A)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _printPdf(BuildContext context, Map<String, dynamic> exam) async {
    try {
      final profile = await ref.read(profileProvider.future);
      await ReportCardPdfService.generate(student: profile, results: exam, examName: exam['examName'] ?? 'Exam', print: true);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  String _grade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    if (pct >= 33) return 'D';
    return 'F';
  }

  Color _gradeColor(String grade) => switch (grade) {
    'A+' || 'A' => const Color(0xFF16A34A),
    'B+' || 'B' => const Color(0xFF0891B2),
    'C+' || 'C' => const Color(0xFFD97706),
    _           => const Color(0xFFDC2626),
  };
}
