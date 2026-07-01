// ============================================================================
// BARCODE LABEL PRINTER WIDGET
// ============================================================================
// Generates and prints barcode labels for products. Supports:
// - Single product labels
// - Batch label printing (multiple products)
// - Multiple label formats (standard shelf, price tag, pharmacy)
// - USB thermal printer output (ESC/POS, ZPL)
// - PDF fallback for regular printers
//
// Business types: All with useBarcodeScanner capability
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart' as bc;

import '../../../core/di/service_locator.dart';
import '../models/barcode_scan_result.dart';
import '../services/barcode_lookup_service.dart';

// ============================================================================
// LABEL FORMAT ENUM
// ============================================================================

enum LabelFormat {
  shelfLabel,      // 50mm x 30mm - name, price, barcode
  priceTag,        // 40mm x 25mm - compact price + barcode
  pharmacyLabel,   // 60mm x 40mm - name, batch, expiry, MRP, barcode
  jewelryTag,      // 30mm x 50mm - vertical tag with price, purity
  fullProduct,     // 70mm x 40mm - full details including HSN
}

extension LabelFormatInfo on LabelFormat {
  String get displayName {
    switch (this) {
      case LabelFormat.shelfLabel:
        return 'Shelf Label (50Ã—30mm)';
      case LabelFormat.priceTag:
        return 'Price Tag (40Ã—25mm)';
      case LabelFormat.pharmacyLabel:
        return 'Pharmacy Label (60Ã—40mm)';
      case LabelFormat.jewelryTag:
        return 'Jewelry Tag (30Ã—50mm)';
      case LabelFormat.fullProduct:
        return 'Full Product (70Ã—40mm)';
    }
  }

  double get widthMm {
    switch (this) {
      case LabelFormat.shelfLabel:
        return 50;
      case LabelFormat.priceTag:
        return 40;
      case LabelFormat.pharmacyLabel:
        return 60;
      case LabelFormat.jewelryTag:
        return 30;
      case LabelFormat.fullProduct:
        return 70;
    }
  }

  double get heightMm {
    switch (this) {
      case LabelFormat.shelfLabel:
        return 30;
      case LabelFormat.priceTag:
        return 25;
      case LabelFormat.pharmacyLabel:
        return 40;
      case LabelFormat.jewelryTag:
        return 50;
      case LabelFormat.fullProduct:
        return 40;
    }
  }
}

// ============================================================================
// LABEL DATA MODEL
// ============================================================================

class BarcodeLabelData {
  final String productName;
  final String barcode;
  final double price;
  final double? mrp;
  final String? unit;
  final String? hsnCode;
  final String? batchNumber;
  final DateTime? expiryDate;
  final String? purity;
  final int quantity; // Number of labels to print

  BarcodeLabelData({
    required this.productName,
    required this.barcode,
    required this.price,
    this.mrp,
    this.unit,
    this.hsnCode,
    this.batchNumber,
    this.expiryDate,
    this.purity,
    this.quantity = 1,
  });

  factory BarcodeLabelData.fromScannedProduct(ScannedProduct product, {int qty = 1}) {
    return BarcodeLabelData(
      productName: product.displayTitle,
      barcode: product.barcode ?? product.sku ?? '',
      price: product.salePrice,
      mrp: product.mrp,
      unit: product.unit,
      hsnCode: product.hsnCode,
      batchNumber: product.batchNumber,
      expiryDate: product.expiryDate,
      purity: product.purity,
      quantity: qty,
    );
  }
}

// ============================================================================
// LABEL PDF GENERATOR
// ============================================================================

class BarcodeLabelGenerator {
  const BarcodeLabelGenerator._();

