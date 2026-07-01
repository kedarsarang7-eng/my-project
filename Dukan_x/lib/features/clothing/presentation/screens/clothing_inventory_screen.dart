// WCAG 2.1 AA: Theme-derived color pairs target ≥4.5:1 contrast (normal text)
// and ≥3:1 (large text). Full conformance requires manual AT testing + expert review.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/business_capabilities.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../purchase/scan_bill.dart';
import '../../data/variant_repository.dart';
import '../../data/repositories/clothing_repository_offline.dart';
import '../../services/clothing_tag_printer.dart';
import '../../widgets/clothing_sync_indicator.dart';

class ClothingInventoryScreen extends ConsumerStatefulWidget {
  const ClothingInventoryScreen({super.key});

  @override
  ConsumerState<ClothingInventoryScreen> createState() =>
      _ClothingInventoryScreenState();
}

class _ClothingInventoryScreenState
    extends ConsumerState<ClothingInventoryScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  late TabController _tabController;
  bool _isLoading = false;
  List<Product> _products = [];
  Map<String, List<Map<String, dynamic>>> _variants = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInventory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final session = sl<SessionManager>();
      final tenantId = session.currentBusinessId ?? '';

      // Load clothing products
      final result = await sl<ProductsRepository>().getAll(userId: tenantId);
      final products = result.data ?? [];

      // Batch fetch with 10s timeout — no per-product fallback (Req 13.5)
      final entries =
          await Future.wait(
            products.map((product) async {
              final productVariants = await _loadProductVariants(
                tenantId,
                product.id,
              );
              return MapEntry(product.id, productVariants);
            }),
          ).timeout(
            const Duration(milliseconds: 10000),
            onTimeout: () => throw TimeoutException(
              'Batch variant fetch exceeded 10 000 ms',
            ),
          );

      final variants = Map.fromEntries(entries);

      // Only update state on full success
      if (mounted) {
        setState(() {
          _products = products;
          _variants = variants;
        });
      }
    } on TimeoutException {
      // Timeout: show error, leave previously loaded data unchanged (Req 13.5)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Loading variants timed out. Previous data retained.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // Failure: show error, leave previously loaded data unchanged (Req 13.5)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading inventory: $e. Previous data retained.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadProductVariants(
    String tenantId,
    String productId,
  ) async {
    try {
      // Route through ClothingRepositoryOffline (offline-first, Req 12.1)
      final repository = ClothingRepositoryOffline(sl(), sl<SessionManager>());
      await repository.initialize();
      final records = await repository.getVariants(productId);

      return records.map((r) => r.variant.toJson()).toList();
    } catch (e) {
      print('Error loading variants for $productId: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _getFilteredVariants() {
    final productMap = {for (final p in _products) p.id: p};

    if (_searchQuery.isEmpty) {
      return _variants.entries.expand((entry) {
        final product = productMap[entry.key];
        if (product == null) return <Map<String, dynamic>>[];
        return entry.value.map(
          (variant) => <String, dynamic>{
            ...variant,
            'productName': product.name,
            'productId': product.id,
          },
        );
      }).toList();
    }

    final query = _searchQuery.toLowerCase();
    return _variants.entries.expand((entry) {
      final product = productMap[entry.key];
      if (product == null) return <Map<String, dynamic>>[];
      if (!product.name.toLowerCase().contains(query))
        return <Map<String, dynamic>>[];

      return entry.value
          .where(
            (variant) =>
                (variant['size']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (variant['color']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (variant['sku']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (variant['barcode']?.toString().toLowerCase().contains(query) ??
                    false),
          )
          .map(
            (variant) => <String, dynamic>{
              ...variant,
              'productName': product.name,
              'productId': product.id,
            },
          );
    }).toList();
  }

  List<Map<String, dynamic>> _getLowStockVariants() {
    return _getFilteredVariants()
        .where((variant) => (variant['stock'] ?? 0) <= 5)
        .toList();
  }

  List<Map<String, dynamic>> _getOutOfStockVariants() {
    return _getFilteredVariants()
        .where((variant) => (variant['stock'] ?? 0) <= 0)
        .toList();
  }

  /// Prints price-tag/barcode labels for all currently filtered variants using
  /// [ClothingTagPrinter]. A failure names the affected variant (Req 12.6, 12.7).
  Future<void> _printAllVariantTags() async {
    final filtered = _getFilteredVariants();
    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No variants available to print tags for.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Convert the raw variant maps to VariantItem instances for the printer
    final variants = filtered.map((v) {
      return VariantItem(
        id: v['id']?.toString() ?? '',
        productId: v['productId']?.toString() ?? '',
        color: v['color']?.toString() ?? '',
        size: v['size']?.toString() ?? '',
        sku: v['sku']?.toString() ?? '',
        barcode: v['barcode']?.toString() ?? '',
        priceCents: (v['priceCents'] is int) ? v['priceCents'] as int : 0,
        stock: (v['stock'] is int) ? v['stock'] as int : 0,
      );
    }).toList();

    const printer = ClothingTagPrinter();
    final result = await printer.printVariantTags(variants);

    if (!mounted) return;

    if (result.allSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Printed ${result.successCount} variant tag(s) successfully.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      final failedNames = result.failureDetails.keys.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Print failed for: $failedNames. '
            '${result.successCount} tag(s) printed successfully.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessType = ref.watch(businessTypeProvider).type;
    final capabilities = BusinessCapabilities.get(businessType);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Clothing Inventory'),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
        actions: [
          ClothingSyncIndicator(
            repository: ClothingRepositoryOffline(sl(), sl<SessionManager>()),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.label_outlined),
            tooltip: 'Print Tags',
            onPressed: _printAllVariantTags,
          ),
          if (capabilities.supportsTextOCR)
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan Bill (OCR)',
              onPressed: () => ScanBillNavigator.start(
                context,
                verticalType: businessType.name,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(text: 'All Variants'),
            Tab(text: 'Low Stock'),
            Tab(text: 'Out of Stock'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassMorphism(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText:
                      'Search by product name, size, color, SKU, or barcode...',
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVariantList(_getFilteredVariants()),
                _buildVariantList(_getLowStockVariants(), isLowStock: true),
                _buildVariantList(_getOutOfStockVariants(), isOutOfStock: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantList(
    List<Map<String, dynamic>> variants, {
    bool isLowStock = false,
    bool isOutOfStock = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (variants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOutOfStock
                  ? Icons.inventory_2_outlined
                  : isLowStock
                  ? Icons.warning_amber_outlined
                  : Icons.checkroom_outlined,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.38),
            ),
            const SizedBox(height: 16),
            Text(
              isOutOfStock
                  ? 'No out of stock variants'
                  : isLowStock
                  ? 'No low stock variants'
                  : 'No variants found',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: variants.length,
        itemBuilder: (context, index) {
          final variant = variants[index];
          final stock = variant['stock'] ?? 0;
          final isLow = stock <= 5 && stock > 0;
          final isOut = stock <= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isOut
                    ? colorScheme.error
                    : isLow
                    ? colorScheme.tertiary
                    : colorScheme.primary,
                child: Text(
                  '$stock',
                  style: TextStyle(
                    color: isOut
                        ? colorScheme.onError
                        : isLow
                        ? colorScheme.onTertiary
                        : colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                variant['productName'] ?? 'Unknown Product',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Size: ${variant['size'] ?? 'N/A'} | Color: ${variant['color'] ?? 'N/A'}',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${((variant['priceCents'] ?? 0) / 100).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (variant['barcode'] != null)
                    Text(
                      variant['barcode'],
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (variant['sku'] != null) ...[
                        _buildDetailRow('SKU', variant['sku']),
                        const SizedBox(height: 8),
                      ],
                      _buildDetailRow('Stock Level', '$stock units'),
                      if (isOut) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ] else if (isLow) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.tertiary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'LOW STOCK',
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
