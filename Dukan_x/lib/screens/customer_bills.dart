import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/ui/smart_table.dart';
import '../widgets/ui/quick_action_toolbar.dart';
import 'bill_detail.dart';
import 'package:intl/intl.dart';

class CustomerBillsScreen extends StatelessWidget {
  const CustomerBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ownerId = sl<SessionManager>().ownerId; // Assumes Owner Mode

    if (ownerId == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: Column(
        children: [
          const QuickActionToolbar(
            title: 'Live Sales Monitor',
            actions: [
              Text(
                'Real-time Updates',
                style: TextStyle(
                  color: FuturisticColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.wifi_tethering,
                color: FuturisticColors.success,
                size: 16,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StreamBuilder<List<Bill>>(
                stream: sl<BillsRepository>().watchAll(userId: ownerId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: FuturisticColors.error),
                      ),
                    );
                  }

                  final bills = snap.data ?? [];
                  // Sort desc by default
                  bills.sort((a, b) => b.date.compareTo(a.date));

                  return SmartTable<Bill>(
                    data: bills,
                    emptyMessage: 'No sales recorded yet.',
                    onRowClick: (b) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BillDetailScreen(bill: b),
                      ),
                    ),
                    columns: [
                      SmartTableColumn(
                        title: 'Invoice #',
                        flex: 2,
                        builder: (b) => Text(
                          '#${b.invoiceNumber}',
                          style: const TextStyle(
                            fontFamily: 'Monospace',
                            color: FuturisticColors.primary,
                          ),
                        ),
                      ),
                      SmartTableColumn(
                        title: 'Customer',
                        flex: 2,
                        valueMapper: (b) =>
                            b.customerName.isEmpty ? 'Guest' : b.customerName,
                      ),
                      SmartTableColumn(
                        title: 'Total',
                        flex: 1,
                        builder: (b) => Text(
                          '₹${b.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.textPrimary,
                          ),
                        ),
                      ),
                      SmartTableColumn(
                        title: 'Status',
                        flex: 1,
                        builder: (b) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (b.status == 'Paid'
                                        ? FuturisticColors.success
                                        : FuturisticColors.warning)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color:
                                  (b.status == 'Paid'
                                          ? FuturisticColors.success
                                          : FuturisticColors.warning)
                                      .withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            b.status,
                            style: TextStyle(
                              color: b.status == 'Paid'
                                  ? FuturisticColors.success
                                  : FuturisticColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SmartTableColumn(
                        title: 'Time',
                        flex: 1,
                        valueMapper: (b) =>
                            DateFormat('hh:mm a').format(b.date),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
