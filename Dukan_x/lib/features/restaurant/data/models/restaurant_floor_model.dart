// ============================================================================
// RESTAURANT FLOOR / ZONE MODEL
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Floor types for zone segregation
enum FloorType {
  ac('AC'),
  nonAc('NON_AC'),
  rooftop('ROOFTOP'),
  outdoor('OUTDOOR'),
  custom('CUSTOM');

  final String value;
  const FloorType(this.value);

  static FloorType fromString(String value) {
    return FloorType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FloorType.custom,
    );
  }

  String get displayName {
    switch (this) {
      case FloorType.ac:
        return 'AC Section';
      case FloorType.nonAc:
        return 'Non-AC Section';
      case FloorType.rooftop:
        return 'Rooftop';
      case FloorType.outdoor:
        return 'Outdoor';
      case FloorType.custom:
        return 'Custom';
    }
  }
}

/// Restaurant Floor / Zone model
class RestaurantFloor extends Equatable {
  final String id;
  final String vendorId;
  final String name;
  final FloorType floorType;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RestaurantFloor({
    required this.id,
    required this.vendorId,
    required this.name,
    this.floorType = FloorType.custom,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RestaurantFloor.fromEntity(RestaurantFloorEntity entity) {
    return RestaurantFloor(
      id: entity.id,
      vendorId: entity.vendorId,
      name: entity.name,
      floorType: FloorType.fromString(entity.floorType),
      description: entity.description,
      sortOrder: entity.sortOrder,
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
    'floorType': floorType.value,
    'description': description,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  RestaurantFloor copyWith({
    String? id,
    String? vendorId,
    String? name,
    FloorType? floorType,
    String? description,
    int? sortOrder,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RestaurantFloor(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      floorType: floorType ?? this.floorType,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, name, floorType];
}
