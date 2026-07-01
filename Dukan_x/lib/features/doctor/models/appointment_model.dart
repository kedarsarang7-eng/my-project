enum AppointmentStatus { scheduled, completed, cancelled }

class AppointmentModel {
  String id;
  String doctorId;
  String patientId;
  DateTime scheduledTime;
  AppointmentStatus status;
  String? purpose;
  String? notes;

  /// Slot duration in minutes. Nullable for legacy rows; defaults to 15 when
  /// not specified during scheduling.
  int? slotDurationMinutes;
  DateTime createdAt;
  DateTime updatedAt;

  /// Default slot duration (minutes) used when [slotDurationMinutes] is null.
  static const int defaultSlotDuration = 15;

  /// Effective slot duration — uses [slotDurationMinutes] if set, otherwise
  /// [defaultSlotDuration].
  int get effectiveSlotDuration => slotDurationMinutes ?? defaultSlotDuration;

  /// The end time of this appointment's slot based on the effective duration.
  DateTime get slotEndTime =>
      scheduledTime.add(Duration(minutes: effectiveSlotDuration));

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.scheduledTime,
    this.status = AppointmentStatus.scheduled,
    this.purpose,
    this.notes,
    this.slotDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] ?? '',
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      scheduledTime:
          DateTime.tryParse(map['scheduledTime'] ?? '') ?? DateTime.now(),
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'scheduled'),
        orElse: () => AppointmentStatus.scheduled,
      ),
      purpose: map['purpose'],
      notes: map['notes'],
      slotDurationMinutes: map['slotDurationMinutes'] as int?,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'doctorId': doctorId,
    'patientId': patientId,
    'scheduledTime': scheduledTime.toIso8601String(),
    'status': status.name,
    'purpose': purpose,
    'notes': notes,
    'slotDurationMinutes': slotDurationMinutes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  AppointmentModel copyWith({
    String? id,
    String? doctorId,
    String? patientId,
    DateTime? scheduledTime,
    AppointmentStatus? status,
    String? purpose,
    String? notes,
    int? slotDurationMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
