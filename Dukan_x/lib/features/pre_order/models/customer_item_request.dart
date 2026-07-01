enum RequestStatus { pending, approved, rejected, billed }

enum ItemStatus { pending, approved, cancelled }

class CustomerItemRequestItem {
  String productId;
  String productName;
  double requestedQty;
  double approvedQty;
  String unit;
  ItemStatus status;

  CustomerItemRequestItem({
    required this.productId,
    required this.productName,
    required this.requestedQty,
    this.approvedQty = 0.0,
    this.unit = 'pcs',
    this.status = ItemStatus.pending,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'requestedQty': requestedQty,
    'approvedQty': approvedQty,
    'unit': unit,
    'status': status.name,
  };

  factory CustomerItemRequestItem.fromMap(Map<String, dynamic> map) {
    return CustomerItemRequestItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      requestedQty: (map['requestedQty'] ?? 0).toDouble(),
      approvedQty: (map['approvedQty'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      status: ItemStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ItemStatus.pending,
      ),
    );
  }

  CustomerItemRequestItem copyWith({
    String? productId,
    String? productName,
    double? requestedQty,
    double? approvedQty,
    String? unit,
    ItemStatus? status,
  }) {
    return CustomerItemRequestItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      requestedQty: requestedQty ?? this.requestedQty,
      approvedQty: approvedQty ?? this.approvedQty,
      unit: unit ?? this.unit,
      status: status ?? this.status,
    );
  }
}

class CustomerItemRequest {
  String id;
  String customerId;
  String vendorId;
  RequestStatus status;
  List<CustomerItemRequestItem> items;
  DateTime createdAt;
  DateTime updatedAt;
  String? note;

  CustomerItemRequest({
    required this.id,
    required this.customerId,
    required this.vendorId,
    this.status = RequestStatus.pending,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'vendorId': vendorId,
    'status': status.name,
    'items': items.map((e) => e.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'note': note,
  };

  factory CustomerItemRequest.fromMap(Map<String, dynamic> map) {
    return CustomerItemRequest(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      items:
          (map['items'] as List<dynamic>?)
              ?.map(
                (e) => CustomerItemRequestItem.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          [],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      note: map['note'],
    );
  }

  CustomerItemRequest copyWith({
    String? id,
    String? customerId,
    String? vendorId,
    RequestStatus? status,
    List<CustomerItemRequestItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
  }) {
    return CustomerItemRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }
}
