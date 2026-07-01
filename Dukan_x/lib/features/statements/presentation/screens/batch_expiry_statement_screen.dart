// ============================================================================
// BATCH/EXPIRY STATEMENT SCREEN - Phase 2.1
// ============================================================================
// Batch and expiry tracking for Grocery/Pharmacy
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

class BatchExpiryStatementScreen extends ConsumerStatefulWidget {
  final String? productId;
  final String? productName;

  const BatchExpiryStatementScreen({
    super.key,
    this.productId,
    this.productName,
  });

  @override
  ConsumerState<BatchExpiryStatementScreen> createState() =>
      _BatchExpiryStatementScreenState();
}

class _BatchExpiryStatementScreenState
    extends ConsumerState<BatchExpiryStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();

  bool _isLoading = true;
  BatchExpiryStatement? _statement;
  String? _error;

  String _selectedFilter = 'All';

  final List<String> _filterOptions = ['All', 'Expired', 'Expiring 7 Days', 'Expiring 30 Days'];

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
      bool expiredOnly = _selectedFilter == 'Expired';
      bool expiringSoon = _selectedFilter == 'Expiring 7 Days' || _selectedFilter == 'Expiring 30 Days';
      DateTime? expiryBefore = expiringSoon ? DateTime.now().add(Duration(days: _selectedFilter == 'Expiring 7 Days' ? 7 : 30)) : null;

      final statement = await _statementsService.generateBatchExpiryStatement(
        productId: widget.productId,
        expiryBefore: expiryBefore,
        expiredOnly: expiredOnly,
        expiringSoon: expiringSoon,
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
              'Batch/Expiry Statement',
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
            onPressed: _statement != null && _statement!.entries.isNotEmpty ? _exportPdf : null,
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
                  value: _selectedFilter,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    _loadStatement();
                  },
                  items: _filterOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
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
          Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('No batch records found', style: Theme.of(context).textTheme.titleMedium),
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
          _buildExpiryDistribution(isDark),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} batches',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._statement!.entries.map((entry) => _buildBatchEntry(entry, isDark)),
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
        _buildSummaryCard('Total Batches', '${_statement!.totalBatches}', '', Colors.blue, isDark),
        _buildSummaryCard('Expired', '${_statement!.expiredCount}', 'Needs disposal', Colors.red, isDark),
        _buildSummaryCard('Expiring <7 Days', '${_statement!.expiring7DaysCount}', 'Urgent', Colors.orange, isDark),
        _buildSummaryCard('Expiring <30 Days', '${_statement!.expiring30DaysCount}', 'Attention', Colors.yellow.shade700, isDark),
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

  Widget _buildExpiryDistribution(bool isDark) {
    final total = _statement!.totalBatches;
    if (total == 0) return const SizedBox.shrink();

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expiry Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildDistributionBar('Expired', _statement!.expiredCount, total, Colors.red),
          _buildDistributionBar('Expiring <7 Days', _statement!.expiring7DaysCount, total, Colors.orange),
          _buildDistributionBar('Expiring <30 Days', _statement!.expiring30DaysCount, total, Colors.yellow.shade700),
          _buildDistributionBar('Valid', _statement!.validCount, total, Colors.green),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(String label, int count, int total, Color color) {
    final percent = total > 0 ? (count / total) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$count (${percent.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBatchEntry(BatchExpiryEntry entry, bool isDark) {
    final isExpired = entry.status == 'EXPIRED';
    final isExpiring7Days = entry.status == 'EXPIRING_7_DAYS';
    final isExpiring30Days = entry.status == 'EXPIRING_30_DAYS';

    Color statusColor;
    if (isExpired) {
      statusColor = Colors.red;
    } else if (isExpiring7Days) {
      statusColor = Colors.orange;
    } else if (isExpiring30Days) {
      statusColor = Colors.yellow.shade700;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(
            isExpired ? Icons.warning : Icons.calendar_today,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Batch: ${entry.batchNumber}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600)),
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expires: ${_formatDate(entry.expiryDate)}', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                    Text(
                      '${entry.quantity.toStringAsFixed(0)} units • ${_formatCurrency(entry.stockValue)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.daysUntilExpiry < 0 
                        ? '${entry.daysUntilExpiry.abs()} days ago' 
                        : '${entry.daysUntilExpiry} days left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_statement == null) return;
    // PDF export implementation
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
