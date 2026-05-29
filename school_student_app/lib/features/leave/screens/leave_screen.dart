import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> with SingleTickerProviderStateMixin {
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
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: const [Tab(text: 'My Applications'), Tab(text: 'Balance')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_LeaveList(ref: ref), _LeaveBalance(ref: ref)],
            ),
          ),
        ],
      ),
    );
  }

  void _showApplyDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    String type = 'sick';
    DateTime? from;
    DateTime? to;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apply for Leave', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: ['sick', 'casual', 'emergency', 'other'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setS(() => type = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setS(() => from = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(from != null ? DateFormat('d MMM').format(from!) : 'From Date'),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(), firstDate: from ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setS(() => to = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(to != null ? DateFormat('d MMM').format(to!) : 'To Date'),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (from == null || to == null) ? null : () async {
                    Navigator.pop(ctx);
                    final repo = ref.read(schoolRepoProvider);
                    try {
                      await repo.applyLeave({
                        'leaveType': type,
                        'startDate': DateFormat('yyyy-MM-dd').format(from!),
                        'endDate': DateFormat('yyyy-MM-dd').format(to!),
                        'reason': reasonCtrl.text,
                        'personType': 'student',
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave application submitted!'), backgroundColor: AppTheme.success));
                      ref.invalidate(leaveProvider);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
                    }
                  },
                  child: const Text('Submit Application'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveList extends StatelessWidget {
  final WidgetRef ref;
  const _LeaveList({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveProvider);
    return async.when(
      loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 80))))),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (items) => items.isEmpty
          ? const EmptyState(message: 'No leave applications', icon: Icons.event_busy_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LeaveTile(leave: items[i] as Map<String, dynamic>),
              ),
            ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveTile({required this.leave});

  @override
  Widget build(BuildContext context) {
    final status = (leave['status'] ?? 'pending').toString();
    final type = (leave['leaveType'] ?? 'leave').toString();
    final from = leave['startDate'] ?? '';
    final to = leave['endDate'] ?? '';
    final days = leave['days'] ?? leave['totalDays'] ?? 0;
    Color c = AppTheme.warning;
    if (status == 'approved') c = AppTheme.success;
    if (status == 'rejected') c = AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.event_busy_rounded, color: c, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('$from → $to ($days days)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (leave['reason'] != null) Text(leave['reason'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        StatusBadge(label: status.toUpperCase(), color: c),
      ]),
    );
  }
}

class _LeaveBalance extends StatelessWidget {
  final WidgetRef ref;
  const _LeaveBalance({required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveBalanceProvider);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: ShimmerBox(height: 200)),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (bal) {
        final types = (bal['balances'] as Map?) ?? {'sick': 10, 'casual': 8, 'emergency': 3};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: types.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BalanceTile(type: e.key, available: e.value as num),
          )).toList(),
        );
      },
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String type;
  final num available;
  const _BalanceTile({required this.type, required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Expanded(child: Text(type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
        Text('$available days', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }
}
