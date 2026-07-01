import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/app_l10n.dart';
import '../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Farmer Ledger Screen (Requirement 11.2)
///
/// Displays a farmer's running balance (cumulative sale proceeds less
/// deductions and payouts) with each contributing transaction, ordered
/// most recent first. Uses a reactive Drift watch for live updates.
class FarmerLedgerScreen extends StatefulWidget {
  final String farmerId;

  const FarmerLedgerScreen({super.key, required this.farmerId});

  @override
  State<FarmerLedgerScreen> createState() => _FarmerLedgerScreenState();
}

class _FarmerLedgerScreenState extends State<FarmerLedgerScreen> {
  late final AppDatabase _db;
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _db = sl<AppDatabase>();
  }

  /// Watch the farmer record for name and current balance (live updates).
  Stream<FarmerEntity?> _watchFarmer() {
    return (_db.select(
      _db.farmers,
    )..where((t) => t.id.equals(widget.farmerId))).watchSingleOrNull();
  }

  /// Watch all CommissionLedger entries for this farmer, ordered by date
  /// descending (most recent first) — Requirement 11.2.
  Stream<List<CommissionLedgerEntity>> _watchLedgerEntries() {
    return (_db.select(_db.commissionLedger)
          ..where((t) => t.farmerId.equals(widget.farmerId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<FarmerEntity?>(
          stream: _watchFarmer(),
          builder: (context, snap) {
            final farmer = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmer?.name ?? 'Farmer Ledger',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Ledger & Running Balance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // --- Balance Header ---
            _buildBalanceHeader(theme),
            const Divider(height: 1),
            // --- Transaction List ---
            Expanded(child: _buildTransactionList(theme)),
          ],
        ),
      ),
    );
  }

  /// Header card showing the farmer's current running balance.
  Widget _buildBalanceHeader(ThemeData theme) {
    return StreamBuilder<FarmerEntity?>(
      stream: _watchFarmer(),
      builder: (context, snap) {
        final farmer = snap.data;
        // currentBalance is stored as integer paise in the generated entity.
        final balancePaise = farmer?.currentBalance ?? 0;
        final balanceRupees = balancePaise / 100.0;
        final isPayable = balanceRupees >= 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Running Balance',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatAmount(balanceRupees.abs()),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPayable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPayable ? 'Payable to Farmer' : 'Advance / Overpaid',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isPayable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Transaction list showing each CommissionLedger entry with running
  /// balance computed cumulatively (most recent first display, but
  /// running balance is calculated oldest-first then displayed).
  Widget _buildTransactionList(ThemeData theme) {
    return StreamBuilder<List<CommissionLedgerEntity>>(
      stream: _watchLedgerEntries(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snap.data ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No transactions yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // Compute running balance for each entry.
        // Entries come in descending date order (most recent first).
        // Running balance is cumulative from oldest → newest, so we
        // reverse, accumulate, then reverse again.
        final runningBalances = _computeRunningBalances(entries);

        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final runningBalance = runningBalances[index];
            return _buildTransactionTile(entry, runningBalance, theme);
          },
        );
      },
    );
  }

  /// Computes the running balance for each entry in display order
  /// (most recent first). The running balance accumulates netPayable
  /// from oldest to newest. Returns values in rupees (paise / 100).
  List<double> _computeRunningBalances(List<CommissionLedgerEntity> entries) {
    // entries are sorted descending (most recent first).
    // We reverse to get oldest first, accumulate, then reverse back.
    final oldest = entries.reversed.toList();
    final balances = <double>[];
    int cumulativePaise = 0;

    for (final entry in oldest) {
      cumulativePaise += entry.netPayableToFarmer;
      balances.add(cumulativePaise / 100.0);
    }

    // Reverse so index 0 = most recent entry's running balance
    return balances.reversed.toList();
  }

  /// A single transaction row showing date, bill reference, sale amount,
  /// commission deducted, total charges deducted, net payable, and
  /// running balance.
  Widget _buildTransactionTile(
    CommissionLedgerEntity entry,
    double runningBalance,
    ThemeData theme,
  ) {
    // Total deduction charges (labor + other expenses) in paise.
    final totalChargesPaise = entry.laborCharges + entry.otherExpenses;

    return InkWell(
      onTap: () => _showTransactionDetail(entry, runningBalance, theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Date + Bill Ref + Net Payable
            Row(
              children: [
                // Date
                Text(
                  _dateFormat.format(entry.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                // Bill Reference
                Expanded(
                  child: Text(
                    'Bill: ${_truncateBillId(entry.billId)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Net Payable (highlighted)
                Text(
                  _formatAmount(entry.netPayableToFarmer / 100.0),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Sale Amount | Commission | Charges | Running Bal
            Row(
              children: [
                _buildInfoChip(
                  'Sale',
                  _formatAmount(entry.saleAmount / 100.0),
                  theme,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  'Comm.',
                  '-${_formatAmount(entry.commissionAmount / 100.0)}',
                  theme,
                  valueColor: theme.colorScheme.error,
                ),
                if (totalChargesPaise > 0) ...[
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    'Charges',
                    '-${_formatAmount(totalChargesPaise / 100.0)}',
                    theme,
                    valueColor: theme.colorScheme.error,
                  ),
                ],
                const Spacer(),
                // Running Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bal.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatAmount(runningBalance),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: runningBalance >= 0
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    String label,
    String value,
    ThemeData theme, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Truncates a long bill ID for display (e.g., first 12 chars + "…").
  String _truncateBillId(String billId) {
    if (billId.length <= 12) return billId;
    return '${billId.substring(0, 12)}…';
  }

  /// Formats a rupee amount (double) as a display string using AppL10n.
  String _formatAmount(double value) {
    return AppL10n.formatCurrency(value);
  }

  /// Shows a bottom sheet with full transaction details.
  void _showTransactionDetail(
    CommissionLedgerEntity entry,
    double runningBalance,
    ThemeData theme,
  ) {
    final totalChargesPaise = entry.laborCharges + entry.otherExpenses;

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Date', _dateFormat.format(entry.date), theme),
            _detailRow('Bill Reference', entry.billId, theme),
            _detailRow(
              'Sale Amount',
              _formatAmount(entry.saleAmount / 100.0),
              theme,
            ),
            _detailRow(
              'Commission',
              _formatAmount(entry.commissionAmount / 100.0),
              theme,
            ),
            if ((entry.commissionRate ?? 0.0) > 0)
              _detailRow(
                'Commission Rate',
                '${entry.commissionRate!.toStringAsFixed(2)}%',
                theme,
              ),
            _detailRow(
              'Labor Charges',
              _formatAmount(entry.laborCharges / 100.0),
              theme,
            ),
            _detailRow(
              'Other Expenses',
              _formatAmount(entry.otherExpenses / 100.0),
              theme,
            ),
            if (totalChargesPaise > 0)
              _detailRow(
                'Total Charges',
                _formatAmount(totalChargesPaise / 100.0),
                theme,
              ),
            const Divider(),
            _detailRow(
              'Net Payable',
              _formatAmount(entry.netPayableToFarmer / 100.0),
              theme,
              isBold: true,
            ),
            _detailRow(
              'Running Balance',
              _formatAmount(runningBalance),
              theme,
              isBold: true,
              valueColor: runningBalance >= 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
