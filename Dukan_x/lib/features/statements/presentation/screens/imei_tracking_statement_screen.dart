// ============================================================================
// IMEI TRACKING STATEMENT SCREEN - Phase 2.2
// ============================================================================
// IMEI/Serial number tracking for Electronics/Mobile/Computer Shop
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/statements_service.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ImeiTrackingStatementScreen extends ConsumerStatefulWidget {
  final String? productId;
  final String? productName;

  const ImeiTrackingStatementScreen({
    super.key,
    this.productId,
    this.productName,
  });

  @override
  ConsumerState<ImeiTrackingStatementScreen> createState() =>
      _ImeiTrackingStatementScreenState();
}

class _ImeiTrackingStatementScreenState
    extends ConsumerState<ImeiTrackingStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();

  bool _isLoading = true;
  ImeiTrackingStatement? _statement;
  String? _error;

  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _statusOptions = ['All', 'IN_STOCK', 'SOLD', 'RETURNED', 'DAMAGED'];

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
      final statement = await _statementsService.generateImeiTrackingStatement(
        productId: widget.productId,
        startDate: _startDate,
        endDate: _endDate,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
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
              'IMEI Tracking Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.productName != null)
              Text(
                widget.productName!,
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
            onPressed: _statement != null && _statement!.entries.isNotEmpty ? () {} : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          _buildFilterBar(isDark),
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
        border: Border(bottom: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedStatus ?? 'All',
                  hint: const Text('All Status'),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value == 'All' ? null : value;
                    });
                    _loadStatement();
                  },
                  items: _statusOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                ),
              ),
            ),
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
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading statement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStatement, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smartphone_outlined, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('No IMEI records found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).disabledColor),
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
          _buildStatusCards(isDark),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IMEI/Serial Records',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} records',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._statement!.entries.map((entry) => _buildImeiEntry(entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatusCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 2),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard('Total Records', '${_statement!.totalRecords}', '', Colors.blue, isDark),
        _buildSummaryCard('In Stock', '${_statement!.inStockCount}', 'Available', Colors.green, isDark),
        _buildSummaryCard('Sold', '${_statement!.soldCount}', 'Completed', Colors.purple, isDark),
        _buildSummaryCard('Issues', '${_statement!.returnedCount + _statement!.damagedCount}', 'Attention needed', Colors.orange, isDark),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, String subtitle, Color color, bool isDark) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24), fontWeight: FontWeight.bold, color: color)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildImeiEntry(ImeiTrackingEntry entry, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    switch (entry.status) {
      case 'IN_STOCK':
        statusColor = Colors.green;
        statusIcon = Icons.inventory_2;
        break;
      case 'SOLD':
        statusColor = Colors.purple;
        statusIcon = Icons.check_circle;
        break;
      case 'RETURNED':
        statusColor = Colors.orange;
        statusIcon = Icons.assignment_return;
        break;
      case 'DAMAGED':
        statusColor = Colors.red;
        statusIcon = Icons.broken_image;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (entry.imeiNumber != null)
                    Text('IMEI: ${entry.imeiNumber}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600)),
                  if (entry.serialNumber != null)
                    Text('S/N: ${entry.serialNumber}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.status.replaceAll('_', ' '),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: entry.soldDate != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sold: ${_formatDate(entry.soldDate!)}${entry.customerName != null ? ' to ${entry.customerName}' : ''}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (entry.billNumber != null)
                  _buildDetailRow('Invoice', entry.billNumber!, isDark),
                if (entry.purchasePrice != null)
                  _buildDetailRow('Purchase Price', _formatCurrency(entry.purchasePrice!), isDark),
                if (entry.soldPrice != null)
                  _buildDetailRow('Sold Price', _formatCurrency(entry.soldPrice!), isDark),
                if (entry.purchaseDate != null)
                  _buildDetailRow('Stock Date', _formatDate(entry.purchaseDate!), isDark),
                if (entry.warrantyExpiry != null)
                  _buildDetailRow(
                    'Warranty',
                    entry.warrantyExpiry!.isBefore(DateTime.now()) ? 'Expired' : 'Valid until ${_formatDate(entry.warrantyExpiry!)}',
                    isDark,
                    valueColor: entry.warrantyExpiry!.isBefore(DateTime.now()) ? Colors.red : Colors.green,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey.shade600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
