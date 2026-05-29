// ============================================================================
// In-Store Payment Screen — Razorpay SDK integration
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../models/in_store_models.dart';
import '../../providers/in_store_providers.dart';
import '../../../../../core/navigation/app_router.dart';
import '../../../../../core/websocket/customer_ws_service.dart';

class InStorePaymentScreen extends ConsumerStatefulWidget {
  final CheckoutResponse checkoutResponse;

  const InStorePaymentScreen({super.key, required this.checkoutResponse});

  @override
  ConsumerState<InStorePaymentScreen> createState() =>
      _InStorePaymentScreenState();
}

class _InStorePaymentScreenState
    extends ConsumerState<InStorePaymentScreen> {
  bool _paymentLaunched = false;
  bool _waiting = false;
  String? _failureMsg;
  Razorpay? _razorpay;

  @override
  void initState() {
    super.initState();
    _listenForPaymentResult();
    // Auto-launch payment after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchPayment());
  }

  void _listenForPaymentResult() {
    // Listen on WebSocket for IN_STORE_PAYMENT_SUCCESS / PAYMENT_FAILED
    final ws = ref.read(customerWsServiceProvider);
    ws.subscribe('in_store_payment_success', _onPaymentSuccess);
    ws.subscribe('payment_success', _onPaymentSuccess);
    ws.subscribe('payment_failed', _onPaymentFailed);
    ws.subscribe('in_store_exit_qr_ready', _onPaymentSuccess);
  }

  void _onPaymentSuccess(Map<String, dynamic> payload) {
    if (!mounted) return;
    final orderId = payload['orderId'] as String?;
    if (orderId != widget.checkoutResponse.orderId) return;

    final exitQRJson = payload['exitQR'] as String?;
    if (exitQRJson != null) {
      ref.read(exitQRProvider.notifier).setFromWsPayload(exitQRJson);
    }

    context.go(AppRoutes.inStoreExitQR);
  }

  void _onPaymentFailed(Map<String, dynamic> payload) {
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _failureMsg =
          payload['reason'] as String? ?? 'Payment failed. Please try again.';
    });
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) {
    // Razorpay SDK confirms client-side — server confirms via webhook → WS
    // Keep _waiting = true so the WS listener drives navigation to exit QR
    // This prevents double navigation if WS arrives before SDK callback
    if (!mounted) return;
    setState(() => _waiting = true);
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _paymentLaunched = false;
      _failureMsg = response.message ?? 'Payment failed. Please try again.';
    });
    _razorpay?.clear();
    _razorpay = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet selected — payment pending
    if (!mounted) return;
    setState(() => _waiting = true);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    final ws = ref.read(customerWsServiceProvider);
    ws.unsubscribe('in_store_payment_success', _onPaymentSuccess);
    ws.unsubscribe('payment_success', _onPaymentSuccess);
    ws.unsubscribe('payment_failed', _onPaymentFailed);
    ws.unsubscribe('in_store_exit_qr_ready', _onPaymentSuccess);
    super.dispose();
  }

  Future<void> _launchPayment() async {
    if (_paymentLaunched) return;
    setState(() {
      _paymentLaunched = true;
      _waiting = true;
      _failureMsg = null;
    });

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _razorpay!.open({
      'key': widget.checkoutResponse.gatewayKey,
      'order_id': widget.checkoutResponse.paymentOrderId,
      'amount': (widget.checkoutResponse.amount * 100).round(),
      'currency': widget.checkoutResponse.currency,
      'name': 'DukanX',
      'description': 'In-Store Purchase',
      'theme': {'color': '#2E7D32'},
      'prefill': {'contact': '', 'email': ''},
    });

    // Payment confirmation arrives via webhook → backend → WS push → _onPaymentSuccess
    setState(() => _waiting = true);
  }

  @override
  Widget build(BuildContext context) {
    final cr = widget.checkoutResponse;

    return PopScope(
      canPop: false, // Prevent back during active payment
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFF8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Amount display
                Center(
                  child: Column(
                    children: [
                      const Text('Total Payable',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        '₹${cr.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order ${cr.orderId}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                if (_waiting && _failureMsg == null) ...[
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                            color: Color(0xFF2E7D32)),
                        SizedBox(height: 20),
                        Text(
                          'Waiting for payment confirmation...',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Complete payment in the Razorpay window.\nDo not close this screen.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                if (_failureMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        const Text('Payment Failed',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(height: 6),
                        Text(_failureMsg!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentLaunched = false;
                        _failureMsg = null;
                      });
                      _launchPayment();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Payment'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('Back to Cart'),
                  ),
                ],

                const Spacer(),

                // Security note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by Razorpay · Your cart is saved',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
