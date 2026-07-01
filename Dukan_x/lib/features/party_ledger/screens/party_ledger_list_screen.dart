// ============================================================================
// PARTY LEDGER LIST SCREEN
// ============================================================================
// Entry point for Party Ledger feature - shows all customers and vendors
// with outstanding balances for quick access to their statements.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/repository/customers_repository.dart';
import '../../../core/repository/vendors_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import 'party_statement_screen.dart';
import '../../customers/presentation/screens/add_customer_screen.dart';
import 'add_vendor_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Party Ledger List Screen
///
/// Shows all customers and vendors with their current balances.
/// Tapping on a party navigates to their detailed statement.
class PartyLedgerListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const PartyLedgerListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<PartyLedgerListScreen> createState() =>
      _PartyLedgerListScreenState();
}

class _PartyLedgerListScreenState extends ConsumerState<PartyLedgerListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'all'; // all, receivable, payable

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialFilter == 'supplier') {
      _tabController.index = 1;
    }
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.isDark;

    return DesktopContentContainer(
      title: 'Party Ledger',
      subtitle: 'Track all customer and vendor accounts',
      showScrollbar: false,
      actions: [
        // Filter Dropdown as an action? Or just keep it as is?
        // DesktopContentContainer Actions expects Buttons ideally.
        // We can put a custom widget.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 40,
          decoration: BoxDecoration(
            color: FuturisticColors.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: FuturisticColors.premiumBlue.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filter,
              dropdownColor: FuturisticColors.surface,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(
                Icons.filter_list,
                color: Colors.white,
                size: 18,
              ),
              onChanged: (val) {
                if (val != null) setState(() => _filter = val);
              },
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Parties')),
                DropdownMenuItem(
                  value: 'receivable',
                  child: Text('Receivable Only'),
                ),
                DropdownMenuItem(value: 'payable', child: Text('Payable Only')),
              ],
            ),
          ),
        ),
      ],
      child: Column(
        children: [
          // Tabs / Search Toolbar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: FuturisticColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: FuturisticColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FuturisticColors.primary),
                    ),
                    labelColor: FuturisticColors.primary,
                    unselectedLabelColor: FuturisticColors.textSecondary,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Customers",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store_outlined, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Vendors",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or phone...',
                    hintStyle: TextStyle(color: FuturisticColors.textSecondary),
                    prefixIcon: Icon(
                      Icons.search,
                      color: FuturisticColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: FuturisticColors.surface,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDesktopList(isDark, isVendor: false),
                _buildDesktopList(isDark, isVendor: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopList(bool isDark, {required bool isVendor}) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return const Center(child: Text('Please log in'));

    Stream<List<dynamic>> stream;
    if (isVendor) {
      stream = sl<VendorsRepository>().watchAll(userId);
    } else {
      stream = sl<CustomersRepository>().watchAll(userId: userId);
    }

    return StreamBuilder<List<dynamic>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = snapshot.data ?? [];

        // Filter Logic
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          items = items.where((i) {
            final name = (i.name as String).toLowerCase();
            final phone = (i.phone as String?) ?? '';
            return name.contains(q) || phone.contains(q);
          }).toList();
        }

        if (_filter == 'receivable') {
          items = items.where((i) {
            double bal = isVendor
                ? (i as Vendor).totalOutstanding
                : (i as Customer).totalDues;
            return bal > 0; // Customer Dues > 0 is Receivable
            // Wait: Vendor Outstanding > 0 usually means WE OWE THEM (Payable)?
            // Let's check model.
            // Customer: totalDues > 0 (Receivable)
            // Vendor: totalOutstanding > 0 (Payable usually)
          }).toList();
          // Re-check filter logic from mobile
          // Mobile:
          // Customer: Receivable = dues > 0.
          // Vendor: Payable = outstanding > 0. Receivable = outstanding < 0.

          if (isVendor) {
            // If filter is 'receivable', we want Vendor outstanding < 0?
            // Mobile logic lines 295: receivable -> vendors where outstanding < 0
            items = items
                .where((i) => (i as Vendor).totalOutstanding < 0)
                .toList();
          } else {
            items = items.where((i) => (i as Customer).totalDues > 0).toList();
          }
        } else if (_filter == 'payable') {
          if (isVendor) {
            items = items
                .where((i) => (i as Vendor).totalOutstanding > 0)
                .toList();
          } else {
            items = items
                .where((i) => (i as Customer).totalDues < 0)
                .toList(); // Available credit / advance
          }
        }

        // Mapping to PartyData for consistent Table
        final partyData = items.map((i) {
          if (isVendor) {
            final v = i as Vendor;
            return _PartyData(
              id: v.id,
              name: v.name,
              phone: v.phone,
              balance: v.totalOutstanding,
              type: 'VENDOR',
            );
          } else {
            final c = i as Customer;
            return _PartyData(
              id: c.id,
              name: c.name,
              phone: c.phone,
              balance: c.totalDues,
              type: 'CUSTOMER',
            );
          }
        }).toList();

        return EnterpriseTable<_PartyData>(
          data: partyData,
          columns: [
            EnterpriseTableColumn(
              title: "Name",
              valueBuilder: (p) => p.name,
              widgetBuilder: (p) => Row(
                children: [
                  CircleAvatar(
                    backgroundColor: FuturisticColors.primary.withOpacity(0.1),
                    child: Text(
                      p.name[0].toUpperCase(),
                      style: const TextStyle(color: FuturisticColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            EnterpriseTableColumn(
              title: "Phone",
              valueBuilder: (p) => p.phone ?? '--',
            ),
            EnterpriseTableColumn(
              title: "Balance",
              valueBuilder: (p) => p.balance,
              isNumeric: true,
              widgetBuilder: (p) {
                // Ideally depend on Party Type logic from mobile
                Color color = Colors.white;
                String label = '';

                // Reuse mobile logic visual
                // Cust: > 0 Red (Due), < 0 Green (Advance)
                // Vendor: > 0 Green (Payable?), < 0 Orange (Receivable?)
                // Let's stick to standard accounting:
                // Positive Balance usually means Due/Payable.

                if (p.type == 'CUSTOMER') {
                  if (p.balance > 0) {
                    color = FuturisticColors.error;
                    label = 'Due';
                  } // Receivable
                  else {
                    color = FuturisticColors.success;
                    label = 'Advance';
                  }
                } else {
                  // VENDOR
                  if (p.balance > 0) {
                    color = FuturisticColors.warning;
                    label = 'Payable';
                  } else {
                    color = FuturisticColors.success;
                    label = 'Advance';
                  }
                }

                return Text(
                  "${sl<CurrencyService>().symbol}${p.balance.abs().toStringAsFixed(2)} ($label)",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
          onRowTap: (p) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PartyStatementScreen(
                  partyId: p.id,
                  partyName: p.name,
                  partyType: p.type,
                ),
              ),
            );
          },
          actionsBuilder: (p) => [
            IconButton(
              icon: const Icon(
                Icons.visibility,
                color: FuturisticColors.accent1,
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartyStatementScreen(
                      partyId: p.id,
                      partyName: p.name,
                      partyType: p.type,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Party Ledger',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              'Customer & Vendor Accounts',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.blue,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Customers', icon: Icon(Icons.people_outline, size: 20)),
            Tab(text: 'Vendors', icon: Icon(Icons.store_outlined, size: 20)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: isDark ? Colors.white : Colors.black,
            ),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      size: 18,
                      color: _filter == 'all' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Parties',
                      style: TextStyle(
                        fontWeight: _filter == 'all'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'receivable',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 18,
                      color: _filter == 'receivable'
                          ? Colors.orange
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Receivable Only',
                      style: TextStyle(
                        fontWeight: _filter == 'receivable'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'payable',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: _filter == 'payable' ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payable Only',
                      style: TextStyle(
                        fontWeight: _filter == 'payable'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.primaryGradient,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          boxShadow: AppShadows.glowShadow(FuturisticColors.primary),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_tabController.index == 0) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVendorScreen()),
              );
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: Text(
            _tabController.index == 0 ? "Add Customer" : "Add Vendor",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          icon: Icon(
            _tabController.index == 0 ? Icons.person_add : Icons.store,
            color: Colors.white,
          ),
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomersList(isDark),
                _buildVendorsList(isDark),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCustomersList(bool isDark) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<List<Customer>>(
      stream: sl<CustomersRepository>().watchAll(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var customers = snapshot.data ?? [];

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          customers = customers
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (c.phone?.contains(_searchQuery) ?? false),
              )
              .toList();
        }

        // Apply balance filter
        if (_filter == 'receivable') {
          customers = customers.where((c) => c.totalDues > 0).toList();
        } else if (_filter == 'payable') {
          customers = customers.where((c) => c.totalDues < 0).toList();
        }

        // Sort by outstanding (highest first)
        customers.sort(
          (a, b) => b.totalDues.abs().compareTo(a.totalDues.abs()),
        );

        if (customers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.people_outline,
            title: 'No Customers Found',
            subtitle: _filter != 'all'
                ? 'Try changing the filter'
                : 'Add customers to see their ledger',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 80,
          ),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            return _buildPartyCard(
              _PartyData(
                id: customer.id,
                name: customer.name,
                phone: customer.phone,
                balance: customer.totalDues,
                type: 'CUSTOMER',
              ),
              isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildVendorsList(bool isDark) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<List<Vendor>>(
      stream: sl<VendorsRepository>().watchAll(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var vendors = snapshot.data ?? [];

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          vendors = vendors
              .where(
                (v) =>
                    v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (v.phone?.contains(_searchQuery) ?? false),
              )
              .toList();
        }

        // Apply balance filter (for vendors, positive = we owe them)
        if (_filter == 'payable') {
          vendors = vendors.where((v) => v.totalOutstanding > 0).toList();
        } else if (_filter == 'receivable') {
          vendors = vendors.where((v) => v.totalOutstanding < 0).toList();
        }

        // Sort by outstanding
        vendors.sort(
          (a, b) =>
              b.totalOutstanding.abs().compareTo(a.totalOutstanding.abs()),
        );

        if (vendors.isEmpty) {
          return _buildEmptyState(
            icon: Icons.store_outlined,
            title: 'No Vendors Found',
            subtitle: _filter != 'all'
                ? 'Try changing the filter'
                : 'Add vendors to see their ledger',
          );
        }

        return _buildPartyList(
          vendors
              .map(
                (v) => _PartyData(
                  id: v.id,
                  name: v.name,
                  phone: v.phone,
                  balance: v.totalOutstanding,
                  type: 'VENDOR',
                ),
              )
              .toList(),
          isDark,
        );
      },
    );
  }

  Widget _buildPartyList(List<_PartyData> parties, bool isDark) {
    // Calculate totals
    final totalReceivable = parties
        .where((p) => p.balance > 0)
        .fold(0.0, (sum, p) => sum + p.balance);
    final totalPayable = parties
        .where((p) => p.balance < 0)
        .fold(0.0, (sum, p) => sum + p.balance.abs());

    return Column(
      children: [
        // Summary Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                  : [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'To Receive',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalReceivable.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'To Pay',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalPayable.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Party List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: parties.length,
            itemBuilder: (context, index) {
              final party = parties[index];
              return _buildPartyCard(party, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPartyCard(_PartyData party, bool isDark) {
    final isReceivable = party.balance > 0;
    final balanceColor = isReceivable ? Colors.orange : Colors.green;
    final balanceLabel = isReceivable ? 'To Receive' : 'To Pay';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartyStatementScreen(
                partyId: party.id,
                partyName: party.name,
                partyType: party.type,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: balanceColor.withOpacity(0.1),
          child: Text(
            party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: balanceColor,
              fontWeight: FontWeight.bold,
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
            ),
          ),
        ),
        title: Text(
          party.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          party.phone ?? 'No phone',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${party.balance.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: balanceColor,
              ),
            ),
            Text(
              balanceLabel,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

/// Internal data class for party list
class _PartyData {
  final String id;
  final String name;
  final String? phone;
  final double balance;
  final String type; // CUSTOMER or VENDOR

  _PartyData({
    required this.id,
    required this.name,
    this.phone,
    required this.balance,
    required this.type,
  });
}
