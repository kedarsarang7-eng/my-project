// ============================================================================
// PAISE-ONLY GST CALCULATOR
// ============================================================================
// All monetary values represented as integer paise (â‚¹1 = 100 paise).
// NEVER use double/float for money. This prevents IEEE 754 rounding errors.
//
// Rules:
//   - CGST = floor(totalTax / 2)
//   - SGST = totalTax - CGST  (remainder absorbs rounding)
//   - IGST = totalTax (full amount, no split)
//   - All intermediate calculations use integer arithmetic
//   - Tax-inclusive: base = total × 10000 / (10000 + rateBps)
//   - Composition scheme: no tax breakup (merchant cannot charge GST)
//   - Negative taxable allowed for credit notes/returns
//
// Author: DukanX Engineering
// ============================================================================

/// Result of paise-based tax calculation for a single line item.
class PaiseTaxBreakup {
  /// Taxable value in paise (price Ã— qty - discount), before tax
  final int taxablePaise;

  /// Total tax in paise
  final int totalTaxPaise;

  /// CGST in paise (intra-state only)
  final int cgstPaise;

  /// SGST in paise (intra-state only, absorbs rounding remainder)
  final int sgstPaise;

  /// IGST in paise (inter-state only)
  final int igstPaise;

  /// GST rate in basis points (18% = 1800 bps)
  final int rateBps;

  /// Line total including tax, in paise
  int get lineTotalPaise => taxablePaise + totalTaxPaise;

  const PaiseTaxBreakup({
    required this.taxablePaise,
    required this.totalTaxPaise,
    required this.cgstPaise,
    required this.sgstPaise,
    required this.igstPaise,
    required this.rateBps,
  });

  /// Convert paise to rupees for display only. NEVER use for calculations.
  double get taxableRupees => taxablePaise / 100.0;
  double get totalTaxRupees => totalTaxPaise / 100.0;
  double get cgstRupees => cgstPaise / 100.0;
  double get sgstRupees => sgstPaise / 100.0;
  double get igstRupees => igstPaise / 100.0;
  double get lineTotalRupees => lineTotalPaise / 100.0;
  double get ratePercent => rateBps / 100.0;
  double get halfRatePercent => rateBps / 200.0;
}

/// Result of paise-based calculation for an entire invoice.
class PaiseInvoiceSummary {
  final int subtotalPaise; // Sum of taxable values
  final int totalCgstPaise;
  final int totalSgstPaise;
  final int totalIgstPaise;
  final int totalTaxPaise;
  final int grandTotalPaise;
  final int discountPaise;
  final List<PaiseTaxBreakup> lineBreakups;

  const PaiseInvoiceSummary({
    required this.subtotalPaise,
    required this.totalCgstPaise,
    required this.totalSgstPaise,
    required this.totalIgstPaise,
    required this.totalTaxPaise,
    required this.grandTotalPaise,
    required this.discountPaise,
    required this.lineBreakups,
  });

  /// Display-only conversions
  double get subtotalRupees => subtotalPaise / 100.0;
  double get totalCgstRupees => totalCgstPaise / 100.0;
  double get totalSgstRupees => totalSgstPaise / 100.0;
  double get totalIgstRupees => totalIgstPaise / 100.0;
  double get totalTaxRupees => totalTaxPaise / 100.0;
  double get grandTotalRupees => grandTotalPaise / 100.0;
  double get discountRupees => discountPaise / 100.0;
}

/// Input for a single line item in paise calculation.
class PaiseLineItem {
  /// Unit price in paise
  final int unitPricePaise;

  /// Quantity (multiplied by 1000 for 3-decimal precision: 1.5 kg = 1500)
  final int quantityMillis;

  /// Discount in paise (flat amount for this line)
  final int discountPaise;

  /// GST rate in basis points (18% = 1800, 28% = 2800, 5% = 500)
  final int gstRateBps;

  /// Whether this is an inter-state supply (IGST) or intra-state (CGST+SGST)
  final bool isInterState;

  /// Whether the unit price is tax-inclusive (MRP).
  /// When true, the calculator reverse-extracts the base price:
  ///   base = lineAmount × 10000 / (10000 + rateBps)
  final bool isTaxInclusive;

  /// Whether this merchant is under composition scheme.
  /// Composition merchants (turnover < ₹1.5 Cr) cannot charge GST on
  /// invoices — no tax breakup is generated regardless of gstRateBps.
  final bool isCompositionScheme;

  /// HSN code for this item
  final String hsnCode;

  /// Item description
  final String description;

  const PaiseLineItem({
    required this.unitPricePaise,
    required this.quantityMillis,
    this.discountPaise = 0,
    required this.gstRateBps,
    this.isInterState = false,
    this.isTaxInclusive = false,
    this.isCompositionScheme = false,
    this.hsnCode = '',
    this.description = '',
  });

  /// Create from rupee values (convenience constructor for migration).
  /// Converts double rupees to int paise internally.
  factory PaiseLineItem.fromRupees({
    required double unitPrice,
    required double quantity,
    double discount = 0,
    required double gstRatePercent,
    bool isInterState = false,
    bool isTaxInclusive = false,
    bool isCompositionScheme = false,
    String hsnCode = '',
    String description = '',
  }) {
    return PaiseLineItem(
      unitPricePaise: _rupeesToPaise(unitPrice),
      quantityMillis: (quantity * 1000).round(),
      discountPaise: _rupeesToPaise(discount),
      gstRateBps: (gstRatePercent * 100).round(),
      isInterState: isInterState,
      isTaxInclusive: isTaxInclusive,
      isCompositionScheme: isCompositionScheme,
      hsnCode: hsnCode,
      description: description,
    );
  }

