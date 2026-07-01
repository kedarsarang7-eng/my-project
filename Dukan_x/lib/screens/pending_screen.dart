import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/di/service_locator.dart';
import '../core/repository/customers_repository.dart';
import '../core/session/session_manager.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/ui/smart_table.dart';
import '../widgets/ui/quick_action_toolbar.dart';
import '../widgets/ui/futuristic_button.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  Customer? _selectedCustomer;
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await sl<CustomersRepository>().getAll(userId: ownerId);
    if (result.success && result.data != null) {
      final pending = result.data!.where((c) => c.totalDues > 0).toList();
      // Sort by highest due descending
      pending.sort((a, b) => b.totalDues.compareTo(a.totalDues));
      setState(() {
        _customers = pending;
        _filteredCustomers = pending;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCustomers = _customers);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredCustomers = _customers
          .where(
            (c) =>
                c.name.toLowerCase().contains(lower) ||
                (c.phone != null && c.phone!.contains(query)),
          )
          .toList();
    });
  }

  void _onRowClick(Customer customer) {
    setState(() => _selectedCustomer = customer);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FuturisticColors.background,
      endDrawer: _buildDetailsDrawer(),
      body: ResponsiveContainer(
        child: Column(
          children: [
            QuickActionToolbar(
            title: 'Customer Dues Monitor',
            searchField: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search by Name or Phone (F2)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: FuturisticColors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            actions: [
              FuturisticButton.primary(
                label: 'Refresh',
                icon: Icons.refresh,
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              FuturisticButton.secondary(
                label: 'Export Report',
                icon: Icons.download_rounded,
                onPressed: _exportOutstandingReportToPdf,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SmartTable<Customer>(
                isLoading: _isLoading,
                emptyMessage: 'No pending dues found. Good job!',
                data: _filteredCustomers,
                onRowClick: _onRowClick,
                columns: [
                  SmartTableColumn(
                    title: 'Customer Name',
                    flex: 2,
                    valueMapper: (c) => c.name,
                  ),
                  SmartTableColumn(
                    title: 'Phone Number',
                    flex: 1,
                    valueMapper: (c) => c.phone ?? 'N/A',
                  ),
                  SmartTableColumn(
                    title: 'Last Activity',
                    flex: 1,
                    valueMapper: (c) {
                      if (c.lastTransactionDate == null) return 'N/A';
                      return DateFormat('dd-MM-yyyy').format(c.lastTransactionDate!);
                    },
                  ),
                  SmartTableColumn(
                    title: 'Total Due',
                    flex: 1,
                    builder: (c) => Text(
                      '₹${c.totalDues.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: FuturisticColors.error,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                  SmartTableColumn(
                    title: 'Status',
                    flex: 1,
                    builder: (c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: FuturisticColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: FuturisticColors.error.withOpacity(0.5),
                        ),
                      ),
                      child: const Text(
                        'OVERDUE',
                        style: TextStyle(
                          color: FuturisticColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildDetailsDrawer() {
    if (_selectedCustomer == null) return const SizedBox.shrink();

    return Drawer(
      width: 400,
      backgroundColor: FuturisticColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: FuturisticColors.surfaceHighlight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: FuturisticColors.primary,
                  child: Text(
                    _selectedCustomer!.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedCustomer!.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _selectedCustomer!.phone ?? 'No Phone',
                  style: const TextStyle(color: FuturisticColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Total Outstanding',
                  '₹${_selectedCustomer!.totalDues.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FuturisticButton.primary(
                  label: 'Send Payment Reminder',
                  icon: Icons.chat, // Corrected Icon
                  onPressed: () {
                    // Integrated WhatsApp Simulation
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('WhatsApp Reminder Sent!')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FuturisticButton.secondary(
                  label: 'Settle Balance',
                  icon: Icons.payments_outlined,
                  onPressed: () {
                    // Navigate to settlement simulation
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening Settlement Flow...'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                FuturisticButton.secondary(
                  label: 'View Full Ledger',
                  icon: Icons.history_edu,
                  onPressed: () {
                    // Navigate to ledger simulation
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening Customer Ledger...'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FuturisticColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? FuturisticColors.error
                : FuturisticColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _exportOutstandingReportToPdf() async {
    final pdf = pw.Document();
    
    final headers = ['Customer Name', 'Phone', 'Last Transaction', 'Total Dues'];
    final rows = _filteredCustomers.map((c) {
      final lastTxStr = c.lastTransactionDate != null
          ? DateFormat('dd-MM-yyyy').format(c.lastTransactionDate!)
          : 'N/A';
      return [
        c.name,
        c.phone ?? 'N/A',
        lastTxStr,
        '₹${c.totalDues.toStringAsFixed(2)}',
      ];
    }).toList();

    double grandTotal = _filteredCustomers.fold(0.0, (sum, c) => sum + c.totalDues);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Outstanding Customer Dues Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total Outstanding: ₹${grandTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
