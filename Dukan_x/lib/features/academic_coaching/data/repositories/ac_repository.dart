// ============================================================================
// ACADEMIC COACHING — API Repository
// ============================================================================
// Integrates with Lambda backend via ApiClient
// All amounts in paise on wire, converted to rupees in models
// ============================================================================

import '../models/ac_models.dart';
import '../../../../core/api/api_client.dart';

/// Generic paginated response wrapper
class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
  int get from => (page - 1) * limit + 1;
  int get to => (page - 1) * limit + items.length;
}

class AcRepository {
  final ApiClient _apiClient;

  AcRepository(this._apiClient);

  // ==========================================================================
  // DASHBOARD
  // ==========================================================================

  Future<AcDashboardStats> getDashboard() async {
    final response = await _apiClient.get('/ac/dashboard');
    if (response.statusCode == 200) {
      return AcDashboardStats.fromJson(response.data ?? {});
    }
    throw Exception('Failed to load dashboard: ${response.error}');
  }

  // ==========================================================================
  // STUDENTS
  // ==========================================================================

  Future<PaginatedResponse<AcStudent>> listStudents({
    String? batchId,
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (batchId != null) queryParams['batchId'] = batchId;
    if (search != null) queryParams['search'] = search;
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      '/ac/students',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final List<dynamic> items = (data as Map)['items'] ?? [];
      return PaginatedResponse(
        items: items.map((json) => AcStudent.fromJson(json)).toList(),
        total: (data)['total'] ?? 0,
        page: (data)['page'] ?? page,
        limit: (data)['limit'] ?? limit,
        totalPages: (data)['totalPages'] ?? 1,
      );
    }
    throw Exception('Failed to load students: ${response.error}');
  }

  Future<AcStudent> getStudent(String id) async {
    final response = await _apiClient.get('/ac/students/$id');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcStudent.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load student: ${response.error}');
  }