  /// Generate PDF with barcode labels
  static Future<Uint8List> generateLabelsPdf({
    required List<BarcodeLabelData> labels,
    required LabelFormat format,
  }) async {
    final pdf = pw.Document();

    final pageWidth = format.widthMm * PdfPageFormat.mm;
    final pageHeight = format.heightMm * PdfPageFormat.mm;

    for (final label in labels) {
      for (int i = 0; i < label.quantity; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidth, pageHeight),
            margin: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
            build: (context) => _buildLabel(label, format),
          ),
        );
      }
    }

    return pdf.save();
  }

  static pw.Widget _buildLabel(BarcodeLabelData label, LabelFormat format) {
    switch (format) {
      case LabelFormat.shelfLabel:
        return _buildShelfLabel(label);
      case LabelFormat.priceTag:
        return _buildPriceTag(label);
      case LabelFormat.pharmacyLabel:
        return _buildPharmacyLabel(label);
      case LabelFormat.jewelryTag:
        return _buildJewelryTag(label);
      case LabelFormat.fullProduct:
        return _buildFullProductLabel(label);
    }
  }

  static pw.Widget _buildShelfLabel(BarcodeLabelData label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label.productName,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          '\u20B9${label.price.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        if (label.barcode.isNotEmpty)
          pw.BarcodeWidget(
            barcode: _getBarcodeType(label.barcode),
            data: label.barcode,
            height: 12 * PdfPageFormat.mm,
            drawText: true,
            textStyle: const pw.TextStyle(fontSize: 6),
          ),
      ],
    );
  }

  static pw.Widget _buildPriceTag(BarcodeLabelData label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          '\u20B9${label.price.toStringAsFixed(0)}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        if (label.barcode.isNotEmpty)
          pw.BarcodeWidget(
            barcode: _getBarcodeType(label.barcode),
            data: label.barcode,
            height: 8 * PdfPageFormat.mm,
            drawText: true,
            textStyle: const pw.TextStyle(fontSize: 5),
          ),
      ],
    );
  }

  static pw.Widget _buildPharmacyLabel(BarcodeLabelData label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.productName,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          maxLines: 2,
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (label.batchNumber != null)
              pw.Text('B: ${label.batchNumber}', style: const pw.TextStyle(fontSize: 6)),
            if (label.expiryDate != null)
              pw.Text(
                'Exp: ${label.expiryDate!.month}/${label.expiryDate!.year}',
                style: const pw.TextStyle(fontSize: 6),
              ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MRP: \u20B9${(label.mrp ?? label.price).toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            if (label.unit != null) pw.Text(label.unit!, style: const pw.TextStyle(fontSize: 6)),
          ],
        ),
        pw.SizedBox(height: 3),
        if (label.barcode.isNotEmpty)
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: _getBarcodeType(label.barcode),
              data: label.barcode,
              height: 10 * PdfPageFormat.mm,
              drawText: true,
              textStyle: const pw.TextStyle(fontSize: 5),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildJewelryTag(BarcodeLabelData label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        if (label.purity != null)
          pw.Text(label.purity!, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(
          '\u20B9${label.price.toStringAsFixed(0)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        if (label.barcode.isNotEmpty)
          pw.BarcodeWidget(
            barcode: _getBarcodeType(label.barcode),
            data: label.barcode,
            height: 15 * PdfPageFormat.mm,
            drawText: true,
            textStyle: const pw.TextStyle(fontSize: 5),
          ),
        pw.SizedBox(height: 2),
        pw.Text(
          label.productName,
          style: const pw.TextStyle(fontSize: 5),
          maxLines: 1,
        ),
      ],
    );
  }

  static pw.Widget _buildFullProductLabel(BarcodeLabelData label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.productName,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          maxLines: 2,
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MRP: \u20B9${(label.mrp ?? label.price).toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            if (label.hsnCode != null)
              pw.Text('HSN: ${label.hsnCode}', style: const pw.TextStyle(fontSize: 6)),
          ],
        ),
        if (label.batchNumber != null || label.expiryDate != null) ...[
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (label.batchNumber != null)
                pw.Text('Batch: ${label.batchNumber}', style: const pw.TextStyle(fontSize: 6)),
              if (label.expiryDate != null)
                pw.Text(
                  'Exp: ${label.expiryDate!.month}/${label.expiryDate!.year}',
                  style: const pw.TextStyle(fontSize: 6),
                ),
            ],
          ),
        ],
        pw.Spacer(),
        if (label.barcode.isNotEmpty)
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: _getBarcodeType(label.barcode),
              data: label.barcode,
              height: 12 * PdfPageFormat.mm,
              drawText: true,
              textStyle: const pw.TextStyle(fontSize: 5),
            ),
          ),
      ],
    );
  }

  /// Determine barcode type from data
  static bc.Barcode _getBarcodeType(String data) {
    if (RegExp(r'^\d{13}$').hasMatch(data)) return bc.Barcode.ean13();
    if (RegExp(r'^\d{8}$').hasMatch(data)) return bc.Barcode.ean8();
    if (RegExp(r'^\d{12}$').hasMatch(data)) return bc.Barcode.upcA();
    return bc.Barcode.code128();
  }
}

// ============================================================================
// LABEL PRINTER DIALOG WIDGET
// ============================================================================

class BarcodeLabelPrinterDialog extends StatefulWidget {
  final List<ScannedProduct>? products;
  final ScannedProduct? singleProduct;

  const BarcodeLabelPrinterDialog({
    super.key,
    this.products,
    this.singleProduct,
  });

  @override
  State<BarcodeLabelPrinterDialog> createState() => _BarcodeLabelPrinterDialogState();
}

class _BarcodeLabelPrinterDialogState extends State<BarcodeLabelPrinterDialog> {
  LabelFormat _selectedFormat = LabelFormat.shelfLabel;
  final Map<String, int> _quantities = {};
  bool _isPrinting = false;

