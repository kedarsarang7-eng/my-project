// ============================================================================
// RESTAURANT BILL MODEL
// ============================================================================

import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Bill payment status enum
enum BillPaymentStatus {
  pending('PENDING'),
  generated('GENERATED'),
  paid('PAID'),
  cancelled('CANCELLED');

  final String value;
  const BillPaymentStatus(this.value);

  static BillPaymentStatus fromString(String value) {
    return BillPaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BillPaymentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case BillPaymentStatus.pending:
        return 'Pending';
      case BillPaymentStatus.generated:
        return 'Generated';
      case BillPaymentStatus.paid:
        return 'Paid';
      case BillPaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Tax breakdown item
class TaxBreakdownItem {
  final String name;
  final double rate;
  final double amount;

  const TaxBreakdownItem({
    required this.name,
    required this.rate,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'rate': rate,
    'amount': amount,
  };

  factory TaxBreakdownItem.fromJson(Map<String, dynamic> json) {
    return TaxBreakdownItem(
      name: json['name'] ?? '',
      rate: (json['rate'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

/// Restaurant Bill model
class RestaurantBill extends Equatable {
  final String id;
  final String vendorId;
  final String orderId;
  final String customerId;
  final String? tableNumber;
  final String billNumber;
  final double subtotal;
  final double cgst;
  final double sgst;
  final double serviceCharge;
  final double discountAmount;
  final double grandTotal;
  final List<TaxBreakdownItem> taxBreakdown;
  final BillPaymentStatus paymentStatus;
  final String? paymentMode;
  final DateTime generatedAt;
  final DateTime? paidAt;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantBill({
    required this.id,
    required this.vendorId,
    required this.orderId,
    required this.customerId,
    this.tableNumber,
    required this.billNumber,
    required this.subtotal,
    this.cgst = 0,
    this.sgst = 0,
    this.serviceCharge = 0,
    this.discountAmount = 0,
    required this.grandTotal,
    this.taxBreakdown = const [],
    this.paymentStatus = BillPaymentStatus.pending,
    this.paymentMode,
    required this.generatedAt,
    this.paidAt,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total tax amount
  double get totalTax => cgst + sgst;

  /// Create from database entity
  factory RestaurantBill.fromEntity(RestaurantBillEntity entity) {
    List<TaxBreakdownItem> breakdown = [];
    if (entity.taxBreakdownJson != null &&
        entity.taxBreakdownJson!.isNotEmpty) {
      try {
        final list = jsonDecode(entity.taxBreakdownJson!) as List;
        breakdown = list.map((e) => TaxBreakdownItem.fromJson(e)).toList();
      } catch (_) {}
    }

    return RestaurantBill(
      id: entity.id,
      vendorId: entity.vendorId,
      orderId: entity.orderId,
      customerId: entity.customerId,
      tableNumber: entity.tableNumber,
      billNumber: entity.billNumber,
      subtotal: entity.subtotal,
      cgst: entity.cgst,
      sgst: entity.sgst,
      serviceCharge: entity.serviceCharge,
      discountAmount: entity.discountAmount,
      grandTotal: entity.grandTotal,
      taxBreakdown: breakdown,
      paymentStatus: BillPaymentStatus.fromString(entity.paymentStatus),
      paymentMode: entity.paymentMode,
      generatedAt: entity.generatedAt,
      paidAt: entity.paidAt,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'vendorId': vendorId,
    'orderId': orderId,
    'customerId': customerId,
    'tableNumber': tableNumber,
    'billNumber': billNumber,
    'subtotal': subtotal,
    'cgst': cgst,
    'sgst': sgst,
    'serviceCharge': serviceCharge,
    'discountAmount': discountAmount,
    'grandTotal': grandTotal,
    'taxBreakdown': taxBreakdown.map((e) => e.toJson()).toList(),
    'paymentStatus': paymentStatus.value,
    'paymentMode': paymentMode,
    'generatedAt': generatedAt.toIso8601String(),
    if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RestaurantBill copyWith({
    String? id,
    String? vendorId,
    String? orderId,
    String? customerId,
    String? tableNumber,
    String? billNumber,
    double? subtotal,
    double? cgst,
    double? sgst,
    double? serviceCharge,
    double? discountAmount,
    double? grandTotal,
    List<TaxBreakdownItem>? taxBreakdown,
    BillPaymentStatus? paymentStatus,
    String? paymentMode,
    DateTime? generatedAt,
    DateTime? paidAt,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantBill(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      tableNumber: tableNumber ?? this.tableNumber,
      billNumber: billNumber ?? this.billNumber,
      subtotal: subtotal ?? this.subtotal,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      discountAmount: discountAmount ?? this.discountAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      generatedAt: generatedAt ?? this.generatedAt,
      paidAt: paidAt ?? this.paidAt,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    orderId,
    billNumber,
    grandTotal,
    paymentStatus,
  ];
}
