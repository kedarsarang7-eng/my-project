// ============================================================================
// RESTAURANT INVENTORY & RECIPE MODELS
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Inventory units
enum InventoryUnit {
  kg('KG'),
  gm('GM'),
  litre('LITRE'),
  ml('ML'),
  pcs('PCS'),
  dozen('DOZEN');

  final String value;
  const InventoryUnit(this.value);

  static InventoryUnit fromString(String value) {
    return InventoryUnit.values.firstWhere(
      (e) => e.value == value,
      orElse: () => InventoryUnit.pcs,
    );
  }

  String get displayName => value;
}

/// Raw material inventory item
class RestaurantInventoryItem extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final InventoryUnit unit;
  final double currentStock;
  final double minStockAlert;
  final double costPerUnit;
  final String? supplierName;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantInventoryItem({
    required this.id,
    required this.vendorId,
    required this.name,
    this.unit = InventoryUnit.pcs,
    this.currentStock = 0,
    this.minStockAlert = 0,
    this.costPerUnit = 0,
    this.supplierName,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minStockAlert;

  factory RestaurantInventoryItem.fromEntity(
    RestaurantInventoryItemEntity entity,
  ) {
    return RestaurantInventoryItem(
      id: entity.id,
      vendorId: entity.vendorId,
      name: entity.name,
      unit: InventoryUnit.fromString(entity.unit),
      currentStock: entity.currentStock,
      minStockAlert: entity.minStockAlert,
      costPerUnit: entity.costPerUnit,
      supplierName: entity.supplierName,
      isActive: entity.isActive,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vendorId': vendorId,
    'name': name,
    'unit': unit.value,
    'currentStock': currentStock,
    'minStockAlert': minStockAlert,
    'costPerUnit': costPerUnit,
    'supplierName': supplierName,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RestaurantInventoryItem copyWith({
    String? id,
    String? vendorId,
    String? name,
    InventoryUnit? unit,
    double? currentStock,
    double? minStockAlert,
    double? costPerUnit,
    String? supplierName,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantInventoryItem(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, name, currentStock];
}

/// Recipe linking a menu item to inventory consumption
class ItemRecipe extends Equatable {
  final String id;
  final String menuItemId;
  final String inventoryItemId;
  final double quantityPerUnit;
  final String?
  variationId; // null = applies to base item; set for Half/Full specific
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemRecipe({
    required this.id,
    required this.menuItemId,
    required this.inventoryItemId,
    required this.quantityPerUnit,
    this.variationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ItemRecipe.fromEntity(ItemRecipeEntity entity) {
    return ItemRecipe(
      id: entity.id,
      menuItemId: entity.menuItemId,
      inventoryItemId: entity.inventoryItemId,
      quantityPerUnit: entity.quantityPerUnit,
      variationId: entity.variationId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'menuItemId': menuItemId,
    'inventoryItemId': inventoryItemId,
    'quantityPerUnit': quantityPerUnit,
    'variationId': variationId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, menuItemId, inventoryItemId, variationId];
}
