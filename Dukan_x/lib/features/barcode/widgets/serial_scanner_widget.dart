// ignore_for_file: empty_catches
// ============================================================================
// SERIAL NUMBER SCANNER WIDGET - COMPUTER SHOP
// ============================================================================
// Specialized scanner for computers and electronics
// Captures both product barcode and serial numbers
//
// Features:
// - Dual scan: Product barcode + Serial Number
// - No checksum validation (unlike IMEI)
// - Warranty date picker
// - Multi-serial support for bulk sales
// - Duplicate serial detection
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

import '../models/barcode_scan_result.dart';
import '../services/barcode_lookup_service.dart';

// ============================================================================
// SERIAL SCANNER WIDGET
// ============================================================================

class SerialScannerWidget extends ConsumerStatefulWidget {
  /// Callback when product + serial(s) are captured
  final void Function(ComputerProductScan result)? onComplete;
  
  /// Callback for cancellation
  final VoidCallback? onCancel;
  
  /// Whether serial is required
  final bool requireSerial;
  
  /// Allow multiple serials
  final bool allowMultipleSerials;

  const SerialScannerWidget({
    super.key,
    this.onComplete,
    this.onCancel,
    this.requireSerial = true,
    this.allowMultipleSerials = true,
  });

  @override
  ConsumerState<SerialScannerWidget> createState() =>
      _SerialScannerWidgetState();
}

class _SerialScannerWidgetState extends ConsumerState<SerialScannerWidget> {
  // Services
  final BarcodeLookupService _lookupService = BarcodeLookupService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  final List<TextEditingController> _serialControllers = [];
  final List<FocusNode> _serialFocusNodes = [];
  final List<String> _capturedSerials = [];
  
  // Scanner
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  Timer? _debounceTimer;
  
  // Product & Warranty
  ScannedProduct? _scannedProduct;
  DateTime? _warrantyEndDate;
  bool _isScanning = false;
  String? _errorMessage;

  // Steps
  int _currentStep = 0; // 0: Product, 1: Serial, 2: Warranty, 3: Confirm

