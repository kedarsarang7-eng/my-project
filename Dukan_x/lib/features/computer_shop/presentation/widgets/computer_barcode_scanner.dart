// ============================================================================
// Computer Shop — Barcode Scanner Widget
// ============================================================================
// USB/Bluetooth barcode scanner support for:
// - Scanning serial numbers on devices
// - Scanning product barcodes for parts
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Barcode scanner widget for Computer Shop
/// Uses hidden TextField to capture USB/Bluetooth scanner input
class ComputerBarcodeScanner extends StatefulWidget {
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onBarcodeScanned;
  final VoidCallback? onScanButtonPressed;
  final bool autoFocus;
  final Duration debounceDuration;

  const ComputerBarcodeScanner({
    super.key,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.onBarcodeScanned,
    this.onScanButtonPressed,
    this.autoFocus = true,
    this.debounceDuration = const Duration(milliseconds: 50),
  });

  @override
  State<ComputerBarcodeScanner> createState() => _ComputerBarcodeScannerState();
}

class _ComputerBarcodeScannerState extends State<ComputerBarcodeScanner> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  DateTime _lastScanTime = DateTime.now();
  String _buffer = '';

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    final now = DateTime.now();
    final timeSinceLastScan = now.difference(_lastScanTime);

    // Reset buffer if too much time has passed
    if (timeSinceLastScan > widget.debounceDuration) {
      _buffer = '';
    }

    _lastScanTime = now;

    if (event is KeyDownEvent) {
      final character = event.character;
      if (character != null) {
        if (character == '\n' || character == '\r') {
          // Enter key - barcode complete
          if (_buffer.isNotEmpty) {
            _processBarcode(_buffer);
            _buffer = '';
          }
        } else {
          _buffer += character;
        }
      }
    }
  }

  void _processBarcode(String barcode) {
    _controller.text = barcode;
    if (widget.onBarcodeScanned != null) {
      widget.onBarcodeScanned!(barcode);
    }
    
    // Show success feedback
    HapticFeedback.lightImpact();
    
    // Refocus for next scan
    _focusNode.requestFocus();
    _controller.clear();
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => _ManualEntryDialog(
        onSubmit: (value) {
          Navigator.pop(context);
          _processBarcode(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      autofocus: widget.autoFocus,
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.labelText ?? 'Scan Barcode',
          hintText: widget.hintText ?? 'Use USB scanner or type manually',
          prefixIcon: Icon(widget.prefixIcon ?? Icons.qr_code_scanner),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scan button
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  _focusNode.requestFocus();
                  if (widget.onScanButtonPressed != null) {
                    widget.onScanButtonPressed!();
                  }
                },
                tooltip: 'Focus scanner',
              ),
              // Manual entry button
              IconButton(
                icon: const Icon(Icons.keyboard),
                onPressed: _showManualEntryDialog,
                tooltip: 'Manual entry',
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        readOnly: true, // Scanner input only
        showCursor: false,
        enableInteractiveSelection: false,
      ),
    );
  }
}

/// Manual entry dialog for when scanner is not available
class _ManualEntryDialog extends StatelessWidget {
  final ValueChanged<String> onSubmit;

  const _ManualEntryDialog({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Manual Entry'),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Enter barcode/serial',
          hintText: 'Type the code manually',
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            onSubmit(value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              onSubmit(controller.text);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// Serial number scanner specifically for device intake
class SerialNumberScanner extends StatelessWidget {
  final ValueChanged<String> onSerialScanned;
  final String? initialSerial;

  const SerialNumberScanner({
    super.key,
    required this.onSerialScanned,
    this.initialSerial,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Device Serial Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        ComputerBarcodeScanner(
          labelText: 'Scan Serial Number',
          hintText: 'Scan device serial barcode',
          prefixIcon: Icons.confirmation_number,
          onBarcodeScanned: onSerialScanned,
        ),
        const SizedBox(height: 8),
        Text(
          'Scan the serial number sticker on the device',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Product barcode scanner for parts lookup
class ProductBarcodeScanner extends StatelessWidget {
  final ValueChanged<String> onProductScanned;
  final String label;

  const ProductBarcodeScanner({
    super.key,
    required this.onProductScanned,
    this.label = 'Scan Product Barcode',
  });

  @override
  Widget build(BuildContext context) {
    return ComputerBarcodeScanner(
      labelText: label,
      hintText: 'Scan product barcode to lookup',
      prefixIcon: Icons.inventory_2,
      onBarcodeScanned: onProductScanned,
    );
  }
}

/// Barcode scan result card showing scanned product info
class BarcodeScanResultCard extends StatelessWidget {
  final String barcode;
  final String? productName;
  final double? price;
  final int? stock;
  final VoidCallback? onAddToJob;
  final VoidCallback? onViewDetails;

  const BarcodeScanResultCard({
    super.key,
    required this.barcode,
    this.productName,
    this.price,
    this.stock,
    this.onAddToJob,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol);
    final bool found = productName != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: found ? Colors.green.shade300 : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: found
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    found ? Icons.check_circle : Icons.warning,
                    color: found ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        found ? 'Product Found' : 'Product Not Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: found ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        'Barcode: $barcode',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (found) ...[
              const Divider(height: 24),
              Text(
                productName!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (price != null)
                    Text(
                      currencyFormat.format(price),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  if (stock != null) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stock! > 0
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${stock!} in stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: stock! > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAddToJob,
                      icon: const Icon(Icons.add),
                      label: const Text('Add to Job'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Navigate to create product
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Product'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


