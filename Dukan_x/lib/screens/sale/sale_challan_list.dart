import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import 'widgets/transaction_list_widget.dart';
import '../advanced_bill_creation_screen.dart';

class SaleChallanListScreen extends StatelessWidget {
  const SaleChallanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TransactionListWidget(
        type: TransactionType.deliveryChallan,
        emptyMessage: "No Delivery Challans found.",
        emptyButtonLabel: "Create Challan",
        onAddPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdvancedBillCreationScreen(
                transactionType: TransactionType.deliveryChallan,
              ),
            ),
          );
        },
      ),
    );
  }
}
