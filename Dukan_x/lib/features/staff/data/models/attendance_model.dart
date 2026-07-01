/// Attendance Status
enum AttendanceStatus { present, absent, halfDay, leave, holiday, weekOff }

/// Leave Type
enum LeaveType { casual, sick, paid, unpaid }

/// Staff Attendance Model
class AttendanceModel {
  final String id;
  final String staffId;
  final String userId;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int breakMinutes;
  final double hoursWorked;
  final double overtimeHours;
  final AttendanceStatus status;
  final LeaveType? leaveType;
  final String? notes;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final String markedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const AttendanceModel({
    required this.id,
    required this.staffId,
    required this.userId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.breakMinutes = 0,
    this.hoursWorked = 0.0,
    this.overtimeHours = 0.0,
    required this.status,
    this.leaveType,
    this.notes,
    this.checkInLatitude,
    this.checkInLongitude,
    this.markedBy = 'ADMIN',
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });
}

/// Extension for entity mapping
extension AttendanceModelX on AttendanceModel {
  /// Create from database entity
  static AttendanceModel fromEntity(dynamic entity) {
    return AttendanceModel(
      id: entity.id as String,
      staffId: entity.staffId as String,
      userId: entity.userId as String,
      date: entity.date as DateTime,
      checkIn: entity.checkIn as DateTime?,
      checkOut: entity.checkOut as DateTime?,
      breakMinutes: entity.breakMinutes as int,
      hoursWorked: entity.hoursWorked as double,
      overtimeHours: entity.overtimeHours as double,
      status: _parseStatus(entity.status as String),
      leaveType: entity.leaveType != null
          ? _parseLeaveType(entity.leaveType as String)
          : null,
      notes: entity.notes as String?,
      checkInLatitude: entity.checkInLatitude as double?,
      checkInLongitude: entity.checkInLongitude as double?,
      markedBy: entity.markedBy as String,
      createdAt: entity.createdAt as DateTime,
      updatedAt: entity.updatedAt as DateTime,
      isSynced: entity.isSynced as bool,
    );
  }

  static AttendanceStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'HALF_DAY':
        return AttendanceStatus.halfDay;
      case 'LEAVE':
        return AttendanceStatus.leave;
      case 'HOLIDAY':
        return AttendanceStatus.holiday;
      case 'WEEK_OFF':
        return AttendanceStatus.weekOff;
      default:
        return AttendanceStatus.absent;
    }
  }

  static LeaveType _parseLeaveType(String type) {
    switch (type.toUpperCase()) {
      case 'CASUAL':
        return LeaveType.casual;
      case 'SICK':
        return LeaveType.sick;
      case 'PAID':
        return LeaveType.paid;
      default:
        return LeaveType.unpaid;
    }
  }
}

/// Attendance summary for a period
class AttendanceSummary {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final double totalHoursWorked;
  final double overtimeHours;

  AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.totalHoursWorked,
    required this.overtimeHours,
  });

  double get attendancePercentage {
    if (totalDays == 0) return 0;
    return (presentDays + (halfDays * 0.5)) / totalDays * 100;
  }
}
