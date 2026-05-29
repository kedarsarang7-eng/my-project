import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingLeavesProvider);

    return PageScaffold(
      title: 'Leave Approvals',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingLeavesProvider),
        child: async.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 100))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(pendingLeavesProvider)),
          data: (items) => items.isEmpty
              ? const EmptyState(message: 'No pending leave requests', icon: Icons.check_circle_outline)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final leave = items[i] as Map<String, dynamic>;
                    final name = leave['applicantName'] ?? leave['studentName'] ?? leave['facultyName'] ?? 'Applicant';
                    final type = (leave['leaveType'] ?? 'leave').toString();
                    final from = leave['startDate'] ?? '';
                    final to = leave['endDate'] ?? '';
                    final days = leave['days'] ?? leave['totalDays'] ?? '';
                    final reason = leave['reason'] ?? '';
                    final personType = (leave['personType'] ?? 'student').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(radius: 20, backgroundColor: AppTheme.warning.withOpacity(0.1), child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${type.toUpperCase()}${days.isNotEmpty ? " · $days days" : ""}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ])),
                            StatusBadge(label: personType.toUpperCase(), color: personType == 'faculty' ? AppTheme.secondary : AppTheme.primary),
                          ]),
                          const SizedBox(height: 6),
                          Text('$from → $to', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(reason, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await ref.read(adminRepoProvider).processLeave(leave['id'], false);
                                  ref.invalidate(pendingLeavesProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave rejected'), backgroundColor: AppTheme.error));
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
                                  await ref.read(adminRepoProvider).processLeave(leave['id'], true);
                                  ref.invalidate(pendingLeavesProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved!'), backgroundColor: AppTheme.success));
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
        ),
      ),
    );
  }
}
