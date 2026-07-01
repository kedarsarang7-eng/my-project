// ============================================================================
// FOOD CATEGORY MODEL
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Food Category for menu organization
class FoodCategory extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const FoodCategory({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Create from database entity
  factory FoodCategory.fromEntity(FoodCategoryEntity entity) {
    return FoodCategory(
      id: entity.id,
      vendorId: entity.vendorId,
      name: entity.name,
      description: entity.description,
      imageUrl: entity.imageUrl,
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
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  /// Create from Firestore map
  factory FoodCategory.fromFirestoreMap(Map<String, dynamic> map) {
    return FoodCategory(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      imageUrl: map['imageUrl'],
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

  FoodCategory copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return FoodCategory(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, name, sortOrder, isActive];
}
