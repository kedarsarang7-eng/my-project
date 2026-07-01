// ============================================================================
// DECORATION & CATERING — INVENTORY MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dc_models.dart';
import '../../data/repositories/dc_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DcInventoryScreen extends ConsumerStatefulWidget {
  const DcInventoryScreen({super.key});

  @override
  ConsumerState<DcInventoryScreen> createState() => _DcInventoryScreenState();
}

class _DcInventoryScreenState extends ConsumerState<DcInventoryScreen> {
  InventoryCategory? _categoryFilter;
  bool _lowStockOnly = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(dcInventoryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilters(),
            Expanded(
              child: inventoryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  var filtered = items;
                  if (_categoryFilter != null)
                    filtered = filtered
                        .where((i) => i.category == _categoryFilter)
                        .toList();
                  if (_lowStockOnly)
                    filtered = filtered.where((i) => i.isLowStock).toList();
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    filtered = filtered
                        .where((i) => i.name.toLowerCase().contains(q))
                        .toList();
                  }
                  return Column(
                    children: [
                      _buildSummaryRow(items),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmpty()
                            : _buildTable(filtered),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Management',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track chairs, tables, flowers, lights & equipment',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _addItemDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final cats = [null, ...InventoryCategory.values];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Low Stock Only'),
            selected: _lowStockOnly,
            onSelected: (v) => setState(() => _lowStockOnly = v),
            selectedColor: Colors.red.withValues(alpha: 0.15),
            checkmarkColor: Colors.red,
            labelStyle: TextStyle(
              color: _lowStockOnly ? Colors.red : const Color(0xFF6B7280),
              fontSize: 12,
            ),
            side: BorderSide(
              color: _lowStockOnly ? Colors.red : const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cats.map((c) {
                  final label = c == null ? 'All' : _catLabel(c);
                  final color = c == null
                      ? const Color(0xFF6B7280)
                      : _catColor(c);
                  final selected = _categoryFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _categoryFilter = c),
                      selectedColor: color.withValues(alpha: 0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        color: selected ? color : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: selected ? color : const Color(0xFFE5E7EB),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(List<DcInventoryItem> items) {
    final totalItems = items.length;
    final lowStock = items.where((i) => i.isLowStock).length;
    final totalValue = items.fold<double>(
      0,
      (s, i) => s + (i.availableQty * i.purchasePrice),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _summaryChip('Total Items', '$totalItems', const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          _summaryChip('Low Stock', '$lowStock', Colors.red),
          const SizedBox(width: 12),
          _summaryChip(
            'Stock Value',
            '₹${(totalValue / 1000).toStringAsFixed(1)}K',
            const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<DcInventoryItem> items) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      'Item Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Total Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Purchase Price',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Rental Price',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Actions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...items.asMap().entries.map((entry) {
              final i = entry.value;
              final idx = entry.key;
              return Column(
                children: [
                  if (idx > 0) const Divider(height: 1),
                  Container(
                    color: i.isLowStock
                        ? Colors.red.withValues(alpha: 0.03)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Row(
                            children: [
                              if (i.isLowStock)
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              if (i.isLowStock) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  i.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _catColor(
                                i.category,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              i.categoryLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: _catColor(i.category),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '${i.totalQty} ${i.unit}',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '${i.availableQty} ${i.unit}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: i.isLowStock
                                  ? Colors.red
                                  : const Color(0xFF059669),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            '₹${i.purchasePrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            '₹${i.rentalPrice.toStringAsFixed(0)}/event',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: i.isLowStock
                              ? const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Low Stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Color(0xFF059669),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'In Stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              _actionIcon(
                                Icons.add_rounded,
                                Colors.green,
                                () => _adjustStock(i, 1),
                                'Increase stock',
                              ),
                              const SizedBox(width: 4),
                              _actionIcon(
                                Icons.remove_rounded,
                                Colors.orange,
                                () => _adjustStock(i, -1),
                                'Decrease stock',
                              ),
                              const SizedBox(width: 4),
                              _actionIcon(
                                Icons.edit_rounded,
                                const Color(0xFF6B7280),
                                () {},
                                'Edit item',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    Color color,
    VoidCallback onTap,
    String label,
  ) {
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Future<void> _adjustStock(DcInventoryItem item, int delta) async {
    await ref.read(dcRepositoryProvider).adjustInventory(item.id, delta);
    ref.invalidate(dcInventoryProvider);
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFD1D5DB)),
          SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  void _addItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final totalQtyCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final rentalPriceCtrl = TextEditingController();
    InventoryCategory category = InventoryCategory.furniture;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Add Inventory Item'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Item Name'),
                const SizedBox(height: 12),
                DropdownButtonFormField<InventoryCategory>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: InventoryCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            DcInventoryItem(
                              id: '',
                              name: '',
                              category: c,
                              totalQty: 0,
                              availableQty: 0,
                              purchasePrice: 0,
                              rentalPrice: 0,
                            ).categoryLabel,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        totalQtyCtrl,
                        'Total Qty',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        purchasePriceCtrl,
                        'Purchase Price (₹)',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        rentalPriceCtrl,
                        'Rental Price (₹)',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final qty = int.tryParse(totalQtyCtrl.text) ?? 0;
                await ref
                    .read(dcRepositoryProvider)
                    .createInventoryItem(
                      DcInventoryItem(
                        id: 'I${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text,
                        category: category,
                        totalQty: qty,
                        availableQty: qty,
                        purchasePrice:
                            double.tryParse(purchasePriceCtrl.text) ?? 0,
                        rentalPrice: double.tryParse(rentalPriceCtrl.text) ?? 0,
                      ),
                    );
                ref.invalidate(dcInventoryProvider);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  TextField _field(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  String _catLabel(InventoryCategory c) {
    return DcInventoryItem(
      id: '',
      name: '',
      category: c,
      totalQty: 0,
      availableQty: 0,
      purchasePrice: 0,
      rentalPrice: 0,
    ).categoryLabel;
  }

  Color _catColor(InventoryCategory c) {
    const map = {
      InventoryCategory.furniture: Color(0xFF2563EB),
      InventoryCategory.lighting: Color(0xFFD97706),
      InventoryCategory.flowers: Color(0xFFEC4899),
      InventoryCategory.fabric: Color(0xFF7C3AED),
      InventoryCategory.utensils: Color(0xFF059669),
      InventoryCategory.sound: Color(0xFF0891B2),
      InventoryCategory.gasItems: Color(0xFFDC2626),
      InventoryCategory.miscellaneous: Color(0xFF6B7280),
    };
    return map[c] ?? const Color(0xFF6B7280);
  }
}
