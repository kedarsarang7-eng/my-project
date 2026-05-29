// ============================================================================
// Store Entry QR Scan Screen — Camera overlay to scan store entry QR
// ============================================================================
// Entry QR payload: { "storeId": "...", "tenantId": "...", "type": "STORE_ENTRY" }
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/in_store_providers.dart';
import '../../services/in_store_api_service.dart';
import '../../../../../core/navigation/app_router.dart';

class StoreEntryQRScanScreen extends ConsumerStatefulWidget {
  const StoreEntryQRScanScreen({super.key});

  @override
  ConsumerState<StoreEntryQRScanScreen> createState() =>
      _StoreEntryQRScanScreenState();
}

class _StoreEntryQRScanScreenState
    extends ConsumerState<StoreEntryQRScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final raw = barcode!.rawValue!;
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _showError('Invalid QR code. Please scan the store entry QR.');
        return;
      }

      final type = payload['type'] as String?;
      final storeId = payload['storeId'] as String?;
      final tenantId = payload['tenantId'] as String?;

      if (type != 'STORE_ENTRY' || storeId == null || tenantId == null) {
        _showError(
            'This QR is not a store entry code. Ask staff for the correct QR.');
        return;
      }

      await ref
          .read(activeSessionProvider.notifier)
          .startSession(storeId, tenantId);

      if (!mounted) return;
      final session = ref.read(activeSessionProvider).valueOrNull;
      if (session != null) {
        context.go(AppRoutes.inStoreShopping);
      }
    } on InStoreApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Could not connect to store. Please try again.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorMsg = msg);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Store Entry QR'),
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Overlay frame
          _ScanOverlay(),

          // Instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_errorMsg != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Point camera at the store entry QR code at the entrance',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Loading overlay
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Starting session...',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4CAF50), width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Corner accents
            ..._buildCorners(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 28.0;
    const thickness = 4.0;
    const color = Color(0xFF4CAF50);
    return [
      Positioned(top: 0, left: 0, child: _Corner(size, thickness, color, topLeft: true)),
      Positioned(top: 0, right: 0, child: _Corner(size, thickness, color, topRight: true)),
      Positioned(bottom: 0, left: 0, child: _Corner(size, thickness, color, bottomLeft: true)),
      Positioned(bottom: 0, right: 0, child: _Corner(size, thickness, color, bottomRight: true)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double thickness;
  final Color color;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  const _Corner(this.size, this.thickness, this.color,
      {this.topLeft = false,
      this.topRight = false,
      this.bottomLeft = false,
      this.bottomRight = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          thickness: thickness,
          color: color,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double thickness;
  final Color color;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    required this.thickness,
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (bottomRight) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
