import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/repository/products_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../services/vendor_profile_service.dart';
import '../models/vendor_profile.dart';
import '../widgets/ui/futuristic_button.dart';
import '../widgets/ui/smart_table.dart';
import '../widgets/ui/quick_action_toolbar.dart';

class BillingFlow extends StatefulWidget {
  const BillingFlow({super.key});

  @override
  State<BillingFlow> createState() => _BillingFlowState();
}

class _BillingFlowState extends State<BillingFlow> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _searchFocus = FocusNode();

  Product? selectedProduct;
  List<BillItem> items = [];
  VendorProfile? _vendorProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      _vendorProfile = await sl<VendorProfileService>().loadProfile();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void addItem() {
    if (selectedProduct == null) return;
    final qty = double.tryParse(qtyController.text.trim()) ?? 0;
    if (qty <= 0) return;

    // Create Item
    final bi = BillItem(
      productId: selectedProduct!.id,
      productName: selectedProduct!.name,
      qty: qty,
      price: selectedProduct!.sellingPrice,
      unit: selectedProduct!.unit,
    );

    setState(() {
      items.add(bi);
      selectedProduct = null;
    });
    qtyController.clear();
    searchController.clear();
    _searchFocus.requestFocus(); // Return focus to search
  }

  double get subtotal => items.fold(0.0, (p, e) => p + e.total);

  Future<void> saveBill() async {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) {
      _showSnack('Error: No active session', isError: true);
      return;
    }

    final bill = Bill(
      id: const Uuid().v4(),
      ownerId: ownerId,
      customerId: 'guest',
      customerName: 'Guest',
      invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      items: items,
      subtotal: subtotal,
      totalTax: 0,
      grandTotal: subtotal,
      paidAmount: 0.0,
      status: 'Unpaid',
      paymentType: 'Cash',
      source: 'POS-DESKTOP',
      shopName: _vendorProfile?.shopName ?? '',
      shopAddress: _vendorProfile?.shopAddress ?? '',
      shopContact: _vendorProfile?.shopMobile ?? '',
      shopGst: _vendorProfile?.gstin ?? '',
    );

    try {
      await sl<BillsRepository>().createBill(bill);
      _showSnack('Bill Saved Successfully! Printing...');
      setState(() {
        items.clear();
      });
    } catch (e) {
      _showSnack('Error saving bill: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? FuturisticColors.error
            : FuturisticColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = sl<SessionManager>().ownerId;

    if (ownerId == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to access POS")),
      );
    }

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: Column(
        children: [
          QuickActionToolbar(
            title: 'Point of Sale',
            searchField: _buildSearchField(),
            actions: [
              Text(
                'Station: DESKTOP-01',
                style: TextStyle(color: FuturisticColors.textSecondary),
              ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANEL: Product Search & Results (40%)
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: FuturisticColors.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (selectedProduct != null)
                          _buildSelectedProductPanel(),
                        Expanded(child: _buildProductList(ownerId)),
                      ],
                    ),
                  ),
                ),

                // RIGHT PANEL: Cart / Bill Items (60%)
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(
                        child: SmartTable<BillItem>(
                          emptyMessage: 'Cart is empty. Scan or search items.',
                          data: items,
                          onRowDelete: (item) {
                            setState(() => items.remove(item));
                          },
                          columns: [
                            SmartTableColumn(
                              title: 'Item',
                              flex: 3,
                              valueMapper: (i) => i.itemName,
                            ),
                            SmartTableColumn(
                              title: 'Qty',
                              flex: 1,
                              valueMapper: (i) => '${i.qty} ${i.unit}',
                            ),
                            SmartTableColumn(
                              title: 'Price',
                              flex: 1,
                              valueMapper: (i) => '₹${i.price}',
                            ),
                            SmartTableColumn(
                              title: 'Total',
                              flex: 1,
                              builder: (i) => Text(
                                '₹${i.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: FuturisticColors.primary,
                                ),
                              ),
                            ),
                            SmartTableColumn(
                              title: '',
                              flex: 1,
                              builder: (i) => IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: FuturisticColors.error,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => items.remove(i)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildTotalsPanel(),
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

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      focusNode: _searchFocus,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: FuturisticColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search Product (Barcode / Name)...',
        hintStyle: const TextStyle(color: FuturisticColors.textSecondary),
        prefixIcon: const Icon(
          Icons.qr_code_scanner,
          color: FuturisticColors.primary,
        ),
        filled: true,
        fillColor: FuturisticColors.surfaceHighlight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProductList(String ownerId) {
    return StreamBuilder<List<Product>>(
      stream: sl<ProductsRepository>().watchAll(userId: ownerId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final query = searchController.text.toLowerCase();
        final filtered = snap.data!
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query) ||
                  (p.barcode?.contains(query) ?? false),
            )
            .take(50) // Limit results for performance
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = filtered[i];
            return ListTile(
              dense: true,
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Stock: ${p.stockQuantity} ${p.unit} | ₹${p.sellingPrice}',
              ),
              trailing: const Icon(
                Icons.add_circle_outline,
                color: FuturisticColors.primary,
              ),
              onTap: () {
                setState(() => selectedProduct = p);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _qtyFocus.requestFocus();
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedProductPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: FuturisticColors.surfaceHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adding: ${selectedProduct!.name}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyController,
                  focusNode: _qtyFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: FuturisticColors.background,
                  ),
                  onSubmitted: (_) => addItem(),
                ),
              ),
              const SizedBox(width: 8),
              FuturisticButton.primary(
                label: 'Add',
                icon: Icons.check,
                onPressed: addItem,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: FuturisticColors.surface,
        border: Border(top: BorderSide(color: FuturisticColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Items: ${items.length}',
                style: const TextStyle(color: FuturisticColors.textSecondary),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.success,
                ),
              ),
            ],
          ),
          const Spacer(),
          FuturisticButton.success(
            label: 'COMPLETE SALE (Ctrl+S)',
            icon: Icons.print,
            onPressed: items.isEmpty ? null : saveBill,
          ),
        ],
      ),
    );
  }
}
