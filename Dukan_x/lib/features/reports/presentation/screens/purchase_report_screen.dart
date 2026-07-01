import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/repository/purchase_repository.dart';
import '../../../../models/purchase_bill.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../services/pdf_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class PurchaseReportScreen extends ConsumerStatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  ConsumerState<PurchaseReportScreen> createState() =>
      _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends ConsumerState<PurchaseReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFilter = 'All'; // All, Paid, Unpaid
  String _searchQuery = '';

  bool _isLoading = false;
  List<PurchaseBill> _allBills = [];
  List<PurchaseBill> _filteredBills = [];

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch purchase orders from repository
      sl<PurchaseRepository>().watchAll(userId: ownerId).listen((orders) {
        if (!mounted) return;

        final bills = orders.map((order) {
          // Map PurchaseOrder to PurchaseBill for UI compatibility
          return PurchaseBill(
            id: order.id,
            billNumber: order.invoiceNumber ?? '',
            supplierId: order.vendorId ?? '',
            supplierName: order.vendorName ?? 'Unknown',
            date: order.purchaseDate,
            items: [], // Items not strictly needed for this list view
            grandTotal: order.totalAmount,
            paidAmount: order.paidAmount,
            status: order.status,
            paymentMode: order.paymentMode ?? 'Cash',
            notes: order.notes ?? '',
            ownerId: order.userId,
          );
        }).toList();

        setState(() {
          _allBills = bills;
          _applyFilters();
          _isLoading = false;
        });
      });
    } catch (e) {
      debugPrint("Error loading purchase bills: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredBills = _allBills.where((bill) {
      // Date Range
      final date = bill.date;
      final afterStart = date.isAfter(
        _startDate.subtract(const Duration(days: 1)),
      );
      final beforeEnd = date.isBefore(_endDate.add(const Duration(days: 1)));
      if (!afterStart || !beforeEnd) return false;

      // Payment Status Filter
      if (_selectedFilter == 'Paid') {
        if (bill.paidAmount < bill.grandTotal) return false;
      }
      if (_selectedFilter == 'Unpaid') {
        if (bill.paidAmount >= bill.grandTotal) return false;
      }

      // Search (Supplier Name or Bill Number)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return bill.supplierName.toLowerCase().contains(q) ||
            bill.billNumber.toLowerCase().contains(q);
      }

      return true;
    }).toList();

    // Sort by date desc
    _filteredBills.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.orange,
            colorScheme: const ColorScheme.light(primary: Colors.orange),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'Purchase Report',
      subtitle:
          '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
      actions: [
        DesktopIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Select Date Range',
          onPressed: _selectDateRange,
        ),
        DesktopIconButton(
          icon: Icons.picture_as_pdf_outlined,
          tooltip: 'Export PDF',
          onPressed: _generatePdf,
        ),
      ],
      child: Column(
        children: [
          // Filter Bar
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterChip('All', isDark),
                _buildFilterChip('Paid', isDark),
                _buildFilterChip('Unpaid', isDark),
                const SizedBox(width: 16),
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    }),
                    // Ah, the previous code had _searchQuery as member but didn't actually update it via a controller or onChanged properly in the UI before?
                    // Wait, line 26: final String _searchQuery = ''; It was final in previous code code? No, line 26: final String _searchQuery = ''; which means it was never updated?
                    // Ah, I see line 352 in previous view_file? No, wait.
                    // Previous code:
                    // 26:   final String _searchQuery = '';
                    // It seems search was broken or I misread.
                    // I will make it a regular variable.
                    decoration: const InputDecoration(
                      hintText: 'Search Supplier or Bill...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBills.isEmpty
                ? _buildEmptyState(isDark)
                : EnterpriseTable<PurchaseBill>(
                    data: _filteredBills,
                    columns: [
                      EnterpriseTableColumn(
                        title: 'Date',
                        valueBuilder: (b) =>
                            DateFormat('dd MMM, hh:mm a').format(b.date),
                      ),
                      EnterpriseTableColumn(
                        title: 'Bill No',
                        valueBuilder: (b) => b.billNumber,
                      ),
                      EnterpriseTableColumn(
                        title: 'Supplier',
                        valueBuilder: (b) =>
                            b.supplierName.isEmpty ? 'Unknown' : b.supplierName,
                      ),
                      EnterpriseTableColumn(
                        title: 'Status',
                        valueBuilder: (b) =>
                            b.paidAmount >= b.grandTotal ? 'Paid' : 'Due',
                        widgetBuilder: (b) {
                          final isPaid = b.paidAmount >= b.grandTotal;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? FuturisticColors.paidBackground
                                  : FuturisticColors.unpaidBackground,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'DUE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? FuturisticColors.paid
                                    : FuturisticColors.unpaid,
                              ),
                            ),
                          );
                        },
                      ),
                      EnterpriseTableColumn(
                        title: 'Total',
                        valueBuilder: (b) => b.grandTotal,
                        isNumeric: true,
                        widgetBuilder: (b) => Text(
                          '₹${b.grandTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Summary Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total Purchase (${_filteredBills.length}): ',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${_calculateTotal()}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = label;
            _applyFilters();
          });
        }
      },
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.grey.shade100,
      selectedColor: Colors.orange,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            "No purchases found",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
          ),
        ],
      ),
    );
  }

  String _calculateTotal() {
    double total = _filteredBills.fold(0, (sum, bill) => sum + bill.grandTotal);
    return total.toStringAsFixed(0);
  }

  Future<void> _generatePdf() async {
    final pdfService = PdfService();
    final data = _filteredBills
        .map(
          (b) => {
            'label': '#${b.billNumber} ${b.supplierName}',
            'value': b.grandTotal,
          },
        )
        .toList();

    final bytes = await pdfService.generateReportPdf(
      "Purchase Report",
      data.cast<Map<String, dynamic>>(),
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
