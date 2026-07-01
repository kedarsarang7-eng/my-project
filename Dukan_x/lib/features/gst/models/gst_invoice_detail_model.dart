import 'dart:convert';

/// Invoice type for GST classification
enum GstInvoiceType {
  b2b, // Business to Business (with GSTIN)
  b2cl, // B2C Large (Interstate > ₹2.5L)
  b2cs, // B2C Small
  export, // Export invoices
  nil, // Nil-rated/Exempt
}

/// Supply type - Interstate or Intrastate
enum SupplyType {
  inter, // Interstate (IGST)
  intra, // Intrastate (CGST + SGST)
}

/// HSN Summary item for GSTR reporting
class HsnSummaryItem {
  final String hsnCode;
  final String description;
  final String? uqc; // Unit Quantity Code
  final double quantity;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;

  HsnSummaryItem({
    required this.hsnCode,
    required this.description,
    this.uqc,
    required this.quantity,
    required this.taxableValue,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.cessAmount = 0,
  });

  double get totalTax => cgstAmount + sgstAmount + igstAmount + cessAmount;

  Map<String, dynamic> toMap() => {
    'hsnCode': hsnCode,
    'description': description,
    'uqc': uqc,
    'quantity': quantity,
    'taxableValue': taxableValue,
    'cgstAmount': cgstAmount,
    'sgstAmount': sgstAmount,
    'igstAmount': igstAmount,
    'cessAmount': cessAmount,
  };

  factory HsnSummaryItem.fromMap(Map<String, dynamic> map) => HsnSummaryItem(
    hsnCode: map['hsnCode'] ?? '',
    description: map['description'] ?? '',
    uqc: map['uqc'],
    quantity: (map['quantity'] ?? 0).toDouble(),
    taxableValue: (map['taxableValue'] ?? 0).toDouble(),
    cgstAmount: (map['cgstAmount'] ?? 0).toDouble(),
    sgstAmount: (map['sgstAmount'] ?? 0).toDouble(),
    igstAmount: (map['igstAmount'] ?? 0).toDouble(),
    cessAmount: (map['cessAmount'] ?? 0).toDouble(),
  );
}

/// GST Invoice Details - GST-specific data for each invoice
class GstInvoiceDetailModel {
  final String id;
  final String billId;
  final GstInvoiceType invoiceType;
  final SupplyType supplyType;
  final String placeOfSupply; // State code
  final double taxableValue;
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;
  final double cessAmount;
  final List<HsnSummaryItem> hsnSummary;
  final bool isReverseCharge;
  final String? eInvoiceIrn;
  final DateTime createdAt;
  final bool isSynced;

  GstInvoiceDetailModel({
    required this.id,
    required this.billId,
    required this.invoiceType,
    required this.supplyType,
    required this.placeOfSupply,
    required this.taxableValue,
    this.cgstRate = 0,
    this.cgstAmount = 0,
    this.sgstRate = 0,
    this.sgstAmount = 0,
    this.igstRate = 0,
    this.igstAmount = 0,
    this.cessAmount = 0,
    this.hsnSummary = const [],
    this.isReverseCharge = false,
    this.eInvoiceIrn,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Total GST amount
  double get totalGst => cgstAmount + sgstAmount + igstAmount + cessAmount;

  /// Invoice type name for display
  String get invoiceTypeName {
    switch (invoiceType) {
      case GstInvoiceType.b2b:
        return 'B2B';
      case GstInvoiceType.b2cl:
        return 'B2C Large';
      case GstInvoiceType.b2cs:
        return 'B2C Small';
      case GstInvoiceType.export:
        return 'Export';
      case GstInvoiceType.nil:
        return 'Nil/Exempt';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billId': billId,
      'invoiceType': invoiceType.name.toUpperCase(),
      'supplyType': supplyType.name.toUpperCase(),
      'placeOfSupply': placeOfSupply,
      'taxableValue': taxableValue,
      'cgstRate': cgstRate,
      'cgstAmount': cgstAmount,
      'sgstRate': sgstRate,
      'sgstAmount': sgstAmount,
      'igstRate': igstRate,
      'igstAmount': igstAmount,
      'cessAmount': cessAmount,
      'hsnSummaryJson': jsonEncode(hsnSummary.map((e) => e.toMap()).toList()),
      'isReverseCharge': isReverseCharge,
      'eInvoiceIrn': eInvoiceIrn,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory GstInvoiceDetailModel.fromMap(Map<String, dynamic> map) {
    List<HsnSummaryItem> hsnList = [];
    if (map['hsnSummaryJson'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['hsnSummaryJson']);
        hsnList = decoded.map((e) => HsnSummaryItem.fromMap(e)).toList();
      } catch (_) {}
    }

    return GstInvoiceDetailModel(
      id: map['id'] ?? '',
      billId: map['billId'] ?? '',
      invoiceType: GstInvoiceType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['invoiceType'],
        orElse: () => GstInvoiceType.b2cs,
      ),
      supplyType: SupplyType.values.firstWhere(
        (e) => e.name.toUpperCase() == map['supplyType'],
        orElse: () => SupplyType.intra,
      ),
      placeOfSupply: map['placeOfSupply'] ?? '',
      taxableValue: (map['taxableValue'] ?? 0).toDouble(),
      cgstRate: (map['cgstRate'] ?? 0).toDouble(),
      cgstAmount: (map['cgstAmount'] ?? 0).toDouble(),
      sgstRate: (map['sgstRate'] ?? 0).toDouble(),
      sgstAmount: (map['sgstAmount'] ?? 0).toDouble(),
      igstRate: (map['igstRate'] ?? 0).toDouble(),
      igstAmount: (map['igstAmount'] ?? 0).toDouble(),
      cessAmount: (map['cessAmount'] ?? 0).toDouble(),
      hsnSummary: hsnList,
      isReverseCharge: map['isReverseCharge'] ?? false,
      eInvoiceIrn: map['eInvoiceIrn'],
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      isSynced: map['isSynced'] ?? false,
    );
  }
}
