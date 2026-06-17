import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});
  @override
  ConsumerState<StudentsScreen> createState() => _State();
}

class _State extends ConsumerState<StudentsScreen> {
  String? _batchId;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider);

    return PageScaffold(
      title: 'My Students',
      body: batchesAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: ShimmerBox(height: 200)),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (batches) => Column(children: [
          _buildFilters(batches),
          Expanded(child: _StudentList(batchId: _batchId, search: _search)),
        ]),
      ),
    );
  }

  Widget _buildFilters(List<dynamic> batches) {
    return Container(
      color: AppTheme.cardBg,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search students...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _batchChip(null, 'All Batches'),
            ...batches.map((b) => _batchChip((b as Map)['id'], b['name'] ?? b['id'])),
          ]),
        ),
      ]),
    );
  }

  Widget _batchChip(String? id, String label) {
    final sel = _batchId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _batchId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? Colors.white : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}

class _StudentList extends ConsumerWidget {
  final String? batchId;
  final String search;
  const _StudentList({this.batchId, required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(teacherRepoProvider).getStudents(batchId: batchId, search: search.isNotEmpty ? search : null),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(5, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: const ShimmerBox(height: 68)))));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final students = snap.data ?? [];
        if (students.isEmpty) return const EmptyState(message: 'No students found', icon: Icons.people_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (_, i) {
            final s = students[i] as Map<String, dynamic>;
            final name = '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
            final id = s['studentId'] ?? '';
            final att = (s['attendancePercentage'] ?? 0) as num;
            final batch = s['batchName'] ?? '';
            final attColor = att >= 75 ? AppTheme.success : att >= 60 ? AppTheme.warning : AppTheme.error;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22, backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$id${batch.isNotEmpty ? ' · $batch' : ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${att.toStringAsFixed(0)}%', style: TextStyle(color: attColor, fontWeight: FontWeight.w700, fontSize: 14)),
                    const Text('attendance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
