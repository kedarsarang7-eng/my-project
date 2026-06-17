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
  String _search = '';
  String? _batchId;
  String _status = 'active';
  int _page = 1;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider);

    return PageScaffold(
      title: 'Students',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Student', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        _buildFilters(batchesAsync.value ?? []),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildFilters(List<dynamic> batches) => Container(
        color: AppTheme.cardBg,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _search = v;
              _page = 1;
            }),
            decoration: InputDecoration(
              hintText: 'Search by name or ID...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _search = '';
                          _page = 1;
                        });
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _statusChip('active', 'Active'),
              _statusChip('inactive', 'Inactive'),
              _statusChip('graduated', 'Graduated'),
              const SizedBox(width: 8),
              ...batches.map((b) {
                final batch = b as Map<String, dynamic>;
                final sel = _batchId == batch['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _batchId = sel ? null : batch['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: sel ? AppTheme.secondary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  sel ? AppTheme.secondary : AppTheme.divider)),
                      child: Text(batch['name'] ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  sel ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              }),
            ]),
          ),
        ]),
      );

  Widget _statusChip(String status, String label) {
    final sel = _status == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _status = status;
          _page = 1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: sel ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: sel ? AppTheme.primary : AppTheme.divider)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: sel ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepoProvider).getStudents(
          page: _page,
          search: _search.isNotEmpty ? _search : null,
          batchId: _batchId,
          status: _status),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  children: List.generate(
                      6,
                      (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: const ShimmerBox(height: 72)))));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final students =
            (snap.data?['items'] ?? snap.data?['students'] ?? []) as List;
        final total = snap.data?['total'] ?? students.length;
        if (students.isEmpty)
          return const EmptyState(
              message: 'No students found', icon: Icons.people_outlined);

        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text('$total students',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Text('Page $_page',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: students.length,
              itemBuilder: (_, i) {
                final s = students[i] as Map<String, dynamic>;
                final name =
                    '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
                final id = s['studentId'] ?? '';
                final batch = s['batchName'] ?? '';
                final status = (s['status'] ?? 'active').toString();
                Color statusColor = AppTheme.success;
                if (status == 'inactive') statusColor = AppTheme.error;
                if (status == 'graduated') statusColor = AppTheme.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('$id${batch.isNotEmpty ? " · $batch" : ""}',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11)),
                          ])),
                      StatusBadge(
                          label: status.toUpperCase(), color: statusColor),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  void _showAddSheet(BuildContext context) {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? batchId;
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
                      const Text('Add New Student',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: firstCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'First Name *'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: lastCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Last Name')))
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration:
                                    const InputDecoration(labelText: 'Phone'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: DropdownButtonFormField<String>(
                                initialValue: batchId,
                                hint: const Text('Batch'),
                                decoration:
                                    const InputDecoration(labelText: 'Batch'),
                                items: batches
                                    .map((b) => DropdownMenuItem<String>(
                                        value: (b as Map)['id'],
                                        child: Text(b['name'] ?? '')))
                                    .toList(),
                                onChanged: (v) => setS(() => batchId = v)))
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: firstCtrl.text.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await ref
                                          .read(adminRepoProvider)
                                          .createStudent({
                                        'firstName': firstCtrl.text,
                                        'lastName': lastCtrl.text,
                                        'email': emailCtrl.text,
                                        'phone': phoneCtrl.text,
                                        if (batchId != null) 'batchId': batchId
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Student added!'),
                                              backgroundColor:
                                                  AppTheme.success));
                                      setState(() {});
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor: AppTheme.error));
                                    }
                                  },
                            child: const Text('Add Student'),
                          )),
                    ]),
              )),
    );
  }
}
