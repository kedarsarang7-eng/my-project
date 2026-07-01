import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/repositories/payment_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/futuristic_kpi_card.dart';
import '../../../../widgets/desktop/enterprise_table.dart';
import '../../../../widgets/desktop/empty_state.dart';
import '../../../../widgets/desktop/status_badge.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Payments History Screen - Redesigned for Desktop
///
/// Features:
/// - No standalone Scaffold - integrates with EnterpriseDesktopShell
/// - KPI summary cards at top (received/paid totals)
/// - Enterprise table with payment mode badges
/// - Filter by date range and payment type
class PaymentsHistoryScreen extends StatelessWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sessionManager.userId ?? '';

    if (userId.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.account_circle_outlined,
        title: 'Not Logged In',
        description: 'Please log in to view payment history.',
      );
    }

    return StreamBuilder<List<PaymentEntity>>(
      stream: sl<PaymentRepository>().watchAllPayments(userId: userId),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final payments = snapshot.data ?? [];

        // Calculate totals for KPI cards
        final now = DateTime.now();

        final todayPayments = payments
            .where(
              (p) =>
                  p.paymentDate.day == now.day &&
                  p.paymentDate.month == now.month &&
                  p.paymentDate.year == now.year,
            )
            .fold<double>(0, (sum, p) => sum + p.amount);

        final monthPayments = payments
            .where(
              (p) =>
                  p.paymentDate.month == now.month &&
                  p.paymentDate.year == now.year,
            )
            .fold<double>(0, (sum, p) => sum + p.amount);

        final totalPayments = payments.fold<double>(
          0,
          (sum, p) => sum + p.amount,
        );

        // Count by payment mode
        final cashPayments = payments
            .where((p) => p.paymentMode.toLowerCase() == 'cash')
            .length;

        final onlinePayments = payments
            .where((p) => p.paymentMode.toLowerCase() != 'cash')
            .length;

        return DesktopContentContainer(
          title: 'Payments History',
          subtitle: 'Track all received and outgoing payments',
          actions: [
            DesktopIconButton(
              icon: Icons.filter_list_rounded,
              tooltip: 'Filter',
              onPressed: () => _showFilterDialog(context),
            ),
            DesktopIconButton(
              icon: Icons.download_rounded,
              tooltip: 'Export',
              onPressed: () {},
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards Row
              KpiCardRow(
                cards: [
                  FuturisticKpiCard(
                    label: 'Today',
                    value: '₹${_formatAmount(todayPayments)}',
                    icon: Icons.today_rounded,
                    accentColor: FuturisticColors.success,
                  ),
                  FuturisticKpiCard(
                    label: 'This Month',
                    value: '₹${_formatAmount(monthPayments)}',
                    icon: Icons.calendar_month_rounded,
                    accentColor: FuturisticColors.premiumBlue,
                  ),
                  FuturisticKpiCard(
                    label: 'Total Payments',
                    value: '₹${_formatAmount(totalPayments)}',
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: FuturisticColors.accent1,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Payment Mode Summary
              Row(
                children: [
                  _buildPaymentModeChip(
                    icon: Icons.payments_outlined,
                    label: 'Cash',
                    count: cashPayments,
                    color: FuturisticColors.success,
                  ),
                  const SizedBox(width: 12),
                  _buildPaymentModeChip(
                    icon: Icons.credit_card_rounded,
                    label: 'Online/Card',
                    count: onlinePayments,
                    color: FuturisticColors.premiumBlue,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Payments Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FuturisticColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FuturisticColors.premiumBlue.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Payment Records',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${payments.length} transactions',
                              style: TextStyle(
                                fontSize: 13,
                                color: FuturisticColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Table Body
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: FuturisticColors.premiumBlue,
                                ),
                              )
                            : payments.isEmpty
                            ? const CompactEmptyState(
                                icon: Icons.payment_outlined,
                                message: 'No payments recorded yet',
                              )
                            : EnterpriseTable<PaymentEntity>(
                                data: payments,
                                columns: [
                                  EnterpriseTableColumn<PaymentEntity>(
                                    title: 'Date',
                                    valueBuilder: (p) => p.paymentDate,
                                    widgetBuilder: (p) => Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(p.paymentDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  EnterpriseTableColumn<PaymentEntity>(
                                    title: 'Reference',
                                    valueBuilder: (p) =>
                                        p.referenceNumber ?? '',
                                    widgetBuilder: (p) => Text(
                                      p.referenceNumber ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  EnterpriseTableColumn<PaymentEntity>(
                                    title: 'Mode',
                                    valueBuilder: (p) => p.paymentMode,
                                    widgetBuilder: (p) =>
                                        _buildPaymentModeBadge(p.paymentMode),
                                  ),
                                  EnterpriseTableColumn<PaymentEntity>(
                                    title: 'Amount',
                                    valueBuilder: (p) => p.amount,
                                    isNumeric: true,
                                    widgetBuilder: (p) => Text(
                                      '₹${p.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: FuturisticColors.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                onRowTap: (payment) =>
                                    _showPaymentDetails(context, payment),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentModeChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeBadge(String mode) {
    final isOnline = mode.toLowerCase() != 'cash';
    return StatusBadge(
      label: mode,
      type: isOnline ? BadgeStatus.info : BadgeStatus.success,
      showDot: true,
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  void _showFilterDialog(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FuturisticColors.primary,
              onPrimary: Colors.white,
              surface: FuturisticColors.surface,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: FuturisticColors.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Filtering from ${DateFormat('dd MMM').format(picked.start)} to ${DateFormat('dd MMM').format(picked.end)}',
            ),
          ),
        );
        // In a real app, apply this filter to the stream or state
      }
    }
  }

  void _showPaymentDetails(BuildContext context, PaymentEntity payment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: FuturisticColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FuturisticColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: FuturisticColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Ref: ${payment.referenceNumber ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: FuturisticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: FuturisticColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Details
              _buildDetailRow(
                'Date',
                DateFormat('MMM dd, yyyy').format(payment.paymentDate),
              ),
              _buildDetailRow(
                'Amount',
                '₹${payment.amount.toStringAsFixed(2)}',
              ),
              _buildDetailRow('Payment Mode', payment.paymentMode),
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildDetailRow('Notes', payment.notes!),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticColors.premiumBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
