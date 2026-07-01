import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import '../core/theme/futuristic_colors.dart';
import '../models/customer.dart';
import 'package:intl/intl.dart';
import 'package:dukanx/core/routing/route_paths.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../services/connection_service.dart';
import '../widgets/premium_tabs.dart';
import './udhar_tab.dart';
import './shop_management_screen.dart';

class ProfessionalCustomerPortal extends StatefulWidget {
  final Customer? customer;

  const ProfessionalCustomerPortal({super.key, this.customer});

  @override
  State<ProfessionalCustomerPortal> createState() =>
      _ProfessionalCustomerPortalState();
}

class _ProfessionalCustomerPortalState extends State<ProfessionalCustomerPortal>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedBottomNavIndex = 0;
  String? _selectedShopId;
  List<String> _linkedShops = [];

  @override
  void initState() {
    super.initState();
    // Tabs: Account, Bills (Shop), Udhar, Report, Total (All Shops)
    _tabController = TabController(length: 5, vsync: this);
    _selectedShopId = widget.customer?.linkedOwnerId;
    _loadLinkedShops();
  }

  Future<void> _loadLinkedShops() async {
    if (widget.customer == null) return;
    try {
      final connections = await sl<ConnectionService>()
          .getAcceptedConnections();
      if (mounted) {
        setState(() {
          _linkedShops = connections
              .map((c) => c['vendorId'] as String)
              .toList();
          // Auto-select first shop if none selected
          if (_selectedShopId == null && _linkedShops.isNotEmpty) {
            _selectedShopId = _linkedShops.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading shops: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.customer?.name ?? 'Customer';
    final customerId = widget.customer?.id ?? '';

    return Scaffold(
      appBar: _buildCustomerAppBar(customerName),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Account Overview Tab (for selected shop)
          _AccountOverviewTab(customerId: customerId, shopId: _selectedShopId),
          // Bill Details Tab (for selected shop)
          CustomerLiveBillsTab(customerId: customerId, shopId: _selectedShopId),
          // Udhar tab (Always available, filtered by shop ideally)
          // UdharTab might need update to support filtering, but for now passing customerId
          customerId.isNotEmpty
              ? UdharTab(customerId: customerId)
              : const Center(child: Text('Customer ID not available')),
          // Report tab (for selected shop)
          _DailyReportTab(customerId: customerId, shopId: _selectedShopId),
          // NEW: Total Bill of Every Shop
          _TotalBillsAllShopsTab(
            customerId: customerId,
            linkedShops: _linkedShops,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildCustomerAppBar(String customerName) {
    return AppBar(
      elevation: 8,
      shadowColor: Colors.black26,
      backgroundColor: Colors.white,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $customerName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.blue.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_selectedShopId != null)
              GestureDetector(
                onTap: _showShopSwitcher,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shop: $_selectedShopId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              )
            else
              Text(
                'Select a shop',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showShopSwitcher,
          icon: const Icon(Icons.store, color: Colors.blue),
          tooltip: 'Switch Shop',
        ),
        IconButton(
          onPressed: () {
            _showCustomerMenu();
          },
          icon: Icon(Icons.more_vert, color: Colors.blue.shade700),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Bills'),
              Tab(text: 'Udhar'),
              Tab(text: 'Report'),
              Tab(text: 'All Shops'),
            ],
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            indicatorWeight: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return PremiumBottomNav(
      currentIndex: _selectedBottomNavIndex,
      onTap: (index) {
        setState(() => _selectedBottomNavIndex = index);
        _tabController.animateTo(index);
      },
      activeColor: Colors.blue.shade700,
      items: const [
        PremiumNavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'Overview',
        ),
        PremiumNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
          label: 'Bills',
        ),
        PremiumNavItem(
          icon: Icons.account_balance_outlined,
          activeIcon: Icons.account_balance,
          label: 'Udhar',
        ),
        PremiumNavItem(
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today,
          label: 'Report',
        ),
        PremiumNavItem(
          icon: Icons.list_alt_outlined,
          activeIcon: Icons.list_alt,
          label: 'All Shops',
        ),
      ],
    );
  }

  void _showCustomerMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.settings, color: Colors.blue.shade700),
              title: const Text('Manage Shops'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ShopManagementScreen(customer: widget.customer),
                  ),
                ).then((_) => _loadLinkedShops());
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: FuturisticColors.error),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                context.go(RoutePaths.authGate);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShopSwitcher() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Shop',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            if (_linkedShops.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No linked shops found.'),
              ),
            ..._linkedShops.map(
              (shopId) => ListTile(
                leading: const Icon(Icons.store),
                title: Text('Shop ID: $shopId'),
                selected: shopId == _selectedShopId,
                trailing: shopId == _selectedShopId
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedShopId = shopId);
                  Navigator.pop(context);
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add / Manage Shops'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ShopManagementScreen(customer: widget.customer),
                  ),
                ).then((_) => _loadLinkedShops());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountOverviewTab extends StatelessWidget {
  final String customerId;
  final String? shopId;

  const _AccountOverviewTab({required this.customerId, this.shopId});

  @override
  Widget build(BuildContext context) {
    if (shopId == null) {
      return const Center(child: Text('Please select a shop'));
    }
    // Use BillsRepository to watch bills for this customer
    // Note: shopId here refers to the owner/vendor ID
    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(
        userId: shopId!,
        customerId: customerId,
      ),
      builder: (context, snap) {
        double totalPurchase = 0;
        double totalPaid = 0;
        double pendingDues = 0;
        int totalBills = 0;
        int billsPaid = 0;
        int pendingBills = 0;

        if (snap.hasData && snap.data != null) {
          final bills = snap.data!;
          totalBills = bills.length;

          for (var bill in bills) {
            totalPurchase += bill.subtotal;
            totalPaid += bill.paidAmount;
            final pending = (bill.subtotal - bill.paidAmount).clamp(
              0.0,
              double.infinity,
            );
            pendingDues += pending;

            if (bill.isPaid || bill.status.toLowerCase() == 'paid') {
              billsPaid++;
            } else {
              pendingBills++;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pending Dues Card (Dynamic from Firestore)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FuturisticColors.error,
                    FuturisticColors.error.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: FuturisticColors.error.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pending Dues',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹${pendingDues.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pendingDues == 0
                        ? 'All clear! No pending dues.'
                        : 'Due soon - please settle',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Statistics Row (Dynamic)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Total Bills',
                    value: totalBills.toString(),
                    icon: Icons.receipt,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Bills Paid',
                    value: billsPaid.toString(),
                    icon: Icons.check_circle,
                    color: FuturisticColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Pending Bills',
                    value: pendingBills.toString(),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Account Summary
            Text(
              'Account Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              'Total Purchases',
              '₹${totalPurchase.toStringAsFixed(2)}',
            ),
            const Divider(),
            _buildSummaryRow(
              context,
              'Amount Paid',
              '₹${totalPaid.toStringAsFixed(2)}',
            ),
            const Divider(),
            _buildSummaryRow(
              context,
              'Pending Dues',
              '₹${pendingDues.toStringAsFixed(2)}',
              isHighlight: true,
            ),
            const SizedBox(height: 24),
            // Payment Methods
            Text(
              'Quick Payment',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            // ... payment buttons ...
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isHighlight
                  ? FuturisticColors.error
                  : Colors.grey.shade700,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isHighlight ? FuturisticColors.error : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyReportTab extends StatelessWidget {
  final String customerId;
  final String? shopId;

  const _DailyReportTab({required this.customerId, this.shopId});

  @override
  Widget build(BuildContext context) {
    if (customerId.isEmpty) {
      return const Center(child: Text('Customer ID not available'));
    }
    if (shopId == null) {
      return const Center(child: Text('Please select a shop'));
    }

    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(
        userId: shopId!,
        customerId: customerId,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bills = snap.data ?? [];

        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate Monthly/Overall Summary
        int totalBills = bills.length;
        double totalAmount = 0;
        double amountPaid = 0;
        double pendingAmount = 0;

        // Group by Date for Daily Report
        final Map<String, List<Bill>> groupedBills = {};
        for (var bill in bills) {
          totalAmount += bill.subtotal;
          amountPaid += bill.paidAmount;
          pendingAmount += (bill.subtotal - bill.paidAmount).clamp(
            0.0,
            double.infinity,
          );

          final dateKey = DateFormat('yyyy-MM-dd').format(bill.date);
          groupedBills.putIfAbsent(dateKey, () => []).add(bill);
        }

        final sortedDates = groupedBills.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Daily Report ($shopId)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            // ... Rest of the report code ...
            const SizedBox(height: 12),
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(context, 'Total Bills', '$totalBills'),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    context,
                    'Total Amount',
                    '₹${totalAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    context,
                    'Amount Paid',
                    '₹${amountPaid.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    context,
                    'Pending Amount',
                    '₹${pendingAmount.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Dynamic daily cards
            ...sortedDates.map((dateStr) {
              final dayBills = groupedBills[dateStr]!;
              final double dayTotal = dayBills.fold(
                0,
                (sum, b) => sum + b.subtotal,
              );

              final bool anyPending = dayBills.any(
                (b) => !b.isPaid && b.status.toLowerCase() != 'paid',
              );
              String statusText = 'Paid';
              Color statusColor = FuturisticColors.success;
              if (anyPending) {
                statusText = 'Pending';
                statusColor = Colors.orange;
              }

              final dt = DateTime.parse(dateStr);
              final displayDate = DateFormat('EEE, dd MMM').format(dt);

              return Card(
                child: ListTile(
                  title: Text(displayDate),
                  subtitle: Text('${dayBills.length} Bills'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${dayTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Live bills tab - streams bills for a given customer and shop
class CustomerLiveBillsTab extends StatelessWidget {
  final String? customerId;
  final String? shopId;

  const CustomerLiveBillsTab({super.key, this.customerId, this.shopId});

  @override
  Widget build(BuildContext context) {
    if (customerId == null) {
      return const Center(child: Text('No customer selected'));
    }
    if (shopId == null) {
      return const Center(child: Text('Please select a shop'));
    }

    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(
        userId: shopId!,
        customerId: customerId!,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final bills = snap.data ?? <Bill>[];

        final totalBills = bills.length;
        if (totalBills == 0) {
          return const Center(child: Text('No bills found for this shop'));
        }

        final paidBills = bills
            .where((b) => b.isPaid || (b.status.toLowerCase() == 'paid'))
            .length;
        final pendingBills = totalBills - paidBills;
        final totalPendingAmount = bills.fold<double>(
          0,
          (sum, b) =>
              sum + ((b.subtotal - b.paidAmount).clamp(0.0, double.infinity)),
        );
        final totalPurchaseAmount = bills.fold<double>(
          0,
          (sum, b) => sum + b.subtotal,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Metrics
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    context,
                    'Total Bills',
                    totalBills.toString(),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricCard(
                    context,
                    'Bills Paid',
                    paidBills.toString(),
                    FuturisticColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricCard(
                    context,
                    'Pending',
                    pendingBills.toString(),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    context,
                    'Pending Amount',
                    '₹${totalPendingAmount.toStringAsFixed(2)}',
                    FuturisticColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricCard(
                    context,
                    'Total Purchases',
                    '₹${totalPurchaseAmount.toStringAsFixed(2)}',
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bills list
            ...bills.map(
              (b) => Card(
                child: ListTile(
                  title: Text(
                    b.invoiceNumber.isNotEmpty ? b.invoiceNumber : b.id,
                  ),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(b.date)),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${b.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.status,
                        style: TextStyle(
                          color: (b.status.toLowerCase() == 'paid')
                              ? FuturisticColors.success
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bill ${b.invoiceNumber}')),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _TotalBillsAllShopsTab extends StatelessWidget {
  final String customerId;
  final List<String> linkedShops;

  const _TotalBillsAllShopsTab({
    required this.customerId,
    required this.linkedShops,
  });

  @override
  Widget build(BuildContext context) {
    if (linkedShops.isEmpty) {
      return const Center(child: Text('No linked shops'));
    }

    // Use FutureBuilder to aggregate bills from all shops
    return FutureBuilder<Map<String, List<Bill>>>(
      future: _fetchBillsFromAllShops(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final shopBillsMap = snap.data ?? {};

        // Calculate grand totals
        int grandTotalBills = 0;
        double grandTotalAmount = 0;
        double grandTotalPending = 0;

        for (var bills in shopBillsMap.values) {
          grandTotalBills += bills.length;
          for (var bill in bills) {
            grandTotalAmount += bill.subtotal;
            grandTotalPending += (bill.subtotal - bill.paidAmount).clamp(
              0.0,
              double.infinity,
            );
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Grand Total Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Shops Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _grandSummaryItem('Total Bills', '$grandTotalBills'),
                      _grandSummaryItem(
                        'Total Amount',
                        '₹${grandTotalAmount.toStringAsFixed(0)}',
                      ),
                      _grandSummaryItem(
                        'Pending',
                        '₹${grandTotalPending.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Per-Shop Cards
            ...linkedShops.map((shopId) {
              final shopBills = shopBillsMap[shopId] ?? [];
              final totalCount = shopBills.length;
              final totalAmount = shopBills.fold(
                0.0,
                (sum, b) => sum + b.subtotal,
              );
              final totalPending = shopBills.fold(
                0.0,
                (sum, b) =>
                    sum +
                    (b.subtotal - b.paidAmount).clamp(0.0, double.infinity),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Shop ID: $shopId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _summaryColumn('Total Bills', '$totalCount'),
                          _summaryColumn(
                            'Total Amount',
                            '₹${totalAmount.toStringAsFixed(0)}',
                          ),
                          _summaryColumn(
                            'Pending',
                            '₹${totalPending.toStringAsFixed(0)}',
                            isWarning: totalPending > 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<Map<String, List<Bill>>> _fetchBillsFromAllShops() async {
    final Map<String, List<Bill>> result = {};

    for (final shopId in linkedShops) {
      try {
        // Fetch bills for this customer from this shop using BillsRepository
        final bills = await sl<BillsRepository>()
            .watchAll(userId: shopId, customerId: customerId)
            .first;
        result[shopId] = bills;
      } catch (e) {
        result[shopId] = []; // Empty on error
      }
    }

    return result;
  }

  Widget _grandSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _summaryColumn(String label, String value, {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isWarning ? FuturisticColors.error : Colors.black,
          ),
        ),
      ],
    );
  }
}
