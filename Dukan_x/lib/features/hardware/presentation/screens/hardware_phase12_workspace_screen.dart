import 'package:flutter/material.dart';
import 'package:dukanx/features/hardware/data/hardware_ops_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Run a repository call defensively. Per-call errors are surfaced in the
  /// returned [_LoadOutcome] without aborting the rest of the dashboard.
  Future<_LoadOutcome<T>> _safe<T>(
    String label,
    Future<T> Function() op,
    T fallback,
  ) async {
    try {
      final value = await op();
      return _LoadOutcome.ok(value);
    } on HardwareOpsException catch (e) {
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

    final po = await _safe(
      'Purchase orders',
      () => _repo.listPurchaseOrders(),
      const <Map<String, dynamic>>[],
    );
    final parties = await _safe(
      'Parties',
      () => _repo.listParties(),
      const <Map<String, dynamic>>[],
    );
    final pendingPos = await _safe(
      'Pending POs',
      () => _repo.getPendingPurchaseOrders(),
      const <Map<String, dynamic>>[],
    );
    final rates = await _safe(
      'Rate comparison',
      () => _repo.getRateComparison(),
      const <Map<String, dynamic>>[],
    );
    final salesOrders = await _safe(
      'Sales orders',
      () => _repo.listSalesOrders(),
      const <Map<String, dynamic>>[],
    );
    final velocity = await _safe(
      'Item velocity',
      () => _repo.getFastSlowMoving(),
      const <Map<String, dynamic>>[],
    );
    final deadStock = await _safe(
      'Dead stock',
      () => _repo.getDeadStock(),
      const <Map<String, dynamic>>[],
    );

    if (!mounted) return;

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
      _purchaseOrders = po.value;
      _parties = parties.value;
      _pendingPurchaseOrders = pendingPos.value;
      _rateComparison = rates.value;
      _salesOrders = salesOrders.value;
      _velocity = velocity.value;
      _deadStock = deadStock.value;
      _loadError = errors.isEmpty ? null : errors.join('\n');
      _loading = false;
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
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            _sectionCard(
              title: 'Purchase Orders',
              count: _purchaseOrders.length,
              emptyText: 'No purchase orders yet.',
              icon: Icons.assignment_outlined,
              color: cs.primary,
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
            _sectionCard(
              title: 'Supplier Rate Comparison',
              count: _rateComparison.length,
              emptyText: 'No supplier rate rows yet.',
              icon: Icons.compare_arrows_outlined,
              color: cs.error,
            ),
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
  const _LoadOutcome._(this.value, this.error);
  factory _LoadOutcome.ok(T value) => _LoadOutcome._(value, null);
  factory _LoadOutcome.err(T fallback, String message) =>
      _LoadOutcome._(fallback, message);
}
