// ============================================================================
// SERVICE JOB STATEMENT SCREEN - Phase 1.3
// ============================================================================
// Generate service/repair job statements with real job data
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

class ServiceJobStatementScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;

  const ServiceJobStatementScreen({
    super.key,
    this.customerId,
    this.customerName,
  });

  @override
  ConsumerState<ServiceJobStatementScreen> createState() =>
      _ServiceJobStatementScreenState();
}

class _ServiceJobStatementScreenState
    extends ConsumerState<ServiceJobStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();
  final PdfService _pdfService = sl<PdfService>();

  bool _isLoading = true;
  ServiceJobStatement? _statement;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;

  final List<String> _statusOptions = [
    'All',
    'PENDING',
    'IN_PROGRESS',
    'COMPLETED',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateServiceJobStatement(
        customerId: widget.customerId,
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

  Future<void> _exportPdf() async {
    if (_statement == null) return;

    try {
      final pdfBytes = await _pdfService.generateServiceJobPdf(
        title: 'Service Job Statement',
        businessName: sl<SessionManager>().currentSession.displayName ?? 'Business',
        generatedAt: _statement!.generatedAt,
        summary: {
          'Total Jobs': _statement!.totalJobs.toString(),
          'Pending Jobs': _statement!.pendingJobs.toString(),
          'Completed Jobs': _statement!.completedJobs.toString(),
          'Total Estimated': _formatCurrency(_statement!.totalEstimatedValue),
          'Total Actual': _formatCurrency(_statement!.totalActualValue),
        },
        entries: _statement!.entries.map((e) => {
          'job_number': e.jobNumber,
          'customer_name': e.customerName,
          'device_info': e.deviceInfo,
          'serial_number': e.serialNumber ?? '-',
          'problem': e.problemDescription,
          'status': e.status,
          'created_at': _formatDate(e.createdAt),
          'completed_at': e.completedAt != null ? _formatDate(e.completedAt!) : '-',
          'estimated_cost': _formatCurrency(e.estimatedCost ?? 0),
          'actual_cost': _formatCurrency(e.actualCost),
          'parts_used': e.partsUsed.join(', '),
        }).toList(),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'ServiceJobs_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
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
              'Service Job Statement',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.customerName != null)
              Text(
                widget.customerName!,
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
                child: _buildStatusDropdown(isDark),
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

  Widget _buildStatusDropdown(bool isDark) {
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
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedStatus,
          hint: Text(
            'All Status',
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
              _selectedStatus = value;
            });
            _loadStatement();
          },
          items: _statusOptions.map((status) => DropdownMenuItem(
            value: status == 'All' ? null : status,
            child: Text(status == 'All' ? 'All Status' : _formatStatus(status)),
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
            Icons.build_circle_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No service jobs found',
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

          // Job Statistics
          _buildJobStatistics(isDark),

          const SizedBox(height: 24),

          // Job List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Jobs',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.entries.length} jobs',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Job Entries
          ..._statement!.entries.map((entry) => _buildJobEntry(entry, isDark)),
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
          'Total Jobs',
          '${_statement!.totalJobs}',
          '${_statement!.completedJobs} completed',
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Pending Jobs',
          '${_statement!.pendingJobs}',
          'Require attention',
          _statement!.pendingJobs > 0 ? Colors.orange : Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Est. Revenue',
          _formatCurrency(_statement!.totalEstimatedValue),
          'Total estimates',
          Colors.purple,
          isDark,
        ),
        _buildSummaryCard(
          'Actual Revenue',
          _formatCurrency(_statement!.totalActualValue),
          'Collected amount',
          Colors.green,
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

  Widget _buildJobStatistics(bool isDark) {
    final completedPercent = _statement!.totalJobs > 0
        ? (_statement!.completedJobs / _statement!.totalJobs) * 100
        : 0;

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Completion Rate',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completedPercent / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completedPercent >= 80 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${completedPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Completed', _statement!.completedJobs, Colors.green),
              _buildStatChip('Pending', _statement!.pendingJobs, Colors.orange),
              _buildStatChip('Total', _statement!.totalJobs, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobEntry(ServiceJobEntry entry, bool isDark) {
    final statusColor = _getStatusColor(entry.status);

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
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(entry.status),
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
                  Text(
                    entry.jobNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    entry.customerName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusChip(entry.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.deviceInfo,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Est: ${_formatCurrency(entry.estimatedCost ?? 0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Actual: ${_formatCurrency(entry.actualCost)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.actualCost > (entry.estimatedCost ?? 0)
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow('Problem', entry.problemDescription, isDark),
                if (entry.serialNumber != null && entry.serialNumber!.isNotEmpty)
                  _buildDetailRow('Serial Number', entry.serialNumber!, isDark),
                _buildDetailRow('Created', _formatDate(entry.createdAt), isDark),
                if (entry.completedAt != null)
                  _buildDetailRow('Completed', _formatDate(entry.completedAt!), isDark),
                if (entry.partsUsed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Parts Used:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.partsUsed.map((part) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        part,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final displayStatus = _formatStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return Icons.check_circle;
      case 'IN_PROGRESS':
        return Icons.build;
      case 'PENDING':
        return Icons.schedule;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((s) => s[0] + s.substring(1).toLowerCase()).join(' ');
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
