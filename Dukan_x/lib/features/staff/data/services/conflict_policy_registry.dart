// ============================================================================
// CONFLICT POLICY REGISTRY — Universal Staff Management
// ============================================================================
// Central registry defining per-entity conflict resolution policies and
// offline capabilities for the staff module. This file implements Req 12.1
// (explicit Conflict_Policy per entity) and Req 12.2 (offline-capable
// operations proceed against the Local_Database).
//
// The design's conflict policy table:
//   - AttendanceEvent: create offline, merge by (eventId, timestamp), append-only
//   - LeaveRequest: create/view offline, optimistic local, server-authoritative
//   - Task: create/update/view offline, last-writer-wins scalars, additive merge
//   - Employee/Dept/Designation: view offline; edit online-preferred, field-level merge
//   - Payslip: view only (read from last synced cache; never written offline)
//   - PayrollRun: none (online-only, single-writer lock)
//
// Author: DukanX Engineering
// ============================================================================

/// The strategy the sync engine uses to resolve conflicts for an entity.
enum ConflictResolutionStrategy {
  /// Append-only: events merge by unique key, no user conflict possible.
  /// Used for AttendanceEvent — merge by (eventId, timestamp).
  appendOnly,

  /// Server-authoritative: local is optimistic; server state wins on sync.
  /// Conflicting concurrent approvals surface to a manager for resolution.
  serverAuthoritative,

  /// Last-writer-wins on scalar fields; list fields (comments, checklist)
  /// are merged additively (union of items).
  lastWriterWinsWithAdditiveMerge,

  /// Field-level merge: non-conflicting field changes are merged automatically;
  /// fields changed on both sides without agreement surface to the user.
  fieldLevelMerge,

  /// Read-only from cache: entity is never written offline; reads come from
  /// the last synced Drift cache.
  readOnlyCache,

  /// Online-only: no offline capability; requires a live connection.
  onlineOnly,
}

/// Operations that can be performed offline for a given entity.
enum OfflineCapability { create, update, view }

/// Configuration for a single staff entity's conflict handling and offline
/// behavior.
class StaffEntityConflictPolicy {
  /// The staff entity type identifier (matches `entityType` in OfflineMutation
  /// and `targetCollection` in SyncQueueItem).
  final String entityType;

  /// Which operations are allowed while offline.
  final Set<OfflineCapability> offlineCapabilities;

  /// How conflicts are resolved during sync reconciliation.
  final ConflictResolutionStrategy resolutionStrategy;

  /// The merge key fields used for deduplication during sync (e.g.,
  /// `['eventId', 'timestamp']` for attendance events).
  final List<String> mergeKeyFields;

  /// Fields that are merged additively (union) rather than overwritten.
  /// Applies to [lastWriterWinsWithAdditiveMerge] strategy.
  final List<String> additiveFields;

  /// Whether unresolvable conflicts should surface to the user via the
  /// conflict resolution dialog.
  final bool surfaceUnresolvable;

  /// Human-readable description for debugging / logging.
  final String description;

  const StaffEntityConflictPolicy({
    required this.entityType,
    required this.offlineCapabilities,
    required this.resolutionStrategy,
    this.mergeKeyFields = const [],
    this.additiveFields = const [],
    this.surfaceUnresolvable = false,
    this.description = '',
  });

  /// Whether this entity supports any offline writes (create or update).
  bool get supportsOfflineWrite =>
      offlineCapabilities.contains(OfflineCapability.create) ||
      offlineCapabilities.contains(OfflineCapability.update);

  /// Whether this entity supports offline reads (view).
  bool get supportsOfflineRead =>
      offlineCapabilities.contains(OfflineCapability.view);

  /// Whether this entity is online-only (no offline capability at all).
  bool get isOnlineOnly => offlineCapabilities.isEmpty;
}

/// Central registry of conflict policies for all Universal Staff Management
/// entities. Mirrors the design document's "Conflict policy registry" table.
///
/// Usage:
/// ```dart
/// final policy = StaffConflictPolicyRegistry.forEntity('staff_attendance_events');
/// if (policy.supportsOfflineWrite) {
///   // Route through OfflineQueue
/// }
/// ```
class StaffConflictPolicyRegistry {
  StaffConflictPolicyRegistry._();

  // ─── Entity Type Constants ─────────────────────────────────────────────────
  // These match the localTableName values in sync_table_registry.dart.

  static const String attendanceEvent = 'staff_attendance_events';
  static const String leaveRequest = 'staff_leave_requests';
  static const String leaveBalance = 'staff_leave_balances';
  static const String leaveType = 'staff_leave_types';
  static const String task = 'staff_tasks';
  static const String employee = 'staff_employees';
  static const String department = 'staff_departments';
  static const String designation = 'staff_designations';
  static const String shift = 'staff_shifts';
  static const String roster = 'staff_rosters';
  static const String payslip = 'staff_payslips';
  static const String payrollRun = 'staff_payroll_runs';
  static const String salaryComponent = 'staff_salary_components';
  static const String commissionRule = 'staff_commission_rules';
  static const String performanceScore = 'staff_performance_scores';

  // ─── Policy Definitions ────────────────────────────────────────────────────

