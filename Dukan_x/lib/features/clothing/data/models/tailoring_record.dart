import '../../../../core/utils/rid_generator.dart';
import '../../utils/clothing_business_rules.dart';

/// Soft-delete status for tailoring records (Requirement 1.6, 9.5).
enum TailoringStatus { active, deleted }

/// A tailoring measurement record carrying an RID identifier, tenant scoping,
/// customer/invoice originating context, validated measurements, priority,
/// a typed [DateTime] delivery date (Requirement 9.6), and a soft-delete
/// status flag.
///
/// Requirements validated: 9.6, 1.3, 1.4
class TailoringRecord {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}` (Req 1.3).
  final String id;

  /// Tenant scoping — every read/write/sync is bound to this (Req 1.4).
  final String tenantId;

  /// The customer for whom the measurements were taken (Req 9.1, 9.4).
  final String customerId;

  /// The originating invoice context (Req 9.1, 9.4).
  final String invoiceId;

  /// Validated measurements keyed by [MeasurementKey], each within the bounds
  /// defined by [ClothingBusinessRules.isValidMeasurement] (Req 9.3, 9.4).
  final Map<MeasurementKey, double> measurements;

  /// Priority level for the tailoring order (e.g. 'normal', 'urgent', 'express').
  final String priority;

  /// Typed delivery date — stored as [DateTime], never a split string (Req 9.6).
  final DateTime deliveryDate;

  /// Soft-delete status flag (Req 1.6, 9.5). Records are never hard-deleted.
  final TailoringStatus status;

  /// Optional notes attached to this measurement record.
  final String notes;

  const TailoringRecord({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.invoiceId,
    required this.measurements,
    required this.priority,
    required this.deliveryDate,
    this.status = TailoringStatus.active,
    this.notes = '',
  });

  /// Factory that creates a new [TailoringRecord] with an auto-generated RID.
  ///
  /// [measurements] are validated against [ClothingBusinessRules.isValidMeasurement];
  /// invalid entries are rejected (caller should pre-validate).
  factory TailoringRecord.create({
    required String tenantId,
    required String customerId,
    required String invoiceId,
    required Map<MeasurementKey, double> measurements,
    required String priority,
    required DateTime deliveryDate,
    String notes = '',
  }) {
    return TailoringRecord(
      id: RidGenerator.next(tenantId),
      tenantId: tenantId,
      customerId: customerId,
      invoiceId: invoiceId,
      measurements: Map.unmodifiable(measurements),
      priority: priority,
      deliveryDate: deliveryDate,
      status: TailoringStatus.active,
      notes: notes,
    );
  }

  /// Deserializes a [TailoringRecord] from a JSON map.
  ///
  /// Performs null/type guarding: required fields that are null or mis-typed
  /// produce a descriptive [FormatException]; optional fields fall back to
  /// defaults.
  factory TailoringRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException(
        'TailoringRecord.fromJson: "id" must be a non-empty String, got: $id',
      );
    }

    final tenantId = json['tenantId'];
    if (tenantId is! String || tenantId.isEmpty) {
      throw FormatException(
        'TailoringRecord.fromJson: "tenantId" must be a non-empty String, got: $tenantId',
      );
    }

    final customerId = json['customerId'];
    if (customerId is! String || customerId.isEmpty) {
      throw FormatException(
        'TailoringRecord.fromJson: "customerId" must be a non-empty String, got: $customerId',
      );
    }

    final invoiceId = json['invoiceId'];
    if (invoiceId is! String || invoiceId.isEmpty) {
      throw FormatException(
        'TailoringRecord.fromJson: "invoiceId" must be a non-empty String, got: $invoiceId',
      );
    }

    // Parse measurements: Map<String, dynamic> → Map<MeasurementKey, double>
    final rawMeasurements = json['measurements'];
    final Map<MeasurementKey, double> measurements = {};
    if (rawMeasurements is Map<String, dynamic>) {
      for (final entry in rawMeasurements.entries) {
        final key = _parseMeasurementKey(entry.key);
        if (key != null) {
          final value = entry.value;
          if (value is num) {
            measurements[key] = value.toDouble();
          }
        }
      }
    }

    // Parse priority with fallback
    final priority =
        (json['priority'] is String && (json['priority'] as String).isNotEmpty)
        ? json['priority'] as String
        : 'normal';

    // Parse deliveryDate — typed DateTime, not a split string (Req 9.6)
    final rawDeliveryDate = json['deliveryDate'];
    DateTime deliveryDate;
    if (rawDeliveryDate is String) {
      final parsed = DateTime.tryParse(rawDeliveryDate);
      if (parsed == null) {
        throw FormatException(
          'TailoringRecord.fromJson: "deliveryDate" could not be parsed as DateTime, got: $rawDeliveryDate',
        );
      }
      deliveryDate = parsed;
    } else if (rawDeliveryDate is int) {
      // Support milliseconds-since-epoch
      deliveryDate = DateTime.fromMillisecondsSinceEpoch(rawDeliveryDate);
    } else {
      throw FormatException(
        'TailoringRecord.fromJson: "deliveryDate" must be a String (ISO 8601) or int (epoch ms), got: $rawDeliveryDate',
      );
    }

    // Parse status with fallback to active
    final rawStatus = json['status'];
    final status = rawStatus == 'deleted'
        ? TailoringStatus.deleted
        : TailoringStatus.active;

    // Parse notes with fallback
    final notes = (json['notes'] is String) ? json['notes'] as String : '';

    return TailoringRecord(
      id: id,
      tenantId: tenantId,
      customerId: customerId,
      invoiceId: invoiceId,
      measurements: Map.unmodifiable(measurements),
      priority: priority,
      deliveryDate: deliveryDate,
      status: status,
      notes: notes,
    );
  }

  /// Serializes the record to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'customerId': customerId,
      'invoiceId': invoiceId,
      'measurements': measurements.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'priority': priority,
      'deliveryDate': deliveryDate.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  /// Returns a copy with the status set to [TailoringStatus.deleted] (soft delete).
  TailoringRecord softDelete() => copyWith(status: TailoringStatus.deleted);

  /// Returns a copy with the provided fields replaced.
  TailoringRecord copyWith({
    String? id,
    String? tenantId,
    String? customerId,
    String? invoiceId,
    Map<MeasurementKey, double>? measurements,
    String? priority,
    DateTime? deliveryDate,
    TailoringStatus? status,
    String? notes,
  }) {
    return TailoringRecord(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      customerId: customerId ?? this.customerId,
      invoiceId: invoiceId ?? this.invoiceId,
      measurements: measurements ?? this.measurements,
      priority: priority ?? this.priority,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  /// Parses a string to its corresponding [MeasurementKey], or null if unrecognized.
  static MeasurementKey? _parseMeasurementKey(String key) {
    switch (key) {
      case 'chest':
        return MeasurementKey.chest;
      case 'waist':
        return MeasurementKey.waist;
      case 'hip':
      case 'hips':
        return MeasurementKey.hip;
      case 'shoulder':
        return MeasurementKey.shoulder;
      case 'sleeve':
        return MeasurementKey.sleeve;
      case 'length':
        return MeasurementKey.length;
      case 'inseam':
        return MeasurementKey.inseam;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TailoringRecord) return false;
    return id == other.id &&
        tenantId == other.tenantId &&
        customerId == other.customerId &&
        invoiceId == other.invoiceId &&
        priority == other.priority &&
        deliveryDate == other.deliveryDate &&
        status == other.status &&
        notes == other.notes;
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    customerId,
    invoiceId,
    priority,
    deliveryDate,
    status,
    notes,
  );

  @override
  String toString() =>
      'TailoringRecord(id: $id, tenantId: $tenantId, customerId: $customerId, '
      'invoiceId: $invoiceId, priority: $priority, deliveryDate: $deliveryDate, '
      'status: $status, measurements: ${measurements.length} fields)';
}
