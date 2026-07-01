// ============================================================================
// FOOD ORDER MODEL
// ============================================================================

import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Order type enum
enum OrderType {
  dineIn('DINE_IN'),
  takeaway('TAKEAWAY'),
  delivery('DELIVERY'),
  parcel('PARCEL');

  final String value;
  const OrderType(this.value);

  static OrderType fromString(String value) {
    return OrderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderType.dineIn,
    );
  }
}

/// Order status enum
enum FoodOrderStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  cooking('COOKING'),
  ready('READY'),
  served('SERVED'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String value;
  const FoodOrderStatus(this.value);

  static FoodOrderStatus fromString(String value) {
    return FoodOrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FoodOrderStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case FoodOrderStatus.pending:
        return 'Pending';
      case FoodOrderStatus.accepted:
        return 'Accepted';
      case FoodOrderStatus.cooking:
        return 'Cooking';
      case FoodOrderStatus.ready:
        return 'Ready';
      case FoodOrderStatus.served:
        return 'Served';
      case FoodOrderStatus.completed:
        return 'Completed';
      case FoodOrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Order item for the items list
class OrderItem extends Equatable {
  final String menuItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? specialInstructions;

  const OrderItem({
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'itemName': itemName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'specialInstructions': specialInstructions,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menuItemId'] ?? '',
      itemName: json['itemName'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      specialInstructions: json['specialInstructions'],
    );
  }

  @override
  List<Object?> get props => [menuItemId, quantity, unitPrice];
}

/// Food Order model
class FoodOrder extends Equatable {
  final String id;
  final String vendorId;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? tableId;
  final String? tableNumber;
  final OrderType orderType;
  final FoodOrderStatus orderStatus;
  final List<OrderItem> items;
  final int itemCount;
  final double subtotal;
  final double taxAmount;
  final double serviceCharge;
  final double discountAmount;
  final double grandTotal;
  final String? specialInstructions;
  final int? estimatedPrepTime;
  final DateTime orderTime;
  final DateTime? acceptedAt;
  final DateTime? cookingStartedAt;
  final DateTime? readyAt;
  final DateTime? servedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final bool billRequested;
  final DateTime? billRequestedAt;
  final String? billId;
  final bool isSynced;
  final String? syncOperationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? reviewRating;
  final String? reviewText;

  const FoodOrder({
    required this.id,
    required this.vendorId,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.tableId,
    this.tableNumber,
    required this.orderType,
    required this.orderStatus,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    this.taxAmount = 0,
    this.serviceCharge = 0,
    this.discountAmount = 0,
    required this.grandTotal,
    this.specialInstructions,
    this.estimatedPrepTime,
    required this.orderTime,
    this.acceptedAt,
    this.cookingStartedAt,
    this.readyAt,
    this.servedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.billRequested = false,
    this.billRequestedAt,
    this.billId,
    this.isSynced = false,
    this.syncOperationId,
    required this.createdAt,
    required this.updatedAt,
    this.reviewRating,
    this.reviewText,
  });

  /// Create from database entity
  factory FoodOrder.fromEntity(FoodOrderEntity entity) {
    List<OrderItem> orderItems = [];
    if (entity.itemsJson.isNotEmpty) {
      try {
        final itemsList = jsonDecode(entity.itemsJson) as List;
        orderItems = itemsList.map((e) => OrderItem.fromJson(e)).toList();
      } catch (_) {}
    }

    return FoodOrder(
      id: entity.id,
      vendorId: entity.vendorId,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      tableId: entity.tableId,
      tableNumber: entity.tableNumber,
      orderType: OrderType.fromString(entity.orderType),
      orderStatus: FoodOrderStatus.fromString(entity.orderStatus),
      items: orderItems,
      itemCount: entity.itemCount,
      subtotal: entity.subtotal,
      taxAmount: entity.taxAmount,
      serviceCharge: entity.serviceCharge,
      discountAmount: entity.discountAmount,
      grandTotal: entity.grandTotal,
      specialInstructions: entity.specialInstructions,
      estimatedPrepTime: entity.estimatedPrepTime,
      orderTime: entity.orderTime,
      acceptedAt: entity.acceptedAt,
      cookingStartedAt: entity.cookingStartedAt,
      readyAt: entity.readyAt,
      servedAt: entity.servedAt,
      completedAt: entity.completedAt,
      cancelledAt: entity.cancelledAt,
      cancellationReason: entity.cancellationReason,
      billRequested: entity.billRequested,
      billRequestedAt: entity.billRequestedAt,
      billId: entity.billId,
      isSynced: entity.isSynced,
      syncOperationId: entity.syncOperationId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      reviewRating: entity.reviewRating,
      reviewText: entity.reviewText,
    );
  }

  /// Convert items to JSON string
  String get itemsJson => jsonEncode(items.map((e) => e.toJson()).toList());

  /// Convert to Firestore map
  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'vendorId': vendorId,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'tableId': tableId,
    'tableNumber': tableNumber,
    'orderType': orderType.value,
    'orderStatus': orderStatus.value,
    'items': items.map((e) => e.toJson()).toList(),
    'itemCount': itemCount,
    'subtotal': subtotal,
    'taxAmount': taxAmount,
    'serviceCharge': serviceCharge,
    'discountAmount': discountAmount,
    'grandTotal': grandTotal,
    'specialInstructions': specialInstructions,
    'estimatedPrepTime': estimatedPrepTime,
    'orderTime': orderTime.toIso8601String(),
    if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
    if (cookingStartedAt != null)
      'cookingStartedAt': cookingStartedAt!.toIso8601String(),
    if (readyAt != null) 'readyAt': readyAt!.toIso8601String(),
    if (servedAt != null) 'servedAt': servedAt!.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
    'cancellationReason': cancellationReason,
    'billRequested': billRequested,
    if (billRequestedAt != null)
      'billRequestedAt': billRequestedAt!.toIso8601String(),
    'billId': billId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reviewRating': reviewRating,
    'reviewText': reviewText,
  };

  /// Whether the order can have bill requested
  bool get canRequestBill =>
      orderStatus == FoodOrderStatus.ready ||
      orderStatus == FoodOrderStatus.served;

  /// Whether the order is active (not completed/cancelled)
  bool get isActive =>
      orderStatus != FoodOrderStatus.completed &&
      orderStatus != FoodOrderStatus.cancelled;

  FoodOrder copyWith({
    String? id,
    String? vendorId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? tableId,
    String? tableNumber,
    OrderType? orderType,
    FoodOrderStatus? orderStatus,
    List<OrderItem>? items,
    int? itemCount,
    double? subtotal,
    double? taxAmount,
    double? serviceCharge,
    double? discountAmount,
    double? grandTotal,
    String? specialInstructions,
    int? estimatedPrepTime,
    DateTime? orderTime,
    DateTime? acceptedAt,
    DateTime? cookingStartedAt,
    DateTime? readyAt,
    DateTime? servedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    bool? billRequested,
    DateTime? billRequestedAt,
    String? billId,
    bool? isSynced,
    String? syncOperationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? reviewRating,
    String? reviewText,
  }) {
    return FoodOrder(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      orderType: orderType ?? this.orderType,
      orderStatus: orderStatus ?? this.orderStatus,
      items: items ?? this.items,
      itemCount: itemCount ?? this.itemCount,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      estimatedPrepTime: estimatedPrepTime ?? this.estimatedPrepTime,
      orderTime: orderTime ?? this.orderTime,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      cookingStartedAt: cookingStartedAt ?? this.cookingStartedAt,
      readyAt: readyAt ?? this.readyAt,
      servedAt: servedAt ?? this.servedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      billRequested: billRequested ?? this.billRequested,
      billRequestedAt: billRequestedAt ?? this.billRequestedAt,
      billId: billId ?? this.billId,
      isSynced: isSynced ?? this.isSynced,
      syncOperationId: syncOperationId ?? this.syncOperationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewRating: reviewRating ?? this.reviewRating,
      reviewText: reviewText ?? this.reviewText,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vendorId,
    customerId,
    orderStatus,
    grandTotal,
  ];
}
