/// Reservation Screen — Conflict-Aware Device Reservation (Dart)
///
/// Allows creating and managing device reservations with:
/// - Version conflict detection (shows when another reservation exists)
/// - Graceful handling of concurrent reservation attempts
/// - Distinct pending/confirmed states via ReconciliationStatusDisplay
/// - Deposit tracking and expiry management
///
/// Uses application services (MobileShopLocalRepository + outbox) — NOT
/// direct authority. Reservation claims are conditional server-side.
///
/// Requirements: 4.6, 11.1–11.8, 12.7
library;

import 'package:flutter/material.dart';

import '../auth/tenant_context_resolver.dart';
import '../billing/mobile_sale_consistency_orchestrator.dart';
import '../billing/reconciliation_status_display.dart';
import '../models/reservation_models.dart';
import '../repository/mobile_shop_local_repository.dart';
import 'inventory_command_service.dart';

// ─── Reservation List Screen ─────────────────────────────────────────────────

/// Lists active and historical reservations with sync status.
///
/// Shows reservation conflicts prominently when detected. Allows
/// creating new reservations with version-aware conditional claims.
class ReservationScreen extends StatefulWidget {
  /// The resolved tenant context (provided by guard).
  final TenantContext tenantContext;

  /// The local repository for tenant-bound data access.
  final MobileShopLocalRepository repository;

  const ReservationScreen({
    super.key,
    required this.tenantContext,
    required this.repository,
  });

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  bool _isLoading = true;
  String? _error;
  List<_ReservationDisplayItem> _reservations = [];
  ReservationStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Reservations are accessed through the local repository as IMEI units
      // in RESERVED state — the reservation claim data comes from synced records
      final units = await widget.repository.listImeiUnits(
        widget.tenantContext,
        limit: 100,
      );

      // Filter to reserved-state units and map to display items
      final reservedUnits = units.where(
        (r) => r.entity.lifecycleState == 'RESERVED',
      );

      final items = reservedUnits.map((record) {
        return _ReservationDisplayItem(
          unitId: record.entity.entityId,
          imei: record.entity.imei,
          brand: record.entity.brand ?? '',
          model: record.entity.model ?? '',
          customerName: 'Reserved',
          status: ReservationStatus.active,
          confirmationStatus: record.confirmationStatus,
          serverVersion: record.serverVersion,
          syncedAt: record.syncedAt,
          expiresAt: null,
        );
      }).toList();

      setState(() {
        _reservations = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reservations: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadReservations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateReservationDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Reservation'),
      ),
      body: Column(
        children: [
          _ReservationFilterBar(
            selected: _statusFilter,
            onChanged: (status) {
              setState(() => _statusFilter = status);
            },
          ),
          const Divider(height: 1),
          Expanded(child: _buildContent()),
        ],
      ),
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
                onPressed: _loadReservations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _statusFilter != null
        ? _reservations.where((r) => r.status == _statusFilter).toList()
        : _reservations;

    if (filtered.isEmpty) {
      return Center(
        child: Semantics(
          label: 'No reservations found',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.book_online_outlined,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No reservations',
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
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _ReservationTile(item: filtered[index]),
      ),
    );
  }

  void _showCreateReservationDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateReservationDialog(
        tenantContext: widget.tenantContext,
        repository: widget.repository,
        onCreated: _loadReservations,
      ),
    );
  }
}

// ─── Reservation Display Item ────────────────────────────────────────────────

class _ReservationDisplayItem {
  final String unitId;
  final String imei;
  final String brand;
  final String model;
  final String customerName;
  final ReservationStatus status;
  final String confirmationStatus;
  final int serverVersion;
  final DateTime? syncedAt;
  final String? expiresAt;

  const _ReservationDisplayItem({
    required this.unitId,
    required this.imei,
    required this.brand,
    required this.model,
    required this.customerName,
    required this.status,
    required this.confirmationStatus,
    required this.serverVersion,
    this.syncedAt,
    this.expiresAt,
  });
}

// ─── Reservation Tile ────────────────────────────────────────────────────────

class _ReservationTile extends StatelessWidget {
  final _ReservationDisplayItem item;

