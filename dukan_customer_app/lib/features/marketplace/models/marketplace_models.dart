// ============================================================
// Dukan Customer App - Marketplace Models
// Freezed models for all marketplace entities
// ============================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'marketplace_models.freezed.dart';
part 'marketplace_models.g.dart';

// ---------- STORE ----------

@freezed
class StoreProfile with _$StoreProfile {
  const factory StoreProfile({
    required String id,
    required String name,
    required String category,
    String? logo,
    String? address,
    String? phone,
    String? description,
    double? rating,
    String? deliveryTime,
    double? minOrderValue,
    double? deliveryCharge,
    bool? isOpen,
  }) = _StoreProfile;

  factory StoreProfile.fromJson(Map<String, dynamic> json) =>
      _$StoreProfileFromJson(json);
}

// ---------- PRODUCT ----------

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    String? description,
    required String category,
    String? subcategory,
    String? brand,
    required double mrp,
    required double sellingPrice,
    required double discountPercent,
    required int stockQuantity,
    required String unit,
    @Default([]) List<String> images,
    bool? isAvailable,
    required double gstPercent,
    // Pharmacy
    String? expiryDate,
    String? drugSchedule,
    // Restaurant
    @Default([]) List<String> comboProducts,
    // Hardware/Electronics
    Map<String, String>? specAttributes,
    int? warrantyMonths,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

@freezed
class ProductDetail with _$ProductDetail {
  const factory ProductDetail({
    required Product product,
    @Default([]) List<Product> relatedProducts,
  }) = _ProductDetail;

  factory ProductDetail.fromJson(Map<String, dynamic> json) =>
      _$ProductDetailFromJson(json);
}

// ---------- CART ----------

@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required String productId,
    required String name,
    String? image,
    required int quantity,
    required String unit,
    required double mrp,
    required double sellingPrice,
    required double discountPercent,
    required double gstPercent,
    required double itemTotal,
    // Industry-specific
    String? prescriptionUrl,
    String? cookingInstructions,
    bool? warrantyRequired,
    // Stock validation
    int? stockQuantity,
    bool? isAvailable,
  }) = _CartItem;

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);
}

@freezed
class Cart with _$Cart {
  const factory Cart({
    @Default([]) List<CartItem> items,
    String? couponCode,
    @Default(0) double discountAmount,
    @Default(0) double subtotal,
    @Default(0) double taxAmount,
    @Default(0) double deliveryCharge,
    @Default(0) double total,
    @Default(0) int itemCount,
    String? lastUpdatedAt,
    List<StockWarning>? stockWarnings,
  }) = _Cart;

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);
}

@freezed
class StockWarning with _$StockWarning {
  const factory StockWarning({
    required String productId,
    required String name,
    required int requested,
    required int available,
  }) = _StockWarning;

  factory StockWarning.fromJson(Map<String, dynamic> json) =>
      _$StockWarningFromJson(json);
}

// ---------- ORDER ----------

enum OrderStatus {
  placed,
  accepted,
  rejected,
  preparing,
  readyForDispatch,
  outForDelivery,
  delivered,
  cancelled,
}

enum PaymentMethod { cod, online, wallet }
enum PaymentStatus { pending, completed, failed, refunded }

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    required String name,
    String? image,
    required int quantity,
    required String unit,
    required double mrp,
    required double sellingPrice,
    required double discountPercent,
    required double gstPercent,
    required double itemTotal,
    int? deliveredQuantity,
    String? returnReason,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

@freezed
class DeliveryAddress with _$DeliveryAddress {
  const factory DeliveryAddress({
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
  }) = _DeliveryAddress;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      _$DeliveryAddressFromJson(json);
}

@freezed
class OrderTimelineEvent with _$OrderTimelineEvent {
  const factory OrderTimelineEvent({
    required OrderStatus status,
    required String timestamp,
    String? note,
    required String updatedBy,
  }) = _OrderTimelineEvent;

