import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payrollProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return PageScaffold(
      title: 'Payroll',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(payrollProvider),
        child: async.when(
          loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12), child: const ShimmerBox(height: 80))))),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(payrollProvider)),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary cards
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
                children: [
                  StatCard(label: 'Total Staff', value: '${data['totalStaff'] ?? 0}', icon: Icons.badge_rounded, color: AppTheme.primary),
                  StatCard(label: 'This Month', value: fmt.format(data['currentMonthTotal'] ?? 0), icon: Icons.payments_rounded, color: AppTheme.success),
                  StatCard(label: 'Pending', value: fmt.format(data['pendingAmount'] ?? 0), icon: Icons.pending_rounded, color: AppTheme.warning),
                  StatCard(label: 'YTD', value: fmt.format(data['yearToDate'] ?? 0), icon: Icons.bar_chart_rounded, color: AppTheme.secondary),
                ],
              ),
              const SectionHeader(title: 'Staff Payroll'),
              ...((data['staffPayroll'] as List?) ?? []).map((p) {
                final staff = p as Map<String, dynamic>;
                final name = '${staff['firstName'] ?? ''} ${staff['lastName'] ?? ''}'.trim();
                final designation = staff['designation'] ?? 'Staff';
                final net = (staff['netSalary'] ?? staff['netPay'] ?? 0) as num;
                final status = (staff['paymentStatus'] ?? 'pending').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: AppTheme.secondary.withOpacity(0.1), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(designation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt.format(net), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 14)),
                        StatusBadge(label: status.toUpperCase(), color: status == 'paid' ? AppTheme.success : AppTheme.warning),
                      ]),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
