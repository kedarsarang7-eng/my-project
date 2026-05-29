import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _State();
}

class _State extends ConsumerState<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Leave Management',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply Leave', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'My Leaves'), Tab(text: 'Pending Approvals')],
        ),
        Expanded(child: TabBarView(controller: _tabs, children: [_MyLeaves(ref: ref), _PendingApprovals(ref: ref)])),
      ]),
    );
  }

  void _showApplyDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    String type = 'casual';
    DateTime? from, to;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Apply for Leave', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Leave Type'), items: ['casual', 'sick', 'earned', 'emergency'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(), onChanged: (v) => setS(() => type = v!)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90))); if (d != null) setS(() => from = d); }, icon: const Icon(Icons.calendar_today, size: 16), label: Text(from != null ? DateFormat('d MMM').format(from!) : 'From'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(), firstDate: from ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90))); if (d != null) setS(() => to = d); }, icon: const Icon(Icons.calendar_today, size: 16), label: Text(to != null ? DateFormat('d MMM').format(to!) : 'To'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: (from == null || to == null) ? null : () async {
              Navigator.pop(ctx);
              try {
                await ref.read(teacherRepoProvider).applyLeave({'leaveType': type, 'startDate': DateFormat('yyyy-MM-dd').format(from!), 'endDate': DateFormat('yyyy-MM-dd').format(to!), 'reason': reasonCtrl.text, 'personType': 'faculty'});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave application submitted!'), backgroundColor: AppTheme.success));
                ref.invalidate(myLeaveProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Submit Application'),
          )),
        ]),
      )),
    );
  }
}

class _MyLeaves extends StatelessWidget {
  final WidgetRef ref;
  const _MyLeaves({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myLeaveProvider);
    return async.when(
      loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 72))))),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (items) => items.isEmpty
          ? const EmptyState(message: 'No leave applications', icon: Icons.event_busy_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final leave = items[i] as Map<String, dynamic>;
                final status = (leave['status'] ?? 'pending').toString();
                Color c = AppTheme.warning;
                if (status == 'approved') c = AppTheme.success;
                if (status == 'rejected') c = AppTheme.error;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      Icon(Icons.event_busy_rounded, color: c, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((leave['leaveType'] ?? 'Leave').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${leave['startDate']} → ${leave['endDate']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ])),
                      StatusBadge(label: status.toUpperCase(), color: c),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class _PendingApprovals extends StatelessWidget {
  final WidgetRef ref;
  const _PendingApprovals({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingLeavesProvider);
    return async.when(
      loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 80))))),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (items) => items.isEmpty
          ? const EmptyState(message: 'No pending leave requests', icon: Icons.check_circle_outline)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final leave = items[i] as Map<String, dynamic>;
                final student = leave['studentName'] ?? leave['applicantName'] ?? 'Student';
                final type = (leave['leaveType'] ?? 'leave').toString();
                final from = leave['startDate'] ?? '';
                final to = leave['endDate'] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(student, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${type.toUpperCase()} · $from → $to', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      if (leave['reason'] != null) Text(leave['reason'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await ref.read(teacherRepoProvider).approveLeave(leave['id'], false);
                              ref.invalidate(pendingLeavesProvider);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
                            }
                          },
                          icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                          label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error)),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await ref.read(teacherRepoProvider).approveLeave(leave['id'], true);
                              ref.invalidate(pendingLeavesProvider);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
                            }
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        )),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
