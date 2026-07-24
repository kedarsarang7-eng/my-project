/// Demo Management Screen — Demo Unit Lifecycle Tracking (Dart)
///
/// Manages demo units: marking devices as demo, tracking demo lifecycle,
/// and returning demo units to stock. Shows distinct pending/confirmed
/// states for all transitions.
///
/// Uses application services (MobileShopLocalRepository + outbox) — NOT
/// direct authority. All demo transitions are conditional on version.
///
/// Requirements: 4.5, 4.9, 11.1–11.8, 12.7
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../billing/reconciliation_status_display.dart';
import '../models/imei_unit_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'inventory_command_service.dart';

// ─── Demo Management Screen ──────────────────────────────────────────────────

/// Manages the demo device lifecycle.
///
/// Displays all devices currently in DEMO state, allows marking in-stock
/// devices as demo, and supports returning demo units to stock.
/// Each transition shows pending/confirmed status.
class DemoManagementScreen extends StatefulWidget {
  /// The resolved tenant context (provided by guard).
  final TenantContext tenantContext;

  /// The local repository for tenant-bound data access.
  final MobileShopLocalRepository repository;

  /// Command service for queuing inventory operations.
  final InventoryCommandService? commandService;

  const DemoManagementScreen({
    super.key,
    required this.tenantContext,
    required this.repository,
    this.commandService,
  });

  @override
  State<DemoManagementScreen> createState() => _DemoManagementScreenState();
}

