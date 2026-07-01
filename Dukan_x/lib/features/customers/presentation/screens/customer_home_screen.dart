// ============================================================================
// CUSTOMER HOME SCREEN
// ============================================================================
// Main dashboard for customer app showing stats, vendors, and quick actions
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/customer_dashboard_repository.dart';
import '../../data/customer_notifications_repository.dart';
import 'customer_invoice_list_screen.dart';
import 'customer_ledger_screen.dart';
import 'customer_notifications_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_payment_screen.dart';
import '../../../../screens/widgets/sync_status_indicator.dart';
import '../../../../core/sync/sync_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerHomeScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(customerId: widget.customerId),
          CustomerInvoiceListScreen(customerId: widget.customerId),
          CustomerLedgerScreen(customerId: widget.customerId),
          CustomerNotificationsScreen(customerId: widget.customerId),
          CustomerProfileScreen(customerId: widget.customerId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Invoices',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ledger',
          ),
          _buildNotificationDestination(),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDestination() {
    final unreadAsync = ref.watch(
      customerUnreadNotificationsCountProvider(widget.customerId),
    );

    return NavigationDestination(
      icon: unreadAsync.when(
        data: (count) => Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
        loading: () => const Icon(Icons.notifications_outlined),
        error: (_, _) => const Icon(Icons.notifications_outlined),
      ),
      selectedIcon: unreadAsync.when(
        data: (count) => Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.notifications),
        ),
        loading: () => const Icon(Icons.notifications),
        error: (_, _) => const Icon(Icons.notifications),
      ),
      label: 'Alerts',
    );
  }
}

// ============================================================================
// HOME TAB
// ============================================================================

class _HomeTab extends ConsumerWidget {
  final String customerId;

  const _HomeTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(customerDashboardStatsProvider(customerId));
    final vendorsAsync = ref.watch(connectedVendorsProvider(customerId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Dashboard',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _triggerSync(context),
                    child: const SyncStatusIndicator(),
                  ),
                ),
              ),
            ],
          ),

          // Stats Cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _buildStatsSection(context, stats),
                loading: () => _buildStatsLoading(),
                error: (e, _) => _buildError('Failed to load stats'),
              ),
            ),
          ),

          // Quick Actions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildQuickActions(context)),
          ),

          // Connected Vendors Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'My Vendors',
                style: GoogleFonts.poppins(
                  fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Vendor List
          vendorsAsync.when(
            data: (vendors) => vendors.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyVendors(context))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildVendorCard(context, vendors[index]),
                      childCount: vendors.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _buildError('Failed to load vendors'),
            ),
          ),

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    CustomerDashboardStats stats,
  ) {
    return Column(
      children: [
        // Outstanding Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: stats.totalOutstanding > 0
                  ? [const Color(0xFFFF6B6B), const Color(0xFFEE5253)]
                  : [const Color(0xFF00B894), const Color(0xFF00CEC9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (stats.totalOutstanding > 0
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF00B894))
                        .withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.totalOutstanding > 0 ? 'Total Outstanding' : 'All Clear!',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${stats.totalOutstanding.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(context,
                    mobile: 28.0,
                    tablet: 30.0,
                    desktop: 32.0,  // PRESERVED: Desktop uses exactly 32 as before
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${stats.vendorCount} vendors • ${stats.unpaidInvoiceCount} unpaid',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mini Stats Row
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                icon: Icons.store,
                label: 'Vendors',
                value: '${stats.vendorCount}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStat(
                context,
                icon: Icons.receipt,
                label: 'Unpaid',
                value: '${stats.unpaidInvoiceCount}',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStat(
                context,
                icon: Icons.notifications,
                label: 'Alerts',
                value: '${stats.unreadNotificationCount}',
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.payments,
            label: 'Pay Now',
            color: const Color(0xFF6C5CE7),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerPaymentScreen(customerId: customerId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.history,
            label: 'History',
            color: const Color(0xFF00B894),
            onTap: () {
              // Navigate to ledger
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.download,
            label: 'Download',
            color: const Color(0xFFFF7675),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download all invoices as PDF')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVendorCard(BuildContext context, VendorConnection vendor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasOutstanding = vendor.outstandingBalance > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasOutstanding
              ? Colors.red.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: hasOutstanding
              ? Colors.red.shade50
              : Colors.green.shade50,
          child: Text(
            vendor.vendorName.isNotEmpty
                ? vendor.vendorName[0].toUpperCase()
                : 'V',
            style: TextStyle(
              color: hasOutstanding ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          vendor.vendorName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          vendor.vendorBusinessName ?? vendor.vendorPhone ?? 'Vendor',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${vendor.outstandingBalance.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: hasOutstanding ? Colors.red : Colors.green,
              ),
            ),
            Text(
              hasOutstanding ? 'Outstanding' : 'Paid',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          // Navigate to vendor detail / invoices
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerInvoiceListScreen(
                customerId: customerId,
                vendorId: vendor.vendorId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyVendors(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(responsiveValue<double>(context,
              mobile: 16,
              tablet: 20,
              desktop: 32,  // PRESERVED: Desktop uses exactly 32 as before
            )),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No vendors connected',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When vendors add you as a customer, they will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoading() {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }

  void _triggerSync(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing...'),
        duration: Duration(seconds: 1),
      ),
    );

    // Trigger actual sync
    await SyncManager.instance.forceSyncAll();
  }
}
