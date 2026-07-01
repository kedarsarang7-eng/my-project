import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/repositories/e_invoice_repository.dart';
import '../../data/models/e_invoice_model.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// e-Invoices List Screen
///
/// Displays all e-invoices with IRN status.
class EInvoicesListScreen extends StatefulWidget {
  const EInvoicesListScreen({super.key});

  @override
  State<EInvoicesListScreen> createState() => _EInvoicesListScreenState();
}

class _EInvoicesListScreenState extends State<EInvoicesListScreen>
    with SingleTickerProviderStateMixin {
  final _repository = sl<EInvoiceRepository>();
  late TabController _tabController;

  List<EInvoiceModel> _invoices = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await _repository.getAllEInvoices(
      userId: userId,
      status: _filterStatus == 'all' ? null : _filterStatus.toUpperCase(),
    );

    if (result.isSuccess) {
      setState(() {
        _invoices = result.data!;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('e-Invoice & e-Way Bills'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'e-Invoices'),
            Tab(text: 'e-Way Bills'),
          ],
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: TabBarView(
        controller: _tabController,
        children: [_buildInvoicesTab(isDark), _buildEWayBillsTab(isDark)],
      ),
      ),
    );
  }

  Widget _buildInvoicesTab(bool isDark) {
    return Column(
      children: [
        // Summary Cards
        _buildSummaryCards(isDark),

        // Filter Chips
        _buildFilterChips(isDark),

        const SizedBox(height: 8),

        // Invoice List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _invoices.isEmpty
              ? _buildEmptyState(isDark, 'No e-invoices generated')
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (_, i) =>
                        _buildInvoiceCard(_invoices[i], isDark),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEWayBillsTab(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'e-Way Bills',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate e-way bills when creating invoices',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    int total = _invoices.length;
    int generated = _invoices
        .where((i) => i.status == EInvoiceStatus.generated)
        .length;
    int pending = _invoices
        .where((i) => i.status == EInvoiceStatus.pending)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Total',
            total.toString(),
            Icons.receipt_long,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Generated',
            generated.toString(),
            Icons.verified,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Pending',
            pending.toString(),
            Icons.pending,
            Colors.orange,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['all', 'pending', 'generated', 'cancelled'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filterStatus == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f == 'all' ? 'All' : f.toUpperCase()),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _filterStatus = f);
                _loadInvoices();
              },
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoiceCard(EInvoiceModel invoice, bool isDark) {
    final statusColor = _getStatusColor(invoice.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    invoice.status == EInvoiceStatus.generated
                        ? Icons.verified
                        : Icons.receipt_long,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Bill Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill: ${invoice.billId.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(invoice.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (invoice.irn != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.key, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'IRN: ${invoice.irn!.substring(0, 20)}...',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      // Copy IRN
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('IRN copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
            if (invoice.lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoice.lastError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _retryGeneration(invoice),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'e-Invoices are generated automatically for GST invoices',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(EInvoiceStatus status) {
    switch (status) {
      case EInvoiceStatus.pending:
        return Colors.orange;
      case EInvoiceStatus.generated:
        return Colors.green;
      case EInvoiceStatus.cancelled:
        return Colors.grey;
      case EInvoiceStatus.failed:
        return Colors.red;
    }
  }

  Future<void> _retryGeneration(EInvoiceModel invoice) async {
    // Trigger retry
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Retrying generation...')));
    // Service would handle retry logic
    _loadInvoices();
  }
}
