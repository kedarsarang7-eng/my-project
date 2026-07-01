import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../widgets/glass_morphism.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDisposed) return;
    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        // Prevent multiple pops
        if (mounted) {
          Navigator.pop(context, code);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Scan Barcode",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final torchState = state.torchState;
              return IconButton(
                icon: Icon(
                  torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: torchState == TorchState.on
                      ? Colors.yellow
                      : Colors.grey,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              return IconButton(
                icon: const Icon(
                  Icons.cameraswitch_rounded,
                  color: Colors.white,
                ),
                onPressed: () => _controller.switchCamera(),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: BoundedBox(
        maxWidth: 800,
        child: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay guides
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corners or animation can be added here
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: GlassContainer(
                borderRadius: 20,
                opacity: 0.3,
                color: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  "Align barcode within frame",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
}
