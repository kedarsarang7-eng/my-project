// ============================================================================
// ISBN SCANNER WIDGET - BOOKSTORE
// ============================================================================
// Specialized barcode scanner for bookstore business type that recognizes
// ISBN-13 (978/979 prefix) barcodes and displays book-specific metadata
// (author, publisher, edition) after lookup.
//
// Features:
// - Automatic ISBN-13 detection from standard EAN-13 scan
// - Book metadata display (author, publisher, ISBN)
// - Publisher returns tracking integration
// - Loyalty points display
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/di/service_locator.dart';
import '../services/barcode_lookup_service.dart';
import '../models/barcode_scan_result.dart';

// ============================================================================
// ISBN SCANNER WIDGET
// ============================================================================

class IsbnScannerWidget extends StatefulWidget {
  final void Function(BookScanResult result)? onComplete;
  final VoidCallback? onCancel;
  final bool showPublisherReturns;

  const IsbnScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
    this.showPublisherReturns = false,
  });

  @override
  State<IsbnScannerWidget> createState() => _IsbnScannerWidgetState();
}

class _IsbnScannerWidgetState extends State<IsbnScannerWidget> {
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;

  // ISBN entry (manual fallback)
  final TextEditingController _isbnController = TextEditingController();

  // State
  bool _isScanning = false;
  String? _errorMessage;
  ScannedProduct? _scannedProduct;
  String? _detectedIsbn;
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
    _isbnController.dispose();
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
    // Detect if this is an ISBN
    final isIsbn = _isIsbn(barcode);
    if (isIsbn) {
      setState(() => _detectedIsbn = barcode);
    }

    try {
      final result = await _lookupService.lookupBarcode(barcode: barcode);

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _isScanning = false;
          _detectedIsbn = result.product!.isbn ?? _detectedIsbn;
        });
        _playSuccessSound();
      } else {
        setState(() {
          _errorMessage = isIsbn
              ? 'ISBN $barcode not found in catalog'
              : (result.errorMessage ?? 'Product not found');
          _isScanning = false;
        });
        _playErrorSound();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isScanning = false;
      });
      _playErrorSound();
    }
  }

  void _manualIsbnLookup() {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) return;
    _processBarcode(isbn);
  }

  bool _isIsbn(String barcode) {
    // ISBN-13 starts with 978 or 979 and is 13 digits
    return RegExp(r'^(978|979)\d{10}$').hasMatch(barcode);
  }

  void _onComplete() {
    if (_scannedProduct == null) return;

    final result = BookScanResult(
      product: _scannedProduct!,
      isbn: _detectedIsbn,
      quantity: _quantity,
      scannedAt: DateTime.now(),
    );

    widget.onComplete?.call(result);
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.3);
    } catch (_) {}
  }

  Future<void> _playErrorSound() async {
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
        width: 480,
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
            if (_scannedProduct != null) _buildBookDetails(),
            const SizedBox(height: 24),
            _buildActions(),
          ],
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
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book, color: Colors.teal, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Book Scanner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan ISBN barcode or enter manually',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hidden barcode input
        SizedBox(
          height: 1,
          child: TextField(
            controller: _barcodeController,
            focusNode: _barcodeFocusNode,
            onSubmitted: _onBarcodeSubmitted,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),

        // Scan area
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 48,
                color: _isScanning ? Colors.teal : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _isScanning ? 'Looking up...' : 'Ready to scan',
                style: TextStyle(
                  fontSize: 14,
                  color: _isScanning ? Colors.teal : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan ISBN barcode with USB scanner',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Manual ISBN entry
        const Text(
          'Or enter ISBN manually:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _isbnController,
                decoration: const InputDecoration(
                  hintText: '978-0-123456-78-9',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _manualIsbnLookup,
              child: const Text('Lookup'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookDetails() {
    final product = _scannedProduct!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success indicator
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Book found!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Book info
        _infoRow('Title', product.displayTitle),
        if (product.author != null)
          _infoRow('Author', product.author!),
        if (product.publisher != null)
          _infoRow('Publisher', product.publisher!),
        if (_detectedIsbn != null) _infoRow('ISBN', _detectedIsbn!),
        _infoRow('Price', '₹${product.salePrice.toStringAsFixed(2)}'),
        _infoRow(
          'In Stock',
          '${product.currentStock.toStringAsFixed(0)} ${product.unit}',
        ),

        if (product.isLowStock) ...[
          const SizedBox(height: 8),
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
                  'Low stock — only ${product.currentStock.toStringAsFixed(0)} left',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Quantity selector
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => _quantity++),
            ),
          ],
        ),

        // Scan another button
        TextButton.icon(
          onPressed: () {
            setState(() {
              _scannedProduct = null;
              _detectedIsbn = null;
              _quantity = 1;
              _errorMessage = null;
            });
            _barcodeFocusNode.requestFocus();
          },
          icon: const Icon(Icons.qr_code_scanner, size: 16),
          label: const Text('Scan Another'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
// BOOK SCAN RESULT
// ============================================================================

class BookScanResult {
  final ScannedProduct product;
  final String? isbn;
  final int quantity;
  final DateTime scannedAt;

  BookScanResult({
    required this.product,
    this.isbn,
    required this.quantity,
    required this.scannedAt,
  });
}
