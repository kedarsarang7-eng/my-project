import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../features/payment/services/upi_payment_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/modern_ui_components.dart';

class PaymentQrDialog extends StatefulWidget {
  final String billId;
  final double amount;
  final String customerName;

  const PaymentQrDialog({
    super.key,
    required this.billId,
    required this.amount,
    required this.customerName,
  });

  @override
  State<PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<PaymentQrDialog> {
  final _upiService = sl<UpiPaymentService>();
  final _session = sl<SessionManager>();

  String? _qrPayload;
  String? _error;
  bool _isLoading = true;
  bool _isSuccess = false;

  // Expiry Timer (Layer 5)
  Timer? _timer;
  int _secondsRemaining = 300; // 5 minutes
  bool _isExpired = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _generateQr();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        if (mounted) {
          setState(() {
            _isExpired = true;
            _timer?.cancel();
          });
        }
      }
    });
  }

  Future<void> _generateQr() async {
    try {
      final vendorId = _session.ownerId;
      if (vendorId == null) throw Exception('Vendor not identified');

      final payload = await _upiService.generateDynamicQrPayload(
        billId: widget.billId,
        vendorId: vendorId,
        amount: widget.amount,
        note: 'Bill #${widget.billId.substring(0, 5)}',
      );

      if (mounted) {
        setState(() {
          _qrPayload = payload;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPayment() async {
    // Simulate verification delay
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    // In production, this would poll the server
    await _upiService.verifyTransaction(
      billId: widget.billId,
      paidAmount: widget.amount, // Expect exact match
      payerUpi: 'manual_verified', // Manual confirmation by vendor
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      // Close dialog after short delay
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context, true); // Return success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        borderRadius: 24.0,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSuccess) ...[
              Icon(
                Icons.check_circle,
                color: FuturisticColors.success,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Verified!',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Redirecting...',
                style: TextStyle(color: FuturisticColors.textMuted),
              ),
            ] else ...[
              Text(
                'Scan to Pay ₹${widget.amount.toStringAsFixed(2)}',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customer: ${widget.customerName}',
                style: AppTypography.bodyMedium.copyWith(
                  color: FuturisticColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 250,
                width: 250,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white, // QR needs white background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: FuturisticColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FuturisticColors.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: FuturisticColors.primary)
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: FuturisticColors.error,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: FuturisticColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : QrImageView(
                        data: _qrPayload!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: FuturisticColors.primary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black87,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Timer Display
              if (!_isSuccess && !_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_isExpired || _secondsRemaining < 30
                                ? FuturisticColors.error
                                : FuturisticColors.success)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isExpired || _secondsRemaining < 30
                          ? FuturisticColors.error
                          : FuturisticColors.success,
                    ),
                  ),
                  child: Text(
                    _isExpired
                        ? 'QR CODE EXPIRED'
                        : 'Valid for: ${_formatTime(_secondsRemaining)}',
                    style: TextStyle(
                      color: _isExpired || _secondsRemaining < 30
                          ? FuturisticColors.error
                          : FuturisticColors.success,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              if (_error == null && !_isExpired)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: EnterpriseButton(
                          onPressed: () =>
                              Navigator.pop(context, false), // Cancel
                          label: 'Cancel',
                          backgroundColor: Colors.transparent,
                          textColor: FuturisticColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: EnterpriseButton(
                          onPressed: _isLoading ? () {} : _verifyPayment,
                          label: 'Received Payment',
                          backgroundColor: FuturisticColors.success,
                        ),
                      ),
                    ),
                  ],
                ),

              if (_isExpired)
                SizedBox(
                  width: double.infinity,
                  child: EnterpriseButton(
                    onPressed: () {
                      setState(() {
                        _isExpired = false;
                        _secondsRemaining = 300;
                        _isLoading = true;
                      });
                      _startTimer();
                      _generateQr();
                    },
                    label: 'Generate New QR',
                    icon: Icons.refresh,
                    backgroundColor: FuturisticColors.warning,
                  ),
                ),

              if (_error != null)
                EnterpriseButton(
                  onPressed: () => Navigator.pop(context),
                  label: 'Close',
                  backgroundColor: Colors.transparent,
                  textColor: FuturisticColors.textPrimary,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
