// ignore_for_file: empty_catches
// ignore_for_file: unused_field
// ============================================================================
// IMEI SCANNER WIDGET - MOBILE SHOP
// ============================================================================
// Specialized scanner for mobile phones and accessories
// Captures both product barcode and IMEI/Serial numbers
//
// Features:
// - Dual scan: Product barcode + IMEI
// - Warranty tracking
// - IMEI validation (Luhn checksum)
// - Bulk IMEI entry for accessories
// - Duplicate IMEI detection
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/barcode_scan_result.dart';
import '../services/barcode_lookup_service.dart';

// ============================================================================
// IMEI SCANNER WIDGET
// ============================================================================

class ImeiScannerWidget extends ConsumerStatefulWidget {
  /// Callback when product + IMEI are captured
  final void Function(MobileProductScan result)? onComplete;
  
  /// Callback for cancellation
  final VoidCallback? onCancel;
  
  /// Whether this is for a mobile phone (requires IMEI) or accessory (optional)
  final bool requireImei;
  
  /// Allow multiple IMEIs (for accessories packs)
  final bool allowMultipleImeis;

  const ImeiScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
    this.requireImei = true,
    this.allowMultipleImeis = false,
  });

  @override
  ConsumerState<ImeiScannerWidget> createState() => _ImeiScannerWidgetState();
}

class _ImeiScannerWidgetState extends ConsumerState<ImeiScannerWidget> {
  // Services
  final BarcodeLookupService _lookupService = BarcodeLookupService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  final List<TextEditingController> _imeiControllers = [];
  final List<FocusNode> _imeiFocusNodes = [];
  final List<String> _capturedImeis = [];
  
  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;
  
  // Product
  ScannedProduct? _scannedProduct;
  bool _isScanning = false;
  String? _errorMessage;
  bool _isImeiValid = false;

  // Steps
  int _currentStep = 0; // 0: Scan product, 1: Scan/enter IMEI, 2: Warranty, 3: Confirm

  @override
  void initState() {
    super.initState();
    _lookupService.initialize();
    _addImeiField(); // Add first IMEI field
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    for (var c in _imeiControllers) {
      c.dispose();
    }
    for (var f in _imeiFocusNodes) {
      f.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addImeiField() {
    setState(() {
      _imeiControllers.add(TextEditingController());
      _imeiFocusNodes.add(FocusNode());
      _capturedImeis.add('');
    });
  }

  void _removeImeiField(int index) {
    if (_imeiControllers.length <= 1) return; // Keep at least one
    setState(() {
      _imeiControllers[index].dispose();
      _imeiFocusNodes[index].dispose();
      _imeiControllers.removeAt(index);
      _imeiFocusNodes.removeAt(index);
      _capturedImeis.removeAt(index);
    });
  }

  // ==========================================================================
  // BARCODE SCANNING
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
      _lookupProduct(trimmed);
    });

