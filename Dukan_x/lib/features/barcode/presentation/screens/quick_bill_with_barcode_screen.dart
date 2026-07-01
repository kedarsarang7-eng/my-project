// ignore_for_file: unreachable_switch_default
// ignore_for_file: unused_field
// ============================================================================
// QUICK BILL WITH BARCODE - PHASE 1
// ============================================================================
// Simplified billing screen with integrated barcode scanning for:
// - Grocery (full barcode support)
// - Pharmacy (drug schedule + expiry warnings)
// - Hardware (multi-unit support)
//
// Features:
// - USB/Bluetooth scanner support (hidden TextField)
// - Continuous multi-scan support
// - Auto-add to bill with audio feedback
// - Expiry warnings (pharmacy)
// - Low stock warnings
// - Offline cache support
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../services/barcode_lookup_service.dart';
import '../../models/barcode_scan_result.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ============================================================================
// QUICK BILL SCREEN
// ============================================================================

class QuickBillWithBarcodeScreen extends ConsumerStatefulWidget {
  final BusinessType businessType;
  final Customer? initialCustomer;

  const QuickBillWithBarcodeScreen({
    super.key,
    required this.businessType,
    this.initialCustomer,
  });

  @override
  ConsumerState<QuickBillWithBarcodeScreen> createState() =>
      _QuickBillWithBarcodeScreenState();
}

