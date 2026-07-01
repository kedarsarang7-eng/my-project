import 'package:flutter/material.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import 'dart:developer' as developer;

/// Widget to display bills with Paid/Pending toggle for owner
class OwnerBillPaidToggleWidget extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double Function() getPendingAmount;
  final VoidCallback onStatusChanged;

  const OwnerBillPaidToggleWidget({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.getPendingAmount,
    required this.onStatusChanged,
  });

  @override
  State<OwnerBillPaidToggleWidget> createState() =>
      _OwnerBillPaidToggleWidgetState();
}

class _OwnerBillPaidToggleWidgetState extends State<OwnerBillPaidToggleWidget> {
  // Use Repositories
  BillsRepository get _billsRepo => sl<BillsRepository>();
  SessionManager get _session => sl<SessionManager>();

  Future<void> _updateBillStatus(
    String billId,
    double billAmount,
    bool isPaid,
  ) async {
    try {
      final status = isPaid ? 'Paid' : 'Pending';
      final paidAmount = isPaid ? billAmount : 0.0;

      // Default to Cash if marking as paid toggled, or use logic safely
      // Legacy code didn't specify, we assume Cash for manual toggle or just update total
      final result = await _billsRepo.updateBillStatus(
        billId: billId,
        status: status,
        paidAmount: paidAmount,
        cashPaid: isPaid ? paidAmount : 0.0, // Assuming cash for manual toggle
        onlinePaid: 0.0,
      );

      if (result.success) {
        widget.onStatusChanged();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill marked as ${isPaid ? 'Paid' : 'Pending'}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          handleOperationError(
            context,
            result.errorMessage ?? 'Unknown error',
            null,
            customMessage: 'Failed to update bill',
          );
        }
      }
    } catch (e, stack) {
      if (mounted) {
        handleOperationError(
          context,
          e,
          stack,
          customMessage: 'Failed to update bill',
        );
      }
    }
  }

  void handleOperationError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace, {
    String? customMessage,
  }) {
    developer.log(
      customMessage ?? 'Operation failed',
      error: error,
      stackTrace: stackTrace,
      name: 'OwnerBillPaidToggle',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customMessage ?? "Error"}: ${error.toString()}'),
        backgroundColor: FuturisticColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _session.ownerId;
    if (userId == null) {
      return const Center(child: Text("Authentication Error"));
    }

    return StreamBuilder<List<Bill>>(
      stream: _billsRepo.watchAll(
        userId: userId,
        customerId: widget.customerId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final bills = snapshot.data ?? [];

        if (bills.isEmpty) {
          return Center(
            child: Text(
              'No bills for ${widget.customerName}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            final billId = bill.id;
            final isPaid = bill.status == 'Paid';
            final billAmount = bill.grandTotal;
            final date = bill.date;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${billAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Paid/Pending Checkbox
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? FuturisticColors.paidBackground
                            : FuturisticColors.unpaidBackground,
                        border: Border.all(
                          color: isPaid
                              ? FuturisticColors.paid
                              : FuturisticColors.unpaid,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isPaid
                                ? FuturisticColors.paid
                                : FuturisticColors.unpaid,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                _updateBillStatus(billId, billAmount, !isPaid),
                            child: Text(
                              isPaid ? 'Paid' : 'Pending',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? FuturisticColors.paid
                                    : FuturisticColors.unpaid,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Dashboard widget showing total pending amount with real-time updates
class PendingAmountSummary extends StatelessWidget {
  const PendingAmountSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Bill>>(
      stream: sl<BillsRepository>().watchAll(userId: userId),
      builder: (context, snapshot) {
        double totalPending = 0;
        int pendingCount = 0;

        if (snapshot.hasData) {
          final bills = snapshot.data!;
          for (var bill in bills) {
            // Logic: Check if status is Pending/Partial or unpaid amount
            // Legacy checked 'status' == 'Pending'.
            // We can check paidAmount < grandTotal
            if (bill.paidAmount < bill.grandTotal) {
              totalPending += (bill.grandTotal - bill.paidAmount);
              pendingCount++;
            }
          }
        }

        return Card(
          color: totalPending > 0
              ? FuturisticColors.unpaidBackground
              : FuturisticColors.paidBackground,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: totalPending > 0
                      ? FuturisticColors.unpaid
                      : FuturisticColors.paid,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pending Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: totalPending > 0
                            ? FuturisticColors.unpaid
                            : FuturisticColors.paid,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${totalPending.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: totalPending > 0
                        ? FuturisticColors.unpaid
                        : FuturisticColors.paid,
                  ),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Average: ₹${(totalPending / pendingCount).toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
