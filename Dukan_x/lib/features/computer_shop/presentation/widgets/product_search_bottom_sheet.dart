// ============================================================================
// Computer Shop — Product Search Bottom Sheet
// ============================================================================
// Search and select products to add as parts to a job
// Features: Search by name/barcode, real-time results, stock indicators
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'computer_barcode_scanner.dart';
import 'package:dukanx/core/api/api_client.dart';

/// Bottom sheet for searching and selecting products to add as parts
class ProductSearchBottomSheet extends ConsumerStatefulWidget {
  final String jobId;
  final Function(String productId, String productName, double unitPrice, int quantity) onProductSelected;

  const ProductSearchBottomSheet({
    super.key,
    required this.jobId,
    required this.onProductSelected,
  });

  @override
  ConsumerState<ProductSearchBottomSheet> createState() => _ProductSearchBottomSheetState();
}

class _ProductSearchBottomSheetState extends ConsumerState<ProductSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  String? _error;
  ProductModel? _selectedProduct;
  bool _showScanner = false;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final repository = ref.read(productRepositoryProvider);
      final results = await repository.searchProducts(
        query: query,
        limit: 20,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to search: $e';
        _isSearching = false;
      });
    }
  }

  void _onBarcodeScanned(String barcode) async {
    // First try to find by barcode
    setState(() {
      _showScanner = false;
      _isSearching = true;
      _searchController.text = barcode;
    });

    try {
      final repository = ref.read(productRepositoryProvider);
      
      // Try barcode lookup first
      final product = await repository.getProductByBarcode(barcode);
      
      if (product != null) {
        setState(() {
          _selectedProduct = product;
          _searchResults = [product];
          _isSearching = false;
        });
      } else {
        // Fallback to search
        await _searchProducts(barcode);
      }
    } catch (e) {
      // Fallback to search
      await _searchProducts(barcode);
    }
  }

  void _onProductSelected(ProductModel product) {
    setState(() {
      _selectedProduct = product;
    });
  }

  void _submit() {
    if (_selectedProduct == null) return;

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    
    widget.onProductSelected(
      _selectedProduct!.id,
      _selectedProduct!.name,
      _selectedProduct!.sellingPrice ?? 0,
      quantity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Part to Job',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showScanner ? Icons.keyboard : Icons.qr_code_scanner,
                      color: const Color(0xFF3B82F6),
                    ),
                    onPressed: () {
                      setState(() {
                        _showScanner = !_showScanner;
                      });
                    },
                    tooltip: _showScanner ? 'Use keyboard' : 'Use scanner',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Search for a product to add as a part',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              
              // Scanner or Search Input
              if (_showScanner)
                ProductBarcodeScanner(
                  onProductScanned: _onBarcodeScanned,
                  label: 'Scan Product Barcode',
                )
              else
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _searchProducts(value);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Search Products',
                    hintText: 'Type product name or barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                                _selectedProduct = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              const SizedBox(height: 16),
              
              // Search Results or Selected Product
              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else if (_selectedProduct != null)
                _SelectedProductCard(
                  product: _selectedProduct!,
                  quantityController: _quantityController,
                  onChangeProduct: () {
                    setState(() {
                      _selectedProduct = null;
                    });
                  },
                )
              else if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return _ProductListTile(
                        product: product,
                        onTap: () => _onProductSelected(product),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, color: Colors.grey.shade300, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No products found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Submit Button
              if (_selectedProduct != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add to Job',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product list tile for search results
class _ProductListTile extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductListTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol);
    final bool hasStock = (product.currentStock ?? 0) > 0;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory_2, color: Color(0xFF3B82F6)),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.barcode != null)
            Text(
              'SKU: ${product.barcode}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasStock
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasStock ? '${product.currentStock} in stock' : 'Out of stock',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasStock ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Text(
        currencyFormat.format(product.sellingPrice ?? 0),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}

/// Selected product card with quantity input
class _SelectedProductCard extends StatelessWidget {
  final ProductModel product;
  final TextEditingController quantityController;
  final VoidCallback onChangeProduct;

  const _SelectedProductCard({
    required this.product,
    required this.quantityController,
    required this.onChangeProduct,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: sl<CurrencyService>().symbol);
    final unitPrice = product.sellingPrice ?? 0;
    final quantity = int.tryParse(quantityController.text) ?? 1;
    final total = unitPrice * quantity;

    return Card(
      elevation: 0,
      color: const Color(0xFFEBF5FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onChangeProduct,
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Unit Price: ${currencyFormat.format(unitPrice)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      // Rebuild to update total
                      (context as Element).markNeedsBuild();
                    },
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      currencyFormat.format(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Provider for Product Repository
// ============================================================================

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final apiClient = sl<ApiClient>();
  return ProductRepository(apiClient);
});

// Stub imports for compilation
class ProductRepository {
  final dynamic apiClient;
  ProductRepository(this.apiClient);
  
  Future<List<ProductModel>> searchProducts({required String query, int limit = 20}) async => [];
  Future<ProductModel?> getProductByBarcode(String barcode) async => null;
}

class ProductModel {
  final String id;
  final String name;
  final double? sellingPrice;
  final int? currentStock;
  final String? barcode;

  ProductModel({
    required this.id,
    required this.name,
    this.sellingPrice,
    this.currentStock,
    this.barcode,
  });
}


