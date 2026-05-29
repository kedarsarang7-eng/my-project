import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/qr_payment_repository.dart';
import '../../providers/qr_payment_provider.dart';
import '../../theme/fuelpos_theme.dart';

/// QR Display Screen
/// 
/// Shows the generated QR code with:
/// - Countdown timer (QR expiry)
/// - Wakelock (screen stays on)
/// - WebSocket listener for payment
/// - Polling fallback
/// - Payment success/failure navigation
class QRDisplayScreen extends ConsumerStatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  ConsumerState<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends ConsumerState<QRDisplayScreen> {
  bool _paymentReceived = false;
  bool _showCancelConfirm = false;

  @override
  void initState() {
    super.initState();
    // Keep screen on while QR is displayed
    WakelockPlus.enable();
    
    // Listen for payment status changes
    _listenForPayment();
  }

  void _listenForPayment() {
    // Use a provider listener to detect payment completion
    ref.listenManual(qrPaymentProvider, (previous, next) {
      if (_paymentReceived) return;

      if (next.isPaid) {
        _paymentReceived = true;
        _onPaymentSuccess();
      } else if (next.isFailed) {
        _paymentReceived = true;
        _onPaymentFailed();
      }
    });
  }

  void _onPaymentSuccess() {
    // Disable wakelock
    WakelockPlus.disable();
    
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Navigate to success screen
    final qrResponse = ref.read(qrPaymentProvider).qrResponse;
    final paymentStatus = ref.read(qrPaymentProvider).paymentStatus;
    
    context.go('/payment/success', extra: {
      'amount': qrResponse?.amountRupees ?? 0,
      'transactionId': paymentStatus?.transactionId ?? qrResponse?.transactionId ?? '',
      'orderId': qrResponse?.orderId ?? '',
    });
  }

  void _onPaymentFailed() {
    // Disable wakelock
    WakelockPlus.disable();
    
    // Haptic feedback
    HapticFeedback.vibrate();
    
    // Navigate to failed screen
    context.go('/payment/failed');
  }

  void _onCancelPressed() {
    setState(() => _showCancelConfirm = true);
  }

  void _cancelPayment() async {
    await ref.read(qrPaymentProvider.notifier).cancelPayment();
    if (mounted) {
      context.go('/dashboard/petrol-pump');
    }
  }

  void _keepWaiting() {
    setState(() => _showCancelConfirm = false);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Ensure wakelock is disabled when leaving
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrState = ref.watch(qrPaymentProvider);
    final qrResponse = qrState.qrResponse;
    final remainingSeconds = qrState.remainingSeconds ?? 0;

    // If no QR, go back to entry
    if (qrResponse == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/qr/entry');
      });
      return const Scaffold(
        backgroundColor: FuelPOSTheme.backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isLowTime = remainingSeconds < 60;
    final isVeryLowTime = remainingSeconds < 30;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onCancelPressed();
      },
      child: Scaffold(
        backgroundColor: FuelPOSTheme.backgroundDark,
        body: Stack(
          children: [
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 32),

                      // Countdown timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isVeryLowTime
                              ? FuelPOSTheme.errorRed.withValues(alpha: 0.15)
                              : isLowTime
                                  ? FuelPOSTheme.warningYellow.withValues(alpha: 0.15)
                                  : FuelPOSTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isVeryLowTime
                                ? FuelPOSTheme.errorRed
                                : isLowTime
                                    ? FuelPOSTheme.warningYellow
                                    : FuelPOSTheme.successGreen,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              color: isVeryLowTime
                                  ? FuelPOSTheme.errorRed
                                  : isLowTime
                                      ? FuelPOSTheme.warningYellow
                                      : FuelPOSTheme.successGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Expires in ${_formatTime(remainingSeconds)}',
                              style: TextStyle(
                                color: isVeryLowTime
                                    ? FuelPOSTheme.errorRed
                                    : isLowTime
                                        ? FuelPOSTheme.warningYellow
                                        : FuelPOSTheme.successGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // QR Code card
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Amount display
                              Text(
                                NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 2,
                                ).format(qrResponse.amountRupees),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Scan to Pay',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: _buildQRCode(qrResponse),
                              ),
                              const SizedBox(height: 16),

                              // Transaction ID
                              Text(
                                'Order ID: ${qrResponse.orderId.substring(0, qrResponse.orderId.length > 12 ? 12 : qrResponse.orderId.length)}...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FuelPOSTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildInstructionRow(
                              Icons.phone_android,
                              'Open any UPI app on your phone',
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionRow(
                              Icons.qr_code_scanner,
                              'Scan this QR code',
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionRow(
                              Icons.check_circle,
                              'Complete the payment',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Waiting indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FuelPOSTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Waiting for payment...',
                            style: TextStyle(
                              color: FuelPOSTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Cancel button
                      OutlinedButton.icon(
                        onPressed: _onCancelPressed,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Payment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FuelPOSTheme.textSecondary,
                          side: BorderSide(color: FuelPOSTheme.borderDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Cancel confirmation dialog
            if (_showCancelConfirm)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    color: FuelPOSTheme.cardDark,
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: FuelPOSTheme.warningYellow,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Cancel Payment?',
                            style: TextStyle(
                              color: FuelPOSTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This will cancel the current payment. The customer will not be able to complete this transaction.',
                            style: TextStyle(
                              color: FuelPOSTheme.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _keepWaiting,
                                  child: const Text('Keep Waiting'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FuelPOSTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelPayment,
                                  child: const Text('Cancel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FuelPOSTheme.errorRed,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FuelPOSTheme.petrolBlue, FuelPOSTheme.dieselOrange],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.local_gas_station,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'FuelPOS Payment',
          style: TextStyle(
            color: FuelPOSTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQRCode(QRPaymentResponse qrResponse) {
    // If backend provides a QR image URL, use it
    if (qrResponse.qrImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: qrResponse.qrImageUrl,
        width: 240,
        height: 240,
        placeholder: (context, url) => const SizedBox(
          width: 240,
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          // Fallback to generated QR if image fails
          return QrImageView(
            data: qrResponse.orderId,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
          );
        },
      );
    } else {
      // Generate QR code locally
      return QrImageView(
        data: qrResponse.orderId,
        version: QrVersions.auto,
        size: 240,
        backgroundColor: Colors.white,
      );
    }
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: FuelPOSTheme.textMuted,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: FuelPOSTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
