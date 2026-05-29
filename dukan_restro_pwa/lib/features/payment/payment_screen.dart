import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pwa_providers.dart';
import '../../services/pwa_api_service.dart';
import '../../services/pwa_payment_service.dart';
import '../../utils/pwa_haptics.dart';
import '../../widgets/pwa_offline_banner.dart';

enum _PaymentMethod { upi, card, cash, wallet }

class PaymentScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String tableId;
  final String customerName;
  final String phone;

  const PaymentScreen({
    super.key,
    required this.vendorId,
    required this.tableId,
    required this.customerName,
    required this.phone,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  static const _orange = Color(0xFFEA580C);
  _PaymentMethod _method = _PaymentMethod.upi;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _placedOrderId;

  @override
  void initState() {
    super.initState();
    PwaPaymentService().init();
  }

  @override
  void dispose() {
    PwaPaymentService().dispose();
    super.dispose();
  }

  Future<void> _payAndPlaceOrder() async {
    final cart = ref.read(pwaCartProvider);
    if (cart.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Step 1: Place order first
    final orderId = await PwaApiService.placeOrder(
      vendorId: widget.vendorId,
      tableId: widget.tableId,
      items: cart
          .map(
            (i) => {
              'menuItemId': i.menuItemId,
              'qty': i.qty,
              if (i.note != null && i.note!.isNotEmpty) 'note': i.note,
            },
          )
          .toList(),
      customerName: widget.customerName.isEmpty ? null : widget.customerName,
      phone: widget.phone.isEmpty ? null : widget.phone,
    );

    if (!mounted) return;

    if (orderId == null || orderId.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Order placement failed. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order failed. Please retry.')),
      );
      return;
    }

    _placedOrderId = orderId;

    // Step 2: Handle payment based on method
    if (_method == _PaymentMethod.cash) {
      // Cash payment - just track order without payment
      ref.read(activeOrderIdProvider.notifier).state = orderId;
      ref.read(pwaCartProvider.notifier).clear();
      await PwaHaptics.success();
      if (!mounted) return;

      context.go(
        '/track',
        extra: {
          'vendorId': widget.vendorId,
          'orderId': orderId,
          'tableId': widget.tableId,
        },
      );
    } else {
      // Online payment via Razorpay
      await _initiateRazorpayPayment(orderId);
    }
  }

  Future<void> _initiateRazorpayPayment(String orderId) async {
    final cart = ref.read(pwaCartProvider);
    final subtotal = cart.fold<double>(0, (sum, i) => sum + (i.price * i.qty));
    final gst = subtotal * 0.05;
    final grandTotal = subtotal + gst;

    // Fetch vendor info for business name
    final vendorInfo = await PwaApiService.fetchVendorInfo(widget.vendorId);
    final businessName = vendorInfo['businessName'] ?? 'Restaurant';

    await PwaPaymentService().initiatePayment(
      vendorId: widget.vendorId,
      tableId: widget.tableId,
      orderId: orderId,
      amount: grandTotal,
      businessName: businessName,
      customerName: widget.customerName.isEmpty ? null : widget.customerName,
      customerPhone: widget.phone.isEmpty ? null : widget.phone,
      onResult: (success, message, paymentId) async {
        if (!mounted) return;

        if (success) {
          // Payment successful
          ref.read(activeOrderIdProvider.notifier).state = orderId;
          ref.read(pwaCartProvider.notifier).clear();
          await PwaHaptics.success();

          if (!mounted) return;
          context.go(
            '/track',
            extra: {
              'vendorId': widget.vendorId,
              'orderId': orderId,
              'tableId': widget.tableId,
              'paymentId': paymentId,
            },
          );
        } else {
          // Payment failed - show retry option
          setState(() {
            _isSubmitting = false;
            _errorMessage = message;
          });
          await PwaHaptics.error();

          if (!mounted) return;
          _showPaymentFailedDialog(message, orderId, grandTotal, businessName);
        }
      },
    );
  }

  void _showPaymentFailedDialog(String message, String orderId, double amount, String businessName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Payment Failed', style: TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Retry payment
              _retryPayment(orderId, amount, businessName);
            },
            child: const Text('Retry', style: TextStyle(color: Color(0xFFEA580C))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Go back to cart
              setState(() => _isSubmitting = false);
            },
            child: const Text('Change Method', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPayment(String orderId, double amount, String businessName) async {
    setState(() => _isSubmitting = true);

    await PwaPaymentService().retryPayment(
      vendorId: widget.vendorId,
      tableId: widget.tableId,
      orderId: orderId,
      amount: amount,
      businessName: businessName,
      customerName: widget.customerName.isEmpty ? null : widget.customerName,
      customerPhone: widget.phone.isEmpty ? null : widget.phone,
      onResult: (success, message, paymentId) async {
        if (!mounted) return;

        if (success) {
          ref.read(activeOrderIdProvider.notifier).state = orderId;
          ref.read(pwaCartProvider.notifier).clear();
          await PwaHaptics.success();

          if (!mounted) return;
          context.go(
            '/track',
            extra: {
              'vendorId': widget.vendorId,
              'orderId': orderId,
              'tableId': widget.tableId,
              'paymentId': paymentId,
            },
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = message;
          });
          await PwaHaptics.error();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(pwaCartProvider);
    final subtotal = cart.fold<double>(0, (sum, i) => sum + (i.price * i.qty));
    final gst = subtotal * 0.05;
    final grand = subtotal + gst;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const PwaOfflineBanner(),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            _methodTile(
              title: 'UPI / QR',
              subtitle: 'Google Pay, PhonePe, Paytm',
              icon: Icons.qr_code_2,
              method: _PaymentMethod.upi,
            ),
            _methodTile(
              title: 'Card',
              subtitle: 'Credit or debit card',
              icon: Icons.credit_card,
              method: _PaymentMethod.card,
            ),
            _methodTile(
              title: 'Cash',
              subtitle: 'Pay at counter',
              icon: Icons.payments_outlined,
              method: _PaymentMethod.cash,
            ),
            _methodTile(
              title: 'Wallet',
              subtitle: 'Digital wallet',
              icon: Icons.account_balance_wallet_outlined,
              method: _PaymentMethod.wallet,
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E2E2E)),
              ),
              child: Column(
                children: [
                  _row('Subtotal', subtotal),
                  const SizedBox(height: 6),
                  _row('GST (5%)', gst),
                  const Divider(color: Color(0xFF2E2E2E), height: 18),
                  _row('Grand Total', grand, highlight: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_method != _PaymentMethod.cash)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Secure payment powered by Razorpay',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _payAndPlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _method == _PaymentMethod.cash
                          ? 'Place Order (Pay at Counter)'
                          : 'Pay ₹${grand.toStringAsFixed(0)} & Place Order',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required _PaymentMethod method,
  }) {
    final selected = _method == method;
    return GestureDetector(
      onTap: () async {
        await PwaHaptics.tap();
        if (mounted) setState(() => _method = method);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _orange.withOpacity(0.12) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _orange : const Color(0xFF2E2E2E),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _orange : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: _orange),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double amount, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? Colors.white : Colors.grey,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: highlight ? _orange : Colors.grey[300],
            fontWeight: FontWeight.w700,
            fontSize: highlight ? 18 : 13,
          ),
        ),
      ],
    );
  }
}
