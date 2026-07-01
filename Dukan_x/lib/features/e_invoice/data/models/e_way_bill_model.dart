/// e-Way Bill Status
enum EWayBillStatus { pending, generated, cancelled, expired }

/// Transport Mode
enum TransportMode { road, rail, air, ship }

/// e-Way Bill Model
/// Represents a GST e-way bill for goods movement
class EWayBillModel {
  final String id;
  final String userId;
  final String billId;
  final String? ewbNumber; // e-Way Bill number
  final DateTime? ewbDate;
  final DateTime? validUntil;
  final String fromPlace;
  final String? fromPincode;
  final String toPlace;
  final String? toPincode;
  final int distanceKm;
  final TransportMode transportMode;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? transporterId;
  final String? transporterName;
  final String? transDocNumber;
  final DateTime? transDocDate;
  final EWayBillStatus status;
  final int extensionCount;
  final String? lastError;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? syncOperationId;

  const EWayBillModel({
    required this.id,
    required this.userId,
    required this.billId,
    this.ewbNumber,
    this.ewbDate,
    this.validUntil,
    required this.fromPlace,
    this.fromPincode,
    required this.toPlace,
    this.toPincode,
    required this.distanceKm,
    this.transportMode = TransportMode.road,
    this.vehicleNumber,
    this.vehicleType,
    this.transporterId,
    this.transporterName,
    this.transDocNumber,
    this.transDocDate,
    this.status = EWayBillStatus.pending,
    this.extensionCount = 0,
    this.lastError,
    this.retryCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.syncOperationId,
  });

  EWayBillModel copyWith({
    String? id,
    String? userId,
    String? billId,
    String? ewbNumber,
    DateTime? ewbDate,
    DateTime? validUntil,
    String? fromPlace,
    String? fromPincode,
    String? toPlace,
    String? toPincode,
    int? distanceKm,
    TransportMode? transportMode,
    String? vehicleNumber,
    String? vehicleType,
    String? transporterId,
    String? transporterName,
    String? transDocNumber,
    DateTime? transDocDate,
    EWayBillStatus? status,
    int? extensionCount,
    String? lastError,
    int? retryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? syncOperationId,
  }) {
    return EWayBillModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      billId: billId ?? this.billId,
      ewbNumber: ewbNumber ?? this.ewbNumber,
      ewbDate: ewbDate ?? this.ewbDate,
      validUntil: validUntil ?? this.validUntil,
      fromPlace: fromPlace ?? this.fromPlace,
      fromPincode: fromPincode ?? this.fromPincode,
      toPlace: toPlace ?? this.toPlace,
      toPincode: toPincode ?? this.toPincode,
      distanceKm: distanceKm ?? this.distanceKm,
      transportMode: transportMode ?? this.transportMode,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      transporterId: transporterId ?? this.transporterId,
      transporterName: transporterName ?? this.transporterName,
      transDocNumber: transDocNumber ?? this.transDocNumber,
      transDocDate: transDocDate ?? this.transDocDate,
      status: status ?? this.status,
      extensionCount: extensionCount ?? this.extensionCount,
      lastError: lastError ?? this.lastError,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncOperationId: syncOperationId ?? this.syncOperationId,
    );
  }
}

/// Extension for entity mapping
extension EWayBillModelX on EWayBillModel {
  /// Create from database entity
  static EWayBillModel fromEntity(dynamic entity) {
    return EWayBillModel(
      id: entity.id as String,
      userId: entity.userId as String,
      billId: entity.billId as String,
      ewbNumber: entity.ewbNumber as String?,
      ewbDate: entity.ewbDate as DateTime?,
      validUntil: entity.validUntil as DateTime?,
      fromPlace: entity.fromPlace as String,
      fromPincode: entity.fromPincode as String?,
      toPlace: entity.toPlace as String,
      toPincode: entity.toPincode as String?,
      distanceKm: entity.distanceKm as int,
      transportMode: _parseTransportMode(entity.transportMode as String),
      vehicleNumber: entity.vehicleNumber as String?,
      vehicleType: entity.vehicleType as String?,
      transporterId: entity.transporterId as String?,
      transporterName: entity.transporterName as String?,
      transDocNumber: entity.transDocNumber as String?,
      transDocDate: entity.transDocDate as DateTime?,
      status: _parseStatus(entity.status as String),
      extensionCount: entity.extensionCount as int,
      lastError: entity.lastError as String?,
      retryCount: entity.retryCount as int,
      createdAt: entity.createdAt as DateTime,
      updatedAt: entity.updatedAt as DateTime,
      isSynced: entity.isSynced as bool,
      syncOperationId: entity.syncOperationId as String?,
    );
  }

  static EWayBillStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'GENERATED':
        return EWayBillStatus.generated;
      case 'CANCELLED':
        return EWayBillStatus.cancelled;
      case 'EXPIRED':
        return EWayBillStatus.expired;
      default:
        return EWayBillStatus.pending;
    }
  }

  static TransportMode _parseTransportMode(String mode) {
    switch (mode.toUpperCase()) {
      case 'RAIL':
        return TransportMode.rail;
      case 'AIR':
        return TransportMode.air;
      case 'SHIP':
        return TransportMode.ship;
      default:
        return TransportMode.road;
    }
  }
}
