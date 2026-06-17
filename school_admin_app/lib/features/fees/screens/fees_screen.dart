import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeAsync = ref.watch(feeOverviewProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return PageScaffold(
      title: 'Fee Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feeOverviewProvider),
        child: feeAsync.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 80))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(feeOverviewProvider)),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Fee summary cards
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
                children: [
                  StatCard(label: 'Total Collected', value: fmt.format(data['totalCollected'] ?? 0), icon: Icons.check_circle_rounded, color: AppTheme.success),
                  StatCard(label: 'Total Pending', value: fmt.format(data['totalPending'] ?? 0), icon: Icons.pending_rounded, color: AppTheme.error),
                  StatCard(label: 'This Month', value: fmt.format(data['thisMonth'] ?? 0), icon: Icons.calendar_month_rounded, color: AppTheme.primary),
                  StatCard(label: 'Overdue', value: '${data['overdueCount'] ?? 0}', icon: Icons.warning_rounded, color: AppTheme.warning, subtitle: 'students'),
                ],
              ),
              const SectionHeader(title: 'Collection Progress'),
              _CollectionProgress(data: data, fmt: fmt),
              const SectionHeader(title: 'Pending Fee Dues'),
              _PendingFeeList(ref: ref, fmt: fmt),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CollectionProgress extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  const _CollectionProgress({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final collected = (data['totalCollected'] ?? 0) as num;
    final total = (data['totalExpected'] ?? data['totalAmount'] ?? 1) as num;
    final pct = total > 0 ? (collected / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(1)}% collected', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${fmt.format(collected)} / ${fmt.format(total)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, backgroundColor: AppTheme.error.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success), minHeight: 10),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _dot(AppTheme.success, 'Collected: ${fmt.format(collected)}'),
          const SizedBox(width: 16),
          _dot(AppTheme.error, 'Pending: ${fmt.format(total - collected)}'),
        ]),
      ]),
    );
  }

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);
}

class _PendingFeeList extends StatelessWidget {
  final WidgetRef ref;
  final NumberFormat fmt;
  const _PendingFeeList({required this.ref, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(adminRepoProvider).getPendingFees(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: const ShimmerBox(height: 60))));
        if (snap.hasError) return ErrorState(message: snap.error.toString());
        final items = snap.data ?? [];
        if (items.isEmpty) return const EmptyState(message: 'No pending fees!', icon: Icons.check_circle_outline);

        return Column(children: items.take(10).map((f) {
          final fee = f as Map<String, dynamic>;
          final name = '${fee['firstName'] ?? ''} ${fee['lastName'] ?? ''}'.trim();
          final amount = (fee['pendingAmount'] ?? fee['amount'] ?? 0) as num;
          final dueDate = fee['dueDate'] ?? '';
          final isOverdue = fee['isOverdue'] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOverdue ? AppTheme.error.withValues(alpha: 0.04) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isOverdue ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.divider),
              ),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: (isOverdue ? AppTheme.error : AppTheme.warning).withValues(alpha: 0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: isOverdue ? AppTheme.error : AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Due: $dueDate${isOverdue ? " (OVERDUE)" : ""}', style: TextStyle(color: isOverdue ? AppTheme.error : AppTheme.textSecondary, fontSize: 11)),
                ])),
                Text(fmt.format(amount), style: TextStyle(color: isOverdue ? AppTheme.error : AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          );
        }).toList());
      },
    );
  }
}
