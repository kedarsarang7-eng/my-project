import '../api/api_client.dart';

/// Teacher/Staff portal repository — all write-enabled calls plus filtered reads.
class TeacherRepository {
  final ApiClient _api;
  TeacherRepository(this._api);

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final r = await _api.get('/ac/dashboard', params: {'role': 'teacher'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load dashboard');
  }

  // ── Timetable ─────────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyTimetable({String? weekOf}) async {
    final r = await _api.get('/ac/timetable', params: {'myView': 'true', if (weekOf != null) 'weekOf': weekOf});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load timetable');
  }

  // ── Students ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> getStudents({String? batchId, String? search}) async {
    final r = await _api.get('/ac/students', params: {if (batchId != null) 'batchId': batchId, if (search != null) 'search': search});
    if (r.isSuccess) return ((r.data?['data']?['items'] ?? r.data?['items'] ?? [])) as List;
    throw Exception(r.error ?? 'Failed to load students');
  }

  // ── Batches ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> getBatches() async {
    final r = await _api.get('/ac/batches', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load batches');
  }

  // ── Attendance — Mark ─────────────────────────────────────────────────────
  Future<void> markAttendance(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/attendance', body: body);
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to mark attendance');
  }

  Future<Map<String, dynamic>> getAttendanceReport({String? batchId, String? date}) async {
    final r = await _api.get('/ac/attendance', params: {if (batchId != null) 'batchId': batchId, if (date != null) 'date': date});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load attendance');
  }

  // ── Exams & Results ───────────────────────────────────────────────────────
  Future<List<dynamic>> getExams({String? batchId}) async {
    final r = await _api.get('/ac/exams', params: {if (batchId != null) 'batchId': batchId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load exams');
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/exams', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create exam');
  }

  Future<void> uploadResults(String examId, List<Map<String, dynamic>> results) async {
    final r = await _api.post('/ac/results', body: {'examId': examId, 'results': results});
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to upload results');
  }

  // ── Homework ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> getHomework({String? batchId}) async {
    final r = await _api.get('/ac/homework', params: {if (batchId != null) 'batchId': batchId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load homework');
  }

  Future<Map<String, dynamic>> createHomework(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/homework', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create homework');
  }

  Future<List<dynamic>> getHomeworkSubmissions(String homeworkId) async {
    final r = await _api.get('/ac/homework/submissions', params: {'homeworkId': homeworkId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load submissions');
  }

  Future<void> gradeSubmission(String submissionId, Map<String, dynamic> body) async {
    final r = await _api.post('/ac/homework/submissions/$submissionId/grade', body: body);
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to grade submission');
  }

  // ── Lesson Plans ──────────────────────────────────────────────────────────
  Future<List<dynamic>> getLessonPlans({String? batchId}) async {
    final r = await _api.get('/ac/lesson-plans', params: {if (batchId != null) 'batchId': batchId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load lesson plans');
  }

  Future<Map<String, dynamic>> createLessonPlan(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/lesson-plans', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create lesson plan');
  }

  // ── Study Materials ───────────────────────────────────────────────────────
  Future<List<dynamic>> getMaterials({String? batchId}) async {
    final r = await _api.get('/ac/materials', params: {if (batchId != null) 'batchId': batchId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load materials');
  }

  Future<Map<String, dynamic>> createMaterial(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/materials', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create material');
  }

  Future<Map<String, dynamic>> getUploadPresignUrl(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/materials/presign', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to get upload URL');
  }

  // ── Leave ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyLeave() async {
    final r = await _api.get('/ac/leave', params: {'myView': 'true', 'personType': 'faculty'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load leave');
  }

  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/leave', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to apply for leave');
  }

  Future<List<dynamic>> getPendingLeaves() async {
    final r = await _api.get('/ac/leave/pending');
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load pending leaves');
  }

  Future<void> approveLeave(String leaveId, bool approve, {String? remarks}) async {
    final r = await _api.post('/ac/leave/$leaveId/approve', body: {'action': approve ? 'approve' : 'reject', 'remarks': remarks});
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to update leave');
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  Future<void> sendAnnouncement(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/communicate', body: body);
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to send announcement');
  }

  // ── Payslip ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyPayslips() async {
    final r = await _api.get('/ac/payslip', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load payslips');
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyProfile() async {
    final r = await _api.get('/ac/faculty/me');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load profile');
  }
}
