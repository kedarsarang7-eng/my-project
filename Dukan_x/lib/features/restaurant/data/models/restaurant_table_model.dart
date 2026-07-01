// ============================================================================
// RESTAURANT TABLE MODEL
// ============================================================================

import 'package:equatable/equatable.dart';
import '../../../../core/database/app_database.dart';

/// Table status enum
enum TableStatus {
  available('AVAILABLE'),
  occupied('OCCUPIED'),
  reserved('RESERVED'),
  cleaning('CLEANING');

  final String value;
  const TableStatus(this.value);

  static TableStatus fromString(String value) {
    return TableStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TableStatus.available,
    );
  }

  String get displayName {
    switch (this) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.reserved:
        return 'Reserved';
      case TableStatus.cleaning:
        return 'Cleaning';
    }
  }
}

/// Restaurant Table model
class RestaurantTable extends Equatable {
  final String id;
  final String vendorId;
  final String tableNumber;
  final int capacity;
  final TableStatus status;
  final String? section;
  final String? qrCodeId;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const RestaurantTable({
    required this.id,
    required this.vendorId,
    required this.tableNumber,
    this.capacity = 4,
    this.status = TableStatus.available,
    this.section,
    this.qrCodeId,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Create from database entity
  factory RestaurantTable.fromEntity(RestaurantTableEntity entity) {
    return RestaurantTable(
      id: entity.id,
      vendorId: entity.vendorId,
      tableNumber: entity.tableNumber,
      capacity: entity.capacity,
      status: TableStatus.fromString(entity.status),
      section: entity.section,
      qrCodeId: entity.qrCodeId,
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
    'tableNumber': tableNumber,
    'capacity': capacity,
    'status': status.value,
    'section': section,
    'qrCodeId': qrCodeId,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };

  RestaurantTable copyWith({
    String? id,
    String? vendorId,
    String? tableNumber,
    int? capacity,
    TableStatus? status,
    String? section,
    String? qrCodeId,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      tableNumber: tableNumber ?? this.tableNumber,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      section: section ?? this.section,
      qrCodeId: qrCodeId ?? this.qrCodeId,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [id, vendorId, tableNumber, status];
}