  factory OrderTimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$OrderTimelineEventFromJson(json);
}

@freezed
class Order with _$Order {
  const factory Order({
    required String orderId,
    required OrderStatus status,
    required String customerName,
    required String customerPhone,
    required int itemCount,
    required double total,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    bool? isExpress,
    String? scheduledFor,
    String? estimatedDeliveryTime,
    required String createdAt,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}

@freezed
class OrderDetail with _$OrderDetail {
  const factory OrderDetail({
    required String orderId,
    required OrderStatus status,
    required String customerName,
    required String customerPhone,
    @Default([]) List<OrderItem> items,
    required DeliveryAddress deliveryAddress,
    required double subtotal,
    required double taxAmount,
    required double deliveryCharge,
    required double discountAmount,
    String? couponCode,
    required double total,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    bool? isExpress,
    String? scheduledFor,
    String? estimatedDeliveryTime,
    @Default([]) List<OrderTimelineEvent> timeline,
    String? notes,
    String? prescriptionUrl,
    String? createdAt,
    DeliveryPartnerInfo? deliveryPartner,
  }) = _OrderDetail;

  factory OrderDetail.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailFromJson(json);
}

@freezed
class DeliveryPartnerInfo with _$DeliveryPartnerInfo {
  const factory DeliveryPartnerInfo({
    required String name,
    required String phone,
    Map<String, double>? currentLocation,
    String? vehicleType,
    String? vehicleNumber,
  }) = _DeliveryPartnerInfo;

  factory DeliveryPartnerInfo.fromJson(Map<String, dynamic> json) =>
      _$DeliveryPartnerInfoFromJson(json);
}

// ---------- CONNECTION ----------

@freezed
class StoreConnection with _$StoreConnection {
  const factory StoreConnection({
    required bool connected,
    String? status,
    String? connectedAt,
    int? totalOrders,
    double? totalSpent,
  }) = _StoreConnection;

  factory StoreConnection.fromJson(Map<String, dynamic> json) =>
      _$StoreConnectionFromJson(json);
}

// ---------- COUPON ----------

@freezed
class Coupon with _$Coupon {
  const factory Coupon({
    required String code,
    required String type,
    required double value,
    double? maxDiscount,
    double? minOrderValue,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);
}

// ---------- SEARCH & FILTERS ----------

@freezed
class ProductSearchFilters with _$ProductSearchFilters {
  const factory ProductSearchFilters({
    String? category,
    String? brand,
    bool? inStock,
    String? sortBy, // newest, priceAsc, priceDesc, popularity
    double? minPrice,
    double? maxPrice,
  }) = _ProductSearchFilters;

  factory ProductSearchFilters.fromJson(Map<String, dynamic> json) =>
      _$ProductSearchFiltersFromJson(json);
}

@freezed
class ProductSearchResult with _$ProductSearchResult {
  const factory ProductSearchResult({
    @Default([]) List<Product> products,
    ProductSearchFilters? filters,
    int? total,
    int? page,
    int? limit,
    bool? hasMore,
  }) = _ProductSearchResult;

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) =>
      _$ProductSearchResultFromJson(json);
}

// ---------- WEBSOCKET MESSAGES ----------

@freezed
class WebSocketMessage with _$WebSocketMessage {
  const factory WebSocketMessage({
    required String type,
    required String timestamp,
    required String businessId,
    String? targetRoom,
    Map<String, dynamic>? payload,
  }) = _WebSocketMessage;

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) =>
      _$WebSocketMessageFromJson(json);
}

@freezed
class OrderUpdatePayload with _$OrderUpdatePayload {
  const factory OrderUpdatePayload({
    required String orderId,
    required String status,
    String? previousStatus,
    required String message,
    String? estimatedTime,
    required String timestamp,
  }) = _OrderUpdatePayload;

  factory OrderUpdatePayload.fromJson(Map<String, dynamic> json) =>
      _$OrderUpdatePayloadFromJson(json);
}
