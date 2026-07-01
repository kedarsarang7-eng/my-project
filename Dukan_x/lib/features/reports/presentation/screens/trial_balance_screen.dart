import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class TrialBalanceScreen extends ConsumerStatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  ConsumerState<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends ConsumerState<TrialBalanceScreen> {
  bool _isLoading = false;
  List<_TBRow> _rows = [];
  double _totalDebit = 0;
  double _totalCredit = 0;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) return;

      // Fetch All Data from local repositories
      final bills = await sl<BillsRepository>().watchAll(userId: ownerId).first;
      final purchases = await sl<PurchaseRepository>()
          .watchAll(userId: ownerId)
          .first;
      final expenses = await sl<ExpensesRepository>()
          .watchAll(userId: ownerId)
          .first;
      final products = await sl<ProductsRepository>()
          .watchAll(userId: ownerId)
          .first;
      final customers = await sl<CustomersRepository>()
          .watchAll(userId: ownerId)
          .first;

      double sales = 0;
      double purch = 0;
      double expenseTotal = 0;
      double debtors = 0;
      double creditors = 0;
      double stockValue = 0;
      double cashBalance = 0;

      // Sales (Credit)
      for (var b in bills) {
        sales += b.grandTotal;
      }

      // Purchases (Debit)
      for (var p in purchases) {
        purch += p.totalAmount;
        // Creditors = Sum of Unpaid Purchase Bills
        final unpaid = (p.totalAmount - p.paidAmount).clamp(0, double.infinity);
        creditors += unpaid;
      }

      // Expenses (Debit)
      for (var e in expenses) {
        expenseTotal += e.amount;
      }

      // Debtors (Debit)
      for (var c in customers) {
        debtors += c.totalDues;
      }

      // Stock Value (Debit - Asset)
      for (var p in products) {
        stockValue += (p.stockQuantity * p.costPrice);
      }

      // Cash/Bank Balance (Debit)
      // Money In = Paid Sales
      double moneyIn = 0;
      for (var b in bills) {
        moneyIn += b.paidAmount;
      }

      double moneyOut = 0;
      for (var p in purchases) {
        moneyOut += p.paidAmount;
      }
      moneyOut += expenseTotal;

      cashBalance = moneyIn - moneyOut;

      // Prepare Rows
      final rows = <_TBRow>[];

      rows.add(_TBRow("Sales Account", 0, sales));
      rows.add(_TBRow("Purchase Account", purch, 0));
      rows.add(_TBRow("Indirect Expenses", expenseTotal, 0));
      rows.add(_TBRow("Sundry Debtors", debtors, 0));
      rows.add(_TBRow("Sundry Creditors", 0, creditors));
      rows.add(_TBRow("Closing Stock", stockValue, 0));

      if (cashBalance >= 0) {
        rows.add(_TBRow("Cash/Bank Balance", cashBalance, 0));
      } else {
        rows.add(_TBRow("Bank Overdraft", 0, cashBalance.abs()));
      }

      // Calculate Totals
      double sumDr = 0;
      double sumCr = 0;
      for (var r in rows) {
        sumDr += r.debit;
        sumCr += r.credit;
      }

      // Difference (Suspense / Opening Equity)
      final diff = sumDr - sumCr;
      if (diff != 0) {
        if (diff > 0) {
          rows.add(_TBRow("Opening Equity / Suspense", 0, diff));
          sumCr += diff;
        } else {
          rows.add(_TBRow("Suspense Account", diff.abs(), 0));
          sumDr += diff.abs();
        }
      }

      _totalDebit = sumDr;
      _totalCredit = sumCr;

      if (mounted) {
        setState(() {
          _rows = rows;
        });
      }
    } catch (e) {
      debugPrint("Error loading TB: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'Trial Balance',
      subtitle: 'Summary of all ledger balances',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: () {
            _calculate();
          },
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: EnterpriseTable<_TBRow>(
                    data: _rows,
                    columns: [
                      EnterpriseTableColumn(
                        title: 'Particulars',
                        valueBuilder: (r) => r.name,
                      ),
                      EnterpriseTableColumn(
                        title: 'Debit',
                        valueBuilder: (r) => r.debit,
                        isNumeric: true,
                        widgetBuilder: (r) => Text(
                          r.debit > 0 ? r.debit.toStringAsFixed(2) : "-",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      EnterpriseTableColumn(
                        title: 'Credit',
                        valueBuilder: (r) => r.credit,
                        isNumeric: true,
                        widgetBuilder: (r) => Text(
                          r.credit > 0 ? r.credit.toStringAsFixed(2) : "-",
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),

                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            "Dr: ${_totalDebit.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "Cr: ${_totalCredit.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
  }
}

class _TBRow {
  final String name;
  final double debit;
  final double credit;

  _TBRow(this.name, this.debit, this.credit);
}
