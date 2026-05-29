// ============================================================================
// Exit QR Screen — Shows HMAC-signed QR for store exit verification
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/in_store_providers.dart';

class ExitQRScreen extends ConsumerStatefulWidget {
  const ExitQRScreen({super.key});

  @override
  ConsumerState<ExitQRScreen> createState() => _ExitQRScreenState();
}

class _ExitQRScreenState extends ConsumerState<ExitQRScreen> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final qr = ref.read(exitQRProvider);
      if (qr == null) return;
      final rem = qr.timeRemaining;
      if (mounted) {
        setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
      }
      if (rem.isNegative) {
        _countdownTimer?.cancel();
      }
    });

    final qr = ref.read(exitQRProvider);
    if (qr != null) {
      final rem = qr.timeRemaining;
      setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final qr = ref.watch(exitQRProvider);
    final session = ref.watch(activeSessionProvider).valueOrNull;

    if (qr == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exit QR')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating your exit QR...'),
            ],
          ),
        ),
      );
    }

    final isExpired = qr.isExpired;
    final isLow = _remaining.inSeconds < 60 && !isExpired;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Show this QR to exit'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Success header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Successful!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          Text(
                            'Order ${qr.orderId}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // QR code
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired
                        ? Colors.red.shade300
                        : isLow
                            ? Colors.orange.shade300
                            : const Color(0xFF4CAF50),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: (isExpired
                                ? Colors.red
                                : const Color(0xFF4CAF50))
                            .withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ],
                ),
                child: isExpired
                    ? Column(
                        children: [
                          const Icon(Icons.qr_code_2,
                              size: 140, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('QR Expired',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      )
                    : QrImageView(
                        data: qr.rawJson,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
              ),

              const SizedBox(height: 16),

              // Countdown
              if (!isExpired)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: isLow ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Valid for ${_formatDuration(_remaining)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLow ? Colors.orange : Colors.grey.shade700,
                      ),
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(exitQRProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Get New QR'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),

              const SizedBox(height: 24),

              // Order summary card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow('Items',
                          '${qr.totalItems} item${qr.totalItems == 1 ? '' : 's'}'),
                      _SummaryRow('Total Paid',
                          '₹${qr.totalAmount.toStringAsFixed(2)}',
                          isBold: true),
                      _SummaryRow('Store',
                          session?.storeName ?? qr.storeId),
                      _SummaryRow('Paid at',
                          _formatDateTime(qr.paidAt)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Show this QR to the staff member at the exit. '
                        'They will scan it on their device to verify your purchase.',
                        style:
                            TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.day}/${dt.month}/${dt.year}';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
