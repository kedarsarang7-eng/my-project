// ============================================================================
// RESTAURANT KOT (KITCHEN ORDER TICKET) MODEL
// ============================================================================

import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// KOT status enum
enum KotStatus {
  pending('PENDING'),
  sent('SENT'),
  printed('PRINTED'),
  cancelled('CANCELLED');

  final String value;
  const KotStatus(this.value);

  static KotStatus fromString(String value) {
    return KotStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => KotStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case KotStatus.pending:
        return 'Pending';
      case KotStatus.sent:
        return 'Sent to Kitchen';
      case KotStatus.printed:
        return 'Printed';
      case KotStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// A single item line in a KOT
class KotItem extends Equatable {
  final String menuItemId;
  final String itemName;
  final int qty;
  final String? variationName; // "Half", "Full", null
  final List<String> addons; // ["Extra Cheese", "Raita"]
  final String? specialInstructions;

  const KotItem({
    required this.menuItemId,
    required this.itemName,
    required this.qty,
    this.variationName,
    this.addons = const [],
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'itemName': itemName,
    'qty': qty,
    'variationName': variationName,
    'addons': addons,
    'specialInstructions': specialInstructions,
  };

  factory KotItem.fromJson(Map<String, dynamic> json) {
    return KotItem(
      menuItemId: json['menuItemId'] ?? '',
      itemName: json['itemName'] ?? '',
      qty: json['qty'] ?? 1,
      variationName: json['variationName'],
      addons: List<String>.from(json['addons'] ?? []),
      specialInstructions: json['specialInstructions'],
    );
  }

  @override
  List<Object?> get props => [menuItemId, qty, variationName];
}

/// Kitchen Order Ticket model
class RestaurantKot extends Equatable {
  final String id;
  final String vendorId;
  final String? orderId;
  final String? tableId;
  final String? tableNumber;
  final int kotNumber;
  final List<KotItem> items;
  final KotStatus status;
  final String? staffId;
  final String? waiterId;
  final String? specialInstructions;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantKot({
    required this.id,
    required this.vendorId,
    this.orderId,
    this.tableId,
    this.tableNumber,
    required this.kotNumber,
    required this.items,
    this.status = KotStatus.pending,
    this.staffId,
    this.waiterId,
    this.specialInstructions,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantKot.fromEntity(RestaurantKotEntity entity) {
    List<KotItem> kotItems = [];
    if (entity.itemsJson.isNotEmpty) {
      try {
        final list = jsonDecode(entity.itemsJson) as List;
        kotItems = list.map((e) => KotItem.fromJson(e)).toList();
      } catch (_) {}
    }
    return RestaurantKot(
      id: entity.id,
      vendorId: entity.vendorId,
      orderId: entity.orderId,
      tableId: entity.tableId,
      tableNumber: entity.tableNumber,
      kotNumber: entity.kotNumber,
      items: kotItems,
      status: KotStatus.fromString(entity.status),
      staffId: entity.staffId,
      waiterId: entity.waiterId,
      specialInstructions: entity.specialInstructions,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  String get itemsJson => jsonEncode(items.map((e) => e.toJson()).toList());

  Map<String, dynamic> toJson() => {
    'id': id,
    'vendorId': vendorId,
    'orderId': orderId,
    'tableId': tableId,
    'tableNumber': tableNumber,
    'kotNumber': kotNumber,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status.value,
    'staffId': staffId,
    'waiterId': waiterId,
    'specialInstructions': specialInstructions,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RestaurantKot copyWith({
    String? id,
    String? vendorId,
    String? orderId,
    String? tableId,
    String? tableNumber,
    int? kotNumber,
    List<KotItem>? items,
    KotStatus? status,
    String? staffId,
    String? waiterId,
    String? specialInstructions,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantKot(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      orderId: orderId ?? this.orderId,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      kotNumber: kotNumber ?? this.kotNumber,
      items: items ?? this.items,
      status: status ?? this.status,
      staffId: staffId ?? this.staffId,
      waiterId: waiterId ?? this.waiterId,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, kotNumber, status];
}
