import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/transactions_provider.dart';
import '../theme/fuelpos_theme.dart';

/// Transaction Table Widget
class TransactionTableWidget extends ConsumerWidget {
  final DateTime? selectedDate;
  final Function(DateTime)? onDateChanged;

  const TransactionTableWidget({
    super.key,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsState = ref.watch(transactionsProvider);
    final transactionsNotifier = ref.read(transactionsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and date picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: FuelPOSTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildDatePicker(context, ref),
              ],
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: transactionsState.isLoading && transactionsState.transactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : transactionsState.error != null && transactionsState.transactions.isEmpty
                      ? _buildError(transactionsState.error!, transactionsNotifier)
                      : _buildDataTable(transactionsState, ref),
            ),

            // Load more button
            if (transactionsState.hasMore || transactionsState.isLoadingMore)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: transactionsState.isLoadingMore
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: () {
                            ref.read(transactionsProvider.notifier).loadMore();
                          },
                          icon: const Icon(Icons.expand_more, size: 18),
                          label: const Text('Load More'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, WidgetRef ref) {
    final currentDate = selectedDate ?? DateTime.now();

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: FuelPOSTheme.primaryBlue,
                  surface: FuelPOSTheme.cardDark,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          onDateChanged?.call(picked);
          ref.read(transactionsProvider.notifier).setDate(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FuelPOSTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FuelPOSTheme.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM dd, yyyy').format(currentDate),
              style: const TextStyle(
                color: FuelPOSTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_drop_down,
              color: FuelPOSTheme.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error, dynamic transactionsNotifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: FuelPOSTheme.errorRed,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: const TextStyle(color: FuelPOSTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              transactionsNotifier.refresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(TransactionsState state, WidgetRef ref) {
    final transactions = state.transactions;

    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: FuelPOSTheme.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Vehicle#')),
          DataColumn(label: Text('Fuel Type')),
          DataColumn(label: Text('Liters'), numeric: true),
          DataColumn(label: Text('Amount'), numeric: true),
          DataColumn(label: Text('Status')),
        ],
        rows: transactions.map((txn) {
          return DataRow(
            cells: [
              DataCell(Text(
                txn.id,
                style: const TextStyle(
                  color: FuelPOSTheme.textSecondary,
                  fontSize: 12,
                ),
              )),
              DataCell(Text(txn.time)),
              DataCell(Text(txn.vehicleNumber)),
              DataCell(Text(
                txn.fuelType,
                style: TextStyle(
                  color: txn.fuelType.toLowerCase() == 'petrol'
                      ? FuelPOSTheme.petrolBlue
                      : FuelPOSTheme.dieselOrange,
                  fontWeight: FontWeight.w500,
                ),
              )),
              DataCell(Text(txn.formattedLiters)),
              DataCell(Text(
                txn.formattedAmount,
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              DataCell(_buildStatusBadge(txn.status, txn.badgeType)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String badgeType) {
    Color bgColor;
    Color textColor;

    switch (badgeType) {
      case 'success':
        bgColor = FuelPOSTheme.successGreen.withValues(alpha:0.15);
        textColor = FuelPOSTheme.successGreen;
        break;
      case 'warning':
        bgColor = FuelPOSTheme.warningYellow.withValues(alpha:0.15);
        textColor = FuelPOSTheme.warningYellow;
        break;
      case 'error':
        bgColor = FuelPOSTheme.errorRed.withValues(alpha:0.15);
        textColor = FuelPOSTheme.errorRed;
        break;
      default:
        bgColor = FuelPOSTheme.textMuted.withValues(alpha:0.15);
        textColor = FuelPOSTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
