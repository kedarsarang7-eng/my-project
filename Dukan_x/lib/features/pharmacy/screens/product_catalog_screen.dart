import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../../../models/bill.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Pharmacy Product Catalog Screen
/// Features:
/// - Product grid with images
/// - Search by name/barcode
/// - Filter by category, price range
/// - Add to bill / Quick reorder
/// - Low-stock alerts
class PharmacyProductCatalogScreen extends ConsumerStatefulWidget {
  const PharmacyProductCatalogScreen({super.key});

  @override
  ConsumerState<PharmacyProductCatalogScreen> createState() =>
      _PharmacyProductCatalogScreenState();
}

class _PharmacyProductCatalogScreenState
    extends ConsumerState<PharmacyProductCatalogScreen> {
  late TextEditingController _searchController;
  String _selectedCategory = 'All';
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _inStockOnly = false;
  int _currentPage = 1;
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadProducts();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final apiClient = sl<ApiClient>();
      final response = await apiClient.get(
        '/products/categories',
        queryParameters: {'businessType': 'pharmacy'},
      );
      if (response.isSuccess && response.data != null) {
        final cats = List<String>.from(
            (response.data!['categories'] as List? ?? []).map((e) => e.toString()));
        if (mounted) {
          setState(() => _categories = ['All', ...cats]);
        }
      }
    } catch (_) {
      // Keep default 'All' category on error
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = sl<ApiClient>();
      final response = await apiClient.get(
        '/products',
        queryParameters: {
          'businessType': 'pharmacy',
          if (_searchController.text.isNotEmpty) 'searchTerm': _searchController.text,
          if (_selectedCategory != 'All') 'category': _selectedCategory,
          'minPrice': _priceRange.start.toInt().toString(),
          'maxPrice': _priceRange.end.toInt().toString(),
          'inStock': _inStockOnly.toString(),
          'page': _currentPage.toString(),
          'limit': '20',
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        setState(() {
          _products = List<Map<String, dynamic>>.from(data['items'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onProductTap(int index) {
    final product = _products[index];
    _showProductDetail(product);
  }

  void _showProductDetail(Map<String, dynamic> product) {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: _ProductDetailContent(product: product),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: _ProductDetailContent(product: product),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterPanel(),
          ),
        ],
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 1200,
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search medicine by name or barcode',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts();
                        },
                      ),
                  ],
                  onSubmitted: (value) => _loadProducts(),
                ),
              ),
              // Active Filters Display
              if (_selectedCategory != 'All' ||
                  _inStockOnly ||
                  _priceRange.start > 0 ||
                  _priceRange.end < 10000)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedCategory != 'All')
                        Chip(
                          label: Text(_selectedCategory),
                          onDeleted: () {
                            setState(() => _selectedCategory = 'All');
                            _loadProducts();
                          },
                        ),
                      if (_inStockOnly)
                        Chip(
                          label: const Text('In Stock'),
                          onDeleted: () {
                            setState(() => _inStockOnly = false);
                            _loadProducts();
                          },
                        ),
                      if (_priceRange.start > 0 || _priceRange.end < 10000)
                        Chip(
                          label: Text(
                            '₹${_priceRange.start.toInt()}-${_priceRange.end.toInt()}',
                          ),
                          onDeleted: () {
                            setState(
                              () =>
                                  _priceRange = const RangeValues(0, 10000),
                            );
                            _loadProducts();
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              // Products Grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.medication,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No products found',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: responsiveValue<int>(context, mobile: 2, tablet: 4, desktop: 5),
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            padding: const EdgeInsets.all(8),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final p = _products[index];
                              return GestureDetector(
                                onTap: () => _onProductTap(index),
                                child: Card(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: p['presignedThumbUrl'] != null
                                            ? Image.network(
                                                p['presignedThumbUrl'] as String,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              )
                                            : const Center(child: Icon(Icons.medication, size: 40)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          p['name'] as String? ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddProductSheet(),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterPanel() {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: _FilterPanelContent(
              categories: _categories,
              selectedCategory: _selectedCategory,
              priceRange: _priceRange,
              inStockOnly: _inStockOnly,
              onApply: (cat, price, stock) {
                setState(() {
                  _selectedCategory = cat;
                  _priceRange = price;
                  _inStockOnly = stock;
                });
                _loadProducts();
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => _FilterPanelContent(
          categories: _categories,
          selectedCategory: _selectedCategory,
          priceRange: _priceRange,
          inStockOnly: _inStockOnly,
          onApply: (cat, price, stock) {
            setState(() {
              _selectedCategory = cat;
              _priceRange = price;
              _inStockOnly = stock;
            });
            _loadProducts();
          },
        ),
      );
    }
  }

  void _showAddProductSheet() {
    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
            child: const _AddProductPlaceholder(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => const _AddProductPlaceholder(),
      );
    }
  }
}

class _AddProductPlaceholder extends StatelessWidget {
  const _AddProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Add Product - Coming Soon'));
  }
}

/// Detail Row Helper Widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _ProductDetailContent extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductDetailContent({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Center(
            child: product['presignedImageUrl'] != null
                ? Image.network(product['presignedImageUrl'] as String,
                    width: 200, height: 200, fit: BoxFit.cover)
                : const Icon(Icons.medication, size: 64),
          ),
          const SizedBox(height: 16),
          // Product Name
          Text(
            product['name'] ?? '',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          // Brand & Manufacturer
          if (product['brand'] != null)
            Text(
              'Brand: ${product['brand']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (product['manufacturer'] != null)
            Text(
              'Manufacturer: ${product['manufacturer']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          const SizedBox(height: 12),
          // Pharmacy Details
          if (product['strength'] != null)
            _DetailRow('Strength', product['strength']),
          if (product['formulation'] != null)
            _DetailRow('Formulation', product['formulation']),
          if (product['batchNo'] != null)
            _DetailRow('Batch No', product['batchNo']),
          if (product['expiryDate'] != null)
            _DetailRow(
              'Expiry Date',
              DateTime.fromMillisecondsSinceEpoch(
                      product['expiryDate'] as int)
                  .toString()
                  .split(' ')
                  .first,
            ),
          const SizedBox(height: 16),
          // Pricing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MRP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  Text(
                    '₹${product['mrp'] ?? product['price']}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                  ),
                ],
              ),
              if (product['cost'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '₹${product['cost']}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stock Info
          Row(
            children: [
              Icon(
                (product['stock'] ?? 0) > 0
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: (product['stock'] ?? 0) > 0
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Stock: ${product['stock'] ?? 0} ${product['unit'] ?? 'pcs'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Create BillItem with product image data
                    final billItem = BillItem(
                      productId: product['id'],
                      productName: product['name'],
                      qty: 1,
                      price: product['price']?.toDouble() ?? 0,
                      unit: 'pcs',
                      gstRate: product['gstRate']?.toDouble() ?? 12.0,
                      presignedImageUrl: product['presignedImageUrl'],
                    );

                    // Return BillItem to billing screen
                    Navigator.pop(context, billItem);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${product['name']} to bill',
                        ),
                      ),
                    );
                  },
                  child: const Text('Add to Bill'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPanelContent extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final RangeValues priceRange;
  final bool inStockOnly;
  final Function(String, RangeValues, bool) onApply;

  const _FilterPanelContent({
    required this.categories,
    required this.selectedCategory,
    required this.priceRange,
    required this.inStockOnly,
    required this.onApply,
  });

  @override
  State<_FilterPanelContent> createState() => _FilterPanelContentState();
}

class _FilterPanelContentState extends State<_FilterPanelContent> {
  late String _selectedCategory;
  late RangeValues _priceRange;
  late bool _inStockOnly;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _priceRange = widget.priceRange;
    _inStockOnly = widget.inStockOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Category Filter
          Text(
            'Category',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.categories
                .map(
                  (category) => ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          // Price Range Filter
          Text(
            'Price Range: ₹${_priceRange.start.toInt()} - ₹${_priceRange.end.toInt()}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 10000,
            divisions: 100,
            labels: RangeLabels(
              '₹${_priceRange.start.toInt()}',
              '₹${_priceRange.end.toInt()}',
            ),
            onChanged: (RangeValues values) {
              setState(() => _priceRange = values);
            },
          ),
          const SizedBox(height: 16),
          // Stock Filter
          CheckboxListTile(
            title: const Text('In Stock Only'),
            value: _inStockOnly,
            onChanged: (value) {
              setState(() => _inStockOnly = value ?? false);
            },
          ),
          const SizedBox(height: 16),
          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_selectedCategory, _priceRange, _inStockOnly);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
