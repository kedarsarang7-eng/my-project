// ============================================================================
// ESTIMATE / QUOTATION MODEL
// ============================================================================
// For Hardware Shop: Contractor requests estimate → owner creates quotation
// → contractor approves → convert to Invoice (Bill).
//
// Lifecycle: Draft → Sent → Accepted → Converted | Rejected | Expired
//
// Author: DukanX Engineering
// ============================================================================

import '../utils/number_utils.dart';

/// Estimate lifecycle status
enum EstimateStatus {
  draft, // Just created, not sent
  sent, // Sent to customer (WhatsApp/SMS/email)
  accepted, // Customer accepted
  rejected, // Customer rejected
  expired, // Past validity date
  converted, // Converted to Invoice
}

/// Single line item in an estimate
class EstimateItem {
  final String productId;
  final String productName;
  final double qty;
  final String unit;
  final double unitPrice;
  final double discount;
  final double gstRate;
  final String hsn;

  /// Calculated fields — use paise internally but stored as double for compat
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double lineTotal;

  /// Optional fields for hardware
  final String? brand;
  final String? specifications;

  /// Hardware-specific: material grade (e.g. "Fe500D") and physical dimensions
  /// (e.g. "12mm x 12m"). Additive optional fields so the estimate builder can
  /// carry them through estimate→invoice conversion (bugfix 2.18).
  final String? grade;
  final String? dimensions;

  EstimateItem({
    required this.productId,
    required this.productName,
    required this.qty,
    this.unit = 'pcs',
    required this.unitPrice,
    this.discount = 0,
    this.gstRate = 0,
    this.hsn = '',
    this.brand,
    this.specifications,
    this.grade,
    this.dimensions,
    double? taxableValue,
    double? cgst,
    double? sgst,
    double? igst,
    double? lineTotal,
  }) : taxableValue = taxableValue ?? _calcTaxable(qty, unitPrice, discount),
       cgst = cgst ?? 0,
       sgst = sgst ?? 0,
       igst = igst ?? 0,
       lineTotal =
           lineTotal ??
           _calcLineTotal(
             qty,
             unitPrice,
             discount,
             cgst ?? 0,
             sgst ?? 0,
             igst ?? 0,
           );

  static double _calcTaxable(double qty, double price, double discount) {
    // Paise arithmetic
    final int basePaise =
        ((qty * 1000).round() * (price * 100).round()) ~/ 1000;
    final int discPaise = (discount * 100).round();
    return (basePaise - discPaise) / 100.0;
  }

  static double _calcLineTotal(
    double qty,
    double price,
    double discount,
    double cgst,
    double sgst,
    double igst,
  ) {
    final taxable = _calcTaxable(qty, price, discount);
    final int taxablePaise = (taxable * 100).round();
    final int taxPaise =
        (cgst * 100).round() + (sgst * 100).round() + (igst * 100).round();
    return (taxablePaise + taxPaise) / 100.0;
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'qty': qty,
    'unit': unit,
    'unitPrice': unitPrice,
    'discount': discount,
    'gstRate': gstRate,
    'hsn': hsn,
    'taxableValue': taxableValue,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'lineTotal': lineTotal,
    if (brand != null) 'brand': brand,
    if (specifications != null) 'specifications': specifications,
    if (grade != null) 'grade': grade,
    // Always emit `dimensions` so hardware dimensions round-trip through
    // estimate→invoice conversion even when null (bugfix 2.18).
    'dimensions': dimensions,
  };

  factory EstimateItem.fromMap(Map<String, dynamic> m) {
    return EstimateItem(
      productId: m['productId']?.toString() ?? '',
      productName: m['productName']?.toString() ?? '',
      qty: parseDouble(m['qty']),
      unit: m['unit']?.toString() ?? 'pcs',
      unitPrice: parseDouble(m['unitPrice']),
      discount: parseDouble(m['discount']),
      gstRate: parseDouble(m['gstRate']),
      hsn: m['hsn']?.toString() ?? '',
      taxableValue: parseDouble(m['taxableValue']),
      cgst: parseDouble(m['cgst']),
      sgst: parseDouble(m['sgst']),
      igst: parseDouble(m['igst']),
      lineTotal: parseDouble(m['lineTotal']),
      brand: m['brand']?.toString(),
      specifications: m['specifications']?.toString(),
      grade: m['grade']?.toString(),
      dimensions: m['dimensions']?.toString(),
    );
  }
}

/// Estimate / Quotation document
class Estimate {
  final String id;
  final String estimateNumber; // e.g. EST-2025-001
  final String ownerId;

  /// Customer info
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerGstin;

  /// Items
  final List<EstimateItem> items;

  /// Dates
  final DateTime createdDate;
  final DateTime? validUntil; // Expiry date
  final DateTime? sentDate;
  final DateTime? acceptedDate;

