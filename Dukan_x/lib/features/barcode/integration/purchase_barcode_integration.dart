// ============================================================================
// PURCHASE ENTRY BARCODE INTEGRATION
// ============================================================================
// Wraps AddPurchaseScreen with USB barcode scanning so that items can be
// scanned directly into a purchase / GRN entry. Scanned products auto-fill
// name, cost price, unit, batch, and expiry from the barcode lookup result.
//
// Supported business types: All types with useBarcodeScanner capability.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/config/business_capabilities.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../providers/app_state_providers.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';
import '../../purchase/screens/add_purchase_screen.dart';

// ============================================================================
// WRAPPER SCREEN
// ============================================================================

class PurchaseWithBarcodeScreen extends ConsumerStatefulWidget {
  final PurchaseOrder? initialBill;

  const PurchaseWithBarcodeScreen({super.key, this.initialBill});

  @override
  ConsumerState<PurchaseWithBarcodeScreen> createState() =>
      _PurchaseWithBarcodeScreenState();
}

class _PurchaseWithBarcodeScreenState
    extends ConsumerState<PurchaseWithBarcodeScreen>
    with BarcodeScannerMixin<PurchaseWithBarcodeScreen> {
  final List<PurchaseItem> _scannedItems = [];
  final _session = sl<SessionManager>();

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
    // Convert ScannedProduct â†’ PurchaseItem and add to list
    final purchaseItem = PurchaseItem(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.displayTitle,
      quantity: 1,
      unit: product.unit,
      costPrice: product.purchasePrice ?? product.salePrice,
      taxRate: product.gstRate,
      totalAmount: product.purchasePrice ?? product.salePrice,
      batchNumber: product.batchNumber,
      expiryDate: product.expiryDate,
    );

    setState(() {
      // Check if already scanned â€“ increment quantity if so
      final existing = _scannedItems.indexWhere(
        (i) => i.productId == product.id,
      );
      if (existing >= 0) {
        final old = _scannedItems[existing];
        _scannedItems[existing] = PurchaseItem(
          id: old.id,
          productId: old.productId,
          productName: old.productName,
          quantity: old.quantity + 1,
          unit: old.unit,
          costPrice: old.costPrice,
          taxRate: old.taxRate,
          totalAmount: old.costPrice * (old.quantity + 1),
          batchNumber: old.batchNumber,
          expiryDate: old.expiryDate,
        );
      } else {
        _scannedItems.add(purchaseItem);
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
      return AddPurchaseScreen(initialBill: widget.initialBill);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Entry (Barcode)'),
        actions: [
          buildBarcodeScannerIndicator(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Hidden barcode input
          buildHiddenBarcodeInput(),

          // Scanned items banner
          if (_scannedItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '${_scannedItems.length} item(s) scanned',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _scannedItems.clear());
                    },
                    child: const Text('Clear Scanned'),
                  ),
                ],
              ),
            ),

          // Scanned items list
          if (_scannedItems.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
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
                      '${item.quantity} Ã— â‚¹${item.costPrice.toStringAsFixed(2)}'
                      '${item.batchNumber != null ? ' | Batch: ${item.batchNumber}' : ''}',
                    ),
                    trailing: Text(
                      'â‚¹${item.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() => _scannedItems.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),

          if (_scannedItems.isNotEmpty) const Divider(),

          // Original purchase screen
          Expanded(
            child: AddPurchaseScreen(
              initialBill: widget.initialBill != null
                  ? PurchaseOrder(
                      id: widget.initialBill!.id,
                      userId: widget.initialBill!.userId,
                      vendorName: widget.initialBill!.vendorName,
                      invoiceNumber: widget.initialBill!.invoiceNumber,
                      purchaseDate: widget.initialBill!.purchaseDate,
                      totalAmount: widget.initialBill!.totalAmount,
                      paidAmount: widget.initialBill!.paidAmount,
                      paymentMode: widget.initialBill!.paymentMode,
                      createdAt: widget.initialBill!.createdAt,
                      items: [
                        ...widget.initialBill!.items,
                        ..._scannedItems,
                      ],
                    )
                  : _scannedItems.isNotEmpty
                      ? PurchaseOrder(
                          id: const Uuid().v4(),
                          userId: _session.ownerId ?? '',
                          purchaseDate: DateTime.now(),
                          totalAmount: _scannedItems.fold(
                            0.0,
                            (sum, item) => sum + item.totalAmount,
                          ),
                          createdAt: DateTime.now(),
                          items: _scannedItems,
                        )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}
