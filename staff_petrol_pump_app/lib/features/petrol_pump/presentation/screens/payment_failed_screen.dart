import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/qr_payment_provider.dart';
import '../../theme/fuelpos_theme.dart';

/// Payment Failed Screen
/// 
/// Shows when payment fails or is cancelled with:
/// - Error indication
/// - Reason for failure
/// - Retry option
/// - Back to dashboard option
class PaymentFailedScreen extends ConsumerWidget {
  final String? errorMessage;

  const PaymentFailedScreen({
    super.key,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Haptic feedback
    HapticFeedback.vibrate();

    final qrState = ref.watch(qrPaymentProvider);
    final failureReason = errorMessage ?? _getFailureReason(qrState);

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
                // Error icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: FuelPOSTheme.errorRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: FuelPOSTheme.errorRed,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 32),

                // Error text
                Text(
                  'Payment Failed',
                  style: TextStyle(
                    color: FuelPOSTheme.errorRed,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  failureReason,
                  style: TextStyle(
                    color: FuelPOSTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Failure details card
                Card(
                  color: FuelPOSTheme.cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: FuelPOSTheme.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: FuelPOSTheme.warningYellow,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'What happened?',
                          style: TextStyle(
                            color: FuelPOSTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getDetailedExplanation(qrState),
                          style: TextStyle(
                            color: FuelPOSTheme.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
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
                        onPressed: () => _onBackToDashboard(context, ref),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: const Text('Dashboard'),
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
                        onPressed: () => _onRetry(context, ref),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FuelPOSTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // New payment button
                TextButton.icon(
                  onPressed: () => _onNewPayment(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New Payment'),
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

  String _getFailureReason(QRPaymentState state) {
    if (state.error != null) {
      return state.error!;
    }
    if (state.qrResponse?.isExpired ?? false) {
      return 'QR code expired. The payment window has closed.';
    }
    return 'The payment could not be completed.';
  }

  String _getDetailedExplanation(QRPaymentState state) {
    if (state.error != null) {
      return 'An error occurred while processing your request. Please try again.';
    }
    if (state.qrResponse?.isExpired ?? false) {
      return 'The QR code was valid for 10 minutes and has now expired. You can generate a new QR code for the customer to complete the payment.';
    }
    if (state.paymentStatus?.isFailed ?? false) {
      return 'The customer attempted to pay but the transaction was declined. This could be due to insufficient funds, network issues, or the customer cancelling the payment.';
    }
    return 'We couldn\'t complete the payment. This might be due to network issues, the customer cancelling, or the payment being declined.';
  }

  void _onRetry(BuildContext context, WidgetRef ref) {
    // Keep the same amount but generate new QR
    final previousAmount = ref.read(qrPaymentProvider).qrResponse?.amountRupees;
    
    // Reset state
    ref.read(qrPaymentProvider.notifier).reset();
    
    // Navigate back to amount entry with previous amount
    if (previousAmount != null) {
      // TODO: Pass amount back to pre-fill
      context.go('/qr/entry');
    } else {
      context.go('/qr/entry');
    }
  }

  void _onNewPayment(BuildContext context, WidgetRef ref) {
    // Reset state completely
    ref.read(qrPaymentProvider.notifier).reset();
    context.go('/qr/entry');
  }

  void _onBackToDashboard(BuildContext context, WidgetRef ref) {
    // Reset state
    ref.read(qrPaymentProvider.notifier).reset();
    context.go('/dashboard/petrol-pump');
  }
}
