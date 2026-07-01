// ============================================================================
// BARCODE INTEGRATION MIXIN
// ============================================================================
// Reusable mixin that provides USB barcode scanning capabilities to any
// StatefulWidget screen. Handles scanner input, lookup, audio feedback,
// expiry/low-stock warnings, and business-type gating.
//
// Usage:
//   class _MyScreenState extends State<MyScreen>
//       with BarcodeScannerMixin<MyScreen> {
//
//     @override
//     void onBarcodeProductFound(ScannedProduct product) {
//       // Add product to your list
//     }
//
//     @override
//     void onBarcodeProductNotFound(String barcode) {
//       // Show "add product" dialog
//     }
//   }
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/config/business_capabilities.dart';
import '../services/barcode_lookup_service.dart';
import '../models/barcode_scan_result.dart';

// ============================================================================
// MIXIN
// ============================================================================

mixin BarcodeScannerMixin<T extends StatefulWidget> on State<T> {
  // --- Services (lazy-initialized) ---
  late final BarcodeLookupService _bsMixinLookupService;
  late final SessionManager _bsMixinSession;
  final AudioPlayer _bsMixinAudioPlayer = AudioPlayer();

  // --- Scanner controllers ---
  final TextEditingController barcodeTextController = TextEditingController();
  final FocusNode barcodeFocusNode = FocusNode();
  Timer? _bsMixinDebounceTimer;
  String _bsMixinLastScanBuffer = '';
  DateTime? _bsMixinLastScanTime;
  bool _bsMixinIsProcessingScan = false;

  // --- State ---
  BarcodeMixinStatus barcodeScanStatus = BarcodeMixinStatus.idle;
  String? barcodeLastError;
  ScannedProduct? barcodeLastProduct;

  // --- Config (override in subclass if needed) ---
  int get barcodeDebounceMs => 50;
  int get barcodeDuplicateWindowMs => 100;
  bool get barcodePlaySounds => true;
  bool get barcodeAutoRefocus => true;

  /// Override to provide the current business type for gating.
  BusinessType get barcodeBusinessType;

  // --- Callbacks (override in subclass) ---
  /// Called when a product is successfully found via barcode scan.
  void onBarcodeProductFound(ScannedProduct product);

  /// Called when no product matches the scanned barcode.
  void onBarcodeProductNotFound(String barcode);

  /// Called on scan error. Default shows a SnackBar.
  void onBarcodeScanError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  /// Call from [initState] of the host widget.
  void initBarcodeMixin() {
    _bsMixinLookupService = sl<BarcodeLookupService>();
    _bsMixinSession = sl<SessionManager>();
    _bsMixinLookupService.initialize();

    // Auto-focus scanner after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      barcodeFocusNode.requestFocus();
    });
  }

  /// Call from [dispose] of the host widget.
  void disposeBarcodeMixin() {
    _bsMixinDebounceTimer?.cancel();
    barcodeTextController.dispose();
    barcodeFocusNode.dispose();
    _bsMixinAudioPlayer.dispose();
  }

  // ==========================================================================
  // PUBLIC API
  // ==========================================================================

  /// Returns true if barcode scanning is supported for the current business type.
  bool get isBarcodeScanSupported {
    return BusinessCapabilities.get(barcodeBusinessType).supportsBarcodeScan;
  }

  /// Manually trigger focus on the hidden barcode scanner input.
  void focusBarcodeScanner() {
    barcodeFocusNode.requestFocus();
  }

  // ==========================================================================
  // SCANNER INPUT HANDLING
  // ==========================================================================

  /// Attach this to the hidden TextField's [onSubmitted] callback.
  void onBarcodeFieldSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Duplicate / bounce check
    final now = DateTime.now();
    if (_bsMixinLastScanTime != null) {
      final diff = now.difference(_bsMixinLastScanTime!).inMilliseconds;
      if (diff < barcodeDuplicateWindowMs &&
          trimmed == _bsMixinLastScanBuffer) {
        barcodeTextController.clear();
        return;
      }
    }
    _bsMixinLastScanTime = now;
    _bsMixinLastScanBuffer = trimmed;

    _bsMixinDebounceTimer?.cancel();
    barcodeTextController.clear();

    setState(() {
      barcodeScanStatus = BarcodeMixinStatus.scanning;
      barcodeLastError = null;
    });

    _bsMixinDebounceTimer = Timer(
      Duration(milliseconds: barcodeDebounceMs),
      () {
        _processBarcode(trimmed);
      },
    );

    if (barcodeAutoRefocus) {
      barcodeFocusNode.requestFocus();
    }
  }

  /// Attach this to the hidden TextField's [onChanged] to catch \n / \r.
  void onBarcodeFieldChanged(String value) {
    if (value.contains('\n') || value.contains('\r')) {
      final clean = value.replaceAll('\n', '').replaceAll('\r', '');
      onBarcodeFieldSubmitted(clean);
    }
  }

  // ==========================================================================
  // INTERNAL
  // ==========================================================================

  Future<void> _processBarcode(String barcode) async {
    if (_bsMixinIsProcessingScan) return;
    _bsMixinIsProcessingScan = true;

    // Business-type gate
    if (!isBarcodeScanSupported) {
      setState(() {
        barcodeScanStatus = BarcodeMixinStatus.error;
        barcodeLastError =
            'Barcode scanning not enabled for this business type';
      });
      _playError();
      _bsMixinIsProcessingScan = false;
      return;
    }

    setState(() => barcodeScanStatus = BarcodeMixinStatus.lookingUp);

    try {
      final result = await _bsMixinLookupService.lookupBarcode(
        barcode: barcode,
        businessId: _bsMixinSession.ownerId ?? '',
      );

      if (result.success && result.product != null) {
        final product = result.product!;

        // Pharmacy expiry block
        if (product.expiryWarning != null &&
            product.expiryWarning!.level == ExpiryLevel.critical &&
            barcodeBusinessType == BusinessType.pharmacy) {
          setState(() {
            barcodeScanStatus = BarcodeMixinStatus.error;
            barcodeLastError =
                'EXPIRED: ${product.displayTitle} cannot be sold';
          });
          _playError();
          _bsMixinIsProcessingScan = false;
          return;
        }

        setState(() {
          barcodeScanStatus = BarcodeMixinStatus.success;
          barcodeLastProduct = product;
        });
        _playSuccess();

        // Warnings
        _showExpiryWarningIfNeeded(product);
        _showLowStockWarningIfNeeded(product);

        // Callback
        onBarcodeProductFound(product);
      } else {
        setState(() {
          barcodeScanStatus = BarcodeMixinStatus.notFound;
          barcodeLastError = result.errorMessage ?? 'Product not found';
        });
        _playError();
        onBarcodeProductNotFound(barcode);
      }
    } catch (e) {
      setState(() {
        barcodeScanStatus = BarcodeMixinStatus.error;
        barcodeLastError = 'Error: $e';
      });
      _playError();
      onBarcodeScanError('Scan error: $e');
    } finally {
      _bsMixinIsProcessingScan = false;

      // Reset status after short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => barcodeScanStatus = BarcodeMixinStatus.idle);
        }
      });
    }
  }

  // ==========================================================================
  // WARNINGS
  // ==========================================================================

  void _showExpiryWarningIfNeeded(ScannedProduct product) {
    if (product.expiryWarning == null) return;
    if (product.expiryWarning!.level != ExpiryLevel.warning) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ ${product.displayTitle} expires in ${product.daysUntilExpiry} days',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLowStockWarningIfNeeded(ScannedProduct product) {
    if (!product.isLowStock) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ Low stock: ${product.displayTitle} (${product.currentStock} ${product.unit} left)',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================================
  // AUDIO
  // ==========================================================================

  Future<void> _playSuccess() async {
    if (!barcodePlaySounds) return;
    try {
      await _bsMixinAudioPlayer.play(
        AssetSource('sounds/beep.mp3'),
        volume: 0.3,
      );
    } catch (_) {}
  }

  Future<void> _playError() async {
    if (!barcodePlaySounds) return;
    try {
      await _bsMixinAudioPlayer.play(
        AssetSource('sounds/error.mp3'),
        volume: 0.3,
      );
    } catch (_) {}
  }

  // ==========================================================================
  // REUSABLE UI WIDGETS
  // ==========================================================================

  /// Hidden 1px TextField that captures USB scanner input.
  /// Place this anywhere in your widget tree (usually at the top of a Column).
  Widget buildHiddenBarcodeInput() {
    return SizedBox(
      height: 1,
      child: TextField(
        controller: barcodeTextController,
        focusNode: barcodeFocusNode,
        onSubmitted: onBarcodeFieldSubmitted,
        onChanged: onBarcodeFieldChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 1),
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.none,
        enableSuggestions: false,
        autocorrect: false,
        autofocus: false,
      ),
    );
  }

  /// Scanner status chip for AppBar or toolbar.
  Widget buildBarcodeScannerIndicator() {
    Color color;
    IconData icon;
    String text;

    switch (barcodeScanStatus) {
      case BarcodeMixinStatus.scanning:
      case BarcodeMixinStatus.lookingUp:
        color = Colors.blue;
        icon = Icons.qr_code_scanner;
        text = 'Scanning...';
        break;
      case BarcodeMixinStatus.success:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Found';
        break;
      case BarcodeMixinStatus.notFound:
        color = Colors.orange;
        icon = Icons.help_outline;
        text = 'Not Found';
        break;
      case BarcodeMixinStatus.error:
        color = Colors.red;
        icon = Icons.error_outline;
        text = 'Error';
        break;
      case BarcodeMixinStatus.idle:
        color = Colors.green;
        icon = Icons.qr_code_scanner;
        text = 'Scanner Ready';
        break;
    }

    return GestureDetector(
      onTap: focusBarcodeScanner,
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(text, style: TextStyle(color: color, fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  /// A generic "Product not found" dialog with option to add a new product.
  void showBarcodeNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No product found for barcode:'),
            const SizedBox(height: 8),
            SelectableText(
              barcode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                '/inventory/add-product',
                extra: {'barcode': barcode},
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS ENUM
// ============================================================================

enum BarcodeMixinStatus { idle, scanning, lookingUp, success, notFound, error }
