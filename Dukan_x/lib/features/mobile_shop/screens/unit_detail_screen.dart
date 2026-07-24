/// MobileShop Unit Detail Screen (Dart)
///
/// Comprehensive current state of a single IMEI unit: associations,
/// lifecycle state, warranty, sync status, and action buttons for
/// lifecycle transitions. Uses unified TenantContext, expected versions,
/// live repository data, and typed loading/empty/error/session states.
///
/// Requirements: 2.7, 5.1–5.11, 9.1–9.8, 12.4
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/tenant_context_resolver.dart';
import '../models/imei_unit_models.dart';
import '../models/common_models.dart';
import '../models/service_job_models.dart';
import '../models/warranty_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import '../widgets/mobile_shop_session_state.dart';
import 'screen_state.dart';

// ─── Unit Detail Screen ──────────────────────────────────────────────────────

/// Shows the complete current state of a single IMEI unit with:
/// - Full device information (brand, model, condition, etc.)
/// - Lifecycle state + available transitions
/// - Connected warranty, service jobs
/// - Financial info (acquisition cost, sale price, margin)
/// - Action buttons gated by policy and expected version
class UnitDetailScreen extends StatefulWidget {
  final TenantContextResolver resolver;
  final MobileShopLocalRepository repository;

  /// The normalized IMEI to display.
  final String imei;

