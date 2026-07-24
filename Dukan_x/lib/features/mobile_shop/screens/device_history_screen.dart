/// MobileShop Device History Screen (Dart)
///
/// Connected device history showing all lifecycle events for an IMEI
/// across its lifetime. Uses unified TenantContext, live repository data,
/// and typed loading/empty/error/session states.
///
/// Requirements: 2.7, 5.8–5.11, 9.1–9.8, 12.4
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../models/audit_event_models.dart';
import '../models/imei_unit_models.dart';
import '../models/common_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../widgets/mobile_shop_session_state.dart';
import 'screen_state.dart';

// ─── Device History Screen ───────────────────────────────────────────────────

/// Shows the complete lifecycle history for a specific IMEI unit.
///
/// Displays:
/// - Current unit state summary
/// - Chronological timeline of all lifecycle events
/// - Connected service jobs, exchanges, warranty claims
///
/// Integrates with:
/// - [TenantContextResolver] for unified identity
/// - [MobileShopLocalRepository] for live data
class DeviceHistoryScreen extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  /// The normalized IMEI to show history for.
  final String imei;

  const DeviceHistoryScreen({
    super.key,
    required this.resolver,
    required this.repository,
    required this.imei,
  });

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  ScreenState<_DeviceHistoryData> _state = const ScreenLoading();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _state = const ScreenLoading());

    final result = widget.resolver.requireMobileShop();
    switch (result) {
      case TenantFailure(:final error):
        setState(() => _state = ScreenSessionLost(message: error.message));
        return;
      case TenantSuccess(:final value):
        try {
          // Load the unit record
          final unitRecord = await widget.repository.getImeiUnit(
            value,
            widget.imei,
          );

          if (unitRecord == null) {
            setState(
              () => _state = ScreenEmpty(
                message: 'No device found with IMEI ${widget.imei}',
              ),
            );
            return;
          }

          // Parse unit for display
          final unit = ImeiUnit.fromJson(_entityToJson(unitRecord.entity));

          // Build connected history from available local data:
          // service jobs, exchanges, and warranties associated with this IMEI
          final serviceJobs = await widget.repository.listServiceJobs(value);
          final exchanges = await widget.repository.listExchanges(value);
          final warranties = await widget.repository.listWarranties(value);

          // Filter for this IMEI
          final relatedJobs = serviceJobs.where((r) {
            try {
              final json = _entityToJson(r.entity);
              return json['imei'] == widget.imei;
            } catch (_) {
              return false;
            }
          }).toList();

          final relatedExchanges = exchanges.where((r) {
            try {
              final json = _entityToJson(r.entity);
              return json['oldDeviceImei'] == widget.imei ||
                  json['newDeviceImei'] == widget.imei;
            } catch (_) {
              return false;
            }
          }).toList();

          final relatedWarranties = warranties.where((r) {
            try {
              final json = _entityToJson(r.entity);
              return json['imei'] == widget.imei;
            } catch (_) {
              return false;
            }
          }).toList();

          // Build timeline events from connected data
          final events = <_HistoryEvent>[];

          // Unit creation
          events.add(
            _HistoryEvent(
              timestamp: unit.createdAt,
              action: 'Unit Created',
              description:
                  'Device registered as ${unit.ownershipSource.toWireValue().replaceAll('_', ' ')}',
              icon: Icons.add_circle_outline,
              color: Colors.green,
            ),
          );

          // Service jobs
          for (final job in relatedJobs) {
            final json = _entityToJson(job.entity);
            events.add(
              _HistoryEvent(
                timestamp: json['createdAt'] as String? ?? '',
                action: 'Service: ${json['status'] ?? 'Unknown'}',
                description:
                    json['faultDescription'] as String? ?? 'Service job',
                icon: Icons.build_circle_outlined,
                color: Colors.blue,
              ),
            );
          }

          // Exchanges
          for (final ex in relatedExchanges) {
            final json = _entityToJson(ex.entity);
            final isOld = json['oldDeviceImei'] == widget.imei;
            events.add(
              _HistoryEvent(
                timestamp: json['createdAt'] as String? ?? '',
                action: isOld ? 'Exchanged Out' : 'Exchanged In',
                description:
                    '${json['oldDeviceBrand']} → ${json['newDeviceBrand']}',
                icon: Icons.swap_horiz,
                color: Colors.orange,
              ),
            );
          }

          // Warranties
          for (final w in relatedWarranties) {
            final json = _entityToJson(w.entity);
            events.add(
              _HistoryEvent(
                timestamp: json['createdAt'] as String? ?? '',
                action: 'Warranty: ${json['status'] ?? 'Registered'}',
                description:
                    '${json['warrantyType'] ?? ''} - ${json['provider'] ?? ''}',
                icon: Icons.verified_user,
                color: Colors.purple,
              ),
            );
          }

          // Sort by timestamp descending (newest first)
          events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          setState(
            () => _state = ScreenData(
              data: _DeviceHistoryData(
                unit: unit,
                unitRecord: unitRecord,
                events: events,
              ),
              lastRefreshed: DateTime.now(),
            ),
          );
        } catch (e) {
          setState(
            () => _state = ScreenError(
              errorCode: 'LOAD_FAILED',
              message: 'Failed to load device history: ${e.toString()}',
              isRetryable: true,
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device History: ${widget.imei}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return _state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      onData: (historyData, isStale, _) =>
          _buildHistory(context, historyData, isStale),
      empty: (message) => Center(
        child: Semantics(
          label: message ?? 'No device history found',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'No device history found',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      error: (code, message, isRetryable) => Center(
        child: Semantics(
          label: 'Error: $message',
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                if (isRetryable) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      sessionLost: (message) => SessionExpiredView(
        error: DomainError(
          kind: DomainErrorKind.sessionExpired,
          message: message,
        ),
      ),
    );
  }

  Widget _buildHistory(
    BuildContext context,
    _DeviceHistoryData data,
    bool isStale,
  ) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isStale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Data may be stale',
                style: theme.textTheme.labelSmall,
              ),
            ),
          // Unit summary card
          _UnitSummaryCard(unit: data.unit, record: data.unitRecord),
          const SizedBox(height: 16),
          // Timeline header
          Text(
            'Lifecycle History (${data.events.length} events)',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // Timeline
          if (data.events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No lifecycle events recorded yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...data.events.map((event) => _TimelineEventTile(event: event)),
        ],
      ),
    );
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class _DeviceHistoryData {
  final ImeiUnit unit;
  final LocalRecord unitRecord;
  final List<_HistoryEvent> events;

  const _DeviceHistoryData({
    required this.unit,
    required this.unitRecord,
    required this.events,
  });
}

class _HistoryEvent {
  final String timestamp;
  final String action;
  final String description;
  final IconData icon;
  final Color color;

  const _HistoryEvent({
    required this.timestamp,
    required this.action,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ─── Unit Summary Card ───────────────────────────────────────────────────────

class _UnitSummaryCard extends StatelessWidget {
  final ImeiUnit unit;
  final LocalRecord record;

  const _UnitSummaryCard({required this.unit, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lifecycleColor = _lifecycleColor(theme, unit.lifecycleState);

    return Semantics(
      label:
          '${unit.brand} ${unit.model}, IMEI ${unit.imei}, '
          'state ${unit.lifecycleState.toWireValue().replaceAll('_', ' ')}',
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android, color: lifecycleColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${unit.brand} ${unit.model}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          unit.imei,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: lifecycleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      unit.lifecycleState.toWireValue().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lifecycleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Details grid
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _DetailItem(
                    label: 'Condition',
                    value: unit.condition.toWireValue(),
                  ),
                  _DetailItem(
                    label: 'Source',
                    value: unit.ownershipSource.toWireValue().replaceAll(
                      '_',
                      ' ',
                    ),
                  ),
                  if (unit.color != null)
                    _DetailItem(label: 'Color', value: unit.color!),
                  if (unit.storage != null)
                    _DetailItem(label: 'Storage', value: unit.storage!),
                  _DetailItem(label: 'Version', value: 'v${unit.version}'),
                  if (!record.isServerConfirmed)
                    _DetailItem(
                      label: 'Sync',
                      value: record.isPending ? 'Pending' : 'Conflict',
                    ),
                ],
              ),
              if (unit.warrantyEndDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Warranty: ${unit.warrantyStartDate ?? '?'} → ${unit.warrantyEndDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _lifecycleColor(ThemeData theme, DeviceLifecycleState state) {
    return switch (state) {
      DeviceLifecycleState.inStock => Colors.green,
      DeviceLifecycleState.secondHand => Colors.teal,
      DeviceLifecycleState.reserved => Colors.blue,
      DeviceLifecycleState.salePending => Colors.amber.shade700,
      DeviceLifecycleState.sold => Colors.indigo,
      DeviceLifecycleState.returned => Colors.orange,
      DeviceLifecycleState.demo => Colors.purple,
      DeviceLifecycleState.inService => Colors.cyan,
      DeviceLifecycleState.exchanged => Colors.deepOrange,
      DeviceLifecycleState.damaged => theme.colorScheme.error,
      DeviceLifecycleState.retired => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// ─── Timeline Event Tile ─────────────────────────────────────────────────────

class _TimelineEventTile extends StatelessWidget {
  final _HistoryEvent event;

  const _TimelineEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${event.action}: ${event.description}, at ${event.timestamp}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: event.color.withOpacity(0.15),
                  child: Icon(event.icon, size: 14, color: event.color),
                ),
                Container(
                  width: 2,
                  height: 32,
                  color: theme.colorScheme.outlineVariant,
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.action,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    event.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatTimestamp(event.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  String _formatTimestamp(String ts) {
    final dt = DateTime.tryParse(ts);
    if (dt == null) return ts;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _entityToJson(dynamic entity) {
  if (entity is Map) return entity.cast<String, dynamic>();
  try {
    return (entity as dynamic).toJson() as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}
