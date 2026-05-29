import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/data/school_repository.dart';

class FeePaymentScreen extends ConsumerStatefulWidget {
  const FeePaymentScreen({super.key});
  @override
  ConsumerState<FeePaymentScreen> createState() => _State();
}

class _State extends ConsumerState<FeePaymentScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final feeAsync = ref.watch(feesProvider);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('My Fees'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
      body: feeAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [ShimmerBox(height: 120), SizedBox(height: 12), ShimmerBox(height: 200)])),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(feesProvider)),
        data: (data) {
          final dues = (data['dues'] as List?) ?? [];
          final paid = (data['paid'] as List?) ?? [];
          final totalDue = (data['totalDue'] ?? 0) as num;
          final totalPaid = (data['totalPaid'] ?? 0) as num;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Outstanding Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(fmt.format(totalDue), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 36)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _balanceItem('Total Paid', fmt.format(totalPaid), AppTheme.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _balanceItem('Total Due', fmt.format(totalDue), AppTheme.error)),
                  ]),
                  if (totalDue > 0) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : () => _initiatePayment(context, totalDue.toDouble(), fmt),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: _processing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payment_rounded),
                        label: Text(_processing ? 'Processing...' : 'Pay Now  ${fmt.format(totalDue)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 24),

              // Pending dues
              if (dues.isNotEmpty) ...[
                const SectionHeader(title: 'Pending Dues'),
                ...dues.map((d) => _FeeItem(item: d as Map<String, dynamic>, fmt: fmt, ref: ref, isPending: true, onPay: (amt) => _initiatePayment(context, amt, fmt))),
              ],

              // Payment history
              if (paid.isNotEmpty) ...[
                const SectionHeader(title: 'Payment History'),
                ...paid.map((p) => _FeeItem(item: p as Map<String, dynamic>, fmt: fmt, ref: ref, isPending: false, onPay: (_) {})),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _balanceItem(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
    ]),
  );

  Future<void> _initiatePayment(BuildContext context, double amount, NumberFormat fmt) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentSheet(amount: amount, fmt: fmt),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      // Create payment order
      final order = await ref.read(schoolRepoProvider).createPaymentOrder({'amount': amount, 'currency': 'INR'});
      final orderId = order['orderId'] ?? order['id'];

      // In production: launch Razorpay SDK here with orderId
      // For now, verify payment directly (demo mode)
      await Future.delayed(const Duration(seconds: 2));
      await ref.read(schoolRepoProvider).verifyPayment({'orderId': orderId, 'status': 'success'});

      ref.invalidate(feesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment of ${fmt.format(amount)} successful!'),
        backgroundColor: AppTheme.success,
        action: SnackBarAction(label: 'Download Receipt', textColor: Colors.white, onPressed: () {}),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _PaymentSheet extends StatefulWidget {
  final double amount;
  final NumberFormat fmt;
  const _PaymentSheet({required this.amount, required this.fmt});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _method = 'upi';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Pay ${widget.fmt.format(widget.amount)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Select payment method', style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 20),
      _MethodTile(icon: Icons.smartphone_rounded, label: 'UPI / GPay / PhonePe', selected: _method == 'upi', onTap: () => setState(() => _method = 'upi')),
      const SizedBox(height: 8),
      _MethodTile(icon: Icons.credit_card_rounded, label: 'Debit / Credit Card', selected: _method == 'card', onTap: () => setState(() => _method = 'card')),
      const SizedBox(height: 8),
      _MethodTile(icon: Icons.account_balance_rounded, label: 'Net Banking', selected: _method == 'netbanking', onTap: () => setState(() => _method = 'netbanking')),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text('Continue with ${_method.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.lock_rounded, size: 14, color: AppTheme.textSecondary),
        SizedBox(width: 4),
        Text('Secured by Razorpay', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    ]),
  );
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withOpacity(0.08) : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider, width: selected ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary, size: 22),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppTheme.primary : AppTheme.textPrimary)),
        const Spacer(),
        if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
      ]),
    ),
  );
}

class _FeeItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat fmt;
  final WidgetRef ref;
  final bool isPending;
  final void Function(double) onPay;
  const _FeeItem({required this.item, required this.fmt, required this.ref, required this.isPending, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final name = item['feeName'] ?? item['feeType'] ?? item['description'] ?? 'Fee';
    final amount = (item['amount'] ?? item['pendingAmount'] ?? 0) as num;
    final dueDate = item['dueDate'] ?? '';
    final isOverdue = item['isOverdue'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOverdue ? AppTheme.error.withOpacity(0.04) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOverdue ? AppTheme.error.withOpacity(0.3) : AppTheme.divider),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: (isPending ? AppTheme.warning : AppTheme.success).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(isPending ? Icons.receipt_long_rounded : Icons.check_circle_rounded, color: isPending ? AppTheme.warning : AppTheme.success, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (dueDate.isNotEmpty) Text('Due: $dueDate${isOverdue ? " ⚠ Overdue" : ""}', style: TextStyle(color: isOverdue ? AppTheme.error : AppTheme.textSecondary, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(amount), style: TextStyle(fontWeight: FontWeight.w700, color: isPending ? (isOverdue ? AppTheme.error : AppTheme.warning) : AppTheme.success)),
            if (isPending) GestureDetector(onTap: () => onPay(amount.toDouble()), child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
              child: const Text('Pay', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    );
  }
}
