// ============================================================================
// ACADEMIC COACHING — DOMAIN MODELS
// ============================================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum StudentStatus { active, inactive, graduated, transferred }

enum BatchStatus { upcoming, active, completed }

enum BatchType { regular, crash, online, weekend }

enum FeeStatus { pending, partial, paid, overdue }

enum AttendanceStatus { present, absent, leave }

enum EmploymentType { fullTime, partTime, visiting }

enum ExamType { internal, mock, unitTest, final_, quiz }

enum MaterialType { notes, practicePaper, solution, videoLink, reference }

enum PaymentMethod { cash, upi, card, cheque, bankTransfer, online }

// ---------------------------------------------------------------------------
// Student
// ---------------------------------------------------------------------------

class AcStudent {
  final String id;
  final String studentId;
  final String firstName;
  final String lastName;
  final String? dob;
  final String? gender;
  final String phone;
  final String? parentPhone;
  final String? parentName;
  final String? email;
  final String? address;
  final String? schoolName;
  final String? currentClass;
  final String? board;
  final List<String> enrolledCourseIds;
  final List<String> enrolledBatchIds;
  final String? photoS3Key;
  final String? photoUrl;
  final String? referralSource;
  final String? branchId;
  final StudentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enriched fields (not stored in DB)
  final List<String>? batchNames;
  final double? totalFees;
  final double? totalPaid;
  final double? balance;
  final int? attendancePercentage;

  // ── Integer Paise fields (source of truth — Mini_Gate Phase 7) ──
  // Populated directly from wire `*Paisa` values WITHOUT dividing.
  // Old double fields retained for backward compat; prefer these for logic.
  final int? totalFeesPaise;
  final int? totalPaidPaise;
  final int? balancePaise;

  AcStudent({
    required this.id,
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.dob,
    this.gender,
    required this.phone,
    this.parentPhone,
    this.parentName,
    this.email,
    this.address,
    this.schoolName,
    this.currentClass,
    this.board,
    this.enrolledCourseIds = const [],
    this.enrolledBatchIds = const [],
    this.photoS3Key,
    this.photoUrl,
    this.referralSource,
    this.branchId,
    this.status = StudentStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.batchNames,
    this.totalFees,
    this.totalPaid,
    this.balance,
    this.attendancePercentage,
    this.totalFeesPaise,
    this.totalPaidPaise,
    this.balancePaise,
  });

  String get fullName => '$firstName $lastName';

  factory AcStudent.fromJson(Map<String, dynamic> json) {
    return AcStudent(
      id: json['id'] ?? '',
      studentId: json['studentId'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      dob: json['dob'],
      gender: json['gender'],
      phone: json['phone'] ?? '',
      parentPhone: json['parentPhone'],
      parentName: json['parentName'],
      email: json['email'],
      address: json['address'],
      schoolName: json['schoolName'],
      currentClass: json['currentClass'],
      board: json['board'],
      enrolledCourseIds: List<String>.from(json['enrolledCourseIds'] ?? []),
      enrolledBatchIds: List<String>.from(json['enrolledBatchIds'] ?? []),
      photoS3Key: json['photoS3Key'],
      photoUrl: json['photoUrl'],
      referralSource: json['referralSource'],
      branchId: json['branchId'],
      status: _parseStudentStatus(json['status']),
      notes: json['notes'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      batchNames: json['batchNames'] != null
          ? List<String>.from(json['batchNames'])
          : null,
      totalFees: json['feeSummary'] != null
          ? (json['feeSummary']['totalFees'] ?? 0).toDouble()
          : null,
      totalPaid: json['feeSummary'] != null
          ? (json['feeSummary']['totalPaid'] ?? 0).toDouble()
          : null,
      balance: json['feeSummary'] != null
          ? (json['feeSummary']['balance'] ?? 0).toDouble()
          : null,
      attendancePercentage: json['attendanceSummary'] != null
          ? json['attendanceSummary']['percentage']
          : null,
      // Integer Paise — populated directly from wire values WITHOUT dividing.
      // Wire sends `*Paisa` integer fields; these capture them as-is.
      totalFeesPaise: json['feeSummary'] != null
          ? (json['feeSummary']['totalFeesPaisa'] ??
                    json['feeSummary']['totalFees'])
                as int?
          : null,
      totalPaidPaise: json['feeSummary'] != null
          ? (json['feeSummary']['totalPaidPaisa'] ??
                    json['feeSummary']['totalPaid'])
                as int?
          : null,
      balancePaise: json['feeSummary'] != null
          ? (json['feeSummary']['balancePaisa'] ??
                    json['feeSummary']['balance'])
                as int?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'dob': dob,
      'gender': gender,
      'phone': phone,
      'parentPhone': parentPhone,
      'parentName': parentName,
      'email': email,
      'address': address,
      'schoolName': schoolName,
      'currentClass': currentClass,
      'board': board,
      'enrolledCourseIds': enrolledCourseIds,
      'enrolledBatchIds': enrolledBatchIds,
      'photoS3Key': photoS3Key,
      'referralSource': referralSource,
      'branchId': branchId,
      'status': status.name,
      'notes': notes,
    };
  }

  static StudentStatus _parseStudentStatus(String? status) {
    switch (status) {
      case 'inactive':
        return StudentStatus.inactive;
      case 'graduated':
        return StudentStatus.graduated;
      case 'transferred':
        return StudentStatus.transferred;
      default:
        return StudentStatus.active;
    }
  }

  Color get statusColor {
    switch (status) {
      case StudentStatus.active:
        return Colors.green;
      case StudentStatus.inactive:
        return Colors.red;
      case StudentStatus.graduated:
        return Colors.blue;
      case StudentStatus.transferred:
        return Colors.orange;
    }
  }

  String get statusLabel {
    switch (status) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.inactive:
        return 'Inactive';
      case StudentStatus.graduated:
        return 'Graduated';
      case StudentStatus.transferred:
        return 'Transferred';
    }
  }
}

// ---------------------------------------------------------------------------
// Batch
// ---------------------------------------------------------------------------

class AcBatch {
  final String id;
  final String name;
  final String? courseId;
  final String? courseName;
  final String? branchId;
  final String? batchCode;
  final List<AcScheduleSlot> schedule;
  final List<String> facultyIds;
  final String? startDate;
  final String? endDate;
  final int maxCapacity;
  final int enrolledCount;
  final BatchStatus status;
  final BatchType batchType;
  final DateTime createdAt;
  final DateTime updatedAt;

