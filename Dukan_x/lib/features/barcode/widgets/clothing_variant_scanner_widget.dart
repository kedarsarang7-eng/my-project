// ============================================================================
// CLOTHING VARIANT SCANNER WIDGET
// ============================================================================
// Specialized barcode scanner for clothing business type. After scanning a
// product barcode, prompts user to select size and color variants before
// adding to bill. Supports SKU-based variant lookup.
//
// Flow:
// 1. Scan barcode → identify base product (style)
// 2. Show available size/color variants
// 3. User selects variant → add to bill with variant info
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
import '../../../core/api/api_client.dart';

// ============================================================================
// CLOTHING VARIANT SCANNER
// ============================================================================

class ClothingVariantScannerWidget extends StatefulWidget {
  final void Function(ClothingVariantScanResult result)? onComplete;
  final VoidCallback? onCancel;

  const ClothingVariantScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<ClothingVariantScannerWidget> createState() =>
      _ClothingVariantScannerWidgetState();
}

class _ClothingVariantScannerWidgetState
    extends State<ClothingVariantScannerWidget> {
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;

  // State
  int _currentStep = 0; // 0: Scan, 1: Select Variant, 2: Confirm
  bool _isScanning = false;
  String? _errorMessage;
  ScannedProduct? _scannedProduct;

  // Variant selection
  String? _selectedSize;
  String? _selectedColor;
  String? _selectedVariantId;
  int? _variantPriceCents;
  int? _variantStock;
  int _quantity = 1;

  // Available variants (from product attributes)
  List<String> get _availableSizes =>
      (_scannedProduct?.attributes['availableSizes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      _defaultSizes;

  List<String> get _availableColors =>
      (_scannedProduct?.attributes['availableColors'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      _defaultColors;

  static const _defaultSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const _defaultColors = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Navy',
    'Grey',
    'Pink',
    'Beige',
    'Brown',
    'Maroon',
  ];

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
      // First try to find variant by barcode (new enhanced functionality)
      final apiClient = sl<ApiClient>();
      final variantResponse = await apiClient.get('/clothing/barcode/$barcode');

      if (variantResponse.statusCode == 200 && variantResponse.data != null) {
        // Found variant directly by barcode
        final variant = variantResponse.data as Map<String, dynamic>;
        final productResponse = await apiClient.get(
          '/products/${variant['productId']}',
        );

        if (productResponse.statusCode == 200 && productResponse.data != null) {
          final product = ScannedProduct.fromJson(
            productResponse.data as Map<String, dynamic>,
          );
          setState(() {
            _scannedProduct = product;
            _isScanning = false;
            _currentStep = 2; // Skip to quantity step since variant is selected
            _selectedSize = variant['size'] as String?;
            _selectedColor = variant['color'] as String?;
            _selectedVariantId = variant['id'] as String?;
            _variantPriceCents = variant['priceCents'] as int?;
            _variantStock = variant['stock'] as int?;
          });
          _playSuccess();
          return;
        }
      }

      // Fallback to original product-level barcode lookup
      final result = await _lookupService.lookupBarcode(barcode: barcode);

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _isScanning = false;
          _currentStep = 1;
          // Pre-select if product already has size/color
          _selectedSize = result.product!.size;
          _selectedColor = result.product!.color;
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

  void _confirmSelection() {
    if (_scannedProduct == null) return;

    setState(() => _currentStep = 2);

    final result = ClothingVariantScanResult(
      product: _scannedProduct!,
      selectedSize: _selectedSize,
      selectedColor: _selectedColor,
      quantity: _quantity,
      scannedAt: DateTime.now(),
    );

    widget.onComplete?.call(result);
  }

  void _resetToScan() {
    setState(() {
      _currentStep = 0;
      _scannedProduct = null;
      _selectedSize = null;
      _selectedColor = null;
      _quantity = 1;
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
              const SizedBox(height: 16),
              _buildStepIndicator(),
              const SizedBox(height: 20),
              if (_errorMessage != null) _buildErrorBanner(),
              if (_errorMessage != null) const SizedBox(height: 12),
              if (_currentStep == 0) _buildScanStep(),
              if (_currentStep == 1) _buildVariantStep(),
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
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.checkroom, color: Colors.purple, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clothing Scanner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan barcode then select size & color',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close scanner',
          onPressed: widget.onCancel,
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(0, 'Scan'),
        _stepLine(0),
        _stepDot(1, 'Variant'),
        _stepLine(1),
        _stepDot(2, 'Done'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? Colors.purple : Colors.grey.shade300,
          child: isActive
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('${step + 1}', style: const TextStyle(fontSize: 11)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.purple : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? Colors.purple : Colors.grey.shade300,
      ),
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
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStep() {
    return Column(
      children: [
        // Hidden input
        Semantics(
          label: 'Barcode input field',
          textField: true,
          child: SizedBox(
            height: 1,
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              onSubmitted: _onBarcodeSubmitted,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 48,
                color: _isScanning ? Colors.purple : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _isScanning ? 'Looking up...' : 'Scan garment barcode',
                style: TextStyle(
                  color: _isScanning ? Colors.purple : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariantStep() {
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
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${product.salePrice.toStringAsFixed(0)} | ${product.brand ?? "Unknown brand"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Size selection
        const Text(
          'Select Size:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableSizes.map((size) {
            final isSelected = _selectedSize == size;
            return ChoiceChip(
              label: Text(size),
              selected: isSelected,
              selectedColor: Colors.purple.withValues(alpha: 0.2),
              onSelected: (val) {
                setState(() => _selectedSize = val ? size : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Color selection
        const Text(
          'Select Color:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return ChoiceChip(
              label: Text(color),
              selected: isSelected,
              selectedColor: Colors.purple.withValues(alpha: 0.2),
              avatar: CircleAvatar(
                backgroundColor: _colorFromName(color),
                radius: 8,
              ),
              onSelected: (val) {
                setState(() => _selectedColor = val ? color : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Quantity
        Row(
          children: [
            const Text(
              'Quantity:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Decrease quantity',
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
            ),
            Text(
              '$_quantity',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Increase quantity',
              onPressed: () => setState(() => _quantity++),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _resetToScan,
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('Scan Another'),
            ),
          ],
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
        if (_currentStep == 1)
          FilledButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check),
            label: Text(
              'Add${_selectedSize != null ? " [$_selectedSize]" : ""}${_selectedColor != null ? " $_selectedColor" : ""}',
            ),
          ),
      ],
    );
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'navy':
        return const Color(0xFF000080);
      case 'grey':
        return Colors.grey;
      case 'pink':
        return Colors.pink;
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'brown':
        return Colors.brown;
      case 'maroon':
        return const Color(0xFF800000);
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// CLOTHING VARIANT SCAN RESULT
// ============================================================================

class ClothingVariantScanResult {
  final ScannedProduct product;
  final String? selectedSize;
  final String? selectedColor;
  final int quantity;
  final DateTime scannedAt;

  ClothingVariantScanResult({
    required this.product,
    this.selectedSize,
    this.selectedColor,
    required this.quantity,
    required this.scannedAt,
  });

  String get variantDescription {
    final parts = <String>[];
    if (selectedSize != null) parts.add(selectedSize!);
    if (selectedColor != null) parts.add(selectedColor!);
    return parts.isEmpty ? 'Default' : parts.join(' / ');
  }
}
