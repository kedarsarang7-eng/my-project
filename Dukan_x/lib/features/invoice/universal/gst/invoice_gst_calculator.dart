import '../../../gst/models/gst_invoice_detail_model.dart' show SupplyType;
import '../../../gst/services/gst_service.dart';

/// Per-line GST result including CESS.
class InvoiceLineTax {
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;

  const InvoiceLineTax({
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
  });

  double get totalTax => cgst + sgst + igst + cess;
  double get lineTotal => taxable + totalTax;
}

/// Invoice-level aggregated GST result.
class InvoiceTaxSummary {
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;

  const InvoiceTaxSummary({
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
  });

  double get totalTax => cgst + sgst + igst + cess;
  double get grandTotal => taxable + totalTax;
}

/// Input for one invoice line.
class InvoiceLineInput {
  final double quantity;
  final double unitPrice;
  final double discount;
  final double gstRate; // e.g. 18 for 18%
  final double cessRate; // e.g. 12 for 12%

  const InvoiceLineInput({
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.gstRate,
    this.cessRate = 0,
  });
}

/// GST calculator for the invoice engine.
///
/// REUSES the authoritative [GstService.calculateTaxBreakup] for the
/// CGST/SGST/IGST split (single source of truth) and adds the CESS component,
/// which the base service does not model. This keeps the split logic
/// non-duplicated while supporting cess-bearing goods (autos, tobacco, etc.).
class InvoiceGstCalculator {
  /// Compute GST for a single line.
  static InvoiceLineTax forLine({
    required double quantity,
    required double unitPrice,
    double discount = 0,
    required double gstRate,
    double cessRate = 0,
    required bool isInterState,
  }) {
    final taxable = quantity * unitPrice - discount;
    final breakup = GstService.calculateTaxBreakup(
      taxableValue: taxable,
      gstRate: gstRate,
      supplyType: isInterState ? SupplyType.inter : SupplyType.intra,
    );
    final cess = taxable * cessRate / 100;
    return InvoiceLineTax(
      taxable: taxable,
      cgst: breakup.cgstAmount,
      sgst: breakup.sgstAmount,
      igst: breakup.igstAmount,
      cess: cess,
    );
  }

  /// Compute and aggregate GST across all lines of an invoice.
  static InvoiceTaxSummary forInvoice(
    List<InvoiceLineInput> lines, {
    required bool isInterState,
  }) {
    var taxable = 0.0, cgst = 0.0, sgst = 0.0, igst = 0.0, cess = 0.0;
    for (final l in lines) {
      final t = forLine(
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        discount: l.discount,
        gstRate: l.gstRate,
        cessRate: l.cessRate,
        isInterState: isInterState,
      );
      taxable += t.taxable;
      cgst += t.cgst;
      sgst += t.sgst;
      igst += t.igst;
      cess += t.cess;
    }
    return InvoiceTaxSummary(
      taxable: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      cess: cess,
    );
  }
}