  const _ReservationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomeState = confirmationStatusToOutcomeState(
      item.confirmationStatus,
    );

    // Show version conflict warning when pending and not confirmed
    final hasVersionConflict =
        item.confirmationStatus == ConfirmationStatus.conflict;

    return Semantics(
      label:
          'Reservation for ${item.brand} ${item.model}, '
          'IMEI ${item.imei}, customer ${item.customerName}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conflict banner
              if (hasVersionConflict) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reservation conflict detected. '
                          'Another reservation may exist for this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.brand} ${item.model}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ReservationStatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 8),
              // IMEI
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
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Customer
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(item.customerName),
                ],
              ),
              const SizedBox(height: 8),
              // Sync status
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

// ─── Reservation Status Chip ─────────────────────────────────────────────────

class _ReservationStatusChip extends StatelessWidget {
  final ReservationStatus status;

  const _ReservationStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReservationStatus.active => ('Active', const Color(0xFF1976D2)),
      ReservationStatus.converted => ('Converted', const Color(0xFF388E3C)),
      ReservationStatus.expired => ('Expired', const Color(0xFF757575)),
      ReservationStatus.cancelled => ('Cancelled', const Color(0xFFD32F2F)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Filter Bar ──────────────────────────────────────────────────────────────

class _ReservationFilterBar extends StatelessWidget {
  final ReservationStatus? selected;
  final ValueChanged<ReservationStatus?> onChanged;

  const _ReservationFilterBar({
    required this.selected,
    required this.onChanged,
  });

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
          ...ReservationStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_reservationStatusLabel(status)),
                selected: selected == status,
                onSelected: (_) =>
                    onChanged(status == selected ? null : status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Create Reservation Dialog ───────────────────────────────────────────────

class _CreateReservationDialog extends StatefulWidget {
  final TenantContext tenantContext;
  final MobileShopLocalRepository repository;
  final VoidCallback onCreated;

  const _CreateReservationDialog({
    required this.tenantContext,
    required this.repository,
    required this.onCreated,
  });

  @override
  State<_CreateReservationDialog> createState() =>
      _CreateReservationDialogState();
}

class _CreateReservationDialogState extends State<_CreateReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imeiController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _depositController = TextEditingController();
  bool _isSubmitting = false;
  String? _conflictError;

  @override
  void dispose() {
    _imeiController.dispose();
    _customerNameController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('New Reservation'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_conflictError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _conflictError!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _imeiController,
                decoration: const InputDecoration(
                  labelText: 'Device IMEI *',
                  hintText: '15-digit IMEI number',
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
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Customer name required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _depositController,
                decoration: const InputDecoration(
                  labelText: 'Deposit Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
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
          onPressed: _isSubmitting ? null : _submitReservation,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reserve'),
        ),
      ],
    );
  }

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    try {
      // Check for existing reservation on this IMEI (conflict-aware)
      final existingUnit = await widget.repository.getImeiUnit(
        widget.tenantContext,
        _imeiController.text.trim(),
      );

      if (existingUnit != null &&
          existingUnit.entity.lifecycleState == 'RESERVED') {
        setState(() {
          _conflictError =
              'This device already has an active reservation. '
              'Version conflict detected (v${existingUnit.serverVersion}).';
          _isSubmitting = false;
        });
        return;
      }

      // Queue reservation mutation through outbox
      final cmdService = InventoryCommandService(repository: widget.repository);

      // The reservation is queued locally and synced — the server-side
      // conditional claim (attribute_not_exists) prevents duplicates.
      await cmdService.queueReservation(
        context: widget.tenantContext,
        imei: _imeiController.text.trim(),
        customerName: _customerNameController.text.trim(),
        depositAmount: _depositController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation queued. Pending server confirmation.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _conflictError = 'Failed to create reservation: $e';
        _isSubmitting = false;
      });
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _reservationStatusLabel(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.active:
      return 'Active';
    case ReservationStatus.converted:
      return 'Converted';
    case ReservationStatus.expired:
      return 'Expired';
    case ReservationStatus.cancelled:
      return 'Cancelled';
  }
}
