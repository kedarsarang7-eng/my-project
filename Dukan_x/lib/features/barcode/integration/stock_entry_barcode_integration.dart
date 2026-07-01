// ============================================================================
// STOCK ENTRY BARCODE INTEGRATION
// ============================================================================
// Wraps AddStockScreen with USB barcode scanning for desktop. When a
// product barcode is scanned, the stock entry form auto-fills with product
// details (name, brand, category, price, unit) from the barcode lookup.
//
// Falls back to the existing AddStockScreen's camera-based scanner on
// mobile or when barcode capability is disabled.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/business_capabilities.dart';
import '../../../models/business_type.dart';
import '../../../providers/app_state_providers.dart';
import '../../stock/presentation/screens/add_stock_screen.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';

// ============================================================================
// WRAPPER SCREEN
// ============================================================================

class StockEntryWithBarcodeScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;

  const StockEntryWithBarcodeScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<StockEntryWithBarcodeScreen> createState() =>
      _StockEntryWithBarcodeScreenState();
}

class _StockEntryWithBarcodeScreenState
    extends ConsumerState<StockEntryWithBarcodeScreen>
    with BarcodeScannerMixin<StockEntryWithBarcodeScreen> {
  String? _lastScannedBarcode;
  ScannedProduct? _lastScannedProduct;

  @override
  BusinessType get barcodeBusinessType =>
      ref.read(businessTypeProvider).type;

  @override
  void initState() {
    super.initState();
    _lastScannedBarcode = widget.initialBarcode;
    initBarcodeMixin();
  }

  @override
  void dispose() {
    disposeBarcodeMixin();
    super.dispose();
  }

  // ==========================================================================
  // BARCODE CALLBACKS
  // ==========================================================================

  @override
  void onBarcodeProductFound(ScannedProduct product) {
    setState(() {
      _lastScannedBarcode = product.barcode;
      _lastScannedProduct = product;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product found: ${product.displayTitle}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void onBarcodeProductNotFound(String barcode) {
    // For stock entry, "not found" is expected – user is adding new stock.
    // Just pass the barcode to the form for manual entry.
    setState(() {
      _lastScannedBarcode = barcode;
      _lastScannedProduct = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New barcode: $barcode — fill in product details'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);

    // If barcode not supported → show regular screen
    if (!capabilities.supportsBarcodeScan) {
      return AddStockScreen(initialBarcode: widget.initialBarcode);
    }

    return Scaffold(
      body: Column(
        children: [
          // Hidden barcode input for USB scanner
          buildHiddenBarcodeInput(),

          // Scan banner with product info
          if (_lastScannedProduct != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastScannedProduct!.displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Barcode: ${_lastScannedProduct!.barcode ?? _lastScannedBarcode}'
                          '${_lastScannedProduct!.brand != null ? ' | Brand: ${_lastScannedProduct!.brand}' : ''}'
                          ' | Stock: ${_lastScannedProduct!.currentStock} ${_lastScannedProduct!.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildBarcodeScannerIndicator(),
                ],
              ),
            )
          else if (capabilities.supportsBarcodeScan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'USB scanner ready — scan barcode to auto-fill',
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                  const Spacer(),
                  buildBarcodeScannerIndicator(),
                ],
              ),
            ),

          // The existing AddStockScreen with pre-filled barcode
          Expanded(
            child: AddStockScreen(
              initialBarcode: _lastScannedBarcode ?? widget.initialBarcode,
            ),
          ),
        ],
      ),
    );
  }
}
