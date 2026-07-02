/// Pharmacy line item. Batch number and expiry date are NON-NULLABLE at the
/// type level — this encodes the regulatory requirement (Drug rules) that a
/// pharmacy invoice line cannot exist without batch + expiry. The universal
/// engine treats these as optional columns; pharmacy needs them mandatory and
/// validated, which is why it is a dedicated template.
class PharmacyInvoiceItem {
  final String name;
  final String batchNo; // regulatory: required
  final DateTime expiryDate; // regulatory: required
  final String? hsn;
  final String? manufacturer;
  final double quantity;
  final double mrp;
  final double gstPercent;
  final double cgst;
  final double sgst;
  final double igst;

  const PharmacyInvoiceItem({
    required this.name,
    required this.batchNo,
    required this.expiryDate,
    this.hsn,
    this.manufacturer,
    required this.quantity,
    required this.mrp,
    this.gstPercent = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
  });

  double get taxable => quantity * mrp;
  double get totalTax => cgst + sgst + igst;
  double get amount => taxable + totalTax;

  bool isExpired(DateTime asOf) => !expiryDate.isAfter(asOf);

  bool expiresWithin(DateTime asOf, Duration window) =>
      !isExpired(asOf) && expiryDate.isBefore(asOf.add(window));
}

/// Regulatory validator for pharmacy invoices. Blocking is enforced at the
/// save/print flow (integration phase); this returns the reasons.
class PharmacyInvoiceValidator {
  /// Returns a list of human-readable errors that must block the sale.
  /// Empty list == valid.
  static List<String> validate(
    List<PharmacyInvoiceItem> items, {
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final errors = <String>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final line = 'Line ${i + 1} (${item.name})';
      if (item.batchNo.trim().isEmpty) {
        errors.add('$line: batch number is mandatory.');
      }
      if (item.isExpired(now)) {
        errors.add('$line: medicine is expired and cannot be sold.');
      }
    }
    return errors;
  }
}
