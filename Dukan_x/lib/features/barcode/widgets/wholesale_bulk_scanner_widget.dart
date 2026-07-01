// ============================================================================
// WHOLESALE BULK ENTRY SCANNER WIDGET
// ============================================================================
// Specialized scanner for wholesale business type. Supports:
// - Multi-unit scanning (case, pallet, dozen, box)
// - UOM conversion (1 case = X units)
// - Bulk quantity entry
// - Running total with base unit conversion
// - Discount tier display
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/di/service_locator.dart';
import '../services/barcode_lookup_service.dart';
import '../models/barcode_scan_result.dart';

// ============================================================================
// WHOLESALE BULK SCANNER
// ============================================================================

class WholesaleBulkScannerWidget extends StatefulWidget {
  final void Function(WholesaleBulkScanResult result)? onComplete;
  final VoidCallback? onCancel;

  const WholesaleBulkScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<WholesaleBulkScannerWidget> createState() =>
      _WholesaleBulkScannerWidgetState();
}

class _WholesaleBulkScannerWidgetState
    extends State<WholesaleBulkScannerWidget> {
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Quantity entry
  final TextEditingController _qtyController = TextEditingController(text: '1');

  // State
  bool _isScanning = false;
  String? _errorMessage;
  ScannedProduct? _scannedProduct;
  String _selectedUnit = 'pcs';
  bool _showProductDetails = false;

  // UOM conversions from product metadata
  Map<String, double> get _uomConversions {
    final conversions = _scannedProduct?.attributes['uomConversions'];
    if (conversions is Map) {
      return Map<String, double>.from(
        conversions.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      );
    }
    return _defaultConversions;
  }

  static const Map<String, double> _defaultConversions = {
    'pcs': 1,
    'dozen': 12,
    'box': 24,
    'case': 48,
    'carton': 100,
    'pallet': 500,
  };

  List<String> get _availableUnits {
    final units = _uomConversions.keys.toList();
    if (!units.contains('pcs')) units.insert(0, 'pcs');
    return units;
  }

  double get _baseQty {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final multiplier = _uomConversions[_selectedUnit] ?? 1;
    return qty * multiplier;
  }

  double get _totalAmount {
    if (_scannedProduct == null) return 0;
    return _baseQty * _scannedProduct!.salePrice;
  }

  // Wholesale price tiers
  List<Map<String, dynamic>> get _priceTiers =>
      (_scannedProduct?.attributes['priceTiers'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];

  double? get _applicableDiscount {
    if (_priceTiers.isEmpty) return null;
    double? discount;
    for (final tier in _priceTiers) {
      final minQty = (tier['minQty'] as num?)?.toDouble() ?? 0;
      if (_baseQty >= minQty) {
        discount = (tier['discountPercent'] as num?)?.toDouble();
      }
    }
    return discount;
  }

  @override
  void initState() {
    super.initState();
    _lookupService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _qtyController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BARCODE PROCESSING
  // ==========================================================================

  void _onBarcodeSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _debounceTimer?.cancel();
    _barcodeController.clear();

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _processBarcode(trimmed);
    });

    _barcodeFocusNode.requestFocus();
  }

  Future<void> _processBarcode(String barcode) async {
    try {
      final result = await _lookupService.lookupBarcode(barcode: barcode);

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _isScanning = false;
          _showProductDetails = true;
          _selectedUnit = result.product!.unit;
          _qtyController.text = '1';
        });
        _playSuccess();
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Product not found';
          _isScanning = false;
        });
        _playError();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isScanning = false;
      });
      _playError();
    }
  }

  void _onComplete() {
    if (_scannedProduct == null) return;

    final result = WholesaleBulkScanResult(
      product: _scannedProduct!,
      enteredQty: double.tryParse(_qtyController.text) ?? 1,
      selectedUnit: _selectedUnit,
      baseUnitQty: _baseQty,
      discountPercent: _applicableDiscount,
      scannedAt: DateTime.now(),
    );

    widget.onComplete?.call(result);
  }

  void _resetToScan() {
    setState(() {
      _scannedProduct = null;
      _showProductDetails = false;
      _selectedUnit = 'pcs';
      _qtyController.text = '1';
      _errorMessage = null;
    });
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _playSuccess() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.3);
    } catch (_) {}
  }

  Future<void> _playError() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'), volume: 0.3);
    } catch (_) {}
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_errorMessage != null) _buildErrorBanner(),
              if (_errorMessage != null) const SizedBox(height: 12),
              if (!_showProductDetails) _buildScanStep(),
              if (_showProductDetails) _buildBulkEntryStep(),
              const SizedBox(height: 20),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.warehouse, color: Colors.indigo, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wholesale Bulk Entry',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan product, select unit & bulk quantity',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildScanStep() {
    return Column(
      children: [
        SizedBox(
          height: 1,
          child: TextField(
            controller: _barcodeController,
            focusNode: _barcodeFocusNode,
            onSubmitted: _onBarcodeSubmitted,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 48,
                color: _isScanning ? Colors.indigo : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _isScanning ? 'Looking up...' : 'Scan product barcode',
                style: TextStyle(color: _isScanning ? Colors.indigo : Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulkEntryStep() {
    final product = _scannedProduct!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '₹${product.salePrice.toStringAsFixed(2)}/pcs | Stock: ${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Unit selection
        const Text('Unit:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableUnits.map((unit) {
            final isSelected = _selectedUnit == unit;
            final multiplier = _uomConversions[unit] ?? 1;
            return ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit.toUpperCase(), style: const TextStyle(fontSize: 12)),
                  if (multiplier > 1)
                    Text(
                      '(${multiplier.toStringAsFixed(0)} pcs)',
                      style: const TextStyle(fontSize: 9),
                    ),
                ],
              ),
              selected: isSelected,
              selectedColor: Colors.indigo.withValues(alpha: 0.2),
              onSelected: (val) {
                setState(() => _selectedUnit = val ? unit : 'pcs');
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Quantity entry
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _qtyController,
                decoration: InputDecoration(
                  labelText: 'Quantity ($_selectedUnit)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Conversion display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Base units (pcs):'),
                  Text(
                    _baseQty.toStringAsFixed(0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Unit price:'),
                  Text('₹${product.salePrice.toStringAsFixed(2)}'),
                ],
              ),
              if (_applicableDiscount != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bulk discount:', style: TextStyle(color: Colors.green)),
                    Text(
                      '-${_applicableDiscount!.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '₹${(_applicableDiscount != null ? _totalAmount * (1 - _applicableDiscount! / 100) : _totalAmount).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Price tiers info
        if (_priceTiers.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Bulk Discount Tiers:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          ...(_priceTiers.map((tier) {
            final minQty = (tier['minQty'] as num?)?.toDouble() ?? 0;
            final discount = (tier['discountPercent'] as num?)?.toDouble() ?? 0;
            final isActive = _baseQty >= minQty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.circle_outlined,
                    size: 14,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '≥ ${minQty.toStringAsFixed(0)} pcs → ${discount.toStringAsFixed(1)}% off',
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          })),
        ],

        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _resetToScan,
          icon: const Icon(Icons.qr_code_scanner, size: 16),
          label: const Text('Scan Another'),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        const SizedBox(width: 12),
        if (_showProductDetails)
          FilledButton.icon(
            onPressed: _baseQty > 0 ? _onComplete : null,
            icon: const Icon(Icons.check),
            label: Text('Add ${_baseQty.toStringAsFixed(0)} pcs'),
          ),
      ],
    );
  }
}

// ============================================================================
// WHOLESALE BULK SCAN RESULT
// ============================================================================

class WholesaleBulkScanResult {
  final ScannedProduct product;
  final double enteredQty;
  final String selectedUnit;
  final double baseUnitQty;
  final double? discountPercent;
  final DateTime scannedAt;

  WholesaleBulkScanResult({
    required this.product,
    required this.enteredQty,
    required this.selectedUnit,
    required this.baseUnitQty,
    this.discountPercent,
    required this.scannedAt,
  });
}
