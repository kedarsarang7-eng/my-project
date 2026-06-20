import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../providers/qr_payment_provider.dart';
import '../../theme/fuelpos_theme.dart';

/// Payment Success Screen
///
/// Shows after successful payment with:
/// - Haptic feedback
/// - Success animation
/// - Transaction details
/// - Print receipt option
/// - New payment button
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? paymentData;

  const PaymentSuccessScreen({
    super.key,
    this.paymentData,
  });

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onNewPayment() {
    // Reset QR payment state
    ref.read(qrPaymentProvider.notifier).reset();
    context.go('/qr/entry');
  }

  void _onBackToDashboard() {
    // Reset QR payment state
    ref.read(qrPaymentProvider.notifier).reset();
    context.go('/dashboard/petrol-pump');
  }

  void _onPrintReceipt() async {
    try {
      final amount = widget.paymentData?['amount'] ?? 0.0;
      final transactionId = widget.paymentData?['transactionId'] ?? '';
      final orderId = widget.paymentData?['orderId'] ?? '';
      final now = DateTime.now();
      final formattedDate = DateFormat('dd MMM yyyy').format(now);
      final formattedTime = DateFormat('hh:mm a').format(now);
      final formattedAmount = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      ).format(amount);

      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'FuelPOS Station',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Payment Receipt',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(formattedDate,
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Time:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(formattedTime,
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Transaction ID:',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      transactionId.length > 20
                          ? '${transactionId.substring(0, 20)}...'
                          : transactionId,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Order ID:',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      orderId.length > 20
                          ? '${orderId.substring(0, 20)}...'
                          : orderId,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Method:',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('UPI Payment',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Amount Paid:',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      formattedAmount,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Thank you for your purchase!',
                  style: pw.TextStyle(
                      fontSize: 10, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Have a safe journey',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'Receipt_$transactionId',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print receipt: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.paymentData?['amount'] ?? 0.0;
    final transactionId = widget.paymentData?['transactionId'] ?? '';
    final orderId = widget.paymentData?['orderId'] ?? '';

    final formattedAmount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(amount);

    return Scaffold(
      backgroundColor: FuelPOSTheme.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: FuelPOSTheme.successGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: FuelPOSTheme.successGreen,
                      size: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Success text
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    color: FuelPOSTheme.successGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transaction completed successfully',
                  style: TextStyle(
                    color: FuelPOSTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),

                // Amount card
                Card(
                  color: FuelPOSTheme.cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: FuelPOSTheme.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          'Amount Received',
                          style: TextStyle(
                            color: FuelPOSTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedAmount,
                          style: const TextStyle(
                            color: FuelPOSTheme.textPrimary,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: FuelPOSTheme.borderDark),
                        const SizedBox(height: 24),

                        // Transaction details
                        _buildDetailRow(
                            'Transaction ID', _formatId(transactionId)),
                        const SizedBox(height: 12),
                        _buildDetailRow('Order ID', _formatId(orderId)),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Date & Time',
                          DateFormat('dd MMM yyyy, hh:mm a')
                              .format(DateTime.now()),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Payment Method', 'UPI'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Status', 'SUCCESS', isSuccess: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _onPrintReceipt,
                        icon: const Icon(Icons.print),
                        label: const Text('Print Receipt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FuelPOSTheme.textPrimary,
                          side: BorderSide(color: FuelPOSTheme.borderDark),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onNewPayment,
                        icon: const Icon(Icons.add),
                        label: const Text('New Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FuelPOSTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Back to dashboard
                TextButton.icon(
                  onPressed: _onBackToDashboard,
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Back to Dashboard'),
                  style: TextButton.styleFrom(
                    foregroundColor: FuelPOSTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSuccess = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: FuelPOSTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isSuccess
                ? FuelPOSTheme.successGreen
                : FuelPOSTheme.textPrimary,
            fontSize: 13,
            fontWeight: isSuccess ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _formatId(String id) {
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }
}
