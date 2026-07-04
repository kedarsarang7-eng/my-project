/// Attendance event model for Universal Staff Management module.
///
/// Maps to the backend AttendanceEvent entity (SK: ATT#{isoTimestamp}#{eventId}).
/// Append-only, immutable record.
class AttendanceEventModel {
  final String eventId;
  final String employeeId;
  final String businessId;
  final String type;
  final String method;
  final DateTime timestamp;
  final GeoData? geo;
  final bool rejected;
  final String? rejectionReason;

  const AttendanceEventModel({
    required this.eventId,
    required this.employeeId,
    required this.businessId,
    required this.type,
    required this.method,
    required this.timestamp,
    this.geo,
    this.rejected = false,
    this.rejectionReason,
  });

  factory AttendanceEventModel.fromJson(Map<String, dynamic> json) {
    return AttendanceEventModel(
      eventId: json['eventId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      type: json['type'] as String? ?? 'check_in',
      method: json['method'] as String? ?? 'manual',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      geo: json['geo'] != null
          ? GeoData.fromJson(json['geo'] as Map<String, dynamic>)
          : null,
      rejected: json['rejected'] as bool? ?? false,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'employeeId': employeeId,
    'businessId': businessId,
    'type': type,
    'method': method,
    'timestamp': timestamp.toIso8601String(),
    'geo': geo?.toJson(),
    'rejected': rejected,
    'rejectionReason': rejectionReason,
  };
}

/// Geographic data for attendance events.
class GeoData {
  final double lat;
  final double lng;
  final bool withinFence;

  const GeoData({
    required this.lat,
    required this.lng,
    this.withinFence = true,
  });

  factory GeoData.fromJson(Map<String, dynamic> json) {
    return GeoData(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      withinFence: json['withinFence'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'withinFence': withinFence,
  };
}
