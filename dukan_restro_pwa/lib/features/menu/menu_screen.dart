// ============================================================================
// MENU SCREEN — Category tabs + item cards with cart badge
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/pwa_api_service.dart';
import '../../providers/pwa_providers.dart';
import '../../utils/pwa_haptics.dart';
import '../../widgets/pwa_offline_banner.dart';
import '../../widgets/pwa_state_widgets.dart';

class MenuScreen extends ConsumerStatefulWidget {
  final String vendorId;
  final String tableId;
  const MenuScreen({super.key, required this.vendorId, required this.tableId});
  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  List<PwaCategory> _menu = [];
  bool _isLoading = true;
  TabController? _tabs;
  static const _orange = Color(0xFFEA580C);

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    final menu = await PwaApiService.fetchMenu(widget.vendorId);
    if (mounted) {
      setState(() {
        _menu = menu;
        _tabs?.dispose();
        _tabs = menu.isEmpty ? null : TabController(length: menu.length, vsync: this);
        _isLoading = false;
      });
    }
  }

  void _addToCart(PwaMenuItem item, {String? variation}) {
    ref
        .read(pwaCartProvider.notifier)
        .add(
          PwaCartItem(
            menuItemId: item.id,
            name: item.name + (variation != null ? ' ($variation)' : ''),
            price: item.price,
            qty: 1,
            isVeg: item.isVeg,
          ),
        );
  }

  void _showVariations(PwaMenuItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ...item.variations.map(
              (v) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(v, style: const TextStyle(color: Colors.white)),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addToCart(item, variation: v);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(pwaCartProvider);
    final cartCount = cart.fold(0, (s, i) => s + i.qty);
    final cartTotal = cart.fold(0.0, (s, i) => s + i.price * i.qty);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: _tabs == null
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                indicatorColor: _orange,
                labelColor: _orange,
                unselectedLabelColor: Colors.grey,
                tabs: _menu.map((c) => Tab(text: c.name)).toList(),
              ),
      ),
      body: _isLoading
          ? const Column(
              children: [
                PwaOfflineBanner(),
                Expanded(child: PwaSkeletonList()),
              ],
            )
          : Column(
              children: [
                const PwaOfflineBanner(),
                Expanded(
                  child: _menu.isEmpty
                      ? PwaErrorState(
                          title: 'Menu unavailable',
                          subtitle: 'Could not load menu now.',
                          onRetry: _loadMenu,
                        )
                      : TabBarView(
                          controller: _tabs!,
                          children: _menu.map((cat) => _buildCategoryList(cat)).toList(),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: cartCount == 0
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: const Border(top: BorderSide(color: Color(0xFF2E2E2E))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await PwaHaptics.tap();
                  if (!context.mounted) return;
                  context.push(
                    '/bag',
                    extra: {
                      'vendorId': widget.vendorId,
                      'tableId': widget.tableId,
                    },
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$cartCount items',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      'View Order Bag',
                      style: TextStyle(fontSize: 15),
                    ),
                    Text(
                      '₹${cartTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryList(PwaCategory cat) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cat.items.length,
      itemBuilder: (ctx, i) => _buildItemCard(cat.items[i]),
    );
  }

  Widget _buildItemCard(PwaMenuItem item) {
    final cart = ref.watch(pwaCartProvider);
    final inCart = cart
        .where((c) => c.menuItemId == item.id)
        .fold(0, (s, c) => s + c.qty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inCart > 0
              ? _orange.withValues(alpha: 0.4)
              : const Color(0xFF2E2E2E),
        ),
      ),
      child: Row(
        children: [
          // Veg/Non-veg indicator
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg ? Colors.green : Colors.red,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: item.isVeg ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Add button or qty counter
          if (inCart == 0)
            GestureDetector(
              onTap: () async {
                await PwaHaptics.tap();
                if (item.variations.isNotEmpty) {
                  _showVariations(item);
                } else {
                  _addToCart(item);
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _orange.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.add, color: _orange, size: 20),
              ),
            )
          else
            Row(
              children: [
                _qtyBtn(Icons.remove, () {
                  PwaHaptics.tap();
                  ref.read(pwaCartProvider.notifier).decrementById(item.id);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '$inCart',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _qtyBtn(Icons.add, () {
                  PwaHaptics.tap();
                  if (item.variations.isNotEmpty) {
                    _showVariations(item);
                  } else {
                    _addToCart(item);
                  }
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFEA580C).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFEA580C), size: 16),
      ),
    );
  }
}
