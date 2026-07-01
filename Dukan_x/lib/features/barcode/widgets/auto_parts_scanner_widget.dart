// ============================================================================
// AUTO PARTS BARCODE SCANNER WIDGET
// ============================================================================
// Specialized barcode scanner for auto parts business type. After scanning
// a part barcode, displays vehicle compatibility info from product metadata
// (OEM number, fitment list, cross-references).
//
// Features:
// - Part number lookup via barcode
// - Vehicle compatibility display (make, model, year range)
// - Cross-reference / alternate part numbers
// - OEM number display
// - Warranty period display
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
// AUTO PARTS SCANNER WIDGET
// ============================================================================

class AutoPartsScannerWidget extends StatefulWidget {
  final void Function(AutoPartScanResult result)? onComplete;
  final VoidCallback? onCancel;

  const AutoPartsScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
  });

  @override
  State<AutoPartsScannerWidget> createState() => _AutoPartsScannerWidgetState();
}

class _AutoPartsScannerWidgetState extends State<AutoPartsScannerWidget> {
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;

  // State
  bool _isScanning = false;
  String? _errorMessage;
  ScannedProduct? _scannedProduct;
  int _quantity = 1;

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
      final result = await _lookupService.lookupBarcode(barcode: barcode);

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _isScanning = false;
        });
        _playSuccess();
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Part not found';
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

    final result = AutoPartScanResult(
      product: _scannedProduct!,
      quantity: _quantity,
      scannedAt: DateTime.now(),
    );

    widget.onComplete?.call(result);
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

  // --- Attribute helpers ---
  String? get _oemNumber => _scannedProduct?.attributes['oemNumber'];
  List<String> get _crossReferences =>
      (_scannedProduct?.attributes['crossReferences'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      [];
  List<Map<String, dynamic>> get _fitmentList =>
      (_scannedProduct?.attributes['fitment'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];
  int? get _warrantyMonths => _scannedProduct?.warrantyMonths;

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 600),
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
              if (_scannedProduct == null) _buildScanStep(),
              if (_scannedProduct != null) _buildPartDetails(),
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
            color: Colors.deepOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.build_circle,
            color: Colors.deepOrange,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto Parts Scanner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan part barcode to view compatibility',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
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
          Expanded(
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStep() {
    return Column(
      children: [
        // Hidden input
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
            color: Colors.deepOrange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 48,
                color: _isScanning ? Colors.deepOrange : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _isScanning ? 'Looking up part...' : 'Ready to scan',
                style: TextStyle(
                  fontSize: 14,
                  color: _isScanning ? Colors.deepOrange : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan part barcode with USB scanner',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartDetails() {
    final product = _scannedProduct!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Part info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow('Barcode', product.barcode ?? 'N/A'),
              if (product.brand != null)
                _infoRow('Brand', product.brand!),
              if (_oemNumber != null) _infoRow('OEM Number', _oemNumber!),
              _infoRow('Price', '₹${product.salePrice.toStringAsFixed(2)}'),
              _infoRow(
                'Stock',
                '${product.currentStock.toStringAsFixed(0)} ${product.unit}',
              ),
              if (_warrantyMonths != null)
                _infoRow('Warranty', '$_warrantyMonths months'),
            ],
          ),
        ),

        // Vehicle compatibility
        if (_fitmentList.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Vehicle Compatibility',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...(_fitmentList.map((fitment) => Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.directions_car, size: 20),
                  title: Text(
                    '${fitment['make'] ?? ''} ${fitment['model'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: fitment['yearRange'] != null
                      ? Text(
                          'Years: ${fitment['yearRange']}',
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                ),
              ))),
        ],

        // Cross-references
        if (_crossReferences.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Cross-Reference Part Numbers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _crossReferences
                .map(
                  (ref) => Chip(
                    label: Text(ref, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                )
                .toList(),
          ),
        ],

        // Low stock warning
        if (product.isLowStock) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Low stock — ${product.currentStock.toStringAsFixed(0)} left',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Quantity & scan another
        Row(
          children: [
            const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
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
              onPressed: () => setState(() => _quantity++),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _scannedProduct = null;
                  _quantity = 1;
                  _errorMessage = null;
                });
                _barcodeFocusNode.requestFocus();
              },
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: const Text('Scan Another'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        if (_scannedProduct != null)
          FilledButton.icon(
            onPressed: _onComplete,
            icon: const Icon(Icons.check),
            label: const Text('Add to Bill'),
          ),
      ],
    );
  }
}

// ============================================================================
// AUTO PART SCAN RESULT
// ============================================================================

class AutoPartScanResult {
  final ScannedProduct product;
  final int quantity;
  final DateTime scannedAt;

  AutoPartScanResult({
    required this.product,
    required this.quantity,
    required this.scannedAt,
  });
}
