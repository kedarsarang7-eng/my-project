import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/products_repository.dart';

import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class BillWiseProfitScreen extends ConsumerStatefulWidget {
  const BillWiseProfitScreen({super.key});

  @override
  ConsumerState<BillWiseProfitScreen> createState() =>
      _BillWiseProfitScreenState();
}

class _BillWiseProfitScreenState extends ConsumerState<BillWiseProfitScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  List<_ProfitItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) return;

      // Fetch Bills from local repository
      final bills = await sl<BillsRepository>().watchAll(userId: ownerId).first;

      // Fetch Stock/Products for Cost Price (Approximation)
      final products = await sl<ProductsRepository>()
          .watchAll(userId: ownerId)
          .first;
      final stockMap = {for (var p in products) p.id: p};

      final profitList = <_ProfitItem>[];

      for (var bill in bills) {
        if (!_isInRange(bill.date)) continue;

        double totalCost = 0;
        double totalRevenue = bill.subtotal;

        for (var item in bill.items) {
          final product = stockMap[item.vegId];
          final productCost = product?.costPrice ?? 0.0;
          totalCost += (productCost * item.qty);
        }

        final profit = totalRevenue - totalCost;

        profitList.add(
          _ProfitItem(bill: bill, cost: totalCost, profit: profit),
        );
      }

      profitList.sort((a, b) => b.bill.date.compareTo(a.bill.date));

      if (mounted) {
        setState(() {
          _items = profitList;
        });
      }
    } catch (e) {
      debugPrint("Error loading profit report: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _fetchData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Bill Wise Profit',
      subtitle:
          '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
      actions: [
        DesktopIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Select Date Range',
          onPressed: _selectDateRange,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : EnterpriseTable<_ProfitItem>(
              data: _items,
              columns: [
                EnterpriseTableColumn(
                  title: 'Date',
                  valueBuilder: (i) => DateFormat('dd MMM').format(i.bill.date),
                ),
                EnterpriseTableColumn(
                  title: 'Inv #',
                  valueBuilder: (i) => i.bill.invoiceNumber,
                ),
                EnterpriseTableColumn(
                  title: 'Customer',
                  valueBuilder: (i) => i.bill.customerName.isEmpty
                      ? 'Cash Sale'
                      : i.bill.customerName,
                ),
                EnterpriseTableColumn(
                  title: 'Revenue',
                  valueBuilder: (i) => i.bill.subtotal,
                  isNumeric: true,
                  widgetBuilder: (i) => Text(
                    '₹${i.bill.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
                EnterpriseTableColumn(
                  title: 'Profit',
                  valueBuilder: (i) => i.profit,
                  isNumeric: true,
                  widgetBuilder: (i) => Text(
                    '₹${i.profit.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i.profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfitItem {
  final Bill bill;
  final double cost;
  final double profit;

  _ProfitItem({required this.bill, required this.cost, required this.profit});
}
