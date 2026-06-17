import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});
  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Exams & Results',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            tabs: const [Tab(text: 'Upcoming Exams'), Tab(text: 'My Results')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ExamsList(ref: ref),
                _ResultsList(ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamsList extends StatelessWidget {
  final WidgetRef ref;
  const _ExamsList({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(examsProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Column(children: [ShimmerBox(height: 90), SizedBox(height: 10), ShimmerBox(height: 90)])),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (exams) => exams.isEmpty
          ? const EmptyState(message: 'No upcoming exams', icon: Icons.event_available_rounded)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exams.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExamCard(exam: exams[i] as Map<String, dynamic>),
              ),
            ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final subject = exam['subjectName'] ?? exam['name'] ?? 'Exam';
    final date = exam['examDate'] ?? exam['date'] ?? '';
    final type = (exam['examType'] ?? 'exam').toString().toUpperCase();
    final maxMarks = exam['maxMarks'] ?? 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text('Max Marks: $maxMarks', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          StatusBadge(label: type, color: AppTheme.warning),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final WidgetRef ref;
  const _ResultsList({required this.ref});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(schoolRepoProvider).getMyResults(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16), child: ShimmerBox(height: 200));
        }
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final results = (snap.data?['results'] as List?) ?? [];
        if (results.isEmpty) return const EmptyState(message: 'No results published yet', icon: Icons.bar_chart_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResultCard(result: results[i] as Map<String, dynamic>),
          ),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final subject = result['subjectName'] ?? 'Subject';
    final marks = result['marksObtained'] ?? 0;
    final maxMarks = result['maxMarks'] ?? 100;
    final grade = result['grade'] ?? '';
    final pct = maxMarks > 0 ? (marks / maxMarks * 100) : 0.0;
    Color gradeColor = AppTheme.success;
    if (pct < 35) gradeColor = AppTheme.error;
    else if (pct < 60) gradeColor = AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$marks / $maxMarks marks (${pct.toStringAsFixed(1)}%)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text(grade, style: TextStyle(color: gradeColor, fontWeight: FontWeight.w800, fontSize: 16))),
          ),
        ],
      ),
    );
  }
}
