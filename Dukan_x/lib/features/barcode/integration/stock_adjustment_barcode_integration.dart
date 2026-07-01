// ignore_for_file: unused_field
// ============================================================================
// STOCK ADJUSTMENT BARCODE INTEGRATION
// ============================================================================
// Wraps StockAdjustmentScreen with USB barcode scanning so that products
// can be selected by scanning their barcode instead of manual search.
// The scanned product auto-fills the product selector field.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/config/business_capabilities.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../models/stock_item.dart';
import '../../../providers/app_state_providers.dart';
import '../../../widgets/ui/futuristic_button.dart';
import '../../inventory/services/inventory_service.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';

// ============================================================================
// STOCK ADJUSTMENT WITH BARCODE
// ============================================================================

class StockAdjustmentWithBarcodeScreen extends ConsumerStatefulWidget {
  const StockAdjustmentWithBarcodeScreen({super.key});

  @override
  ConsumerState<StockAdjustmentWithBarcodeScreen> createState() =>
      _StockAdjustmentWithBarcodeScreenState();
}

class _StockAdjustmentWithBarcodeScreenState
    extends ConsumerState<StockAdjustmentWithBarcodeScreen>
    with BarcodeScannerMixin<StockAdjustmentWithBarcodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = sl<InventoryService>();
  final _userId = sl<SessionManager>().ownerId;

  String _type = 'OUT';
  String _reason = 'DAMAGE';
  DateTime _date = DateTime.now();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Product selected via barcode or manual picker
  StockItem? _selectedProduct;
  ScannedProduct? _scannedProductData;
  bool _isLoading = false;
  bool _productSelectedViaBarcode = false;

  final List<String> _reasonsOut = [
    'DAMAGE',
    'LOSS',
    'THEFT',
    'CONSUMPTION',
    'EXPIRED',
    'OTHER_OUT',
  ];

  final List<String> _reasonsIn = [
    'OPENING_STOCK',
    'SALE_RETURN',
    'FOUND',
    'SURPLUS',
    'OTHER_IN',
  ];

  @override
  BusinessType get barcodeBusinessType =>
      ref.read(businessTypeProvider).type;

  @override
  void initState() {
    super.initState();
    _reason = _type == 'OUT' ? _reasonsOut.first : _reasonsIn.first;
    initBarcodeMixin();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _descriptionController.dispose();
    disposeBarcodeMixin();
    super.dispose();
  }

  // ==========================================================================
  // BARCODE CALLBACKS
  // ==========================================================================

  @override
  void onBarcodeProductFound(ScannedProduct product) {
    // Convert ScannedProduct → StockItem for the adjustment form
    final stockItem = StockItem(
      id: product.id,
      name: product.displayTitle,
      category: product.category ?? 'General',
      sku: product.sku ?? '',
      hsn: product.hsnCode ?? '',
      purchasePrice: product.purchasePrice ?? 0,
      sellingPrice: product.salePrice,
      gstRate: product.gstRate,
      quantity: product.currentStock,
      unit: product.unit,
      lowStockThreshold: product.lowStockThreshold,
      expiryDate: product.expiryDate,
      ownerId: _userId ?? '',
      metadata: {
        if (product.batchNumber != null) 'batchNumber': product.batchNumber,
        if (product.imei != null) 'imei': product.imei,
        if (product.serialNumber != null) 'serialNumber': product.serialNumber,
        if (product.brand != null) 'brand': product.brand,
      },
    );

    setState(() {
      _selectedProduct = stockItem;
      _scannedProductData = product;
      _productSelectedViaBarcode = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product selected: ${product.displayTitle}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void onBarcodeProductNotFound(String barcode) {
    showBarcodeNotFoundDialog(barcode);
  }

  // ==========================================================================
  // FORM LOGIC
  // ==========================================================================

  void _onTypeChanged(String? val) {
    if (val != null) {
      setState(() {
        _type = val;
        _reason = val == 'OUT' ? _reasonsOut.first : _reasonsIn.first;
      });
    }
  }

  void _clearSelectedProduct() {
    setState(() {
      _selectedProduct = null;
      _scannedProductData = null;
      _productSelectedViaBarcode = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or select a product')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qty = double.parse(_quantityController.text);

      await _inventoryService.addStockMovement(
        userId: _userId ?? '',
        productId: _selectedProduct!.id,
        type: _type,
        reason: _reason,
        quantity: qty,
        referenceId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        date: _date,
        description: _descriptionController.text.isEmpty
            ? 'Manual Adjustment ($_reason)'
            : _descriptionController.text,
        createdBy: sl<SessionManager>().currentSession.role.name.toUpperCase(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjusted Successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);
    final reasons = _type == 'OUT' ? _reasonsOut : _reasonsIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
        actions: [
          if (capabilities.supportsBarcodeScan) ...[
            buildBarcodeScannerIndicator(),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hidden barcode input (only if supported)
              if (capabilities.supportsBarcodeScan) buildHiddenBarcodeInput(),

              // Barcode scan hint
              if (capabilities.supportsBarcodeScan && _selectedProduct == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan barcode to select product',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'USB/Bluetooth scanner is active',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Type Toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'OUT', label: Text('Stock OUT (-)')),
                  ButtonSegment(value: 'IN', label: Text('Stock IN (+)')),
                ],
                selected: {_type},
                onSelectionChanged: (Set<String> newSelection) {
                  _onTypeChanged(newSelection.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return _type == 'OUT'
                          ? FuturisticColors.unpaidBackground
                          : FuturisticColors.paidBackground;
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Reason Dropdown
              DropdownButtonFormField<String>(
                value: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _reason = val!),
              ),
              const SizedBox(height: 16),

              // Product Selector (barcode-enhanced)
              if (_selectedProduct != null)
                Card(
                  color: _productSelectedViaBarcode
                      ? Colors.green.withValues(alpha: 0.05)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      _productSelectedViaBarcode
                          ? Icons.qr_code_scanner
                          : Icons.inventory_2,
                      color: _productSelectedViaBarcode
                          ? Colors.green
                          : Colors.grey,
                    ),
                    title: Text(
                      _selectedProduct!.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Stock: ${_selectedProduct!.quantity} ${_selectedProduct!.unit}'),
                        if (_productSelectedViaBarcode)
                          const Text(
                            'Selected via barcode scan',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelectedProduct,
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    // Fallback to manual product picker
                    // The original screen's _selectProduct logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scan a barcode or use the product picker'),
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Product',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (capabilities.supportsBarcodeScan)
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: focusBarcodeScanner,
                              tooltip: 'Focus barcode scanner',
                            ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                    child: const Text(
                      'Scan barcode or select product',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final v = double.tryParse(val);
                  if (v == null || v <= 0) return 'Invalid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Note (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Submit
              _type == 'OUT'
                  ? FuturisticButton.danger(
                      label:
                          _isLoading ? 'Submitting...' : 'Submit Deduction',
                      icon: Icons.remove_circle,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    )
                  : FuturisticButton.success(
                      label:
                          _isLoading ? 'Submitting...' : 'Submit Addition',
                      icon: Icons.add_circle,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
