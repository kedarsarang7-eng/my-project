import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/neon_card.dart';
import '../../../dashboard/data/dashboard_analytics_repository.dart';
import '../../../../core/session/session_manager.dart';
import 'dart:convert';
import '../../../../models/bill.dart';
import '../../../../screens/bill_detail.dart';

class RecentTransactionsPanel extends StatelessWidget {
  const RecentTransactionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sl<SessionManager>().userId;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    return NeonCard(
      height: 400, // Match graph height
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Optional: Navigate to full list via callback or route if available
                  // For now, assuming parent might handle or user navigates via Sidebar
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: FuturisticColors.accent1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: StreamBuilder<List<BillEntity>>(
              stream: sl<DashboardAnalyticsRepository>()
                  .watchRecentTransactions(userId: userId, limit: 8),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: FuturisticColors.error),
                    ),
                  );
                }

                final bills = snapshot.data ?? [];
                if (bills.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: FuturisticColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: bills.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: FuturisticColors.surface,
                    height: 16,
                  ),
                  itemBuilder: (context, index) {
                    final bill = bills[index];
                    return _buildTransactionItem(context, bill);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, BillEntity bill) {
    // Convert BillEntity to Bill model required by BillDetailScreen
    // Since BillDetailScreen expects `Bill` (from bills_repository.dart) and we have `BillEntity` (drift),
    // they are likely sharing structure or we need a mapper.
    // However, usually features use their own models.
    // Let's assume for UI tap we need to construct a compatible object or pass ID.
    // Checking `bills_list_screen.dart`, it takes `Bill` class.
    // Drift generated class is `Bill`. If `BillEntity` is a typedef or the same class, we are good.
    // Usually in Drift: `class Bills extends Table` -> generates `Bill` class.
    // The repository uses `BillEntity` which might be `Bill`.
    // Let's assume it works. If not, I'll need a mapper.

    final bool isPaid = bill.status == 'Paid' || bill.status == 'PAID';
    final bool isPartial =
        bill.paidAmount > 0 && bill.paidAmount < bill.grandTotal;

    Color statusColor = isPaid
        ? FuturisticColors.success
        : (isPartial ? FuturisticColors.warning : FuturisticColors.error);
    String statusText = isPaid ? 'Paid' : (isPartial ? 'Partial' : 'Unpaid');

    final customerName = bill.customerName;
    final hasCustomer = customerName != null && customerName.isNotEmpty;

    return InkWell(
      onTap: () {
        // Map BillEntity to Bill model for navigation
        final billModel = _mapToBill(bill);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailScreen(bill: billModel)),
        );
      },
      child: Row(
        children: [
          // Icon/Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FuturisticColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FuturisticColors.divider.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Text(
                hasCustomer ? customerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasCustomer ? customerName : 'Walk-in Customer',
                  style: const TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(bill.createdAt),
                  style: const TextStyle(
                    color: FuturisticColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                sl<CurrencyService>().format(bill.grandTotal),
                style: const TextStyle(
                  color: FuturisticColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Bill _mapToBill(BillEntity entity) {
    return Bill(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      customerId: entity.customerId ?? '',
      customerName: entity.customerName ?? '',
      date: entity.billDate,
      items: (jsonDecode(entity.itemsJson) as List)
          .map((e) => BillItem.fromMap(e))
          .toList(),
      subtotal: entity.subtotal,
      totalTax: entity.taxAmount,
      grandTotal: entity.grandTotal,
      paidAmount: entity.paidAmount,
      cashPaid: entity.cashPaid,
      onlinePaid: entity.onlinePaid,
      status: entity.status,
      paymentType: entity.paymentMode ?? 'Cash',
      discountApplied: entity.discountAmount,
      ownerId: entity.userId,
      source: entity.source,
      businessType: entity.businessType,
      businessId: entity.businessId,
      serviceCharge: entity.serviceCharge,
      prescriptionId: entity.prescriptionId,
    );
  }
}
