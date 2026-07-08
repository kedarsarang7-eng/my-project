import 'package:flutter/material.dart';
import 'package:dukanx/features/hardware/data/hardware_ops_repository.dart';
import 'package:dukanx/features/hardware/data/hardware_endpoint_health.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'hardware_grn_screen.dart';
import 'hardware_purchase_bill_screen.dart';

class HardwarePhase12WorkspaceScreen extends StatefulWidget {
  const HardwarePhase12WorkspaceScreen({super.key});

  @override
  State<HardwarePhase12WorkspaceScreen> createState() =>
      _HardwarePhase12WorkspaceScreenState();
}

class _HardwarePhase12WorkspaceScreenState
    extends State<HardwarePhase12WorkspaceScreen> {
  final _repo = HardwareOpsRepository();
  bool _loading = true;
  String? _loadError;
  List<Map<String, dynamic>> _purchaseOrders = const [];
  List<Map<String, dynamic>> _parties = const [];
  List<Map<String, dynamic>> _pendingPurchaseOrders = const [];
  List<Map<String, dynamic>> _rateComparison = const [];
  List<Map<String, dynamic>> _salesOrders = const [];
  List<Map<String, dynamic>> _velocity = const [];
  List<Map<String, dynamic>> _deadStock = const [];

  // Rate comparison drill-down state (HARDWARE-024)
  final TextEditingController _rateFilterController = TextEditingController();
  String _rateFilterText = '';
  int _rateSortColumn = 0;
  bool _rateSortAscending = true;
  bool _rateComparisonExpanded = false;

  /// Tracks which sections had endpoint-unavailable (404/501/503) responses.
  /// Key: section label. Only present when endpoint is unavailable.
  final Map<String, String> _unavailableSections = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rateFilterController.dispose();
    super.dispose();
  }

  /// Run a repository call defensively. Per-call errors are surfaced in the
  /// returned [_LoadOutcome] without aborting the rest of the dashboard.
  /// Now also classifies endpoint-unavailable (404/501/503) distinctly from
  /// generic errors (HARDWARE-004 fix).
  Future<_LoadOutcome<T>> _safe<T>(
    String label,
    Future<T> Function() op,
    T fallback,
  ) async {
    try {
      final value = await op();
      return _LoadOutcome.ok(value);
    } on HardwareOpsException catch (e) {
      if (HardwareEndpointHealth.isEndpointUnavailable(e)) {
        return _LoadOutcome.unavailable(
          fallback,
          HardwareEndpointHealth.unavailableMessage(label),
        );
      }
      return _LoadOutcome.err(fallback, '$label: ${e.message}');
    } catch (e) {
      return _LoadOutcome.err(fallback, '$label: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    // Run all 7 independent fetches CONCURRENTLY (HARDWARE-009 fix) via
    // Future.wait rather than awaiting them one-by-one, so load is bound by
    // the slowest call instead of the sum of all seven.
    final results = await Future.wait([
      _safe(
        'Purchase orders',
        () => _repo.listPurchaseOrders(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Parties',
        () => _repo.listParties(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Pending POs',
        () => _repo.getPendingPurchaseOrders(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Rate comparison',
        () => _repo.getRateComparison(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Sales orders',
        () => _repo.listSalesOrders(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Item velocity',
        () => _repo.getFastSlowMoving(),
        const <Map<String, dynamic>>[],
      ),
      _safe(
        'Dead stock',
        () => _repo.getDeadStock(),
        const <Map<String, dynamic>>[],
      ),
    ]);

    if (!mounted) return;

    final po = results[0];
    final parties = results[1];
    final pendingPos = results[2];
    final rates = results[3];
    final salesOrders = results[4];
    final velocity = results[5];
    final deadStock = results[6];

    final errors = [
      po.error,
      parties.error,
      pendingPos.error,
      rates.error,
      salesOrders.error,
      velocity.error,
      deadStock.error,
    ].whereType<String>().toList();

    setState(() {
      _purchaseOrders = po.value as List<Map<String, dynamic>>;
      _parties = parties.value as List<Map<String, dynamic>>;
      _pendingPurchaseOrders = pendingPos.value as List<Map<String, dynamic>>;
      _rateComparison = rates.value as List<Map<String, dynamic>>;
      _salesOrders = salesOrders.value as List<Map<String, dynamic>>;
      _velocity = velocity.value as List<Map<String, dynamic>>;
      _deadStock = deadStock.value as List<Map<String, dynamic>>;
      _loadError = errors.isEmpty ? null : errors.join('\n');
      _loading = false;

      // Track endpoint unavailability for distinct UI (HARDWARE-004)
      _unavailableSections.clear();
      for (final entry in <String, _LoadOutcome>{
        'Purchase Orders': po,
        'Parties': parties,
        'Pending POs': pendingPos,
        'Rate Comparison': rates,
        'Sales Orders': salesOrders,
        'Item Velocity': velocity,
        'Dead Stock': deadStock,
      }.entries) {
        if (entry.value.isUnavailable) {
          _unavailableSections[entry.key] =
              entry.value.unavailableMessage ?? '';
        }
      }
    });

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some sections failed to load:\n${errors.join('\n')}'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: DesktopContentContainer(
        maxWidth: 1600,
        padding: const EdgeInsets.all(16),
        showScrollbar: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hardware Operations Workspace',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              _errorBanner(_loadError!),
            ],
            const SizedBox(height: 12),
            _kpiRow(),
            const SizedBox(height: 12),
            _navigableSectionCard(
              title: 'Purchase Orders',
              count: _purchaseOrders.length,
              emptyText: 'No purchase orders yet.',
              icon: Icons.assignment_outlined,
              color: cs.primary,
              onTap: () => _navigateToGrn(null),
              actionLabel: 'GRN →',
            ),
            const SizedBox(height: 12),
            _navigableSectionCard(
              title: 'Goods Receipt Notes (GRN)',
              count: null,
              emptyText: 'View and create GRNs from Purchase Orders.',
              icon: Icons.inventory_2_outlined,
              color: Colors.teal,
              onTap: () => _navigateToGrn(null),
              actionLabel: 'Open',
            ),
            const SizedBox(height: 12),
            _navigableSectionCard(
              title: 'Purchase Bills',
              count: null,
              emptyText: 'View and create Purchase Bills from GRNs.',
              icon: Icons.receipt_long_outlined,
              color: Colors.deepPurple,
              onTap: () => _navigateToPurchaseBills(null),
              actionLabel: 'Open',
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Parties & Credit Accounts',
              count: _parties.length,
              emptyText: 'No party accounts yet.',
              icon: Icons.account_balance_wallet_outlined,
              color: cs.secondary,
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Pending Purchase Orders',
              count: _pendingPurchaseOrders.length,
              emptyText: 'No pending purchase orders.',
              icon: Icons.pending_actions_outlined,
              color: cs.tertiary,
            ),
            const SizedBox(height: 12),
            _rateComparisonDrillDown(),
            const SizedBox(height: 12),
            _salesOrdersCard(),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Fast/Slow Moving',
              count: _velocity.length,
              emptyText: 'No velocity report rows yet.',
              icon: Icons.speed_outlined,
              color: cs.primary,
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Dead Stock',
              count: _deadStock.length,
              emptyText: 'No dead stock rows.',
              icon: Icons.hourglass_empty_outlined,
              color: cs.error,
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                title: Text('GST & Reports'),
                subtitle: Text(
                  'Use GST module for GSTR-1/GSTR-3B export. Phase1+2 backend contracts active.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiRow() {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            'Open POs',
            '${_purchaseOrders.length}',
            icon: Icons.assignment_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            'Credit Parties',
            '${_parties.length}',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            'Sales Orders',
            '${_salesOrders.length}',
            icon: Icons.local_shipping_outlined,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, {required IconData icon}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required int count,
    required String emptyText,
    required IconData icon,
    required Color color,
  }) {
    // HARDWARE-004: Render distinct "endpoint unavailable" UI
    if (_unavailableSections.containsKey(title)) {
      return _endpointUnavailableCard(
        title: title,
        icon: icon,
        color: color,
        message: _unavailableSections[title]!,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(count == 0 ? emptyText : '$count records'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section card with a navigation action — used for GRN / Purchase Bill
  /// cards that link into the PO → GRN → Bill pipeline.
  Widget _navigableSectionCard({
    required String title,
    required int? count,
    required String emptyText,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String actionLabel,
  }) {
    // HARDWARE-004: Render distinct "endpoint unavailable" UI
    if (_unavailableSections.containsKey(title)) {
      return _endpointUnavailableCard(
        title: title,
        icon: icon,
        color: color,
        message: _unavailableSections[title]!,
      );
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count != null
                          ? (count == 0 ? emptyText : '$count records')
                          : emptyText,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onTap, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToGrn(String? purchaseOrderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HardwareGrnScreen(purchaseOrderId: purchaseOrderId),
      ),
    );
  }

  void _navigateToPurchaseBills(String? purchaseOrderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HardwarePurchaseBillScreen(purchaseOrderId: purchaseOrderId),
      ),
    );
  }

  /// Dedicated rate-comparison drill-down view (HARDWARE-024 fix).
  /// Replaces the bare count card with an expandable item × supplier × price
  /// table that supports sorting by column and filtering by item name.
  Widget _rateComparisonDrillDown() {
    final cs = Theme.of(context).colorScheme;

    // HARDWARE-004: Render distinct "endpoint unavailable" UI
    if (_unavailableSections.containsKey('Rate Comparison')) {
      return _endpointUnavailableCard(
        title: 'Supplier Rate Comparison',
        icon: Icons.compare_arrows_outlined,
        color: cs.error,
        message: _unavailableSections['Rate Comparison']!,
      );
    }

    // Filter the rate comparison data by item name
    final filteredRateComparison = _rateFilterText.isEmpty
        ? _rateComparison
        : _rateComparison.where((row) {
            final itemName = (row['itemName'] ?? row['item_name'] ?? '')
                .toString()
                .toLowerCase();
            final supplier =
                (row['supplierName'] ??
                        row['supplier_name'] ??
                        row['supplier'] ??
                        '')
                    .toString()
                    .toLowerCase();
            final query = _rateFilterText.toLowerCase();
            return itemName.contains(query) || supplier.contains(query);
          }).toList();

    // Sort the filtered data
    final sortedRateComparison = List<Map<String, dynamic>>.from(
      filteredRateComparison,
    );
    sortedRateComparison.sort((a, b) {
      dynamic aVal, bVal;
      switch (_rateSortColumn) {
        case 0:
          aVal = (a['itemName'] ?? a['item_name'] ?? '').toString();
          bVal = (b['itemName'] ?? b['item_name'] ?? '').toString();
          break;
        case 1:
          aVal =
              (a['supplierName'] ?? a['supplier_name'] ?? a['supplier'] ?? '')
                  .toString();
          bVal =
              (b['supplierName'] ?? b['supplier_name'] ?? b['supplier'] ?? '')
                  .toString();
          break;
        case 2:
          aVal = _parsePrice(a['price'] ?? a['rate'] ?? a['unitPrice'] ?? 0);
          bVal = _parsePrice(b['price'] ?? b['rate'] ?? b['unitPrice'] ?? 0);
          break;
        default:
          aVal = '';
          bVal = '';
      }
      final cmp = Comparable.compare(aVal as Comparable, bVal as Comparable);
      return _rateSortAscending ? cmp : -cmp;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and expand/collapse toggle
            InkWell(
              onTap: () {
                setState(() {
                  _rateComparisonExpanded = !_rateComparisonExpanded;
                });
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.error.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.compare_arrows_outlined,
                      size: 18,
                      color: cs.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supplier Rate Comparison',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_rateComparison.length} records — tap to ${_rateComparisonExpanded ? 'collapse' : 'expand'}',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _rateComparisonExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: cs.primary,
                  ),
                ],
              ),
            ),

            // Drill-down table (visible when expanded)
            if (_rateComparisonExpanded) ...[
              const SizedBox(height: 12),
              // Filter field
              TextField(
                controller: _rateFilterController,
                decoration: InputDecoration(
                  hintText: 'Filter by item or supplier name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _rateFilterText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _rateFilterController.clear();
                              _rateFilterText = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _rateFilterText = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              // Results summary
              Text(
                'Showing ${sortedRateComparison.length} of ${_rateComparison.length} entries',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              // Data table with sort support
              if (sortedRateComparison.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No supplier rate rows match the filter.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    sortColumnIndex: _rateSortColumn,
                    sortAscending: _rateSortAscending,
                    columnSpacing: 24,
                    headingRowHeight: 40,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 48,
                    columns: [
                      DataColumn(
                        label: const Text(
                          'Item',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onSort: (col, asc) {
                          setState(() {
                            _rateSortColumn = col;
                            _rateSortAscending = asc;
                          });
                        },
                      ),
                      DataColumn(
                        label: const Text(
                          'Supplier',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onSort: (col, asc) {
                          setState(() {
                            _rateSortColumn = col;
                            _rateSortAscending = asc;
                          });
                        },
                      ),
                      DataColumn(
                        label: const Text(
                          'Price (₹)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        numeric: true,
                        onSort: (col, asc) {
                          setState(() {
                            _rateSortColumn = col;
                            _rateSortAscending = asc;
                          });
                        },
                      ),
                    ],
                    rows: sortedRateComparison.take(50).map((row) {
                      final itemName =
                          (row['itemName'] ?? row['item_name'] ?? 'Unknown')
                              .toString();
                      final supplier =
                          (row['supplierName'] ??
                                  row['supplier_name'] ??
                                  row['supplier'] ??
                                  'Unknown')
                              .toString();
                      final price = _parsePrice(
                        row['price'] ?? row['rate'] ?? row['unitPrice'] ?? 0,
                      );

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(itemName, overflow: TextOverflow.ellipsis),
                          ),
                          DataCell(
                            Text(supplier, overflow: TextOverflow.ellipsis),
                          ),
                          DataCell(Text('₹${price.toStringAsFixed(2)}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              if (sortedRateComparison.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing first 50 of ${sortedRateComparison.length} rows. '
                    'Use the filter to narrow results.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Parse a price value that may be num, String, or null into a double.
  double _parsePrice(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _salesOrdersCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Orders',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
            ),
            const SizedBox(height: 8),
            if (_salesOrders.isEmpty)
              const Text('No sales orders yet.')
            else
              ..._salesOrders.take(8).map((order) {
                final id = (order['id'] ?? '').toString();
                final customer = (order['customerName'] ?? '').toString();
                final status = (order['status'] ?? 'pending').toString();
                return ListTile(
                  dense: true,
                  title: Text(customer.isEmpty ? id : customer),
                  subtitle: Text('Status: $status'),
                  leading: _statusDot(status),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      try {
                        await _repo.updateSalesOrderStatus(
                          id: id,
                          status: value,
                        );
                      } on HardwareOpsException catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to update status: ${e.message}',
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }
                      await _load();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'pending', child: Text('Pending')),
                      PopupMenuItem(
                        value: 'partially_delivered',
                        child: Text('Partially Delivered'),
                      ),
                      PopupMenuItem(
                        value: 'delivered',
                        child: Text('Delivered'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    Color color;
    switch (status) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'partially_delivered':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(Icons.circle, size: 8, color: color),
    );
  }

  /// Distinct UI widget for "endpoint unavailable" state (HARDWARE-004).
  /// This is visually different from the empty-data cards — it uses an amber
  /// color scheme with a cloud-off icon and explicit messaging that the
  /// endpoint is not deployed/available, so users can distinguish it from
  /// "no records found."
  Widget _endpointUnavailableCard({
    required String title,
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.amber.shade100,
              child: Icon(
                Icons.cloud_off,
                size: 18,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          HardwareEndpointHealth.unavailableBadgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadOutcome<T> {
  final T value;
  final String? error;
  final bool isUnavailable;
  final String? unavailableMessage;
  const _LoadOutcome._(
    this.value,
    this.error, {
    this.isUnavailable = false,
    this.unavailableMessage,
  });
  factory _LoadOutcome.ok(T value) => _LoadOutcome._(value, null);
  factory _LoadOutcome.err(T fallback, String message) =>
      _LoadOutcome._(fallback, message);
  factory _LoadOutcome.unavailable(T fallback, String message) =>
      _LoadOutcome._(
        fallback,
        null,
        isUnavailable: true,
        unavailableMessage: message,
      );
}
