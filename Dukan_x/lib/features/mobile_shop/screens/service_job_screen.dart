/// MobileShop Service Job Screen (Dart)
///
/// Lists and manages service/repair jobs. Uses unified TenantContext,
/// expected versions for conditional updates, live repository data,
/// exact status filters, and typed loading/empty/error/session states.
///
/// Requirements: 5.1–5.3, 5.8–5.11, 9.1–9.8, 12.4
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/tenant_context_resolver.dart';
import '../models/service_job_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../widgets/mobile_shop_session_state.dart';
import 'screen_state.dart';

// ─── Service Job List Screen ─────────────────────────────────────────────────

/// Main service job list screen with status filtering, search, and
/// typed screen states.
///
/// Integrates with:
/// - [TenantContextResolver] for unified identity
/// - [MobileShopLocalRepository] for live data
/// - Exact status filter from query params or status card navigation
class ServiceJobScreen extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  /// Optional initial status filter (from query param or status card).
  final String? initialStatusFilter;

  const ServiceJobScreen({
    super.key,
    required this.resolver,
    required this.repository,
    this.initialStatusFilter,
  });

  @override
  State<ServiceJobScreen> createState() => _ServiceJobScreenState();
}

class _ServiceJobScreenState extends State<ServiceJobScreen> {
  ScreenState<List<_ServiceJobDisplay>> _state = const ScreenLoading();
  ServiceJobStatus? _activeFilter;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      try {
        _activeFilter = ServiceJobStatus.fromWire(
          widget.initialStatusFilter!.toUpperCase(),
        );
      } catch (_) {
        // Invalid filter value — ignore and show all
      }
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
          final records = await widget.repository.listServiceJobs(
            value,
            status: _activeFilter?.toWireValue(),
          );

          if (records.isEmpty) {
            setState(
              () => _state = ScreenEmpty(
                message: _activeFilter != null
                    ? 'No service jobs with status "${_activeFilter!.toWireValue()}"'
                    : 'No service jobs found',
              ),
            );
          } else {
            final items = records
                .map(
                  (r) => _ServiceJobDisplay(
                    record: r,
                    job: ServiceJob.fromJson(_entityToJson(r.entity)),
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
              message: 'Failed to load service jobs: ${e.toString()}',
              isRetryable: true,
            ),
          );
        }
    }
  }

  void _setFilter(ServiceJobStatus? status) {
    setState(() => _activeFilter = status);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Jobs'),
        actions: [
          PopupMenuButton<ServiceJobStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: _setFilter,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...ServiceJobStatus.values.map(
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
      empty: (message) => _EmptyStateWidget(message: message),
      error: (code, message, isRetryable) => _ErrorStateWidget(
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
    List<_ServiceJobDisplay> items,
    bool isStale,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (_activeFilter != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.secondaryContainer,
            child: Row(
              children: [
                Text(
                  'Filter: ${_activeFilter!.toWireValue().replaceAll('_', ' ')}',
                  style: theme.textTheme.labelMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _setFilter(null),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        if (isStale)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.tertiaryContainer,
            child: Text('Data may be stale', style: theme.textTheme.labelSmall),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) =>
                  _ServiceJobTile(display: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Display Model ───────────────────────────────────────────────────────────

class _ServiceJobDisplay {
  final LocalRecord record;
  final ServiceJob job;

  const _ServiceJobDisplay({required this.record, required this.job});
}

// ─── Service Job List Tile ───────────────────────────────────────────────────

class _ServiceJobTile extends StatelessWidget {
  final _ServiceJobDisplay display;

  const _ServiceJobTile({required this.display});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = display.job;
    final record = display.record;

    final statusColor = _statusColor(theme, job.status);

    return Semantics(
      label:
          'Service job for ${job.customerName}, IMEI ${job.imei}, '
          'status ${job.status.toWireValue().replaceAll('_', ' ')}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(_statusIcon(job.status), color: statusColor, size: 20),
          ),
          title: Text(
            job.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IMEI: ${job.imei}', style: theme.textTheme.bodySmall),
              Row(
                children: [
                  _StatusChip(
                    label: job.status.toWireValue().replaceAll('_', ' '),
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  if (!record.isServerConfirmed)
                    _StatusChip(
                      label: record.isPending ? 'Pending' : 'Conflict',
                      color: record.isPending
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('v${job.version}', style: theme.textTheme.labelSmall),
              if (job.priority == ServicePriority.urgent ||
                  job.priority == ServicePriority.high)
                Icon(
                  Icons.priority_high,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
            ],
          ),
          onTap: () {
            // Navigate to service job detail
            GoRouter.of(
              context,
            ).go('/mobile-shop/service-jobs/${job.entityId}');
          },
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, ServiceJobStatus status) {
    return switch (status) {
      ServiceJobStatus.received => theme.colorScheme.primary,
      ServiceJobStatus.diagnosed => Colors.orange,
      ServiceJobStatus.estimateSent => Colors.amber,
      ServiceJobStatus.approved => Colors.blue,
      ServiceJobStatus.inProgress => Colors.indigo,
      ServiceJobStatus.partsOrdered => Colors.purple,
      ServiceJobStatus.ready => Colors.green,
      ServiceJobStatus.delivered => Colors.teal,
      ServiceJobStatus.cancelled => theme.colorScheme.error,
    };
  }

  IconData _statusIcon(ServiceJobStatus status) {
    return switch (status) {
      ServiceJobStatus.received => Icons.inbox,
      ServiceJobStatus.diagnosed => Icons.search,
      ServiceJobStatus.estimateSent => Icons.send,
      ServiceJobStatus.approved => Icons.check_circle_outline,
      ServiceJobStatus.inProgress => Icons.build,
      ServiceJobStatus.partsOrdered => Icons.local_shipping,
      ServiceJobStatus.ready => Icons.done_all,
      ServiceJobStatus.delivered => Icons.handshake,
      ServiceJobStatus.cancelled => Icons.cancel,
    };
  }
}

// ─── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ─── Shared State Widgets ────────────────────────────────────────────────────

class _EmptyStateWidget extends StatelessWidget {
  final String? message;

  const _EmptyStateWidget({this.message});

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
              Icons.inbox_outlined,
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

class _ErrorStateWidget extends StatelessWidget {
  final String message;
  final bool isRetryable;
  final VoidCallback? onRetry;

  const _ErrorStateWidget({
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

/// Converts a Drift entity to JSON map for domain model hydration.
/// The entity types from Drift are data classes with matching field names.
Map<String, dynamic> _entityToJson(dynamic entity) {
  // Drift-generated entities have a toJson-like shape; cast fields directly.
  // This works with the generated Drift data classes.
  if (entity is Map) return entity.cast<String, dynamic>();
  // For Drift companion objects that expose .toColumns(), we serialize manually.
  // The repository impl handles the actual mapping.
  try {
    return (entity as dynamic).toJson() as Map<String, dynamic>;
  } catch (_) {
    // Fallback: treat as a generic object with a data map field
    return <String, dynamic>{};
  }
}
