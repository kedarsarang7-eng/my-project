import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../services/bill_print_service.dart';
import '../widgets/bill_display_table.dart';
import 'edit_bill_screen.dart';

class OwnerBillListScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const OwnerBillListScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<OwnerBillListScreen> createState() => _OwnerBillListScreenState();
}

class _OwnerBillListScreenState extends State<OwnerBillListScreen> {
  double fontSize = 12.0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _markBillPaid(Bill bill, bool paid) async {
    try {
      final updatedBill = bill
          .copyWith(
            status: paid ? 'Paid' : 'Unpaid',
            paidAmount: paid ? bill.subtotal : 0.0,
          )
          .sanitized();

      await sl<BillsRepository>().updateBill(updatedBill);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bill marked as ${paid ? 'Paid' : 'Unpaid'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating bill: $e')));
      }
    }
  }

  Future<void> _deleteBill(Bill bill) async {
    try {
      debugPrint("Attempting to delete bill with ID: ${bill.id}");

      await sl<BillsRepository>().deleteBill(bill.id, bill.ownerId);
      debugPrint("Bill deleted successfully - refreshing UI");
      // The StreamBuilder will automatically refresh and remove the deleted bill
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('âœ… Bill deleted successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: FuturisticColors.success,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint("Error deleting bill: $e");
      debugPrint("STACK: $stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('âŒ Error deleting bill: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
    }
  }

  void _editBill(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBillScreen(
          bill: bill,
          customerName: widget.customerName,
          onBillUpdated: () {
            setState(() {}); // Refresh UI
          },
        ),
      ),
    );
  }

  void _printBill(Bill bill) async {
    // Show theme selection dialog
    final theme = await showDialog<BillTheme>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Bill Theme'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, BillTheme.standard),
            child: const Row(
              children: [
                Icon(Icons.receipt, color: FuturisticColors.primary),
                SizedBox(width: 10),
                Text('Standard (Green)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, BillTheme.modern),
            child: const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 10),
                Text('Modern (Blue)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, BillTheme.minimal),
            child: const Row(
              children: [
                Icon(Icons.description, color: Colors.black),
                SizedBox(width: 10),
                Text('Minimal (B&W)'),
              ],
            ),
          ),
        ],
      ),
    );

    if (theme == null) return; // Cancelled

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating bill...'),
          duration: Duration(seconds: 1),
        ),
      );

      await BillPrintService.generateAndPrintBillPDF(
        bill,
        widget.customerName,
        'à¤®à¥‹ à¤¨à¤µà¤¦à¥à¤°à¥à¤—à¤¾ à¤¸à¤¬à¥à¤œà¥€ à¤­à¤£à¥à¤¡à¤¾à¤°', // Replace with your shop name
        '9876543210', // Replace with your phone
        'Vegetable Market, City', // Replace with your address
        printDirectly: true,
        theme: theme,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  void _increaseFontSize() {
    setState(() {
      if (fontSize < 18.0) fontSize += 1.0;
    });
  }

  void _decreaseFontSize() {
    setState(() {
      if (fontSize > 8.0) fontSize -= 1.0;
    });
  }

  void _resetFontSize() {
    setState(() {
      fontSize = 12.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bills - ${widget.customerName}'),
        backgroundColor: FuturisticColors.primary,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Decrease Font Size',
            child: IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _decreaseFontSize,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                '${(fontSize / 12.0 * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Increase Font Size',
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _increaseFontSize,
            ),
          ),
          Tooltip(
            message: 'Reset Font Size',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetFontSize,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveContainer(
        child: StreamBuilder<List<Bill>>(
        stream: sl<BillsRepository>().watchAll(
          userId: sl<SessionManager>().ownerId ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bills: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Check if filtered list is empty inside logic below, but initially check raw data
            // actually we need to filter first
          }

          final allBills = snapshot.data ?? [];
          final bills = allBills
              .where((b) => b.customerId == widget.customerId)
              .toList();

          // Sort descending by date
          bills.sort((a, b) => b.date.compareTo(a.date));

          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No bills found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Logic moved above to 'bills' variable
          // final bills = snapshot.data!.docs ...

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final dateStr = DateFormat('dd/MM/yyyy').format(bill.date);
              final isPaid = bill.status == 'Paid';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                child: ExpansionTile(
                  backgroundColor: isPaid
                      ? FuturisticColors.paidBackground
                      : FuturisticColors.unpaidBackground,
                  collapsedBackgroundColor: isPaid
                      ? FuturisticColors.paidBackground
                      : FuturisticColors.unpaidBackground,
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${bill.items.length} items â€¢ â‚¹${bill.subtotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? FuturisticColors.paid
                              : FuturisticColors.unpaid,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle : Icons.cancel,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              bill.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bill table
                          BillDisplayTable(
                            items: bill.items,
                            subtotal: bill.subtotal,
                            discountApplied: bill.discountApplied,
                            total: bill.subtotal - bill.discountApplied,
                            status: bill.status,
                            fontSize: fontSize,
                          ),

                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _editBill(bill),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _printBill(bill),
                                  icon: const Icon(Icons.print),
                                  label: const Text('Print'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (isPaid) {
                                      _markBillPaid(bill, false);
                                    } else {
                                      _markBillPaid(bill, true);
                                    }
                                  },
                                  icon: Icon(
                                    isPaid ? Icons.close : Icons.check,
                                  ),
                                  label: Text(
                                    isPaid ? 'Mark Unpaid' : 'Mark Paid',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Bill?'),
                                        content: const Text(
                                          'Are you sure you want to delete this bill? This action cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteBill(bill);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  FuturisticColors.error,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete Bill'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FuturisticColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ));
  }
}
