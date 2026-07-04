/// Staff Management Module
///
/// Provides employee management, attendance tracking, and payroll
/// with offline-first architecture.
library;

// Data Layer — Legacy
export 'data/models/staff_model.dart';
export 'data/models/attendance_model.dart';
export 'data/models/salary_model.dart';
export 'data/repositories/staff_repository.dart';
export 'data/services/payroll_service.dart';

// Data Layer — Universal Staff Management
export 'data/models/employee_model.dart';
export 'data/models/department_model.dart';
export 'data/models/designation_model.dart';
export 'data/models/attendance_event_model.dart';
export 'data/models/shift_model.dart';
export 'data/models/roster_model.dart';
export 'data/models/leave_type_model.dart';
export 'data/models/leave_request_model.dart';
export 'data/models/leave_balance_model.dart';
export 'data/models/task_model.dart';
export 'data/models/payroll_run_model.dart';
export 'data/models/payslip_model.dart';
export 'data/models/salary_component_model.dart';
export 'data/models/commission_rule_model.dart';
export 'data/models/performance_score_model.dart';
export 'data/repositories/staff_management_repository.dart';
export 'data/services/conflict_policy_registry.dart';
export 'data/services/staff_reconciliation.dart';

// Providers — Universal Staff Management (config-gated)
export 'providers/staff_feature_keys.dart';
export 'providers/employees_notifier.dart';
export 'providers/attendance_notifier.dart';
export 'providers/leave_notifier.dart';
export 'providers/tasks_notifier.dart';
export 'providers/payroll_view_notifier.dart';
export 'providers/performance_notifier.dart';
