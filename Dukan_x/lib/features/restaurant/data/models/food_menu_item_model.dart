// ============================================================================
// FOOD MENU ITEM MODEL
// ============================================================================

import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Food Menu Item for restaurant/hotel menu
class FoodMenuItem extends Equatable {
  final String id;
  final String vendorId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final bool isPopular;
  final int? preparationTimeMinutes;
  final int popularityCount;
  final bool isVegetarian;
  final bool isVegan;
  final bool isSpicy;
  final List<String> allergens;
  final int sortOrder;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const FoodMenuItem({
    required this.id,
    required this.vendorId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.isAvailable = true,
    this.isPopular = false,
    this.preparationTimeMinutes,
    this.popularityCount = 0,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isSpicy = false,
    this.allergens = const [],
    this.sortOrder = 0,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Create from database entity
  factory FoodMenuItem.fromEntity(FoodMenuItemEntity entity) {
    List<String> allergensList = [];
    if (entity.allergensJson != null && entity.allergensJson!.isNotEmpty) {
      try {
        allergensList = List<String>.from(jsonDecode(entity.allergensJson!));
      } catch (_) {}
    }

    return FoodMenuItem(
      id: entity.id,
      vendorId: entity.vendorId,
      categoryId: entity.categoryId,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      imageUrl: entity.imageUrl,
      isAvailable: entity.isAvailable,
      isPopular: entity.isPopular,
      preparationTimeMinutes: entity.preparationTimeMinutes,
      popularityCount: entity.popularityCount,
      isVegetarian: entity.isVegetarian,
      isVegan: entity.isVegan,
      isSpicy: entity.isSpicy,
      allergens: allergensList,
      sortOrder: entity.sortOrder,
      isActive: entity.isActive,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'vendorId': vendorId,
    'categoryId': categoryId,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'isAvailable': isAvailable,
    'isPopular': isPopular,
    'preparationTimeMinutes': preparationTimeMinutes,
    'popularityCount': popularityCount,
    'isVegetarian': isVegetarian,
    'isVegan': isVegan,
    'isSpicy': isSpicy,
    'allergens': allergens,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  /// Create from Firestore map
  factory FoodMenuItem.fromFirestoreMap(Map<String, dynamic> map) {
    return FoodMenuItem(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      categoryId: map['categoryId'],
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      isAvailable: map['isAvailable'] ?? true,
      isPopular: map['isPopular'] ?? false,
      preparationTimeMinutes: map['preparationTimeMinutes'],
      popularityCount: map['popularityCount'] ?? 0,
      isVegetarian: map['isVegetarian'] ?? false,
      isVegan: map['isVegan'] ?? false,
      isSpicy: map['isSpicy'] ?? false,
      allergens: List<String>.from(map['allergens'] ?? []),
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
      isSynced: true,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'])
          : null,
    );
  }

  FoodMenuItem copyWith({
    String? id,
    String? vendorId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    bool? isPopular,
    int? preparationTimeMinutes,
    int? popularityCount,
    bool? isVegetarian,
    bool? isVegan,
    bool? isSpicy,
    List<String>? allergens,
    int? sortOrder,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FoodMenuItem(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isPopular: isPopular ?? this.isPopular,
      preparationTimeMinutes:
          preparationTimeMinutes ?? this.preparationTimeMinutes,
      popularityCount: popularityCount ?? this.popularityCount,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isSpicy: isSpicy ?? this.isSpicy,
      allergens: allergens ?? this.allergens,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, name, price, isAvailable];
}
