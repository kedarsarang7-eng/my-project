// ============================================================================
// FEE STATEMENT SCREEN - Phase 1.4
// ============================================================================
// Generate fee collection statements for School ERP and Clinic
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

class FeeStatementScreen extends ConsumerStatefulWidget {
  final String? studentId;
  final String? studentName;
  final String? patientId;
  final String? patientName;
  final bool isAcademic;

  const FeeStatementScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.patientId,
    this.patientName,
    this.isAcademic = true,
  });

  @override
  ConsumerState<FeeStatementScreen> createState() => _FeeStatementScreenState();
}

class _FeeStatementScreenState extends ConsumerState<FeeStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();
  final PdfService _pdfService = sl<PdfService>();

  bool _isLoading = true;
  FeeStatement? _statement;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 90));
    _endDate = DateTime.now();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateFeeStatement(
        studentId: widget.studentId,
        patientId: widget.patientId,
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
      final partyName = widget.isAcademic
          ? (widget.studentName ?? 'All Students')
          : (widget.patientName ?? 'All Patients');
      
      final pdfBytes = await _pdfService.generateFeeStatementPdf(
        title: widget.isAcademic ? 'Fee Collection Statement' : 'Billing Statement',
        businessName: sl<SessionManager>().currentSession.displayName ?? 'Business',
        generatedAt: _statement!.generatedAt,
        partyName: partyName,
        period: '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
        summary: {
          'Total Collected': _formatCurrency(_statement!.totalCollected),
          'Total Pending': _formatCurrency(_statement!.totalPending),
          'Total Entries': _statement!.totalEntries.toString(),
        },
        entries: _statement!.entries.map((e) => {
          'receipt_number': e.receiptNumber,
          'payer_name': e.payerName,
          'amount': _formatCurrency(e.amount),
          'description': e.description,
          'payment_mode': e.paymentMode,
          'date': _formatDate(e.date),
          'reference': e.reference ?? '-',
        }).toList(),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'FeeStatement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
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
    final title = widget.isAcademic ? 'Fee Statement' : 'Billing Statement';
    final subtitle = widget.isAcademic
        ? (widget.studentName ?? 'All Students')
        : (widget.patientName ?? 'All Patients');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
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
            onPressed: _statement != null && _statement!.entries.isNotEmpty ? _exportPdf : null,
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
    required DateTime? date,
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
              date != null ? _formatDate(date) : 'Select Date',
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
            widget.isAcademic ? 'No fee records found' : 'No billing records found',
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

          // Pending Alert
          if (_statement!.totalPending > 0) ...[
            _buildPendingAlert(isDark),
            const SizedBox(height: 24),
          ],

          // Collection Statistics
          _buildCollectionStats(isDark),

          const SizedBox(height: 24),

          // Fee Entries Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isAcademic ? 'Fee Collection Details' : 'Billing Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} entries',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fee Entries
          ..._statement!.entries.map((entry) => _buildFeeEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context,
        mobile: 1,
        tablet: 2,
        desktop: 2,  // PRESERVED: Desktop uses exactly 2 columns as before
      ),
      childAspectRatio: responsiveValue<double>(context,
        mobile: 2.0,
        tablet: 1.3,
        desktop: 1.3,  // PRESERVED: Desktop uses exactly 1.3 aspect ratio as before
      ),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total Collected',
          _formatCurrency(_statement!.totalCollected),
          '${_statement!.totalEntries} transactions',
          Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Total Pending',
          _formatCurrency(_statement!.totalPending),
          'Outstanding amount',
          _statement!.totalPending > 0 ? Colors.orange : Colors.grey,
          isDark,
        ),
        _buildSummaryCard(
          'Net Position',
          _formatCurrency(_statement!.totalCollected - _statement!.totalPending),
          'Collected - Pending',
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Collection Rate',
          '${_calculateCollectionRate().toStringAsFixed(1)}%',
          'Of total dues',
          _calculateCollectionRate() >= 80 ? Colors.green : Colors.orange,
          isDark,
        ),
      ],
    );
  }

  double _calculateCollectionRate() {
    final total = _statement!.totalCollected + _statement!.totalPending;
    return total > 0 ? (_statement!.totalCollected / total) * 100 : 0;
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String subtitle,
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
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Amount Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${_formatCurrency(_statement!.totalPending)} pending collection',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionStats(bool isDark) {
    // Group entries by payment mode
    final Map<String, double> modeTotals = {};
    for (final entry in _statement!.entries) {
      modeTotals[entry.paymentMode] = (modeTotals[entry.paymentMode] ?? 0) + entry.amount;
    }

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Mode Breakdown',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...modeTotals.entries.map((entry) => _buildPaymentModeRow(
            entry.key,
            entry.value,
            _statement!.totalCollected,
            isDark,
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentModeRow(String mode, double amount, double total, bool isDark) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  _getPaymentIcon(mode),
                  size: 16,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  mode,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FuturisticColors.primary.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'CASH':
        return Icons.money;
      case 'ONLINE':
      case 'UPI':
        return Icons.qr_code;
      case 'CARD':
        return Icons.credit_card;
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      case 'CHEQUE':
        return Icons.edit;
      default:
        return Icons.payment;
    }
  }

  Widget _buildFeeEntry(FeeEntry entry, bool isDark) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getPaymentIcon(entry.paymentMode),
            color: FuturisticColors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.payerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              _formatCurrency(entry.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              entry.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.paymentMode,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
                if (entry.reference != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Ref: ${entry.reference}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ],
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