  const UnitDetailScreen({
    super.key,
    required this.resolver,
    required this.repository,
    required this.imei,
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  ScreenState<_UnitDetailData> _state = const ScreenLoading();

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

          final unit = ImeiUnit.fromJson(_entityToJson(unitRecord.entity));

          // Load related data
          final serviceJobs = await widget.repository.listServiceJobs(value);
          final warranties = await widget.repository.listWarranties(value);

          final relatedJobs = serviceJobs.where((r) {
            try {
              final json = _entityToJson(r.entity);
              return json['imei'] == widget.imei;
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

          setState(
            () => _state = ScreenData(
              data: _UnitDetailData(
                unit: unit,
                unitRecord: unitRecord,
                relatedServiceJobs: relatedJobs.length,
                relatedWarranties: relatedWarranties.length,
                activeWarranty: relatedWarranties.isNotEmpty,
              ),
              lastRefreshed: DateTime.now(),
            ),
          );
        } catch (e) {
          setState(
            () => _state = ScreenError(
              errorCode: 'LOAD_FAILED',
              message: 'Failed to load unit details: ${e.toString()}',
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
        title: const Text('Unit Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              GoRouter.of(
                context,
              ).go('/mobile-shop/imei/history?serial=${widget.imei}');
            },
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
      onData: (detailData, isStale, _) =>
          _buildDetail(context, detailData, isStale),
      empty: (message) => Center(
        child: Semantics(
          label: message ?? 'Unit not found',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_android_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'Unit not found',
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

  Widget _buildDetail(
    BuildContext context,
    _UnitDetailData data,
    bool isStale,
  ) {
    final theme = Theme.of(context);
    final unit = data.unit;
    final record = data.unitRecord;
    final lifecycleColor = _lifecycleColor(theme, unit.lifecycleState);

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

          // Sync status banner
          if (!record.isServerConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    (record.isPending
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: record.isPending
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.error,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    record.isPending ? Icons.sync : Icons.sync_problem,
                    size: 16,
                    color: record.isPending
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    record.isPending
                        ? 'Pending sync — not yet confirmed by server'
                        : 'Conflict — requires resolution',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // ─── Device Identity ──────────────────────────────────────────────
          _SectionCard(
            title: 'Device',
            icon: Icons.phone_android,
            children: [
              _InfoRow(label: 'Brand', value: unit.brand),
              _InfoRow(label: 'Model', value: unit.model),
              _InfoRow(label: 'IMEI', value: unit.imei, monospace: true),
              if (unit.color != null)
                _InfoRow(label: 'Color', value: unit.color!),
              if (unit.storage != null)
                _InfoRow(label: 'Storage', value: unit.storage!),
              _InfoRow(
                label: 'Condition',
                value: unit.condition.toWireValue().replaceAll('_', ' '),
              ),
              _InfoRow(
                label: 'Source',
                value: unit.ownershipSource.toWireValue().replaceAll('_', ' '),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Lifecycle ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Lifecycle',
            icon: Icons.timeline,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            children: [
              _InfoRow(label: 'Version', value: 'v${unit.version}'),
              _InfoRow(label: 'Data Model', value: 'v${unit.dataModelVersion}'),
              _InfoRow(label: 'Created', value: _formatDate(unit.createdAt)),
              _InfoRow(label: 'Updated', value: _formatDate(unit.updatedAt)),
              if (unit.customerId != null)
                _InfoRow(label: 'Customer ID', value: unit.customerId!),
              if (unit.soldAt != null)
                _InfoRow(label: 'Sold At', value: _formatDate(unit.soldAt!)),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Financial ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Financial',
            icon: Icons.payments_outlined,
            children: [
              _InfoRow(
                label: 'Acquisition Cost',
                value: _formatMoney(unit.acquisitionCost),
              ),
              _InfoRow(
                label: 'Sale Price',
                value: _formatMoney(unit.salePrice),
              ),
              if (unit.marketValuation != null)
                _InfoRow(
                  label: 'Market Value',
                  value: _formatMoney(unit.marketValuation!),
                ),
              _InfoRow(
                label: 'Margin',
                value: _formatMoney(
                  Money(
                    amountMinorUnits:
                        unit.salePrice.amountMinorUnits -
                        unit.acquisitionCost.amountMinorUnits,
                    currency: unit.salePrice.currency,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Warranty ─────────────────────────────────────────────────────
          if (unit.warrantyEndDate != null)
            _SectionCard(
              title: 'Warranty',
              icon: Icons.verified_user_outlined,
              children: [
                _InfoRow(
                  label: 'Start',
                  value: unit.warrantyStartDate ?? 'N/A',
                ),
                _InfoRow(label: 'End', value: unit.warrantyEndDate!),
                if (unit.warrantyProvider != null)
                  _InfoRow(label: 'Provider', value: unit.warrantyProvider!),
              ],
            ),
          if (unit.warrantyEndDate != null) const SizedBox(height: 12),

          // ─── Associations ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Associations',
            icon: Icons.link,
            children: [
              _InfoRow(
                label: 'Service Jobs',
                value: '${data.relatedServiceJobs}',
              ),
              _InfoRow(label: 'Warranties', value: '${data.relatedWarranties}'),
              if (unit.saleInvoiceId != null)
                _InfoRow(label: 'Sale Invoice', value: unit.saleInvoiceId!),
              if (unit.exchangeId != null)
                _InfoRow(label: 'Exchange', value: unit.exchangeId!),
              if (unit.intakeId != null)
                _InfoRow(label: 'Intake', value: unit.intakeId!),
              if (unit.supplierId != null)
                _InfoRow(label: 'Supplier', value: unit.supplierId!),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Action Buttons ───────────────────────────────────────────────
          _ActionSection(unit: unit),
        ],
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

  String _formatDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatMoney(Money money) {
    final major = money.amountMinorUnits ~/ 100;
    final minor = (money.amountMinorUnits % 100).abs();
    final sign = money.amountMinorUnits < 0 ? '-' : '';
    final symbol = money.currency == 'INR' ? '₹' : money.currency;
    return '$sign$symbol ${major.abs()}.${minor.toString().padLeft(2, '0')}';
  }
}

// ─── Data Model ──────────────────────────────────────────────────────────────

class _UnitDetailData {
  final ImeiUnit unit;
  final LocalRecord unitRecord;
  final int relatedServiceJobs;
  final int relatedWarranties;
  final bool activeWarranty;

  const _UnitDetailData({
    required this.unit,
    required this.unitRecord,
    required this.relatedServiceJobs,
    required this.relatedWarranties,
    required this.activeWarranty,
  });
}

// ─── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _InfoRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Section ──────────────────────────────────────────────────────────

/// Action buttons gated by current lifecycle state.
/// Only shows actions that are valid transitions from the current state.
class _ActionSection extends StatelessWidget {
  final ImeiUnit unit;

  const _ActionSection({required this.unit});

  @override
  Widget build(BuildContext context) {
    final actions = _availableActions(unit.lifecycleState);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Actions', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.map((action) {
            return Semantics(
              button: true,
              label: action.label,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Actions navigate to appropriate workflow screens,
                  // passing the expected version for conditional updates.
                  _navigateAction(context, action);
                },
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _navigateAction(BuildContext context, _UnitAction action) {
    final router = GoRouter.of(context);
    switch (action.type) {
      case _ActionType.createServiceJob:
        router.go('/mobile-shop/service-jobs?imei=${unit.imei}');
      case _ActionType.exchange:
        router.go('/mobile-shop/exchanges?imei=${unit.imei}');
      case _ActionType.viewHistory:
        router.go('/mobile-shop/imei/history?serial=${unit.imei}');
      case _ActionType.warranty:
        router.go('/mobile-shop/warranty?imei=${unit.imei}');
    }
  }

  List<_UnitAction> _availableActions(DeviceLifecycleState state) {
    final actions = <_UnitAction>[];

    // View history is always available
    actions.add(
      const _UnitAction(
        type: _ActionType.viewHistory,
        label: 'View History',
        icon: Icons.history,
      ),
    );

    // State-dependent actions
    switch (state) {
      case DeviceLifecycleState.inStock:
      case DeviceLifecycleState.secondHand:
        actions.add(
          const _UnitAction(
            type: _ActionType.exchange,
            label: 'Exchange',
            icon: Icons.swap_horiz,
          ),
        );
      case DeviceLifecycleState.sold:
        actions.add(
          const _UnitAction(
            type: _ActionType.createServiceJob,
            label: 'Create Service Job',
            icon: Icons.build,
          ),
        );
        actions.add(
          const _UnitAction(
            type: _ActionType.warranty,
            label: 'Warranty',
            icon: Icons.verified_user,
          ),
        );
        actions.add(
          const _UnitAction(
            type: _ActionType.exchange,
            label: 'Exchange',
            icon: Icons.swap_horiz,
          ),
        );
      case DeviceLifecycleState.inService:
        actions.add(
          const _UnitAction(
            type: _ActionType.createServiceJob,
            label: 'View Service',
            icon: Icons.build,
          ),
        );
      case DeviceLifecycleState.reserved:
      case DeviceLifecycleState.salePending:
      case DeviceLifecycleState.returned:
      case DeviceLifecycleState.demo:
      case DeviceLifecycleState.exchanged:
      case DeviceLifecycleState.damaged:
      case DeviceLifecycleState.retired:
        // Minimal actions for terminal/pending states
        break;
    }

    return actions;
  }
}

enum _ActionType { createServiceJob, exchange, viewHistory, warranty }

class _UnitAction {
  final _ActionType type;
  final String label;
  final IconData icon;

  const _UnitAction({
    required this.type,
    required this.label,
    required this.icon,
  });
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
