import '../api/api_client.dart';

/// Full admin-level access to all School ERP endpoints.
class AdminRepository {
  final ApiClient _api;
  AdminRepository(this._api);

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() async {
    final r = await _api.get('/ac/dashboard', params: {'role': 'admin'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load dashboard');
  }

  // ── Students ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStudents({int page = 1, int limit = 20, String? search, String? batchId, String? status}) async {
    final r = await _api.get('/ac/students', params: {'page': page, 'limit': limit, if (search != null) 'search': search, if (batchId != null) 'batchId': batchId, if (status != null) 'status': status});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load students');
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/students', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create student');
  }

  Future<Map<String, dynamic>> updateStudent(String id, Map<String, dynamic> body) async {
    final r = await _api.put('/ac/students/$id', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to update student');
  }

  // ── Faculty ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFaculty({int page = 1, String? search}) async {
    final r = await _api.get('/ac/faculty', params: {'page': page, if (search != null) 'search': search});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load faculty');
  }

  Future<Map<String, dynamic>> createFaculty(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/faculty', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create faculty');
  }

  // ── Batches / Classes ─────────────────────────────────────────────────────
  Future<List<dynamic>> getBatches() async {
    final r = await _api.get('/ac/batches');
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load batches');
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/batches', body: body);
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to create batch');
  }

  // ── Fees ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeeOverview() async {
    final r = await _api.get('/ac/fees', params: {'view': 'overview'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load fees');
  }

  Future<List<dynamic>> getPendingFees({String? batchId}) async {
    final r = await _api.get('/ac/fees/pending', params: {if (batchId != null) 'batchId': batchId});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load pending fees');
  }

  // ── Admissions ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAdmissions({String? status}) async {
    final r = await _api.get('/ac/admissions', params: {if (status != null) 'status': status});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load admissions');
  }

  Future<void> approveAdmission(String id, String action, {String? remarks}) async {
    final r = await _api.post('/ac/admissions/$id/review', body: {'action': action, if (remarks != null) 'remarks': remarks});
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to process admission');
  }

  // ── Attendance Reports ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAttendanceReport({String? batchId, String? fromDate, String? toDate}) async {
    final r = await _api.get('/ac/attendance', params: {'admin': 'true', if (batchId != null) 'batchId': batchId, if (fromDate != null) 'fromDate': fromDate, if (toDate != null) 'toDate': toDate});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load attendance');
  }

  // ── Reports ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getReports({String? type, String? period}) async {
    final r = await _api.get('/ac/reports', params: {if (type != null) 'type': type, if (period != null) 'period': period});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load reports');
  }

  // ── Leave Approvals ───────────────────────────────────────────────────────
  Future<List<dynamic>> getAllPendingLeaves() async {
    final r = await _api.get('/ac/leave/pending', params: {'admin': 'true'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data?['items'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load leaves');
  }

  Future<void> processLeave(String id, bool approve, {String? remarks}) async {
    final r = await _api.post('/ac/leave/$id/approve', body: {'action': approve ? 'approve' : 'reject', if (remarks != null) 'remarks': remarks});
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to process leave');
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  Future<void> sendAnnouncement(Map<String, dynamic> body) async {
    final r = await _api.post('/ac/communicate', body: body);
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to send announcement');
  }

  // ── Transport ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTransportOverview() async {
    final r = await _api.get('/ac/transport');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load transport');
  }

  // ── Library ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLibraryStats() async {
    final r = await _api.get('/ac/library');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load library');
  }

  // ── Hostel ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getHostelInfo() async {
    final r = await _api.get('/ac/hostel');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load hostel');
  }

  // ── Payroll ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPayrollSummary() async {
    final r = await _api.get('/ac/payslip', params: {'admin': 'true', 'view': 'summary'});
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load payroll');
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getInstitutionConfig() async {
    final r = await _api.get('/ac/config');
    if (r.isSuccess) return (r.data?['data'] ?? r.data) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to load config');
  }

  Future<void> updateInstitutionConfig(Map<String, dynamic> body) async {
    final r = await _api.put('/ac/config', body: body);
    if (!r.isSuccess) throw Exception(r.error ?? 'Failed to update config');
  }

  // ── Analytics (Charts) ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAnalytics({String? period}) async {
    final r = await _api.get('/ac/reports/financial', params: {if (period != null) 'period': period});
    if (r.isSuccess) return (r.data?['data'] ?? r.data ?? {}) as Map<String, dynamic>;
    // Return fallback mock structure so dashboard renders even if endpoint is cold
    return {
      'feeCollection': <Map<String, dynamic>>[],
      'admissionTrend': <Map<String, dynamic>>[],
      'attendanceSummary': {'present': 0.0, 'absent': 0.0, 'leave': 0.0},
    };
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  Future<List<dynamic>> getNotifications({bool unreadOnly = false}) async {
    final r = await _api.get('/ac/notifications', params: {'unread': unreadOnly.toString()});
    if (r.isSuccess) return (r.data?['items'] ?? r.data?['data'] ?? []) as List;
    throw Exception(r.error ?? 'Failed to load notifications');
  }

  Future<void> markNotificationRead(String id) async {
    await _api.put('/ac/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _api.put('/ac/notifications/read-all');
  }

  // ── Fee payment helpers ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> generatePayslips(String month) async {
    final r = await _api.post('/ac/payslip', body: {'month': month, 'bulk': true});
    if (r.isSuccess) return (r.data?['data'] ?? r.data ?? {}) as Map<String, dynamic>;
    throw Exception(r.error ?? 'Failed to generate payslips');
  }
}