  static const _attendanceEventPolicy = StaffEntityConflictPolicy(
    entityType: attendanceEvent,
    offlineCapabilities: {OfflineCapability.create, OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.appendOnly,
    mergeKeyFields: ['eventId', 'timestamp'],
    surfaceUnresolvable: false,
    description:
        'Append-only. Merge by (eventId, timestamp). No user conflict.',
  );

  static const _leaveRequestPolicy = StaffEntityConflictPolicy(
    entityType: leaveRequest,
    offlineCapabilities: {OfflineCapability.create, OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: true,
    description:
        'Optimistic local; server-authoritative on sync. '
        'Conflicting approvals → manager resolution.',
  );

  static const _leaveBalancePolicy = StaffEntityConflictPolicy(
    entityType: leaveBalance,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; balances are server-authoritative.',
  );

  static const _leaveTypePolicy = StaffEntityConflictPolicy(
    entityType: leaveType,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; leave type config is server-authoritative.',
  );

  static const _taskPolicy = StaffEntityConflictPolicy(
    entityType: task,
    offlineCapabilities: {
      OfflineCapability.create,
      OfflineCapability.update,
      OfflineCapability.view,
    },
    resolutionStrategy:
        ConflictResolutionStrategy.lastWriterWinsWithAdditiveMerge,
    mergeKeyFields: ['id'],
    additiveFields: ['comments', 'checklist'],
    surfaceUnresolvable: false,
    description:
        'Last-writer-wins on scalars; comments/checklist merged additively.',
  );

  static const _employeePolicy = StaffEntityConflictPolicy(
    entityType: employee,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.fieldLevelMerge,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: true,
    description:
        'View offline; edit online-preferred. Field-level merge; '
        'unresolved → surface to user.',
  );

  static const _departmentPolicy = StaffEntityConflictPolicy(
    entityType: department,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.fieldLevelMerge,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: true,
    description:
        'View offline; edit online-preferred. Field-level merge; '
        'unresolved → surface to user.',
  );

  static const _designationPolicy = StaffEntityConflictPolicy(
    entityType: designation,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.fieldLevelMerge,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: true,
    description:
        'View offline; edit online-preferred. Field-level merge; '
        'unresolved → surface to user.',
  );

  static const _shiftPolicy = StaffEntityConflictPolicy(
    entityType: shift,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; shift config is server-authoritative.',
  );

  static const _rosterPolicy = StaffEntityConflictPolicy(
    entityType: roster,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; roster is server-authoritative.',
  );

  static const _payslipPolicy = StaffEntityConflictPolicy(
    entityType: payslip,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.readOnlyCache,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description:
        'View only. Read from last synced cache; never written offline.',
  );

  static const _payrollRunPolicy = StaffEntityConflictPolicy(
    entityType: payrollRun,
    offlineCapabilities: {},
    resolutionStrategy: ConflictResolutionStrategy.onlineOnly,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'Online-only. Single-writer lock. No offline capability.',
  );

  static const _salaryComponentPolicy = StaffEntityConflictPolicy(
    entityType: salaryComponent,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; salary data is server-authoritative.',
  );

  static const _commissionRulePolicy = StaffEntityConflictPolicy(
    entityType: commissionRule,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; commission rules are server-authoritative.',
  );

  static const _performanceScorePolicy = StaffEntityConflictPolicy(
    entityType: performanceScore,
    offlineCapabilities: {OfflineCapability.view},
    resolutionStrategy: ConflictResolutionStrategy.serverAuthoritative,
    mergeKeyFields: ['id'],
    surfaceUnresolvable: false,
    description: 'View offline; scores are server-authoritative.',
  );

  // ─── Registry Map ──────────────────────────────────────────────────────────

  /// All registered conflict policies, keyed by entity type.
  static final Map<String, StaffEntityConflictPolicy> _policies =
      Map.unmodifiable({
        attendanceEvent: _attendanceEventPolicy,
        leaveRequest: _leaveRequestPolicy,
        leaveBalance: _leaveBalancePolicy,
        leaveType: _leaveTypePolicy,
        task: _taskPolicy,
        employee: _employeePolicy,
        department: _departmentPolicy,
        designation: _designationPolicy,
        shift: _shiftPolicy,
        roster: _rosterPolicy,
        payslip: _payslipPolicy,
        payrollRun: _payrollRunPolicy,
        salaryComponent: _salaryComponentPolicy,
        commissionRule: _commissionRulePolicy,
        performanceScore: _performanceScorePolicy,
      });

  /// All registered policies as an unmodifiable list.
  static List<StaffEntityConflictPolicy> get allPolicies =>
      _policies.values.toList();

  /// Look up the conflict policy for a given entity type.
  ///
  /// Returns `null` if the entity type is not registered in this module.
  static StaffEntityConflictPolicy? forEntity(String entityType) =>
      _policies[entityType];

  /// Returns all entity types that support offline writes (create or update).
  static List<String> get offlineWritableEntities => _policies.entries
      .where((e) => e.value.supportsOfflineWrite)
      .map((e) => e.key)
      .toList();

  /// Returns all entity types that support offline reads (view from cache).
  static List<String> get offlineReadableEntities => _policies.entries
      .where((e) => e.value.supportsOfflineRead)
      .map((e) => e.key)
      .toList();

  /// Returns all entity types that are online-only.
  static List<String> get onlineOnlyEntities => _policies.entries
      .where((e) => e.value.isOnlineOnly)
      .map((e) => e.key)
      .toList();

  /// Returns all entity types where unresolvable conflicts are surfaced
  /// to the user via the conflict resolution dialog.
  static List<String> get entitiesWithUserSurfacedConflicts => _policies.entries
      .where((e) => e.value.surfaceUnresolvable)
      .map((e) => e.key)
      .toList();

  /// Check whether a specific operation is allowed offline for an entity.
  static bool isOfflineCapable(
    String entityType,
    OfflineCapability capability,
  ) {
    final policy = _policies[entityType];
    if (policy == null) return false;
    return policy.offlineCapabilities.contains(capability);
  }
}
