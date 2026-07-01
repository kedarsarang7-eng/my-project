import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/app_l10n.dart';

/// Commission Report Screen for the Mandi (vegetablesBroker) business type.
///
/// Displays all commission ledger entries showing sale amounts, commission
/// earned, and deductions, ordered most recent first.
///
/// Requirement: 12.2 — navigation opens a real Mandi screen with no legacy
/// redirect.
class MandiCommissionReportScreen extends StatefulWidget {
  const MandiCommissionReportScreen({super.key});

  @override
  State<MandiCommissionReportScreen> createState() =>
      _MandiCommissionReportScreenState();
}

class _MandiCommissionReportScreenState
    extends State<MandiCommissionReportScreen> {
  late final AppDatabase _db;
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _db = sl<AppDatabase>();
  }

  /// Watch all commission ledger entries ordered by date descending.
  Stream<List<CommissionLedgerEntity>> _watchLedger() {
    return (_db.select(
      _db.commissionLedger,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Commission Report', style: theme.textTheme.titleLarge),
      ),
      body: StreamBuilder<List<CommissionLedgerEntity>>(
        stream: _watchLedger(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No commission entries',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Commission data will appear here after sales are recorded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // Summary header (convert paise to rupees for display)
          final totalCommission =
              entries.fold<int>(0, (sum, e) => sum + e.commissionAmount) /
              100.0;
          final totalSales =
              entries.fold<int>(0, (sum, e) => sum + e.saleAmount) / 100.0;

          return Column(
            children: [
              _buildSummaryHeader(totalSales, totalCommission, theme),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildEntryTile(entries[index], theme),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(
    double totalSales,
    double totalCommission,
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryItem(
            'Total Sales',
            AppL10n.formatCurrency(totalSales),
            theme,
          ),
          _buildSummaryItem(
            'Total Commission',
            AppL10n.formatCurrency(totalCommission),
            theme,
            valueColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    ThemeData theme, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(CommissionLedgerEntity entry, ThemeData theme) {
    return ListTile(
      title: Row(
        children: [
          Text(
            _dateFormat.format(entry.date),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bill: ${entry.billId.length > 12 ? '${entry.billId.substring(0, 12)}…' : entry.billId}',
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            'Sale: ${AppL10n.formatCurrency(entry.saleAmount / 100.0)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          if (entry.commissionRate != null)
            Text(
              'Rate: ${entry.commissionRate!.toStringAsFixed(2)}%',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Text(
        AppL10n.formatCurrency(entry.commissionAmount / 100.0),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
