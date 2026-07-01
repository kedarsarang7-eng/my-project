import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/glass_morphism.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BalanceScreen extends ConsumerStatefulWidget {
  const BalanceScreen({super.key});

  @override
  ConsumerState<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends ConsumerState<BalanceScreen> {
  double _totalBankBalance = 0;
  double _estimatedCashBalance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) return;

    try {
      // Bank balance: For now, we'll estimate from bills cash transactions
      // In a real scenario, we would have a BankRepository
      double bankBal = 0;

      // Get bills and expenses from local repository
      final bills = await sl<BillsRepository>().watchAll(userId: ownerId).first;
      final expenses = await sl<ExpensesRepository>()
          .watchAll(userId: ownerId)
          .first;

      // Sum Cash Sales
      double totalCashSales = 0;
      double totalOnlineSales = 0;
      for (var bill in bills) {
        totalCashSales += bill.cashPaid;
        totalOnlineSales += bill.onlinePaid;
      }

      // Sum Expenses
      double totalExpenses = 0;
      for (var exp in expenses) {
        totalExpenses += exp.amount;
      }

      // Estimate: Online sales go to bank, cash stays in hand
      bankBal = totalOnlineSales;
      final estCash = totalCashSales - totalExpenses;

      if (mounted) {
        setState(() {
          _totalBankBalance = bankBal;
          _estimatedCashBalance = estCash;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading balance: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final totalBalance = _totalBankBalance + _estimatedCashBalance;

    return DesktopContentContainer(
      title: "Balance Overview",
      subtitle: "Snapshot of your current liquid assets",
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: () {
            setState(() => _loading = true);
            _loadData();
          },
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Total Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF43cea2), const Color(0xFF185a9d)]
                            : [Colors.blue.shade400, Colors.blue.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Total Liquid Assets",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "${sl<CurrencyService>().symbol} ${totalBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: responsiveValue<double>(context,
                    mobile: 32.0,
                    tablet: 32.0,
                    desktop: 40.0,  // PRESERVED: Desktop uses exactly 40 as before
                  ),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Breakdown
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildBalanceCard(
                            "Cash in Hand",
                            _estimatedCashBalance,
                            Icons.money_rounded,
                            Colors.green,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildBalanceCard(
                            "Bank Accounts",
                            _totalBankBalance,
                            Icons.account_balance_rounded,
                            Colors.blue,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(
    String title,
    double value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "${sl<CurrencyService>().symbol} ${value.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
