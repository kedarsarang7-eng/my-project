import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import 'widgets/transaction_list_widget.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../models/customer.dart';
import 'widgets/record_payment_sheet.dart';

class PaymentInListScreen extends StatelessWidget {
  const PaymentInListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TransactionListWidget(
        type: TransactionType.paymentIn,
        emptyMessage: "No Payments Received found.",
        emptyButtonLabel: "Record Payment",
        onAddPressed: () => _showRecordPaymentFlow(context),
      ),
    );
  }

  void _showRecordPaymentFlow(BuildContext context) async {
    // Step 1: Select Customer
    final Customer? selectedCustomer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (ctx) => const CustomersListScreen(isSelectionMode: true),
      ),
    );

    if (selectedCustomer == null || !context.mounted) return;

    // Step 2: Show Payment Recording Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecordPaymentSheet(customer: selectedCustomer),
    );
  }
}
