import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/reports_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../services/pdf_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ProductSalesBreakdownScreen extends ConsumerStatefulWidget {
  const ProductSalesBreakdownScreen({super.key});

  @override
  ConsumerState<ProductSalesBreakdownScreen> createState() =>
      _ProductSalesBreakdownScreenState();
}

class _ProductSalesBreakdownScreenState
    extends ConsumerState<ProductSalesBreakdownScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;

      final result = await sl<ReportsRepository>().getProductSalesBreakdown(
        userId: userId,
        start: _startDate,
        end: _endDate,
      );

      if (mounted) {
        setState(() {
          _data = result.data ?? [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeStateProvider).isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _data.isEmpty ? null : _generatePdf,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Change Date'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                ? const Center(child: Text('No sales data found'))
                : ListView.builder(
                    itemCount: _data.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final item = _data[index];
                      final size = item['size'] as String?;
                      final color = item['color'] as String?;
                      final hasVars =
                          (size != null && size.isNotEmpty) ||
                          (color != null && color.isNotEmpty);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: hasVars
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Size: ${size ?? '-'} | Color: ${color ?? '-'}',
                                  ),
                                )
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Qty: ${item['quantity']}'),
                              Text(
                                '₹${(item['total'] as double).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdfService = PdfService();
    final pdfData = _data
        .map(
          (e) => {
            'label': "${e['name']} ${e['size'] ?? ''} ${e['color'] ?? ''}",
            'value': e['total'],
          },
        )
        .toList();

    final bytes = await pdfService.generateReportPdf(
      "Product Performance",
      pdfData.cast<Map<String, dynamic>>(),
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
