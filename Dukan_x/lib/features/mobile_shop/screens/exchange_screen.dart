/// MobileShop Exchange Screen (Dart)
///
/// Device exchange workflow showing both sides of the exchange (old/new device),
/// financial adjustments, lifecycle transitions. Uses unified TenantContext,
/// expected versions, live repository data, exact status filters, and typed
/// loading/empty/error/session states.
///
/// Requirements: 5.4, 5.8–5.11, 9.1–9.8, 12.4
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../models/exchange_models.dart';
import '../models/common_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../widgets/mobile_shop_session_state.dart';
import 'screen_state.dart';

// ─── Exchange List Screen ────────────────────────────────────────────────────

/// Lists device exchanges with status filtering, showing both old and new
/// device info, financial adjustment direction, and sync state.
class ExchangeScreen extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  /// Optional initial status filter (from query param or status card).
  final String? initialStatusFilter;

  const ExchangeScreen({
    super.key,
    required this.resolver,
    required this.repository,
    this.initialStatusFilter,
  });

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  ScreenState<List<_ExchangeDisplay>> _state = const ScreenLoading();
  ExchangeStatus? _activeFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      try {
        _activeFilter = ExchangeStatus.fromWire(
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
          final records = await widget.repository.listExchanges(
            value,
            status: _activeFilter?.toWireValue(),
          );

          if (records.isEmpty) {
            setState(
              () => _state = ScreenEmpty(
                message: _activeFilter != null
                    ? 'No exchanges with status "${_activeFilter!.toWireValue()}"'
                    : 'No exchanges found',
              ),
            );
          } else {
            final items = records
                .map(
                  (r) => _ExchangeDisplay(
                    record: r,
                    exchange: Exchange.fromJson(_entityToJson(r.entity)),
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
              message: 'Failed to load exchanges: ${e.toString()}',
              isRetryable: true,
            ),
          );
        }
    }
  }

  void _setFilter(ExchangeStatus? status) {
    setState(() => _activeFilter = status);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exchanges'),
        actions: [
          PopupMenuButton<ExchangeStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: _setFilter,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...ExchangeStatus.values.map(
                (s) => PopupMenuItem(
                  value: s,
                  child: Text(s.toWireValue().replaceAll('_', ' ')),
                ),
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
      empty: (message) => _EmptyState(message: message),
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
    List<_ExchangeDisplay> items,
    bool isStale,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_activeFilter != null)
          _FilterBanner(
            label: _activeFilter!.toWireValue().replaceAll('_', ' '),
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
                  _ExchangeTile(display: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Display Model ───────────────────────────────────────────────────────────

class _ExchangeDisplay {
  final LocalRecord record;
  final Exchange exchange;

  const _ExchangeDisplay({required this.record, required this.exchange});
}

// ─── Exchange Tile ───────────────────────────────────────────────────────────

class _ExchangeTile extends StatelessWidget {
  final _ExchangeDisplay display;

  const _ExchangeTile({required this.display});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = display.exchange;
    final record = display.record;

    return Semantics(
      label:
          'Exchange for ${ex.customerName}: '
          '${ex.oldDeviceBrand} ${ex.oldDeviceModel} to '
          '${ex.newDeviceBrand} ${ex.newDeviceModel}, '
          'status ${ex.status.toWireValue().replaceAll('_', ' ')}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: customer + status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ex.customerName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ExchangeStatusChip(status: ex.status),
                  if (!record.isServerConfirmed) ...[
                    const SizedBox(width: 4),
                    _SyncChip(isPending: record.isPending),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Old device → New device
              Row(
                children: [
                  Expanded(
                    child: _DeviceSide(
                      label: 'Old',
                      brand: ex.oldDeviceBrand,
                      model: ex.oldDeviceModel,
                      imei: ex.oldDeviceImei,
                      icon: Icons.phone_android,
                      iconColor: theme.colorScheme.error,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _DeviceSide(
                      label: 'New',
                      brand: ex.newDeviceBrand,
                      model: ex.newDeviceModel,
                      imei: ex.newDeviceImei,
                      icon: Icons.phone_iphone,
                      iconColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Financial adjustment
              _AdjustmentRow(
                amount: ex.adjustmentAmount,
                direction: ex.adjustmentDirection,
              ),
              // Version info
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'v${ex.version}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

// ─── Sub-components ──────────────────────────────────────────────────────────

class _DeviceSide extends StatelessWidget {
  final String label;
  final String brand;
  final String model;
  final String imei;
  final IconData icon;
  final Color iconColor;

  const _DeviceSide({
    required this.label,
    required this.brand,
    required this.model,
    required this.imei,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
        Text(
          '$brand $model',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          imei,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  final Money amount;
  final AdjustmentDirection direction;

  const _AdjustmentRow({required this.amount, required this.direction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = _formatMoney(amount);
    final dirLabel = direction == AdjustmentDirection.customerPays
        ? 'Customer pays'
        : 'Customer receives';
    final color = direction == AdjustmentDirection.customerPays
        ? theme.colorScheme.primary
        : Colors.green;

    return Row(
      children: [
        Icon(Icons.payments_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$dirLabel: $formatted',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }

  String _formatMoney(Money money) {
    final major = money.amountMinorUnits ~/ 100;
    final minor = money.amountMinorUnits % 100;
    return '${money.currency == 'INR' ? '₹' : money.currency} $major.${minor.toString().padLeft(2, '0')}';
  }
}

class _ExchangeStatusChip extends StatelessWidget {
  final ExchangeStatus status;

  const _ExchangeStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      ExchangeStatus.initiated => theme.colorScheme.primary,
      ExchangeStatus.valuationPending => Colors.orange,
      ExchangeStatus.valuationApproved => Colors.amber.shade700,
      ExchangeStatus.approved => Colors.blue,
      ExchangeStatus.completed => Colors.green,
      ExchangeStatus.cancelled => theme.colorScheme.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toWireValue().replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final bool isPending;

  const _SyncChip({required this.isPending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPending
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    final label = isPending ? 'Pending' : 'Conflict';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

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

  const _EmptyState({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: message ?? 'No exchanges found',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'No exchanges found',
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
