/// Roster model for Universal Staff Management module.
///
/// Maps to the backend Roster entity (SK: ROSTER#{id}).
class RosterModel {
  final String id;
  final String businessId;
  final String date;
  final List<RosterAssignment> assignments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RosterModel({
    required this.id,
    required this.businessId,
    required this.date,
    this.assignments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RosterModel.fromJson(Map<String, dynamic> json) {
    return RosterModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      assignments:
          (json['assignments'] as List<dynamic>?)
              ?.map((e) => RosterAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'date': date,
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// A single shift assignment within a roster.
class RosterAssignment {
  final String employeeId;
  final String shiftId;

  const RosterAssignment({required this.employeeId, required this.shiftId});

  factory RosterAssignment.fromJson(Map<String, dynamic> json) {
    return RosterAssignment(
      employeeId: json['employeeId'] as String? ?? '',
      shiftId: json['shiftId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'shiftId': shiftId,
  };
}
