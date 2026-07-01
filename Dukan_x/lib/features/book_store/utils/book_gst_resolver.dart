/// GST rate resolver for the Book Store vertical.
///
/// Resolves the applicable GST rate (as a percentage) for a line item based on
/// its HSN code, following the confirmed tax policy:
///
///   • Printed books (HSN 4901): 0% GST (exempt).
///   • Notebooks / exercise books (HSN 4820): 5% GST (CGST 2.5% + SGST 2.5%).
///   • Other stationery: 5%–18% by HSN code (see [_stationeryHsnRates]).
///
/// When no HSN code is available, the resolver falls back to the product's
/// stored `taxRate` field. When that too is absent or zero, it returns 0.0
/// (the platform default for printed books, the most common bookstore item).
///
/// Used by `BookPosScreen` (Task 7.3) to compute per-line-item tax.
library;

/// Resolves the GST rate (percentage) for a book-store line item.
///
/// [hsnCode] — the product's HSN code (nullable). If provided, the first 4
/// characters determine the rate bracket.
///
/// [storedTaxRate] — the product's persisted `taxRate` field (nullable). Used
/// as a fallback when [hsnCode] is null or not recognized.
///
/// Returns the applicable GST rate as a double percentage:
/// 0.0, 5.0, 12.0, or 18.0.
class BookGstResolver {
  const BookGstResolver._();

  /// Primary entry point: resolve the GST rate for a product.
  ///
  /// Priority:
  /// 1. HSN code → known bracket.
  /// 2. Product's stored `taxRate`.
  /// 3. 0.0 (exempt fallback — most common item is a printed book).
  static double resolveGstRate({String? hsnCode, double? storedTaxRate}) {
    if (hsnCode != null && hsnCode.isNotEmpty) {
      final rate = _resolveFromHsn(hsnCode);
      if (rate != null) return rate;
    }

    // Fallback to stored per-product rate (operator override via gstEditable).
    if (storedTaxRate != null && storedTaxRate > 0) {
      return storedTaxRate;
    }

    // Ultimate fallback: printed books are exempt.
    return 0.0;
  }

  /// Splits the resolved GST rate into CGST and SGST halves.
  ///
  /// For intra-state sales, total GST = CGST + SGST, each being half the rate.
  /// Returns a record with `cgst` and `sgst` as double percentages.
  static ({double cgst, double sgst}) splitCgstSgst({
    String? hsnCode,
    double? storedTaxRate,
  }) {
    final total = resolveGstRate(
      hsnCode: hsnCode,
      storedTaxRate: storedTaxRate,
    );
    return (cgst: total / 2.0, sgst: total / 2.0);
  }

  // ─── Private HSN resolution ────────────────────────────────────────────────

  /// Returns the GST rate for a known HSN prefix, or null if unrecognized.
  static double? _resolveFromHsn(String hsn) {
    final normalized = hsn.trim();
    if (normalized.isEmpty) return null;

    // Chapter 49 — Printed books, newspapers, pictures (exempt).
    if (normalized.startsWith('4901')) return 0.0;

    // Chapter 48 — Paper & paperboard articles.
    // 4820: Registers, notebooks, exercise books → 5%.
    if (normalized.startsWith('4820')) return 5.0;

    // Check the broader stationery HSN map for other common codes.
    final prefix4 = normalized.length >= 4
        ? normalized.substring(0, 4)
        : normalized;
    if (_stationeryHsnRates.containsKey(prefix4)) {
      return _stationeryHsnRates[prefix4]!;
    }

    // Not a recognized book-store HSN — return null so caller uses fallback.
    return null;
  }

  /// Known stationery HSN codes and their GST rates.
  ///
  /// Sources: Indian GST HSN classification (Central Excise Tariff Act).
  /// This is not exhaustive; unrecognized codes fall back to the product's
  /// stored `taxRate` or 0.0.
  static const Map<String, double> _stationeryHsnRates = {
    // Paper & paperboard articles (Chapter 48)
    '4802': 12.0, // Uncoated paper (writing/printing paper)
    '4810': 12.0, // Coated paper
    '4816': 18.0, // Carbon paper, self-copy paper
    '4817': 18.0, // Envelopes, letter cards, plain postcards
    '4819': 18.0, // Cartons, boxes of paper
    '4820': 5.0, // Registers, account books, notebooks, exercise books
    '4821': 12.0, // Paper labels
    // Printed books & related (Chapter 49) — all exempt
    '4901': 0.0, // Printed books, brochures, leaflets
    '4902': 0.0, // Newspapers, journals, periodicals
    '4903': 0.0, // Children's picture/drawing/colouring books
    '4904': 0.0, // Music, printed or in manuscript
    '4905': 5.0, // Maps and hydrographic charts (not books)
    // Writing instruments (Chapter 96)
    '9608': 18.0, // Ball-point pens, felt-tipped pens, markers
    '9609': 12.0, // Pencils, crayons, pastels, drawing charcoals
    '9610': 18.0, // Slates and boards for writing/drawing
    // Adhesives, inks, correction fluid (Chapter 35/32)
    '3506': 18.0, // Prepared glues and adhesives
    '3215': 18.0, // Printing ink, writing ink, drawing ink
  };
}
