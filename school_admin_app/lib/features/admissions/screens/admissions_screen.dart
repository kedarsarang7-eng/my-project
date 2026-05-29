import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AdmissionsScreen extends ConsumerStatefulWidget {
  const AdmissionsScreen({super.key});
  @override
  ConsumerState<AdmissionsScreen> createState() => _State();
}

class _State extends ConsumerState<AdmissionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Admissions',
      body: Column(children: [
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Rejected')],
        ),
        Expanded(child: TabBarView(
          controller: _tabs,
          children: [
            _AdmissionList(ref: ref, status: 'pending'),
            _AdmissionList(ref: ref, status: 'approved'),
            _AdmissionList(ref: ref, status: 'rejected'),
          ],
        )),
      ]),
    );
  }
}

class _AdmissionList extends StatelessWidget {
  final WidgetRef ref;
  final String status;
  const _AdmissionList({required this.ref, required this.status});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(adminRepoProvider).getAdmissions(status: status),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 90)))));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final items = (snap.data?['items'] ?? snap.data?['admissions'] ?? []) as List;
        if (items.isEmpty) return EmptyState(message: 'No ${status} applications', icon: Icons.how_to_reg_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final a = items[i] as Map<String, dynamic>;
            final name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
            final email = a['email'] ?? '';
            final phone = a['phone'] ?? '';
            final batch = a['requestedBatch'] ?? a['batchName'] ?? '';
            final appliedDate = a['appliedDate'] ?? a['createdAt'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: AppTheme.warning.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${email.isNotEmpty ? email : phone}${batch.isNotEmpty ? " · $batch" : ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    ])),
                    if (appliedDate.isNotEmpty) Text(appliedDate.toString().substring(0, 10), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ]),
                  if (status == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          try { await ref.read(adminRepoProvider).approveAdmission(a['id'], 'reject'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application rejected'), backgroundColor: AppTheme.error)); }
                          catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error)); }
                        },
                        icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                        label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(
                        onPressed: () async {
                          try { await ref.read(adminRepoProvider).approveAdmission(a['id'], 'approve'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admission approved!'), backgroundColor: AppTheme.success)); }
                          catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error)); }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                      )),
                    ]),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
