// ============================================================================
// RESTAURANT RAW MATERIAL INVENTORY SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/restaurant_inventory_model.dart';
import '../../data/repositories/restaurant_inventory_repository.dart';
import '../../../barcode/widgets/desktop_usb_scanner.dart';
import '../../../barcode/services/barcode_lookup_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class RestaurantInventoryScreen extends StatefulWidget {
  final String vendorId;
  const RestaurantInventoryScreen({super.key, this.vendorId = 'SYSTEM'});
  @override
  State<RestaurantInventoryScreen> createState() =>
      _RestaurantInventoryScreenState();
}

class _RestaurantInventoryScreenState extends State<RestaurantInventoryScreen>
    with SingleTickerProviderStateMixin {
  final RestaurantInventoryRepository _repo = RestaurantInventoryRepository();
  late TabController _tabs;
  final _orange = const Color(0xFFEA580C);
  String get _vendorId => widget.vendorId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _orange),
    ),
  );

  Future<void> _scanAndPrefillMaterial(
    TextEditingController nameCtrl,
    TextEditingController costCtrl,
  ) async {
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
                  Icon(Icons.qr_code_scanner, size: 24, color: _orange),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Scan Packaged Item',
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
                'Scan packaged ingredient/beverage barcode to auto-fill name.',
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
      // Try lookup service for name/price data
      final lookupService = sl<BarcodeLookupService>();
      await lookupService.initialize();
      final lookupResult = await lookupService.lookupBarcode(
        barcode: barcode,
        businessId: sl<SessionManager>().ownerId ?? '',
      );

      if (lookupResult.success && lookupResult.product != null) {
        nameCtrl.text = lookupResult.product!.name;
        costCtrl.text = lookupResult.product!.salePrice.toStringAsFixed(2);
        return;
      }

      // Fallback: local product DB
      final userId = sl<SessionManager>().ownerId ?? '';
      final productsResult = await sl<ProductsRepository>().search(barcode, userId: userId);
      final products = productsResult.data ?? [];
      if (products.isNotEmpty) {
        final match = products.firstWhere(
          (p) => p.barcode == barcode || p.altBarcodes.contains(barcode),
          orElse: () => products.first,
        );
        nameCtrl.text = match.name;
        costCtrl.text = match.costPrice.toStringAsFixed(2);
            } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found for barcode: $barcode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEditDialog({RestaurantInventoryItem? item}) {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final stockCtrl = TextEditingController(
      text: item?.currentStock.toString() ?? '0',
    );
    final alertCtrl = TextEditingController(
      text: item?.minStockAlert.toString() ?? '0',
    );
    final costCtrl = TextEditingController(
      text: item?.costPerUnit.toString() ?? '0',
    );
    final supplierCtrl = TextEditingController(text: item?.supplierName ?? '');
    InventoryUnit selectedUnit = item?.unit ?? InventoryUnit.pcs;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: FuturisticColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? 'Add Ingredient / Material' : 'Edit Material',
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('Material Name *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _scanAndPrefillMaterial(nameCtrl, costCtrl),
                        icon: Icon(Icons.qr_code_scanner, color: _orange),
                        tooltip: 'Scan barcode to auto-fill',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<InventoryUnit>(
                    value: selectedUnit,
                    dropdownColor: FuturisticColors.darkSurfaceVariant,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec('Unit'),
                    items: InventoryUnit.values
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDS(() => selectedUnit = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('Current Stock'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: alertCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('Low Alert Level'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('Cost / Unit (₹)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: supplierCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('Supplier'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                if (item == null) {
                  await _repo.createInventoryItem(
                    vendorId: _vendorId,
                    name: nameCtrl.text.trim(),
                    unit: selectedUnit,
                    currentStock: double.tryParse(stockCtrl.text) ?? 0,
                    minStockAlert: double.tryParse(alertCtrl.text) ?? 0,
                    costPerUnit: double.tryParse(costCtrl.text) ?? 0,
                    supplierName: supplierCtrl.text.isEmpty
                        ? null
                        : supplierCtrl.text,
                  );
                } else {
                  await _repo.updateStock(
                    item.id,
                    double.tryParse(stockCtrl.text) ?? item.currentStock,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(item == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustDialog(RestaurantInventoryItem item) {
    final ctrl = TextEditingController();
    bool isAdd = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          backgroundColor: FuturisticColors.darkSurface,
          title: Text(
            'Adjust Stock — ${item.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Add'),
                    selected: isAdd,
                    onSelected: (_) => setDS(() => isAdd = true),
                    selectedColor: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Remove'),
                    selected: !isAdd,
                    onSelected: (_) => setDS(() => isAdd = false),
                    selectedColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Qty (${item.unit.displayName})'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdd ? Colors.green : Colors.red,
              ),
              onPressed: () async {
                final qty = double.tryParse(ctrl.text) ?? 0;
                await _repo.adjustStock(item.id, isAdd ? qty : -qty);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
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
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.inventory_2_outlined, color: _orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Raw Material Inventory',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _orange,
          labelColor: _orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'All Materials'),
            Tab(icon: Icon(Icons.warning_amber_outlined), text: 'Low Stock'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Material'),
              onPressed: () => _showAddEditDialog(),
            ),
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
        controller: _tabs,
        children: [_buildAllItems(isDark), _buildLowStockItems(isDark)],
      ),
      ),
    );
  }

  Widget _buildAllItems(bool isDark) {
    return StreamBuilder<List<RestaurantInventoryItem>>(
      stream: _repo.watchInventoryItems(_vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _orange));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No materials added yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }
        return _buildList(items, isDark);
      },
    );
  }

  Widget _buildLowStockItems(bool isDark) {
    return StreamBuilder<List<RestaurantInventoryItem>>(
      stream: _repo.watchInventoryItems(_vendorId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final low = all.where((i) => i.isLowStock).toList();
        if (low.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                const Text(
                  'All materials above alert level ✓',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        return _buildList(low, isDark);
      },
    );
  }

  Widget _buildList(List<RestaurantInventoryItem> items, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildItemCard(items[i], isDark),
    );
  }

  Widget _buildItemCard(RestaurantInventoryItem item, bool isDark) {
    final isLow = item.isLowStock;
    final stockColor = isLow ? Colors.red : Colors.green;
    final pct = item.minStockAlert > 0
        ? (item.currentStock / (item.minStockAlert * 3)).clamp(0.0, 1.0)
        : 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _orange.withValues(alpha: 0.25)),
                  ),
                  child: Center(
                    child: Text(
                      item.unit.displayName,
                      style: TextStyle(
                        color: _orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.name,
                            style: AppTypography.labelLarge.copyWith(
                              color: isDark
                                  ? FuturisticColors.darkTextPrimary
                                  : FuturisticColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isLow)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LOW',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${item.currentStock} ${item.unit.displayName}  •  '
                        'Alert: ${item.minStockAlert}  •  '
                        '₹${item.costPerUnit}/${item.unit.displayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? FuturisticColors.darkTextSecondary
                              : FuturisticColors.textSecondary,
                        ),
                      ),
                      if (item.supplierName != null)
                        Text(
                          '📦 ${item.supplierName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.tune, color: _orange, size: 20),
                      tooltip: 'Adjust Stock',
                      onPressed: () => _showAdjustDialog(item),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.grey,
                        size: 18,
                      ),
                      tooltip: 'Edit',
                      onPressed: () => _showAddEditDialog(item: item),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                backgroundColor: Colors.white12,
                color: stockColor,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
