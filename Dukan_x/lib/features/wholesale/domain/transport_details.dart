/// Transport details captured for a dispatch or delivery challan.
///
/// Persisted as a standalone entity scoped to the active Tenant_Id with an RID
/// identifier. Surfaces only when `useTransportDetails` capability is granted.
///
/// Design model (Phase 5):
/// ```
/// TransportDetails (new)
///   id                 : RID
///   tenantId           : string
///   vehicleNumber      : string
///   lrNumber           : string
///   transporterName    : string
///   linkedChallanId    : string
/// ```
class TransportDetails {
  /// RID-format identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  final String id;

  /// The owning tenant — scopes all queries and writes.
  final String tenantId;

  /// Vehicle registration number (e.g. "MH12AB1234").
  /// Required field — must not be empty.
  final String vehicleNumber;

  /// Lorry Receipt (LR) number issued by the transporter.
  /// Optional — may be empty for self-transport scenarios.
  final String lrNumber;

  /// Name of the transporter or transport company.
  /// Required field — must not be empty.
  final String transporterName;

  /// The delivery challan this transport record is linked to.
  final String linkedChallanId;

  /// Timestamp when this record was created.
  final DateTime createdAt;

  const TransportDetails({
    required this.id,
    required this.tenantId,
    required this.vehicleNumber,
    required this.lrNumber,
    required this.transporterName,
    required this.linkedChallanId,
    required this.createdAt,
  });

  /// Creates a copy with the given fields replaced.
  TransportDetails copyWith({
    String? id,
    String? tenantId,
    String? vehicleNumber,
    String? lrNumber,
    String? transporterName,
    String? linkedChallanId,
    DateTime? createdAt,
  }) {
    return TransportDetails(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      lrNumber: lrNumber ?? this.lrNumber,
      transporterName: transporterName ?? this.transporterName,
      linkedChallanId: linkedChallanId ?? this.linkedChallanId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportDetails &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tenantId == other.tenantId &&
          vehicleNumber == other.vehicleNumber &&
          lrNumber == other.lrNumber &&
          transporterName == other.transporterName &&
          linkedChallanId == other.linkedChallanId;

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    vehicleNumber,
    lrNumber,
    transporterName,
    linkedChallanId,
  );

  @override
  String toString() =>
      'TransportDetails(id: $id, tenant: $tenantId, vehicle: $vehicleNumber, '
      'lr: $lrNumber, transporter: $transporterName, '
      'challan: $linkedChallanId)';
}
