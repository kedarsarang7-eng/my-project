import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../models/purchase_bill.dart';
import '../../../../models/expense.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

class PnlScreen extends ConsumerStatefulWidget {
  const PnlScreen({super.key});

  @override
  ConsumerState<PnlScreen> createState() => _PnlScreenState();
}

class _PnlScreenState extends ConsumerState<PnlScreen> {
  String _period = 'Monthly'; // Daily, Monthly
  DateTime _selectedDate = DateTime.now();

  // Data
  List<Bill> _allBills = [];
  List<PurchaseBill> _purchaseBills = [];
  List<Expense> _expenses = [];
  bool _isLoading = true;

  // Subscriptions
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _setupStreams(); // Call the new setup method
  }

  void _setupStreams() {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading if no ownerId
        });
      }
      return;
    }

    // 1. Sales (Bills)
    _subs.add(
      sl<BillsRepository>().watchAll(userId: ownerId).listen((bills) {
        if (mounted) {
          setState(() {
            _allBills = bills;
            _isLoading = false; // Set loading to false after first data stream
          });
        }
      }),
    );

    // 2. Purchases
    _subs.add(
      sl<PurchaseRepository>().watchAll(userId: ownerId).listen((orders) {
        if (mounted) {
          // Map PurchaseOrder to PurchaseBill for internal calculation
          final bills = orders.map((order) {
            return PurchaseBill(
              id: order.id,
              billNumber: order.invoiceNumber ?? '',
              supplierId: order.vendorId ?? '',
              supplierName: order.vendorName ?? 'Unknown',
              date: order.purchaseDate,
              items: [],
              grandTotal: order.totalAmount,
              paidAmount: order.paidAmount,
              status: order.status,
              paymentMode: order.paymentMode ?? 'Cash',
              notes: order.notes ?? '',
              ownerId: order.userId,
            );
          }).toList();

          setState(() {
            _purchaseBills = bills;
          });
        }
      }),
    );

    // 3. Expenses
    _subs.add(
      sl<ExpensesRepository>().watchAll(userId: ownerId).listen((expenses) {
        if (mounted) {
          // Map ExpenseModel to Expense for internal calculation
          final mappedExpenses = expenses
              .map(
                (e) => Expense(
                  id: e.id,
                  category: e.category,
                  description: e.description,
                  amount: e.amount,
                  date: e.date,
                  ownerId: e.ownerId,
                ),
              )
              .toList();

          setState(() {
            _expenses = mappedExpenses;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    for (var sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  PnLData _calculate() {
    DateTime start, end;

    if (_period == 'Daily') {
      start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      end = start.add(const Duration(days: 1));
    } else {
      start = DateTime(_selectedDate.year, _selectedDate.month);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1);
    }

    double sales = 0;
    double purch = 0;
    double exp = 0;

    for (var b in _allBills) {
      if (b.date.isAfter(start) && b.date.isBefore(end)) {
        sales += b.grandTotal;
      }
    }
    for (var p in _purchaseBills) {
      if (p.date.isAfter(start) && p.date.isBefore(end)) {
        purch += p.grandTotal;
      }
    }
    for (var e in _expenses) {
      if (e.date.isAfter(start) && e.date.isBefore(end)) {
        exp += e.amount;
      }
    }

    return PnLData(sales, purch, exp);
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final data = _calculate();

    return DesktopContentContainer(
      title: "Profit & Loss",
      subtitle: "Net income analysis and breakdown",
      actions: [
        // Dropdown for frequency
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              icon: const Icon(Icons.arrow_drop_down),
              onChanged: (val) {
                if (val != null) setState(() => _period = val);
              },
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        DesktopIconButton(
          icon: Icons.calendar_month_rounded,
          tooltip: 'Select Date',
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (data.totalSales == 0 &&
                data.totalPurchases == 0 &&
                data.totalExpenses == 0)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pie_chart_outline_rounded,
                    size: 80,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No profit data available",
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Start making sales to see analysis.",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Period Selector Label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _period == 'Daily'
                          ? DateFormat('MMMM d, yyyy').format(_selectedDate)
                          : DateFormat('MMMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  // Net Profit Card
                  _buildNetProfitCard(data, isDark),
                  const SizedBox(height: 20),

                  // Breakdown
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Total Sales",
                          data.totalSales,
                          FuturisticColors.success,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          "Purchases",
                          data.totalPurchases,
                          Colors.orange,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          "Expenses",
                          data.totalExpenses,
                          Colors.redAccent,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Container()), // Spacer
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNetProfitCard(PnLData data, bool isDark) {
    final profit = data.netProfit;
    final isLoss = profit < 0;

    return GlassMorphism(
      borderRadius: 24,
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
      color: isLoss ? Colors.redAccent : Colors.teal,
      opacity: 0.2,
      child: Column(
        children: [
          Text(
            "Net Profit",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            "${sl<CurrencyService>().symbol} ${profit.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isLoss ? Colors.redAccent : Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  (isLoss ? FuturisticColors.error : FuturisticColors.success)
                      .withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isLoss ? "Loss Detected" : "Healthy Profit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLoss
                    ? FuturisticColors.error
                    : FuturisticColors.success,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color, bool isDark) {
    return GlassMorphism(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.attach_money, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${sl<CurrencyService>().symbol}${value.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class PnLData {
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;

  PnLData(this.totalSales, this.totalPurchases, this.totalExpenses);

  factory PnLData.empty() => PnLData(0, 0, 0);

  double get netProfit => totalSales - totalPurchases - totalExpenses;
}
