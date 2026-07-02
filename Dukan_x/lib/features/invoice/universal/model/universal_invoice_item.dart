/// Pure, presentation-agnostic invoice line item consumed by the universal
/// rendering engine.
///
/// Kept free of any PDF/printing/platform dependency so the engine and its
/// widget tests stay fast and decoupled. A thin adapter maps the app's
/// `EnhancedInvoiceItem` onto this type at integration time (Phase 5).
class UniversalInvoiceItem {
  final String name;
  final String? description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
  final double taxPercent;
  final double cgst;
  final double sgst;
  final double igst;

  // Optional business-specific fields (rendered only when a config field
  // references their key).
  final String? hsn;
  final String? serialNo; // also used for IMEI (labelled per business type)
  final int? warrantyMonths;
  final String? size;
  final String? color;
  final String? partNumber;
  final String? isbn;
  final String? batchNo;
  final DateTime? expiryDate;

  const UniversalInvoiceItem({
    required this.name,
    this.description,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.discount = 0,
    this.taxPercent = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.hsn,
    this.serialNo,
    this.warrantyMonths,
    this.size,
    this.color,
    this.partNumber,
    this.isbn,
    this.batchNo,
    this.expiryDate,
  });

  double get subtotal => quantity * unitPrice;
  double get taxable => subtotal - discount;
  double get totalTax => cgst + sgst + igst;
  double get total => taxable + totalTax;

  /// Resolve a formatted display string for a product-table column [key].
  ///
  /// This is the single mapping point from field keys to values. The widget
  /// stays generic: it renders whatever visible fields the config declares.
  /// [currency] lets the PDF path pass 'Rs.' since the standard PDF font has no
  /// rupee glyph, while the on-screen widget uses the default rupee symbol.
  String cell(String key, {String currency = '\u20B9'}) {
    String money(double v) => '$currency${v.toStringAsFixed(2)}';
    switch (key) {
      case 'name':
        return name;
      case 'description':
        return description ?? '';
      case 'qty':
        return _qty(quantity);
      case 'unit':
        return unit;
      case 'rate':
      case 'price':
      case 'mrp':
        return money(unitPrice);
      case 'hsn':
        return hsn ?? '-';
      case 'serialNo':
      case 'imei':
        return serialNo ?? '-';
      case 'warranty':
        return warrantyMonths != null ? _warranty(warrantyMonths!) : '-';
      case 'size':
        return size ?? '-';
      case 'color':
        return color ?? '-';
      case 'partNumber':
        return partNumber ?? '-';
      case 'isbn':
        return isbn ?? '-';
      case 'batchNo':
        return batchNo ?? '-';
      case 'expiry':
        return expiryDate != null ? _mmYY(expiryDate!) : '-';
      case 'gst':
        return '${_trim(taxPercent)}%';
      case 'discount':
        return money(discount);
      case 'taxable':
        return money(taxable);
      case 'amount':
      case 'total':
        return money(total);
      default:
        return '-';
    }
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _mmYY(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${(d.year % 100).toString().padLeft(2, '0')}';

  static String _warranty(int months) {
    if (months >= 12) {
      final years = months ~/ 12;
      return '$years Year${years > 1 ? 's' : ''}';
    }
    return '$months Month${months > 1 ? 's' : ''}';
  }
}
