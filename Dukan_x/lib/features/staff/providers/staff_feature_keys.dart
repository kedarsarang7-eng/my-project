/// Feature keys for the Universal Staff Management module.
///
/// These keys correspond to entries in the tenant's `effectiveFeatures` list
/// served by GET /tenant/config. A sub-area provider checks its key via
/// [featureEnabledProvider] before loading data.
library;

/// Staff module feature keys — matches STAFF_* keys in plan-feature-registry.
class StaffFeatureKeys {
  StaffFeatureKeys._();

  /// Core employee/department/designation management.
  static const String employees = 'staff_employees';

  /// Attendance and shift management.
  static const String attendance = 'staff_attendance';

  /// Leave management (types, requests, balances, calendar).
  static const String leave = 'staff_leave';

  /// Task management (assignments, recurrence, escalation).
  static const String tasks = 'staff_tasks';

  /// Payroll viewing (payslips, salary components). Payroll runs are online-only.
  static const String payroll = 'staff_payroll';

  /// Performance scoring and commission rules.
  static const String performance = 'staff_performance';
}
