import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materialsProvider);

    return PageScaffold(
      title: 'Study Materials',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context, ref),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(materialsProvider),
        child: async.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 68))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(materialsProvider)),
          data: (items) => items.isEmpty
              ? EmptyState(message: 'No materials uploaded yet', icon: Icons.menu_book_outlined, actionLabel: 'Upload Material', onAction: () => _showUploadSheet(context, ref))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i] as Map<String, dynamic>;
                    final title = m['title'] ?? 'Material';
                    final type = m['type'] ?? 'notes';
                    final batch = m['batchName'] ?? '';
                    final views = m['downloadCount'] ?? 0;
                    final icons = {'notes': Icons.description_outlined, 'practicePaper': Icons.quiz_outlined, 'videoLink': Icons.play_circle_outline, 'reference': Icons.book_outlined};
                    final colors = {'notes': AppTheme.primary, 'practicePaper': AppTheme.warning, 'videoLink': AppTheme.error, 'reference': AppTheme.success};
                    final icon = icons[type] ?? Icons.attach_file;
                    final color = colors[type] ?? AppTheme.primary;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('${type}${batch.isNotEmpty ? " · $batch" : ""} · $views downloads', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ])),
                          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), onPressed: () {}),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showUploadSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    String type = 'notes';
    String? batchId;
    final batches = ref.read(batchesProvider).value ?? [];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upload Material', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: batchId, hint: const Text('Select Batch'), decoration: const InputDecoration(labelText: 'Batch'), items: batches.map((b) => DropdownMenuItem<String>(value: (b as Map)['id'], child: Text(b['name'] ?? b['id']))).toList(), onChanged: (v) => setS(() => batchId = v)),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type'), items: ['notes', 'practicePaper', 'videoLink', 'reference'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setS(() => type = v!)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity, height: 100,
            decoration: BoxDecoration(border: Border.all(color: AppTheme.primary, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12), color: AppTheme.primary.withOpacity(0.04)),
            child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 32), SizedBox(height: 8), Text('Tap to select file', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500))])),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: titleCtrl.text.isEmpty ? null : () async {
              Navigator.pop(ctx);
              try {
                await ref.read(teacherRepoProvider).createMaterial({'title': titleCtrl.text, 'type': type, if (batchId != null) 'batchId': batchId});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material uploaded!'), backgroundColor: AppTheme.success));
                ref.invalidate(materialsProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Upload Material'),
          )),
        ]),
      )),
    );
  }
}
