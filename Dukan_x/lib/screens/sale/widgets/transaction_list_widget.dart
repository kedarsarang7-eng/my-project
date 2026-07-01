import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction_model.dart';
import '../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../providers/app_state_providers.dart';
import 'package:intl/intl.dart';

class TransactionListWidget extends ConsumerWidget {
  final TransactionType type;
  final String emptyMessage;
  final String emptyButtonLabel;
  final VoidCallback? onAddPressed;

  const TransactionListWidget({
    super.key,
    required this.type,
    this.emptyMessage = "No records found",
    this.emptyButtonLabel = "Create New",
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = sl<SessionManager>().ownerId ?? '';
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    // Use BillsRepository for sales data
    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(userId: ownerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final bills = snapshot.data ?? [];

        // Filter by transaction type (sales are bills)
        // For now, all bills are treated as sales
        final filteredBills = type == TransactionType.sale
            ? bills
            : <Bill>[]; // Other types would need different repositories

        if (filteredBills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                if (onAddPressed != null)
                  ElevatedButton.icon(
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add),
                    label: Text(emptyButtonLabel),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBills.length,
          itemBuilder: (context, index) {
            final bill = filteredBills[index];
            return _buildBillCard(context, bill, isDark);
          },
        );
      },
    );
  }

  Widget _buildBillCard(BuildContext context, Bill bill, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd MMM yyyy');

    Color statusColor = Colors.grey;
    if (bill.status.toLowerCase() == 'paid') statusColor = Colors.green;
    if (bill.status.toLowerCase() == 'partial') statusColor = Colors.orange;
    if (bill.status.toLowerCase() == 'unpaid') statusColor = Colors.red;

    final balanceAmount = (bill.grandTotal - bill.paidAmount).clamp(
      0.0,
      double.infinity,
    );

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBillDetail(context, bill, isDark),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bill.customerName.isNotEmpty
                        ? bill.customerName
                        : "Unknown Party",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      bill.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "#${bill.invoiceNumber} • ${dateFormat.format(bill.date)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  Text(
                    currencyFormat.format(bill.grandTotal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (balanceAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "Balance: ${currencyFormat.format(balanceAmount)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBillDetail(BuildContext context, Bill bill, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: sl<CurrencyService>().symbol,
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final balanceAmount = (bill.grandTotal - bill.paidAmount).clamp(
      0.0,
      double.infinity,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Details
            _detailRow('Reference', '#${bill.invoiceNumber}', isDark),
            _detailRow('Type', 'SALE', isDark),
            _detailRow(
              'Party',
              bill.customerName.isNotEmpty ? bill.customerName : 'N/A',
              isDark,
            ),
            _detailRow('Date', dateFormat.format(bill.date), isDark),
            _detailRow(
              'Amount',
              currencyFormat.format(bill.grandTotal),
              isDark,
            ),
            _detailRow('Paid', currencyFormat.format(bill.paidAmount), isDark),
            _detailRow('Balance', currencyFormat.format(balanceAmount), isDark),
            _detailRow('Status', bill.status.toUpperCase(), isDark),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
