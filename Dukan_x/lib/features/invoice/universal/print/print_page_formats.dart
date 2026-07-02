import 'package:pdf/pdf.dart';

/// Print target for an invoice.
enum InvoicePrintMode { a4, thermal80mm, thermal58mm }

/// Page formats for invoice printing.
///
/// The thermal 80mm/58mm continuous-roll formats and margins are SALVAGED
/// (non-destructively copied) from the pre-existing but dead
/// `lib/core/services/bill_print_service.dart`, which Phase 0 flagged as
/// holding the most complete thermal implementation. Keeping them here lets
/// the config-driven builder reuse the proven formats without depending on the
/// dead file (which is scheduled for deletion in the migration phase).
class InvoicePageFormats {
  /// 80mm standard POS thermal, continuous roll.
  static const thermal80mm = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 4 * PdfPageFormat.mm,
  );

  /// 58mm mini POS thermal, continuous roll.
  static const thermal58mm = PdfPageFormat(
    58 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 3 * PdfPageFormat.mm,
  );

  /// A4 with standard margins.
  static final a4 = PdfPageFormat.a4.copyWith(
    marginTop: 20 * PdfPageFormat.mm,
    marginBottom: 20 * PdfPageFormat.mm,
    marginLeft: 20 * PdfPageFormat.mm,
    marginRight: 20 * PdfPageFormat.mm,
  );

  static PdfPageFormat forMode(InvoicePrintMode mode) {
    switch (mode) {
      case InvoicePrintMode.a4:
        return a4;
      case InvoicePrintMode.thermal80mm:
        return thermal80mm;
      case InvoicePrintMode.thermal58mm:
        return thermal58mm;
    }
  }

  /// Thermal modes use a compact, single-column receipt layout; A4 uses the
  /// full tabular layout. This is a PRINT-TARGET decision, not a business-type
  /// decision.
  static bool isCompact(InvoicePrintMode mode) => mode != InvoicePrintMode.a4;
}