  @override
  void initState() {
    super.initState();
    _lookupService.initialize();
    _addSerialField();
    
    // Default warranty: 1 year
    _warrantyEndDate = DateTime.now().add(const Duration(days: 365));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    for (var c in _serialControllers) {
      c.dispose();
    }
    for (var f in _serialFocusNodes) {
      f.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addSerialField() {
    setState(() {
      _serialControllers.add(TextEditingController());
      _serialFocusNodes.add(FocusNode());
      _capturedSerials.add('');
    });
  }

  void _removeSerialField(int index) {
    if (_serialControllers.length <= 1) return;
    setState(() {
      _serialControllers[index].dispose();
      _serialFocusNodes[index].dispose();
      _serialControllers.removeAt(index);
      _serialFocusNodes.removeAt(index);
      _capturedSerials.removeAt(index);
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
      final result = await _lookupService.lookupBarcode(barcode: barcode);

      if (result.success && result.product != null) {
        setState(() {
          _scannedProduct = result.product;
          _currentStep = 1;
          _isScanning = false;
        });
        _playSuccessSound();
        
        if (_serialFocusNodes.isNotEmpty) {
          _serialFocusNodes.first.requestFocus();
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
  // SERIAL VALIDATION
  // ==========================================================================

  bool _isValidSerial(String serial) {
    // Serials can be alphanumeric, no strict format
    // Just check min/max length and not empty
    if (serial.trim().isEmpty) return false;
    if (serial.length < 5) return false; // Too short to be a serial
    if (serial.length > 50) return false; // Too long
    return true;
  }

  void _onSerialChanged(int index, String value) {
    setState(() {
      _capturedSerials[index] = value.trim().toUpperCase();
      _errorMessage = null;
    });
  }

  void _validateAndAdvance() {
    final validSerials = _capturedSerials.where((s) => _isValidSerial(s)).toList();
    
    if (validSerials.isEmpty && widget.requireSerial) {
      setState(() {
        _errorMessage = 'Please enter at least one valid serial number';
      });
      _playErrorSound();
      return;
    }

    // Check for duplicates
    final uniqueSerials = validSerials.toSet();
    if (uniqueSerials.length != validSerials.length) {
      setState(() {
        _errorMessage = 'Duplicate serial number detected';
      });
      _playErrorSound();
      return;
    }

    setState(() {
      _currentStep = 2; // Move to warranty step
    });
    _playSuccessSound();
  }

  Future<void> _selectWarrantyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyEndDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    
    if (picked != null) {
      setState(() {
        _warrantyEndDate = picked;
      });
    }
  }

  void _onComplete() {
    if (_scannedProduct == null) return;

    final validSerials = _capturedSerials.where((s) => _isValidSerial(s)).toList();
    
    final result = ComputerProductScan(
      product: _scannedProduct!,
      serials: validSerials,
      warrantyEndDate: _warrantyEndDate ?? DateTime.now().add(const Duration(days: 365)),
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
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.computer, color: Colors.purple, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Computer Product Scan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scan product then enter serial number',
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
        _buildStepCircle(1, 'Serial', _currentStep >= 1),
        _buildStepLine(_currentStep >= 2),
        _buildStepCircle(2, 'Warranty', _currentStep >= 2),
        _buildStepLine(_currentStep >= 3),
        _buildStepCircle(3, 'Confirm', _currentStep >= 3),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, bool active) {
    IconData icon;
    switch (step) {
      case 0:
        icon = Icons.qr_code;
        break;
      case 1:
        icon = Icons.confirmation_number;
        break;
      case 2:
        icon = Icons.calendar_today;
        break;
      default:
        icon = Icons.check;
    }
    
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.purple : Colors.grey.shade300,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.grey, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Colors.purple : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool active) {
    return Container(
      width: 24,
      height: 2,
      color: active ? Colors.purple : Colors.grey.shade300,
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
        return _buildSerialEntryStep();
      case 2:
        return _buildWarrantyStep();
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
            color: Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                _isScanning ? Icons.radar : Icons.qr_code_scanner,
                size: 64,
                color: _isScanning ? Colors.purple : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _isScanning ? 'Looking up product...' : 'Ready to scan',
                style: TextStyle(
                  fontSize: 16,
                  color: _isScanning ? Colors.purple : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSerialEntryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        _scannedProduct!.sku ?? 'SKU: N/A',
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
          'Step 2: Enter Serial Number(s)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          widget.requireSerial
              ? 'Serial number required'
              : 'Enter serial if available (optional)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        ...List.generate(_serialControllers.length, (index) {
          final isValid = _isValidSerial(_capturedSerials[index]);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serialControllers[index],
                    focusNode: _serialFocusNodes[index],
                    onChanged: (v) => _onSerialChanged(index, v),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Serial ${index + 1}',
                      hintText: 'ABC123456789',
                      border: const OutlineInputBorder(),
                      errorText: _capturedSerials[index].isNotEmpty && !isValid
                          ? 'Serial must be 5-50 characters'
                          : null,
                      suffixIcon: isValid
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  ),
                ),
                if (_serialControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeSerialField(index),
                  ),
                ],
              ],
            ),
          );
        }),

        if (widget.allowMultipleSerials)
          TextButton.icon(
            onPressed: _addSerialField,
            icon: const Icon(Icons.add),
            label: const Text('Add Another Serial'),
          ),
      ],
    );
  }

  Widget _buildWarrantyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 3: Set Warranty End Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        
        ListTile(
          leading: const Icon(Icons.calendar_today, color: Colors.purple),
          title: const Text('Warranty Expires On'),
          subtitle: Text(
            _warrantyEndDate != null
                ? DateFormat('MMMM dd, yyyy').format(_warrantyEndDate!)
                : 'Not set',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: FilledButton(
            onPressed: _selectWarrantyDate,
            child: const Text('Change'),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Quick warranty options
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('1 Year'),
              onPressed: () => setState(() {
                _warrantyEndDate = DateTime.now().add(const Duration(days: 365));
              }),
            ),
            ActionChip(
              label: const Text('2 Years'),
              onPressed: () => setState(() {
                _warrantyEndDate = DateTime.now().add(const Duration(days: 730));
              }),
            ),
            ActionChip(
              label: const Text('3 Years'),
              onPressed: () => setState(() {
                _warrantyEndDate = DateTime.now().add(const Duration(days: 1095));
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final validSerials = _capturedSerials.where((s) => _isValidSerial(s)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Review & Confirm',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        
        if (_scannedProduct != null) ...[
          _buildSummaryRow('Product', _scannedProduct!.displayTitle),
          _buildSummaryRow('Price', '₹${_scannedProduct!.salePrice.toStringAsFixed(2)}'),
        ],
        
        const Divider(height: 24),
        
        const Text(
          'Captured Serial(s):',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...validSerials.map((serial) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                serial,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        )),
        
        if (validSerials.isEmpty && !widget.requireSerial)
          const Text(
            'No serial captured',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        
        const SizedBox(height: 16),
        _buildSummaryRow(
          'Warranty Until',
          _warrantyEndDate != null
              ? DateFormat('MMM dd, yyyy').format(_warrantyEndDate!)
              : 'Not set',
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
            width: 120,
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
        if (_currentStep == 1)
          FilledButton(
            onPressed: _validateAndAdvance,
            child: const Text('Continue'),
          ),
        if (_currentStep == 2)
          FilledButton(
            onPressed: () => setState(() => _currentStep = 3),
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
// COMPUTER PRODUCT SCAN RESULT
// ============================================================================

class ComputerProductScan {
  final ScannedProduct product;
  final List<String> serials;
  final DateTime warrantyEndDate;
  final DateTime scannedAt;

  ComputerProductScan({
    required this.product,
    required this.serials,
    required this.warrantyEndDate,
    required this.scannedAt,
  });
}
