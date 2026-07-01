import '../models/models.dart';
import '../repositories/gst_repository.dart';

/// HSN Summary Report Service - Generates HSN-wise summary for GST reporting
class HsnSummaryService {
  final GstRepository _gstRepo;

  HsnSummaryService({GstRepository? gstRepo})
    : _gstRepo = gstRepo ?? GstRepository();

  /// Generate HSN summary report for a period
  Future<HsnSummaryReport> generateReport({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final invoices = await _gstRepo.getGstInvoicesForPeriod(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    // Aggregate all HSN items across invoices
    final hsnMap = <String, HsnReportItem>{};

    for (final invoice in invoices) {
      for (final hsn in invoice.hsnSummary) {
        if (hsnMap.containsKey(hsn.hsnCode)) {
          hsnMap[hsn.hsnCode] = hsnMap[hsn.hsnCode]!.merge(hsn);
        } else {
          hsnMap[hsn.hsnCode] = HsnReportItem.fromSummary(hsn);
        }
      }
    }

    // Sort by taxable value descending
    final items = hsnMap.values.toList()
      ..sort((a, b) => b.taxableValue.compareTo(a.taxableValue));

    // Calculate totals
    final totals = HsnReportTotals(
      totalQuantity: items.fold(0.0, (sum, i) => sum + i.quantity),
      totalTaxableValue: items.fold(0.0, (sum, i) => sum + i.taxableValue),
      totalCgst: items.fold(0.0, (sum, i) => sum + i.cgstAmount),
      totalSgst: items.fold(0.0, (sum, i) => sum + i.sgstAmount),
      totalIgst: items.fold(0.0, (sum, i) => sum + i.igstAmount),
      totalCess: items.fold(0.0, (sum, i) => sum + i.cessAmount),
    );

    return HsnSummaryReport(
      period: '${_formatDate(startDate)} to ${_formatDate(endDate)}',
      items: items,
      totals: totals,
      uniqueHsnCount: items.length,
    );
  }

  /// Get HSN-wise tax breakup for a specific invoice
  Future<List<HsnReportItem>> getHsnBreakupForInvoice(String billId) async {
    final detail = await _gstRepo.getGstDetailsByBillId(billId);
    if (detail == null) return [];

    return detail.hsnSummary
        .map((hsn) => HsnReportItem.fromSummary(hsn))
        .toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// HSN Summary Report
class HsnSummaryReport {
  final String period;
  final List<HsnReportItem> items;
  final HsnReportTotals totals;
  final int uniqueHsnCount;

  HsnSummaryReport({
    required this.period,
    required this.items,
    required this.totals,
    required this.uniqueHsnCount,
  });

  /// Export as CSV
  String toCsv() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'HSN Code,Description,UQC,Quantity,Taxable Value,CGST,SGST,IGST,Cess,Total Tax',
    );

    // Items
    for (final item in items) {
      buffer.writeln(
        '${item.hsnCode},'
        '"${item.description}",'
        '${item.uqc ?? "OTH"},'
        '${item.quantity.toStringAsFixed(2)},'
        '${item.taxableValue.toStringAsFixed(2)},'
        '${item.cgstAmount.toStringAsFixed(2)},'
        '${item.sgstAmount.toStringAsFixed(2)},'
        '${item.igstAmount.toStringAsFixed(2)},'
        '${item.cessAmount.toStringAsFixed(2)},'
        '${item.totalTax.toStringAsFixed(2)}',
      );
    }

    // Totals
    buffer.writeln(
      'TOTAL,,,,'
      '${totals.totalTaxableValue.toStringAsFixed(2)},'
      '${totals.totalCgst.toStringAsFixed(2)},'
      '${totals.totalSgst.toStringAsFixed(2)},'
      '${totals.totalIgst.toStringAsFixed(2)},'
      '${totals.totalCess.toStringAsFixed(2)},'
      '${totals.totalTax.toStringAsFixed(2)}',
    );

    return buffer.toString();
  }
}

/// HSN Report Item
class HsnReportItem {
  final String hsnCode;
  final String description;
  final String? uqc;
  final double quantity;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;

  HsnReportItem({
    required this.hsnCode,
    required this.description,
    this.uqc,
    required this.quantity,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.cessAmount,
  });

  double get totalTax => cgstAmount + sgstAmount + igstAmount + cessAmount;
  double get totalValue => taxableValue + totalTax;

  /// Determine effective GST rate
  double get effectiveRate {
    if (taxableValue == 0) return 0;
    return (totalTax / taxableValue) * 100;
  }

  factory HsnReportItem.fromSummary(HsnSummaryItem summary) {
    return HsnReportItem(
      hsnCode: summary.hsnCode,
      description: summary.description,
      uqc: summary.uqc,
      quantity: summary.quantity,
      taxableValue: summary.taxableValue,
      cgstAmount: summary.cgstAmount,
      sgstAmount: summary.sgstAmount,
      igstAmount: summary.igstAmount,
      cessAmount: summary.cessAmount,
    );
  }

  /// Merge with another HSN item of same code
  HsnReportItem merge(HsnSummaryItem other) {
    return HsnReportItem(
      hsnCode: hsnCode,
      description: description,
      uqc: uqc ?? other.uqc,
      quantity: quantity + other.quantity,
      taxableValue: taxableValue + other.taxableValue,
      cgstAmount: cgstAmount + other.cgstAmount,
      sgstAmount: sgstAmount + other.sgstAmount,
      igstAmount: igstAmount + other.igstAmount,
      cessAmount: cessAmount + other.cessAmount,
    );
  }
}

/// HSN Report Totals
class HsnReportTotals {
  final double totalQuantity;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;

  HsnReportTotals({
    required this.totalQuantity,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
  });

  double get totalTax => totalCgst + totalSgst + totalIgst + totalCess;
  double get totalValue => totalTaxableValue + totalTax;
}
