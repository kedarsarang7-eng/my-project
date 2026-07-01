import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/theme/futuristic_colors.dart';

class TotalBillsScreen extends StatefulWidget {
  const TotalBillsScreen({super.key});

  @override
  State<TotalBillsScreen> createState() => _TotalBillsScreenState();
}

class _TotalBillsScreenState extends State<TotalBillsScreen> {
  final _searchCtrl = TextEditingController();
  String _dateFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final ownerId = sessionManager.ownerId;
    if (ownerId == null) {
      return const Scaffold(body: Center(child: Text("Please login first")));
    }

    final isMobile = context.isMobile;

    return Scaffold(
      appBar: AppBar(
        elevation: 8,
        shadowColor: Colors.black26,
        backgroundColor: Colors.white,
        title: Text(
          'Total Bills',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: FuturisticColors.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ResponsiveContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search & Filters
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by invoice/customer name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // Date Filter Chips
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _dateFilter == 'All',
                    onSelected: (_) => setState(() => _dateFilter = 'All'),
                  ),
                  FilterChip(
                    label: const Text('Daily'),
                    selected: _dateFilter == 'Daily',
                    onSelected: (_) => setState(() => _dateFilter = 'Daily'),
                  ),
                  FilterChip(
                    label: const Text('Weekly'),
                    selected: _dateFilter == 'Weekly',
                    onSelected: (_) => setState(() => _dateFilter = 'Weekly'),
                  ),
                  FilterChip(
                    label: const Text('Monthly'),
                    selected: _dateFilter == 'Monthly',
                    onSelected: (_) => setState(() => _dateFilter = 'Monthly'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<Bill>>(
                  stream: sl<BillsRepository>().watchAll(userId: ownerId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var bills = snap.data ?? [];

                    // Apply search filter
                    final q = _searchCtrl.text.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      bills = bills.where((b) {
                        if (b.invoiceNumber.toLowerCase().contains(q)) {
                          return true;
                        }
                        if (b.customerName.toLowerCase().contains(q)) return true;
                        return false;
                      }).toList();
                    }

                    // Apply date filter
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final weekStart = today.subtract(
                      Duration(days: today.weekday - 1),
                    );
                    final monthStart = DateTime(now.year, now.month, 1);

                    if (_dateFilter == 'Daily') {
                      bills = bills
                          .where(
                            (b) =>
                                !b.date.isBefore(today) &&
                                b.date.isBefore(
                                  today.add(const Duration(days: 1)),
                                ),
                          )
                          .toList();
                    } else if (_dateFilter == 'Weekly') {
                      bills = bills
                          .where((b) => !b.date.isBefore(weekStart))
                          .toList();
                    } else if (_dateFilter == 'Monthly') {
                      bills = bills
                          .where((b) => !b.date.isBefore(monthStart))
                          .toList();
                    }

                    if (bills.isEmpty) {
                      return const Center(child: Text('No bills found'));
                    }

                    return isMobile
                        ? ListView.separated(
                            itemCount: bills.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              return _buildBillCard(context, bills[idx]);
                            },
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 450,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 110,
                            ),
                            itemCount: bills.length,
                            itemBuilder: (context, idx) {
                              return _buildBillCard(context, bills[idx]);
                            },
                          );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Bill b) {
    final statusColor = b.status.toLowerCase().contains('paid')
        ? FuturisticColors.paid
        : (b.status.toLowerCase().contains('partial')
            ? FuturisticColors.warning
            : FuturisticColors.unpaid);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice ${b.invoiceNumber.isEmpty ? b.id.substring(0, 8) : b.invoiceNumber}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      b.customerName.isEmpty ? 'Unknown Customer' : b.customerName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  b.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b.date.toIso8601String().split('T')[0],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '₹${b.grandTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