class _DemoManagementScreenState extends State<DemoManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<_DemoUnitItem> _demoUnits = [];

  @override
  void initState() {
    super.initState();
    _loadDemoUnits();
  }

  Future<void> _loadDemoUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await widget.repository.listImeiUnits(
        widget.tenantContext,
        limit: 100,
      );

      // Filter to demo-state units
      final demoUnits = records
          .where((r) => r.entity.lifecycleState == 'DEMO')
          .map(
            (record) => _DemoUnitItem(
              entityId: record.entity.entityId,
              imei: record.entity.imei,
              brand: record.entity.brand ?? '',
              model: record.entity.model ?? '',
              color: null,
              storage: null,
              condition: record.entity.condition ?? 'GOOD',
              serverVersion: record.serverVersion,
              confirmationStatus: record.confirmationStatus,
              syncedAt: record.syncedAt,
              updatedAt: record.entity.updatedAt,
            ),
          )
          .toList();

      setState(() {
        _demoUnits = demoUnits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load demo units: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Units'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDemoUnits,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMarkAsDemoDialog,
        icon: const Icon(Icons.add),
        label: const Text('Mark as Demo'),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadDemoUnits,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_demoUnits.isEmpty) {
      return Center(
        child: Semantics(
          label: 'No demo units',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No demo units',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mark a device as demo to track it here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDemoUnits,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _demoUnits.length,
        itemBuilder: (context, index) => _DemoUnitTile(
          item: _demoUnits[index],
          onReturnToStock: () => _returnToStock(_demoUnits[index]),
        ),
      ),
    );
  }

  void _showMarkAsDemoDialog() {
    showDialog(
      context: context,
      builder: (context) => _MarkAsDemoDialog(
        tenantContext: widget.tenantContext,
        repository: widget.repository,
        onMarked: _loadDemoUnits,
      ),
    );
  }

  Future<void> _returnToStock(_DemoUnitItem unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Stock'),
        content: Text(
          'Return ${unit.brand} ${unit.model} (${unit.imei}) from demo to stock?\n\n'
          'Current version: v${unit.serverVersion}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Return to Stock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cmdService =
          widget.commandService ??
          InventoryCommandService(repository: widget.repository);

      await cmdService.queueDemoTransition(
        context: widget.tenantContext,
        imei: unit.imei,
        expectedVersion: unit.serverVersion,
        targetState: 'IN_STOCK',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return to stock queued. Pending confirmation.'),
          ),
        );
        _loadDemoUnits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

// ─── Demo Unit Item ──────────────────────────────────────────────────────────

class _DemoUnitItem {
  final String entityId;
  final String imei;
  final String brand;
  final String model;
  final String? color;
  final String? storage;
  final String condition;
  final int serverVersion;
  final String confirmationStatus;
  final DateTime? syncedAt;
  final dynamic updatedAt;

  const _DemoUnitItem({
    required this.entityId,
    required this.imei,
    required this.brand,
    required this.model,
    this.color,
    this.storage,
    required this.condition,
    required this.serverVersion,
    required this.confirmationStatus,
    this.syncedAt,
    this.updatedAt,
  });
}

// ─── Demo Unit Tile ──────────────────────────────────────────────────────────

class _DemoUnitTile extends StatelessWidget {
  final _DemoUnitItem item;
  final VoidCallback onReturnToStock;

  const _DemoUnitTile({required this.item, required this.onReturnToStock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomeState = confirmationStatusToOutcomeState(
      item.confirmationStatus,
    );

    return Semantics(
      label: 'Demo unit: ${item.brand} ${item.model}, IMEI ${item.imei}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.devices_other,
                      color: Color(0xFF00796B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.brand} ${item.model}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.color != null || item.storage != null)
                          Text(
                            [item.color, item.storage]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // IMEI + version
              Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.imei,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'v${item.serverVersion}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Sync status + action
              Row(
                children: [
                  if (outcomeState != null)
                    Expanded(
                      child: ReconciliationStatusDisplay(
                        outcome: ConsistencyOutcome(
                          state: outcomeState,
                          operationId: '',
                        ),
                        compact: true,
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton.icon(
                    onPressed: onReturnToStock,
                    icon: const Icon(Icons.keyboard_return, size: 18),
                    label: const Text('Return to Stock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mark as Demo Dialog ─────────────────────────────────────────────────────

class _MarkAsDemoDialog extends StatefulWidget {
  final TenantContext tenantContext;
  final MobileShopLocalRepository repository;
  final VoidCallback onMarked;

  const _MarkAsDemoDialog({
    required this.tenantContext,
    required this.repository,
    required this.onMarked,
  });

  @override
  State<_MarkAsDemoDialog> createState() => _MarkAsDemoDialogState();
}

class _MarkAsDemoDialogState extends State<_MarkAsDemoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imeiController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _imeiController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Mark Device as Demo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _imeiController,
                decoration: const InputDecoration(
                  labelText: 'Device IMEI *',
                  hintText: 'Enter IMEI of in-stock device',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                keyboardType: TextInputType.number,
                maxLength: 15,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'IMEI required';
                  if (v.trim().length != 15) return 'Must be 15 digits';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why is this device being marked as demo?',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _markAsDemo,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark as Demo'),
        ),
      ],
    );
  }

  Future<void> _markAsDemo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Verify the unit exists and is in-stock (eligible for demo)
      final unit = await widget.repository.getImeiUnit(
        widget.tenantContext,
        _imeiController.text.trim(),
      );

      if (unit == null) {
        setState(() {
          _error = 'No device found with this IMEI.';
          _isSubmitting = false;
        });
        return;
      }

      if (unit.entity.lifecycleState != 'IN_STOCK') {
        setState(() {
          _error =
              'Only in-stock devices can be marked as demo. '
              'Current state: ${unit.entity.lifecycleState}';
          _isSubmitting = false;
        });
        return;
      }

      // Queue demo transition
      final cmdService = InventoryCommandService(repository: widget.repository);

      await cmdService.queueDemoTransition(
        context: widget.tenantContext,
        imei: _imeiController.text.trim(),
        expectedVersion: unit.serverVersion,
        targetState: 'DEMO',
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onMarked();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo transition queued. Pending confirmation.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed: $e';
        _isSubmitting = false;
      });
    }
  }
}

// ─── Internal Mutation Data ──────────────────────────────────────────────────

// End of file
