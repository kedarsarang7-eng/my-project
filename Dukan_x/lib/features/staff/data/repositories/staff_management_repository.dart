import '../../../../core/api/api_client.dart';
import '../models/employee_model.dart';
import '../models/department_model.dart';
import '../models/designation_model.dart';
import '../models/attendance_event_model.dart';
import '../models/shift_model.dart';
import '../models/roster_model.dart';
import '../models/leave_type_model.dart';
import '../models/leave_request_model.dart';
import '../models/leave_balance_model.dart';
import '../models/task_model.dart';
import '../models/payroll_run_model.dart';
import '../models/payslip_model.dart';
import '../models/salary_component_model.dart';
import '../models/commission_rule_model.dart';
import '../models/performance_score_model.dart';

/// REST-based repository for the Universal Staff Management module.
///
/// Uses [ApiClient] to communicate with the `/staff/*` backend endpoints.
/// Follows the same pattern as [CustomerRepository] and [JewelleryRepository].
class StaffManagementRepository {
  final ApiClient _apiClient;

  StaffManagementRepository(this._apiClient);

  // ─── Helpers ───────────────────────────────────────────────────────────────

  List<T> _parseList<T>(
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
    String key,
  ) {
    if (data == null) return [];
    final items = data['items'] ?? data[key] ?? (data is List ? data : []);
    return (items as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Employees ─────────────────────────────────────────────────────────────

  Future<List<EmployeeModel>> getEmployees({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null) params['search'] = search;

    final response = await _apiClient.get(
      '/staff/employees',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(response.data, EmployeeModel.fromJson, 'employees');
    }
    throw Exception('Failed to load employees: ${response.error}');
  }

  Future<EmployeeModel> getEmployee(String id) async {
    final response = await _apiClient.get('/staff/employees/$id');
    if (response.statusCode == 200) {
      return EmployeeModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to load employee: ${response.error}');
  }

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/employees', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return EmployeeModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create employee: ${response.error}');
  }

  Future<EmployeeModel> updateEmployee(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch('/staff/employees/$id', body: data);
    if (response.statusCode == 200) {
      return EmployeeModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update employee: ${response.error}');
  }

  Future<void> deactivateEmployee(String id) async {
    final response = await _apiClient.patch(
      '/staff/employees/$id',
      body: {'status': 'inactive'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to deactivate employee: ${response.error}');
    }
  }

  // ─── Departments ───────────────────────────────────────────────────────────

  Future<List<DepartmentModel>> getDepartments() async {
    final response = await _apiClient.get('/staff/departments');
    if (response.statusCode == 200) {
      return _parseList(response.data, DepartmentModel.fromJson, 'departments');
    }
    throw Exception('Failed to load departments: ${response.error}');
  }

  Future<DepartmentModel> createDepartment(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/departments', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DepartmentModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create department: ${response.error}');
  }

  Future<DepartmentModel> updateDepartment(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      '/staff/departments/$id',
      body: data,
    );
    if (response.statusCode == 200) {
      return DepartmentModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update department: ${response.error}');
  }

  Future<void> deactivateDepartment(String id) async {
    final response = await _apiClient.patch(
      '/staff/departments/$id',
      body: {'status': 'inactive'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to deactivate department: ${response.error}');
    }
  }

  // ─── Designations ─────────────────────────────────────────────────────────

  Future<List<DesignationModel>> getDesignations() async {
    final response = await _apiClient.get('/staff/designations');
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        DesignationModel.fromJson,
        'designations',
      );
    }
    throw Exception('Failed to load designations: ${response.error}');
  }

  Future<DesignationModel> createDesignation(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/designations', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return DesignationModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create designation: ${response.error}');
  }

  Future<DesignationModel> updateDesignation(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      '/staff/designations/$id',
      body: data,
    );
    if (response.statusCode == 200) {
      return DesignationModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update designation: ${response.error}');
  }

