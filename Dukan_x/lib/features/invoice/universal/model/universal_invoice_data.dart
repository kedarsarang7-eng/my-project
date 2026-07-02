import 'dart:typed_data';

import 'universal_invoice_item.dart';

/// Pure view model: everything the universal invoice engine needs to render an
/// invoice, independent of the app's data/PDF layers.
class UniversalInvoiceData {
  // Business / shop
  final String shopName;
  final String ownerName;
  final String address;
  final String mobile;
  final String? email;
  final String? gstin;
  final String? tagline;
  final String? upiId;
  final String? drugLicenseNumber;

  // Bank details
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfsc;

  // Images (Uint8List is pure dart:typed_data — no platform dependency)
  final Uint8List? logoImage;
  final Uint8List? signatureImage;
  final Uint8List? stampImage;

  // Customer
  final String customerName;
  final String customerMobile;
  final String? customerAddress;
  final String? customerGstin;

  // Shipping
  final String? shippingAddress;
  final String? transportDetails;

  // Invoice meta
  final String invoiceNumber;
  final DateTime date;

  // Items + totals (totals are supplied pre-computed by the caller; the engine
  // does not own tax math — that lives in the GST service, verified in Phase 9)
  final List<UniversalInvoiceItem> items;
  final double subtotal;
  final double totalDiscount;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double grandTotal;
  final bool isInterState;

  // Payment
  final String paymentMode;
  final double paidAmount;
  final double dueAmount;
  final String? paymentStatus; // e.g. 'Paid' / 'Due'

  // Free text
  final String? notes;
  final String? terms;
  final String? warrantyTerms;
  final String? watermarkText;

  const UniversalInvoiceData({
    required this.shopName,
    required this.ownerName,
    required this.address,
    required this.mobile,
    this.email,
    this.gstin,
    this.tagline,
    this.upiId,
    this.drugLicenseNumber,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfsc,
    this.logoImage,
    this.signatureImage,
    this.stampImage,
    required this.customerName,
    this.customerMobile = '',
    this.customerAddress,
    this.customerGstin,
    this.shippingAddress,
    this.transportDetails,
    required this.invoiceNumber,
    required this.date,
    required this.items,
    this.subtotal = 0,
    this.totalDiscount = 0,
    this.totalCgst = 0,
    this.totalSgst = 0,
    this.totalIgst = 0,
    this.grandTotal = 0,
    this.isInterState = false,
    this.paymentMode = 'Cash',
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.paymentStatus,
    this.notes,
    this.terms,
    this.warrantyTerms,
    this.watermarkText,
  });

  double get totalTax => totalCgst + totalSgst + totalIgst;
}
