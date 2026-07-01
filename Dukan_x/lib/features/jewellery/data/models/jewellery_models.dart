/// Custom Order model for Jewellery module
class CustomOrder {
  final String orderId;
  final String customerName;
  final String? customerPhone;
  final String itemDescription;
  final String metalType;
  final double estimatedWeightGrams;
  final double estimatedTotalPaisa;
  final String status;
  final String? designUrl;
  final DateTime? createdAt;

  CustomOrder({
    required this.orderId,
    required this.customerName,
    this.customerPhone,
    required this.itemDescription,
    required this.metalType,
    this.estimatedWeightGrams = 0,
    this.estimatedTotalPaisa = 0,
    required this.status,
    this.designUrl,
    this.createdAt,
  });

  factory CustomOrder.fromJson(Map<String, dynamic> json) {
    return CustomOrder(
      orderId: json['orderId'] ?? json['id'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'],
      itemDescription: json['itemDescription'] ?? '',
      metalType: json['metalType'] ?? 'GOLD',
      estimatedWeightGrams:
          (json['estimatedWeightGrams'] as num?)?.toDouble() ?? 0,
      estimatedTotalPaisa:
          (json['estimatedTotalPaisa'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'PENDING',
      designUrl: json['designUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'itemDescription': itemDescription,
    'metalType': metalType,
    'estimatedWeightGrams': estimatedWeightGrams,
    'estimatedTotalPaisa': estimatedTotalPaisa,
    'status': status,
    'designUrl': designUrl,
    'createdAt': createdAt?.toIso8601String(),
  };
}