  Future<AcStudent> createStudent(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/students', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcStudent.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create student: ${response.error}');
  }

  Future<AcStudent> updateStudent(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/ac/students/$id', body: data);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcStudent.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update student: ${response.error}');
  }

  Future<void> deleteStudent(String id) async {
    final response = await _apiClient.delete('/ac/students/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete student: ${response.error}');
    }
  }

  Future<AcStudent> transferStudent(
    String id, {
    required String fromBatchId,
    required String toBatchId,
    String? transferDate,
    String? reason,
  }) async {
    final response = await _apiClient.post(
      '/ac/students/$id/transfer',
      body: {
        'fromBatchId': fromBatchId,
        'toBatchId': toBatchId,
        'transferDate': transferDate,
        'reason': reason,
      },
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcStudent.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to transfer student: ${response.error}');
  }

  // ==========================================================================
  // BATCHES
  // ==========================================================================

  Future<List<AcBatch>> listBatches({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      '/ac/batches',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcBatch.fromJson(json)).toList();
    }
    throw Exception('Failed to load batches: ${response.error}');
  }

  Future<AcBatch> createBatch(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/batches', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcBatch.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create batch: ${response.error}');
  }

  Future<AcBatch> getBatch(String batchId) async {
    final response = await _apiClient.get('/ac/batches/$batchId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcBatch.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load batch: ${response.error}');
  }

  Future<AcBatch> updateBatch(String batchId, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/ac/batches/$batchId', body: data);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcBatch.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update batch: ${response.error}');
  }

  Future<void> deleteBatch(String batchId) async {
    final response = await _apiClient.delete('/ac/batches/$batchId');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete batch: ${response.error}');
    }
  }

  Future<Map<String, dynamic>> getBatchSeats(String batchId) async {
    final response = await _apiClient.get('/ac/batches/$batchId/seats');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load batch seats: ${response.error}');
  }

  // ==========================================================================
  // COURSES
  // ==========================================================================

  Future<List<AcCourse>> listCourses() async {
    final response = await _apiClient.get('/ac/courses');
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcCourse.fromJson(json)).toList();
    }
    throw Exception('Failed to load courses: ${response.error}');
  }

  Future<AcCourse> createCourse(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/courses', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcCourse.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create course: ${response.error}');
  }

  Future<AcCourse> getCourse(String courseId) async {
    final response = await _apiClient.get('/ac/courses/$courseId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcCourse.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load course: ${response.error}');
  }

  Future<AcCourse> updateCourse(
    String courseId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.put('/ac/courses/$courseId', body: data);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcCourse.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update course: ${response.error}');
  }

  Future<void> deleteCourse(String courseId) async {
    final response = await _apiClient.delete('/ac/courses/$courseId');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete course: ${response.error}');
    }
  }

  // ==========================================================================
  // FEE MANAGEMENT
  // ==========================================================================

  Future<List<AcInvoice>> getStudentFees(String studentId) async {
    final response = await _apiClient.get('/ac/fees/student/$studentId');
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcInvoice.fromJson(json)).toList();
    }
    throw Exception('Failed to load student fees: ${response.error}');
  }

  Future<AcInvoice> createInvoice(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/invoices', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcInvoice.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create invoice: ${response.error}');
  }

  Future<AcPayment> recordPayment(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/payments', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcPayment.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to record payment: ${response.error}');
  }

  // ==========================================================================
  // ATTENDANCE
  // ==========================================================================

  Future<AcAttendance> markAttendance(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/attendance', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcAttendance.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to mark attendance: ${response.error}');
  }

  Future<dynamic> getAttendanceReport({
    String? batchId,
    String? studentId,
    String? fromDate,
    String? toDate,
  }) async {
    final queryParams = <String, String>{};
    if (batchId != null) queryParams['batchId'] = batchId;
    if (studentId != null) queryParams['studentId'] = studentId;
    if (fromDate != null) queryParams['fromDate'] = fromDate;
    if (toDate != null) queryParams['toDate'] = toDate;

    final response = await _apiClient.get(
      '/ac/attendance/report',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load attendance report: ${response.error}');
  }

  // ==========================================================================
  // FACULTY
  // ==========================================================================

  Future<List<AcFaculty>> listFaculty() async {
    final response = await _apiClient.get('/ac/faculty');
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcFaculty.fromJson(json)).toList();
    }
    throw Exception('Failed to load faculty: ${response.error}');
  }

  Future<AcFaculty> createFaculty(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/faculty', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcFaculty.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create faculty: ${response.error}');
  }

  Future<AcFaculty> getFaculty(String facultyId) async {
    final response = await _apiClient.get('/ac/faculty/$facultyId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcFaculty.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load faculty: ${response.error}');
  }

  Future<AcFaculty> updateFaculty(
    String facultyId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.put('/ac/faculty/$facultyId', body: data);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcFaculty.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update faculty: ${response.error}');
  }

  Future<void> deleteFaculty(String facultyId) async {
    final response = await _apiClient.delete('/ac/faculty/$facultyId');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete faculty: ${response.error}');
    }
  }

  Future<Map<String, dynamic>> getFacultyPayroll(
    String facultyId, {
    String? month,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;

    final response = await _apiClient.get(
      '/ac/faculty/$facultyId/payroll',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load faculty payroll: ${response.error}');
  }

  Future<void> markFacultyAttendance(
    String facultyId, {
    required String date,
    required int classesTaken,
    List<String>? batchIds,
  }) async {
    final response = await _apiClient.post(
      '/ac/faculty/$facultyId/attendance',
      body: {
        'date': date,
        'classesTaken': classesTaken,
        'batchIds': batchIds ?? [],
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to mark faculty attendance: ${response.error}');
    }
  }

  // ==========================================================================
  // EXAMS & RESULTS
  // ==========================================================================

  Future<List<AcExam>> listExams() async {
    final response = await _apiClient.get('/ac/exams');
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcExam.fromJson(json)).toList();
    }
    throw Exception('Failed to load exams: ${response.error}');
  }

  Future<AcExam> createExam(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/exams', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcExam.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create exam: ${response.error}');
  }

  Future<AcExam> getExam(String examId) async {
    final response = await _apiClient.get('/ac/exams/$examId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcExam.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load exam: ${response.error}');
  }

  Future<AcExam> updateExam(String examId, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/ac/exams/$examId', body: data);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcExam.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update exam: ${response.error}');
  }

  Future<void> deleteExam(String examId) async {
    final response = await _apiClient.delete('/ac/exams/$examId');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete exam: ${response.error}');
    }
  }

  Future<List<AcResult>> uploadResults(
    String examId,
    List<Map<String, dynamic>> results,
  ) async {
    final response = await _apiClient.post(
      '/ac/results',
      body: {'examId': examId, 'results': results},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final List<dynamic> items = (data as Map)['results'] ?? [];
      return items.map((json) => AcResult.fromJson(json)).toList();
    }
    throw Exception('Failed to upload results: ${response.error}');
  }

  Future<Map<String, dynamic>> getExamResults(String examId) async {
    final response = await _apiClient.get('/ac/exams/$examId/results');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load exam results: ${response.error}');
  }

  // ==========================================================================
  // TIMETABLE
  // ==========================================================================

  Future<List<dynamic>> getTimetable({
    String? batchId,
    String? facultyId,
    String? weekOf,
  }) async {
    final queryParams = <String, String>{};
    if (batchId != null) queryParams['batchId'] = batchId;
    if (facultyId != null) queryParams['facultyId'] = facultyId;
    if (weekOf != null) queryParams['weekOf'] = weekOf;

    final response = await _apiClient.get(
      '/ac/timetable',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      return data['data'] ?? data['items'] ?? [];
    }
    throw Exception('Failed to load timetable: ${response.error}');
  }

  Future<Map<String, dynamic>> createTimetableSlot(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post('/ac/timetable/slots', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to create timetable slot: ${response.error}');
  }

  // ==========================================================================
  // STUDY MATERIALS
  // ==========================================================================

  Future<List<AcMaterial>> listMaterials({
    String? subjectId,
    String? batchId,
    String? type,
  }) async {
    final queryParams = <String, String>{};
    if (subjectId != null) queryParams['subjectId'] = subjectId;
    if (batchId != null) queryParams['batchId'] = batchId;
    if (type != null) queryParams['type'] = type;

    final response = await _apiClient.get(
      '/ac/materials',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final List<dynamic> items = data['data'] ?? data['items'] ?? [];
      return items.map((json) => AcMaterial.fromJson(json)).toList();
    }
    throw Exception('Failed to load materials: ${response.error}');
  }

  Future<AcMaterial> createMaterial(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/ac/materials', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcMaterial.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create material: ${response.error}');
  }

  Future<AcMaterial> getMaterial(String materialId) async {
    final response = await _apiClient.get('/ac/materials/$materialId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcMaterial.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load material: ${response.error}');
  }

  Future<AcMaterial> updateMaterial(
    String materialId,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.put(
      '/ac/materials/$materialId',
      body: data,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return AcMaterial.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to update material: ${response.error}');
  }

  Future<void> deleteMaterial(String materialId) async {
    final response = await _apiClient.delete('/ac/materials/$materialId');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete material: ${response.error}');
    }
  }

  Future<Map<String, dynamic>> getMaterialDownloadUrl(String materialId) async {
    final response = await _apiClient.get('/ac/materials/$materialId/download');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get download URL: ${response.error}');
  }

  // ==========================================================================
  // REPORTS
  // ==========================================================================

  Future<Map<String, dynamic>> getReportsSummary({
    String type = 'overview',
    String? fromDate,
    String? toDate,
    String? batchId,
    String? courseId,
  }) async {
    final queryParams = <String, String>{'type': type};
    if (fromDate != null) queryParams['fromDate'] = fromDate;
    if (toDate != null) queryParams['toDate'] = toDate;
    if (batchId != null) queryParams['batchId'] = batchId;
    if (courseId != null) queryParams['courseId'] = courseId;

    final response = await _apiClient.get(
      '/ac/reports/summary',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load reports: ${response.error}');
  }

  // ==========================================================================
  // AI RISK DETECTION
  // ==========================================================================

  Future<Map<String, dynamic>> getAtRiskStudents() async {
    final response = await _apiClient.get('/ac/analytics/at-risk-students');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load at-risk students: ${response.error}');
  }

  Future<Map<String, dynamic>> getUpcomingBirthdays({int days = 7}) async {
    final response = await _apiClient.get(
      '/ac/students/birthdays',
      queryParameters: {'days': days.toString()},
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load birthday reminders: ${response.error}');
  }

  // ==========================================================================
  // NOTIFICATIONS
  // ==========================================================================

  Future<List<dynamic>> listNotificationTemplates() async {
    final response = await _apiClient.get('/ac/notifications/templates');
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      return data['data'] ?? data['items'] ?? [];
    }
    throw Exception('Failed to load templates: ${response.error}');
  }

  Future<Map<String, dynamic>> sendNotification({
    required String templateId,
    required List<Map<String, dynamic>> recipients,
    Map<String, dynamic>? variables,
    List<String> channels = const ['sms'],
    String? scheduledAt,
  }) async {
    final response = await _apiClient.post(
      '/ac/notifications/send',
      body: {
        'templateId': templateId,
        'recipients': recipients,
        'variables': variables,
        'channels': channels,
        'scheduledAt': scheduledAt,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to send notification: ${response.error}');
  }

  Future<Map<String, dynamic>> sendFeeReminders() async {
    final response = await _apiClient.post(
      '/ac/notifications/fee-reminders',
      body: null,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to send fee reminders: ${response.error}');
  }

  // ==========================================================================
  // BULK OPERATIONS
  // ==========================================================================

  Future<Map<String, dynamic>> bulkImportStudents({
    required List<Map<String, dynamic>> students,
    String? courseId,
    String? batchId,
    Map<String, dynamic>? defaultValues,
  }) async {
    final response = await _apiClient.post(
      '/ac/bulk/student-import',
      body: {
        'students': students,
        'courseId': courseId,
        'batchId': batchId,
        'defaultValues': defaultValues,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to import students: ${response.error}');
  }

  Future<Map<String, dynamic>> bulkGenerateInvoices({
    String? batchId,
    String? courseId,
    required List<Map<String, dynamic>> feeComponents,
    String? dueDate,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/ac/bulk/generate-invoices',
      body: {
        'batchId': batchId,
        'courseId': courseId,
        'feeComponents': feeComponents,
        'dueDate': dueDate,
        'description': description,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to generate invoices: ${response.error}');
  }

  // ==========================================================================
  // FINANCIAL REPORTS
  // ==========================================================================

  Future<Map<String, dynamic>> getFinancialReports({
    String reportType = 'pl',
    String? fromDate,
    String? toDate,
  }) async {
    final queryParams = <String, String>{'reportType': reportType};
    if (fromDate != null) queryParams['fromDate'] = fromDate;
    if (toDate != null) queryParams['toDate'] = toDate;

    final response = await _apiClient.get(
      '/ac/reports/financial',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load financial reports: ${response.error}');
  }

  // ==========================================================================
  // CERTIFICATES
  // ==========================================================================

  Future<List<dynamic>> listCertificates({
    String? studentId,
    String? type,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null) queryParams['studentId'] = studentId;
    if (type != null) queryParams['type'] = type;

    final response = await _apiClient.get(
      '/ac/certificates',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      return data['data'] ?? data['items'] ?? [];
    }
    throw Exception('Failed to load certificates: ${response.error}');
  }

  Future<Map<String, dynamic>> generateCertificate({
    required String studentId,
    required String type,
    String? templateId,
    String? issueDate,
    String? expiryDate,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _apiClient.post(
      '/ac/certificates/generate',
      body: {
        'studentId': studentId,
        'type': type,
        'templateId': templateId,
        'issueDate': issueDate,
        'expiryDate': expiryDate,
        'metadata': metadata,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to generate certificate: ${response.error}');
  }

  Future<Map<String, dynamic>> downloadCertificate(String certificateId) async {
    final response = await _apiClient.get(
      '/ac/certificates/$certificateId/download',
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get download URL: ${response.error}');
  }

  Future<Map<String, dynamic>> bulkGenerateCertificates({
    required List<String> studentIds,
    required String type,
    String? templateId,
    String? courseId,
    String? issueDate,
  }) async {
    final response = await _apiClient.post(
      '/ac/bulk/certificates',
      body: {
        'studentIds': studentIds,
        'type': type,
        'templateId': templateId,
        'courseId': courseId,
        'issueDate': issueDate,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to bulk generate certificates: ${response.error}');
  }

  // ── Student Photo ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentPhotoUploadUrl(
    String studentId, {
    String contentType = 'image/jpeg',
  }) async {
    final response = await _apiClient.post(
      '/ac/students/$studentId/photo-upload',
      body: {'contentType': contentType},
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get photo upload URL: ${response.error}');
  }

  Future<Map<String, dynamic>> getStudentPhotoUrl(String studentId) async {
    final response = await _apiClient.get('/ac/students/$studentId/photo');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get photo URL: ${response.error}');
  }

  // ── Pending Fees ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPendingFees({
    String? batchId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'batchId': ?batchId,
      'status': ?status,
    };
    final response = await _apiClient.get(
      '/ac/fees/pending',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get pending fees: ${response.error}');
  }

  // ── ID Cards ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateIdCard({
    required String studentId,
    String? validUntil,
    String? templateId,
  }) async {
    final response = await _apiClient.post(
      '/ac/id-cards/generate',
      body: {
        'studentId': studentId,
        'validUntil': ?validUntil,
        'templateId': ?templateId,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to generate ID card: ${response.error}');
  }

  Future<List<Map<String, dynamic>>> listIdCards({String? studentId}) async {
    final params = <String, String>{'studentId': ?studentId};
    final response = await _apiClient.get('/ac/id-cards', queryParams: params);
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      if (data is List) return List<Map<String, dynamic>>.from(data);
    }
    throw Exception('Failed to list ID cards: ${response.error}');
  }

  Future<Map<String, dynamic>> downloadIdCard(String idCardId) async {
    final response = await _apiClient.get('/ac/id-cards/$idCardId/download');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to get ID card download URL: ${response.error}');
  }

  // ── Demo Classes ─────────────────────────────────────────────────────────

  Future<PaginatedResponse<Map<String, dynamic>>> listDemoClasses({
    String? status,
    String? courseId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'status': ?status,
      'courseId': ?courseId,
      'search': ?search,
    };
    final response = await _apiClient.get(
      '/ac/demo-classes',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['demos'] ?? (data is List ? data : []);
      final total = data['total'] ?? (items as List).length;
      return PaginatedResponse(
        items: List<Map<String, dynamic>>.from(items as List),
        total: total as int,
        page: page,
        limit: limit,
        totalPages: ((total as int) / limit).ceil(),
      );
    }
    throw Exception('Failed to list demo classes: ${response.error}');
  }

  Future<Map<String, dynamic>> createDemoClass({
    required String prospectName,
    required String phone,
    required String scheduledAt,
    String? email,
    String? courseId,
    String? batchId,
    String? facultyId,
    String? notes,
    String? source,
  }) async {
    final response = await _apiClient.post(
      '/ac/demo-classes',
      body: {
        'prospectName': prospectName,
        'phone': phone,
        'scheduledAt': scheduledAt,
        'email': ?email,
        'courseId': ?courseId,
        'batchId': ?batchId,
        'facultyId': ?facultyId,
        'notes': ?notes,
        'source': ?source,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to create demo class: ${response.error}');
  }

  Future<Map<String, dynamic>> updateDemoClass(
    String demoId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      '/ac/demo-classes/$demoId',
      body: updates,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to update demo class: ${response.error}');
  }

  Future<Map<String, dynamic>> convertDemoToEnrollment(
    String demoId, {
    List<String> enrolledBatchIds = const [],
    List<String> enrolledCourseIds = const [],
    String? parentName,
    String? parentPhone,
    String? dob,
    String? gender,
    String? address,
  }) async {
    final response = await _apiClient.post(
      '/ac/demo-classes/$demoId/convert',
      body: {
        'enrolledBatchIds': enrolledBatchIds,
        'enrolledCourseIds': enrolledCourseIds,
        'parentName': ?parentName,
        'parentPhone': ?parentPhone,
        'dob': ?dob,
        'gender': ?gender,
        'address': ?address,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to convert demo to enrollment: ${response.error}');
  }

  // ── Classes & Sections ────────────────────────────────────────────────────

  Future<List<AcClassRoom>> listClasses() async {
    final response = await _apiClient.get('/ac/classes');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['classes'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcClassRoom.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list classes: ${response.error}');
  }

  Future<void> createClass({
    required String name,
    String? classTeacherName,
  }) async {
    final response = await _apiClient.post(
      '/ac/classes',
      body: {'name': name, 'classTeacherName': ?classTeacherName},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create class: ${response.error}');
    }
  }

  Future<void> updateClass({
    required String classId,
    required String name,
    String? classTeacherName,
  }) async {
    final response = await _apiClient.put(
      '/ac/classes/$classId',
      body: {'name': name, 'classTeacherName': ?classTeacherName},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to update class: ${response.error}');
  }

  Future<void> deleteClass({required String classId}) async {
    final response = await _apiClient.delete('/ac/classes/$classId');
    if (response.statusCode != 200)
      throw Exception('Failed to delete class: ${response.error}');
  }

  Future<void> addSection({
    required String classId,
    required String sectionName,
    String? teacherName,
  }) async {
    final response = await _apiClient.post(
      '/ac/classes/$classId/sections',
      body: {'name': sectionName, 'teacherName': ?teacherName},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add section: ${response.error}');
    }
  }

  Future<void> updateSection({
    required String classId,
    required String sectionId,
    String? teacherName,
  }) async {
    final response = await _apiClient.put(
      '/ac/classes/$classId/sections/$sectionId',
      body: {'teacherName': ?teacherName},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to update section: ${response.error}');
  }

  Future<void> deleteSection({
    required String classId,
    required String sectionId,
  }) async {
    final response = await _apiClient.delete(
      '/ac/classes/$classId/sections/$sectionId',
    );
    if (response.statusCode != 200)
      throw Exception('Failed to delete section: ${response.error}');
  }

  // ── Academic Year & Terms ─────────────────────────────────────────────────

  Future<List<AcAcademicYear>> listAcademicYears() async {
    final response = await _apiClient.get('/ac/academic-years');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['years'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcAcademicYear.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list academic years: ${response.error}');
  }

  Future<void> createAcademicYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _apiClient.post(
      '/ac/academic-years',
      body: {
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create academic year: ${response.error}');
    }
  }

  Future<void> updateAcademicYear({
    required String yearId,
    required String name,
  }) async {
    final response = await _apiClient.put(
      '/ac/academic-years/$yearId',
      body: {'name': name},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to update academic year: ${response.error}');
  }

  Future<void> deleteAcademicYear({required String yearId}) async {
    final response = await _apiClient.delete('/ac/academic-years/$yearId');
    if (response.statusCode != 200)
      throw Exception('Failed to delete academic year: ${response.error}');
  }

  Future<void> setActiveAcademicYear({required String yearId}) async {
    final response = await _apiClient.post(
      '/ac/academic-years/$yearId/set-active',
      body: {},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to set active year: ${response.error}');
  }

  Future<void> addTerm({
    required String yearId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _apiClient.post(
      '/ac/academic-years/$yearId/terms',
      body: {
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add term: ${response.error}');
    }
  }

  // ── Library ───────────────────────────────────────────────────────────────

  Future<List<AcBook>> listBooks() async {
    final response = await _apiClient.get('/ac/library/books');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['books'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcBook.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list books: ${response.error}');
  }

  Future<void> addBook({
    required String title,
    required String author,
    String? isbn,
    int copies = 1,
  }) async {
    final response = await _apiClient.post(
      '/ac/library/books',
      body: {'title': title, 'author': author, 'copies': copies, 'isbn': ?isbn},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add book: ${response.error}');
    }
  }

  Future<void> deleteBook({required String bookId}) async {
    final response = await _apiClient.delete('/ac/library/books/$bookId');
    if (response.statusCode != 200)
      throw Exception('Failed to delete book: ${response.error}');
  }

  Future<List<AcBookIssue>> listActiveIssues() async {
    final response = await _apiClient.get(
      '/ac/library/issues',
      queryParams: {'status': 'active'},
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['issues'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcBookIssue.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list issues: ${response.error}');
  }

  Future<List<AcBookIssue>> listOverdueIssues() async {
    final response = await _apiClient.get(
      '/ac/library/issues',
      queryParams: {'status': 'overdue'},
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['issues'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcBookIssue.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list overdue issues: ${response.error}');
  }

  Future<void> issueBook({
    required String bookId,
    required String studentName,
    required DateTime dueDate,
  }) async {
    final response = await _apiClient.post(
      '/ac/library/issues',
      body: {
        'bookId': bookId,
        'studentName': studentName,
        'dueDate': dueDate.toIso8601String(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to issue book: ${response.error}');
    }
  }

  Future<void> returnBook({
    required String issueId,
    double? fineCollected,
  }) async {
    final response = await _apiClient.post(
      '/ac/library/issues/$issueId/return',
      body: {'fineCollected': ?fineCollected},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to return book: ${response.error}');
  }

  // ── Transport ─────────────────────────────────────────────────────────────

  Future<List<AcTransportRoute>> listTransportRoutes() async {
    final response = await _apiClient.get('/ac/transport/routes');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['routes'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcTransportRoute.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list transport routes: ${response.error}');
  }

  Future<void> createTransportRoute({
    required String name,
    String? driverName,
    String? vehicleNumber,
  }) async {
    final response = await _apiClient.post(
      '/ac/transport/routes',
      body: {
        'name': name,
        'driverName': ?driverName,
        'vehicleNumber': ?vehicleNumber,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create route: ${response.error}');
    }
  }

  Future<void> updateTransportRoute({
    required String routeId,
    required String name,
    String? driverName,
  }) async {
    final response = await _apiClient.put(
      '/ac/transport/routes/$routeId',
      body: {'name': name, 'driverName': ?driverName},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to update route: ${response.error}');
  }

  Future<void> deleteTransportRoute({required String routeId}) async {
    final response = await _apiClient.delete('/ac/transport/routes/$routeId');
    if (response.statusCode != 200)
      throw Exception('Failed to delete route: ${response.error}');
  }

  Future<void> addTransportStop({
    required String routeId,
    required String stopName,
    String? pickupTime,
  }) async {
    final response = await _apiClient.post(
      '/ac/transport/routes/$routeId/stops',
      body: {'name': stopName, 'pickupTime': ?pickupTime},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add stop: ${response.error}');
    }
  }

  Future<List<AcVehicle>> listVehicles() async {
    final response = await _apiClient.get('/ac/transport/vehicles');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['vehicles'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcVehicle.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list vehicles: ${response.error}');
  }

  Future<void> createVehicle({
    required String number,
    String? driverName,
    String? driverPhone,
    int capacity = 40,
  }) async {
    final response = await _apiClient.post(
      '/ac/transport/vehicles',
      body: {
        'number': number,
        'capacity': capacity,
        'driverName': ?driverName,
        'driverPhone': ?driverPhone,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create vehicle: ${response.error}');
    }
  }

  // ── Report Cards ──────────────────────────────────────────────────────────

  Future<List<AcReportCard>> listReportCards({
    String? classId,
    String? examName,
  }) async {
    final params = <String, String>{'classId': ?classId, 'examName': ?examName};
    final response = await _apiClient.get(
      '/ac/report-cards',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final items =
          data['items'] ?? data['reportCards'] ?? (data is List ? data : []);
      return (items as List)
          .map((j) => AcReportCard.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to list report cards: ${response.error}');
  }

  Future<void> generateReportCards({
    required String classId,
    required String examName,
  }) async {
    final response = await _apiClient.post(
      '/ac/report-cards/generate',
      body: {'classId': classId, 'examName': examName},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to generate report cards: ${response.error}');
    }
  }

  Future<String?> downloadReportCardPdf({required String reportCardId}) async {
    final response = await _apiClient.get('/ac/report-cards/$reportCardId/pdf');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data']?['pdfUrl'] ?? raw['pdfUrl'];
    }
    throw Exception('Failed to download report card: ${response.error}');
  }

  Future<void> shareReportCard({required String reportCardId}) async {
    final response = await _apiClient.post(
      '/ac/report-cards/$reportCardId/share',
      body: {},
    );
    if (response.statusCode != 200)
      throw Exception('Failed to share report card: ${response.error}');
  }

  // ── Classwise Fee Structure ────────────────────────────────────────────────

  Future<List<AcFeeStructure>> listFeeStructures({
    required String classId,
  }) async {
    final response = await _apiClient.get(
      '/ac/fee-structure',
      queryParams: {'classId': classId},
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final List items = raw['data']?['structures'] ?? raw['structures'] ?? [];
      return items
          .map((e) => AcFeeStructure.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load fee structures: ${response.error}');
  }

  Future<AcFeeStructure> createFeeStructure({
    required String classId,
    required String feeHead,
    required double amountRupees,
    required String frequency,
    int? dueDayOfMonth,
    required bool isOptional,
  }) async {
    final response = await _apiClient.post(
      '/ac/fee-structure',
      body: {
        'classId': classId,
        'feeHead': feeHead,
        'amountRupees': amountRupees,
        'frequency': frequency,
        'dueDayOfMonth': ?dueDayOfMonth,
        'isOptional': isOptional,
      },
    );
    if (response.statusCode == 201) {
      final raw = response.data ?? {};
      return AcFeeStructure.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create fee structure: ${response.error}');
  }

  Future<void> updateFeeStructure({
    required String structureId,
    required String classId,
    required String feeHead,
    required double amountRupees,
    required String frequency,
    int? dueDayOfMonth,
    required bool isOptional,
  }) async {
    final response = await _apiClient.put(
      '/ac/fee-structure/$structureId',
      body: {
        'classId': classId,
        'feeHead': feeHead,
        'amountRupees': amountRupees,
        'frequency': frequency,
        'dueDayOfMonth': ?dueDayOfMonth,
        'isOptional': isOptional,
      },
    );
    if (response.statusCode != 200)
      throw Exception('Failed to update fee structure: ${response.error}');
  }

  Future<void> deleteFeeStructure(String classId, String structureId) async {
    final response = await _apiClient.delete('/ac/fee-structure/$structureId');
    if (response.statusCode != 200)
      throw Exception('Failed to delete fee structure: ${response.error}');
  }

  // ==========================================================================
  // ADMISSIONS
  // ==========================================================================

  Future<List<Map<String, dynamic>>> getAdmissionsApplications({
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status != 'all') queryParams['status'] = status;

    final response = await _apiClient.get(
      '/ac/admissions/applications',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items = data['data'] ?? data['items'] ?? [];
      return List<Map<String, dynamic>>.from(items as List);
    }
    throw Exception('Failed to load admissions: ${response.error}');
  }

  Future<void> updateApplicationStatus(
    String id, {
    required String status,
  }) async {
    final response = await _apiClient.patch(
      '/ac/admissions/applications/$id/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update application status: ${response.error}');
    }
  }

  // ==========================================================================
  // HOMEWORK
  // ==========================================================================

  Future<List<Map<String, dynamic>>> getHomework({
    String? batchId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (batchId != null) queryParams['batchId'] = batchId;
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      '/ac/homework',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items = data['data'] ?? data['items'] ?? [];
      return List<Map<String, dynamic>>.from(items as List);
    }
    throw Exception('Failed to load homework: ${response.error}');
  }

  // ==========================================================================
  // LESSON PLANS
  // ==========================================================================

  Future<List<Map<String, dynamic>>> getLessonPlans({
    String? batchId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (batchId != null) queryParams['batchId'] = batchId;
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      '/ac/lesson-plans',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items = data['data'] ?? data['items'] ?? [];
      return List<Map<String, dynamic>>.from(items as List);
    }
    throw Exception('Failed to load lesson plans: ${response.error}');
  }

  Future<void> approveLessonPlan(String id, {required bool approved}) async {
    final response = await _apiClient.patch(
      '/ac/lesson-plans/$id/approve',
      body: {'approved': approved},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to approve lesson plan: ${response.error}');
    }
  }

  Future<void> updateLessonPlanStatus(
    String id, {
    required String status,
  }) async {
    final response = await _apiClient.patch(
      '/ac/lesson-plans/$id/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update lesson plan status: ${response.error}');
    }
  }

  Future<void> deleteLessonPlan(String id) async {
    final response = await _apiClient.delete('/ac/lesson-plans/$id');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete lesson plan: ${response.error}');
    }
  }
}
