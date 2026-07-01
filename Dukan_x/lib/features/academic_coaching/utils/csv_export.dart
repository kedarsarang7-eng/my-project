// ============================================================================
// ACADEMIC COACHING — CSV EXPORT UTILITIES
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import '../data/models/ac_models.dart';

/// Threshold above which the synchronous CSV converter is dispatched onto
/// a background isolate. Anything below stays on the UI isolate so the
/// dispatch overhead does not regress the timing class for small exports
/// (preservation 3.1: "timing class preserved on already-correct screens").
const int _csvIsolateThreshold = 500;

class CsvExportHelper {
  /// Export students to CSV
  static String exportStudents(List<AcStudent> students) {
    final rows = <List<dynamic>>[
      // Header
      [
        'Student ID',
        'Name',
        'Phone',
        'Parent Phone',
        'Email',
        'Gender',
        'Date of Birth',
        'Status',
        'Enrolled Batches',
        'Total Fees',
        'Paid Amount',
        'Balance',
      ],
    ];

    for (final student in students) {
      rows.add([
        student.studentId,
        student.fullName,
        student.phone,
        student.parentPhone ?? '',
        student.email ?? '',
        student.gender ?? '',
        student.dob ?? '',
        student.statusLabel,
        student.enrolledBatchIds.join(', '),
        student.totalFees ?? 0.0,
        student.totalPaid ?? 0.0,
        student.balance ?? 0.0,
      ]);
    }

    return Csv().encode(rows);
  }

