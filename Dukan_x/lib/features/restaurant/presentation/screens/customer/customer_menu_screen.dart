// ============================================================================
// CUSTOMER MENU SCREEN
// ============================================================================
// Accessed by customer through QR code scan

import 'package:flutter/material.dart';
import '../../../../../core/theme/futuristic_colors.dart';
import '../../../data/models/food_menu_item_model.dart';
import '../../../data/models/food_category_model.dart';
import '../../../data/models/food_order_model.dart';
import 'order_tracking_screen.dart';
import '../../../data/repositories/food_menu_repository.dart';
import '../../../data/repositories/food_order_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerMenuScreen extends StatefulWidget {
  final String vendorId;
  final String? tableId;
  final String? tableNumber;
  final String customerId;

  const CustomerMenuScreen({
    super.key,
    required this.vendorId,
    this.tableId,
    this.tableNumber,
    required this.customerId,
  });

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  final FoodMenuRepository _menuRepo = FoodMenuRepository();
  final FoodOrderRepository _orderRepo = FoodOrderRepository();

  List<FoodCategory> _categories = [];
  List<FoodMenuItem> _menuItems = [];
  final Map<String, int> _cart = {}; // itemId -> quantity
  String? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categoriesResult = await _menuRepo.getCategoriesByVendor(
      widget.vendorId,
    );
    final menuResult = await _menuRepo.getAvailableItems(widget.vendorId);

    setState(() {
      _categories = categoriesResult.data ?? [];
      _menuItems = menuResult.data ?? [];
      _isLoading = false;
    });
  }

  List<FoodMenuItem> get _filteredItems {
    if (_selectedCategoryId == null) return _menuItems;
    return _menuItems
        .where((i) => i.categoryId == _selectedCategoryId)
        .toList();
  }

  int get _cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final item = _menuItems.firstWhere((i) => i.id == entry.key);
      total += item.price * entry.value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // App bar with restaurant info
                SliverAppBar(
                  expandedHeight: 150,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.tableNumber != null
                          ? 'Table ${widget.tableNumber}'
                          : 'Menu',
                      style: const TextStyle(color: Colors.white),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primaryContainer,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Categories
                SliverToBoxAdapter(child: _buildCategoryChips()),
                // Popular section
                if (_selectedCategoryId == null)
                  SliverToBoxAdapter(child: _buildPopularSection()),
                // Menu items grid
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildMenuItemCard(_filteredItems[index]),
                      childCount: _filteredItems.length,
                    ),
                  ),
                ),
                // Bottom padding for cart button
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
      // Cart button
      ),

      floatingActionButton: _cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: _showCart,
              icon: Badge(
                label: Text('$_cartItemCount'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: Text('â‚¹${_cartTotal.toStringAsFixed(0)}'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _selectedCategoryId == null,
              onSelected: (_) => setState(() => _selectedCategoryId = null),
            ),
            const SizedBox(width: 8),
            ..._categories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat.name),
                  selected: _selectedCategoryId == cat.id,
                  onSelected: (_) =>
                      setState(() => _selectedCategoryId = cat.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    final popularItems = _menuItems.where((i) => i.isPopular).take(5).toList();
    if (popularItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Popular', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: popularItems.length,
            itemBuilder: (context, index) => SizedBox(
              width: 150,
              child: _buildMenuItemCard(popularItems[index]),
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildMenuItemCard(FoodMenuItem item) {
    final quantity = _cart[item.id] ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
                // Dietary badges
                Positioned(
                  top: 4,
                  left: 4,
                  child: Row(
                    children: [
                      if (item.isVegetarian)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.eco,
                            size: 16,
                            color: FuturisticColors.success,
                          ),
                        ),
                      if (item.isSpicy)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ðŸŒ¶ï¸',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'â‚¹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      // Add to cart button
                      quantity == 0
                          ? InkWell(
                              onTap: () => _addToCart(item.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _removeFromCart(item.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text('$quantity'),
                                ),
                                InkWell(
                                  onTap: () => _addToCart(item.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.restaurant, size: 40),
    );
  }

  void _addToCart(String itemId) {
    setState(() {
      _cart[itemId] = (_cart[itemId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      final current = _cart[itemId] ?? 0;
      if (current <= 1) {
        _cart.remove(itemId);
      } else {
        _cart[itemId] = current - 1;
      }
    });
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                'Your Order',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              // Cart items
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _cart.entries.map((entry) {
                    final item = _menuItems.firstWhere(
                      (i) => i.id == entry.key,
                    );
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('â‚¹${item.price} Ã— ${entry.value}'),
                      trailing: Text(
                        'â‚¹${(item.price * entry.value).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'â‚¹${_cartTotal.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Place order button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _placeOrder,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('PLACE ORDER'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    // Build order items
    final orderItems = _cart.entries.map((entry) {
      final item = _menuItems.firstWhere((i) => i.id == entry.key);
      return OrderItem(
        menuItemId: item.id,
        itemName: item.name,
        quantity: entry.value,
        unitPrice: item.price,
        totalPrice: item.price * entry.value,
      );
    }).toList();

    final result = await _orderRepo.createOrder(
      vendorId: widget.vendorId,
      customerId: widget.customerId,
      orderType: widget.tableNumber != null
          ? OrderType.dineIn
          : OrderType.takeaway,
      items: orderItems,
      tableId: widget.tableId,
      tableNumber: widget.tableNumber,
    );

    if (result.success && mounted) {
      Navigator.of(context).pop(); // Close bottom sheet
      setState(() => _cart.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed successfully!'),
          backgroundColor: FuturisticColors.success,
        ),
      );

      // Navigate to order tracking
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OrderTrackingScreen(orderId: 'temp_id'),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: ${result.errorMessage}'),
          backgroundColor: FuturisticColors.error,
        ),
      );
    }
  }
}