  static int _rupeesToPaise(double rupees) => (rupees * 100).round();
}

/// Paise-only GST Calculator.
///
/// All arithmetic is integer-only. No floating point anywhere in the
/// calculation pipeline. Results are exact to the paise.
class PaiseCalculator {
  const PaiseCalculator._();

  // -------------------------------------------------------------------------
  // Single Line Item
  // -------------------------------------------------------------------------

  /// Calculate tax breakup for a single line item using integer arithmetic.
  ///
  /// Formula (tax-exclusive, default):
  ///   taxable = (unitPrice × quantity / 1000) - discount
  ///   totalTax = taxable × rateBps / 10000   (integer division = floor)
  ///   cgst = totalTax / 2                     (integer division = floor)
  ///   sgst = totalTax - cgst                  (absorbs remainder)
  ///
  /// Formula (tax-inclusive, isTaxInclusive = true):
  ///   lineAmount = (unitPrice × quantity / 1000) - discount
  ///   taxable = lineAmount × 10000 / (10000 + rateBps)
  ///   totalTax = lineAmount - taxable
  ///
  /// Composition scheme: no tax breakup regardless of rate.
  /// Negative taxable: allowed for credit notes (produces negative tax).
  static PaiseTaxBreakup calculateLineItem(PaiseLineItem item) {
    // lineAmount = unitPrice * qty / 1000 (since qty is in millis)
    // We use integer division, which floors.
    final int lineAmount =
        ((item.unitPricePaise * item.quantityMillis) ~/ 1000) -
            item.discountPaise;

    // --- Composition scheme: no tax breakup ---
    if (item.isCompositionScheme) {
      return PaiseTaxBreakup(
        taxablePaise: lineAmount,
        totalTaxPaise: 0,
        cgstPaise: 0,
        sgstPaise: 0,
        igstPaise: 0,
        rateBps: 0, // Composition merchants show 0% on invoice
      );
    }

    int taxablePaise;
    int totalTaxPaise;

    if (item.isTaxInclusive && item.gstRateBps > 0) {
      // --- Tax-inclusive: reverse-extract base from total ---
      // taxable = lineAmount × 10000 / (10000 + rateBps)
      taxablePaise = (lineAmount * 10000) ~/ (10000 + item.gstRateBps);
      totalTaxPaise = lineAmount - taxablePaise;
    } else {
      // --- Tax-exclusive (original logic) ---
      taxablePaise = lineAmount;
      totalTaxPaise = (lineAmount * item.gstRateBps) ~/ 10000;
    }

    int cgst = 0;
    int sgst = 0;
    int igst = 0;

    if (item.isInterState) {
      igst = totalTaxPaise;
    } else {
      // CGST = floor(totalTax / 2) — works for both positive and negative
      cgst = totalTaxPaise ~/ 2;
      // SGST = totalTax - CGST (absorbs the 1-paise remainder on odd tax)
      sgst = totalTaxPaise - cgst;
    }

    return PaiseTaxBreakup(
      taxablePaise: taxablePaise,
      totalTaxPaise: totalTaxPaise,
      cgstPaise: cgst,
      sgstPaise: sgst,
      igstPaise: igst,
      rateBps: item.gstRateBps,
    );
  }

  // -------------------------------------------------------------------------
  // Full Invoice
  // -------------------------------------------------------------------------

  /// Calculate tax for an entire invoice (multiple line items).
  static PaiseInvoiceSummary calculateInvoice(List<PaiseLineItem> items) {
    int subtotal = 0;
    int totalCgst = 0;
    int totalSgst = 0;
    int totalIgst = 0;
    int totalTax = 0;
    int totalDiscount = 0;
    final breakups = <PaiseTaxBreakup>[];

    for (final item in items) {
      final breakup = calculateLineItem(item);
      subtotal += breakup.taxablePaise;
      totalCgst += breakup.cgstPaise;
      totalSgst += breakup.sgstPaise;
      totalIgst += breakup.igstPaise;
      totalTax += breakup.totalTaxPaise;
      totalDiscount += item.discountPaise;
      breakups.add(breakup);
    }

    return PaiseInvoiceSummary(
      subtotalPaise: subtotal,
      totalCgstPaise: totalCgst,
      totalSgstPaise: totalSgst,
      totalIgstPaise: totalIgst,
      totalTaxPaise: totalTax,
      grandTotalPaise: subtotal + totalTax,
      discountPaise: totalDiscount,
      lineBreakups: breakups,
    );
  }

  // -------------------------------------------------------------------------
  // Utility: Convert between rupees and paise
  // -------------------------------------------------------------------------

  /// Convert rupee double to paise int. Use ONLY at system boundaries
  /// (user input, API response). Never mid-calculation.
  static int rupeesToPaise(double rupees) => (rupees * 100).round();

  /// Convert paise int to rupee double. Use ONLY for display/serialization.
  static double paiseToRupees(int paise) => paise / 100.0;

  /// Convert GST rate percent (e.g. 18.0) to basis points (1800).
  static int percentToBps(double percent) => (percent * 100).round();

  /// Convert basis points to percent for display.
  static double bpsToPercent(int bps) => bps / 100.0;
}
