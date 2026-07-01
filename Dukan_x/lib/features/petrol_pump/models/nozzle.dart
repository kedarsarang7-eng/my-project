import 'package:dukanx/core/compat/firestore_compat.dart';

/// Nozzle entity representing an individual fuel dispenser nozzle
/// Tracks readings for sales calculation
class Nozzle {
  final String nozzleId;
  final String dispenserId;
  final String fuelTypeId;
  final String? fuelTypeName; // Denormalized for display
  final double openingReading;
  final double closingReading;
  final String? linkedShiftId;
  final String? linkedEmployeeId;
  final String? linkedTankId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Nozzle({
    required this.nozzleId,
    required this.dispenserId,
    required this.fuelTypeId,
    this.fuelTypeName,
    this.openingReading = 0.0,
    this.closingReading = 0.0,
    this.linkedShiftId,
    this.linkedEmployeeId,
    this.linkedTankId,
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Calculate sale litres from readings
  double get calculatedSaleLitres {
    final sale = closingReading - openingReading;
    return sale >= 0 ? sale : 0;
  }

  /// Validate that closing reading is not less than opening
  bool get isValidReading => closingReading >= openingReading;

  Nozzle copyWith({
    String? nozzleId,
    String? dispenserId,
    String? fuelTypeId,
    String? fuelTypeName,
    double? openingReading,
    double? closingReading,
    String? linkedShiftId,
    String? linkedEmployeeId,
    String? linkedTankId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Nozzle(
      nozzleId: nozzleId ?? this.nozzleId,
      dispenserId: dispenserId ?? this.dispenserId,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      fuelTypeName: fuelTypeName ?? this.fuelTypeName,
      openingReading: openingReading ?? this.openingReading,
      closingReading: closingReading ?? this.closingReading,
      linkedShiftId: linkedShiftId ?? this.linkedShiftId,
      linkedEmployeeId: linkedEmployeeId ?? this.linkedEmployeeId,
      linkedTankId: linkedTankId ?? this.linkedTankId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  /// Reset readings for new shift (closing becomes new opening)
  Nozzle resetForNewShift(String newShiftId) {
    return copyWith(
      openingReading: closingReading,
      closingReading: closingReading, // Will be updated during shift
      linkedShiftId: newShiftId,
      linkedEmployeeId: null,
    );
  }

  Map<String, dynamic> toMap() => {
    'nozzleId': nozzleId,
    'dispenserId': dispenserId,
    'fuelTypeId': fuelTypeId,
    'fuelTypeName': fuelTypeName,
    'openingReading': openingReading,
    'closingReading': closingReading,
    'calculatedSaleLitres': calculatedSaleLitres,
    'linkedShiftId': linkedShiftId,
    'linkedEmployeeId': linkedEmployeeId,
    'linkedTankId': linkedTankId,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
  };

  factory Nozzle.fromMap(String id, Map<String, dynamic> map) {
    return Nozzle(
      nozzleId: id,
      dispenserId: map['dispenserId'] as String? ?? '',
      fuelTypeId: map['fuelTypeId'] as String? ?? '',
      fuelTypeName: map['fuelTypeName'] as String?,
      openingReading: (map['openingReading'] as num?)?.toDouble() ?? 0.0,
      closingReading: (map['closingReading'] as num?)?.toDouble() ?? 0.0,
      linkedShiftId: map['linkedShiftId'] as String?,
      linkedEmployeeId: map['linkedEmployeeId'] as String?,
      linkedTankId: map['linkedTankId'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
