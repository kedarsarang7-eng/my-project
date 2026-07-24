/// MobileShop Warranty Screen (Dart)
///
/// Warranty management with month-end date calculation, claim
/// creation/resolution, evidence attachment. Uses unified TenantContext,
/// expected versions, live repository data, and typed states.
///
/// Requirements: 5.5–5.7, 5.8–5.11, 9.1–9.8, 12.4
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../models/warranty_models.dart';
import '../models/common_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../widgets/mobile_shop_session_state.dart';
import 'screen_state.dart';

// ─── Warranty List Screen ────────────────────────────────────────────────────

/// Lists warranties with status filtering, month-end warranty behavior,
/// claim status visibility, and typed screen states.
class WarrantyManagementScreen extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  /// Optional initial status filter.
  final String? initialStatusFilter;

  const WarrantyManagementScreen({
    super.key,
    required this.resolver,
    required this.repository,
    this.initialStatusFilter,
  });

  @override
  State<WarrantyManagementScreen> createState() =>
      _WarrantyManagementScreenState();
}

class _WarrantyManagementScreenState extends State<WarrantyManagementScreen> {
  ScreenState<List<_WarrantyDisplay>> _state = const ScreenLoading();
  WarrantyStatus? _activeFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      try {
        _activeFilter = WarrantyStatus.fromWire(
          widget.initialStatusFilter!.toUpperCase(),
        );
      } catch (_) {}
    }
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
          final records = await widget.repository.listWarranties(
            value,
            status: _activeFilter?.toWireValue(),
          );

          if (records.isEmpty) {
            setState(
              () => _state = ScreenEmpty(
                message: _activeFilter != null
                    ? 'No warranties with status "${_activeFilter!.toWireValue()}"'
                    : 'No warranties found',
              ),
            );
          } else {
            final items = records
                .map(
                  (r) => _WarrantyDisplay(
                    record: r,
                    warranty: Warranty.fromJson(_entityToJson(r.entity)),
                  ),
                )
                .toList();
            setState(
              () => _state = ScreenData(
                data: items,
                lastRefreshed: DateTime.now(),
              ),
            );
          }
        } catch (e) {
          setState(
            () => _state = ScreenError(
              errorCode: 'LOAD_FAILED',
              message: 'Failed to load warranties: ${e.toString()}',
              isRetryable: true,
            ),
          );
        }
    }
  }

  void _setFilter(WarrantyStatus? status) {
    setState(() => _activeFilter = status);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty Management'),
        actions: [
          PopupMenuButton<WarrantyStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: _setFilter,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...WarrantyStatus.values.map(
                (s) => PopupMenuItem(value: s, child: Text(s.toWireValue())),
              ),
            ],
          ),
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
      onData: (items, isStale, _) => _buildList(context, items, isStale),
      empty: (message) =>
          _EmptyState(message: message, icon: Icons.verified_user_outlined),
      error: (code, message, isRetryable) => _ErrorState(
        message: message,
        isRetryable: isRetryable,
        onRetry: _loadData,
      ),
      sessionLost: (message) => SessionExpiredView(
        error: DomainError(
          kind: DomainErrorKind.sessionExpired,
          message: message,
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<_WarrantyDisplay> items,
    bool isStale,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_activeFilter != null)
          _FilterBanner(
            label: _activeFilter!.toWireValue(),
            onClear: () => _setFilter(null),
          ),
        if (isStale) _StaleBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) =>
                  _WarrantyTile(display: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Display Model ───────────────────────────────────────────────────────────

class _WarrantyDisplay {
  final LocalRecord record;
  final Warranty warranty;

  const _WarrantyDisplay({required this.record, required this.warranty});

  /// Whether the warranty has expired based on endDate.
  bool get isExpired {
    final end = DateTime.tryParse(warranty.endDate);
    return end != null && end.isBefore(DateTime.now());
  }

  /// Days until expiry (negative if expired).
  int? get daysUntilExpiry {
    final end = DateTime.tryParse(warranty.endDate);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }
}

// ─── Warranty Tile ───────────────────────────────────────────────────────────

class _WarrantyTile extends StatelessWidget {
  final _WarrantyDisplay display;

  const _WarrantyTile({required this.display});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = display.warranty;
    final record = display.record;

    final statusColor = _warrantyStatusColor(theme, w.status);
    final expiryInfo = _buildExpiryInfo(theme);

    return Semantics(
      label:
          'Warranty for IMEI ${w.imei}, '
          'type ${w.warrantyType.toWireValue()}, '
          'status ${w.status.toWireValue()}, '
          'provider ${w.provider}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.verified_user, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${w.warrantyType.toWireValue()} Warranty',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  _WarrantyStatusChip(status: w.status, color: statusColor),
                  if (!record.isServerConfirmed) ...[
                    const SizedBox(width: 4),
                    _SyncIndicator(isPending: record.isPending),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // IMEI + Provider
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'IMEI: ${w.imei}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    w.provider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Period: month-end warranty dates
              Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${w.startDate} → ${w.endDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${w.durationMonths} months)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              // Expiry info
              if (expiryInfo != null) ...[
                const SizedBox(height: 4),
                expiryInfo,
              ],
              // Version
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'v${w.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildExpiryInfo(ThemeData theme) {
    final days = display.daysUntilExpiry;
    if (days == null) return null;

    if (days < 0) {
      return Text(
        'Expired ${(-days)} days ago',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (days <= 30) {
      return Text(
        'Expires in $days days',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.orange,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return null;
  }

  Color _warrantyStatusColor(ThemeData theme, WarrantyStatus status) {
    return switch (status) {
      WarrantyStatus.active => Colors.green,
      WarrantyStatus.expired => theme.colorScheme.error,
      WarrantyStatus.claimed => Colors.orange,
      WarrantyStatus.void_ => theme.colorScheme.onSurfaceVariant,
    };
  }
}

// ─── Sub-Widgets ─────────────────────────────────────────────────────────────

class _WarrantyStatusChip extends StatelessWidget {
  final WarrantyStatus status;
  final Color color;

  const _WarrantyStatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toWireValue(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final bool isPending;

  const _SyncIndicator({required this.isPending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPending
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    return Icon(
      isPending ? Icons.sync : Icons.sync_problem,
      size: 14,
      color: color,
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterBanner({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: [
          Text('Filter: $label', style: theme.textTheme.labelMedium),
          const Spacer(),
          TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.tertiaryContainer,
      child: Text('Data may be stale', style: theme.textTheme.labelSmall),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? message;
  final IconData icon;

  const _EmptyState({this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: message ?? 'No items found',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'No items found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final bool isRetryable;
  final VoidCallback? onRetry;

  const _ErrorState({
    required this.message,
    required this.isRetryable,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (isRetryable && onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
