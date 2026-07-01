// ============================================================================
// BARCODE SCANNER SERVICE
// ============================================================================
// Wrapper around mobile_scanner to provide a clean API for barcode scanning.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerService {
  /// Scan a barcode and return the value.
  /// Returns null if cancelled.
  Future<String?> scanBarcode(BuildContext context) async {
    try {
      // We navigate to a dedicated scanning screen provided by mobile_scanner's examples
      // or build a quick custom one. For consistency, let's build a simple one here.
      final result = await Navigator.push<BarcodeCapture?>(
        context,
        MaterialPageRoute(
          builder: (context) => const _SimpleBarcodeScannerPage(),
        ),
      );

      if (result != null && result.barcodes.isNotEmpty) {
        return result.barcodes.first.rawValue;
      }
    } catch (e) {
      debugPrint('Barcode scanner exception: $e');
    }
    return null;
  }
}

class _SimpleBarcodeScannerPage extends StatefulWidget {
  const _SimpleBarcodeScannerPage();

  @override
  State<_SimpleBarcodeScannerPage> createState() =>
      _SimpleBarcodeScannerPageState();
}

class _SimpleBarcodeScannerPageState extends State<_SimpleBarcodeScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.all],
  );

  bool _isTorchOn = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                // Return the first detected barcode
                Navigator.pop(context, capture);
              }
            },
          ),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Corners
            Align(
              alignment: Alignment.topLeft,
              child: Container(width: 20, height: 20, color: Colors.red),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Container(width: 20, height: 20, color: Colors.red),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(width: 20, height: 20, color: Colors.red),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(width: 20, height: 20, color: Colors.red),
            ),
            Center(
              child: Container(
                color: Colors.red.withOpacity(0.1),
                width: double.infinity,
                height: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
