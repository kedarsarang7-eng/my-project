import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/shop_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../screens/customer_link_shop_screen.dart';
import '../../data/repositories/customer_item_request_repository.dart';
import '../../models/customer_item_request.dart';
import '../../services/local_cart_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerPreOrderScreen extends StatefulWidget {
  final String customerPhone;
  const CustomerPreOrderScreen({required this.customerPhone, super.key});

  @override
  State<CustomerPreOrderScreen> createState() => _CustomerPreOrderScreenState();
}

class _CustomerPreOrderScreenState extends State<CustomerPreOrderScreen> {
  // Dependencies
  CustomerItemRequestRepository get _requestRepo =>
      sl<CustomerItemRequestRepository>();
  ProductsRepository get _productsRepo => sl<ProductsRepository>();
  ShopRepository get _shopRepo => sl<ShopRepository>();

  // State
  final LocalCartService _cartService = LocalCartService();

  String? _linkedVendorId;
  String? _businessType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLinkedShop();
  }

  Future<void> _checkLinkedShop() async {
    setState(() => _isLoading = true);
    final session = sl<SessionManager>();
    final ownerId = session.ownerId;

    try {
      if (ownerId != null && ownerId.isNotEmpty) {
        _linkedVendorId = ownerId;
        _cartService.initializeForVendor(ownerId);

        // Fetch Shop Profile to get Business Type
        final shopRes = await _shopRepo.getShopProfile(ownerId);
        if (shopRes.data != null) {
          setState(() {
            _businessType = shopRes.data!.businessType ?? 'grocery';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(
          e,
          stackTrace: StackTrace.current,
          userMessage: 'Failed to load shop details. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1. Not Linked State
    if (_linkedVendorId == null) {
      return Scaffold(body: _buildLinkShopPrompt());
    }

    final bool isWide = context.isDesktop || context.isTablet;

    // 2. Linked State - Dashboard
    return AnimatedBuilder(
      animation: _cartService,
      builder: (context, child) {
        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: _buildHeader(),
              elevation: 0,
              backgroundColor: Colors.white,
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Catalog (Left/Main)
                Expanded(flex: 6, child: _buildCatalog()),

                // Cart & History (Right - Desktop Style)
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildCartSection(isMobile: false),
                      const Divider(),
                      Expanded(child: _buildRequestHistory()),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _cartService.itemCount > 0
                ? FloatingActionButton.extended(
                    onPressed: _sendRequest,
                    icon: const Icon(Icons.send),
                    label: Text('Send Request (${_cartService.itemCount})'),
                  )
                : null,
          );
        } else {
          // Mobile layout using tabs
          return DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: _buildHeader(),
                elevation: 0,
                backgroundColor: Colors.white,
                bottom: TabBar(
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    const Tab(icon: Icon(Icons.grid_view), text: 'Catalog'),
                    Tab(
                      icon: Badge(
                        label: Text('${_cartService.itemCount}'),
                        isLabelVisible: _cartService.itemCount > 0,
                        child: const Icon(Icons.shopping_cart),
                      ),
                      text: 'Cart',
                    ),
                    const Tab(icon: Icon(Icons.history), text: 'History'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _buildCatalog(),
                  _buildCartSection(isMobile: true),
                  _buildRequestHistory(),
                ],
              ),
              floatingActionButton: _cartService.itemCount > 0
                  ? FloatingActionButton.extended(
                      onPressed: _sendRequest,
                      icon: const Icon(Icons.send),
                      label: Text('Send Request (${_cartService.itemCount})'),
                    )
                  : null,
            ),
          );
        }
      },
    );
  }

  Widget _buildLinkShopPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Not Linked to any Shop',
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Link to a vendor to start ordering items.'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerLinkShopScreen(),
                ),
              );
              if (result == true) {
                _checkLinkedShop();
              }
            },
            icon: const Icon(Icons.qr_code),
            label: const Text('Link to Shop'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.store, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ordering from',
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
            ),
            Text(
              _linkedVendorId ?? 'Unknown',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        if (_businessType != null)
          Chip(
            label: Text(
              _businessType!.toUpperCase(),
              style: const TextStyle(fontSize: 9),
            ),
            backgroundColor: Colors.blue.withOpacity(0.1),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildCatalog() {
    return FutureBuilder<RepositoryResult<List<Product>>>(
      future: _productsRepo.getAll(userId: _linkedVendorId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading catalog: ${snapshot.error}'),
          );
        }

        final products = snapshot.data?.data ?? [];
        if (products.isEmpty) {
          return const Center(child: Text('No items available in catalog'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isPharmacy = _businessType == 'pharmacy';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAddToCartDialog(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(
                    isPharmacy ? Icons.medication : Icons.shopping_bag,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${product.sellingPrice}',
                    style: GoogleFonts.outfit(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/ ${product.unit}',
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSection({required bool isMobile}) {
    return Container(
      height: isMobile ? null : 350,
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Request',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_cartService.itemCount > 0)
                  TextButton(
                    onPressed: () => _cartService.clear(),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _cartService.items.isEmpty
                ? const Center(child: Text('Cart is empty'))
                : ListView.builder(
                    itemCount: _cartService.items.length,
                    itemBuilder: (context, index) {
                      final item = _cartService.items[index];
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text('${item.requestedQty} ${item.unit}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              _cartService.removeItem(item.productId),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Past Requests',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CustomerItemRequest>>(
            stream: _requestRepo.watchRequestsForCustomer(widget.customerPhone),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data!;
              if (requests.isEmpty) {
                return const Center(child: Text('No history'));
              }

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return ListTile(
                    leading: _buildStatusIcon(req.status),
                    title: Text('${req.items.length} Items'),
                    subtitle: Text(_formatDate(req.createdAt)),
                    trailing: _buildStatusBadge(req.status),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddToCartDialog(Product product) async {
    final qtyController = TextEditingController(text: '1');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: product.unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty > 0) {
                _cartService.addItem(
                  CustomerItemRequestItem(
                    productId: product.id,
                    productName: product.name,
                    requestedQty: qty,
                    unit: product.unit,
                    status: ItemStatus.pending,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest() async {
    if (_cartService.items.isEmpty) return;

    try {
      final request = CustomerItemRequest(
        id: const Uuid().v4(),
        customerId: widget.customerPhone,
        vendorId: _linkedVendorId!,
        items: _cartService.items,
        status: RequestStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _requestRepo.createRequest(request);
      _cartService.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request sent successfully! Vendor will review it shortly.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
      }
    }
  }

  Widget _buildStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Icon(Icons.timer, color: Colors.orange);
      case RequestStatus.approved:
        return const Icon(Icons.check_circle, color: Colors.green);
      case RequestStatus.rejected:
        return const Icon(Icons.cancel, color: Colors.red);
      case RequestStatus.billed:
        return const Icon(Icons.receipt, color: Colors.blue);
    }
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color color;
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        break;
      case RequestStatus.approved:
        color = Colors.green;
        break;
      case RequestStatus.rejected:
        color = Colors.red;
        break;
      case RequestStatus.billed:
        color = Colors.blue;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute}';
  }
}
