import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../core/repository/customers_repository.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';

/// @deprecated Use [DashboardMetricsRow] instead, which has responsive 2×2
/// grid layout on mobile, FittedBox value scaling, and proper theme colors.
/// This widget is retained for backward compatibility only.
@Deprecated('Use DashboardMetricsRow instead for responsive KPI cards')
class OwnerSummaryCards extends StatelessWidget {
  const OwnerSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return const SizedBox.shrink();

    final customersRepo = sl<CustomersRepository>();
    final billsRepo = sl<BillsRepository>();

    return StreamBuilder(
      stream: customersRepo.watchAll(userId: userId),
      builder: (context, customerSnap) {
        final customers = customerSnap.data ?? [];

        final totalCustomers = customers.length;
        final totalDues = customers.fold<double>(
          0,
          (sum, c) => sum + c.totalDues,
        );

        return StreamBuilder(
          stream: billsRepo.watchAll(userId: userId),
          builder: (context, billsSnap) {
            final bills = billsSnap.data ?? [];

            // Calculate Week Sales
            final now = DateTime.now();
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final weekSales = bills
                .where(
                  (b) => b.date.isAfter(
                    startOfWeek.subtract(const Duration(seconds: 1)),
                  ),
                )
                .fold<double>(0, (sum, b) => sum + b.grandTotal);

            return Row(
              children: [
                Expanded(
                  child: _card(context, 'Customers', totalCustomers.toString()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _card(context, 'Total Dues', '₹${totalDues.toStringAsFixed(0)}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _card(context, 'Week Sales', '₹${weekSales.toStringAsFixed(0)}'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, String title, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
