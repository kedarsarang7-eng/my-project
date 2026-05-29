// ============================================================================
// Cart Review Screen — Full order summary before payment
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/in_store_models.dart';
import '../../providers/in_store_providers.dart';
import '../../services/in_store_api_service.dart';
import '../../../../../core/navigation/app_router.dart';

class CartReviewScreen extends ConsumerWidget {
  const CartReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartItemsProvider);
    final summary = ref.watch(cartSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Review Order'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Item list
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${cartItems.length} product${cartItems.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...cartItems.map((item) => _ReviewItemRow(item: item,
                  onQtyChanged: (qty) => ref
                      .read(activeSessionProvider.notifier)
                      .updateQuantity(item.productId, qty),
                  onRemove: () => ref
                      .read(activeSessionProvider.notifier)
                      .removeItem(item.productId),
                )),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Price breakdown
          if (summary != null) _PriceBreakdown(summary: summary),

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: summary != null
          ? _ProceedToPaymentBar(
              summary: summary,
              onTap: () => _proceedToPayment(context, ref),
            )
          : null,
    );
  }

  Future<void> _proceedToPayment(BuildContext context, WidgetRef ref) async {
    final checkoutResult =
        await ref.read(checkoutProvider.notifier).checkout();

    if (!context.mounted) return;

    if (checkoutResult != null) {
      context.push(AppRoutes.inStorePayment,
          extra: checkoutResult);
    } else {
      final err = ref.read(checkoutProvider).error;
      String msg = 'Checkout failed. Please try again.';
      if (err is InStoreApiException) msg = err.message;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }
}

class _ReviewItemRow extends StatelessWidget {
  final CartItem item;
  final void Function(int) onQtyChanged;
  final VoidCallback onRemove;

  const _ReviewItemRow({
    required this.item,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (item.brand != null)
                  Text(item.brand!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Row(
                  children: [
                    Text('₹${(item.sellingPrice / 100).toStringAsFixed(2)} × ',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    // mini stepper
                    _MiniStepper(
                      qty: item.quantity,
                      onChanged: onQtyChanged,
                      onRemove: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '₹${(item.sellingPrice * item.quantity / 100).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  final int qty;
  final void Function(int) onChanged;
  final VoidCallback onRemove;

  const _MiniStepper(
      {required this.qty, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => qty == 1 ? onRemove() : onChanged(qty - 1),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              qty == 1 ? Icons.delete_outline : Icons.remove,
              size: 14,
              color: qty == 1 ? Colors.red : Colors.grey.shade700,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () => onChanged(qty + 1),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  final CartSummary summary;
  const _PriceBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price Breakdown',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _Row('Subtotal (${summary.itemCount} items)',
                summary.subtotalDisplay),
            if (summary.discountCents > 0)
              _Row('Discount', '-${summary.discountDisplay}',
                  valueColor: Colors.green),
            ...summary.gstBreakup.map((g) => _Row(
                  'GST ${g.slab}% (CGST + SGST)',
                  '₹${(g.total / 100).toStringAsFixed(2)}',
                  isSmall: true,
                )),
            const Divider(height: 20),
            _Row('Total Payable', summary.totalDisplay,
                isBold: true, valueColor: const Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isSmall;
  final Color? valueColor;

  const _Row(this.label, this.value,
      {this.isBold = false, this.isSmall = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isSmall ? 13 : 15,
      color: isSmall ? Colors.grey : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value,
              style: style.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

class _ProceedToPaymentBar extends StatelessWidget {
  final CartSummary summary;
  final VoidCallback onTap;

  const _ProceedToPaymentBar(
      {required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          'Proceed to Payment · ${summary.totalDisplay}',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
