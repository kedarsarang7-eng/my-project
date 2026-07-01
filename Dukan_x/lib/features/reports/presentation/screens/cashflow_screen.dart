import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/session/session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CashflowScreen extends ConsumerStatefulWidget {
  const CashflowScreen({super.key});

  @override
  ConsumerState<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends ConsumerState<CashflowScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;

  double _totalIn = 0;
  double _totalOut = 0;

  final List<_FlowItem> _inItems = [];
  final List<_FlowItem> _outItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch data using Repositories (Offline-First)
      // Using .first to get current snapshot for this report logic
      // Ideally these reports should be reactive streams, but keeping existing structure for now.

      final bills = await sl<BillsRepository>().watchAll(userId: ownerId).first;
      final purchases = await sl<PurchaseRepository>()
          .watchAll(userId: ownerId)
          .first;
      final expenses = await sl<ExpensesRepository>()
          .watchAll(userId: ownerId)
          .first;

      // Reset
      _totalIn = 0;
      _totalOut = 0;
      _inItems.clear();
      _outItems.clear();

      // Process Money In (Sales)
      for (var b in bills) {
        if (!_isInRange(b.date)) continue;
        if (b.paidAmount > 0) {
          _totalIn += b.paidAmount;
          _inItems.add(
            _FlowItem(
              date: b.date,
              title: b.customerName.isEmpty ? 'Cash Sale' : b.customerName,
              subtitle: 'Inv #${b.invoiceNumber}',
              amount: b.paidAmount,
              isCash: b.paymentMode == 'Cash',
            ),
          );
        }
      }

      // Process Money Out (Purchases)
      for (var p in purchases) {
        if (!_isInRange(p.purchaseDate)) continue;
        if (p.paidAmount > 0) {
          _totalOut += p.paidAmount;
          _outItems.add(
            _FlowItem(
              date: p.purchaseDate,
              title: p.vendorName ?? 'Unknown Vendor',
              subtitle: 'Bill #${p.invoiceNumber ?? 'N/A'}',
              amount: p.paidAmount,
              isCash: false,
            ),
          );
        }
      }

      // Process Money Out (Expenses)
      for (var e in expenses) {
        if (!_isInRange(e.date)) continue;
        _totalOut += e.amount;
        _outItems.add(
          _FlowItem(
            date: e.date,
            title: e.category,
            subtitle: e.description,
            amount: e.amount,
            isCash: true,
          ),
        );
      }

      // Sort
      _inItems.sort((a, b) => b.date.compareTo(a.date));
      _outItems.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading cashflow: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'Cashflow',
      subtitle:
          '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
      actions: [
        DesktopIconButton(
          icon: Icons.date_range,
          tooltip: 'Select Date Range',
          onPressed: _selectDateRange,
        ),
      ],
      child: Column(
        children: [
          // Tabs in Content Container
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: context.isMobile ? double.infinity : 400,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: context.isMobile,
              labelColor: isDark ? Colors.white : Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorWeight: 0,
              indicator: BoxDecoration(
                color: isDark ? Colors.blue.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              tabs: const [
                Tab(text: "Money In"),
                Tab(text: "Money Out"),
              ],
            ),
          ),
          // Net Cashflow Card — responsive layout for mobile
          Container(
            padding: EdgeInsets.all(
              responsiveValue<double>(
                context,
                mobile: 16,
                tablet: 20,
                desktop: 24,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: context.isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Flow (Selected Period)',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\u20B9${(_totalIn - _totalOut).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                          color: (_totalIn - _totalOut) >= 0
                              ? FuturisticColors.success
                              : FuturisticColors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FuturisticColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'In: \u20B9${_totalIn.toStringAsFixed(0)}  |  Out: \u20B9${_totalOut.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: FuturisticColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Flow (Selected Period)',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\u20B9${(_totalIn - _totalOut).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: responsiveValue<double>(
                                context,
                                mobile: 28.0,
                                tablet: 30.0,
                                desktop:
                                    32.0, // PRESERVED: Desktop uses exactly 32 as before
                              ),
                              fontWeight: FontWeight.bold,
                              color: (_totalIn - _totalOut) >= 0
                                  ? FuturisticColors.success
                                  : FuturisticColors.error,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: FuturisticColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Total In: \u20B9${_totalIn.toStringAsFixed(0)}  |  Total Out: \u20B9${_totalOut.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FuturisticColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Tab content with minimum height on mobile for visibility
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    height: responsiveValue<double>(
                      context,
                      mobile: 200,
                      desktop: 300,
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_inItems, FuturisticColors.success, isDark),
                        _buildList(_outItems, FuturisticColors.error, isDark),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_FlowItem> items, Color amountColor, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text("No transactions", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 8, tablet: 12, desktop: 16),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 10,
              tablet: 12,
              desktop: 12,
            ),
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
            ],
          ),
          child: Row(
            children: [
              Icon(
                item.isCash ? Icons.money : Icons.credit_card,
                color: isDark ? Colors.white54 : Colors.grey,
                size: context.isMobile ? 20 : 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.isMobile ? 13 : 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM hh:mm a').format(item.date),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '\u20B9${item.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 14 : 16,
                  color: amountColor,
                ),
              ),
            ],
          ),
        );
      },
    );
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
}

class _FlowItem {
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCash;

  _FlowItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCash,
  });
}
