import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/gstr1_export_service.dart';
import '../services/gstr3b_summary_service.dart';
import '../services/hsn_summary_service.dart';
import '../repositories/gst_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GST Reports Screen - View and export GST reports
class GstReportsScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const GstReportsScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<GstReportsScreen> createState() => _GstReportsScreenState();
}

class _GstReportsScreenState extends ConsumerState<GstReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedReport = 'gstr1';
  bool _isLoading = false;

  final Gstr1ExportService _gstr1Service = Gstr1ExportService();
  final Gstr3bSummaryService _gstr3bService = Gstr3bSummaryService();
  final HsnSummaryService _hsnService = HsnSummaryService();

  Gstr1Summary? _gstr1Summary;
  Gstr3bSummary? _gstr3bSummary;
  HsnSummaryReport? _hsnReport;
  String? _exportedJson;
  String? _exportedCsv;

  @override
  void initState() {
    super.initState();
    // Map initialIndex to report selection
    if (widget.initialIndex == 1) {
      _selectedReport = 'hsn';
    } else if (widget.initialIndex == 2) {
      _selectedReport = 'gstr3b';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = ref.watch(themeStateProvider);
    // ignore: unused_local_variable
    final isDark = theme.isDark;

    return DesktopContentContainer(
      title: 'GST Reports',
      subtitle: 'Generate GSTR-1, GSTR-3B and HSN Reports',
      actions: [
        DesktopIconButton(
          icon: Icons.calendar_today,
          tooltip: 'Select Date Range',
          onPressed: () => _pickDate(true),
        ),
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Generate Report',
          onPressed: _isLoading ? null : _generateReport,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Type Selector as Tabs. On phones the icons are dropped so
            // all three labels (GSTR-1 / GSTR-3B / HSN) stay on one line without
            // clipping; tablets/desktop keep the icon+label form.
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              // On mobile the segmented control is stretched to the full
              // available width so all three labels (GSTR-1 / GSTR-3B / HSN)
              // share the row and never clip; non-mobile keeps intrinsic sizing.
              width: context.isMobile ? double.infinity : null,
              child: SegmentedButton<String>(
                // Each label is wrapped in maxLines:1 + FittedBox(scaleDown)
                // so the three options (GSTR-1 / GSTR-3B / HSN) shrink to fit
                // rather than clipping when the text scale is raised, while
                // still sharing a single row.
                segments: [
                  ButtonSegment(
                    value: 'gstr1',
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('GSTR-1', maxLines: 1),
                    ),
                    icon: context.isMobile
                        ? null
                        : const Icon(Icons.upload_file),
                  ),
                  ButtonSegment(
                    value: 'gstr3b',
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('GSTR-3B', maxLines: 1),
                    ),
                    icon: context.isMobile ? null : const Icon(Icons.summarize),
                  ),
                  ButtonSegment(
                    value: 'hsn',
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('HSN', maxLines: 1),
                    ),
                    icon: context.isMobile ? null : const Icon(Icons.category),
                  ),
                ],
                selected: {_selectedReport},
                onSelectionChanged: (selection) =>
                    setState(() => _selectedReport = selection.first),
              ),
            ),

            // Date Range Display
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Themed surface so the card reads correctly in dark mode too.
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade300,
                ),
              ),
              child: context.isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              color: FuturisticColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Period: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickDateChip('Month', _thisMonth),
                            _buildQuickDateChip('Last Month', _lastMonth),
                            _buildQuickDateChip('Quarter', _thisQuarter),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.date_range,
                          color: FuturisticColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Period: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 24),
                        _buildQuickDateChip('Month', _thisMonth),
                        const SizedBox(width: 8),
                        _buildQuickDateChip('Last Month', _lastMonth),
                        const SizedBox(width: 8),
                        _buildQuickDateChip('Quarter', _thisQuarter),
                      ],
                    ),
            ),

            // Report Results
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_gstr1Summary != null && _selectedReport == 'gstr1')
                _buildGstr1Summary(),
              if (_gstr3bSummary != null && _selectedReport == 'gstr3b')
                _buildGstr3bSummary(),
              if (_hsnReport != null && _selectedReport == 'hsn')
                _buildHsnSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: FuturisticColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FuturisticColors.primary.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: FuturisticColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGstr1Summary() {
    final summary = _gstr1Summary!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GSTR-1 Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _exportJson(),
                  tooltip: 'Export JSON',
                ),
              ],
            ),
            const Divider(),
            _buildSummaryRow('Total Invoices', '${summary.totalInvoices}'),
            _buildSummaryRow('B2B Invoices', '${summary.b2bCount}'),
            _buildSummaryRow('B2CL Invoices', '${summary.b2clCount}'),
            _buildSummaryRow('B2CS Invoices', '${summary.b2csCount}'),
            const Divider(),
            _buildSummaryRow(
              'Taxable Value',
              _formatCurrency(summary.totalTaxableValue),
            ),
            _buildSummaryRow('CGST', _formatCurrency(summary.totalCgst)),
            _buildSummaryRow('SGST', _formatCurrency(summary.totalSgst)),
            _buildSummaryRow('IGST', _formatCurrency(summary.totalIgst)),
            _buildSummaryRow('Cess', _formatCurrency(summary.totalCess)),
            const Divider(),
            _buildSummaryRow(
              'Total GST',
              _formatCurrency(summary.totalGst),
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstr3bSummary() {
    final summary = _gstr3bSummary!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GSTR-3B Summary - ${summary.period}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Text(
              'Table 3.1 - Outward Supplies',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'Taxable Value',
              _formatCurrency(summary.table3_1.taxableSuppliesTaxableValue),
            ),
            _buildSummaryRow(
              'CGST',
              _formatCurrency(summary.table3_1.taxableSuppliesCgst),
            ),
            _buildSummaryRow(
              'SGST',
              _formatCurrency(summary.table3_1.taxableSuppliesSgst),
            ),
            _buildSummaryRow(
              'IGST',
              _formatCurrency(summary.table3_1.taxableSuppliesIgst),
            ),
            const Divider(),
            _buildSummaryRow(
              'Total Tax Liability',
              _formatCurrency(summary.totalTaxLiability.total),
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHsnSummary() {
    final report = _hsnReport!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HSN Summary - ${report.period}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _exportCsv(),
                  tooltip: 'Export CSV',
                ),
              ],
            ),
            Text(
              '${report.uniqueHsnCount} unique HSN codes',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(),
            // HSN Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('HSN')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Taxable'), numeric: true),
                  DataColumn(label: Text('Tax'), numeric: true),
                ],
                rows: report.items.take(10).map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.hsnCode)),
                      DataCell(
                        Text(
                          item.description.length > 20
                              ? '${item.description.substring(0, 20)}...'
                              : item.description,
                        ),
                      ),
                      DataCell(Text(item.quantity.toStringAsFixed(2))),
                      DataCell(Text(_formatCurrency(item.taxableValue))),
                      DataCell(Text(_formatCurrency(item.totalTax))),
                    ],
                  );
                }).toList(),
              ),
            ),
            if (report.items.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing 10 of ${report.items.length} items',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const Divider(),
            _buildSummaryRow(
              'Total Taxable',
              _formatCurrency(report.totals.totalTaxableValue),
            ),
            _buildSummaryRow(
              'Total Tax',
              _formatCurrency(report.totals.totalTax),
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: isHighlighted
                  ? theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : null,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              style: isHighlighted
                  ? theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    )
                  : const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2017, 7, 1),
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
    }
  }

  void _thisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    });
  }

  void _lastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - 1, 1);
      _endDate = DateTime(now.year, now.month, 0);
    });
  }

  void _thisQuarter() {
    final now = DateTime.now();
    final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
    setState(() {
      _startDate = DateTime(now.year, quarterStart, 1);
      _endDate = DateTime(now.year, quarterStart + 3, 0);
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      switch (_selectedReport) {
        case 'gstr1':
          // Fetch GST Settings to get the actual GSTIN
          final gstRepo = GstRepository();
          final gstSettings = await gstRepo.getGstSettings(userId);

          if (gstSettings == null ||
              gstSettings.gstin == null ||
              gstSettings.gstin!.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'GSTIN not configured. Please configured it in Settings.',
                  ),
                ),
              );
            }
            return;
          }

          final result = await _gstr1Service.generateGstr1Json(
            userId: userId,
            gstin: gstSettings.gstin!,
            financialYear: '2025-26',
            taxPeriod:
                '${_startDate.month.toString().padLeft(2, '0')}${_startDate.year}',
            startDate: _startDate,
            endDate: _endDate,
          );
          if (result.success) {
            setState(() {
              _gstr1Summary = result.summary;
              _exportedJson = result.json;
            });
          }
          break;

        case 'gstr3b':
          final summary = await _gstr3bService.generateSummary(
            userId: userId,
            startDate: _startDate,
            endDate: _endDate,
          );
          setState(() => _gstr3bSummary = summary);
          break;

        case 'hsn':
          final report = await _hsnService.generateReport(
            userId: userId,
            startDate: _startDate,
            endDate: _endDate,
          );
          setState(() {
            _hsnReport = report;
            _exportedCsv = report.toCsv();
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportJson() async {
    if (_exportedJson == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'GSTR1_${_startDate.month}_${_startDate.year}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(_exportedJson!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to: ${file.path}')));
      }
    } catch (e) {
      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: _exportedJson!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copied to clipboard')),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_exportedCsv == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'HSN_Summary_${_startDate.month}_${_startDate.year}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(_exportedCsv!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to: ${file.path}')));
      }
    } catch (e) {
      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: _exportedCsv!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }
}
