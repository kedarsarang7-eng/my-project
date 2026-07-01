// ============================================================
// Dukan Billing Software - Business Marketplace Models
// Desktop-optimized models for order management
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_order_models.freezed.dart';
part 'business_order_models.g.dart';

// ---------- ORDER STATUS ----------

enum BusinessOrderStatus {
  placed,
  accepted,
  rejected,
  preparing,
  readyForDispatch,
  outForDelivery,
  delivered,
  cancelled,
}

// ---------- PAYMENT ----------

enum BusinessPaymentMethod { cod, online, wallet }
enum BusinessPaymentStatus { pending, completed, failed, refunded }

// ---------- CUSTOMER ----------

@freezed
abstract class OnlineCustomer with _$OnlineCustomer {
  const factory OnlineCustomer({
    required String customerId,
    required String name,
    required String phone,
    String? email,
    required int totalOrders,
    required double totalSpent,
    required String connectedAt,
  }) = _OnlineCustomer;

  factory OnlineCustomer.fromJson(Map<String, dynamic> json) =>
      _$OnlineCustomerFromJson(json);
}

// ---------- ORDER ITEM ----------

@freezed
abstract class BusinessOrderItem with _$BusinessOrderItem {
  const factory BusinessOrderItem({
    required String productId,
    required String name,
    String? image,
    required int quantity,
    required int? stockQuantity,
    required String unit,
    required double mrp,
    required double sellingPrice,
    required double itemTotal,
    String? prescriptionUrl,
    String? cookingInstructions,
    bool? warrantyRequired,
    // For preparation tracking
    bool? isPrepared,
    String? preparedAt,
    String? preparedBy,
  }) = _BusinessOrderItem;

  factory BusinessOrderItem.fromJson(Map<String, dynamic> json) =>
      _$BusinessOrderItemFromJson(json);
}

// ---------- DELIVERY ADDRESS ----------

@freezed
abstract class BusinessDeliveryAddress with _$BusinessDeliveryAddress {
  const factory BusinessDeliveryAddress({
    required String id,
    required String label,
    required String addressLine1,
    String? addressLine2,
    String? landmark,
    required String city,
    required String state,
    required String pincode,
    required String contactName,
    required String contactPhone,
    Map<String, double>? location,
  }) = _BusinessDeliveryAddress;

  factory BusinessDeliveryAddress.fromJson(Map<String, dynamic> json) =>
      _$BusinessDeliveryAddressFromJson(json);
}

// ---------- TIMELINE ----------

@freezed
abstract class BusinessOrderTimelineEvent with _$BusinessOrderTimelineEvent {
  const factory BusinessOrderTimelineEvent({
    required BusinessOrderStatus status,
    required String timestamp,
    String? note,
    required String updatedBy,
  }) = _BusinessOrderTimelineEvent;

  factory BusinessOrderTimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$BusinessOrderTimelineEventFromJson(json);
}

// ---------- ORDER ----------

@freezed
abstract class BusinessOrder with _$BusinessOrder {
  const factory BusinessOrder({
    required String orderId,
    required BusinessOrderStatus status,
    required OnlineCustomer customer,
    required int itemCount,
    required double total,
    required BusinessPaymentMethod paymentMethod,
    required BusinessPaymentStatus paymentStatus,
    bool? isExpress,
    String? scheduledFor,
    String? estimatedDeliveryTime,
    required String createdAt,
    String? updatedAt,
  }) = _BusinessOrder;

  factory BusinessOrder.fromJson(Map<String, dynamic> json) =>
      _$BusinessOrderFromJson(json);
}

@freezed
abstract class BusinessOrderDetail with _$BusinessOrderDetail {
  const factory BusinessOrderDetail({
    required String orderId,
    required BusinessOrderStatus status,
    required OnlineCustomer customer,
    @Default([]) List<BusinessOrderItem> items,
    required BusinessDeliveryAddress deliveryAddress,
    required double subtotal,
    required double taxAmount,
    required double deliveryCharge,
    required double discountAmount,
    String? couponCode,
    required double total,
    required BusinessPaymentMethod paymentMethod,
    required BusinessPaymentStatus paymentStatus,
    bool? isExpress,
    String? scheduledFor,
    String? estimatedDeliveryTime,
    @Default([]) List<BusinessOrderTimelineEvent> timeline,
    String? notes,
    String? prescriptionUrl,
    String? createdAt,
    String? updatedAt,
    // Assignment
    DeliveryPartnerInfo? assignedPartner,
  }) = _BusinessOrderDetail;

  factory BusinessOrderDetail.fromJson(Map<String, dynamic> json) =>
      _$BusinessOrderDetailFromJson(json);
}

@freezed
abstract class DeliveryPartnerInfo with _$DeliveryPartnerInfo {
  const factory DeliveryPartnerInfo({
    required String partnerId,
    required String name,
    required String phone,
    Map<String, double>? currentLocation,
    String? vehicleType,
    String? vehicleNumber,
    bool? isActive,
  }) = _DeliveryPartnerInfo;

  factory DeliveryPartnerInfo.fromJson(Map<String, dynamic> json) =>
      _$DeliveryPartnerInfoFromJson(json);
}

// ---------- STATS ----------

@freezed
abstract class OrderStats with _$OrderStats {
  const factory OrderStats({
    required int totalOrders,
    required double totalRevenue,
    required int pendingOrders,
    required int preparingOrders,
    required int outForDeliveryOrders,
    required int deliveredToday,
    required double avgOrderValue,
    required int newCustomers,
    required int repeatCustomers,
  }) = _OrderStats;

  factory OrderStats.fromJson(Map<String, dynamic> json) =>
      _$OrderStatsFromJson(json);
}

// ---------- FILTERS ----------

@freezed
abstract class OrderFilters with _$OrderFilters {
  const factory OrderFilters({
    BusinessOrderStatus? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? searchQuery,
    String? sortBy,
    bool? isExpress,
  }) = _OrderFilters;

  factory OrderFilters.fromJson(Map<String, dynamic> json) =>
      _$OrderFiltersFromJson(json);
}

@freezed
abstract class PaginatedOrders with _$PaginatedOrders {
  const factory PaginatedOrders({
    @Default([]) List<BusinessOrder> orders,
    required int total,
    required int page,
    required int limit,
    required bool hasMore,
  }) = _PaginatedOrders;

  factory PaginatedOrders.fromJson(Map<String, dynamic> json) =>
      _$PaginatedOrdersFromJson(json);
}

// ---------- INVENTORY SYNC ----------

@freezed
abstract class InventorySyncItem with _$InventorySyncItem {
  const factory InventorySyncItem({
    required String productId,
    required String name,
    required String category,
    double? mrp,
    double? sellingPrice,
    int? stockQuantity,
    bool? isActive,
    bool? isAvailableForOnline,
    String? barcode,
    String? hsnCode,
    double? gstPercent,
    // Industry-specific
    String? expiryDate,
    String? drugSchedule,
  }) = _InventorySyncItem;

  factory InventorySyncItem.fromJson(Map<String, dynamic> json) =>
      _$InventorySyncItemFromJson(json);
}
