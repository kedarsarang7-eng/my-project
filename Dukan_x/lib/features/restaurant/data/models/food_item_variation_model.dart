// ============================================================================
// FOOD ITEM VARIATION MODEL (Half / Full / Quarter pricing)
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

class FoodItemVariation extends Equatable {
  final String id;
  final String menuItemId;
  final String vendorId;
  final String name; // "Half", "Full", "Quarter"
  final double price;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItemVariation({
    required this.id,
    required this.menuItemId,
    required this.vendorId,
    required this.name,
    required this.price,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // factory FoodItemVariation.fromEntity(FoodItemVariationEntity entity) {
  //   return FoodItemVariation(
  //     id: entity.id,
  //     menuItemId: entity.menuItemId,
  //     vendorId: entity.vendorId,
  //     name: entity.name,
  //     price: entity.price,
  //     isActive: entity.isActive,
  //     sortOrder: entity.sortOrder,
  //     createdAt: entity.createdAt,
  //     updatedAt: entity.updatedAt,
  //   );
  // }

  Map<String, dynamic> toJson() => {
    'id': id,
    'menuItemId': menuItemId,
    'vendorId': vendorId,
    'name': name,
    'price': price,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  FoodItemVariation copyWith({
    String? id,
    String? menuItemId,
    String? vendorId,
    String? name,
    double? price,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodItemVariation(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, menuItemId, name, price];
}
