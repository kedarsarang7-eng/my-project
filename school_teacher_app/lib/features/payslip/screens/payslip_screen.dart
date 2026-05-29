import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class PayslipScreen extends ConsumerWidget {
  const PayslipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payslipsProvider);

    return PageScaffold(
      title: 'My Payslips',
      body: async.when(
        loading: () => Padding(padding: const EdgeInsets.all(16), child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: const ShimmerBox(height: 80))))),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (payslips) => payslips.isEmpty
            ? const EmptyState(message: 'No payslips available', icon: Icons.receipt_long_outlined)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payslips.length,
                itemBuilder: (_, i) {
                  final p = payslips[i] as Map<String, dynamic>;
                  final month = p['month'] ?? p['payPeriod'] ?? '';
                  final netPay = (p['netPay'] ?? p['netSalary'] ?? 0) as num;
                  final grossPay = (p['grossSalary'] ?? netPay) as num;
                  final deductions = (p['totalDeductions'] ?? 0) as num;
                  final status = (p['status'] ?? 'generated').toString();
                  final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_rounded, color: AppTheme.success, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(month, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Gross: ${fmt.format(grossPay)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(fmt.format(netPay), style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 18)),
                            StatusBadge(label: status.toUpperCase(), color: status == 'paid' ? AppTheme.success : AppTheme.warning),
                          ]),
                        ]),
                        const Divider(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _row('Gross', fmt.format(grossPay), AppTheme.textPrimary),
                          _row('Deductions', '- ${fmt.format(deductions)}', AppTheme.error),
                          _row('Net Pay', fmt.format(netPay), AppTheme.success),
                        ]),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.download_outlined, size: 16),
                            label: const Text('Download PDF'),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}
