// ============================================================================
// TABLE ORDER SCREEN — Menu browser + cart
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pos_providers.dart';
import '../../models/cart_item.dart';
import '../../models/pos_menu_item.dart';
import '../../services/pos_api_service.dart';

class TableOrderScreen extends ConsumerStatefulWidget {
  final String tableId;
  final String tableNumber;
  const TableOrderScreen({
    super.key,
    required this.tableId,
    required this.tableNumber,
  });
  @override
  ConsumerState<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends ConsumerState<TableOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<PosCategory> _menu = [];
  bool _isLoading = true;
  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final session = ref.read(vendorSessionProvider);
    final menu = await PosApiService.fetchMenu(session?.vendorId ?? '');
    if (mounted) {
      setState(() {
        _menu = menu;
        _tabs.dispose();
        _tabs = TabController(length: menu.isEmpty ? 1 : menu.length, vsync: this);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _addToCart(PosMenuItem item, {String? variation}) {
    ref
        .read(cartProvider.notifier)
        .addItem(
          CartItem(
            menuItemId: item.id,
            itemName: item.name + (variation != null ? ' ($variation)' : ''),
            price: item.price,
            qty: 1,
            variationName: variation,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added'),
        duration: const Duration(seconds: 1),
        backgroundColor: _orange,
      ),
    );
  }

  void _showVariationDialog(PosMenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(item.name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: item.variations
              .map(
                (v) => ListTile(
                  title: Text(v, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addToCart(item, variation: v);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Table ${widget.tableNumber}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                indicatorColor: _orange,
                labelColor: _orange,
                unselectedLabelColor: Colors.grey,
                tabs: _menu.map((c) => Tab(text: c.name)).toList(),
              ),
        actions: [
          if (cartCount > 0)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: _orange),
              icon: const Icon(Icons.receipt_long),
              label: Text('KOT ($cartCount items)'),
              onPressed: () => context.push('/kot'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _menu.isEmpty
          ? const Center(
              child: Text('Menu unavailable', style: TextStyle(color: Colors.grey)),
            )
          : Row(
              children: [
                // ── Menu (left 70%) ───────────────────────────────────────
                Expanded(
                  flex: 7,
                  child: TabBarView(
                    controller: _tabs,
                    children: _menu.map((cat) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: cat.items.length,
                        itemBuilder: (ctx, i) => _buildMenuCard(cat.items[i]),
                      );
                    }).toList(),
                  ),
                ),
                // ── Cart panel (right 30%) ────────────────────────────────
                Container(
                  width: 280,
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ORDER',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            if (cart.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    ref.read(cartProvider.notifier).clear(),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF2E2E2E)),
                      Expanded(
                        child: cart.isEmpty
                            ? const Center(
                                child: Text(
                                  'No items added',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: cart.length,
                                itemBuilder: (ctx, i) =>
                                    _buildCartRow(cart[i], i),
                              ),
                      ),
                      const Divider(height: 1, color: Color(0xFF2E2E2E)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '₹${cartTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Punch KOT'),
                                onPressed: cart.isEmpty
                                    ? null
                                    : () => context.push('/kot'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                                icon: const Icon(Icons.call_split, size: 16),
                                label: const Text('Split Bill'),
                                onPressed: () =>
                                    context.push('/split/${widget.tableId}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuCard(PosMenuItem item) {
    return GestureDetector(
      onTap: () {
        if (item.variations.isNotEmpty) {
          _showVariationDialog(item);
        } else {
          _addToCart(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veg/Non-veg indicator
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: item.isVeg ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.isVeg ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (item.variations.isNotEmpty)
                  Icon(Icons.tune, size: 12, color: Colors.grey[600]),
              ],
            ),
            const Spacer(),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: _orange, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartRow(CartItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  '₹${(item.price * item.qty).toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          // Qty controls
          Row(
            children: [
              GestureDetector(
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .updateQty(index, item.qty - 1),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.qty}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => ref
                    .read(cartProvider.notifier)
                    .updateQty(index, item.qty + 1),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, size: 14, color: _orange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
