import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:intl/intl.dart';
import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/ui/smart_table.dart';
import '../widgets/ui/quick_action_toolbar.dart';
import '../widgets/ui/futuristic_button.dart';
import 'bill_detail.dart';

class BillSearchScreen extends StatefulWidget {
  const BillSearchScreen({super.key});

  @override
  State<BillSearchScreen> createState() => _BillSearchScreenState();
}

class _BillSearchScreenState extends State<BillSearchScreen> {
  final TextEditingController searchController = TextEditingController();
  BillsRepository get _billsRepo => sl<BillsRepository>();
  SessionManager get _session => sl<SessionManager>();

  List<Bill> filteredBills = [];
  List<Bill> allBills = [];
  bool isLoading = true;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _loadAllBills();
  }

  Future<void> _loadAllBills() async {
    setState(() => isLoading = true);
    try {
      final userId = _session.ownerId;
      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      final result = await _billsRepo.getAll(userId: userId);
      final bills = result.data ?? [];

      // Sort by date desc
      bills.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        allBills = bills;
        filteredBills = bills;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: FuturisticColors.error,
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  void _filter() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredBills = allBills.where((bill) {
        // Text Filter
        final matchesText =
            query.isEmpty ||
            bill.customerName.toLowerCase().contains(query) ||
            bill.id.toLowerCase().contains(query) ||
            bill.status.toLowerCase().contains(query);

        // Date Filter
        bool matchesDate = true;
        if (_selectedRange != null) {
          final start = DateTime(
            _selectedRange!.start.year,
            _selectedRange!.start.month,
            _selectedRange!.start.day,
          );
          final end = DateTime(
            _selectedRange!.end.year,
            _selectedRange!.end.month,
            _selectedRange!.end.day,
            23,
            59,
            59,
          );
          matchesDate = bill.date.isAfter(start) && bill.date.isBefore(end);
        }

        return matchesText && matchesDate;
      }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FuturisticColors.primary,
              surface: FuturisticColors.surface,
              onSurface: FuturisticColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedRange = picked);
      _filter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: ResponsiveContainer(
        child: Column(
          children: [
          QuickActionToolbar(
            title: 'Bill Archives',
            searchField: TextField(
              controller: searchController,
              onChanged: (_) => _filter(),
              style: const TextStyle(color: FuturisticColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by Customer, ID, Status...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: FuturisticColors.textSecondary,
                ),
                filled: true,
                fillColor: FuturisticColors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              FuturisticButton.secondary(
                label: _selectedRange == null
                    ? 'Date Range'
                    : '${DateFormat('dd/MM').format(_selectedRange!.start)} - ${DateFormat('dd/MM').format(_selectedRange!.end)}',
                icon: Icons.calendar_today,
                onPressed: _pickDateRange,
              ),
              if (_selectedRange != null)
                IconButton(
                  icon: const Icon(Icons.close, color: FuturisticColors.error),
                  onPressed: () {
                    setState(() => _selectedRange = null);
                    _filter();
                  },
                ),
              const SizedBox(width: 8),
              FuturisticButton.primary(
                label: 'Refresh',
                icon: Icons.refresh,
                onPressed: _loadAllBills,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SmartTable<Bill>(
                isLoading: isLoading,
                emptyMessage: 'No bills found matching your criteria.',
                data: filteredBills,
                onRowClick: (bill) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BillDetailScreen(bill: bill),
                    ),
                  );
                },
                columns: [
                  SmartTableColumn(
                    title: 'Bill ID',
                    flex: 2,
                    builder: (b) => Text(
                      '#${b.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontFamily: 'Monospace',
                        color: FuturisticColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SmartTableColumn(
                    title: 'Date',
                    flex: 1,
                    valueMapper: (b) =>
                        DateFormat('dd MMM yyyy').format(b.date),
                  ),
                  SmartTableColumn(
                    title: 'Customer',
                    flex: 2,
                    valueMapper: (b) =>
                        b.customerName.isEmpty ? b.customerId : b.customerName,
                  ),
                  SmartTableColumn(
                    title: 'Amount',
                    flex: 1,
                    builder: (b) => Text(
                      '₹${b.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: FuturisticColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SmartTableColumn(
                    title: 'Status',
                    flex: 1,
                    builder: (b) {
                      Color color = FuturisticColors.textSecondary;
                      if (b.status == 'Paid') color = FuturisticColors.success;
                      if (b.status == 'Unpaid') color = FuturisticColors.error;
                      if (b.status == 'Partial') {
                        color = FuturisticColors.warning;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          b.status.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
