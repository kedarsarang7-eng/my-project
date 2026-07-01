/// Delivery Challan Model
/// For issuing delivery challans before final tax invoice generation
library;

enum DeliveryChallanStatus {
  draft,
  sent,
  converted, // Converted to Tax Invoice
  cancelled,
}

class DeliveryChallanItem {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final String? hsnCode;

  // GST details (preserved for eventual invoice conversion)
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;

  DeliveryChallanItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.hsnCode,
    this.cgstRate = 0,
    this.cgstAmount = 0,
    this.sgstRate = 0,
    this.sgstAmount = 0,
    this.igstRate = 0,
    this.igstAmount = 0,
  });

  factory DeliveryChallanItem.fromJson(Map<String, dynamic> json) {
    return DeliveryChallanItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'pcs',
      unitPrice: (json['unitPrice'] as num).toDouble(),
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      hsnCode: json['hsnCode'] as String?,
      cgstRate: (json['cgstRate'] as num?)?.toDouble() ?? 0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0,
      sgstRate: (json['sgstRate'] as num?)?.toDouble() ?? 0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0,
      igstRate: (json['igstRate'] as num?)?.toDouble() ?? 0,
      igstAmount: (json['igstAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
    'taxAmount': taxAmount,
    'totalAmount': totalAmount,
    'hsnCode': hsnCode,
    'cgstRate': cgstRate,
    'cgstAmount': cgstAmount,
    'sgstRate': sgstRate,
    'sgstAmount': sgstAmount,
    'igstRate': igstRate,
    'igstAmount': igstAmount,
  };
}

class DeliveryChallan {
  final String id;
  final String userId;
  final String challanNumber;
  final String? customerId;
  final String? customerName;
  final DateTime challanDate;
  final DateTime? dueDate;

  final double subtotal;
  final double taxAmount;
  final double grandTotal;

  final DeliveryChallanStatus status;

  // Transport Details
  final String? transportMode; // Road, Rail, Air, Ship
  final String? vehicleNumber;
  final String? eWayBillNumber;
  final String? shippingAddress;
  final String? lrNumber; // Lorry Receipt Number
  final String? transporterName;

  final List<DeliveryChallanItem> items;

  // Linkage
  final String? convertedBillId;

  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  DeliveryChallan({
    required this.id,
    required this.userId,
    required this.challanNumber,
    this.customerId,
    this.customerName,
    required this.challanDate,
    this.dueDate,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.grandTotal = 0,
    this.status = DeliveryChallanStatus.draft,
    this.transportMode,
    this.vehicleNumber,
    this.eWayBillNumber,
    this.shippingAddress,
    this.lrNumber,
    this.transporterName,
    this.items = const [],
    this.convertedBillId,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory DeliveryChallan.fromJson(Map<String, dynamic> json) {
    return DeliveryChallan(
      id: json['id'] as String,
      userId: json['userId'] as String,
      challanNumber: json['challanNumber'] as String,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      challanDate: DateTime.parse(json['challanDate'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      status: DeliveryChallanStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeliveryChallanStatus.draft,
      ),
      transportMode: json['transportMode'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      eWayBillNumber: json['eWayBillNumber'] as String?,
      shippingAddress: json['shippingAddress'] as String?,
      lrNumber: json['lrNumber'] as String?,
      transporterName: json['transporterName'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => DeliveryChallanItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      convertedBillId: json['convertedBillId'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'challanNumber': challanNumber,
    'customerId': customerId,
    'customerName': customerName,
    'challanDate': challanDate.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'subtotal': subtotal,
    'taxAmount': taxAmount,
    'grandTotal': grandTotal,
    'status': status.name,
    'transportMode': transportMode,
    'vehicleNumber': vehicleNumber,
    'eWayBillNumber': eWayBillNumber,
    'shippingAddress': shippingAddress,
    'lrNumber': lrNumber,
    'transporterName': transporterName,
    'items': items.map((e) => e.toJson()).toList(),
    'convertedBillId': convertedBillId,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  DeliveryChallan copyWith({
    String? id,
    String? userId,
    String? challanNumber,
    String? customerId,
    String? customerName,
    DateTime? challanDate,
    DateTime? dueDate,
    double? subtotal,
    double? taxAmount,
    double? grandTotal,
    DeliveryChallanStatus? status,
    String? transportMode,
    String? vehicleNumber,
    String? eWayBillNumber,
    String? shippingAddress,
    String? lrNumber,
    String? transporterName,
    List<DeliveryChallanItem>? items,
    String? convertedBillId,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DeliveryChallan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      challanNumber: challanNumber ?? this.challanNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      challanDate: challanDate ?? this.challanDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      status: status ?? this.status,
      transportMode: transportMode ?? this.transportMode,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      eWayBillNumber: eWayBillNumber ?? this.eWayBillNumber,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      lrNumber: lrNumber ?? this.lrNumber,
      transporterName: transporterName ?? this.transporterName,
      items: items ?? this.items,
      convertedBillId: convertedBillId ?? this.convertedBillId,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