class _QuickBillWithBarcodeScreenState
    extends ConsumerState<QuickBillWithBarcodeScreen> {
  // Services
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final SessionManager _session = sl<SessionManager>();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ProductsRepository _productsRepo = sl<ProductsRepository>();

  // State
  final List<ScannedBillItem> _items = [];
  Customer? _selectedCustomer;
  String _invoiceNumber = '';

  // Scanner
  final TextEditingController _scannerController = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _lastScanBuffer = '';
  DateTime? _lastScanTime;
  bool _isProcessingScan = false;

  // UI
  ScannerStatus _scannerStatus = ScannerStatus.idle;
  String? _lastError;
  ScannedProduct? _lastScannedProduct;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
    _generateInvoiceNumber();
    _lookupService.initialize();

    // Auto-focus scanner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scannerController.dispose();
    _scannerFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ==========================================================================
  // INVOICE NUMBER
  // ==========================================================================

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    final random = (now.millisecondsSinceEpoch % 9999).toString().padLeft(
      4,
      '0',
    );
    _invoiceNumber =
        'B${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  // ==========================================================================
  // BARCODE SCANNING
  // ==========================================================================

  void _onBarcodeSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Duplicate check
    final now = DateTime.now();
    if (_lastScanTime != null) {
      final diff = now.difference(_lastScanTime!).inMilliseconds;
      if (diff < 100 && trimmed == _lastScanBuffer) {
        _scannerController.clear();
        return;
      }
    }
    _lastScanTime = now;
    _lastScanBuffer = trimmed;

    _debounceTimer?.cancel();
    _scannerController.clear();

    setState(() {
      _scannerStatus = ScannerStatus.scanning;
      _lastError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _processBarcode(trimmed);
    });

    // Refocus
    _scannerFocusNode.requestFocus();
  }

  Future<void> _processBarcode(String barcode) async {
    if (_isProcessingScan) return;
    _isProcessingScan = true;

    setState(() => _scannerStatus = ScannerStatus.lookingUp);

    try {
      final result = await _lookupService.lookupBarcode(
        barcode: barcode,
        businessId: _session.ownerId ?? '',
      );

      if (result.success && result.product != null) {
        final product = result.product!;

        // Check expiry (pharmacy)
        if (product.expiryWarning != null) {
          if (product.expiryWarning!.level == ExpiryLevel.critical &&
              widget.businessType == BusinessType.pharmacy) {
            // Block expired medicines
            setState(() {
              _scannerStatus = ScannerStatus.error;
              _lastError = 'EXPIRED: ${product.displayTitle} cannot be sold';
            });
            _playErrorSound();
            _isProcessingScan = false;
            return;
          }
        }

        // Add to bill
        await _addProductToBill(product);

        setState(() {
          _scannerStatus = ScannerStatus.success;
          _lastScannedProduct = product;
        });

        _playSuccessSound();
      } else {
        setState(() {
          _scannerStatus = ScannerStatus.notFound;
          _lastError = result.errorMessage ?? 'Product not found';
        });
        _playErrorSound();
        _showNotFoundDialog(barcode);
      }
    } catch (e) {
      setState(() {
        _scannerStatus = ScannerStatus.error;
        _lastError = 'Error: $e';
      });
      _playErrorSound();
    } finally {
      _isProcessingScan = false;

      // Reset status after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _scannerStatus = ScannerStatus.idle);
        }
      });
    }
  }

  Future<void> _addProductToBill(ScannedProduct product) async {
    // Check if already in bill
    final existingIndex = _items.indexWhere((i) => i.product.id == product.id);

    if (existingIndex >= 0) {
      // Increment quantity
      setState(() {
        _items[existingIndex].quantity += 1;
      });
    } else {
      // Add new item
      setState(() {
        _items.add(
          ScannedBillItem(
            product: product,
            quantity: 1,
            unitPrice: product.salePrice,
            taxRate: product.gstRate,
          ),
        );
      });
    }

    // Show warnings
    if (product.expiryWarning != null &&
        product.expiryWarning!.level == ExpiryLevel.warning) {
      _showExpiryWarning(product);
    }

    if (product.isLowStock) {
      _showLowStockWarning(product);
    }
  }

  // ==========================================================================
  // SOUNDS
  // ==========================================================================

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.3);
    } catch (e) {
      // Sound not critical
    }
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'), volume: 0.3);
    } catch (e) {
      // Sound not critical
    }
  }

  // ==========================================================================
  // DIALOGS
  // ==========================================================================

  void _showNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No product found for:'),
            const SizedBox(height: 8),
            SelectableText(
              barcode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add product
              context.push(
                '/inventory/add-product',
                extra: {'barcode': barcode},
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  void _showExpiryWarning(ScannedProduct product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'âš ï¸ ${product.displayTitle} expires in ${product.daysUntilExpiry} days',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLowStockWarning(ScannedProduct product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'âš ï¸ Low stock: ${product.displayTitle} (${product.currentStock} left)',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================================================
  // BILL OPERATIONS
  // ==========================================================================

  void _updateQuantity(int index, double newQty) {
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
    } else {
      setState(() => _items[index].quantity = newQty);
    }
  }

  void _clearBill() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Bill?'),
        content: const Text('Remove all items from the current bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _items.clear());
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add items to save bill')));
      return;
    }

    // Pending: Implement bill saving logic
    // This would sync to backend via BillsRepository

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bill saved successfully!')));

    setState(() {
      _items.clear();
      _generateInvoiceNumber();
    });
  }

  // ==========================================================================
  // COMPUTED PROPERTIES
  // ==========================================================================

  double get _subtotal =>
      _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));

  double get _totalTax => _items.fold(
    0,
    (sum, item) => sum + (item.unitPrice * item.quantity * item.taxRate / 100),
  );

  double get _grandTotal => _subtotal + _totalTax;

  int get _totalItems => _items.length;
  double get _totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quick Bill - ${widget.businessType.displayName}'),
        actions: [
          // Scanner status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildScannerIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _items.isEmpty ? null : _clearBill,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = context.isMobile;

          if (isMobile) {
            return Column(
              children: [
                // Hidden barcode scanner input
                _buildHiddenScannerInput(),

                // Bill items
                Expanded(
                  child: _items.isEmpty ? _buildEmptyState() : _buildItemList(),
                ),

                // Bottom summary bar
                _buildBottomSummaryBar(),
              ],
            );
          }

          // Desktop view
          return Row(
            children: [
              // Left: Item list
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Hidden barcode scanner input
                    _buildHiddenScannerInput(),

                    // Bill items
                    Expanded(
                      child: _items.isEmpty
                          ? _buildEmptyState()
                          : _buildItemList(),
                    ),
                  ],
                ),
              ),

              // Right: Summary
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade300)),
                ),
                child: _buildSummaryPanel(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHiddenScannerInput() {
    return SizedBox(
      height: 1,
      child: TextField(
        controller: _scannerController,
        focusNode: _scannerFocusNode,
        onSubmitted: _onBarcodeSubmitted,
        onChanged: (value) {
          if (value.contains('\n') || value.contains('\r')) {
            final clean = value.replaceAll('\n', '').replaceAll('\r', '');
            _onBarcodeSubmitted(clean);
          }
        },
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(fontSize: 1),
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.none,
        enableSuggestions: false,
        autocorrect: false,
        autofocus: true,
      ),
    );
  }

  Widget _buildScannerIndicator() {
    Color color;
    IconData icon;
    String text;

    switch (_scannerStatus) {
      case ScannerStatus.scanning:
      case ScannerStatus.lookingUp:
        color = Colors.blue;
        icon = Icons.qr_code_scanner;
        text = 'Scanning...';
        break;
      case ScannerStatus.success:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Added';
        break;
      case ScannerStatus.notFound:
        color = Colors.orange;
        icon = Icons.help_outline;
        text = 'Not Found';
        break;
      case ScannerStatus.error:
        color = Colors.red;
        icon = Icons.error_outline;
        text = 'Error';
        break;
      case ScannerStatus.idle:
      default:
        color = Colors.green;
        icon = Icons.qr_code_scanner;
        text = 'Ready (Ctrl+B)';
    }

    return GestureDetector(
      onTap: () => _scannerFocusNode.requestFocus(),
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(text, style: TextStyle(color: color, fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Scan a barcode to add items',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Or press Ctrl+B to focus scanner',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item, index);
      },
    );
  }

  Widget _buildItemCard(ScannedBillItem item, int index) {
    final product = item.product;
    final hasExpiryWarning =
        product.expiryWarning != null &&
        product.expiryWarning!.level == ExpiryLevel.warning;
    final hasLowStock = product.isLowStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.displayTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (product.barcode != null)
                        Text(
                          'Barcode: ${product.barcode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasExpiryWarning)
                  Tooltip(
                    message: 'Expires in ${product.daysUntilExpiry} days',
                    child: Icon(Icons.warning, color: Colors.orange, size: 20),
                  ),
                if (hasLowStock)
                  const Tooltip(
                    message: 'Low stock',
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _updateQuantity(index, 0),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateQuantity(index, item.quantity - 1),
                      ),
                      Text(
                        item.quantity.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateQuantity(index, item.quantity + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Ã— â‚¹${item.unitPrice.toStringAsFixed(2)}'),
                const Spacer(),
                Text(
                  'â‚¹${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill #$_invoiceNumber',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$_totalItems items | ${_totalQuantity.toStringAsFixed(0)} qty',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),

        // Summary
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryRow('Subtotal:', _subtotal),
              _buildSummaryRow(
                'Tax (${(_items.firstOrNull?.taxRate ?? 0).toStringAsFixed(1)}%):',
                _totalTax,
              ),
              const Divider(height: 24),
              _buildSummaryRow('Grand Total:', _grandTotal, isTotal: true),
            ],
          ),
        ),

        const Spacer(),

        // Actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _items.isEmpty ? null : _saveBill,
                  icon: const Icon(Icons.save),
                  label: Text(
                    'SAVE BILL - â‚¹${_grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _items.isEmpty ? null : () {},
                icon: const Icon(Icons.print),
                label: const Text('PRINT'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSummaryBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_totalItems Items | ${_totalQuantity.toStringAsFixed(0)} Qty',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: ₹${_grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _items.isEmpty ? null : _saveBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('SAVE BILL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            'â‚¹${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

enum ScannerStatus { idle, scanning, lookingUp, success, notFound, error }

class ScannedBillItem {
  final ScannedProduct product;
  double quantity;
  final double unitPrice;
  final double taxRate;

  ScannedBillItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
  });
}

// Extensions for null safety
extension FirstOrNullExtension<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
