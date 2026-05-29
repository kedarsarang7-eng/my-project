// ============================================================================
// In-Store Self Scan & Checkout — Models
// ============================================================================

import 'dart:convert';

import 'package:equatable/equatable.dart';

// ── Session ───────────────────────────────────────────────────────────────────

class InStoreSession extends Equatable {
  final String sessionId;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String status;
  final List<CartItem> cartItems;
  final CartSummary? summary;
  final DateTime startedAt;

  const InStoreSession({
    required this.sessionId,
    required this.storeId,
    required this.storeName,
    this.storeAddress = '',
    required this.status,
    this.cartItems = const [],
    this.summary,
    required this.startedAt,
  });

  bool get isActive => status == 'ACTIVE';

  factory InStoreSession.fromJson(Map<String, dynamic> json) {
    return InStoreSession(
      sessionId: json['sessionId'] as String,
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String? ?? '',
      storeAddress: json['storeAddress'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      cartItems: (json['cartItems'] as List<dynamic>? ?? [])
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] != null
          ? CartSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  InStoreSession copyWith({
    List<CartItem>? cartItems,
    CartSummary? summary,
    String? status,
  }) {
    return InStoreSession(
      sessionId: sessionId,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      status: status ?? this.status,
      cartItems: cartItems ?? this.cartItems,
      summary: summary ?? this.summary,
      startedAt: startedAt,
    );
  }

  @override
  List<Object?> get props =>
      [sessionId, storeId, status, cartItems, summary];
}

// ── Cart Item ─────────────────────────────────────────────────────────────────

class CartItem extends Equatable {
  final String productId;
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int mrp;
  final int sellingPrice;
  final double discountPercent;
  final int gstSlab;
  final String unit;
  final String? category;
  final int quantity;
  final int lineTotalCents;
  final int gstAmountCents;

  const CartItem({
    required this.productId,
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.mrp,
    required this.sellingPrice,
    required this.discountPercent,
    required this.gstSlab,
    required this.unit,
    this.category,
    required this.quantity,
    required this.lineTotalCents,
    required this.gstAmountCents,
  });

  factory CartItem.fromScannedProduct(ScannedProduct p, {int qty = 1}) {
    return CartItem(
      productId: p.productId,
      barcode: p.barcode,
      name: p.name,
      brand: p.brand,
      imageUrl: p.imageUrl,
      mrp: p.mrp,
      sellingPrice: p.sellingPrice,
      discountPercent: p.discountPercent.toDouble(),
      gstSlab: p.gstSlab,
      unit: p.unit,
      category: p.category,
      quantity: qty,
      lineTotalCents: p.sellingPrice * qty,
      gstAmountCents: p.gstAmount * qty,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] as String,
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String,
      brand: json['brand'] as String?,
      imageUrl: json['imageUrl'] as String?,
      mrp: (json['mrp'] as num).toInt(),
      sellingPrice: (json['sellingPrice'] as num).toInt(),
      discountPercent: (json['discountPercent'] as num? ?? 0).toDouble(),
      gstSlab: (json['gstSlab'] as num? ?? 0).toInt(),
      unit: json['unit'] as String? ?? 'piece',
      category: json['category'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      lineTotalCents: (json['lineTotalCents'] as num).toInt(),
      gstAmountCents: (json['gstAmountCents'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'imageUrl': imageUrl,
        'mrp': mrp,
        'sellingPrice': sellingPrice,
        'discountPercent': discountPercent,
        'gstSlab': gstSlab,
        'unit': unit,
        'category': category,
        'quantity': quantity,
        'lineTotalCents': sellingPrice * quantity,
        'gstAmountCents': gstAmountCents * quantity,
      };

  CartItem withQuantity(int qty) {
    return CartItem(
      productId: productId,
      barcode: barcode,
      name: name,
      brand: brand,
      imageUrl: imageUrl,
      mrp: mrp,
      sellingPrice: sellingPrice,
      discountPercent: discountPercent,
      gstSlab: gstSlab,
      unit: unit,
      category: category,
      quantity: qty,
      lineTotalCents: sellingPrice * qty,
      gstAmountCents: gstAmountCents,
    );
  }

  @override
  List<Object?> get props => [productId, barcode, quantity];
}

// ── Scanned Product (from barcode lookup) ─────────────────────────────────────

class ScannedProduct extends Equatable {
  final String productId;
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int mrp;
  final int sellingPrice;
  final num discountPercent;
  final int gstSlab;
  final int gstAmount;
  final bool stockAvailable;
  final int stockQuantity;
  final String unit;
  final String? category;

  const ScannedProduct({
    required this.productId,
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.mrp,
    required this.sellingPrice,
    required this.discountPercent,
    required this.gstSlab,
    required this.gstAmount,
    required this.stockAvailable,
    required this.stockQuantity,
    required this.unit,
    this.category,
  });

  factory ScannedProduct.fromJson(Map<String, dynamic> json) {
    return ScannedProduct(
      productId: json['productId'] as String,
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String,
      brand: json['brand'] as String?,
      imageUrl: json['imageUrl'] as String?,
      mrp: (json['mrp'] as num).toInt(),
      sellingPrice: (json['sellingPrice'] as num).toInt(),
      discountPercent: json['discountPercent'] as num? ?? 0,
      gstSlab: (json['gstSlab'] as num? ?? 0).toInt(),
      gstAmount: (json['gstAmount'] as num? ?? 0).toInt(),
      stockAvailable: json['stockAvailable'] as bool? ?? false,
      stockQuantity: (json['stockQuantity'] as num? ?? 0).toInt(),
      unit: json['unit'] as String? ?? 'piece',
      category: json['category'] as String?,
    );
  }

  @override
  List<Object?> get props => [productId, barcode];
}

// ── Cart Summary ──────────────────────────────────────────────────────────────

class GstBreakup extends Equatable {
  final int slab;
  final int taxableAmount;
  final int cgst;
  final int sgst;
  final int total;

  const GstBreakup({
    required this.slab,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.total,
  });

  factory GstBreakup.fromJson(Map<String, dynamic> json) {
    return GstBreakup(
      slab: (json['slab'] as num).toInt(),
      taxableAmount: (json['taxableAmount'] as num).toInt(),
      cgst: (json['cgst'] as num).toInt(),
      sgst: (json['sgst'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [slab, total];
}

class CartSummary extends Equatable {
  final int subtotalCents;
  final int discountCents;
  final List<GstBreakup> gstBreakup;
  final int totalGstCents;
  final int totalCents;
  final int itemCount;

  const CartSummary({
    required this.subtotalCents,
    required this.discountCents,
    required this.gstBreakup,
    required this.totalGstCents,
    required this.totalCents,
    required this.itemCount,
  });

  String get totalDisplay =>
      '₹${(totalCents / 100).toStringAsFixed(2)}';
  String get subtotalDisplay =>
      '₹${(subtotalCents / 100).toStringAsFixed(2)}';
  String get discountDisplay =>
      '₹${(discountCents / 100).toStringAsFixed(2)}';
  String get gstDisplay =>
      '₹${(totalGstCents / 100).toStringAsFixed(2)}';

  factory CartSummary.fromJson(Map<String, dynamic> json) {
    return CartSummary(
      subtotalCents: (json['subtotalCents'] as num).toInt(),
      discountCents: (json['discountCents'] as num? ?? 0).toInt(),
      gstBreakup: (json['gstBreakup'] as List<dynamic>? ?? [])
          .map((e) => GstBreakup.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalGstCents: (json['totalGstCents'] as num? ?? 0).toInt(),
      totalCents: (json['totalCents'] as num).toInt(),
      itemCount: (json['itemCount'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [totalCents, itemCount];
}

// ── Checkout Response ─────────────────────────────────────────────────────────

class CheckoutResponse extends Equatable {
  final String orderId;
  final String paymentOrderId;
  final double amount;
  final String currency;
  final String gatewayKey;
  final CartSummary summary;

  const CheckoutResponse({
    required this.orderId,
    required this.paymentOrderId,
    required this.amount,
    required this.currency,
    required this.gatewayKey,
    required this.summary,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutResponse(
      orderId: json['orderId'] as String,
      paymentOrderId: json['paymentOrderId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      gatewayKey: json['gatewayKey'] as String,
      summary: CartSummary.fromJson(
          json['summary'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [orderId, paymentOrderId, amount];
}

// ── Exit QR ───────────────────────────────────────────────────────────────────

class ExitQRData extends Equatable {
  final String orderId;
  final String sessionId;
  final String storeId;
  final String tenantId;
  final int totalItems;
  final double totalAmount;
  final DateTime paidAt;
  final DateTime expiresAt;
  final String signature;
  final String rawJson;

  const ExitQRData({
    required this.orderId,
    required this.sessionId,
    required this.storeId,
    required this.tenantId,
    required this.totalItems,
    required this.totalAmount,
    required this.paidAt,
    required this.expiresAt,
    required this.signature,
    required this.rawJson,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  factory ExitQRData.fromJson(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return ExitQRData(
      orderId: decoded['orderId'] as String,
      sessionId: decoded['sessionId'] as String,
      storeId: decoded['storeId'] as String,
      tenantId: decoded['tenantId'] as String,
      totalItems: (decoded['totalItems'] as num).toInt(),
      totalAmount: (decoded['totalAmount'] as num).toDouble(),
      paidAt: DateTime.parse(decoded['paidAt'] as String),
      expiresAt: DateTime.parse(decoded['expiresAt'] as String),
      signature: decoded['signature'] as String,
      rawJson: rawJson,
    );
  }

  @override
  List<Object?> get props => [orderId, signature];
}