  Future<void> deactivateDesignation(String id) async {
    final response = await _apiClient.patch(
      '/staff/designations/$id',
      body: {'status': 'inactive'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to deactivate designation: ${response.error}');
    }
  }

  // ─── Attendance Events ─────────────────────────────────────────────────────

  Future<List<AttendanceEventModel>> getAttendanceEvents({
    String? employeeId,
    String? from,
    String? to,
    int page = 1,
    int limit = 100,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (employeeId != null) params['employeeId'] = employeeId;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await _apiClient.get(
      '/staff/attendance/events',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(response.data, AttendanceEventModel.fromJson, 'events');
    }
    throw Exception('Failed to load attendance events: ${response.error}');
  }

  Future<AttendanceEventModel> createAttendanceEvent(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post(
      '/staff/attendance/events',
      body: data,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AttendanceEventModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create attendance event: ${response.error}');
  }

  // ─── Shifts ────────────────────────────────────────────────────────────────

  Future<List<ShiftModel>> getShifts() async {
    final response = await _apiClient.get('/staff/shifts');
    if (response.statusCode == 200) {
      return _parseList(response.data, ShiftModel.fromJson, 'shifts');
    }
    throw Exception('Failed to load shifts: ${response.error}');
  }

  Future<ShiftModel> createShift(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/shifts', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ShiftModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create shift: ${response.error}');
  }

  Future<ShiftModel> updateShift(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch('/staff/shifts/$id', body: data);
    if (response.statusCode == 200) {
      return ShiftModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update shift: ${response.error}');
  }

  // ─── Rosters ───────────────────────────────────────────────────────────────

  Future<List<RosterModel>> getRosters({String? date}) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;

    final response = await _apiClient.get(
      '/staff/rosters',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(response.data, RosterModel.fromJson, 'rosters');
    }
    throw Exception('Failed to load rosters: ${response.error}');
  }

  Future<RosterModel> createRoster(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/rosters', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return RosterModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create roster: ${response.error}');
  }

  // ─── Leave Types ───────────────────────────────────────────────────────────

  Future<List<LeaveTypeModel>> getLeaveTypes() async {
    final response = await _apiClient.get('/staff/leave/types');
    if (response.statusCode == 200) {
      return _parseList(response.data, LeaveTypeModel.fromJson, 'leaveTypes');
    }
    throw Exception('Failed to load leave types: ${response.error}');
  }

  Future<LeaveTypeModel> createLeaveType(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/leave/types', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return LeaveTypeModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create leave type: ${response.error}');
  }

  // ─── Leave Requests ────────────────────────────────────────────────────────

  Future<List<LeaveRequestModel>> getLeaveRequests({
    String? employeeId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = employeeId;
    if (status != null) params['status'] = status;

    final response = await _apiClient.get(
      '/staff/leave/requests',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        LeaveRequestModel.fromJson,
        'leaveRequests',
      );
    }
    throw Exception('Failed to load leave requests: ${response.error}');
  }

  Future<LeaveRequestModel> createLeaveRequest(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post('/staff/leave/requests', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return LeaveRequestModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create leave request: ${response.error}');
  }

  Future<LeaveRequestModel> approveLeaveRequest(String id) async {
    final response = await _apiClient.patch(
      '/staff/leave/requests/$id',
      body: {'status': 'approved'},
    );
    if (response.statusCode == 200) {
      return LeaveRequestModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to approve leave request: ${response.error}');
  }

  Future<LeaveRequestModel> rejectLeaveRequest(String id) async {
    final response = await _apiClient.patch(
      '/staff/leave/requests/$id',
      body: {'status': 'rejected'},
    );
    if (response.statusCode == 200) {
      return LeaveRequestModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to reject leave request: ${response.error}');
  }

  // ─── Leave Balances ────────────────────────────────────────────────────────

  Future<List<LeaveBalanceModel>> getLeaveBalances({String? employeeId}) async {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = employeeId;

    final response = await _apiClient.get(
      '/staff/leave/balances',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        LeaveBalanceModel.fromJson,
        'leaveBalances',
      );
    }
    throw Exception('Failed to load leave balances: ${response.error}');
  }

  // ─── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<StaffTaskModel>> getTasks({
    String? assigneeId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (assigneeId != null) params['assigneeId'] = assigneeId;
    if (status != null) params['status'] = status;

    final response = await _apiClient.get('/staff/tasks', queryParams: params);
    if (response.statusCode == 200) {
      return _parseList(response.data, StaffTaskModel.fromJson, 'tasks');
    }
    throw Exception('Failed to load tasks: ${response.error}');
  }

  Future<StaffTaskModel> createTask(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/tasks', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return StaffTaskModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create task: ${response.error}');
  }

