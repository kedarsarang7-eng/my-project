import 'dart:typed_data';
import '../../models/business_type.dart';
import '../../models/bill.dart';
import '../../services/invoice_pdf_service.dart' show InvoiceLanguage;

/// Enhanced Invoice Configuration with all fields
class EnhancedInvoiceConfig {
  // Shop/Vendor Details
  final String shopName;
  final String ownerName;
  final String address;
  final String mobile;
  final String? email;
  final String? gstin;
  final String? fssaiNumber;

  /// Tenant-level Drug License Number for the pharmacy invoice header (R14).
  /// Null/empty for non-pharmacy businesses or when none is configured, in
  /// which case it is simply omitted from the header (R14.3).
  final String? drugLicenseNumber;
  final String? tagline;
  final String? upiId;

  // Images
  final Uint8List? logoImage;
  final Uint8List? avatarImage;
  final Uint8List? signatureImage;
  final Uint8List? stampImage;

  // Settings
  final InvoiceLanguage language;
  final BusinessType businessType;
  final bool showTax;
  final bool isGstBill;
  final String? returnPolicy;
  final String? termsAndConditions;

  // New: Versioning for backward compatibility
  final int version;

  EnhancedInvoiceConfig({
    required this.shopName,
    required this.ownerName,
    required this.address,
    required this.mobile,
    this.email,
    this.gstin,
    this.fssaiNumber,
    this.drugLicenseNumber,
    this.tagline,
    this.upiId,
    this.logoImage,
    this.avatarImage,
    this.signatureImage,
    this.stampImage,
    this.language = InvoiceLanguage.english,
    this.businessType = BusinessType.grocery,
    this.showTax = false,
    this.isGstBill = false,
    this.returnPolicy,
    this.termsAndConditions,
    this.version = 2, // Default to new engine
  });
}

/// Customer details for invoice
class EnhancedInvoiceCustomer {
  final String name;
  final String mobile;
  final String? address;
  final String? gstin;

  EnhancedInvoiceCustomer({
    required this.name,
    required this.mobile,
    this.address,
    this.gstin,
  });

  /// Create from Bill model
  factory EnhancedInvoiceCustomer.fromBill(Bill bill) {
    return EnhancedInvoiceCustomer(
      name: bill.customerName.isEmpty ? 'Walk-in Customer' : bill.customerName,
      mobile: bill.customerPhone,
      address: bill.customerAddress,
      gstin: bill.customerGst,
    );
  }
}

/// Individual invoice item
class EnhancedInvoiceItem {
  final String name;
  final String? description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double? discountAmount;
  final double? taxPercent;
  final double? cgst;
  final double? sgst;
  final double? igst;

  // Business-specific fields
  final String? batchNo;
  final DateTime? expiryDate;
  final String? serialNo;
  final int? warrantyMonths;
  final String? size;
  final String? color;
  final String? tableNo;
  final bool? isParcel;
  final bool? isHalf;
  final double? laborCharge;
  final double? partsCharge;
  final String? notes;
  final String? hsn;
  final String? vehicleNumber;
  // Vegetable Broker
  final double? grossWeight;
  final double? tareWeight;
  final double? netWeight;
  final double? commission;
  final double? marketFee;
  final String? lotId;

  EnhancedInvoiceItem({
    required this.name,
    this.description,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.discountAmount,
    this.taxPercent,
    this.cgst,
    this.sgst,
    this.igst,
    // Business-specific
    this.batchNo,
    this.expiryDate,
    this.serialNo,
    this.warrantyMonths,
    this.size,
    this.color,
    this.tableNo,
    this.isParcel,
    this.isHalf,
    this.laborCharge,
    this.partsCharge,
    this.notes,
    this.hsn,
    this.vehicleNumber,
    // Vegetable Broker
    this.grossWeight,
    this.tareWeight,
    this.netWeight,
    this.commission,
    this.marketFee,
    this.lotId,
  });

  double get subtotal => quantity * unitPrice;
  double get discount => discountAmount ?? 0;
  double get taxableAmount => subtotal - discount;
  double get totalTax => (cgst ?? 0) + (sgst ?? 0) + (igst ?? 0);
  double get total =>
      taxableAmount + totalTax + (laborCharge ?? 0) + (partsCharge ?? 0);

  /// Create from BillItem model (from bill.dart)
  factory EnhancedInvoiceItem.fromBillItem(BillItem item) {
    return EnhancedInvoiceItem(
      name: item.itemName,
      quantity: item.qty,
      unit: item.unit,
      unitPrice: item.price,
      discountAmount: item.discount,
      taxPercent: item.gstRate,
      cgst: item.cgst,
      sgst: item.sgst,
      igst: item.igst,
      // Business-specific
      batchNo: item.batchNo,
      expiryDate: item.expiryDate,
      serialNo: item.serialNo,
      warrantyMonths: item.warrantyMonths,
      size: item.size,
      color: item.color,
      tableNo: item.tableNo,
      isParcel: item.isParcel,
      isHalf: item.isHalf,
      laborCharge: item.laborCharge,
      partsCharge: item.partsCharge,
      notes: item.notes,
      hsn: item.hsn,
      vehicleNumber: item.vehicleNumber,
      // Vegetable Broker
      grossWeight: item.grossWeight,
      tareWeight: item.tareWeight,
      netWeight: item.netWeight,
      commission: item.commission,
      marketFee: item.marketFee,
      lotId: item.lotId,
    );
  }
}
