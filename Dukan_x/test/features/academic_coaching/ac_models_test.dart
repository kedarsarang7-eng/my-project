// ============================================================================
// ACADEMIC COACHING — MODEL UNIT TESTS
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/academic_coaching/data/models/ac_models.dart';

void main() {
  group('AcStudent', () {
    test('fromJson creates student from JSON', () {
      final json = {
        'id': '1',
        'studentId': 'STU001',
        'firstName': 'John',
        'lastName': 'Doe',
        'phone': '9876543210',
        'parentPhone': '9876543211',
        'email': 'john@example.com',
        'gender': 'male',
        'dob': '2009-01-15',
        'status': 'active',
        'enrolledBatchIds': ['1', '2'],
        'feeSummary': {
          'totalFees': 5000.0,
          'totalPaid': 3000.0,
          'balance': 2000.0,
        },
        'createdAt': '2024-01-01T00:00:00Z',
        'updatedAt': '2024-01-01T00:00:00Z',
      };

      final student = AcStudent.fromJson(json);

      expect(student.id, '1');
      expect(student.studentId, 'STU001');
      expect(student.fullName, 'John Doe');
      expect(student.phone, '9876543210');
      expect(student.gender, 'male');
      expect(student.status, StudentStatus.active);
      expect(student.totalFees, 5000.0);
      expect(student.totalPaid, 3000.0);
      expect(student.balance, 2000.0);
    });

    test('toJson converts student to JSON', () {
      final student = AcStudent(
        id: '1',
        studentId: 'STU001',
        firstName: 'John',
        lastName: 'Doe',
        phone: '9876543210',
        gender: 'male',
        status: StudentStatus.active,
        enrolledBatchIds: const ['1'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = student.toJson();

      expect(json['firstName'], 'John');
      expect(json['status'], 'active');
    });

    test('fullName concatenates first and last name', () {
      final student = AcStudent(
        id: '1',
        studentId: 'STU001',
        firstName: 'John',
        lastName: 'Doe',
        phone: '9876543210',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(student.fullName, 'John Doe');
    });

    test('status defaults to active', () {
      final student = AcStudent(
        id: '1',
        studentId: 'STU001',
        firstName: 'John',
        lastName: 'Doe',
        phone: '9876543210',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(student.status, StudentStatus.active);
    });
  });

  group('AcBatch', () {
    test('fromJson creates batch from JSON', () {
      final json = {
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

      final batch = AcBatch.fromJson(json);

      expect(batch.batchCode, 'B001');
      expect(batch.name, 'Morning Batch');
      expect(batch.maxCapacity, 30);
      expect(batch.enrolledCount, 25);
      expect(batch.availableSeats, 5);
    });

    test('availableSeats is calculated correctly', () {
      final batch = AcBatch(
        id: '1',
        batchCode: 'B001',
        name: 'Morning',
        courseId: 'C001',
        maxCapacity: 30,
        enrolledCount: 25,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(batch.availableSeats, 5);
    });

    test('isFull returns true when at capacity', () {
      final batch = AcBatch(
        id: '1',
        name: 'Full Batch',
        maxCapacity: 30,
        enrolledCount: 30,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(batch.isFull, isTrue);
    });
  });

  group('AcCourse', () {
    test('fromJson creates course from JSON', () {
      final json = {
        'id': '1',
        'name': 'Mathematics',
        'description': 'Advanced Mathematics Course',
        'subjects': [
          {'subjectId': 'S1', 'name': 'Algebra'},
          {'subjectId': 'S2', 'name': 'Geometry'},
          {'subjectId': 'S3', 'name': 'Calculus'},
        ],
        'duration': {'value': 1, 'unit': 'year'},
        'targetExam': 'JEE',
        'totalFee': 50000.0,
        'materialFee': 5000.0,
        'admissionFee': 10000.0,
        'isActive': true,
        'createdAt': '2024-01-01T00:00:00Z',
        'updatedAt': '2024-01-01T00:00:00Z',
      };

      final course = AcCourse.fromJson(json);

      expect(course.name, 'Mathematics');
      expect(course.subjects.length, 3);
      expect(course.totalFee, 50000.0);
      expect(course.isActive, true);
    });
  });

  group('AcInvoice', () {
    test('fromJson creates invoice from JSON', () {
      final json = {
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

      final invoice = AcInvoice.fromJson(json);

      expect(invoice.invoiceNumber, 'INV-2024-001');
      expect(invoice.totalAmount, 5000.0);
      expect(invoice.status, FeeStatus.partial);
    });

    test('isOverdue returns true for past due date with unpaid balance', () {
      final invoice = AcInvoice(
        id: 'INV001',
        invoiceNumber: 'INV-001',
        studentId: 'STU001',
        totalAmount: 5000.0,
        balance: 2000.0,
        status: FeeStatus.partial,
        dueDate: '2020-01-01', // Past date
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(invoice.isOverdue, true);
    });

    test('isOverdue returns false when paid', () {
      final invoice = AcInvoice(
        id: 'INV002',
        invoiceNumber: 'INV-002',
        studentId: 'STU001',
        totalAmount: 5000.0,
        status: FeeStatus.paid,
        dueDate: '2020-01-01',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(invoice.isOverdue, false);
    });
  });

  group('AcFaculty', () {
    test('fromJson creates faculty from JSON', () {
      final json = {
        'id': '1',
        'name': 'Dr. Smith',
        'phone': '9876543210',
        'email': 'smith@example.com',
        'specialization': ['Mathematics', 'Physics'],
        'employmentType': 'full_time',
        'salaryStructure': {
          'type': 'fixed',
          'fixedAmount': 50000.0,
        },
        'isActive': true,
        'createdAt': '2024-01-01T00:00:00Z',
        'updatedAt': '2024-01-01T00:00:00Z',
      };

      final faculty = AcFaculty.fromJson(json);

      expect(faculty.name, 'Dr. Smith');
      expect(faculty.specialization.length, 2);
      expect(faculty.salaryStructure.type, 'fixed');
    });
  });

  group('AcExam', () {
    test('fromJson creates exam from JSON', () {
      final json = {
        'id': '1',
        'name': 'Mid Term Exam',
        'type': 'internal',
        'batchIds': ['1', '2'],
        'date': '2024-03-15',
        'duration': '3 hours',
        'venue': 'Hall A',
        'subjects': [
          {'subjectId': 'S001', 'subjectName': 'Math', 'maxMarks': 100},
        ],
        'status': 'scheduled',
        'createdAt': '2024-01-01T00:00:00Z',
      };

      final exam = AcExam.fromJson(json);

      expect(exam.name, 'Mid Term Exam');
      expect(exam.type, ExamType.internal);
      expect(exam.status, 'scheduled');
      expect(exam.isScheduled, true);
    });
  });

  group('AcResult', () {
    test('fromJson creates result from JSON', () {
      final json = {
        'id': '1',
        'examId': 'EX001',
        'studentId': 'STU001',
        'studentName': 'John Doe',
        'subjectResults': [
          {'subjectId': 'S001', 'subjectName': 'Math', 'marksObtained': 85, 'maxMarks': 100},
        ],
        'totalObtained': 85,
        'totalMax': 100,
        'percentage': 85.0,
        'grade': 'A',
        'status': 'pass',
        'createdAt': '2024-01-01T00:00:00Z',
      };

      final result = AcResult.fromJson(json);

      expect(result.percentage, 85.0);
      expect(result.grade, 'A');
      expect(result.isPass, true);
    });
  });

  group('AcMaterial', () {
    test('fromJson creates material from JSON', () {
      final json = {
        'id': '1',
        'title': 'Math Notes',
        'subjectId': 'S001',
        'type': 'notes',
        'isFree': false,
        'materialFee': 500.0,
        'downloadCount': 50,
        'publishedAt': '2024-01-01T00:00:00Z',
        'createdAt': '2024-01-01T00:00:00Z',
      };

      final material = AcMaterial.fromJson(json);

      expect(material.title, 'Math Notes');
      expect(material.type, MaterialType.notes);
      expect(material.typeLabel, 'Notes');
      expect(material.isFree, false);
    });

    test('practice_paper type maps correctly', () {
      final json = {
        'id': '2',
        'title': 'Practice Set',
        'subjectId': 'S001',
        'type': 'practice_paper',
        'isFree': true,
        'publishedAt': '2024-01-01T00:00:00Z',
        'createdAt': '2024-01-01T00:00:00Z',
      };
      final material = AcMaterial.fromJson(json);
      expect(material.type, MaterialType.practicePaper);
    });
  });

  group('Enums via fromJson parsing', () {
    test('StudentStatus parses active/inactive/graduated/transferred', () {
      expect(AcStudent.fromJson({
        'id': '1', 'studentId': 'S1', 'firstName': 'A', 'lastName': 'B',
        'phone': '9999999999', 'status': 'inactive',
        'createdAt': '2024-01-01T00:00:00Z', 'updatedAt': '2024-01-01T00:00:00Z',
      }).status, StudentStatus.inactive);
      expect(AcStudent.fromJson({
        'id': '2', 'studentId': 'S2', 'firstName': 'A', 'lastName': 'B',
        'phone': '9999999999', 'status': 'graduated',
        'createdAt': '2024-01-01T00:00:00Z', 'updatedAt': '2024-01-01T00:00:00Z',
      }).status, StudentStatus.graduated);
      expect(AcStudent.fromJson({
        'id': '3', 'studentId': 'S3', 'firstName': 'A', 'lastName': 'B',
        'phone': '9999999999', 'status': 'transferred',
        'createdAt': '2024-01-01T00:00:00Z', 'updatedAt': '2024-01-01T00:00:00Z',
      }).status, StudentStatus.transferred);
    });

    test('ExamType parses mock/unit_test/final/quiz/internal', () {
      AcExam parseExam(String type) => AcExam.fromJson({
        'id': '1', 'name': 'E', 'date': '2024-01-01', 'type': type,
        'createdAt': '2024-01-01T00:00:00Z',
      });
      expect(parseExam('mock').type, ExamType.mock);
      expect(parseExam('unit_test').type, ExamType.unitTest);
      expect(parseExam('final').type, ExamType.final_);
      expect(parseExam('quiz').type, ExamType.quiz);
      expect(parseExam('internal').type, ExamType.internal);
    });

    test('MaterialType parses practice_paper/solution/video_link/reference', () {
      AcMaterial parseMaterial(String type) => AcMaterial.fromJson({
        'id': '1', 'title': 'T', 'subjectId': 'S1', 'type': type,
        'publishedAt': '2024-01-01T00:00:00Z', 'createdAt': '2024-01-01T00:00:00Z',
      });
      expect(parseMaterial('notes').type, MaterialType.notes);
      expect(parseMaterial('practice_paper').type, MaterialType.practicePaper);
      expect(parseMaterial('solution').type, MaterialType.solution);
      expect(parseMaterial('video_link').type, MaterialType.videoLink);
      expect(parseMaterial('reference').type, MaterialType.reference);
    });

    test('FeeStatus parses paid/partial/overdue/pending', () {
      AcInvoice parseInv(String status) => AcInvoice.fromJson({
        'id': '1', 'invoiceNumber': 'I1', 'studentId': 'S1',
        'totalAmount': 100.0, 'status': status,
        'createdAt': '2024-01-01T00:00:00Z', 'updatedAt': '2024-01-01T00:00:00Z',
      });
      expect(parseInv('paid').status, FeeStatus.paid);
      expect(parseInv('partial').status, FeeStatus.partial);
      expect(parseInv('overdue').status, FeeStatus.overdue);
      expect(parseInv('pending').status, FeeStatus.pending);
    });
  });
}
