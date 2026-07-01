import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stock_item.dart';
import '../../core/repository/products_repository.dart';
import '../../core/di/service_locator.dart';
import '../../providers/app_state_providers.dart';

// Fixed Stock Picker implementing Clean Architecture & Theme
class StockProductPicker extends ConsumerStatefulWidget {
  final String ownerId;
  final bool selectProductOnly;

  const StockProductPicker({
    super.key,
    required this.ownerId,
    this.selectProductOnly = false,
  });

  @override
  ConsumerState<StockProductPicker> createState() => _StockProductPickerState();
}

class _StockProductPickerState extends ConsumerState<StockProductPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: palette.leafGreen),
                const SizedBox(width: 12),
                Text(
                  'Select Product',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : palette.mutedGray,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white54 : palette.darkGray,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search by Name or SKU...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : palette.offWhite, // Use palette offWhite
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: sl<ProductsRepository>().watchAll(userId: widget.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: palette.tomatoRed),
                    ),
                  );
                }

                // Convert Product to StockItem
                final products = snapshot.data ?? [];

                final items = products
                    .map(
                      (p) => StockItem(
                        id: p.id,
                        name: p.name,
                        sku: p.sku ?? '',
                        quantity: p.stockQuantity,
                        sellingPrice: p.sellingPrice,
                        unit: p.unit,
                        ownerId: widget.ownerId,
                        lowStockThreshold: p.lowStockThreshold,
                      ),
                    )
                    .where((item) {
                      final matchesName = item.name.toLowerCase().contains(
                        _searchQuery,
                      );
                      final matchesSku = item.sku.toLowerCase().contains(
                        _searchQuery,
                      );
                      return matchesName || matchesSku;
                    })
                    .toList();

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: palette.darkGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            color: palette.darkGray,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: palette.darkGray.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isOutOfStock = item.quantity <= 0;
                    final canInteract =
                        widget.selectProductOnly || !isOutOfStock;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isOutOfStock
                            ? palette.tomatoRed.withOpacity(0.1)
                            : palette.leafGreen.withOpacity(0.1),
                        child: Text(
                          item.name.isNotEmpty
                              ? item.name.characters.first.toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isOutOfStock
                                ? palette.tomatoRed
                                : palette.leafGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock
                              ? palette.darkGray
                              : (isDark ? Colors.white : palette.mutedGray),
                          decoration:
                              (isOutOfStock && !widget.selectProductOnly)
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: palette.darkGray,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.sku.isNotEmpty)
                            Text(
                              'SKU: ${item.sku}',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.darkGray,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${item.sellingPrice.toStringAsFixed(2)} / ${item.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white70
                                      : palette.mutedGray,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isOutOfStock
                                      ? palette.tomatoRed
                                      : palette.leafGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOutOfStock
                                      ? 'No Stock'
                                      : '${item.quantity} ${item.unit} left',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: widget.selectProductOnly
                          ? Icon(
                              Icons.touch_app,
                              color: palette.leafGreen.withOpacity(0.8),
                            )
                          : (isOutOfStock
                                ? null
                                : IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: palette.leafGreen,
                                      size: 32,
                                    ),
                                    onPressed: () => _showQuantityDialog(item),
                                  )),
                      onTap: canInteract
                          ? () {
                              if (widget.selectProductOnly) {
                                Navigator.pop(context, item);
                              } else {
                                _showQuantityDialog(item);
                              }
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StockQuantityDialog(item: item),
    ).then((result) {
      if (result != null) {
        // Return result to parent
        Navigator.pop(context, result);
      }
    });
  }
}

class _StockQuantityDialog extends ConsumerStatefulWidget {
  final StockItem item;

  const _StockQuantityDialog({required this.item});

  @override
  ConsumerState<_StockQuantityDialog> createState() =>
      _StockQuantityDialogState();
}

class _StockQuantityDialogState extends ConsumerState<_StockQuantityDialog> {
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(); // Allow price override
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.item.sellingPrice.toString();
  }

  void _validate(String value) {
    final qty = double.tryParse(value);
    if (qty == null) return;

    if (qty > widget.item.quantity) {
      setState(
        () => _errorText =
            '⚠️ Only ${widget.item.quantity} ${widget.item.unit} available',
      );
    } else {
      setState(() => _errorText = null);
    }
  }

  void _submit() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    if (qty <= 0) {
      setState(() => _errorText = 'Enter valid quantity');
      return;
    }

    if (qty > widget.item.quantity) {
      setState(() => _errorText = 'Stock insufficient');
      return;
    }

    Navigator.pop(context, {
      'stockItem': widget.item,
      'qty': qty,
      'price': price,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final palette = theme.palette;
    final isDark = theme.isDark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add ${widget.item.name}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : palette.mutedGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Available Stock: ${widget.item.quantity} ${widget.item.unit}',
            style: TextStyle(
              color: palette.leafGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  onChanged: _validate,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${widget.item.unit})',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : palette.darkGray,
                    ),
                    errorText: _errorText,
                    errorStyle: TextStyle(color: palette.tomatoRed),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : palette.darkGray,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.scale,
                      color: isDark ? Colors.white54 : palette.darkGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : palette.darkGray,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : palette.darkGray,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.currency_rupee,
                      color: isDark ? Colors.white54 : palette.darkGray,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _errorText == null ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.leafGreen,
                disabledBackgroundColor: palette.darkGray.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Add to Bill',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
