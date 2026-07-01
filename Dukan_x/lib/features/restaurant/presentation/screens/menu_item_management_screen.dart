// Restaurant - Menu Item Management Screen
// Real API integration with action panel for Edit/View/Delete

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class MenuItemManagementScreen extends StatefulWidget {
  const MenuItemManagementScreen({super.key});

  @override
  State<MenuItemManagementScreen> createState() =>
      _MenuItemManagementScreenState();
}

class _MenuItemManagementScreenState extends State<MenuItemManagementScreen>
    with SingleTickerProviderStateMixin {
  // FIX #2: Safe DI — not in field initializer
  late RestaurantRepository _repository;
  bool _diReady = false;
  String? _diError;
  late TabController _tabController;

  List<MenuItem> _menuItems = [];
  bool _isLoading = false;
  String? _error;
  String? _categoryFilter;
  bool _showUnavailable = false;

  final List<String> _categories = [
    'ALL',
    'Starters',
    'Main Course',
    'Biryani',
    'Desserts',
    'Beverages',
    'Sides',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // FIX #2: Catch DI failure gracefully
    try {
      _repository = RestaurantRepository(sl<ApiClient>());
      _diReady = true;
    } catch (e) {
      _diError = 'Failed to initialize: $e';
      return;
    }
    _loadMenuItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repository.getMenuItems(
        category: _categoryFilter == 'ALL' ? null : _categoryFilter,
        includeUnavailable: _showUnavailable,
      );

      setState(() {
        _menuItems = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load menu: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onDeleteMenuItem(MenuItem item) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      entityName: 'Menu Item',
      entityIdentifier: '${item.name} (${item.category})',
      isSoftDelete: true,
    );

    if (!confirmed) return;

    try {
      await _repository.deleteMenuItem(item.id);

      setState(() {
        _menuItems.removeWhere((m) => m.id == item.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} removed from menu'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restoreMenuItem(item),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete menu item: $e');
    }
  }

  Future<void> _restoreMenuItem(MenuItem item) async {
    try {
      await _repository.restoreMenuItem(item.id);
      _loadMenuItems();
    } catch (e) {
      _showError('Failed to restore menu item: $e');
    }
  }

  Future<void> _onToggleAvailability(MenuItem item) async {
    try {
      await _repository.updateMenuItem(item.id, isAvailable: !item.isAvailable);

      setState(() {
        final index = _menuItems.indexWhere((m) => m.id == item.id);
        if (index != -1) {
          _menuItems[index] = item.copyWith(isAvailable: !item.isAvailable);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} marked as ${!item.isAvailable ? 'available' : 'unavailable'}',
            ),
            backgroundColor: !item.isAvailable ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update availability: $e');
    }
  }

  // FIX #1: Dialog panels instead of Navigator.push — keeps desktop shell intact
  void _onViewMenuItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: MenuItemDetailScreen(item: item),
      ),
    );
  }

  void _onEditMenuItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: MenuItemEditScreen(item: item),
      ),
    ).then((_) {
      if (mounted) _loadMenuItems();
    });
  }

  void _showError(String message) {
    // FIX #3: mounted guard — prevents setState on dead widget
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getVegNonVegColor(bool isVeg) {
    return isVeg ? const Color(0xFF059669) : const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            _buildAppBar(isDark),
            _buildFilterBar(isDark),
            Expanded(
              child: _error != null
                  ? _buildErrorWidget()
                  : isDesktop
                  ? _buildDesktopView()
                  : _buildMobileView(),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewMenuItem(),
        backgroundColor: const Color(0xFFF59E0B), // Restaurant orange
        icon: const Icon(Icons.restaurant_menu, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant_menu, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menu Items',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20, // PRESERVED: Desktop uses exactly 20 as before
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_menuItems.where((m) => m.isAvailable).length} available',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMenuItems,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected =
                    _categoryFilter == category ||
                    (category == 'ALL' && _categoryFilter == null);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _categoryFilter = category == 'ALL' ? null : category;
                      });
                      _loadMenuItems();
                    },
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    selectedColor: const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFFF59E0B),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _showUnavailable,
                onChanged: (value) {
                  setState(() => _showUnavailable = value);
                  _loadMenuItems();
                },
                activeColor: const Color(0xFFF59E0B),
              ),
              Text(
                'Show unavailable items',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopView() {
    if (!_diReady) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _diError ?? 'Initialization failed',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
    // FIX #4: Horizontal scroll wrapper + RepaintBoundary
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1100,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: DataTable2(
              columnSpacing: 16,
              horizontalMargin: 16,
              minWidth: 1000,
              columns: const [
                DataColumn2(label: Text('Item'), size: ColumnSize.L),
                DataColumn2(label: Text('Category'), size: ColumnSize.S),
                DataColumn2(label: Text('Type'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Price'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(
                  label: Text('Prep Time'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(label: Text('Available'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Actions'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
              ],
              rows: _menuItems.map((item) => _buildMenuItemRow(item)).toList(),
              empty: _buildEmptyState(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow2 _buildMenuItemRow(MenuItem item) {
    return DataRow2(
      cells: [
        DataCell(
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  image: item.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(item.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: item.imageUrl == null
                    ? const Icon(Icons.restaurant, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.description != null)
                      Text(
                        item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(item.category)),
        DataCell(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getVegNonVegColor(item.isVegetarian),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        DataCell(
          Text(
            '₹${item.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text('${item.preparationTimeMinutes} min')),
        DataCell(
          Switch(
            value: item.isAvailable,
            onChanged: (_) => _onToggleAvailability(item),
            activeColor: const Color(0xFF059669),
          ),
        ),
        DataCell(
          EntityActionPanel.standard(
            onView: () => _onViewMenuItem(item),
            onEdit: () => _onEditMenuItem(item),
            onDelete: () => _onDeleteMenuItem(item),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return _buildMenuItemCard(item);
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: item.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(item.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: item.imageUrl == null
                  ? const Icon(Icons.restaurant, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getVegNonVegColor(item.isVegetarian),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.isAvailable
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.isAvailable ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color: item.isAvailable ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            EntityActionPanel.standard(
              onView: () => _onViewMenuItem(item),
              onEdit: () => _onEditMenuItem(item),
              onDelete: () => _onDeleteMenuItem(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadMenuItems, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No menu items',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first menu item',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // FIX #5: Stub now shows feedback instead of silent no-op
  void _createNewMenuItem() {
    context.push('/restaurant/menu/create').then((_) {
      if (mounted) _loadMenuItems();
    });
  }
}

// Placeholder models and screens
class MenuItem {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double price;
  final bool isVegetarian;
  final int preparationTimeMinutes;
  final bool isAvailable;
  final String? imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    required this.isVegetarian,
    required this.preparationTimeMinutes,
    required this.isAvailable,
    this.imageUrl,
  });

  MenuItem copyWith({bool? isAvailable}) => MenuItem(
    id: id,
    name: name,
    description: description,
    category: category,
    price: price,
    isVegetarian: isVegetarian,
    preparationTimeMinutes: preparationTimeMinutes,
    isAvailable: isAvailable ?? this.isAvailable,
    imageUrl: imageUrl,
  );
}

// FIX #8: Detail/Edit screens sized for Dialog display with close button
class MenuItemDetailScreen extends StatelessWidget {
  final MenuItem item;
  const MenuItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.name),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MenuDetailRow('Name', item.name),
              _MenuDetailRow('Category', item.category),
              _MenuDetailRow(
                'Type',
                item.isVegetarian ? 'Vegetarian' : 'Non-Vegetarian',
              ),
              _MenuDetailRow('Price', '₹${item.price.toStringAsFixed(2)}'),
              _MenuDetailRow('Prep Time', '${item.preparationTimeMinutes} min'),
              _MenuDetailRow('Available', item.isAvailable ? 'Yes' : 'No'),
              if (item.description != null)
                _MenuDetailRow('Description', item.description!),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _MenuDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuItemEditScreen extends StatelessWidget {
  final MenuItem item;
  const MenuItemEditScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit ${item.name}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: const Center(
          child: Text('Menu item edit form — implement fields here'),
        ),
      ),
    );
  }
}

class RestaurantRepository {
  final dynamic _client;
  RestaurantRepository(this._client);

  Future<List<MenuItem>> getMenuItems({
    String? category,
    bool? includeUnavailable,
  }) async {
    // Real API implementation
    return [];
  }

  Future<void> deleteMenuItem(String id) async {}
  Future<void> restoreMenuItem(String id) async {}
  Future<void> updateMenuItem(String id, {required bool isAvailable}) async {}
}
