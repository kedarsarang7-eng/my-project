/// IMEI Inventory Screen — Unit-Level Lifecycle Views (Dart)
///
/// Displays tenant-scoped IMEI units with current lifecycle state,
/// version, condition, and last-update timestamp. Supports filtering
/// by lifecycle state and shows distinct pending/confirmed indicators.
///
/// Uses application services (MobileShopLocalRepository) — NOT direct
/// DynamoDB authority. ReconciliationStatusDisplay shows sync state.
///
/// Requirements: 4.1–4.9, 11.1–11.8, 12.7
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../billing/reconciliation_status_display.dart';
import '../models/imei_unit_models.dart';
import '../repository/mobile_shop_local_repository.dart';

// ─── Inventory Screen ────────────────────────────────────────────────────────

/// Unit-level IMEI inventory screen with lifecycle filtering.
///
/// Shows all devices in the tenant scope with:
/// - Current lifecycle state (color-coded chip)
/// - Device brand/model/IMEI
/// - Version number and last-update timestamp
/// - Pending/confirmed sync status via [ReconciliationStatusDisplay]
class ImeiInventoryScreen extends StatefulWidget {
  /// The resolved tenant context (provided by guard).
  final TenantContext tenantContext;

  /// The local repository for tenant-bound data access.
  final MobileShopLocalRepository repository;

  /// Optional initial lifecycle filter from navigation query params.
  final DeviceLifecycleState? initialFilter;

  const ImeiInventoryScreen({
    super.key,
    required this.tenantContext,
    required this.repository,
    this.initialFilter,
  });

  @override
  State<ImeiInventoryScreen> createState() => _ImeiInventoryScreenState();
}

class _ImeiInventoryScreenState extends State<ImeiInventoryScreen> {
  DeviceLifecycleState? _selectedFilter;
  bool _isLoading = true;
  String? _error;
  List<_InventoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await widget.repository.listImeiUnits(
        widget.tenantContext,
        limit: 100,
      );

      final items = records.map((record) {
        final json = _entityToJson(record.entity);
        final unit = ImeiUnit.fromJson(json);
        return _InventoryItem(
          unit: unit,
          confirmationStatus: record.confirmationStatus,
          serverVersion: record.serverVersion,
          syncedAt: record.syncedAt,
        );
      }).toList();

      // Apply lifecycle filter if set
      final filtered = _selectedFilter != null
          ? items
                .where((i) => i.unit.lifecycleState == _selectedFilter)
                .toList()
          : items;

      setState(() {
        _items = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load inventory: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IMEI Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInventory,
            tooltip: 'Refresh inventory',
          ),
        ],
      ),
      body: Column(
        children: [
          // Lifecycle filter chips
          _LifecycleFilterBar(
            selected: _selectedFilter,
            onChanged: (state) {
              setState(() => _selectedFilter = state);
              _loadInventory();
            },
          ),
          const Divider(height: 1),
          // Content area
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Semantics(
          liveRegion: true,
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
                  onPressed: _loadInventory,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Semantics(
          label: 'No devices in inventory',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedFilter != null
                    ? 'No devices with status "${_lifecycleLabel(_selectedFilter!)}"'
                    : 'No devices in inventory',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        itemBuilder: (context, index) => _InventoryTile(item: _items[index]),
      ),
    );
  }

  /// Converts a Drift entity to JSON for domain model construction.
  Map<String, dynamic> _entityToJson(dynamic entity) {
    // The entity from Drift carries typed fields; build a map matching
    // ImeiUnit.fromJson expectations.
    return {
      'tenantId': entity.tenantId ?? '',
      'entityId': entity.entityId ?? '',
      'version': entity.serverVersion ?? 1,
      'dataModelVersion': entity.dataModelVersion ?? 1,
      'imei': entity.imei ?? '',
      'lifecycleState': entity.lifecycleState ?? 'IN_STOCK',
      'condition': entity.condition ?? 'NEW',
      'ownershipSource': entity.ownershipSource ?? 'PURCHASED_NEW',
      'brand': entity.brand ?? '',
      'model': entity.model ?? '',
      'color': entity.color,
      'storage': entity.storage,
      'acquisitionCost': {
        'amountMinorUnits': entity.acquisitionCostMinor ?? 0,
        'currency': entity.currency ?? 'INR',
      },
      'salePrice': {
        'amountMinorUnits': entity.salePriceMinor ?? 0,
        'currency': entity.currency ?? 'INR',
      },
      'createdAt': entity.createdAt?.toIso8601String() ?? '',
      'updatedAt': entity.updatedAt?.toIso8601String() ?? '',
    };
  }
}

