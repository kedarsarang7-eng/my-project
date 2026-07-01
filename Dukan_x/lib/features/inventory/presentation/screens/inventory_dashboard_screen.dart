import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Design System
import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/glass_morphism.dart';

// Models
import '../../../../core/repository/products_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/services/event_dispatcher.dart';
import '../../../../core/services/websocket_service.dart';

// Core Services

// Screens
import 'barcode_scanner_screen.dart'; // camera fallback
import '../../../barcode/widgets/desktop_usb_scanner.dart';
import '../widgets/dead_stock_tab.dart';
import '../widgets/reorder_tab.dart';
import '../widgets/add_edit_product_sheet.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'import_inventory_screen.dart';
import '../../../barcode/presentation/screens/barcode_label_printing_screen.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/low_stock_chart.dart';
import '../../../../widgets/desktop/stock_value_category_chart.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState
    extends ConsumerState<InventoryDashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // WS callback references kept for unsubscribe on dispose
  late final WSEventCallback _onInventoryUpdated;
  late final WSEventCallback _onLowStockAlert;
  StreamSubscription<BusinessEventData>? _stockSubscription;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
      });
    });

    // Real-time local updates via EventDispatcher
    _stockSubscription = EventDispatcher.instance.where(BusinessEvent.stockChanged).listen((_) {
      if (mounted) setState(() {});
    });

    // Real-time cross-device updates via WebSocket
    _onInventoryUpdated = (_) {
      if (mounted) setState(() {});
    };
    _onLowStockAlert = (_) {
      if (mounted) setState(() {});
    };
    final ws = WebSocketService.instance;
    ws.subscribe(WSEventName.inventoryUpdated, _onInventoryUpdated);
    ws.subscribe(WSEventName.lowStockAlert, _onLowStockAlert);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return DefaultTabController(
      length: 4,
      child: DesktopContentContainer(
        title: "Inventory Management",
        subtitle: "Track stock, value and reorder levels",
        actions: [
          DesktopActionButton(
            label: "Print Labels",
            icon: Icons.label_outline,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BarcodeLabelPrintingScreen(),
              ),
            ),
            isPrimary: false,
          ),
          const SizedBox(width: 12),
          DesktopActionButton(
            label: "Export CSV",
            icon: Icons.download,
            onPressed: _exportInventory,
            isPrimary: false,
          ),
          const SizedBox(width: 12),
          DesktopActionButton(
            label: "Import CSV",
            icon: Icons.upload_file,
            onPressed: () => _navigateToImport(context),
            isPrimary: false,
          ),
          const SizedBox(width: 12),
          DesktopActionButton(
            label: "Add Product",
            icon: Icons.add,
            onPressed: () => _showAddEditProductDialog(context),
            isPrimary: true,
          ),
        ],
        child: Column(
          children: [
            // Tabs Row
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FuturisticColors.premiumBlue.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: TabBar(
                isScrollable: true,
                labelColor: FuturisticColors.premiumBlue,
                unselectedLabelColor: FuturisticColors.textSecondary,
                indicatorColor: FuturisticColors.premiumBlue,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: "All Items"),
                  Tab(text: "In Stock"),
                  Tab(text: "Reorder Required"),
                  Tab(text: "Dead Stock"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildDesktopProductTableWithCharts("All"),
                  _buildDesktopProductTableWithCharts("InStock"),
                  _buildDesktopProductTableWithCharts("Reorder"),
                  _buildDesktopProductTableWithCharts("DeadStock"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopProductTableWithCharts(String mode) {
    return StreamBuilder<List<Product>>(
      stream: sl<ProductsRepository>().watchAll(
        userId: sl<SessionManager>().ownerId ?? '',
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var products = snap.data ?? [];

        // Data processing for charts (we process all products regardless of tab mode to keep chart data stable)
        int lowStockCount = 0;
        int healthyCount = 0;
        Map<String, double> categoryValues = {};

        for (var p in snap.data ?? <Product>[]) {
          if (p.isLowStock) {
            lowStockCount++;
          } else {
            healthyCount++;
          }

          final cat = p.category ?? 'Uncategorized';
          final val = p.stockQuantity * p.costPrice;
          categoryValues[cat] = (categoryValues[cat] ?? 0) + val;
        }

        // Filter Logic for table
        if (mode == "Reorder") {
          products = products.where((p) => p.isLowStock).toList();
        } else if (mode == "DeadStock") {
          products = products.where((p) => p.stockQuantity <= 0).toList();
        }

        // Search Filter: supports barcode exact match (with highlight) and name/SKU fuzzy match
        String? highlightedProductId;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase().trim();

          // First try exact barcode match for highlighting
          final barcodeMatch = products.firstWhere(
            (p) =>
                p.barcode?.toLowerCase() == query ||
                p.altBarcodes.any((b) => b.toLowerCase() == query) == true,
            orElse: () => products.first,
          );
          if (barcodeMatch.barcode?.toLowerCase() == query ||
              barcodeMatch.altBarcodes.any((b) => b.toLowerCase() == query) ==
                  true) {
            highlightedProductId = barcodeMatch.id;
          }

          products = products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(query) ||
                    (p.sku?.toLowerCase().contains(query) ?? false) ||
                    (p.barcode?.toLowerCase().contains(query) ?? false) ||
                    (p.altBarcodes.any(
                          (b) => b.toLowerCase().contains(query),
                        ) ??
                        false),
              )
              .toList();

          // If barcode exact match, move it to top
          if (highlightedProductId != null) {
            final highlighted = products.firstWhere(
              (p) => p.id == highlightedProductId,
            );
            products.removeWhere((p) => p.id == highlightedProductId);
            products.insert(0, highlighted);
          }
        }

        if (mode == "InStock") {
          products = products.where((p) => p.stockQuantity > 0).toList();
        }

        return Column(
          children: [
            // Analytics Row
            if (mode == "All") ...[
              SizedBox(
                height: 320,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: StockValueCategoryChart(
                        categoryValues: categoryValues,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: LowStockChart(
                        lowStockCount: lowStockCount,
                        healthyStockCount: healthyCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (mode == "All")
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(color: FuturisticColors.white),
                        decoration: InputDecoration(
                          hintText: "Search by Name or SKU...",
                          prefixIcon: Icon(
                            Icons.search,
                            color: FuturisticColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: FuturisticColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: EnterpriseTable<Product>(
                columns: [
                  EnterpriseTableColumn(
                    title: "Product Name",
                    valueBuilder: (p) => p.name,
                    widgetBuilder: (p) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (p.sku != null)
                          Text(
                            p.sku!,
                            style: TextStyle(
                              fontSize: 12,
                              color: FuturisticColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  EnterpriseTableColumn(
                    title: "Category",
                    valueBuilder: (p) => p.category ?? "General",
                  ),
                  EnterpriseTableColumn(
                    title: "Stock",
                    isNumeric: true,
                    valueBuilder: (p) => p.stockQuantity,
                    widgetBuilder: (p) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${p.stockQuantity} ${p.unit}"),
                        if (p.isLowStock)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.warning,
                              color: FuturisticColors.error,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                  EnterpriseTableColumn(
                    title: "Cost",
                    isNumeric: true,
                    valueBuilder: (p) => p.costPrice,
                    widgetBuilder: (p) => Text("${sl<CurrencyService>().symbol}${p.costPrice}"),
                  ),
                  EnterpriseTableColumn(
                    title: "Price",
                    isNumeric: true,
                    valueBuilder: (p) => p.sellingPrice,
                    widgetBuilder: (p) => Text(
                      "${sl<CurrencyService>().symbol}${p.sellingPrice}",
                      style: const TextStyle(
                        color: FuturisticColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                data: products,
                actionsBuilder: (p) => [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: FuturisticColors.primary,
                      size: 20,
                    ),
                    onPressed: () =>
                        _showAddEditProductDialog(context, product: p),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: FuturisticColors.error,
                      size: 20,
                    ),
                    onPressed: () => _confirmDelete(p),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark
            ? FuturisticColors.darkBackground
            : FuturisticColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark
              ? FuturisticColors.darkSurface
              : FuturisticColors.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.secondaryGradient,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  boxShadow: AppShadows.glowShadow(FuturisticColors.secondary),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Inventory Management',
                style: AppTypography.headlineMedium.copyWith(
                  color: isDark
                      ? FuturisticColors.darkTextPrimary
                      : FuturisticColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          leading: BackButton(color: isDark ? Colors.white : Colors.black),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.md),
              decoration: BoxDecoration(
                color: FuturisticColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: Border.all(
                  color: FuturisticColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.file_download,
                  color: FuturisticColors.primary,
                ),
                onPressed: _exportInventory,
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: FuturisticColors.primary,
            unselectedLabelColor: isDark
                ? FuturisticColors.darkTextSecondary
                : FuturisticColors.textSecondary,
            indicatorColor: FuturisticColors.primary,
            labelStyle: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'All Items'),
              Tab(text: 'Reorder'),
              Tab(text: 'Dead Stock'),
            ],
          ),
        ),
        floatingActionButton: Container(
          margin: const EdgeInsets.only(bottom: 60), // Lift up above nav bar
          decoration: BoxDecoration(
            gradient: AppGradients.primaryGradient,
            borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
            boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
          ),
          child: FloatingActionButton(
            onPressed: () => _showAddEditProductDialog(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        body: TabBarView(
          children: [
            // All Items Tab
            StreamBuilder<List<Product>>(
              stream: sl<ProductsRepository>().watchAll(
                userId: sl<SessionManager>().ownerId ?? '',
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allProducts = snap.data ?? [];

                // Calculate Stats
                final totalItems = allProducts.length;
                final lowStockCount = allProducts
                    .where((p) => p.isLowStock)
                    .length;
                final totalValue = allProducts.fold(
                  0.0,
                  (sum, p) => sum + (p.stockQuantity * p.costPrice),
                );

                // Filter for List
                var visibleProducts = allProducts;
                if (_searchQuery.isNotEmpty) {
                  visibleProducts = allProducts
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (p.sku?.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false),
                      )
                      .toList();
                }

                return Column(
                  children: [
                    // Search & Filter
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white24 : Colors.grey,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Colors.blueAccent,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(
                              Icons.qr_code_scanner,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            tooltip: 'Scan barcode to search',
                            onPressed: () async {
                              // Primary: USB/BT scanner dialog
                              final result = await showDialog<String>(
                                context: context,
                                barrierDismissible: true,
                                builder: (ctx) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.qr_code_scanner,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Text(
                                                'Search by Barcode',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        DesktopUsbScanner(
                                          onProductScanned: (p) =>
                                              Navigator.pop(ctx, p.barcode),
                                          onProductNotFound: (code) =>
                                              Navigator.pop(ctx, code),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            final cam = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const BarcodeScannerScreen(),
                                              ),
                                            );
                                            if (cam != null && mounted) {
                                              _searchCtrl.text = cam as String;
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Use Camera Instead',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                _searchCtrl.text = result;
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Stats Bar
                    _buildStatsBar(
                      isDark,
                      totalItems,
                      lowStockCount,
                      totalValue,
                    ),

                    // Product List
                    Expanded(
                      child: visibleProducts.isEmpty
                          ? CompactEmptyState(
                              icon: Icons.inventory_2_outlined,
                              message: _searchQuery.isNotEmpty
                                  ? 'No products match "$_searchQuery"'
                                  : 'No products yet. Add your first product to get started.',
                              actionLabel: _searchQuery.isEmpty
                                  ? 'Add Product'
                                  : null,
                              onAction: _searchQuery.isEmpty
                                  ? () => _showAddEditProductDialog(context)
                                  : null,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: visibleProducts.length,
                              itemBuilder: (context, index) {
                                final product = visibleProducts[index];
                                return _buildProductCard(product, isDark);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),

            // Reorder Tab
            const ReorderTab(),

            // Dead Stock Tab
            const DeadStockTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(bool isDark, int items, int lowStock, double val) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        borderRadius: AppBorderRadius.xl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statsItem('Items', '$items', FuturisticColors.primary, isDark),
            Container(
              width: 1,
              height: 40,
              color: isDark
                  ? FuturisticColors.darkDivider
                  : FuturisticColors.divider,
            ),
            _statsItem(
              'Low Stock',
              '$lowStock',
              FuturisticColors.warning,
              isDark,
            ),
            Container(
              width: 1,
              height: 40,
              color: isDark
                  ? FuturisticColors.darkDivider
                  : FuturisticColors.divider,
            ),
            _statsItem(
              'Value',
              '₹${val.toStringAsFixed(2)}',
              FuturisticColors.success,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isDark
                ? FuturisticColors.darkTextSecondary
                : FuturisticColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product p, bool isDark) {
    final isLowStock = p.stockQuantity <= (p.lowStockThreshold);

    return ModernCard(
      backgroundColor: isDark
          ? FuturisticColors.darkSurface
          : FuturisticColors.surface,
      borderGradient: isLowStock ? AppGradients.accentGradient : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark
                        ? FuturisticColors.darkTextPrimary
                        : FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Price: ₹${p.sellingPrice} | Stock: ${p.stockQuantity} ${p.unit}',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? FuturisticColors.darkTextSecondary
                        : FuturisticColors.textSecondary,
                  ),
                ),
                if (isLowStock)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppGradients.accentGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                    ),
                    child: Text(
                      'Low Stock Alert',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: FuturisticColors.primary,
                ),
                onPressed: () => _showAddEditProductDialog(context, product: p),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: FuturisticColors.error),
                onPressed: () => _confirmDelete(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEditProductDialog(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditProductSheet(product: product),
    );
  }

  Future<void> _confirmDelete(Product p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${p.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FuturisticColors.error,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final userId = sl<SessionManager>().ownerId;
      if (userId != null) {
        await sl<ProductsRepository>().deleteProduct(p.id, userId: userId);
      }
    }
  }

  void _exportInventory() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Inventory Report...')),
    );

    try {
      // 1. Fetch Data
      final result = await sl<ProductsRepository>().getAll(userId: userId);
      final products = result.data ?? [];

      if (products.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No products to export.')),
          );
        }
        return;
      }

      // 2. Build CSV
      final buffer = StringBuffer();
      buffer.writeln(
        'Name,SKU,Category,Stock,Unit,Cost Price,Selling Price,Value',
      );

      for (final p in products) {
        final value = p.stockQuantity * p.costPrice;
        buffer.writeln(
          '"${p.name}","${p.sku ?? ''}","${p.category ?? ''}",${p.stockQuantity},"${p.unit}",${p.costPrice},${p.sellingPrice},${value.toStringAsFixed(2)}',
        );
      }

      // 3. Save File
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/inventory_report_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buffer.toString());

      // 4. Share
      if (mounted) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Here is my Inventory Report');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _navigateToImport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportInventoryScreen()),
    );
    // Maybe refresh? StreamBuilder handles it automatically usually.
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _stockSubscription?.cancel();
    final ws = WebSocketService.instance;
    ws.unsubscribe(WSEventName.inventoryUpdated, _onInventoryUpdated);
    ws.unsubscribe(WSEventName.lowStockAlert, _onLowStockAlert);
    super.dispose();
  }
}