  /// Totals (calculated from items)
  final double subtotal;
  final double totalDiscount;
  final double totalTax;
  final double grandTotal;

  /// Status & lifecycle
  final EstimateStatus status;
  final String? convertedBillId; // Bill ID if converted
  final String? rejectionReason;

  /// Notes
  final String notes;
  final String termsAndConditions;

  Estimate({
    required this.id,
    required this.estimateNumber,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    this.customerPhone = '',
    this.customerGstin,
    required this.items,
    required this.createdDate,
    this.validUntil,
    this.sentDate,
    this.acceptedDate,
    double? subtotal,
    double? totalDiscount,
    double? totalTax,
    double? grandTotal,
    this.status = EstimateStatus.draft,
    this.convertedBillId,
    this.rejectionReason,
    this.notes = '',
    this.termsAndConditions = '',
  }) : subtotal = subtotal ?? items.fold(0.0, (sum, i) => sum + i.taxableValue),
       totalDiscount =
           totalDiscount ?? items.fold(0.0, (sum, i) => sum + i.discount),
       totalTax =
           totalTax ??
           items.fold(0.0, (sum, i) => sum + i.cgst + i.sgst + i.igst),
       grandTotal =
           grandTotal ?? items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Check if estimate has expired
  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);

  /// Check if estimate can be converted to invoice
  bool get canConvert =>
      status == EstimateStatus.accepted ||
      status == EstimateStatus.sent ||
      status == EstimateStatus.draft;

  Map<String, dynamic> toMap() => {
    'estimateNumber': estimateNumber,
    'ownerId': ownerId,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerGstin': customerGstin,
    'items': items.map((e) => e.toMap()).toList(),
    'createdDate': createdDate.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
    'sentDate': sentDate?.toIso8601String(),
    'acceptedDate': acceptedDate?.toIso8601String(),
    'subtotal': subtotal,
    'totalDiscount': totalDiscount,
    'totalTax': totalTax,
    'grandTotal': grandTotal,
    'status': status.name,
    'convertedBillId': convertedBillId,
    'rejectionReason': rejectionReason,
    'notes': notes,
    'termsAndConditions': termsAndConditions,
  };

  factory Estimate.fromMap(String id, Map<String, dynamic> m) {
    return Estimate(
      id: id,
      estimateNumber: m['estimateNumber']?.toString() ?? '',
      ownerId: m['ownerId']?.toString() ?? '',
      customerId: m['customerId']?.toString() ?? '',
      customerName: m['customerName']?.toString() ?? '',
      customerPhone: m['customerPhone']?.toString() ?? '',
      customerGstin: m['customerGstin']?.toString(),
      items:
          (m['items'] as List?)?.map((e) => EstimateItem.fromMap(e)).toList() ??
          [],
      createdDate:
          DateTime.tryParse(m['createdDate']?.toString() ?? '') ??
          DateTime.now(),
      validUntil: m['validUntil'] != null
          ? DateTime.tryParse(m['validUntil'].toString())
          : null,
      sentDate: m['sentDate'] != null
          ? DateTime.tryParse(m['sentDate'].toString())
          : null,
      acceptedDate: m['acceptedDate'] != null
          ? DateTime.tryParse(m['acceptedDate'].toString())
          : null,
      subtotal: parseDouble(m['subtotal']),
      totalDiscount: parseDouble(m['totalDiscount']),
      totalTax: parseDouble(m['totalTax']),
      grandTotal: parseDouble(m['grandTotal']),
      status: EstimateStatus.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => EstimateStatus.draft,
      ),
      convertedBillId: m['convertedBillId']?.toString(),
      rejectionReason: m['rejectionReason']?.toString(),
      notes: m['notes']?.toString() ?? '',
      termsAndConditions: m['termsAndConditions']?.toString() ?? '',
    );
  }

  Estimate copyWith({
    String? estimateNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    List<EstimateItem>? items,
    DateTime? validUntil,
    DateTime? sentDate,
    DateTime? acceptedDate,
    double? subtotal,
    double? totalDiscount,
    double? totalTax,
    double? grandTotal,
    EstimateStatus? status,
    String? convertedBillId,
    String? rejectionReason,
    String? notes,
    String? termsAndConditions,
  }) {
    return Estimate(
      id: id,
      estimateNumber: estimateNumber ?? this.estimateNumber,
      ownerId: ownerId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerGstin: customerGstin ?? this.customerGstin,
      items: items ?? this.items,
      createdDate: createdDate,
      validUntil: validUntil ?? this.validUntil,
      sentDate: sentDate ?? this.sentDate,
      acceptedDate: acceptedDate ?? this.acceptedDate,
      subtotal: subtotal ?? this.subtotal,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      totalTax: totalTax ?? this.totalTax,
      grandTotal: grandTotal ?? this.grandTotal,
      status: status ?? this.status,
      convertedBillId: convertedBillId ?? this.convertedBillId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }
}
