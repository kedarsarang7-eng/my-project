import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import 'widgets/transaction_list_widget.dart';
import '../advanced_bill_creation_screen.dart';

class SaleInvoiceListScreen extends StatelessWidget {
  const SaleInvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TransactionListWidget(
        type: TransactionType.sale,
        emptyMessage: "No Sale Invoices found.",
        emptyButtonLabel: "Create Sale",
        onAddPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdvancedBillCreationScreen(
                transactionType: TransactionType.sale,
              ),
            ),
          );
        },
      ),
      // We don't need FAB here because SaleHomeScreen handles FAB for now,
      // OR we can move FAB logic here if we want screen-specific FABs.
      // Requirements said "Floating Action Buttons like Vyapar".
      // Usually it's better to have it per screen.
      // But SaleHomeScreen has a main FAB. Let's rely on that or duplicate.
      // Actually SaleHomeScreen's FAB calls _handleFabAction which just shows a SnackBar for now.
    );
  }
}