  AcBatch({
    required this.id,
    required this.name,
    this.courseId,
    this.courseName,
    this.branchId,
    this.batchCode,
    this.schedule = const [],
    this.facultyIds = const [],
    this.startDate,
    this.endDate,
    this.maxCapacity = 30,
    this.enrolledCount = 0,
    this.status = BatchStatus.upcoming,
    this.batchType = BatchType.regular,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcBatch.fromJson(Map<String, dynamic> json) {
    return AcBatch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      courseId: json['courseId'],
      courseName: json['courseName'],
      branchId: json['branchId'],
      batchCode: json['batchCode'],
      schedule: (json['schedule'] as List? ?? [])
          .map((s) => AcScheduleSlot.fromJson(s))
          .toList(),
      facultyIds: (json['facultyIds'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      startDate: json['startDate'],
      endDate: json['endDate'],
      maxCapacity: json['maxCapacity'] ?? 30,
      enrolledCount: json['enrolledCount'] ?? 0,
      status: _parseBatchStatus(json['status']),
      batchType: _parseBatchType(json['batchType']),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  int get availableSeats => maxCapacity - enrolledCount;
  bool get isFull => enrolledCount >= maxCapacity;
  double get occupancyPercentage => (enrolledCount / maxCapacity) * 100;

  static BatchStatus _parseBatchStatus(String? status) {
    switch (status) {
      case 'active':
        return BatchStatus.active;
      case 'completed':
        return BatchStatus.completed;
      default:
        return BatchStatus.upcoming;
    }
  }

  static BatchType _parseBatchType(String? type) {
    switch (type) {
      case 'crash':
        return BatchType.crash;
      case 'online':
        return BatchType.online;
      case 'weekend':
        return BatchType.weekend;
      default:
        return BatchType.regular;
    }
  }

  Color get statusColor {
    switch (status) {
      case BatchStatus.upcoming:
        return Colors.orange;
      case BatchStatus.active:
        return Colors.green;
      case BatchStatus.completed:
        return Colors.grey;
    }
  }
}

class AcScheduleSlot {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? subjectId;
  final String? subjectName;
  final String? facultyId;
  final String? facultyName;
  final String? roomNo;

  AcScheduleSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.subjectId,
    this.subjectName,
    this.facultyId,
    this.facultyName,
    this.roomNo,
  });

  factory AcScheduleSlot.fromJson(Map<String, dynamic> json) {
    return AcScheduleSlot(
      dayOfWeek: json['dayOfWeek'] ?? 1,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      subjectId: json['subjectId'],
      subjectName: json['subjectName'],
      facultyId: json['facultyId'],
      facultyName: json['facultyName'],
      roomNo: json['roomNo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'subjectId': subjectId,
      'facultyId': facultyId,
      'roomNo': roomNo,
    };
  }

  String get dayName {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOfWeek] ?? '';
  }
}

// ---------------------------------------------------------------------------
// Course
// ---------------------------------------------------------------------------

class AcCourse {
  final String id;
  final String name;
  final String? description;
  final List<AcSubject> subjects;
  final Map<String, dynamic>? duration;
  final String? targetExam;
  final double totalFee;
  final double materialFee;
  final double admissionFee;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Integer Paise fields (source of truth — Mini_Gate Phase 7) ──
  final int totalFeePaise;
  final int materialFeePaise;
  final int admissionFeePaise;

  AcCourse({
    required this.id,
    required this.name,
    this.description,
    this.subjects = const [],
    this.duration,
    this.targetExam,
    this.totalFee = 0,
    this.materialFee = 0,
    this.admissionFee = 0,
    this.totalFeePaise = 0,
    this.materialFeePaise = 0,
    this.admissionFeePaise = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcCourse.fromJson(Map<String, dynamic> json) {
    return AcCourse(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      subjects: (json['subjects'] as List? ?? [])
          .map((s) => AcSubject.fromJson(s))
          .toList(),
      duration: json['duration'],
      targetExam: json['targetExam'],
      totalFee: (json['totalFee'] ?? json['totalFeePaisa'] ?? 0) is int
          ? (json['totalFeePaisa'] ?? 0) / 100
          : (json['totalFee'] ?? 0).toDouble(),
      materialFee: (json['materialFee'] ?? json['materialFeePaisa'] ?? 0) is int
          ? (json['materialFeePaisa'] ?? 0) / 100
          : (json['materialFee'] ?? 0).toDouble(),
      admissionFee:
          (json['admissionFee'] ?? json['admissionFeePaisa'] ?? 0) is int
          ? (json['admissionFeePaisa'] ?? 0) / 100
          : (json['admissionFee'] ?? 0).toDouble(),
      // Integer Paise — directly from wire without dividing
      totalFeePaise:
          (json['totalFeePaisa'] ?? json['totalFee'] ?? 0) as int? ?? 0,
      materialFeePaise:
          (json['materialFeePaisa'] ?? json['materialFee'] ?? 0) as int? ?? 0,
      admissionFeePaise:
          (json['admissionFeePaisa'] ?? json['admissionFee'] ?? 0) as int? ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'duration': duration,
      'targetExam': targetExam,
      'totalFee': totalFee,
      'materialFee': materialFee,
      'admissionFee': admissionFee,
    };
  }
}

class AcSubject {
  final String id;
  final String name;
  final int totalClasses;

  AcSubject({required this.id, required this.name, this.totalClasses = 0});

  factory AcSubject.fromJson(Map<String, dynamic> json) {
    return AcSubject(
      id: json['subjectId'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      totalClasses: json['totalClasses'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'subjectId': id, 'name': name, 'totalClasses': totalClasses};
  }
}

// ---------------------------------------------------------------------------
// Fee Invoice
// ---------------------------------------------------------------------------

class AcInvoice {
  final String id;
  final String invoiceNumber;
  final String studentId;
  final String? studentName;
  final List<AcFeeComponent> feeComponents;
  final List<String> discountIds;
  final double discountAmount;
  final double adjustmentAmount;
  final String? adjustmentNote;
  final double totalAmount;
  final double paidAmount;
  final double balance;
  final FeeStatus status;
  final String? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Integer Paise fields (source of truth — Mini_Gate Phase 7) ──
  final int totalAmountPaise;
  final int paidAmountPaise;
  final int balancePaise;
  final int discountAmountPaise;
  final int adjustmentAmountPaise;

  AcInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.studentId,
    this.studentName,
    this.feeComponents = const [],
    this.discountIds = const [],
    this.discountAmount = 0,
    this.adjustmentAmount = 0,
    this.adjustmentNote,
    required this.totalAmount,
    this.paidAmount = 0,
    this.balance = 0,
    this.totalAmountPaise = 0,
    this.paidAmountPaise = 0,
    this.balancePaise = 0,
    this.discountAmountPaise = 0,
    this.adjustmentAmountPaise = 0,
    this.status = FeeStatus.pending,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcInvoice.fromJson(Map<String, dynamic> json) {
    return AcInvoice(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'],
      feeComponents: (json['feeComponents'] as List? ?? [])
          .map((c) => AcFeeComponent.fromJson(c))
          .toList(),
      discountIds: List<String>.from(json['discountIds'] ?? []),
      discountAmount:
          (json['discountAmount'] ?? json['discountAmountPaisa'] ?? 0) is int
          ? (json['discountAmountPaisa'] ?? 0) / 100
          : (json['discountAmount'] ?? 0).toDouble(),
      adjustmentAmount:
          (json['adjustmentAmount'] ?? json['adjustmentAmountPaisa'] ?? 0)
              is int
          ? (json['adjustmentAmountPaisa'] ?? 0) / 100
          : (json['adjustmentAmount'] ?? 0).toDouble(),
      adjustmentNote: json['adjustmentNote'],
      totalAmount: (json['totalAmount'] ?? json['totalAmountPaisa'] ?? 0) is int
          ? (json['totalAmountPaisa'] ?? 0) / 100
          : (json['totalAmount'] ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] ?? json['paidAmountPaisa'] ?? 0) is int
          ? (json['paidAmountPaisa'] ?? 0) / 100
          : (json['paidAmount'] ?? 0).toDouble(),
      balance: (json['balance'] ?? json['balancePaisa'] ?? 0) is int
          ? (json['balancePaisa'] ?? 0) / 100
          : (json['balance'] ?? 0).toDouble(),
      // Integer Paise — directly from wire without dividing
      totalAmountPaise:
          (json['totalAmountPaisa'] ?? json['totalAmount'] ?? 0) as int? ?? 0,
      paidAmountPaise:
          (json['paidAmountPaisa'] ?? json['paidAmount'] ?? 0) as int? ?? 0,
      balancePaise: (json['balancePaisa'] ?? json['balance'] ?? 0) as int? ?? 0,
      discountAmountPaise:
          (json['discountAmountPaisa'] ?? json['discountAmount'] ?? 0)
              as int? ??
          0,
      adjustmentAmountPaise:
          (json['adjustmentAmountPaisa'] ?? json['adjustmentAmount'] ?? 0)
              as int? ??
          0,
      status: _parseFeeStatus(json['status']),
      dueDate: json['dueDate'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static FeeStatus _parseFeeStatus(String? status) {
    switch (status) {
      case 'paid':
        return FeeStatus.paid;
      case 'partial':
        return FeeStatus.partial;
      case 'overdue':
        return FeeStatus.overdue;
      default:
        return FeeStatus.pending;
    }
  }

  Color get statusColor {
    switch (status) {
      case FeeStatus.paid:
        return Colors.green;
      case FeeStatus.partial:
        return Colors.orange;
      case FeeStatus.pending:
        return Colors.blue;
      case FeeStatus.overdue:
        return Colors.red;
    }
  }

  String get statusLabel {
    switch (status) {
      case FeeStatus.paid:
        return 'Paid';
      case FeeStatus.partial:
        return 'Partial';
      case FeeStatus.pending:
        return 'Pending';
      case FeeStatus.overdue:
        return 'Overdue';
    }
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return status != FeeStatus.paid &&
        DateTime.parse(dueDate!).isBefore(DateTime.now());
  }
}

class AcFeeComponent {
  final String name;
  final double amount;
  final bool isOneTime;
  final String? billingCycle;

  // ── Integer Paise field (source of truth — Mini_Gate Phase 7) ──
  final int amountPaise;

  AcFeeComponent({
    required this.name,
    required this.amount,
    this.amountPaise = 0,
    this.isOneTime = true,
    this.billingCycle,
  });

  factory AcFeeComponent.fromJson(Map<String, dynamic> json) {
    return AcFeeComponent(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? json['amountPaisa'] ?? 0) is int
          ? (json['amountPaisa'] ?? 0) / 100
          : (json['amount'] ?? 0).toDouble(),
      // Integer Paise — directly from wire without dividing
      amountPaise: (json['amountPaisa'] ?? json['amount'] ?? 0) as int? ?? 0,
      isOneTime: json['isOneTime'] ?? true,
      billingCycle: json['billingCycle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'isOneTime': isOneTime,
      'billingCycle': billingCycle,
    };
  }
}

class AcPayment {
  final String id;
  final String invoiceId;
  final String studentId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? transactionRef;
  final String? paymentDate;
  final String? remarks;
  final String? collectedBy;
  final DateTime createdAt;

  // ── Integer Paise field (source of truth — Mini_Gate Phase 7) ──
  final int amountPaise;

  AcPayment({
    required this.id,
    required this.invoiceId,
    required this.studentId,
    required this.amount,
    this.amountPaise = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.transactionRef,
    this.paymentDate,
    this.remarks,
    this.collectedBy,
    required this.createdAt,
  });

  factory AcPayment.fromJson(Map<String, dynamic> json) {
    return AcPayment(
      id: json['id'] ?? '',
      invoiceId: json['invoiceId'] ?? '',
      studentId: json['studentId'] ?? '',
      amount: (json['amount'] ?? json['amountPaisa'] ?? 0) is int
          ? (json['amountPaisa'] ?? 0) / 100
          : (json['amount'] ?? 0).toDouble(),
      // Integer Paise — directly from wire without dividing
      amountPaise: (json['amountPaisa'] ?? json['amount'] ?? 0) as int? ?? 0,
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      transactionRef: json['transactionRef'],
      paymentDate: json['paymentDate'],
      remarks: json['remarks'],
      collectedBy: json['collectedBy'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static PaymentMethod _parsePaymentMethod(String? method) {
    switch (method) {
      case 'upi':
        return PaymentMethod.upi;
      case 'card':
        return PaymentMethod.card;
      case 'cheque':
        return PaymentMethod.cheque;
      case 'bankTransfer':
        return PaymentMethod.bankTransfer;
      case 'online':
        return PaymentMethod.online;
      default:
        return PaymentMethod.cash;
    }
  }
}

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

class AcAttendance {
  final String id;
  final String batchId;
  final String? batchName;
  final String? subjectId;
  final String? subjectName;
  final String date;
  final String? facultyId;
  final Map<String, AttendanceStatus> records;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int totalCount;
  final DateTime createdAt;

  AcAttendance({
    required this.id,
    required this.batchId,
    this.batchName,
    this.subjectId,
    this.subjectName,
    required this.date,
    this.facultyId,
    this.records = const {},
    this.presentCount = 0,
    this.absentCount = 0,
    this.leaveCount = 0,
    this.totalCount = 0,
    required this.createdAt,
  });

  factory AcAttendance.fromJson(Map<String, dynamic> json) {
    final recordsMap = (json['records'] as Map? ?? {}).map(
      (key, value) =>
          MapEntry(key.toString(), _parseAttendanceStatus(value.toString())),
    );

    return AcAttendance(
      id: json['id'] ?? '',
      batchId: json['batchId'] ?? '',
      batchName: json['batchName'],
      subjectId: json['subjectId'],
      subjectName: json['subjectName'],
      date: json['date'] ?? '',
      facultyId: json['facultyId'],
      records: recordsMap,
      presentCount: json['presentCount'] ?? 0,
      absentCount: json['absentCount'] ?? 0,
      leaveCount: json['leaveCount'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static AttendanceStatus _parseAttendanceStatus(String? status) {
    switch (status) {
      case 'P':
        return AttendanceStatus.present;
      case 'L':
        return AttendanceStatus.leave;
      default:
        return AttendanceStatus.absent;
    }
  }

  static String attendanceToString(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.leave:
        return 'L';
      case AttendanceStatus.absent:
        return 'A';
    }
  }

  Color getStatusColor(String studentId) {
    final status = records[studentId];
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.leave:
        return Colors.orange;
      case AttendanceStatus.absent:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ---------------------------------------------------------------------------
// Faculty
// ---------------------------------------------------------------------------

class AcFaculty {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final List<String> specialization;
  final List<Map<String, dynamic>> qualifications;
  final Map<String, dynamic>? experience;
  final EmploymentType employmentType;
  final AcSalaryStructure salaryStructure;
  final String? joiningDate;
  final List<String> branchIds;
  final bool isActive;
  final List<String> assignedBatchIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  AcFaculty({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.specialization = const [],
    this.qualifications = const [],
    this.experience,
    this.employmentType = EmploymentType.fullTime,
    required this.salaryStructure,
    this.joiningDate,
    this.branchIds = const [],
    this.isActive = true,
    this.assignedBatchIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcFaculty.fromJson(Map<String, dynamic> json) {
    return AcFaculty(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      specialization: List<String>.from(json['specialization'] ?? []),
      qualifications: List<Map<String, dynamic>>.from(
        json['qualifications'] ?? [],
      ),
      experience: json['experience'],
      employmentType: _parseEmploymentType(json['employmentType']),
      salaryStructure: AcSalaryStructure.fromJson(
        json['salaryStructure'] ?? {},
      ),
      joiningDate: json['joiningDate'],
      branchIds: List<String>.from(json['branchIds'] ?? []),
      isActive: json['isActive'] ?? true,
      assignedBatchIds: List<String>.from(json['assignedBatchIds'] ?? []),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static EmploymentType _parseEmploymentType(String? type) {
    switch (type) {
      case 'part_time':
        return EmploymentType.partTime;
      case 'visiting':
        return EmploymentType.visiting;
      default:
        return EmploymentType.fullTime;
    }
  }

  String get roleLabel {
    switch (employmentType) {
      case EmploymentType.fullTime:
        return 'Full Time';
      case EmploymentType.partTime:
        return 'Part Time';
      case EmploymentType.visiting:
        return 'Visiting';
    }
  }

  Color get roleColor {
    switch (employmentType) {
      case EmploymentType.fullTime:
        return const Color(0xFF2196F3);
      case EmploymentType.partTime:
        return const Color(0xFF4CAF50);
      case EmploymentType.visiting:
        return const Color(0xFFFF9800);
    }
  }
}

class AcSalaryStructure {
  final String type;
  final double fixedAmount;
  final double perClassRate;
  final int classesCommitted;

  AcSalaryStructure({
    this.type = 'fixed',
    this.fixedAmount = 0,
    this.perClassRate = 0,
    this.classesCommitted = 0,
  });

  factory AcSalaryStructure.fromJson(Map<String, dynamic> json) {
    return AcSalaryStructure(
      type: json['type'] ?? 'fixed',
      fixedAmount: (json['fixedAmount'] ?? json['fixedAmountPaisa'] ?? 0) is int
          ? (json['fixedAmountPaisa'] ?? 0) / 100
          : (json['fixedAmount'] ?? 0).toDouble(),
      perClassRate:
          (json['perClassRate'] ?? json['perClassRatePaisa'] ?? 0) is int
          ? (json['perClassRatePaisa'] ?? 0) / 100
          : (json['perClassRate'] ?? 0).toDouble(),
      classesCommitted: json['classesCommitted'] ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Exam & Results
// ---------------------------------------------------------------------------

class AcExam {
  final String id;
  final String name;
  final ExamType type;
  final List<String> batchIds;
  final String date;
  final String? duration;
  final String? venue;
  final List<AcExamSubject> subjects;
  final String? syllabusS3Key;
  final String status;
  final DateTime createdAt;

  AcExam({
    required this.id,
    required this.name,
    this.type = ExamType.internal,
    this.batchIds = const [],
    required this.date,
    this.duration,
    this.venue,
    this.subjects = const [],
    this.syllabusS3Key,
    this.status = 'scheduled',
    required this.createdAt,
  });

  factory AcExam.fromJson(Map<String, dynamic> json) {
    return AcExam(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: _parseExamType(json['type']),
      batchIds: List<String>.from(json['batchIds'] ?? []),
      date: json['date'] ?? '',
      duration: json['duration'],
      venue: json['venue'],
      subjects: (json['subjects'] as List? ?? [])
          .map((s) => AcExamSubject.fromJson(s))
          .toList(),
      syllabusS3Key: json['syllabusS3Key'],
      status: json['status'] ?? 'scheduled',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static ExamType _parseExamType(String? type) {
    switch (type) {
      case 'mock':
        return ExamType.mock;
      case 'unit_test':
        return ExamType.unitTest;
      case 'final':
        return ExamType.final_;
      case 'quiz':
        return ExamType.quiz;
      default:
        return ExamType.internal;
    }
  }

  bool get isCompleted => status == 'completed';
  bool get isScheduled => status == 'scheduled';
}

class AcExamSubject {
  final String subjectId;
  final String? subjectName;
  final int maxMarks;
  final int passingMarks;

  AcExamSubject({
    required this.subjectId,
    this.subjectName,
    this.maxMarks = 100,
    this.passingMarks = 35,
  });

  factory AcExamSubject.fromJson(Map<String, dynamic> json) {
    return AcExamSubject(
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subjectName'],
      maxMarks: json['maxMarks'] ?? 100,
      passingMarks: json['passingMarks'] ?? 35,
    );
  }
}

class AcResult {
  final String id;
  final String examId;
  final String? examName;
  final String studentId;
  final String? studentName;
  final List<AcSubjectResult> subjectResults;
  final double totalObtained;
  final double totalMax;
  final double percentage;
  final String grade;
  final String status;
  final String? remarks;
  final DateTime createdAt;

  AcResult({
    required this.id,
    required this.examId,
    this.examName,
    required this.studentId,
    this.studentName,
    this.subjectResults = const [],
    this.totalObtained = 0,
    this.totalMax = 0,
    this.percentage = 0,
    this.grade = 'F',
    this.status = 'fail',
    this.remarks,
    required this.createdAt,
  });

  factory AcResult.fromJson(Map<String, dynamic> json) {
    return AcResult(
      id: json['id'] ?? '',
      examId: json['examId'] ?? '',
      examName: json['examName'],
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'],
      subjectResults: (json['subjectResults'] as List? ?? [])
          .map((r) => AcSubjectResult.fromJson(r))
          .toList(),
      totalObtained: (json['totalObtained'] ?? 0).toDouble(),
      totalMax: (json['totalMax'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      grade: json['grade'] ?? 'F',
      status: json['status'] ?? 'fail',
      remarks: json['remarks'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  bool get isPass => status == 'pass';

  Color get gradeColor {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade == 'C') return Colors.orange;
    return Colors.red;
  }
}

class AcSubjectResult {
  final String subjectId;
  final String? subjectName;
  final double marksObtained;
  final double maxMarks;
  final bool isAbsent;

  AcSubjectResult({
    required this.subjectId,
    this.subjectName,
    this.marksObtained = 0,
    this.maxMarks = 100,
    this.isAbsent = false,
  });

  factory AcSubjectResult.fromJson(Map<String, dynamic> json) {
    return AcSubjectResult(
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subjectName'],
      marksObtained: (json['marksObtained'] ?? 0).toDouble(),
      maxMarks: (json['maxMarks'] ?? 100).toDouble(),
      isAbsent: json['isAbsent'] ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Study Material
// ---------------------------------------------------------------------------

class AcMaterial {
  final String id;
  final String title;
  final String subjectId;
  final String? subjectName;
  final List<String> batchIds;
  final List<String> courseIds;
  final MaterialType type;
  final String? s3Key;
  final int? fileSize;
  final String? fileType;
  final bool isFree;
  final double materialFee;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final int downloadCount;
  final DateTime createdAt;

  AcMaterial({
    required this.id,
    required this.title,
    required this.subjectId,
    this.subjectName,
    this.batchIds = const [],
    this.courseIds = const [],
    this.type = MaterialType.notes,
    this.s3Key,
    this.fileSize,
    this.fileType,
    this.isFree = false,
    this.materialFee = 0,
    required this.publishedAt,
    this.expiresAt,
    this.downloadCount = 0,
    required this.createdAt,
  });

  factory AcMaterial.fromJson(Map<String, dynamic> json) {
    return AcMaterial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subjectName'],
      batchIds: List<String>.from(json['batchIds'] ?? []),
      courseIds: List<String>.from(json['courseIds'] ?? []),
      type: _parseMaterialType(json['type']),
      s3Key: json['s3Key'],
      fileSize: json['fileSize'],
      fileType: json['fileType'],
      isFree: json['isFree'] ?? false,
      materialFee: (json['materialFee'] ?? json['materialFeePaisa'] ?? 0) is int
          ? (json['materialFeePaisa'] ?? 0) / 100
          : (json['materialFee'] ?? 0).toDouble(),
      publishedAt: DateTime.parse(
        json['publishedAt'] ?? DateTime.now().toIso8601String(),
      ),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      downloadCount: json['downloadCount'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static MaterialType _parseMaterialType(String? type) {
    switch (type) {
      case 'practice_paper':
        return MaterialType.practicePaper;
      case 'solution':
        return MaterialType.solution;
      case 'video_link':
        return MaterialType.videoLink;
      case 'reference':
        return MaterialType.reference;
      default:
        return MaterialType.notes;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case MaterialType.notes:
        return Icons.description;
      case MaterialType.practicePaper:
        return Icons.assignment;
      case MaterialType.solution:
        return Icons.check_circle;
      case MaterialType.videoLink:
        return Icons.video_library;
      case MaterialType.reference:
        return Icons.book;
    }
  }

  String get typeLabel {
    switch (type) {
      case MaterialType.notes:
        return 'Notes';
      case MaterialType.practicePaper:
        return 'Practice Paper';
      case MaterialType.solution:
        return 'Solution';
      case MaterialType.videoLink:
        return 'Video';
      case MaterialType.reference:
        return 'Reference';
    }
  }
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class AcDashboardStats {
  final AcStudentStats students;
  final AcBatchStats batches;
  final int courses;
  final int faculty;
  final AcRevenueStats revenue;
  final AcOverdueStats overdue;
  final AcTodayAttendance todayAttendance;
  final AcRecentActivity recentActivity;

  AcDashboardStats({
    required this.students,
    required this.batches,
    required this.courses,
    required this.faculty,
    required this.revenue,
    required this.overdue,
    required this.todayAttendance,
    required this.recentActivity,
  });

  factory AcDashboardStats.fromJson(Map<String, dynamic> json) {
    return AcDashboardStats(
      students: AcStudentStats.fromJson(json['students'] ?? {}),
      batches: AcBatchStats.fromJson(json['batches'] ?? {}),
      courses: json['courses'] ?? 0,
      faculty: json['faculty'] ?? 0,
      revenue: AcRevenueStats.fromJson(json['revenue'] ?? {}),
      overdue: AcOverdueStats.fromJson(json['overdue'] ?? {}),
      todayAttendance: AcTodayAttendance.fromJson(
        json['todayAttendance'] ?? {},
      ),
      recentActivity: AcRecentActivity.fromJson(json['recentActivity'] ?? {}),
    );
  }
}

class AcStudentStats {
  final int total;
  final int active;
  final int newThisMonth;
  final int inactive;

  AcStudentStats({
    required this.total,
    required this.active,
    required this.newThisMonth,
    required this.inactive,
  });

  factory AcStudentStats.fromJson(Map<String, dynamic> json) {
    return AcStudentStats(
      total: json['total'] ?? 0,
      active: json['active'] ?? 0,
      newThisMonth: json['newThisMonth'] ?? 0,
      inactive: json['inactive'] ?? 0,
    );
  }
}

class AcBatchStats {
  final int total;
  final int active;
  final int upcoming;
  final int completed;

  AcBatchStats({
    required this.total,
    required this.active,
    required this.upcoming,
    required this.completed,
  });

  factory AcBatchStats.fromJson(Map<String, dynamic> json) {
    return AcBatchStats(
      total: json['total'] ?? 0,
      active: json['active'] ?? 0,
      upcoming: json['upcoming'] ?? 0,
      completed: json['completed'] ?? 0,
    );
  }
}

class AcRevenueStats {
  final double total;
  final double collected;
  final double pending;
  final double monthly;

  AcRevenueStats({
    required this.total,
    required this.collected,
    required this.pending,
    required this.monthly,
  });

  factory AcRevenueStats.fromJson(Map<String, dynamic> json) {
    return AcRevenueStats(
      total: (json['total'] ?? 0).toDouble(),
      collected: (json['collected'] ?? 0).toDouble(),
      pending: (json['pending'] ?? 0).toDouble(),
      monthly: (json['monthly'] ?? 0).toDouble(),
    );
  }
}

class AcOverdueStats {
  final int count;
  final double amount;

  AcOverdueStats({required this.count, required this.amount});

  factory AcOverdueStats.fromJson(Map<String, dynamic> json) {
    return AcOverdueStats(
      count: json['count'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class AcTodayAttendance {
  final int present;
  final int absent;
  final int total;
  final int percentage;

  AcTodayAttendance({
    required this.present,
    required this.absent,
    required this.total,
    required this.percentage,
  });

  factory AcTodayAttendance.fromJson(Map<String, dynamic> json) {
    return AcTodayAttendance(
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      total: json['total'] ?? 0,
      percentage: json['percentage'] ?? 0,
    );
  }
}

class AcRecentActivity {
  final int newStudents;
  final int upcomingExams;
  final int pendingFeeReminders;

  AcRecentActivity({
    required this.newStudents,
    required this.upcomingExams,
    required this.pendingFeeReminders,
  });

  factory AcRecentActivity.fromJson(Map<String, dynamic> json) {
    return AcRecentActivity(
      newStudents: json['newStudents'] ?? 0,
      upcomingExams: json['upcomingExams'] ?? 0,
      pendingFeeReminders: json['pendingFeeReminders'] ?? 0,
    );
  }
}

// ============================================================================
// NEW SCHOOL ERP MODELS
// ============================================================================

// ---------------------------------------------------------------------------
// Class & Section
// ---------------------------------------------------------------------------

class AcSection {
  final String id;
  final String name;
  final String? teacherName;
  final int studentCount;

  AcSection({
    required this.id,
    required this.name,
    this.teacherName,
    required this.studentCount,
  });

  factory AcSection.fromJson(Map<String, dynamic> j) => AcSection(
    id: j['id'] ?? j['sectionId'] ?? '',
    name: j['name'] ?? '',
    teacherName: j['teacherName'],
    studentCount: j['studentCount'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacherName': teacherName,
    'studentCount': studentCount,
  };
}

class AcClassRoom {
  final String id;
  final String name;
  final String? classTeacherName;
  final List<AcSection> sections;
  final int totalStudents;

  AcClassRoom({
    required this.id,
    required this.name,
    this.classTeacherName,
    required this.sections,
    required this.totalStudents,
  });

  factory AcClassRoom.fromJson(Map<String, dynamic> j) => AcClassRoom(
    id: j['id'] ?? j['classId'] ?? '',
    name: j['name'] ?? '',
    classTeacherName: j['classTeacherName'],
    sections: (j['sections'] as List? ?? [])
        .map((s) => AcSection.fromJson(s as Map<String, dynamic>))
        .toList(),
    totalStudents: j['totalStudents'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'classTeacherName': classTeacherName,
    'sections': sections.map((s) => s.toJson()).toList(),
    'totalStudents': totalStudents,
  };
}

// ---------------------------------------------------------------------------
// Academic Year & Term
// ---------------------------------------------------------------------------

class AcTerm {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  AcTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory AcTerm.fromJson(Map<String, dynamic> j) => AcTerm(
    id: j['id'] ?? j['termId'] ?? '',
    name: j['name'] ?? '',
    startDate: DateTime.parse(j['startDate']),
    endDate: DateTime.parse(j['endDate']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
  };
}

class AcAcademicYear {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<AcTerm> terms;

  AcAcademicYear({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.terms,
  });

  factory AcAcademicYear.fromJson(Map<String, dynamic> j) => AcAcademicYear(
    id: j['id'] ?? j['yearId'] ?? '',
    name: j['name'] ?? '',
    startDate: DateTime.parse(j['startDate']),
    endDate: DateTime.parse(j['endDate']),
    isActive: j['isActive'] ?? false,
    terms: (j['terms'] as List? ?? [])
        .map((t) => AcTerm.fromJson(t as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isActive': isActive,
    'terms': terms.map((t) => t.toJson()).toList(),
  };
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

class AcBook {
  final String id;
  final String title;
  final String author;
  final String? isbn;
  final int totalCopies;
  final int availableCopies;

  AcBook({
    required this.id,
    required this.title,
    required this.author,
    this.isbn,
    required this.totalCopies,
    required this.availableCopies,
  });

  factory AcBook.fromJson(Map<String, dynamic> j) => AcBook(
    id: j['id'] ?? j['bookId'] ?? '',
    title: j['title'] ?? '',
    author: j['author'] ?? '',
    isbn: j['isbn'],
    totalCopies: j['totalCopies'] ?? 1,
    availableCopies: j['availableCopies'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'isbn': isbn,
    'totalCopies': totalCopies,
    'availableCopies': availableCopies,
  };
}

class AcBookIssue {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentId;
  final String studentName;
  final DateTime issuedDate;
  final DateTime dueDate;
  final DateTime? returnedDate;
  final double? finePerDay;
  final double? fineCollected;

  AcBookIssue({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentId,
    required this.studentName,
    required this.issuedDate,
    required this.dueDate,
    this.returnedDate,
    this.finePerDay,
    this.fineCollected,
  });

  factory AcBookIssue.fromJson(Map<String, dynamic> j) => AcBookIssue(
    id: j['id'] ?? j['issueId'] ?? '',
    bookId: j['bookId'] ?? '',
    bookTitle: j['bookTitle'] ?? '',
    studentId: j['studentId'] ?? '',
    studentName: j['studentName'] ?? '',
    issuedDate: DateTime.parse(j['issuedDate']),
    dueDate: DateTime.parse(j['dueDate']),
    returnedDate: j['returnedDate'] != null
        ? DateTime.parse(j['returnedDate'])
        : null,
    finePerDay: j['finePerDay'] != null
        ? (j['finePerDay'] as num).toDouble()
        : null,
    fineCollected: j['fineCollected'] != null
        ? (j['fineCollected'] as num).toDouble()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'studentId': studentId,
    'issuedDate': issuedDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
  };
}

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

class AcTransportStop {
  final String id;
  final String name;
  final String? pickupTime;

  AcTransportStop({required this.id, required this.name, this.pickupTime});

  factory AcTransportStop.fromJson(Map<String, dynamic> j) => AcTransportStop(
    id: j['id'] ?? j['stopId'] ?? '',
    name: j['name'] ?? '',
    pickupTime: j['pickupTime'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pickupTime': pickupTime,
  };
}

class AcTransportRoute {
  final String id;
  final String name;
  final String? driverName;
  final String? vehicleNumber;
  final int studentCount;
  final List<AcTransportStop> stops;

  AcTransportRoute({
    required this.id,
    required this.name,
    this.driverName,
    this.vehicleNumber,
    required this.studentCount,
    required this.stops,
  });

  factory AcTransportRoute.fromJson(Map<String, dynamic> j) => AcTransportRoute(
    id: j['id'] ?? j['routeId'] ?? '',
    name: j['name'] ?? '',
    driverName: j['driverName'],
    vehicleNumber: j['vehicleNumber'],
    studentCount: j['studentCount'] ?? 0,
    stops: (j['stops'] as List? ?? [])
        .map((s) => AcTransportStop.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'driverName': driverName,
    'vehicleNumber': vehicleNumber,
    'studentCount': studentCount,
    'stops': stops.map((s) => s.toJson()).toList(),
  };
}

class AcVehicle {
  final String id;
  final String number;
  final String? driverName;
  final String? driverPhone;
  final int capacity;
  final bool isActive;

  AcVehicle({
    required this.id,
    required this.number,
    this.driverName,
    this.driverPhone,
    required this.capacity,
    required this.isActive,
  });

  factory AcVehicle.fromJson(Map<String, dynamic> j) => AcVehicle(
    id: j['id'] ?? j['vehicleId'] ?? '',
    number: j['number'] ?? j['vehicleNumber'] ?? '',
    driverName: j['driverName'],
    driverPhone: j['driverPhone'],
    capacity: j['capacity'] ?? 40,
    isActive: j['isActive'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'driverName': driverName,
    'driverPhone': driverPhone,
    'capacity': capacity,
    'isActive': isActive,
  };
}

// ---------------------------------------------------------------------------
// Report Card
// ---------------------------------------------------------------------------

class AcReportSubject {
  final String subjectName;
  final double marksObtained;
  final double maxMarks;
  final String? grade;

  AcReportSubject({
    required this.subjectName,
    required this.marksObtained,
    required this.maxMarks,
    this.grade,
  });

  factory AcReportSubject.fromJson(Map<String, dynamic> j) => AcReportSubject(
    subjectName: j['subjectName'] ?? '',
    marksObtained: (j['marksObtained'] ?? 0).toDouble(),
    maxMarks: (j['maxMarks'] ?? 100).toDouble(),
    grade: j['grade'],
  );

  Map<String, dynamic> toJson() => {
    'subjectName': subjectName,
    'marksObtained': marksObtained,
    'maxMarks': maxMarks,
    'grade': grade,
  };
}

class AcReportCard {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String examName;
  final List<AcReportSubject> subjects;
  final double totalMarksObtained;
  final double totalMaxMarks;
  final double percentage;
  final String grade;
  final bool isPassed;
  final DateTime generatedAt;
  final String? pdfUrl;

  AcReportCard({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.examName,
    required this.subjects,
    required this.totalMarksObtained,
    required this.totalMaxMarks,
    required this.percentage,
    required this.grade,
    required this.isPassed,
    required this.generatedAt,
    this.pdfUrl,
  });

  factory AcReportCard.fromJson(Map<String, dynamic> j) => AcReportCard(
    id: j['id'] ?? j['reportCardId'] ?? '',
    studentId: j['studentId'] ?? '',
    studentName: j['studentName'] ?? '',
    classId: j['classId'] ?? '',
    className: j['className'] ?? '',
    examName: j['examName'] ?? '',
    subjects: (j['subjects'] as List? ?? [])
        .map((s) => AcReportSubject.fromJson(s as Map<String, dynamic>))
        .toList(),
    totalMarksObtained: (j['totalMarksObtained'] ?? 0).toDouble(),
    totalMaxMarks: (j['totalMaxMarks'] ?? 100).toDouble(),
    percentage: (j['percentage'] ?? 0).toDouble(),
    grade: j['grade'] ?? 'F',
    isPassed: j['isPassed'] ?? false,
    generatedAt: DateTime.parse(
      j['generatedAt'] ?? DateTime.now().toIso8601String(),
    ),
    pdfUrl: j['pdfUrl'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'classId': classId,
    'examName': examName,
    'percentage': percentage,
    'grade': grade,
    'isPassed': isPassed,
  };
}

// ── Classwise Fee Structure ──────────────────────────────────────────────────

class AcFeeStructure {
  final String id;
  final String classId;
  final String feeHead;
  final double amountRupees;
  final String
  frequency; // monthly | quarterly | half_yearly | annual | one_time
  final int? dueDayOfMonth;
  final bool isOptional;
  final DateTime createdAt;

  const AcFeeStructure({
    required this.id,
    required this.classId,
    required this.feeHead,
    required this.amountRupees,
    required this.frequency,
    this.dueDayOfMonth,
    required this.isOptional,
    required this.createdAt,
  });

  factory AcFeeStructure.fromJson(Map<String, dynamic> j) => AcFeeStructure(
    id: j['id'] ?? j['structureId'] ?? '',
    classId: j['classId'] ?? '',
    feeHead: j['feeHead'] ?? '',
    amountRupees: (j['amountRupees'] ?? j['amount'] ?? 0).toDouble(),
    frequency: j['frequency'] ?? 'monthly',
    dueDayOfMonth: j['dueDayOfMonth'] as int?,
    isOptional: j['isOptional'] ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'classId': classId,
    'feeHead': feeHead,
    'amountRupees': amountRupees,
    'frequency': frequency,
    'dueDayOfMonth': dueDayOfMonth,
    'isOptional': isOptional,
  };
}
