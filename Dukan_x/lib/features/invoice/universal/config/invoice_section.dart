/// The 16 modular invoice sections that make up any universal invoice.
///
/// The rendering engine iterates over an ordered list of section configs and
/// renders each section via a renderer keyed by this enum. The engine never
/// branches on [BusinessType] — business differences are expressed purely as
/// data (which sections/fields are enabled/required/visible).
///
/// See: design_docs/universal-invoice-architecture.md (Phase 1, section 2).
enum InvoiceSection {
  businessInfo,
  customerInfo,
  shipping,
  productTable,
  tax,
  payment,
  discount,
  bankDetails,
  warranty,
  serialImei,
  notes,
  terms,
  qr,
  signature,
  logo,
  watermark,
}
