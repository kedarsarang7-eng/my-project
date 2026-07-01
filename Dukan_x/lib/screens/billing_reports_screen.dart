import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; // For PDF export
import 'package:dukanx/core/compat/firebase_auth_compat.dart'; // For User ID

import '../core/di/service_locator.dart';
import '../core/repository/bills_repository.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/glass_morphism.dart';
import '../widgets/modern_ui_components.dart';
import '../services/pdf_service.dart';
import '../providers/app_state_providers.dart';
import 'advanced_bill_creation_screen.dart';

class BillingReportsScreen extends ConsumerStatefulWidget {
  const BillingReportsScreen({super.key});

  @override
  ConsumerState<BillingReportsScreen> createState() =>
      _BillingReportsScreenState();
}

class _BillingReportsScreenState extends ConsumerState<BillingReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _selectedFilter = 'All'; // All, Cash, Online, Udhar
  final String _searchQuery = '';

  bool _isLoading = false;
  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = FirebaseAuth.instance.currentUser?.uid;
      if (ownerId == null) return;

      final result = await sl<BillsRepository>().getAll(userId: ownerId);

      if (mounted) {
        if (result.isSuccess) {
          setState(() {
            _allBills = result.data ?? [];
            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading bills: $e");
    } finally {
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

      // Type Filter
      if (_selectedFilter == 'Cash' && bill.paymentType != 'Cash') return false;
      if (_selectedFilter == 'Online' && bill.paymentType != 'Online') {
        return false;
      }
      if (_selectedFilter == 'Credit') {
        if (bill.status == 'Paid') return false;
      }

      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return bill.customerName.toLowerCase().contains(q) ||
            bill.invoiceNumber.toLowerCase().contains(q);
      }

      return true;
    }).toList();

    _filteredBills.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _selectDateRange() async {
    final theme = ref.read(themeStateProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: theme.isDark ? ThemeData.dark() : ThemeData.light(),
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
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Turnover Analysis',
          style: AppTypography.headlineMedium.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: FuturisticColors.primary,
            ),
            onPressed: _generatePdf,
          ),
          IconButton(
            icon: Icon(Icons.share, color: FuturisticColors.success),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdvancedBillCreationScreen(),
            ),
          ).then((_) => _fetchBills());
        },
        backgroundColor: FuturisticColors.primary,
        icon: const Icon(Icons.add),
        label: const Text("New Bill"),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FuturisticColors.darkBackgroundGradient
              : FuturisticColors.lightBackgroundGradient,
        ),
        child: SafeArea(
          child: ResponsiveContainer(
          child: Column(
            children: [
              // Filter Bar (Glass)
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date Selector
                      InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white70 : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('Cash', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('Online', isDark),
                            const SizedBox(width: 8),
                            _buildFilterChip('Credit', isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBills.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notes_rounded,
                        title: "No revenue records",
                        description: "Try adjusting your filters or date range",
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredBills.length,
                        itemBuilder: (context, index) {
                          return _buildBillCard(_filteredBills[index], isDark);
                        },
                      ),
              ),

              // Total Summary Sticky Footer
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Revenue (${_filteredBills.length})',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      '₹${_calculateTotal()}',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
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
      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
      selectedColor: FuturisticColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildBillCard(Bill bill, bool isDark) {
    // Determine status color safely
    final isCash = bill.paymentType == 'Cash';
    Color statusColor = FuturisticColors.textMuted;

    if (isCash) {
      statusColor = FuturisticColors.success;
    } else if (bill.paymentType == 'Online') {
      statusColor = FuturisticColors.accent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdvancedBillCreationScreen(editingBill: bill),
            ),
          ).then((_) => _fetchBills());
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FuturisticColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: FuturisticColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.customerName.isEmpty ? 'Unknown' : bill.customerName,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${bill.invoiceNumber} • ${DateFormat('dd MMM, hh:mm a').format(bill.date)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${bill.grandTotal.toStringAsFixed(0)}',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bill.paymentType.isEmpty ? 'Unknown' : bill.paymentType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _calculateTotal() {
    double total = _filteredBills.fold(0, (sum, bill) => sum + bill.grandTotal);
    return total.toStringAsFixed(0);
  }

  Future<void> _generatePdf() async {
    final pdfService = PdfService();
    // Generate basic report PDF
    final data = _filteredBills
        .map(
          (b) => {
            'label': '#${b.invoiceNumber} ${b.customerName}',
            'value': b.grandTotal,
          },
        )
        .toList();

    final bytes = await pdfService.generateReportPdf(
      "Turnover Analysis",
      data.cast<Map<String, dynamic>>(),
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
