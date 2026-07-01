// ============================================================================
// ACADEMIC COACHING — TEST HELPERS
// ============================================================================

import 'package:dukanx/features/academic_coaching/data/models/ac_models.dart';

/// Factory for creating test model instances
class TestFactories {
  static AcStudent createStudent({
    String id = '1',
    String studentId = 'STU001',
    String firstName = 'John',
    String lastName = 'Doe',
    String phone = '9876543210',
    StudentStatus status = StudentStatus.active,
    double totalFees = 10000.0,
    double paidAmount = 5000.0,
  }) {
    return AcStudent(
      id: id,
      studentId: studentId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      status: status,
      totalFees: totalFees,
      paidAmount: paidAmount,
      enrolledBatchIds: const ['1'],
    );
  }

  static AcBatch createBatch({
    String id = '1',
    String batchCode = 'B001',
    String name = 'Morning Batch',
    String courseId = 'C001',
    int maxCapacity = 30,
    int enrolledCount = 25,
    BatchStatus status = BatchStatus.active,
  }) {
    return AcBatch(
      id: id,
      batchCode: batchCode,
      name: name,
      courseId: courseId,
      maxCapacity: maxCapacity,
      enrolledCount: enrolledCount,
      status: status,
    );
  }

  static AcCourse createCourse({
    String id = '1',
    String name = 'Mathematics',
    String description = 'Advanced Math',
    List<String> subjects = const ['Algebra', 'Geometry'],
    double totalFee = 50000.0,
    bool isActive = true,
  }) {
    return AcCourse(
      id: id,
      name: name,
      description: description,
      subjects: subjects,
      totalFee: totalFee,
      isActive: isActive,
    );
  }

  static AcInvoice createInvoice({
    String id = 'INV001',
    String invoiceNumber = 'INV-2024-001',
    String studentId = 'STU001',
    String studentName = 'John Doe',
    double totalAmount = 5000.0,
    double paidAmount = 3000.0,
    InvoiceStatus status = InvoiceStatus.partial,
  }) {
    return AcInvoice(
      id: id,
      invoiceNumber: invoiceNumber,
      studentId: studentId,
      studentName: studentName,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      balance: totalAmount - paidAmount,
      status: status,
    );
  }

  static AcFaculty createFaculty({
    String id = '1',
    String name = 'Dr. Smith',
    String phone = '9876543210',
    String email = 'smith@example.com',
    List<String> specialization = const ['Mathematics'],
    EmploymentType employmentType = EmploymentType.fullTime,
  }) {
    return AcFaculty(
      id: id,
      name: name,
      phone: phone,
      email: email,
      specialization: specialization,
      employmentType: employmentType,
      isActive: true,
    );
  }

  static AcExam createExam({
    String id = '1',
    String name = 'Mid Term',
    ExamType type = ExamType.internal,
    List<String> batchIds = const ['1'],
    String date = '2024-03-15',
    ExamStatus status = ExamStatus.scheduled,
  }) {
    return AcExam(
      id: id,
      name: name,
      type: type,
      batchIds: batchIds,
      date: date,
      status: status,
    );
  }

  static AcMaterial createMaterial({
    String id = '1',
    String title = 'Math Notes',
    String subjectId = 'S001',
    MaterialType type = MaterialType.notes,
    bool isFree = false,
    double materialFee = 500.0,
  }) {
    return AcMaterial(
      id: id,
      title: title,
      subjectId: subjectId,
      type: type,
      isFree: isFree,
      materialFee: materialFee,
    );
  }
}

/// Test data constants
class TestData {
  static const validStudentJson = {
    'id': '1',
    'studentId': 'STU001',
    'firstName': 'John',
    'lastName': 'Doe',
    'phone': '9876543210',
    'parentPhone': '9876543211',
    'email': 'john@example.com',
    'gender': 'male',
    'dateOfBirth': '2009-01-15',
    'status': 'active',
    'enrolledBatchIds': ['1', '2'],
    'totalFeesPaisa': 500000,
    'paidAmountPaisa': 300000,
    'createdAt': '2024-01-01T00:00:00Z',
    'updatedAt': '2024-01-01T00:00:00Z',
  };

  static const validBatchJson = {
    'id': '1',
    'batchCode': 'B001',
    'name': 'Morning Batch',
    'courseId': 'C001',
    'maxCapacity': 30,
    'enrolledCount': 25,
    'status': 'active',
    'startDate': '2024-01-01',
    'endDate': '2024-12-31',
  };

  static const validCourseJson = {
    'id': '1',
    'name': 'Mathematics',
    'description': 'Advanced Mathematics Course',
    'subjects': ['Algebra', 'Geometry', 'Calculus'],
    'duration': '1 Year',
    'targetExam': 'JEE',
    'totalFee': 50000.0,
    'materialFee': 5000.0,
    'admissionFee': 10000.0,
    'isActive': true,
  };

  static const validInvoiceJson = {
    'id': 'INV001',
    'invoiceNumber': 'INV-2024-001',
    'studentId': 'STU001',
    'studentName': 'John Doe',
    'totalAmount': 5000.0,
    'totalAmountPaisa': 500000,
    'paidAmount': 3000.0,
    'paidAmountPaisa': 300000,
    'balance': 2000.0,
    'balancePaisa': 200000,
    'status': 'partial',
    'dueDate': '2024-02-01',
  };
}
