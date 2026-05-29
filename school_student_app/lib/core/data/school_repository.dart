import '../api/api_client.dart';

/// Thin repository — all School ERP API calls for the student portal.
/// Endpoints match the backend at my-backend/src/modules/school-erp/
class SchoolRepository {
  final ApiClient _api;
  SchoolRepository(this._api);

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final r = await _api.get('/ac/dashboard');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load dashboard');
  }

  // ── Timetable ─────────────────────────────────────────────────────────────
  Future<List<dynamic>> getTimetable({String? batchId, String? weekOf}) async {
    final r = await _api.get('/ac/timetable', params: {
      if (batchId != null) 'batchId': batchId,
      if (weekOf != null) 'weekOf': weekOf,
    });
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load timetable');
  }

  // ── Attendance ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyAttendance({String? fromDate, String? toDate}) async {
    final r = await _api.get('/ac/attendance', params: {
      if (fromDate != null) 'fromDate': fromDate,
      if (toDate != null) 'toDate': toDate,
      'myView': 'true',
    });
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load attendance');
  }

  // ── Exams & Results ───────────────────────────────────────────────────────
  Future<List<dynamic>> getMyExams() async {
    final r = await _api.get('/ac/exams', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load exams');
  }

  Future<Map<String, dynamic>> getMyResults({String? examId}) async {
    final r = await _api.get('/ac/results', params: {
      'myView': 'true',
      if (examId != null) 'examId': examId,
    });
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load results');
  }

  // ── Fees ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyFees() async {
    final r = await _api.get('/ac/fees', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load fees');
  }

  Future<Map<String, dynamic>> createPaymentOrder(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/payments/create-order', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create payment order');
  }

  Future<Map<String, dynamic>> verifyPayment(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/payments/verify', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to verify payment');
  }

  Future<Map<String, dynamic>> getPaymentHistory() async {
    final r = await _api.get('/ac/payments', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load payment history');
  }

  // ── Study Materials ───────────────────────────────────────────────────────
  Future<List<dynamic>> getMaterials({String? batchId, String? type}) async {
    final r = await _api.get('/ac/materials', params: {
      if (batchId != null) 'batchId': batchId,
      if (type != null) 'type': type,
    });
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load materials');
  }

  Future<Map<String, dynamic>> getMaterialDownloadUrl(String id) async {
    final r = await _api.get('/ac/materials/$id/download');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to get download URL');
  }

  // ── Homework ──────────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyHomework({String? status}) async {
    final r = await _api.get('/ac/homework', params: {
      'myView': 'true',
      if (status != null) 'status': status,
    });
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load homework');
  }

  Future<Map<String, dynamic>> submitHomework(String homeworkId, Map<String, dynamic> body) async {
    final r = await _api.post('/ac/homework/$homeworkId/submit', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to submit homework');
  }

  // ── Leave ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyLeave() async {
    final r = await _api.get('/ac/leave', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load leave');
  }

  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/leave', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to apply for leave');
  }

  Future<Map<String, dynamic>> getLeaveBalance() async {
    final r = await _api.get('/ac/leave/balance/student/me');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load leave balance');
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getNotifications() async {
    final r = await _api.get('/ac/communicate', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load notifications');
  }

  // ── Library ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLibraryInfo() async {
    final r = await _api.get('/ac/library', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load library info');
  }

  // ── Transport ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyTransport() async {
    final r = await _api.get('/ac/transport', params: {'myView': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load transport info');
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyProfile() async {
    final r = await _api.get('/ac/students/me');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load profile');
  }
}