// ─── Inventory Item Model ────────────────────────────────────────────────────

class _InventoryItem {
  final ImeiUnit unit;
  final String confirmationStatus;
  final int serverVersion;
  final DateTime? syncedAt;

  const _InventoryItem({
    required this.unit,
    required this.confirmationStatus,
    required this.serverVersion,
    this.syncedAt,
  });
}

// ─── Inventory Tile ──────────────────────────────────────────────────────────

class _InventoryTile extends StatelessWidget {
  final _InventoryItem item;

  const _InventoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = item.unit;
    final outcomeState = confirmationStatusToOutcomeState(
      item.confirmationStatus,
    );

    return Semantics(
      label:
          '${unit.brand} ${unit.model}, IMEI ${unit.imei}, '
          'status ${_lifecycleLabel(unit.lifecycleState)}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: brand/model + lifecycle chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${unit.brand} ${unit.model}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _LifecycleChip(state: unit.lifecycleState),
                ],
              ),
              const SizedBox(height: 8),
              // IMEI row
              Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit.imei,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Version + last update
              Row(
                children: [
                  Text(
                    'v${unit.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Updated: ${_formatTimestamp(unit.updatedAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Reconciliation status
              if (outcomeState != null)
                ReconciliationStatusDisplay(
                  outcome: ConsistencyOutcome(
                    state: outcomeState,
                    operationId: '',
                  ),
                  compact: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Lifecycle Filter Bar ────────────────────────────────────────────────────

class _LifecycleFilterBar extends StatelessWidget {
  final DeviceLifecycleState? selected;
  final ValueChanged<DeviceLifecycleState?> onChanged;

  const _LifecycleFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...DeviceLifecycleState.values.map(
            (state) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_lifecycleLabel(state)),
                selected: selected == state,
                onSelected: (_) => onChanged(state == selected ? null : state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lifecycle Chip ──────────────────────────────────────────────────────────

class _LifecycleChip extends StatelessWidget {
  final DeviceLifecycleState state;

  const _LifecycleChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, _) = _lifecycleColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _lifecycleLabel(state),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _lifecycleLabel(DeviceLifecycleState state) {
  switch (state) {
    case DeviceLifecycleState.inStock:
      return 'In Stock';
    case DeviceLifecycleState.secondHand:
      return 'Second Hand';
    case DeviceLifecycleState.reserved:
      return 'Reserved';
    case DeviceLifecycleState.salePending:
      return 'Sale Pending';
    case DeviceLifecycleState.sold:
      return 'Sold';
    case DeviceLifecycleState.returned:
      return 'Returned';
    case DeviceLifecycleState.demo:
      return 'Demo';
    case DeviceLifecycleState.inService:
      return 'In Service';
    case DeviceLifecycleState.exchanged:
      return 'Exchanged';
    case DeviceLifecycleState.damaged:
      return 'Damaged';
    case DeviceLifecycleState.retired:
      return 'Retired';
  }
}

(Color, Color) _lifecycleColor(DeviceLifecycleState state) {
  switch (state) {
    case DeviceLifecycleState.inStock:
      return (const Color(0xFF388E3C), const Color(0xFF388E3C));
    case DeviceLifecycleState.secondHand:
      return (const Color(0xFF7B1FA2), const Color(0xFF7B1FA2));
    case DeviceLifecycleState.reserved:
      return (const Color(0xFF1976D2), const Color(0xFF1976D2));
    case DeviceLifecycleState.salePending:
      return (const Color(0xFFF57C00), const Color(0xFFF57C00));
    case DeviceLifecycleState.sold:
      return (const Color(0xFF455A64), const Color(0xFF455A64));
    case DeviceLifecycleState.returned:
      return (const Color(0xFFD32F2F), const Color(0xFFD32F2F));
    case DeviceLifecycleState.demo:
      return (const Color(0xFF00796B), const Color(0xFF00796B));
    case DeviceLifecycleState.inService:
      return (const Color(0xFFFBC02D), const Color(0xFFFBC02D));
    case DeviceLifecycleState.exchanged:
      return (const Color(0xFF5D4037), const Color(0xFF5D4037));
    case DeviceLifecycleState.damaged:
      return (const Color(0xFFE53935), const Color(0xFFE53935));
    case DeviceLifecycleState.retired:
      return (const Color(0xFF757575), const Color(0xFF757575));
  }
}

String _formatTimestamp(String isoTimestamp) {
  try {
    final dt = DateTime.parse(isoTimestamp);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return isoTimestamp;
  }
}
