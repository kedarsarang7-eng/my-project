import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/customer_item_request_repository.dart';
import '../../data/repositories/vendor_item_snapshot_repository.dart';
import '../../models/customer_item_request.dart';
import '../../models/vendor_item_snapshot.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Futuristic Stock Status Badge Widget
class StockBadge extends StatelessWidget {
  final StockStatus status;
  final double? stockQty;

  const StockBadge({required this.status, this.stockQty, super.key});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case StockStatus.outOfStock:
        label = 'OUT OF STOCK';
        bgColor = const Color(0x30FF1744);
        textColor = const Color(0xFFFF1744);
        icon = Icons.block;
        break;
      case StockStatus.lowStock:
        label = stockQty != null
            ? 'Only ${stockQty!.toInt()} left'
            : 'LOW STOCK';
        bgColor = const Color(0x30FFAB00);
        textColor = const Color(0xFFFFAB00);
        icon = Icons.warning_amber_rounded;
        break;
      case StockStatus.inStock:
        label = 'IN STOCK';
        bgColor = const Color(0x3000E676);
        textColor = const Color(0xFF00E676);
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Futuristic Product Card using SnapshotItem
class SnapshotProductCard extends StatelessWidget {
  final SnapshotItem item;
  final VoidCallback onAdd;

  const SnapshotProductCard({
    required this.item,
    required this.onAdd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = !item.isAvailable;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOutOfStock
              ? Colors.red.withOpacity(0.3)
              : Colors.cyan.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (isOutOfStock ? Colors.red : Colors.cyan).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isOutOfStock ? null : onAdd,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white54,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${item.price.toStringAsFixed(2)} / ${item.unit}',
                        style: TextStyle(
                          color: Colors.cyan[200],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StockBadge(
                        status: item.stockStatus,
                        stockQty: item.stockQty,
                      ),
                    ],
                  ),
                ),
                // Add Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOutOfStock
                        ? Colors.grey.withOpacity(0.2)
                        : Colors.cyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOutOfStock
                          ? Colors.grey.withOpacity(0.3)
                          : Colors.cyan.withOpacity(0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.add_shopping_cart,
                    color: isOutOfStock ? Colors.grey : Colors.cyan,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Main Vendor Catalog Screen (10M+ Scale - Cache First)
class VendorCatalogScreen extends StatefulWidget {
  final String vendorId;
  final String customerId;

  const VendorCatalogScreen({
    required this.vendorId,
    required this.customerId,
    super.key,
  });

  @override
  State<VendorCatalogScreen> createState() => _VendorCatalogScreenState();
}

class _VendorCatalogScreenState extends State<VendorCatalogScreen> {
  final VendorItemSnapshotRepository _snapshotRepo =
      sl<VendorItemSnapshotRepository>();
  final CustomerItemRequestRepository _requestRepo =
      sl<CustomerItemRequestRepository>();

  VendorItemSnapshot? _snapshot;
  List<SnapshotItem> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _stockFilter = 'all'; // 'all', 'inStock', 'lowStock'

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _snapshotRepo.getSnapshot(widget.vendorId);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _applyFilters();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSnapshot() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _snapshotRepo.refreshSnapshot(widget.vendorId);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _applyFilters();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    if (_snapshot == null) {
      _filteredItems = [];
      return;
    }

    List<SnapshotItem> filtered = _snapshot!.items;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Stock filter
    if (_stockFilter == 'inStock') {
      filtered = filtered.where((p) => p.isAvailable).toList();
    } else if (_stockFilter == 'lowStock') {
      filtered = filtered
          .where((p) => p.stockStatus == StockStatus.lowStock)
          .toList();
    }

    setState(() => _filteredItems = filtered);
  }

  void _showAddToListDialog(SnapshotItem item) {
    double qty = 1;
    final maxQty = item.stockQty;

    if (context.isDesktop || context.isTablet) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: StatefulBuilder(
              builder: (ctx, setModalState) => _buildAddToListSheetContent(item, qty, maxQty, setModalState, ctx),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => _buildAddToListSheetContent(item, qty, maxQty, setModalState, ctx),
        ),
      );
    }
  }

  Widget _buildAddToListSheetContent(SnapshotItem item, double qty, double maxQty, StateSetter setModalState, BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: (context.isDesktop || context.isTablet)
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!(context.isDesktop || context.isTablet)) ...[
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Product Name
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '₹${item.price.toStringAsFixed(2)} / ${item.unit}',
            style: TextStyle(color: Colors.cyan[200], fontSize: 16),
          ),
          const SizedBox(height: 24),
          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQtyButton(Icons.remove, () {
                if (qty > 1) setModalState(() => qty--);
              }),
              Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  qty.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildQtyButton(Icons.add, () {
                if (qty < maxQty) setModalState(() => qty++);
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Max available: ${maxQty.toInt()} ${item.unit}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange[300],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stock may change before vendor confirmation.',
                    style: TextStyle(
                      color: Colors.orange[200],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Add Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                _addToItemList(item, qty);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ADD TO MY ITEMS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.5)),
          ),
          child: Icon(icon, color: Colors.cyan),
        ),
      ),
    );
  }

  Future<void> _addToItemList(SnapshotItem item, double qty) async {
    final draft = await _requestRepo.getDraft(widget.customerId);
    List<CustomerItemRequestItem> items = draft?.items ?? [];

    final index = items.indexWhere((i) => i.productId == item.itemId);
    if (index != -1) {
      items[index] = items[index].copyWith(
        requestedQty: items[index].requestedQty + qty,
      );
    } else {
      items.add(
        CustomerItemRequestItem(
          productId: item.itemId,
          productName: item.name,
          requestedQty: qty,
          unit: item.unit,
        ),
      );
    }

    final request = CustomerItemRequest(
      id: 'draft',
      customerId: widget.customerId,
      vendorId: widget.vendorId,
      items: items,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: RequestStatus.pending,
    );
    await _requestRepo.saveDraft(request);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} added to your item list!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shop Catalog',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (_snapshot != null)
              Text(
                'Updated ${_formatLastUpdated(_snapshot!.snapshotUpdatedAt)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyan),
            onPressed: _refreshSnapshot,
            tooltip: 'Refresh Stock',
          ),
        ],
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              // Search Bar
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: TextField(
                  onChanged: (v) {
                    _searchQuery = v;
                    _applyFilters();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Stock', 'inStock'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Low Stock', 'lowStock'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Product List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.cyan),
                      )
                    : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No products found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshSnapshot,
                        color: Colors.cyan,
                        child: ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (ctx, i) {
                            final item = _filteredItems[i];
                            return SnapshotProductCard(
                              item: item,
                              onAdd: () => _showAddToListDialog(item),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _stockFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _stockFilter = value);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyan.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyan : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
