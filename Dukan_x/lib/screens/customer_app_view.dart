import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx/core/routing/route_paths.dart';

import '../core/di/service_locator.dart';
import '../core/error/error_handler.dart'; // For RepositoryResult
import '../core/repository/bills_repository.dart';
import '../core/repository/customers_repository.dart';
import '../core/repository/products_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../features/pre_order/presentation/customer/customer_pre_order_screen.dart';
import '../features/pre_order/presentation/customer/vendor_catalog_screen.dart';

class CustomerAppView extends StatefulWidget {
  final String phoneNumber;
  final bool isOwnerMode;

  const CustomerAppView({
    required this.phoneNumber,
    this.isOwnerMode = false,
    super.key,
  });

  @override
  State<CustomerAppView> createState() => _CustomerAppViewState();
}

class _CustomerAppViewState extends State<CustomerAppView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Repositories
  CustomersRepository get _customersRepo => sl<CustomersRepository>();
  BillsRepository get _billsRepo => sl<BillsRepository>();
  ProductsRepository get _productsRepo => sl<ProductsRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwnerMode ? 'Customer Account' : 'My Account'),
        actions: [
          if (widget.isOwnerMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDuesDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go(RoutePaths.splash),
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            Container(
              color: FuturisticColors.paidBackground,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          widget.phoneNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.store), text: 'Shop'),
                Tab(icon: Icon(Icons.receipt), text: 'Bills'),
                Tab(icon: Icon(Icons.shopping_bag), text: 'My Items'),
                Tab(icon: Icon(Icons.info), text: 'Info'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Shop Catalog (requires vendorId = ownerId from session)
                  Builder(
                    builder: (ctx) {
                      final vendorId = sl<SessionManager>().ownerId;
                      if (vendorId == null) {
                        return const Center(child: Text('No shop linked'));
                      }
                      return VendorCatalogScreen(
                        vendorId: vendorId,
                        customerId: widget.phoneNumber,
                      );
                    },
                  ),
                  _buildBillsTab(),
                  CustomerPreOrderScreen(customerPhone: widget.phoneNumber),
                  _buildInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to find customer by phone.
  // In offline-first, we usually query by ID. If we only have phone, we might need a search method.
  // For now, assuming `CustomersRepository.watchAll` can provide list and we filter.
  // Ideally, repo should have `getByPhone`.
  Stream<Customer?> _watchCustomerByPhone() {
    // Assuming current session owner is the shop owner.
    // If we are in "Customer Mode" (self-login), we might need to know which shop context we are in.
    // But typically `CustomerAppView` is used either by owner (viewing customer) or customer (viewing self).
    // If customer viewing self, `userId` context might be tricky if we don't have it.
    // Assuming `sl<SessionManager>().ownerId` is correct for the data scope.

    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) return Stream.value(null);

    return _customersRepo.watchAll(userId: ownerId).map((list) {
      try {
        return list.firstWhere(
          (c) => c.phone == widget.phoneNumber || c.name == widget.phoneNumber,
        );
      } catch (e) {
        return null;
      }
    });
  }

  Widget _buildBillsTab() {
    return StreamBuilder<Customer?>(
      stream: _watchCustomerByPhone(),
      builder: (context, custSnap) {
        if (custSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // final customer = custSnap.data;

        // Use local repo stream
        final ownerId = sl<SessionManager>().ownerId;
        if (ownerId == null) {
          return const Center(child: Text("No Shop Context"));
        }

        return StreamBuilder<List<Bill>>(
          stream: _billsRepo.watchAll(userId: ownerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter by customer phone/ID locally for now
            // Ideally Repo supports filter
            final allBills = snapshot.data ?? [];
            final bills = allBills
                .where(
                  (b) =>
                      b.customerId == widget.phoneNumber ||
                      b.customerName == widget.phoneNumber,
                )
                .toList();

            double totalDue = 0;
            for (var bill in bills) {
              if (bill.status != 'Paid') {
                totalDue += (bill.grandTotal - bill.paidAmount);
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop selector - Removed as per instruction, assuming ownerId context handles it.
                  // If multi-shop selection is needed, this logic would need to be re-introduced
                  // with a mechanism to filter bills by selected shop ID from the repo.
                  const SizedBox(height: 12),
                  if (widget.isOwnerMode)
                    ElevatedButton.icon(
                      onPressed: () => _showCreateBillDialog(context),
                      icon: const Icon(Icons.note_add),
                      label: const Text('Create Bill'),
                    ),

                  if (totalDue > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: FuturisticColors.unpaidBackground,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pending Due',
                            style: TextStyle(color: FuturisticColors.error),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _showPaymentDialog(context, totalDue),
                            child: const Text('Pay Now'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'Recent Bills',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      final pending = (bill.grandTotal - bill.paidAmount).clamp(
                        0.0,
                        double.infinity,
                      );
                      final color = bill.status == 'Paid'
                          ? FuturisticColors.success
                          : (bill.status == 'Partial'
                                ? Colors.orange
                                : FuturisticColors.error);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(Icons.receipt, color: color),
                          ),
                          onTap: () => _showBillDetails(context, bill),
                          title: Text('Bill #${bill.id.substring(0, 8)}'),
                          subtitle: Text(
                            '${bill.date.day}/${bill.date.month}/${bill.date.year}',
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${bill.grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pending > 0)
                                Text(
                                  'Pending: ₹${pending.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: FuturisticColors.error,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                onPressed: () =>
                                    _showCustomPayDialog(context, bill),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 0),
                                ),
                                child: const Text(
                                  'Pay',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoTab() {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) return const Center(child: Text("No Shop Context"));

    return StreamBuilder<List<Bill>>(
      stream: _billsRepo.watchAll(userId: ownerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allBills = snapshot.data!;
        final bills = allBills
            .where(
              (b) =>
                  b.customerId == widget.phoneNumber ||
                  b.customerName == widget.phoneNumber,
            )
            .toList();

        double totalSpent = 0, totalPaid = 0, totalDue = 0;
        for (var b in bills) {
          totalSpent += b.grandTotal;
          totalPaid += b.paidAmount;
          totalDue += (b.grandTotal - b.paidAmount);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _infoCard(
                'Total Spent',
                '₹${totalSpent.toStringAsFixed(2)}',
                Icons.shopping_cart,
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _infoCard(
                'Total Paid',
                '₹${totalPaid.toStringAsFixed(2)}',
                Icons.check_circle,
                FuturisticColors.success,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: totalDue > 0
                      ? FuturisticColors.unpaidBackground
                      : FuturisticColors.paidBackground,
                ),
                child: Row(
                  children: [
                    Icon(
                      totalDue > 0 ? Icons.pending : Icons.check_circle,
                      color: totalDue > 0
                          ? FuturisticColors.error
                          : FuturisticColors.success,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          totalDue > 0 ? 'Total Pending' : 'All Bills Paid',
                          style: TextStyle(
                            color: totalDue > 0
                                ? FuturisticColors.error
                                : FuturisticColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${totalDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: totalDue > 0
                                ? FuturisticColors.error
                                : FuturisticColors.success,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _paymentMethodCard('Online Payment', 'Pay via UPI or Debit Card'),
              const SizedBox(height: 8),
              _paymentMethodCard('Cash Payment', 'Pay at shop'),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // ----------------- Dialogs & Helpers -----------------

  void _showCreateBillDialog(BuildContext context) {
    final outerContext = context;
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) return;

    List<BillItem> items = [];
    double subtotal = 0.0;
    String paymentMethod = 'none';
    double payNow = 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          title: const Text('Create Bill'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<RepositoryResult<List<Product>>>(
                  // Using ProductsRepo
                  future: _productsRepo.getAll(userId: ownerId),
                  builder: (c, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Map Products to match UI expectation if needed, or use Products directly
                    final products = snap.data!.data ?? [];

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Item',
                                ),
                                items: products
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v.id,
                                        child: Text(
                                          '${v.name} (${'₹${v.sellingPrice}/${v.unit}'})',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (vid) {
                                  final product = products.firstWhere(
                                    (v) => v.id == vid,
                                  );
                                  final qtyCtrl = TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Add ${product.name}'),
                                      content: TextField(
                                        controller: qtyCtrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final qty =
                                                double.tryParse(
                                                  qtyCtrl.text.trim(),
                                                ) ??
                                                0.0;
                                            if (qty <= 0) return;

                                            final item = BillItem(
                                              productId: product.id,
                                              productName: product.name,
                                              qty: qty,
                                              price: product.sellingPrice,
                                              unit: product.unit,
                                            );
                                            setState(() {
                                              items.add(item);
                                              subtotal = items.fold(
                                                0.0,
                                                (s, it) => s + it.total,
                                              );
                                            });
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (items.isNotEmpty)
                          Column(
                            children: items
                                .map(
                                  (it) => ListTile(
                                    title: Text(it.itemName),
                                    subtitle: Text(
                                      '${it.qty} ${it.unit} × ₹${it.price}/${it.unit}',
                                    ),
                                    trailing: Text(
                                      '₹${it.total.toStringAsFixed(2)}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Subtotal: '),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('No payment now'),
                            ),
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'online',
                              child: Text('Online'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => paymentMethod = v ?? 'none'),
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                          ),
                        ),
                        if (paymentMethod != 'none')
                          TextField(
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount paid now (₹)',
                            ),
                            onChanged: (v) =>
                                payNow = double.tryParse(v) ?? 0.0,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (items.isEmpty) {
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('Add at least one item')),
                  );
                  return;
                }

                final paidInfo = (payNow <= 0 ? 0.0 : payNow);
                final bill = Bill(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  customerId: widget.phoneNumber,
                  ownerId: ownerId,
                  date: DateTime.now(),
                  items: items,
                  subtotal: subtotal,
                  grandTotal:
                      subtotal, // Assuming no tax/discount logic here for simplicity
                  paidAmount: paymentMethod == 'none' ? 0.0 : paidInfo,
                  cashPaid: paymentMethod == 'cash' ? paidInfo : 0.0,
                  onlinePaid: paymentMethod == 'online' ? paidInfo : 0.0,
                  paymentType: paymentMethod == 'none'
                      ? 'Unpaid'
                      : (paymentMethod == 'cash' ? 'Cash' : 'Online'),
                  status: (paymentMethod != 'none' && paidInfo >= subtotal)
                      ? 'Paid'
                      : (paidInfo > 0 ? 'Partial' : 'Unpaid'),
                );

                // Use Repository
                try {
                  await _billsRepo.createBill(bill);

                  if (!mounted) return;
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(
                    outerContext,
                  ).showSnackBar(const SnackBar(content: Text('Bill created')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    outerContext,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Create Bill'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payBill(Bill bill, double amount, String method) async {
    if (amount <= 0) return;
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) return;

      await _billsRepo.recordPayment(
        billId: bill.id,
        amount: amount,
        paymentMode: method,
        userId: ownerId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment of ₹${amount.toStringAsFixed(2)} recorded ($method)',
          ),
          backgroundColor: FuturisticColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: FuturisticColors.error,
        ),
      );
    }
  }

  void _showCustomPayDialog(BuildContext context, Bill bill) {
    final TextEditingController amtCtrl = TextEditingController();
    String method = 'cash';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Custom Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
              ],
              onChanged: (v) => method = v ?? 'cash',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter valid amount')),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              _payBill(bill, amt, method);
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  void _showBillDetails(BuildContext context, Bill bill) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill Details',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...bill.items.map(
              (it) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(it.itemName),
                  Text('${it.qty} ${it.unit}'),
                  Text('₹${it.total.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${bill.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Amount to Pay:'),
            const SizedBox(height: 8),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please contact the shop for UPI payment details',
                  ),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('UPI Pay'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please contact shop for cash payment'),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Cash'),
          ),
        ],
      ),
    );
  }

  void _showEditDuesDialog(BuildContext context) {
    double newDueAmount = 0;
    final TextEditingController controller = TextEditingController();

    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StreamBuilder<List<Customer>>(
        stream: _customersRepo.watchAll(userId: ownerId),
        builder: (streamContext, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: Center(child: CircularProgressIndicator()),
            );
          }

          // Handle case where customer might not exist locally yet
          Customer? customer;
          try {
            customer = snapshot.data!.firstWhere(
              (c) =>
                  c.phone == widget.phoneNumber || c.name == widget.phoneNumber,
            );
          } catch (_) {}

          if (customer == null) {
            return const AlertDialog(
              content: Text("Customer not found or not synced yet."),
            );
          }

          controller.text = customer.totalDues.toStringAsFixed(2);
          return AlertDialog(
            title: const Text('Edit Customer Due Amount'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Customer: ${customer.name}'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'New Due Amount (₹)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  newDueAmount = double.tryParse(controller.text) ?? -1;
                  if (newDueAmount >= 0) {
                    try {
                      final updated = customer!.copyWith(
                        totalDues: newDueAmount,
                      );
                      await _customersRepo.updateCustomer(
                        updated,
                        userId: ownerId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Due amount updated to ₹${newDueAmount.toStringAsFixed(2)}',
                            ),
                            backgroundColor: FuturisticColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: FuturisticColors.error,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }
}
