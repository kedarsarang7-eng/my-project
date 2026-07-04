import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/employee_model.dart';
import '../data/models/department_model.dart';
import '../data/models/designation_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the employees sub-area (employees, departments, designations).
class EmployeesState {
  final List<EmployeeModel> employees;
  final List<DepartmentModel> departments;
  final List<DesignationModel> designations;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const EmployeesState({
    this.employees = const [],
    this.departments = const [],
    this.designations = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  EmployeesState copyWith({
    List<EmployeeModel>? employees,
    List<DepartmentModel>? departments,
    List<DesignationModel>? designations,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return EmployeesState(
      employees: employees ?? this.employees,
      departments: departments ?? this.departments,
      designations: designations ?? this.designations,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class EmployeesNotifier extends StateNotifier<EmployeesState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  EmployeesNotifier(this._ref) : super(const EmployeesState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.employees),
    );
    if (!enabled) {
      state = const EmployeesState(isDisabled: true);
      return;
    }
    loadAll();
  }

  /// Load employees, departments, and designations in parallel.
  Future<void> loadAll() async {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.employees),
    );
    if (!enabled) {
      state = const EmployeesState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getEmployees(),
        _repo.getDepartments(),
        _repo.getDesignations(),
      ]);

      state = EmployeesState(
        employees: results[0] as List<EmployeeModel>,
        departments: results[1] as List<DepartmentModel>,
        designations: results[2] as List<DesignationModel>,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh the employee list only.
  Future<void> refreshEmployees({String? search}) async {
    if (state.isDisabled) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final employees = await _repo.getEmployees(search: search);
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new employee.
  Future<EmployeeModel?> createEmployee(Map<String, dynamic> data) async {
    if (state.isDisabled) return null;
    try {
      final created = await _repo.createEmployee(data);
      state = state.copyWith(employees: [...state.employees, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Deactivate an employee.
  Future<bool> deactivateEmployee(String id) async {
    if (state.isDisabled) return false;
    try {
      await _repo.deactivateEmployee(id);
      state = state.copyWith(
        employees: state.employees
            .map(
              (e) => e.id == id
                  ? EmployeeModel(
                      id: e.id,
                      businessId: e.businessId,
                      fullName: e.fullName,
                      designationId: e.designationId,
                      departmentId: e.departmentId,
                      status: 'inactive',
                      phone: e.phone,
                      email: e.email,
                      createdAt: e.createdAt,
                      updatedAt: DateTime.now(),
                    )
                  : e,
            )
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, EmployeesState>((ref) {
      return EmployeesNotifier(ref);
    });
