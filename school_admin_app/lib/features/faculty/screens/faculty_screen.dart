import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class FacultyScreen extends ConsumerStatefulWidget {
  const FacultyScreen({super.key});
  @override
  ConsumerState<FacultyScreen> createState() => _State();
}

class _State extends ConsumerState<FacultyScreen> {
  String _search = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Faculty & Staff',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Faculty', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _ctrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(hintText: 'Search faculty...', prefixIcon: const Icon(Icons.search, size: 20), suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _ctrl.clear(); setState(() => _search = ''); }) : null, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ),
        Expanded(child: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(adminRepoProvider).getFaculty(search: _search.isNotEmpty ? _search : null),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) return Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(5, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: const ShimmerBox(height: 72)))));
            if (snap.hasError) return ErrorState(message: snap.error.toString());
            final faculty = (snap.data?['items'] ?? snap.data?['faculty'] ?? []) as List;
            if (faculty.isEmpty) return const EmptyState(message: 'No faculty found', icon: Icons.badge_outlined);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: faculty.length,
              itemBuilder: (_, i) {
                final f = faculty[i] as Map<String, dynamic>;
                final name = '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}'.trim();
                final designation = f['designation'] ?? 'Faculty';
                final dept = f['department'] ?? '';
                final subjects = (f['subjects'] as List?)?.join(', ') ?? '';
                final empType = (f['employmentType'] ?? 'full_time').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      CircleAvatar(radius: 24, backgroundColor: AppTheme.secondary.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontSize: 16))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('$designation${dept.isNotEmpty ? " · $dept" : ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        if (subjects.isNotEmpty) Text(subjects, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      StatusBadge(label: empType == 'full_time' ? 'FT' : 'PT', color: empType == 'full_time' ? AppTheme.success : AppTheme.warning),
                    ]),
                  ),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  void _showAddSheet(BuildContext context) {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final desigCtrl = TextEditingController();
    String empType = 'full_time';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Faculty Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'First Name *'))), const SizedBox(width: 10), Expanded(child: TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Last Name')))]),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *')),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department'))), const SizedBox(width: 10), Expanded(child: TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Designation')))]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: empType, decoration: const InputDecoration(labelText: 'Employment Type'), items: [const DropdownMenuItem(value: 'full_time', child: Text('Full Time')), const DropdownMenuItem(value: 'part_time', child: Text('Part Time'))], onChanged: (v) => setS(() => empType = v!)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: firstCtrl.text.isEmpty || emailCtrl.text.isEmpty ? null : () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepoProvider).createFaculty({'firstName': firstCtrl.text, 'lastName': lastCtrl.text, 'email': emailCtrl.text, 'department': deptCtrl.text, 'designation': desigCtrl.text, 'employmentType': empType});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faculty member added!'), backgroundColor: AppTheme.success));
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Add Faculty'),
          )),
        ]),
      )),
    );
  }
}
