// ============================================================================
// FUEL SALES STATEMENT SCREEN - Phase 1.5
// ============================================================================
// Generate fuel sales statements for petrol pump businesses
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

class FuelSalesStatementScreen extends ConsumerStatefulWidget {
  final String? fuelType;
  final String? nozzleId;

  const FuelSalesStatementScreen({
    super.key,
    this.fuelType,
    this.nozzleId,
  });

  @override
  ConsumerState<FuelSalesStatementScreen> createState() =>
      _FuelSalesStatementScreenState();
}

class _FuelSalesStatementScreenState
    extends ConsumerState<FuelSalesStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();
  final PdfService _pdfService = sl<PdfService>();

  bool _isLoading = true;
  FuelSalesStatement? _statement;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedFuelType;
  String? _selectedNozzle;

  final List<String> _fuelTypes = ['All', 'Petrol', 'Diesel', 'Premium'];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();
    _selectedFuelType = widget.fuelType ?? 'All';
    _selectedNozzle = widget.nozzleId;
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateFuelSalesStatement(
        startDate: _startDate,
        endDate: _endDate,
        fuelType: _selectedFuelType == 'All' ? null : _selectedFuelType,
        nozzleId: _selectedNozzle,
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
      final pdfBytes = await _pdfService.generateFuelSalesPdf(
        title: 'Fuel Sales Statement',
        businessName: sl<SessionManager>().currentSession.displayName ?? 'Petrol Pump',
        generatedAt: _statement!.generatedAt,
        period: '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
        summary: {
          'Total Sales': _formatCurrency(_statement!.totalAmount),
          'Total Volume': '${_statement!.totalVolume.toStringAsFixed(2)} L',
          'Avg Rate': _formatCurrency(_statement!.averageRate),
          'Transactions': _statement!.totalTransactions.toString(),
        },
        fuelTypeSummary: _statement!.fuelTypeSummary.map((f) => {
          'fuel_type': f.fuelType,
          'volume': '${f.totalVolume.toStringAsFixed(2)} L',
          'amount': _formatCurrency(f.totalAmount),
          'transactions': f.transactionCount.toString(),
          'avg_rate': f.totalVolume > 0 
              ? _formatCurrency(f.totalAmount / f.totalVolume) 
              : '₹0.00',
        }).toList(),
        entries: _statement!.entries.map((e) => {
          'invoice_number': e.invoiceNumber,
          'date': _formatDate(e.date),
          'fuel_type': e.fuelType,
          'nozzle_id': e.nozzleId ?? '-',
          'vehicle_number': e.vehicleNumber ?? '-',
          'volume': '${e.volume.toStringAsFixed(2)} L',
          'rate': _formatCurrency(e.rate),
          'amount': _formatCurrency(e.amount),
          'payment_mode': e.paymentMode,
        }).toList(),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'FuelSales_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fuel Sales Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Sales analysis & reporting',
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
          // Filter Bar
          _buildFilterBar(isDark),

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

  Widget _buildFilterBar(bool isDark) {
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'From',
                  date: _startDate,
                  onTap: () => _pickDate(true),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward,
                color: isDark ? Colors.white60 : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFuelTypeDropdown(isDark),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadStatement,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
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

  Widget _buildFuelTypeDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedFuelType,
          hint: Text(
            'All Fuel Types',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (value) {
            setState(() {
              _selectedFuelType = value;
            });
            _loadStatement();
          },
          items: _fuelTypes.map((fuelType) => DropdownMenuItem(
            value: fuelType,
            child: Text(fuelType),
          )).toList(),
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
            Icons.local_gas_station_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No fuel sales found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the filters or date range',
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

          // Fuel Type Breakdown
          _buildFuelTypeBreakdown(isDark),

          const SizedBox(height: 24),

          // Sales Entries Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} transactions',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sales Entries
          ..._statement!.entries.map((entry) => _buildSalesEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total Sales',
          _formatCurrency(_statement!.totalAmount),
          '${_statement!.totalTransactions} transactions',
          Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Total Volume',
          '${_statement!.totalVolume.toStringAsFixed(2)} L',
          'Fuel dispensed',
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Average Rate',
          _formatCurrency(_statement!.averageRate),
          'Per liter',
          Colors.orange,
          isDark,
        ),
        _buildSummaryCard(
          'Fuel Types',
          '${_statement!.fuelTypeSummary.length}',
          'Active fuels',
          Colors.purple,
          isDark,
        ),
      ],
    );
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

  Widget _buildFuelTypeBreakdown(bool isDark) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fuel Type Breakdown',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ..._statement!.fuelTypeSummary.map((fuel) => _buildFuelTypeRow(fuel, isDark)),
        ],
      ),
    );
  }

  Widget _buildFuelTypeRow(FuelTypeSummary fuel, bool isDark) {
    final totalVolume = _statement!.totalVolume;
    final volumePercent = totalVolume > 0 ? (fuel.totalVolume / totalVolume) * 100 : 0;
    final avgRate = fuel.totalVolume > 0 ? (fuel.totalAmount / fuel.totalVolume).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getFuelColor(fuel.fuelType).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: _getFuelColor(fuel.fuelType),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fuel.fuelType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '${fuel.transactionCount} sales',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: volumePercent / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getFuelColor(fuel.fuelType),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${volumePercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${fuel.totalVolume.toStringAsFixed(2)} L',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              Text(
                _formatCurrency(fuel.totalAmount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '@ ${_formatCurrency(avgRate)}/L',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getFuelColor(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
      case 'gasoline':
        return Colors.red;
      case 'diesel':
        return Colors.orange;
      case 'premium':
      case 'power':
        return Colors.green;
      case 'cng':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSalesEntry(FuelSalesEntry entry, bool isDark) {
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
            color: _getFuelColor(entry.fuelType).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_gas_station,
            color: _getFuelColor(entry.fuelType),
            size: 20,
          ),
        ),
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
                    entry.fuelType,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getFuelColor(entry.fuelType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.volume.toStringAsFixed(2)} L @ ${_formatCurrency(entry.rate)}/L',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (entry.nozzleId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Nozzle: ${entry.nozzleId}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _formatDate(entry.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (entry.vehicleNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.vehicleNumber!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
