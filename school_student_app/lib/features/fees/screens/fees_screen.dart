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
    final feesAsync = ref.watch(feesProvider);

    return PageScaffold(
      title: 'Fee Payments',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feesProvider),
        child: feesAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120, radius: 20), SizedBox(height: 16), ShimmerBox(height: 200, radius: 16)])),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(feesProvider)),
          data: (data) => _FeesBody(data: data),
        ),
      ),
    );
  }
}

class _FeesBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeesBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final invoices = (data['invoices'] as List?) ?? [];
    final totalDue = (data['totalDue'] ?? 0) as num;
    final totalPaid = (data['totalPaid'] ?? 0) as num;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2D6A4F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fee Summary', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _feeStat('Due', fmt.format(totalDue), AppTheme.error),
                          const SizedBox(width: 20),
                          _feeStat('Paid', fmt.format(totalPaid), AppTheme.success),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.account_balance_wallet_rounded, size: 48, color: Colors.white30),
              ],
            ),
          ),
          const SectionHeader(title: 'Fee Invoices'),

          if (invoices.isEmpty)
            const EmptyState(message: 'No fee invoices found', icon: Icons.receipt_long_outlined)
          else
            ...invoices.map((inv) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InvoiceTile(invoice: inv as Map<String, dynamic>),
            )),
        ],
      ),
    );
  }

  Widget _feeStat(String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 20)),
      ],
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final status = (invoice['status'] ?? 'pending').toString();
    final amount = (invoice['totalAmount'] ?? 0) as num;
    final paid = (invoice['paidAmount'] ?? 0) as num;
    final due = (invoice['balance'] ?? amount - paid) as num;
    final desc = invoice['description'] ?? invoice['feeType'] ?? 'Fee';
    final dueDate = invoice['dueDate'];
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    Color statusColor = AppTheme.warning;
    if (status == 'paid') statusColor = AppTheme.success;
    if (status == 'overdue') statusColor = AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              StatusBadge(label: status.toUpperCase(), color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _amt('Total', fmt.format(amount), AppTheme.textPrimary)),
              Expanded(child: _amt('Paid', fmt.format(paid), AppTheme.success)),
              Expanded(child: _amt('Due', fmt.format(due), AppTheme.error)),
            ],
          ),
          if (dueDate != null) ...[
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('Due: $dueDate', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                if (status != 'paid' && due > 0)
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Pay Now'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amt(String label, String val, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
    ],
  );
}
