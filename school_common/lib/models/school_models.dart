// Shared data models for all School ERP sub-apps

class StudentModel {
  final String id;
  final String firstName;
  final String lastName;
  final String studentId;
  final String? email;
  final String? phone;
  final String? batchId;
  final String? batchName;
  final String status;
  final double attendancePercentage;
  final String? photoUrl;

  const StudentModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentId,
    this.email,
    this.phone,
    this.batchId,
    this.batchName,
    this.status = 'active',
    this.attendancePercentage = 0,
    this.photoUrl,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory StudentModel.fromJson(Map<String, dynamic> j) => StudentModel(
    id: j['id'] ?? j['studentId'] ?? '',
    firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '',
    studentId: j['studentId'] ?? j['rollNumber'] ?? '',
    email: j['email'],
    phone: j['phone'],
    batchId: j['batchId'],
    batchName: j['batchName'],
    status: j['status'] ?? 'active',
    attendancePercentage: (j['attendancePercentage'] ?? 0).toDouble(),
    photoUrl: j['photoUrl'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'firstName': firstName, 'lastName': lastName,
    'studentId': studentId, 'email': email, 'phone': phone,
    'batchId': batchId, 'status': status,
  };
}

class FacultyModel {
  final String id;
  final String firstName;
  final String lastName;
  final String? employeeId;
  final String? email;
  final String? phone;
  final String? department;
  final String? designation;
  final List<String> subjects;
  final String employmentType;

  const FacultyModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.employeeId,
    this.email,
    this.phone,
    this.department,
    this.designation,
    this.subjects = const [],
    this.employmentType = 'full_time',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory FacultyModel.fromJson(Map<String, dynamic> j) => FacultyModel(
    id: j['id'] ?? '',
    firstName: j['firstName'] ?? '',
    lastName: j['lastName'] ?? '',
    employeeId: j['employeeId'],
    email: j['email'],
    phone: j['phone'],
    department: j['department'],
    designation: j['designation'],
    subjects: List<String>.from(j['subjects'] ?? []),
    employmentType: j['employmentType'] ?? 'full_time',
  );
}

class BatchModel {
  final String id;
  final String name;
  final String? subject;
  final int? capacity;
  final int studentCount;

  const BatchModel({
    required this.id,
    required this.name,
    this.subject,
    this.capacity,
    this.studentCount = 0,
  });

  factory BatchModel.fromJson(Map<String, dynamic> j) => BatchModel(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    subject: j['subject'] ?? j['course'],
    capacity: j['capacity'],
    studentCount: j['studentCount'] ?? j['enrolledStudents'] ?? 0,
  );
}

class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String date;
  final String batchId;
  bool isPresent;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.batchId,
    this.isPresent = true,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'date': date,
    'batchId': batchId,
    'status': isPresent ? 'present' : 'absent',
  };
}

class FeeRecord {
  final String id;
  final String studentId;
  final String? studentName;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String? dueDate;
  final bool isOverdue;
  final String status;

  const FeeRecord({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    this.dueDate,
    this.isOverdue = false,
    this.status = 'pending',
  });

  factory FeeRecord.fromJson(Map<String, dynamic> j) => FeeRecord(
    id: j['id'] ?? '',
    studentId: j['studentId'] ?? '',
    studentName: j['studentName'],
    totalAmount: (j['totalAmount'] ?? j['amount'] ?? 0).toDouble(),
    paidAmount: (j['paidAmount'] ?? 0).toDouble(),
    pendingAmount: (j['pendingAmount'] ?? j['pendingAmount'] ?? 0).toDouble(),
    dueDate: j['dueDate'],
    isOverdue: j['isOverdue'] == true,
    status: j['status'] ?? 'pending',
  );
}

class ExamModel {
  final String id;
  final String subject;
  final String? batchId;
  final String? batchName;
  final String? examDate;
  final int maxMarks;
  final String examType;
  final bool resultsUploaded;

  const ExamModel({
    required this.id,
    required this.subject,
    this.batchId,
    this.batchName,
    this.examDate,
    this.maxMarks = 100,
    this.examType = 'unit_test',
    this.resultsUploaded = false,
  });

  factory ExamModel.fromJson(Map<String, dynamic> j) => ExamModel(
    id: j['id'] ?? '',
    subject: j['subjectName'] ?? j['subject'] ?? '',
    batchId: j['batchId'],
    batchName: j['batchName'],
    examDate: j['examDate'] ?? j['date'],
    maxMarks: j['maxMarks'] ?? 100,
    examType: j['examType'] ?? 'unit_test',
    resultsUploaded: j['resultsUploaded'] == true,
  );
}

class LeaveApplication {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String? reason;
  final String status;
  final String personType;

  const LeaveApplication({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.status = 'pending',
    this.personType = 'student',
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
    id: j['id'] ?? '',
    leaveType: j['leaveType'] ?? 'casual',
    startDate: j['startDate'] ?? '',
    endDate: j['endDate'] ?? '',
    reason: j['reason'],
    status: j['status'] ?? 'pending',
    personType: j['personType'] ?? 'student',
  );
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String category;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'general',
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    body: j['body'] ?? j['message'] ?? '',
    category: j['category'] ?? 'general',
    isRead: j['isRead'] == true || j['read'] == true,
    createdAt: j['createdAt'] ?? j['timestamp'] ?? '',
  );
}
