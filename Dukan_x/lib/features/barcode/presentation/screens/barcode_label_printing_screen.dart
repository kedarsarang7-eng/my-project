// ignore_for_file: dead_null_aware_expression
import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../widgets/desktop_usb_scanner.dart';
import '../../widgets/barcode_label_printer.dart';
import '../../models/barcode_scan_result.dart';
import 'package:dukanx/core/responsive/responsive.dart';

// ============================================================================
// BARCODE LABEL PRINTING SCREEN
// ============================================================================
// Navigation shell that hosts the BarcodeLabelPrinter widget.
// Reachable from InventoryDashboardScreen ("Print Labels" action).
//
// Flow:
//  1. User scans or searches a product
//  2. Product is loaded into BarcodeLabelPrinter
//  3. User selects label format + quantity → Print / Preview PDF
// ============================================================================

class BarcodeLabelPrintingScreen extends StatefulWidget {
  const BarcodeLabelPrintingScreen({super.key});

  @override
  State<BarcodeLabelPrintingScreen> createState() =>
      _BarcodeLabelPrintingScreenState();
}

class _BarcodeLabelPrintingScreenState
    extends State<BarcodeLabelPrintingScreen> {
  final _session = sl<SessionManager>();
  final _searchController = TextEditingController();

  List<Product> _searchResults = [];
  Product? _selectedProduct;
  ScannedProduct? _scannedProduct;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final userId = _session.ownerId ?? '';
      final result = await sl<ProductsRepository>().search(query, userId: userId);
      setState(() => _searchResults = result.data ?? []);
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 24, color: Colors.blue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Scan Product Barcode',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan an existing product barcode to load it for label printing.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DesktopUsbScanner(
                onProductScanned: (product) => Navigator.pop(ctx, product.barcode),
                onProductNotFound: (code) => Navigator.pop(ctx, code),
              ),
            ],
          ),
        ),
      ),
    );

    if (barcode == null || barcode.isEmpty) return;

    try {
      final userId = _session.ownerId ?? '';
      final result =
          await sl<ProductsRepository>().search(barcode, userId: userId);
      final products = result.data ?? [];
      if (products.isNotEmpty) {
        final match = products.firstWhere(
          (p) => p.barcode == barcode || p.altBarcodes.contains(barcode),
          orElse: () => products.first,
        );
        setState(() {
          _selectedProduct = match;
          _scannedProduct = _toScannedProduct(match);
          _searchController.text = match.name;
          _searchResults = [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No product found for barcode: $barcode'),
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
    }
  }

  ScannedProduct _toScannedProduct(Product p) {
    return ScannedProduct(
      id: p.id,
      tenantId: _session.ownerId ?? '',
      name: p.name,
      sku: p.sku,
      barcode: p.barcode ?? '',
      unit: p.unit ?? 'pcs',
      salePriceCents: (p.sellingPrice * 100).round(),
      purchasePriceCents: (p.costPrice * 100).round(),
      mrpCents: (p.sellingPrice * 100).round(),
      cgstRateBp: (p.taxRate * 100).round(),
      sgstRateBp: (p.taxRate * 100).round(),
      igstRateBp: (p.taxRate * 200).round(),
      currentStock: p.stockQuantity,
      lowStockThreshold: p.lowStockThreshold.toDouble(),
      isActive: true,
      isArchived: false,
      attributes: const {},
      category: p.category,
      hsnCode: p.hsnCode,
      drugSchedule: p.drugSchedule,
      size: p.size,
      color: p.color,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121F) : const Color(0xFFF5F8FF),
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.label_outline, size: 22, color: Colors.blue),
            SizedBox(width: 10),
            Text('Barcode Label Printing',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan barcode to load product',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = context.isMobile;

          final productSelector = Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Product',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search product name...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: _searchProducts,
                  ),
                  const SizedBox(height: 8),
                  // Scan button
                  OutlinedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Scan Barcode'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_searchResults.isNotEmpty) ...[
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, i) {
                          final product = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(product.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(product.barcode ?? 'No barcode',
                                style: const TextStyle(fontSize: 11)),
                            selected: _selectedProduct?.id == product.id,
                            selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            onTap: () => setState(() {
                              _selectedProduct = product;
                              _scannedProduct = _toScannedProduct(product);
                              _searchResults = [];
                              _searchController.text = product.name;
                            }),
                          );
                        },
                      ),
                    ),
                  ] else if (_selectedProduct != null) ...[
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedProduct!.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Barcode: ${_selectedProduct!.barcode ?? 'N/A'}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(
                              'MRP: ₹${_selectedProduct!.sellingPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => BarcodeLabelPrinterDialog(
                                singleProduct: _scannedProduct,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('Configure & Print Labels'),
                        ),
                      ),
                    ],
                  ] else ...[
                    const Spacer(),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Search or scan a product',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ],
              ),
            ),
          );

          if (isMobile) {
            return Center(
              child: BoundedBox(
                maxWidth: 550,
                child: productSelector,
              ),
            );
          }

          // Desktop
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: productSelector,
              ),
              Expanded(
                child: _selectedProduct == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.label_outline, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Select a product on the left to configure labels',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _scanBarcode,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan Product Barcode'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          ],
                        ),
                      )
                    : BarcodeLabelPrinterDialog(
                        singleProduct: _scannedProduct,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
