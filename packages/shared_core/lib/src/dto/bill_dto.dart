class BillItemDto {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;

  const BillItemDto({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };

  factory BillItemDto.fromJson(Map<String, dynamic> json) {
    return BillItemDto(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}

class CreateBillDto {
  final String customerId;
  final List<BillItemDto> items;
  final double totalAmount;
  final String? notes;

  const CreateBillDto({
    required this.customerId,
    required this.items,
    required this.totalAmount,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'items': items.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
        if (notes != null) 'notes': notes,
      };
}
