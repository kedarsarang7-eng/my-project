// ============================================================================
// Exit Verification Screen (DukanX Operator Panel — Staff Side)
// ============================================================================
// Staff scans customer exit QR → calls POST /in-store/verify-exit
// Shows VERIFIED / INVALID result in under 5 seconds.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:dukanx/core/responsive/responsive.dart';

// ── Verification result model ─────────────────────────────────────────────────

class VerifyResult {
  final bool valid;
  final String? reason;
  final String? customerName;
  final int? totalItems;
  final double? totalAmount;
  final String? paidAt;
  final String? orderId;
  final int? minutesAgo;

  const VerifyResult({
    required this.valid,
    this.reason,
    this.customerName,
    this.totalItems,
    this.totalAmount,
    this.paidAt,
    this.orderId,
    this.minutesAgo,
  });

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return VerifyResult(
      valid: json['valid'] as bool,
      reason: json['reason'] as String?,
      customerName: order?['customerName'] as String?,
      totalItems: (order?['totalItems'] as num?)?.toInt(),
      totalAmount: (order?['totalAmount'] as num?)?.toDouble(),
      paidAt: order?['paidAt'] as String?,
      orderId: order?['orderId'] as String?,
      minutesAgo: (order?['minutesAgo'] as num?)?.toInt(),
    );
  }
}

// ── Provider for API call ─────────────────────────────────────────────────────

final _verifyResultProvider =
    StateNotifierProvider<VerifyNotifier, AsyncValue<VerifyResult?>>(
      (ref) => VerifyNotifier(),
    );

class VerifyNotifier extends StateNotifier<AsyncValue<VerifyResult?>> {
  VerifyNotifier() : super(const AsyncValue.data(null));

  Future<void> verify(String qrPayload, String baseUrl, String token) async {
    state = const AsyncValue.loading();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/v1/in-store/verify-exit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'qrPayload': qrPayload}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      state = AsyncValue.data(VerifyResult.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ExitVerificationScreen extends ConsumerStatefulWidget {
  final String apiBaseUrl;
  final String accessToken;

  const ExitVerificationScreen({
    super.key,
    required this.apiBaseUrl,
    required this.accessToken,
  });

  @override
  ConsumerState<ExitVerificationScreen> createState() =>
      _ExitVerificationScreenState();
}

class _ExitVerificationScreenState
    extends ConsumerState<ExitVerificationScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _scanning = true;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (!_scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _scanning = false);
    await _scanner.stop();

    await ref
        .read(_verifyResultProvider.notifier)
        .verify(raw, widget.apiBaseUrl, widget.accessToken);
  }

  void _reset() {
    ref.read(_verifyResultProvider.notifier).reset();
    setState(() => _scanning = true);
    _scanner.start();
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(_verifyResultProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Exit Verification'),
        actions: [
          if (!_scanning)
            IconButton(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Scan next customer',
            ),
        ],
      ),
      body: resultAsync.when(
        data: (result) {
          if (result == null) {
            // Scanning state
            return Stack(
              children: [
                MobileScanner(controller: _scanner, onDetect: _onQrDetected),
                _ScanFrame(),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Scan customer\'s exit QR code',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Result state
          return _VerifyResultView(result: result, onNext: _reset);
        },
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Verifying...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Network error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _reset, child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Verification result view ──────────────────────────────────────────────────

class _VerifyResultView extends StatelessWidget {
  final VerifyResult result;
  final VoidCallback onNext;

  const _VerifyResultView({required this.result, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final color = result.valid ? const Color(0xFF1B5E20) : Colors.red.shade900;
    final bgColor = result.valid
        ? const Color(0xFFF1F8E9)
        : const Color(0xFFFFF3F3);
    final icon = result.valid ? Icons.check_circle : Icons.cancel;

    return Container(
      color: bgColor,
      padding: EdgeInsets.all(
        responsiveValue<double>(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 32, // PRESERVED: Desktop uses exactly 32 as before
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Big status icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 60),
            ),
          ),

          const SizedBox(height: 20),

          // Status text
          Center(
            child: Text(
              result.valid ? '✅  VERIFIED' : '❌  INVALID',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 28.0,
                  tablet: 30.0,
                  desktop: 32.0, // PRESERVED: Desktop uses exactly 32 as before
                ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (result.valid && result.customerName != null) ...[
            _InfoCard(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Customer',
                  value: result.customerName!,
                ),
                _InfoRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Items',
                  value:
                      '${result.totalItems} item${result.totalItems == 1 ? '' : 's'}',
                ),
                _InfoRow(
                  icon: Icons.currency_rupee,
                  label: 'Amount Paid',
                  value: '₹${result.totalAmount?.toStringAsFixed(2) ?? '—'}',
                  valueStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    color: Color(0xFF1B5E20),
                  ),
                ),
                if (result.minutesAgo != null)
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Paid',
                    value: result.minutesAgo == 0
                        ? 'Just now'
                        : '${result.minutesAgo} min ago',
                  ),
                if (result.orderId != null)
                  _InfoRow(
                    icon: Icons.receipt_outlined,
                    label: 'Order',
                    value: result.orderId!,
                    valueStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],

          if (!result.valid && result.reason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.reason!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Do NOT allow this customer to exit.\nCall your manager.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Next Customer'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Text(
            value,
            style:
                valueStyle ??
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Scan frame overlay ────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 270,
        height: 270,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
