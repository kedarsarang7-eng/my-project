// ============================================================================
// DELIVERY CHALLAN BARCODE INTEGRATION
// ============================================================================
// Wraps CreateDeliveryChallanScreen with USB barcode scanning so items
// can be scanned directly into the challan. Scanned products auto-fill
// name, unit, price, HSN, and GST details.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/business_capabilities.dart';
import '../../../models/business_type.dart';
import '../../../providers/app_state_providers.dart';
import '../../delivery_challan/models/delivery_challan_model.dart';
import '../../delivery_challan/presentation/screens/create_delivery_challan_screen.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';

// ============================================================================
// WRAPPER SCREEN
// ============================================================================

class DeliveryChallanWithBarcodeScreen extends ConsumerStatefulWidget {
  final DeliveryChallan? existingChallan;

  const DeliveryChallanWithBarcodeScreen({super.key, this.existingChallan});

  @override
  ConsumerState<DeliveryChallanWithBarcodeScreen> createState() =>
      _DeliveryChallanWithBarcodeScreenState();
}

class _DeliveryChallanWithBarcodeScreenState
    extends ConsumerState<DeliveryChallanWithBarcodeScreen>
    with BarcodeScannerMixin<DeliveryChallanWithBarcodeScreen> {
  final List<DeliveryChallanItem> _scannedItems = [];

  @override
  BusinessType get barcodeBusinessType =>
      ref.read(businessTypeProvider).type;

  @override
  void initState() {
    super.initState();
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
    final qty = 1.0;
    final unitPrice = product.salePrice;
    final taxRate = product.gstRate;
    final baseAmount = qty * unitPrice;
    final cgstRate = taxRate / 2;
    final sgstRate = taxRate / 2;
    final cgst = baseAmount * cgstRate / 100;
    final sgst = baseAmount * sgstRate / 100;

    final item = DeliveryChallanItem(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.displayTitle,
      quantity: qty,
      unit: product.unit,
      unitPrice: unitPrice,
      taxRate: taxRate,
      taxAmount: cgst + sgst,
      totalAmount: baseAmount + cgst + sgst,
      hsnCode: product.hsnCode,
      cgstRate: cgstRate,
      cgstAmount: cgst,
      sgstRate: sgstRate,
      sgstAmount: sgst,
    );

    setState(() {
      // Check if already scanned â€“ increment quantity
      final existing = _scannedItems.indexWhere(
        (i) => i.productId == product.id,
      );
      if (existing >= 0) {
        final old = _scannedItems[existing];
        final newQty = old.quantity + 1;
        final newBase = newQty * old.unitPrice;
        final newCgst = newBase * old.cgstRate / 100;
        final newSgst = newBase * old.sgstRate / 100;
        _scannedItems[existing] = DeliveryChallanItem(
          id: old.id,
          productId: old.productId,
          productName: old.productName,
          quantity: newQty,
          unit: old.unit,
          unitPrice: old.unitPrice,
          taxRate: old.taxRate,
          taxAmount: newCgst + newSgst,
          totalAmount: newBase + newCgst + newSgst,
          hsnCode: old.hsnCode,
          cgstRate: old.cgstRate,
          cgstAmount: newCgst,
          sgstRate: old.sgstRate,
          sgstAmount: newSgst,
        );
      } else {
        _scannedItems.add(item);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added: ${product.displayTitle}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void onBarcodeProductNotFound(String barcode) {
    showBarcodeNotFoundDialog(barcode);
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);

    // If barcode not supported â†’ show regular screen
    if (!capabilities.supportsBarcodeScan) {
      return CreateDeliveryChallanScreen(existingChallan: widget.existingChallan);
    }

    return Scaffold(
      body: Column(
        children: [
          // Hidden barcode input
          buildHiddenBarcodeInput(),

          // Scanned items banner
          if (_scannedItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '${_scannedItems.length} item(s) scanned for challan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  buildBarcodeScannerIndicator(),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _scannedItems.clear());
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Scanned items preview
          if (_scannedItems.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _scannedItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _scannedItems[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.productName),
                    subtitle: Text(
                      '${item.quantity} ${item.unit} Ã— â‚¹${item.unitPrice.toStringAsFixed(2)}'
                      '${item.hsnCode != null ? ' | HSN: ${item.hsnCode}' : ''}',
                    ),
                    trailing: Text(
                      'â‚¹${item.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() => _scannedItems.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),

          if (_scannedItems.isNotEmpty) const Divider(),

          // Original challan screen
          Expanded(
            child: CreateDeliveryChallanScreen(
              existingChallan: widget.existingChallan,
            ),
          ),
        ],
      ),
    );
  }
}
