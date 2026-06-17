import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});
  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  String _filter = 'all';
  final _types = ['all', 'notes', 'practicePaper', 'videoLink', 'reference'];

  @override
  Widget build(BuildContext context) {
    final matAsync = ref.watch(materialsProvider);
    return PageScaffold(
      title: 'Study Materials',
      body: Column(
        children: [
          _TypeFilter(selected: _filter, types: _types, onSelect: (t) => setState(() => _filter = t)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(materialsProvider),
              child: matAsync.when(
                loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 70))))),
                error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(materialsProvider)),
                data: (items) {
                  final filtered = _filter == 'all' ? items : items.where((m) => (m as Map)['type'] == _filter).toList();
                  return filtered.isEmpty
                      ? const EmptyState(message: 'No materials available', icon: Icons.menu_book_outlined)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MaterialTile(material: filtered[i] as Map<String, dynamic>, ref: ref),
                          ),
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  final String selected;
  final List<String> types;
  final ValueChanged<String> onSelect;
  const _TypeFilter({required this.selected, required this.types, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.cardBg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: types.map((t) {
          final sel = t == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider),
                ),
                child: Text(
                  t == 'all' ? 'All' : _label(t),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? Colors.white : AppTheme.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String t) => switch (t) {
    'notes' => 'Notes',
    'practicePaper' => 'Practice',
    'videoLink' => 'Videos',
    'reference' => 'Reference',
    _ => t,
  };
}

class _MaterialTile extends StatelessWidget {
  final Map<String, dynamic> material;
  final WidgetRef ref;
  const _MaterialTile({required this.material, required this.ref});

  static const _typeIcons = {
    'notes': (Icons.description_outlined, AppTheme.primary),
    'practicePaper': (Icons.quiz_outlined, AppTheme.warning),
    'videoLink': (Icons.play_circle_outline, AppTheme.error),
    'reference': (Icons.book_outlined, AppTheme.success),
  };

  @override
  Widget build(BuildContext context) {
    final title = material['title'] ?? 'Material';
    final type = material['type'] ?? 'notes';
    final subject = material['subjectName'] ?? material['subject'] ?? '';
    final size = material['fileSize'];
    final (icon, color) = _typeIcons[type] ?? (Icons.attach_file, AppTheme.primary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 3),
          Row(children: [
            if (subject.isNotEmpty) ...[Text(subject, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)), const Text(' · ', style: TextStyle(color: AppTheme.textSecondary))],
            Text(type, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            if (size != null) ...[const Text(' · ', style: TextStyle(color: AppTheme.textSecondary)), Text('$size', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))],
          ]),
        ])),
        IconButton(
          icon: Icon(type == 'videoLink' ? Icons.open_in_new : Icons.download_outlined, color: AppTheme.primary, size: 20),
          onPressed: () async {
            try {
              final repo = ref.read(schoolRepoProvider);
              final res = await repo.getMaterialDownloadUrl(material['id']);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['url'] ?? 'Download started'), backgroundColor: AppTheme.success));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
            }
          },
        ),
      ]),
    );
  }
}