  Future<StaffTaskModel> updateTask(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch('/staff/tasks/$id', body: data);
    if (response.statusCode == 200) {
      return StaffTaskModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update task: ${response.error}');
  }

  // ─── Payroll ───────────────────────────────────────────────────────────────

  Future<List<PayrollRunModel>> getPayrollRuns({String? period}) async {
    final params = <String, String>{};
    if (period != null) params['period'] = period;

    final response = await _apiClient.get(
      '/staff/payroll/runs',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(response.data, PayrollRunModel.fromJson, 'payrollRuns');
    }
    throw Exception('Failed to load payroll runs: ${response.error}');
  }

  Future<PayrollRunModel> createPayrollRun(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/staff/payroll/runs', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PayrollRunModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create payroll run: ${response.error}');
  }

  // ─── Payslips ──────────────────────────────────────────────────────────────

  Future<List<PayslipModel>> getPayslips({
    String? employeeId,
    String? period,
  }) async {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = employeeId;
    if (period != null) params['period'] = period;

    final response = await _apiClient.get(
      '/staff/payslips',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(response.data, PayslipModel.fromJson, 'payslips');
    }
    throw Exception('Failed to load payslips: ${response.error}');
  }

  // ─── Salary Components ─────────────────────────────────────────────────────

  Future<List<SalaryComponentModel>> getSalaryComponents({
    required String employeeId,
  }) async {
    final params = <String, String>{'employeeId': employeeId};

    final response = await _apiClient.get(
      '/staff/salary-components',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        SalaryComponentModel.fromJson,
        'salaryComponents',
      );
    }
    throw Exception('Failed to load salary components: ${response.error}');
  }

  Future<SalaryComponentModel> createSalaryComponent(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post(
      '/staff/salary-components',
      body: data,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return SalaryComponentModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create salary component: ${response.error}');
  }

  Future<SalaryComponentModel> updateSalaryComponent(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      '/staff/salary-components/$id',
      body: data,
    );
    if (response.statusCode == 200) {
      return SalaryComponentModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update salary component: ${response.error}');
  }

  // ─── Commission Rules ──────────────────────────────────────────────────────

  Future<List<CommissionRuleModel>> getCommissionRules() async {
    final response = await _apiClient.get('/staff/commission/rules');
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        CommissionRuleModel.fromJson,
        'commissionRules',
      );
    }
    throw Exception('Failed to load commission rules: ${response.error}');
  }

  Future<CommissionRuleModel> createCommissionRule(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.post(
      '/staff/commission/rules',
      body: data,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return CommissionRuleModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to create commission rule: ${response.error}');
  }

  Future<CommissionRuleModel> updateCommissionRule(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.patch(
      '/staff/commission/rules/$id',
      body: data,
    );
    if (response.statusCode == 200) {
      return CommissionRuleModel.fromJson(response.data ?? {});
    }
    throw Exception('Failed to update commission rule: ${response.error}');
  }

  // ─── Performance Scores ────────────────────────────────────────────────────

  Future<List<PerformanceScoreModel>> getPerformanceScores({
    String? employeeId,
    String? period,
  }) async {
    final params = <String, String>{};
    if (employeeId != null) params['employeeId'] = employeeId;
    if (period != null) params['period'] = period;

    final response = await _apiClient.get(
      '/staff/performance/scores',
      queryParams: params,
    );
    if (response.statusCode == 200) {
      return _parseList(
        response.data,
        PerformanceScoreModel.fromJson,
        'performanceScores',
      );
    }
    throw Exception('Failed to load performance scores: ${response.error}');
  }
}
