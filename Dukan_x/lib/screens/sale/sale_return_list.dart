import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import 'widgets/transaction_list_widget.dart';
import '../advanced_bill_creation_screen.dart';

class SaleReturnListScreen extends StatelessWidget {
  const SaleReturnListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TransactionListWidget(
        type: TransactionType.saleReturn,
        emptyMessage: "No Sale Returns (Credit Notes) found.",
        emptyButtonLabel: "Create Return",
        onAddPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdvancedBillCreationScreen(
                transactionType: TransactionType.saleReturn,
              ),
            ),
          );
        },
      ),
    );
  }
}
