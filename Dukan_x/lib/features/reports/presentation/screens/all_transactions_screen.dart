import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../models/expense.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../core/repository/expenses_repository.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AllTransactionsScreen extends ConsumerStatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  ConsumerState<AllTransactionsScreen> createState() =>
      _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends ConsumerState<AllTransactionsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _searchQuery = '';

  bool _isLoading = false;
  List<_LedgerItem> _items = [];

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

      // Fetch all data from local repositories in parallel
      final billsFuture = sl<BillsRepository>().watchAll(userId: ownerId).first;
      final purchFuture = sl<PurchaseRepository>()
          .watchAll(userId: ownerId)
          .first;
      final expFuture = sl<ExpensesRepository>()
          .watchAll(userId: ownerId)
          .first;

      final results = await Future.wait([billsFuture, purchFuture, expFuture]);

      final bills = results[0] as List<Bill>;
      final purchases = results[1] as List<PurchaseOrder>;
      final expenses = results[2] as List<Expense>;

      final ledger = <_LedgerItem>[];

      // Process Sales (Credit)
      for (var b in bills) {
        if (!_isInRange(b.date)) continue;
        ledger.add(
          _LedgerItem(
            date: b.date,
            type: 'Sale',
            refNo: b.invoiceNumber,
            party: b.customerName,
            debit: 0,
            credit: b.grandTotal,
          ),
        );
      }

      // Process Purchases (Debit)
      for (var p in purchases) {
        if (!_isInRange(p.purchaseDate)) continue;
        ledger.add(
          _LedgerItem(
            date: p.purchaseDate,
            type: 'Purchase',
            refNo: p.invoiceNumber ?? '',
            party: p.vendorName ?? 'Unknown',
            debit: p.totalAmount,
            credit: 0,
          ),
        );
      }

      // Process Expenses (Debit)
      for (var e in expenses) {
        if (!_isInRange(e.date)) continue;
        ledger.add(
          _LedgerItem(
            date: e.date,
            type: 'Expense',
            refNo: '-',
            party: e.category,
            debit: e.amount,
            credit: 0,
          ),
        );
      }

      // Sort by date descending
      ledger.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _items = ledger;
        });
      }
    } catch (e) {
      debugPrint("Error loading ledger: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isInRange(DateTime date) {
    return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(_endDate.add(const Duration(days: 1)));
  }

  List<_LedgerItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items
        .where(
          (i) =>
              i.party.toLowerCase().contains(q) ||
              i.refNo.toLowerCase().contains(q) ||
              i.type.toLowerCase().contains(q),
        )
        .toList();
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
            primaryColor: Colors.teal,
            colorScheme: const ColorScheme.light(primary: Colors.teal),
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
        _fetchData(); // Refetch/Re-filter
      });
    }
  }

  Future<void> _exportToPdf(
    BuildContext context,
    List<_LedgerItem> items,
    bool isDark,
  ) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Calculate totals
      final totalDebit = items.fold(0.0, (sum, i) => sum + i.debit);
      final totalCredit = items.fold(0.0, (sum, i) => sum + i.credit);

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(
            responsiveValue<double>(
              context,
              mobile: 16,
              tablet: 20,
              desktop: 32, // PRESERVED: Desktop uses exactly 32 as before
            ),
          ),
          header: (pw.Context pdfContext) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'All Transactions Report',
                style: pw.TextStyle(
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (pw.Context pdfContext) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${pdfContext.pageNumber} of ${pdfContext.pagesCount}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          build: (pw.Context pdfContext) => [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Type', 'Ref No', 'Party', 'Debit', 'Credit'],
              data: items
                  .map(
                    (item) => [
                      DateFormat('dd-MM-yyyy').format(item.date),
                      item.type,
                      item.refNo,
                      item.party,
                      item.debit > 0
                          ? '₹${item.debit.toStringAsFixed(0)}'
                          : '-',
                      item.credit > 0
                          ? '₹${item.credit.toStringAsFixed(0)}'
                          : '-',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Debit: ₹${totalDebit.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Total Credit: ₹${totalCredit.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      Navigator.pop(context); // Close loading

      // Show print/share dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final filtered = _filteredItems;

    return DesktopContentContainer(
      title: 'All Transactions',
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
          onPressed: () => _exportToPdf(context, filtered, isDark),
        ),
      ],
      child: Column(
        children: [
          // Search Bar
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search Party, Ref No...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Ledger Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : EnterpriseTable<_LedgerItem>(
                    data: filtered,
                    columns: [
                      EnterpriseTableColumn(
                        title: 'Date',
                        valueBuilder: (i) =>
                            DateFormat('dd-MMM').format(i.date),
                      ),
                      EnterpriseTableColumn(
                        title: 'Type',
                        valueBuilder: (i) => i.type,
                        widgetBuilder: (i) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(i.type).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            i.type,
                            style: TextStyle(
                              color: _getTypeColor(i.type),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      EnterpriseTableColumn(
                        title: 'Ref No',
                        valueBuilder: (i) => i.refNo,
                      ),
                      EnterpriseTableColumn(
                        title: 'Party',
                        valueBuilder: (i) => i.party,
                      ),
                      EnterpriseTableColumn(
                        title: 'Debit',
                        valueBuilder: (i) => i.debit,
                        isNumeric: true,
                        widgetBuilder: (i) => Text(
                          i.debit > 0 ? '₹${i.debit.toStringAsFixed(0)}' : '-',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      EnterpriseTableColumn(
                        title: 'Credit',
                        valueBuilder: (i) => i.credit,
                        isNumeric: true,
                        widgetBuilder: (i) => Text(
                          i.credit > 0
                              ? '₹${i.credit.toStringAsFixed(0)}'
                              : '-',
                          style: const TextStyle(
                            color: FuturisticColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Sale':
        return FuturisticColors.success;
      case 'Purchase':
        return Colors.orange;
      case 'Expense':
        return FuturisticColors.error;
      default:
        return Colors.grey;
    }
  }
}

class _LedgerItem {
  final DateTime date;
  final String type;
  final String refNo;
  final String party;
  final double debit;
  final double credit;

  _LedgerItem({
    required this.date,
    required this.type,
    required this.refNo,
    required this.party,
    required this.debit,
    required this.credit,
  });
}