  List<ScannedProduct> get _allProducts =>
      widget.products ?? (widget.singleProduct != null ? [widget.singleProduct!] : []);

  @override
  void initState() {
    super.initState();
    for (final p in _allProducts) {
      _quantities[p.id] = 1;
    }
  }

  int get _totalLabels =>
      _quantities.values.fold(0, (sum, q) => sum + q);

  Future<void> _print() async {
    setState(() => _isPrinting = true);

    try {
      final labels = _allProducts
          .map((p) => BarcodeLabelData.fromScannedProduct(
                p,
                qty: _quantities[p.id] ?? 1,
              ))
          .where((l) => l.barcode.isNotEmpty)
          .toList();

      if (labels.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid barcodes to print')),
          );
        }
        return;
      }

      final pdfBytes = await BarcodeLabelGenerator.generateLabelsPdf(
        labels: labels,
        format: _selectedFormat,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Barcode Labels',
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.print, color: Colors.blue),
          SizedBox(width: 8),
          Text('Print Barcode Labels'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selector
            const Text('Label Format:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<LabelFormat>(
              value: _selectedFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: LabelFormat.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.displayName)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFormat = val);
              },
            ),
            const SizedBox(height: 16),

            // Product list with quantity
            const Text('Products:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allProducts.length,
                itemBuilder: (context, index) {
                  final product = _allProducts[index];
                  final qty = _quantities[product.id] ?? 1;
                  return ListTile(
                    dense: true,
                    title: Text(
                      product.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      product.barcode ?? 'No barcode',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: qty > 1
                              ? () => setState(() => _quantities[product.id] = qty - 1)
                              : null,
                        ),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () =>
                              setState(() => _quantities[product.id] = qty + 1),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Total labels: $_totalLabels',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isPrinting ? null : _print,
          icon: _isPrinting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print),
          label: Text(_isPrinting ? 'Printing...' : 'Print'),
        ),
      ],
    );
  }
}

// ============================================================================
// SCAN-TO-PRINT SCREEN (Batch Label Printing)
// ============================================================================

class ScanToPrintLabelsScreen extends StatefulWidget {
  const ScanToPrintLabelsScreen({super.key});

  @override
  State<ScanToPrintLabelsScreen> createState() => _ScanToPrintLabelsScreenState();
}

class _ScanToPrintLabelsScreenState extends State<ScanToPrintLabelsScreen> {
  final BarcodeLookupService _lookupService = sl<BarcodeLookupService>();
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  final List<ScannedProduct> _scannedProducts = [];
  final Map<String, int> _labelCounts = {};
  bool _isScanning = false;

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
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _onBarcodeSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
    _lookupBarcode(trimmed);
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() => _isScanning = true);

    try {
      final result = await _lookupService.lookupBarcode(barcode: barcode);
      if (result.success && result.product != null) {
        final existing = _scannedProducts.indexWhere((p) => p.id == result.product!.id);
        setState(() {
          if (existing >= 0) {
            _labelCounts[result.product!.id] =
                (_labelCounts[result.product!.id] ?? 1) + 1;
          } else {
            _scannedProducts.insert(0, result.product!);
            _labelCounts[result.product!.id] = 1;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Not found: $barcode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _printLabels() {
    showDialog(
      context: context,
      builder: (_) => BarcodeLabelPrinterDialog(products: _scannedProducts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & Print Labels'),
        actions: [
          if (_scannedProducts.isNotEmpty)
            FilledButton.icon(
              onPressed: _printLabels,
              icon: const Icon(Icons.print),
              label: Text('Print ${_scannedProducts.length} Labels'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Hidden scanner input
          SizedBox(
            height: 1,
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              onSubmitted: _onBarcodeSubmitted,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),

          // Scanner status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isScanning ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(
                  _isScanning ? Icons.radar : Icons.qr_code_scanner,
                  color: _isScanning ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isScanning ? 'Looking up...' : 'Scanner ready â€” scan products to add labels',
                  style: TextStyle(
                    color: _isScanning ? Colors.blue : Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_scannedProducts.length} products',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: _scannedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.print, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Scan products to add labels for printing',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _scannedProducts.length,
                    itemBuilder: (context, index) {
                      final product = _scannedProducts[index];
                      final qty = _labelCounts[product.id] ?? 1;
                      return Card(
                        child: ListTile(
                          title: Text(product.displayTitle),
                          subtitle: Text(
                            product.barcode ?? 'No barcode',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: qty > 1
                                    ? () => setState(() => _labelCounts[product.id] = qty - 1)
                                    : () => setState(() {
                                          _scannedProducts.removeAt(index);
                                          _labelCounts.remove(product.id);
                                        }),
                              ),
                              Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => setState(() => _labelCounts[product.id] = qty + 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
