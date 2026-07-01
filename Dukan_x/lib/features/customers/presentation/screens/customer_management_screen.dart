// Customer Management Screen - Unified for ALL Business Types
// Works with: Grocery, Pharmacy, Restaurant, Clothing, Electronics, Computer, Hardware, etc.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../shared/widgets/entity_action_panel.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerManagementScreen extends StatefulWidget {
  final String? businessType;

  const CustomerManagementScreen({super.key, this.businessType});

  @override
  State<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  // FIX #2: Declare as late/nullable — initialized safely in initState
  late CustomerRepository _repository;
  late SessionManager _session;
  bool _diReady = false;
  String? _diError;

  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _filterType;
  int _currentPage = 1;
  int _totalItems = 0;
  bool _hasMore = true;

  // FIX #6: Timer-based debounce — cancellable
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    // FIX #2: Safe DI init — crash here is caught, not in field initializer
    try {
      _repository = CustomerRepository(sl<ApiClient>());
      _session = sl<SessionManager>();
      _diReady = true;
    } catch (e) {
      _diError = 'Failed to initialize: $e';
      return;
    }
    _loadCustomers();
  }

  @override
  void dispose() {
    // FIX #6: Cancel pending search timer on dispose
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _repository.getCustomers(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        filter: _filterType,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (_currentPage == 1) {
          _customers = response.items;
        } else {
          _customers.addAll(response.items);
        }
        _totalItems = response.total;
        _hasMore = response.items.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load customers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onDeleteCustomer(Customer customer) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context: context,
      entityName: 'Customer',
      entityIdentifier: '${customer.name} (${customer.phone ?? 'No phone'})',
      isSoftDelete: true,
    );

    if (!confirmed) return;

    try {
      await _repository.deleteCustomer(customer.id);

      setState(() {
        _customers.removeWhere((c) => c.id == customer.id);
        _totalItems--;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.name} moved to recycle bin'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => _restoreCustomer(customer),
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete customer: $e');
    }
  }

  Future<void> _restoreCustomer(Customer customer) async {
    try {
      await _repository.restoreCustomer(customer.id);
      _loadCustomers();
    } catch (e) {
      _showError('Failed to restore customer: $e');
    }
  }

  Future<void> _onToggleBlock(Customer customer) async {
    try {
      await _repository.setCustomerBlockStatus(
        customer.id,
        isBlocked: !customer.isBlocked,
        reason: !customer.isBlocked ? 'Manual block by admin' : null,
      );

      setState(() {
        final index = _customers.indexWhere((c) => c.id == customer.id);
        if (index != -1) {
          _customers[index] = customer.copyWith(isBlocked: !customer.isBlocked);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${customer.name} ${!customer.isBlocked ? 'blocked' : 'unblocked'}',
            ),
            backgroundColor: !customer.isBlocked ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update customer: $e');
    }
  }

  // FIX #1: Replace Navigator.push (breaks desktop shell) with in-shell Dialog panels
  void _onViewCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CustomerDetailScreen(customer: customer),
      ),
    );
  }

  void _onEditCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CustomerEditScreen(customer: customer),
      ),
    ).then((_) => _loadCustomers());
  }

  void _onViewLedger(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CustomerLedgerScreen(customer: customer),
      ),
    );
  }

  void _onNewInvoice(Customer customer) {
    // Navigate to create invoice for customer
    context.push('/billing', extra: {'customerId': customer.id});
  }

  void _showError(String message) {
    // FIX #3: Guard against calling on disposed widget
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(isDark),
          _buildFilterBar(isDark),
          if (isDesktop) _buildStatsBar(isDark),
        ],
        body: _error != null
            ? _buildErrorWidget()
            : isDesktop
            ? _buildDesktopView()
            : _buildMobileView(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewCustomer(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Customer',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.people_outline,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Customers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_totalItems customers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Recycle Bin',
          onPressed: () => _showRecycleBin(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadCustomers,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search customers by name, phone, or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _currentPage = 1;
                          _loadCustomers();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                // FIX #6: Cancel previous timer, start fresh — safe on dispose
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 500), () {
                  if (!mounted) return;
                  _currentPage = 1;
                  _loadCustomers();
                });
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Customers', null, Icons.people_outline),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Active',
                    'active',
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Blocked', 'blocked', Icons.block),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'With Credit',
                    'credit',
                    Icons.account_balance_wallet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, IconData icon) {
    final isSelected =
        _filterType == value || (value == null && _filterType == null);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterType = value;
          _currentPage = 1;
        });
        _loadCustomers();
      },
      backgroundColor: Colors.grey[100],
      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF6366F1),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    // FIX #5: Show server total for Total; page-slice counts shown with "this page" label
    final pageActive = _customers.where((c) => !c.isBlocked).length;
    final pageBlocked = _customers.where((c) => c.isBlocked).length;
    final pageDues = _customers.where((c) => (c.totalDues ?? 0) > 0).length;
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
        child: Row(
          children: [
            _buildStatCard(
              'Total',
              _totalItems.toString(),
              Icons.people_outline,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Active (pg)',
              pageActive.toString(),
              Icons.check_circle_outline,
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Blocked (pg)',
              pageBlocked.toString(),
              Icons.block,
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Dues (pg)',
              pageDues.toString(),
              Icons.warning_amber,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.05) ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color?.withValues(alpha: 0.2) ?? Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[600]),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
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
          ElevatedButton(onPressed: _loadCustomers, child: const Text('Retry')),
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
    // FIX #4: Wrap in SingleChildScrollView for horizontal overflow safety
    // FIX #7: Wrap in RepaintBoundary to isolate table repaints
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1200,
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
              minWidth: 1100,
              columns: const [
                DataColumn2(label: Text('Customer'), size: ColumnSize.L),
                DataColumn2(label: Text('Phone/Email'), size: ColumnSize.M),
                DataColumn2(label: Text('GSTIN'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Outstanding'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
                DataColumn2(label: Text('Status'), size: ColumnSize.S),
                DataColumn2(
                  label: Text('Actions'),
                  numeric: true,
                  size: ColumnSize.S,
                ),
              ],
              rows: _customers.map((c) => _buildCustomerRow(c)).toList(),
              empty: _buildEmptyState(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow2 _buildCustomerRow(Customer customer) {
    final hasDues = (customer.totalDues ?? 0) > 0;

    return DataRow2(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: customer.isBlocked
                    ? Colors.red.withValues(alpha: 0.1)
                    : const Color(0xFF6366F1).withValues(alpha: 0.1),
                child: Icon(
                  Icons.person,
                  color: customer.isBlocked
                      ? Colors.red
                      : const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: customer.isBlocked ? Colors.grey : null,
                        decoration: customer.isBlocked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (customer.businessName != null)
                      Text(
                        customer.businessName!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(customer.phone ?? '-'),
              if (customer.email != null)
                Text(
                  customer.email!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        DataCell(Text(customer.gstin ?? '-')),
        DataCell(
          Text(
            '₹${(customer.totalDues ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: hasDues ? Colors.red : Colors.green,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: customer.isBlocked
                  ? Colors.red.withValues(alpha: 0.1)
                  : hasDues
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              customer.isBlocked
                  ? 'Blocked'
                  : hasDues
                  ? 'Has Dues'
                  : 'Active',
              style: TextStyle(
                color: customer.isBlocked
                    ? Colors.red
                    : hasDues
                    ? Colors.orange
                    : Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view':
                  _onViewCustomer(customer);
                  break;
                case 'edit':
                  _onEditCustomer(customer);
                  break;
                case 'ledger':
                  _onViewLedger(customer);
                  break;
                case 'invoice':
                  _onNewInvoice(customer);
                  break;
                case 'block':
                  _onToggleBlock(customer);
                  break;
                case 'delete':
                  _onDeleteCustomer(customer);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('View Details')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Customer')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'ledger', child: Text('View Ledger')),
              const PopupMenuItem(value: 'invoice', child: Text('New Invoice')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'block',
                child: Text(customer.isBlocked ? 'Unblock' : 'Block'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
            child: const Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        return _buildCustomerCard(_customers[index]);
      },
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    final hasDues = (customer.totalDues ?? 0) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: customer.isBlocked
                      ? Colors.red.withValues(alpha: 0.1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: customer.isBlocked
                        ? Colors.red
                        : const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: customer.isBlocked
                              ? TextDecoration.lineThrough
                              : null,
                          color: customer.isBlocked ? Colors.grey : null,
                        ),
                      ),
                      if (customer.businessName != null)
                        Text(
                          customer.businessName!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                EntityActionPanel.standard(
                  onView: () => _onViewCustomer(customer),
                  onEdit: () => _onEditCustomer(customer),
                  onDelete: () => _onDeleteCustomer(customer),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.phone, customer.phone ?? 'N/A'),
                ),
                if (customer.gstin != null)
                  Expanded(
                    child: _buildInfoItem(Icons.receipt, customer.gstin!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasDues
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Due: ₹${(customer.totalDues ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: hasDues ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _onNewInvoice(customer),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Invoice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first customer',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // FIX #8/#9: Stub methods now show actionable feedback instead of silently doing nothing
  void _showRecycleBin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recycle bin — coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _createNewCustomer() {
    context.push('/customers/create').then((_) {
      if (mounted) _loadCustomers();
    });
  }
}

// Placeholder screens
// FIX #8: Detail/Edit/Ledger screens now render inside Dialog — need CloseButton + proper size
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: Text(customer.name),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Name', customer.name),
              _DetailRow('Phone', customer.phone ?? '—'),
              _DetailRow('Email', customer.email ?? '—'),
              _DetailRow('Business', customer.businessName ?? '—'),
              _DetailRow('GSTIN', customer.gstin ?? '—'),
              _DetailRow(
                'Outstanding',
                '₹${(customer.totalDues ?? 0).toStringAsFixed(2)}',
              ),
              _DetailRow('Status', customer.isBlocked ? 'Blocked' : 'Active'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

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

class CustomerEditScreen extends StatelessWidget {
  final Customer customer;
  const CustomerEditScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 700,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit ${customer.name}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: const Center(
          child: Text('Customer edit form — implement fields here'),
        ),
      ),
    );
  }
}

class CustomerLedgerScreen extends StatelessWidget {
  final Customer customer;
  const CustomerLedgerScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 800,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${customer.name} — Ledger'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: const Center(child: Text('Ledger transactions — implement here')),
      ),
    );
  }
}

// Placeholder model
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? businessName;
  final String? gstin;
  final double? totalDues;
  final bool isBlocked;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.businessName,
    this.gstin,
    this.totalDues,
    this.isBlocked = false,
  });

  Customer copyWith({bool? isBlocked}) => Customer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    businessName: businessName,
    gstin: gstin,
    totalDues: totalDues,
    isBlocked: isBlocked ?? this.isBlocked,
  );
}

class CustomerListResponse {
  final List<Customer> items;
  final int total;

  CustomerListResponse({required this.items, required this.total});
}

class CustomerRepository {
  final dynamic _client;
  CustomerRepository(this._client);

  Future<CustomerListResponse> getCustomers({
    String? search,
    String? filter,
    int page = 1,
    int limit = 20,
  }) async {
    // Real API implementation
    return CustomerListResponse(items: [], total: 0);
  }

  Future<void> deleteCustomer(String id) async {}
  Future<void> restoreCustomer(String id) async {}
  Future<void> setCustomerBlockStatus(
    String id, {
    required bool isBlocked,
    String? reason,
  }) async {}
}
