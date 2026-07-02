/// Status of an e-Way bill record.
///
/// Lifecycle:
/// - [captured]: Form fields saved locally; e-Way number not yet generated.
/// - [generated]: Real e-Way number obtained from NIC/GSP API.
/// - [blocked]: GSP credentials unavailable; generation cannot proceed.
///
/// Per Phase 0 §5 (External_Dependency_Gate: GSP_Credentials-unavailable),
/// all records created under the current configuration will have
/// `status = EWayStatus.blocked` and `ewayNumber = null`.
/// NO mock, simulation, or fabricated e-Way number is ever assigned.
enum EWayStatus {
  /// Captured locally — awaiting generation.
  captured,

  /// Real e-Way number generated via NIC/GSP API.
  generated,

  /// Generation blocked — GSP credentials are unavailable.
  blocked,
}

/// Persisted e-Way bill record.
///
/// All money is integer paise; id follows the RID pattern; tenant-scoped.
///
/// When GSP_Credentials are unavailable:
/// - [ewayNumber] is always `null`
/// - [status] is always [EWayStatus.blocked]
///
/// (Phase 9, Requirements 12.5, 12.6, 12.7)
class EWayRecord {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  final String id;

  /// Tenant scope — every query MUST filter by this field.
  final String tenantId;

  /// Consignment total in integer paise.
  final int consignmentPaise;

  /// Whether this is an inter-state movement.
  final bool interState;

  /// Transporter / transport company name.
  final String transporterName;

  /// Approximate distance in kilometres.
  final int approxDistanceKm;

  /// Vehicle registration number.
  final String vehicleNumber;

  /// Party's GSTIN (15-character alphanumeric).
  final String partyGstin;

  /// The real e-Way bill number from NIC/GSP, or `null` if [status] is
  /// [EWayStatus.blocked] or [EWayStatus.captured].
  ///
  /// NEVER fabricated, mocked, or simulated.
  final String? ewayNumber;

  /// Current status of this e-Way record.
  final EWayStatus status;

  /// Timestamp when this record was created.
  final DateTime createdAt;

  const EWayRecord({
    required this.id,
    required this.tenantId,
    required this.consignmentPaise,
    required this.interState,
    required this.transporterName,
    required this.approxDistanceKm,
    required this.vehicleNumber,
    required this.partyGstin,
    this.ewayNumber,
    required this.status,
    required this.createdAt,
  });
}