    _barcodeFocusNode.requestFocus();
  }

  Future<void> _lookupProduct(String barcode) async {
    try {
      final result = await _lookupService.lookupBarcode(
        barcode: barcode,
      );

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _currentStep = 1;
          _isScanning = false;
        });
        _playSuccessSound();
        
        // Auto-focus first IMEI field
        if (_imeiFocusNodes.isNotEmpty) {
          _imeiFocusNodes.first.requestFocus();
        }
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Product not found';
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

  // ==========================================================================
  // IMEI VALIDATION
  // ==========================================================================

  /// Validate IMEI using Luhn algorithm
  bool _isValidImei(String imei) {
    if (imei.length != 15) return false;
    if (!RegExp(r'^\d{15}$').hasMatch(imei)) return false;
    return _luhnCheck(imei);
  }

  bool _luhnCheck(String digits) {
    int sum = 0;
    bool alternate = false;
    
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    
    return sum % 10 == 0;
  }

  void _onImeiChanged(int index, String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    setState(() {
      _capturedImeis[index] = cleaned;
      _isImeiValid = cleaned.length == 15 && _isValidImei(cleaned);
      _errorMessage = null;
    });

    // Auto-advance when 15 digits entered
    if (cleaned.length == 15) {
      _validateAndAdvance();
    }
  }

  void _validateAndAdvance() {
    // Check all IMEIs are valid
    final validImeis = _capturedImeis.where((i) => _isValidImei(i)).toList();
    
    if (validImeis.isEmpty && widget.requireImei) {
      setState(() {
        _errorMessage = 'Please enter valid 15-digit IMEI';
      });
      _playErrorSound();
      return;
    }

    // Check for duplicates within this scan
    final uniqueImeis = validImeis.toSet();
    if (uniqueImeis.length != validImeis.length) {
      setState(() {
        _errorMessage = 'Duplicate IMEI detected';
      });
      _playErrorSound();
      return;
    }

    setState(() {
      _currentStep = 3;
    });
    _playSuccessSound();
  }

  void _onComplete() {
    if (_scannedProduct == null) return;

    final validImeis = _capturedImeis.where((i) => _isValidImei(i)).toList();
    
    final result = MobileProductScan(
      product: _scannedProduct!,
      imeis: validImeis,
      warrantyMonths: _scannedProduct?.warrantyMonths ?? 12,
      scannedAt: DateTime.now(),
    );

    widget.onComplete?.call(result);
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.3);
    } catch (e) {}
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'), volume: 0.3);
    } catch (e) {}
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStepIndicator(),
            const SizedBox(height: 24),
            if (_errorMessage != null) _buildErrorBanner(),
            if (_errorMessage != null) const SizedBox(height: 16),
            _buildCurrentStep(),
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
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.smartphone, color: Colors.blue, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mobile Product Scan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan product then enter IMEI',
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

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepCircle(0, 'Product', _currentStep >= 0),
        _buildStepLine(_currentStep >= 1),
        _buildStepCircle(1, 'IMEI', _currentStep >= 1),
        _buildStepLine(_currentStep >= 2),
        _buildStepCircle(2, 'Confirm', _currentStep >= 3),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.blue : Colors.grey.shade300,
            ),
            child: Icon(
              step == 0
                  ? Icons.qr_code
                  : step == 1
                      ? Icons.sim_card
                      : Icons.check,
              color: active ? Colors.white : Colors.grey,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool active) {
    return Container(
      width: 40,
      height: 2,
      color: active ? Colors.blue : Colors.grey.shade300,
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

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildProductScanStep();
      case 1:
      case 2:
        return _buildImeiEntryStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProductScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Scan Product Barcode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 64,
                color: _isScanning ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _isScanning ? 'Looking up product...' : 'Ready to scan',
                style: TextStyle(
                  fontSize: 16,
                  color: _isScanning ? Colors.blue : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Focus is on scanner - scan any product barcode',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImeiEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product info
        if (_scannedProduct != null) ...[
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scannedProduct!.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Barcode: ${_scannedProduct!.barcode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        const Text(
          'Step 2: Enter IMEI Number(s)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          widget.requireImei
              ? '15-digit IMEI required for mobile phones'
              : 'Enter IMEI if available (optional for accessories)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // IMEI fields
        ...List.generate(_imeiControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _imeiControllers[index],
                    focusNode: _imeiFocusNodes[index],
                    onChanged: (v) => _onImeiChanged(index, v),
                    decoration: InputDecoration(
                      labelText: 'IMEI ${index + 1}',
                      hintText: '123456789012345',
                      border: const OutlineInputBorder(),
                      counterText: '${_capturedImeis[index].length}/15',
                      errorText: _capturedImeis[index].length == 15 &&
                              !_isValidImei(_capturedImeis[index])
                          ? 'Invalid IMEI checksum'
                          : null,
                      suffixIcon: _capturedImeis[index].length == 15 &&
                              _isValidImei(_capturedImeis[index])
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                if (_imeiControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeImeiField(index),
                  ),
                ],
              ],
            ),
          );
        }),

        // Add more IMEI button
        if (widget.allowMultipleImeis)
          TextButton.icon(
            onPressed: _addImeiField,
            icon: const Icon(Icons.add),
            label: const Text('Add Another IMEI'),
          ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final validImeis = _capturedImeis.where((i) => _isValidImei(i)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Review & Confirm',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        
        // Product summary
        if (_scannedProduct != null) ...[
          _buildSummaryRow('Product', _scannedProduct!.displayTitle),
          _buildSummaryRow('Price', '₹${_scannedProduct!.salePrice.toStringAsFixed(2)}'),
          _buildSummaryRow('Warranty', '${_scannedProduct!.warrantyMonths ?? 12} months'),
        ],
        
        const Divider(height: 24),
        
        // IMEI summary
        const Text(
          'Captured IMEI(s):',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...validImeis.map((imei) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                imei,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        )),
        
        if (validImeis.isEmpty && !widget.requireImei)
          const Text(
            'No IMEI captured (accessory without IMEI)',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
        if (_currentStep == 1 || _currentStep == 2)
          FilledButton(
            onPressed: _validateAndAdvance,
            child: const Text('Continue'),
          ),
        if (_currentStep == 3)
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
// MOBILE PRODUCT SCAN RESULT
// ============================================================================

class MobileProductScan {
  final ScannedProduct product;
  final List<String> imeis;
  final int warrantyMonths;
  final DateTime scannedAt;

  MobileProductScan({
    required this.product,
    required this.imeis,
    required this.warrantyMonths,
    required this.scannedAt,
  });
}