  /// Export batches to CSV
  static String exportBatches(List<AcBatch> batches) {
    final rows = <List<dynamic>>[
      [
        'Batch Code',
        'Name',
        'Course',
        'Status',
        'Capacity',
        'Enrolled',
        'Available',
        'Start Date',
        'End Date',
      ],
    ];

    for (final batch in batches) {
      rows.add([
        batch.batchCode,
        batch.name,
        batch.courseId,
        batch.status,
        batch.maxCapacity,
        batch.enrolledCount,
        batch.availableSeats,
        batch.startDate ?? '',
        batch.endDate ?? '',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Export courses to CSV
  static String exportCourses(List<AcCourse> courses) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Description',
        'Subjects',
        'Duration',
        'Target Exam',
        'Total Fee',
        'Material Fee',
        'Admission Fee',
        'Status',
      ],
    ];

    for (final course in courses) {
      rows.add([
        course.name,
        course.description ?? '',
        course.subjects.join(', '),
        course.duration ?? '',
        course.targetExam ?? '',
        course.totalFee,
        course.materialFee,
        course.admissionFee,
        course.isActive ? 'Active' : 'Inactive',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Export faculty to CSV
  static String exportFaculty(List<AcFaculty> faculty) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Phone',
        'Email',
        'Specialization',
        'Employment Type',
        'Salary Type',
        'Fixed Amount',
        'Per Class Rate',
        'Status',
      ],
    ];

    for (final f in faculty) {
      rows.add([
        f.name,
        f.phone,
        f.email ?? '',
        f.specialization.join(', '),
        f.employmentType,
        f.salaryStructure.type ?? '',
        f.salaryStructure.fixedAmount ?? 0,
        f.salaryStructure.perClassRate ?? 0,
        f.isActive ? 'Active' : 'Inactive',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Export fee records to CSV
  static String exportFeeRecords(List<AcInvoice> invoices) {
    final rows = <List<dynamic>>[
      [
        'Invoice Number',
        'Student ID',
        'Student Name',
        'Total Amount',
        'Paid Amount',
        'Balance',
        'Status',
        'Due Date',
        'Paid Date',
      ],
    ];

    for (final invoice in invoices) {
      rows.add([
        invoice.invoiceNumber,
        invoice.studentId,
        invoice.studentName ?? '',
        invoice.totalAmount,
        invoice.paidAmount,
        invoice.balance,
        invoice.statusLabel,
        invoice.dueDate ?? '',
        invoice.status == FeeStatus.paid ? invoice.updatedAt.toIso8601String() : '',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Export attendance to CSV
  static String exportAttendance(List<Map<String, dynamic>> records) {
    final rows = <List<dynamic>>[
      ['Date', 'Batch', 'Student ID', 'Student Name', 'Status'],
    ];

    for (final record in records) {
      final date = record['date'] ?? '';
      final batchName = record['batchName'] ?? '';
      final students = record['students'] as List<dynamic>? ?? [];

      for (final student in students) {
        rows.add([
          date,
          batchName,
          student['studentId'] ?? '',
          student['studentName'] ?? '',
          student['status'] ?? '',
        ]);
      }
    }

    return Csv().encode(rows);
  }

  /// Export exam results to CSV
  static String exportExamResults(List<AcResult> results) {
    final rows = <List<dynamic>>[
      [
        'Student ID',
        'Student Name',
        'Total Marks',
        'Obtained Marks',
        'Percentage',
        'Grade',
        'Status',
        'Remarks',
      ],
    ];

    for (final result in results) {
      rows.add([
        result.studentId,
        result.studentName ?? '',
        result.totalMax,
        result.totalObtained,
        result.percentage,
        result.grade,
        result.status,
        result.remarks ?? '',
      ]);
    }

    return Csv().encode(rows);
  }

  /// Generate filename with timestamp
  static String generateFilename(String entity) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${entity}_export_$timestamp.csv';
  }

  // ==========================================================================
  // D9 performance fix (task 3.2.9) — isolate-offloaded async variants.
  //
  // The sync `export*` methods above are preserved as-is to honor the
  // public API perimeter (preservation 3.4). The async variants below
  // dispatch CSV serialization onto a background isolate via Flutter's
  // `compute()` whenever the row set is large enough that the UI thread
  // would visibly stall. Below the threshold we stay synchronous to
  // avoid adding isolate overhead to small, already-fast exports
  // (preservation 3.1).
  // ==========================================================================

  /// Off-isolate version of [exportStudents] for large row sets.
  static Future<String> exportStudentsAsync(List<AcStudent> students) {
    if (students.length < _csvIsolateThreshold) {
      return Future.value(exportStudents(students));
    }
    return compute(_isolateExportStudents, students);
  }

  /// Off-isolate version of [exportFeeRecords] for large row sets.
  static Future<String> exportFeeRecordsAsync(List<AcInvoice> invoices) {
    if (invoices.length < _csvIsolateThreshold) {
      return Future.value(exportFeeRecords(invoices));
    }
    return compute(_isolateExportFeeRecords, invoices);
  }

  /// Off-isolate version of [exportAttendance] for large row sets.
  static Future<String> exportAttendanceAsync(
    List<Map<String, dynamic>> records,
  ) {
    if (records.length < _csvIsolateThreshold) {
      return Future.value(exportAttendance(records));
    }
    return compute(_isolateExportAttendance, records);
  }

  /// Off-isolate version of [exportExamResults] for large row sets.
  static Future<String> exportExamResultsAsync(List<AcResult> results) {
    if (results.length < _csvIsolateThreshold) {
      return Future.value(exportExamResults(results));
    }
    return compute(_isolateExportExamResults, results);
  }

  /// Download CSV (web) or share (mobile)
  static void downloadCsv(String csvContent, String filename) {
    // Implementation depends on platform
    // For web: use dart:html AnchorElement
    // For mobile: use share_plus package
    if (kIsWeb) {
      _downloadWeb(csvContent, filename);
    } else {
      // Mobile implementation
      throw UnimplementedError('Mobile CSV download not implemented');
    }
  }

  static void _downloadWeb(String csvContent, String filename) {
    // Web-specific implementation would go here
    // Requires dart:html which is only available on web
    throw UnimplementedError('Web CSV download requires dart:html import');
  }
}

// ============================================================================
// D9 isolate entry points — must be top-level for `compute()` to invoke.
// ============================================================================

String _isolateExportStudents(List<AcStudent> students) =>
    CsvExportHelper.exportStudents(students);

String _isolateExportFeeRecords(List<AcInvoice> invoices) =>
    CsvExportHelper.exportFeeRecords(invoices);

String _isolateExportAttendance(List<Map<String, dynamic>> records) =>
    CsvExportHelper.exportAttendance(records);

String _isolateExportExamResults(List<AcResult> results) =>
    CsvExportHelper.exportExamResults(results);
