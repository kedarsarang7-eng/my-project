import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/purchase_repository.dart' as repo;
import '../../../../providers/app_state_providers.dart';
import '../../../widgets/desktop/desktop_content_container.dart';
import '../../../widgets/desktop/empty_state.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'package:dukanx/widgets/responsive/overflow_safe.dart';

// Simple model for Buy Order (Local only for now, or lightweight cloud)

class BuyOrdersScreen extends ConsumerStatefulWidget {
  const BuyOrdersScreen({super.key});

  @override
  ConsumerState<BuyOrdersScreen> createState() => _BuyOrdersScreenState();
}

class _BuyOrdersScreenState extends ConsumerState<BuyOrdersScreen> {
  final _session = sl<SessionManager>();
  // Using a sub-collection for orders just for this screen

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'Buy Orders (PO)',
      actions: [
        DesktopActionButton(
          icon: Icons.add,
          label: 'New Order',
          onPressed: _createNewOrder,
        ),
      ],
      child: StreamBuilder<List<repo.PurchaseOrder>>(
        stream: sl<repo.PurchaseRepository>().watchAll(
          userId: _session.ownerId ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: EmptyStateWidget(
                icon: Icons.assignment_add,
                title: 'No Purchase Orders',
                description: 'Create your first purchase order to get started.',
                buttonLabel: 'Create PO',
                onButtonPressed: _createNewOrder,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _PurchaseOrderCard(
                order: order,
                isDark: isDark,
                onConvert: _convertToStock,
              );
            },
          );
        },
      ),
    );
  }

  void _createNewOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _CreateOrderScreen()),
    );
  }

  void _convertToStock(String orderId) async {
    final result = await sl<repo.PurchaseRepository>().completePurchaseOrder(
      id: orderId,
      userId: _session.ownerId ?? '',
    );
    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order converted to Stock")),
        );
      }
    }
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  final repo.PurchaseOrder order;
  final bool isDark;
  final Function(String) onConvert;

  const _PurchaseOrderCard({
    required this.order,
    required this.isDark,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final total = order.totalAmount;
    final vendorName = order.vendorName ?? 'Unknown';

    Color statusColor;
    if (status == 'PENDING') {
      statusColor = Colors.blue;
    } else if (status == 'COMPLETED') {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "${order.items.length} Items",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Est. Total: \u20B9${total.toStringAsFixed(2)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (status == 'PENDING')
                OutlinedButton(
                  onPressed: () => onConvert(order.id),
                  child: const Text("Convert to Stock Entry"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateOrderScreen extends ConsumerStatefulWidget {
  const _CreateOrderScreen();

  @override
  ConsumerState<_CreateOrderScreen> createState() => __CreateOrderScreenState();
}

class __CreateOrderScreenState extends ConsumerState<_CreateOrderScreen> {
  final _vendorCtrl = TextEditingController();
  final List<repo.PurchaseItem> _items = [];
  String? _selectedVendorId;
  bool _isSaving = false;
  String _selectedSection = 'Vendor Details';

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'New Purchase Order',
      child: context.isMobile
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVendorDetailsSection(isDark),
                  const SizedBox(height: 16),
                  _buildItemsSection(isDark),
                ],
              ),
            )
          : Row(
              // PRESERVED: Desktop two-column Row(flex:4, flex:6) layout unchanged
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _buildVendorDetailsSection(isDark)),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: _buildItemsSection(isDark, useExpanded: true),
                ),
              ],
            ),
    );
  }

  /// Builds the vendor details section (left column on desktop, top section on mobile).
  Widget _buildVendorDetailsSection(bool isDark) {
    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section selector dropdown — isExpanded prevents label truncation
          DropdownButton<String>(
            value: _selectedSection,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
              ),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            items: const [
              DropdownMenuItem(
                value: 'Vendor Details',
                child: Text('Vendor Details'),
              ),
              DropdownMenuItem(
                value: 'Payment Info',
                child: Text('Payment Info'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedSection = value);
              }
            },
          ),
          const SizedBox(height: 16),
          if (_selectedSection == 'Vendor Details') ...[
            TextField(
              controller: _vendorCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Vendor Name",
                hintText: "Type vendor name...",
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Mode: Cash / Credit',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: PENDING',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const OverflowSafeInfoBanner(
            icon: Icons.info,
            message:
                'Purchase Orders are created as PENDING. You can convert them to Stock Entries later.',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  /// Builds the items section (right column on desktop, bottom section on mobile).
  /// When [useExpanded] is true, the items list uses Expanded (for desktop Row context).
  /// On mobile (useExpanded = false), uses a SizedBox with fixed height instead.
  Widget _buildItemsSection(bool isDark, {bool useExpanded = false}) {
    final itemsList = _items.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No items added",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : ListView.separated(
            shrinkWrap: !useExpanded,
            physics: useExpanded ? null : const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _items[i].productName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                "Qty: ${_items[i].quantity} \u00D7 \u20B9${_items[i].costPrice}",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "\u20B9${_items[i].totalAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                ],
              ),
            ),
          );

    return Container(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Order Items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddItemDialog(context, isDark),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // On desktop, use Expanded to fill available space.
          // On mobile, use ConstrainedBox with a fixed min height (no Expanded in scrollable Column).
          if (useExpanded)
            Expanded(child: itemsList)
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
              child: itemsList,
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: responsiveValue<double>(
                      context,
                      mobile: 14.0,
                      tablet: 16.0,
                      desktop:
                          18.0, // PRESERVED: Desktop uses exactly 18 as before
                    ),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                '\u20B9${_items.fold<double>(0, (sum, i) => sum + i.totalAmount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 24,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Create Purchase Order",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context, bool isDark) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Add Item',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Item Name',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Quantity',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Price',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _items.add(
                    repo.PurchaseItem(
                      id: const Uuid().v4(),
                      productName: nameCtrl.text,
                      quantity: double.tryParse(qtyCtrl.text) ?? 1,
                      costPrice: double.tryParse(priceCtrl.text) ?? 0,
                      totalAmount:
                          (double.tryParse(qtyCtrl.text) ?? 1) *
                          (double.tryParse(priceCtrl.text) ?? 0),
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _saveOrder() async {
    if (_vendorCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter vendor name")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one item")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ownerId = sl<SessionManager>().ownerId ?? '';
      final total = _items.fold<double>(0, (sum, i) => sum + i.totalAmount);

      await sl<repo.PurchaseRepository>().createPurchaseOrder(
        userId: ownerId,
        vendorName: _vendorCtrl.text,
        vendorId: _selectedVendorId,
        totalAmount: total,
        status: 'PENDING',
        items: _items,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving order: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
