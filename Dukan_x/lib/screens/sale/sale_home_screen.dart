import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_state_providers.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/futuristic_colors.dart';
import '../advanced_bill_creation_screen.dart';
import 'sale_invoice_list.dart';
import 'sale_order_list.dart';
import 'sale_challan_list.dart';
import 'sale_return_list.dart';
import 'payment_in_list.dart';

class SaleHomeScreen extends ConsumerStatefulWidget {
  const SaleHomeScreen({super.key});

  @override
  ConsumerState<SaleHomeScreen> createState() => _SaleHomeScreenState();
}

class _SaleHomeScreenState extends ConsumerState<SaleHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Revenue Overview",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FuturisticColors.primary, FuturisticColors.secondary],
            ),
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: "Bills"),
            Tab(text: "Bookings"),
            Tab(text: "Dispatches"),
            Tab(text: "Inwards"),
            Tab(text: "Receipts"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Proforma & Estimates',
            onPressed: () {
              context.push('/proforma');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FuturisticColors.darkBackgroundGradient
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: const [
            SaleInvoiceListScreen(),
            SaleOrderListScreen(),
            SaleChallanListScreen(),
            SaleReturnListScreen(),
            PaymentInListScreen(),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: FuturisticColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: FuturisticColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            _handleFabAction(_tabController.index);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  void _handleFabAction(int index) {
    // Determine action based on current tab
    switch (index) {
      case 0: // Invoice
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const AdvancedBillCreationScreen(
              transactionType: TransactionType.sale,
            ),
          ),
        );
        break;
      case 1: // Order
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const AdvancedBillCreationScreen(
              transactionType: TransactionType.saleOrder,
            ),
          ),
        );
        break;
      case 2: // Challan
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const AdvancedBillCreationScreen(
              transactionType: TransactionType.deliveryChallan,
            ),
          ),
        );
        break;
      case 3: // Return
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const AdvancedBillCreationScreen(
              transactionType: TransactionType.saleReturn,
            ),
          ),
        );
        break;
      case 4: // Payment
        // This tab has its own FAB handler in PaymentInListScreen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use the Record Payment button above')),
        );
        break;
    }
  }
}
