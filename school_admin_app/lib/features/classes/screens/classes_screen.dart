import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(batchesProvider);

    return PageScaffold(
      title: 'Classes & Batches',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Class', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(batchesProvider),
        child: async.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 80))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(batchesProvider)),
          data: (batches) => batches.isEmpty
              ? EmptyState(message: 'No classes created yet', icon: Icons.class_outlined, actionLabel: 'Create Class', onAction: () => _showAddSheet(context, ref))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
                  itemCount: batches.length,
                  itemBuilder: (_, i) {
                    final b = batches[i] as Map<String, dynamic>;
                    final name = b['name'] ?? 'Class';
                    final count = b['studentCount'] ?? b['enrolledStudents'] ?? 0;
                    final subject = b['subject'] ?? b['course'] ?? '';
                    final colors = [AppTheme.primary, AppTheme.secondary, AppTheme.success, AppTheme.warning, AppTheme.accent];
                    final color = colors[name.hashCode.abs() % colors.length];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.class_rounded, color: color, size: 20)),
                        const SizedBox(height: 10),
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (subject.isNotEmpty) Text(subject, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(children: [
                          const Icon(Icons.people_rounded, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('$count students', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '30');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create New Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name *')),
          const SizedBox(height: 12),
          TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject / Course')),
          const SizedBox(height: 12),
          TextField(controller: capacityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: nameCtrl.text.isEmpty ? null : () async {
              Navigator.pop(context);
              try {
                await ref.read(adminRepoProvider).createBatch({'name': nameCtrl.text, 'subject': subjectCtrl.text, 'capacity': int.tryParse(capacityCtrl.text) ?? 30});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class created!'), backgroundColor: AppTheme.success));
                ref.invalidate(batchesProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Create Class'),
          )),
        ]),
      ),
    );
  }
}
