// ============================================================================
// CUSTOMER INVOICE STATEMENT SCREEN - Phase 1.1
// ============================================================================
// Generate comprehensive invoice statements for customers with real data
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/statements_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerInvoiceStatementScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final String? customerPhone;

  const CustomerInvoiceStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  @override
  ConsumerState<CustomerInvoiceStatementScreen> createState() =>
      _CustomerInvoiceStatementScreenState();
}

class _CustomerInvoiceStatementScreenState
    extends ConsumerState<CustomerInvoiceStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();
  final PdfService _pdfService = sl<PdfService>();
  
  bool _isLoading = true;
  CustomerInvoiceStatement? _statement;
  String? _error;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateCustomerInvoiceStatement(
        customerId: widget.customerId,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _statement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_statement == null) return;

    try {
      final pdfBytes = await _pdfService.generateStatementPdf(
        title: 'Customer Invoice Statement',
        businessName: sl<SessionManager>().currentSession.displayName ?? 'Business',
        businessAddress: '',
        partyName: _statement!.customerName,
        partyDetails: _buildPartyDetails(),
        period: 'Period: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
        summary: _buildSummaryData(),
        aging: _buildAgingData(),
        entries: _buildEntriesData(),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Statement_${_statement!.customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  String _buildPartyDetails() {
    final parts = <String>[];
    if (_statement!.customerPhone != null) parts.add('Phone: ${_statement!.customerPhone}');
    if (_statement!.customerAddress != null && _statement!.customerAddress!.isNotEmpty) {
      parts.add('Address: ${_statement!.customerAddress}');
    }
    if (_statement!.gstin != null && _statement!.gstin!.isNotEmpty) {
      parts.add('GSTIN: ${_statement!.gstin}');
    }
    return parts.join('\n');
  }

  Map<String, dynamic> _buildSummaryData() {
    return {
      'Opening Balance': _formatCurrency(_statement!.openingBalance),
      'Total Sales': _formatCurrency(_statement!.totalSales),
      'Total Paid': _formatCurrency(_statement!.totalPaid),
      'Total Due': _formatCurrency(_statement!.totalDue),
      'Closing Balance': _formatCurrency(_statement!.closingBalance),
    };
  }

  Map<String, dynamic> _buildAgingData() {
    return {
      'Current': _formatCurrency(_statement!.aging.current),
      '1-30 Days': _formatCurrency(_statement!.aging.days1To30),
      '31-60 Days': _formatCurrency(_statement!.aging.days31To60),
      '61-90 Days': _formatCurrency(_statement!.aging.days61To90),
      '90+ Days': _formatCurrency(_statement!.aging.days90Plus),
    };
  }

  List<Map<String, dynamic>> _buildEntriesData() {
    return _statement!.entries.map((e) => {
      'Date': _formatDate(e.date),
      'Invoice #': e.invoiceNumber,
      'Amount': _formatCurrency(e.amount),
      'Paid': _formatCurrency(e.paidAmount),
      'Balance': _formatCurrency(e.balance),
      'Running Balance': _formatCurrency(e.runningBalance),
    }).toList();
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
      _loadStatement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.customerName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _statement != null ? _exportPdf : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Date Filter Bar
          _buildDateFilterBar(isDark),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _statement == null || _statement!.entries.isEmpty
                        ? _buildEmptyState()
                        : _buildStatementContent(isDark),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDateFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDateButton(
              label: 'From',
              date: _startDate,
              onTap: () => _pickDate(true),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.arrow_forward,
            color: isDark ? Colors.white60 : Colors.grey,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildDateButton(
              label: 'To',
              date: _endDate,
              onTap: () => _pickDate(false),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
                _formatDate(date),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading statement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadStatement,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No invoices found for this period',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different date range',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(isDark),
          
          const SizedBox(height: 24),
          
          // Aging Analysis
          _buildAgingAnalysis(isDark),
          
          const SizedBox(height: 24),
          
          // Invoice List Header
          Text(
            'Invoice Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          
          // Invoice Entries
          ..._statement!.entries.map((entry) => _buildInvoiceEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Opening Balance',
          _formatCurrency(_statement!.openingBalance),
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Total Sales',
          _formatCurrency(_statement!.totalSales),
          Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Total Paid',
          _formatCurrency(_statement!.totalPaid),
          Colors.orange,
          isDark,
        ),
        _buildSummaryCard(
          'Closing Balance',
          _formatCurrency(_statement!.closingBalance),
          _statement!.closingBalance > 0 ? Colors.red : Colors.green,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingAnalysis(bool isDark) {
    final aging = _statement!.aging;
    
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aging Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Total: ${_formatCurrency(aging.totalOutstanding)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAgingRow('Current', aging.current, Colors.green, aging.totalOutstanding),
          _buildAgingRow('1-30 Days', aging.days1To30, Colors.orange, aging.totalOutstanding),
          _buildAgingRow('31-60 Days', aging.days31To60, Colors.deepOrange, aging.totalOutstanding),
          _buildAgingRow('61-90 Days', aging.days61To90, Colors.red.shade400, aging.totalOutstanding),
          _buildAgingRow('90+ Days', aging.days90Plus, Colors.red, aging.totalOutstanding),
        ],
      ),
    );
  }

  Widget _buildAgingRow(String label, double amount, Color color, double total) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceEntry(InvoiceStatementEntry entry, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade200,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #${entry.invoiceNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatDate(entry.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(entry.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(entry.status),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text(
                'Paid: ${_formatCurrency(entry.paidAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Balance: ${_formatCurrency(entry.balance)}',
                style: TextStyle(
                  fontSize: 12,
                  color: entry.balance > 0 ? Colors.red.shade600 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        children: [
          if (entry.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Items:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entry.items.map((item) => _buildItemRow(item, isDark)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BillItemDetail item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.quantity.toStringAsFixed(0)} ${item.unit ?? 'pcs'}',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(item.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PAID':
        color = Colors.green;
        break;
      case 'PARTIAL':
        color = Colors.orange;
        break;
      case 'PENDING':
        color = Colors.blue;
        break;
      case 'OVERDUE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
