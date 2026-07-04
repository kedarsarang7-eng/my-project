/// Shared Dart models for the Flutter UI audit-and-remediation process engine.
///
/// Contains: enums (ChecklistCategory, ScreenState, CategoryStatus, Severity,
/// FindingState, FileScope) and immutable data classes (ScreenRef, UnresolvedEntry,
/// ScreenInventory, CategoryResult, ScreenAnalysis, Finding, BlockedItem,
/// DeferredItem, FixLogEntry, SharedImpactNote, TestResult, MatrixCell, MatrixRow,
/// SignOff, CycleState).
///
/// Referenced by: engine components (ScreenInventoryBuilder, EditScopeGuard,
/// ChecklistEvaluator, FindingRecorder, Prioritizer, PlatformMatrixBuilder,
/// SignOffEvaluator, FixApplier, TestCoordinator, ReportBuilder, CycleOrchestrator).
///
/// Requirements: 3.8, 6.3, 7.5
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// The five analysis checklist categories evaluated per screen per state.
enum ChecklistCategory {
  layoutAndOverflow,
  hardcodedValues,
  responsivenessAndPlatformCoverage,
  uiUxCorrectness,
  performance,
}

/// The four widget states each screen is evaluated across.
enum ScreenState { empty, loading, error, populated }

/// Result status for a single category check.
enum CategoryStatus { pass, fail, na }

/// Severity level for a Finding (exactly one per Finding, Req 7.5).
/// Maps to existing audit_rules.json: P0→critical, P1→high, P2→medium, P3→low.
enum Severity { critical, high, medium, low }

/// Lifecycle state of a Finding.
enum FindingState { open, resolved, blocked, deferred }

/// File-ownership classification for the Edit-Scope Guard.
enum FileScope { activeVertical, sharedCore, otherVerticalExclusive }

/// Business types matching `lib/models/business_type.dart` values.
/// Defined locally so the audit engine scripts can run standalone.
enum BusinessType {
  grocery,
  pharmacy,
  restaurant,
  clothing,
  electronics,
  mobileShop,
  computerShop,
  hardware,
  service,
  wholesale,
  petrolPump,
  vegetablesBroker,
  clinic,
  bookStore,
  jewellery,
  autoParts,
  decorationCatering,
  schoolErp,
  other;

  /// Human-readable display name (mirrors app's displayName getter).
  String get displayName => switch (this) {
    BusinessType.grocery => 'Grocery',
    BusinessType.pharmacy => 'Pharmacy',
    BusinessType.restaurant => 'Restaurant',
    BusinessType.clothing => 'Clothing',
    BusinessType.electronics => 'Electronics',
    BusinessType.mobileShop => 'Mobile Shop',
    BusinessType.computerShop => 'Computer Shop',
    BusinessType.hardware => 'Hardware',
    BusinessType.service => 'Service',
    BusinessType.wholesale => 'Wholesale',
    BusinessType.petrolPump => 'Petrol Pump',
    BusinessType.vegetablesBroker => 'Vegetables Broker',
    BusinessType.clinic => 'Clinic',
    BusinessType.bookStore => 'Book Store',
    BusinessType.jewellery => 'Jewellery',
    BusinessType.autoParts => 'Auto Parts',
    BusinessType.decorationCatering => 'Decoration & Catering',
    BusinessType.schoolErp => 'School ERP',
    BusinessType.other => 'Other',
  };
}

/// Target platforms for the Platform Verification Matrix.
enum TargetPlatform {
  windowsDesktop,
  linuxDesktop,
  androidPhoneSmall,
  androidPhoneMedium,
  androidPhoneLarge,
  androidTabletPortrait,
  androidTabletLandscape,
  iphone,
  ipadPortrait,
  ipadLandscape,
  ipadSplitView;

  /// Human-readable label for report output.
  String get label => switch (this) {
    TargetPlatform.windowsDesktop => 'Windows Desktop',
    TargetPlatform.linuxDesktop => 'Linux Desktop',
    TargetPlatform.androidPhoneSmall => 'Android Phone (Small)',
    TargetPlatform.androidPhoneMedium => 'Android Phone (Medium)',
    TargetPlatform.androidPhoneLarge => 'Android Phone (Large)',
    TargetPlatform.androidTabletPortrait => 'Android Tablet (Portrait)',
    TargetPlatform.androidTabletLandscape => 'Android Tablet (Landscape)',
    TargetPlatform.iphone => 'iPhone',
    TargetPlatform.ipadPortrait => 'iPad (Portrait)',
    TargetPlatform.ipadLandscape => 'iPad (Landscape)',
    TargetPlatform.ipadSplitView => 'iPad (Split View)',
  };
}

// ---------------------------------------------------------------------------
// Data Classes
// ---------------------------------------------------------------------------

/// Normalizes a file path to its canonical form for dedup comparison.
///
/// - Converts backslashes to forward slashes.
/// - Lowercases the entire path (case-insensitive FS like Windows).
/// - Trims leading/trailing whitespace.
String canonicalFilePath(String raw) =>
    raw.trim().replaceAll(r'\', '/').toLowerCase();

/// One resolved, distinct screen in a Business_Type's inventory.
///
/// Value equality is based on [filePath] after canonical normalization,
/// which serves as the dedup key (Req 2.2).
class ScreenRef {
  /// Screen/widget display name.
  final String name;

  /// Route or sidebar id this screen resolves from.
  final String route;

  /// Canonical source path (dedup key). Stored in normalized form.
  final String filePath;

  ScreenRef({required this.name, required this.route, required String filePath})
    : filePath = canonicalFilePath(filePath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenRef && filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;

  @override
  String toString() => 'ScreenRef($name, route: $route, file: $filePath)';
}

/// A sidebar entry that could not be resolved to a screen source file.
class UnresolvedEntry {
  /// SidebarMenuItem.id or label that failed resolution.
  final String entryName;

  /// Why resolution failed (Req 2.7).
  final String reason;

  const UnresolvedEntry({required this.entryName, required this.reason});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnresolvedEntry &&
          entryName == other.entryName &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(entryName, reason);

  @override
  String toString() => 'UnresolvedEntry($entryName: $reason)';
}

/// Complete inventory produced before analysis (Req 2.1).
class ScreenInventory {
  /// The active business type this inventory belongs to.
  final BusinessType businessType;

  /// Deduplicated resolved screens (Req 2.2).
  final List<ScreenRef> screens;

  /// Sidebar entries that could not be resolved — never dropped (Req 2.7).
  final List<UnresolvedEntry> unresolved;

  const ScreenInventory({
    required this.businessType,
    required this.screens,
    required this.unresolved,
  });

  @override
  String toString() =>
      'ScreenInventory(${businessType.displayName}, '
      'screens: ${screens.length}, unresolved: ${unresolved.length})';
}

/// Result of one category on one screen (across a specific Screen_State).
class CategoryResult {
  /// Which checklist category was evaluated.
  final ChecklistCategory category;

  /// Pass, fail, or not-applicable.
  final CategoryStatus status;

  /// Required when status is [CategoryStatus.na] (Req 3.7).
  final String? reason;

  const CategoryResult({
    required this.category,
    required this.status,
    this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryResult &&
          category == other.category &&
          status == other.status &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(category, status, reason);

  @override
  String toString() =>
      'CategoryResult(${category.name}: ${status.name}'
      '${reason != null ? ', reason: $reason' : ''})';
}

/// Per-screen analysis; blocked when the file cannot be read (Req 2.8).
class ScreenAnalysis {
  /// The screen that was analyzed.
  final ScreenRef screen;

  /// Whether the analysis was blocked (e.g. file unreadable).
  final bool blocked;

  /// Reason for blocking, if [blocked] is true.
  final String? blockedReason;

  /// Results per Screen_State; empty map when blocked.
  final Map<ScreenState, List<CategoryResult>> results;

  const ScreenAnalysis({
    required this.screen,
    required this.blocked,
    this.blockedReason,
    required this.results,
  });

  /// Creates a blocked analysis result.
  const ScreenAnalysis.blocked({required this.screen, required String reason})
    : blocked = true,
      blockedReason = reason,
      results = const {};

  @override
  String toString() =>
      'ScreenAnalysis(${screen.name}, '
      'blocked: $blocked${blockedReason != null ? ' ($blockedReason)' : ''})';
}

/// A recorded issue (Req 3.8).
///
/// Invariant: exactly one [severity] per Finding (Req 7.5).
/// [state] and [discoveryIndex] are mutable for lifecycle tracking.
class Finding {
  /// Unique identifier for this finding.
  final String id;

  /// The screen where the issue was found.
  final ScreenRef screen;

  /// Which checklist category this finding belongs to.
  final ChecklistCategory category;

  /// Exactly one severity level (Req 7.5).
  final Severity severity;

  /// Description of the issue.
  final String description;

  /// File:line reference to the issue location.
  final String fileLine;

  /// Lifecycle state: open → resolved | blocked | deferred.
  FindingState state;

  /// Preserves original discovery order for stable sort (Req 7.6).
  int discoveryIndex;

  Finding({
    required this.id,
    required this.screen,
    required this.category,
    required this.severity,
    required this.description,
    required this.fileLine,
    this.state = FindingState.open,
    this.discoveryIndex = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Finding && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Finding($id, ${severity.name}, ${category.name}, state: ${state.name})';
}

/// A Finding that is blocked from resolution (Req 7.1–7.3).
class BlockedItem {
  /// The blocked finding.
  final Finding finding;

  /// Why it's blocked: missing-spec | ambiguous-requirement | external-dependency.
  final String blockingReason;

  /// The specific missing or ambiguous artifact.
  final String missingArtifact;

  /// What action is needed to unblock.
  final String actionToUnblock;

  /// For cross-vertical defers (Req 1.8): the owning vertical.
  final BusinessType? targetBusinessType;

  const BlockedItem({
    required this.finding,
    required this.blockingReason,
    required this.missingArtifact,
    required this.actionToUnblock,
    this.targetBusinessType,
  });

  @override
  String toString() => 'BlockedItem(${finding.id}, reason: $blockingReason)';
}

/// A Finding that is deferred to a later cycle.
class DeferredItem {
  /// The deferred finding.
  final Finding finding;

  /// Why it was deferred.
  final String reason;

  const DeferredItem({required this.finding, required this.reason});

  @override
  String toString() => 'DeferredItem(${finding.id}, reason: $reason)';
}

/// One Fix Log entry recording what was changed and why (Req 6.4).
class FixLogEntry {
  /// The finding that was fixed.
  final Finding finding;

  /// What was changed in the source.
  final String whatChanged;

  /// Why the change was made (root-cause reasoning).
  final String whyChanged;

  /// Behavior before the fix.
  final String beforeBehavior;

  /// Behavior after the fix.
  final String afterBehavior;

  /// Call sites impacted; populated for API-breaking fixes (Req 4.7).
  final List<String> impactedCallSites;

  const FixLogEntry({
    required this.finding,
    required this.whatChanged,
    required this.whyChanged,
    required this.beforeBehavior,
    required this.afterBehavior,
    this.impactedCallSites = const [],
  });

  @override
  String toString() => 'FixLogEntry(${finding.id}: $whatChanged)';
}

/// Shared_Core_Widget impact record (Req 1.4, 1.5, 6.7).
class SharedImpactNote {
  /// Path to the shared widget that was modified.
  final String widgetPath;

  /// Pass/fail verification per other consuming Business_Type.
  final Map<BusinessType, bool> consumerVerification;

  const SharedImpactNote({
    required this.widgetPath,
    required this.consumerVerification,
  });

  @override
  String toString() =>
      'SharedImpactNote($widgetPath, consumers: ${consumerVerification.length})';
}

/// One test result (Req 5.7, 6.6).
class TestResult {
  /// Unique test identifier.
  final String testId;

  /// Whether the test passed.
  final bool passed;

  const TestResult({required this.testId, required this.passed});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestResult && testId == other.testId && passed == other.passed;

  @override
  int get hashCode => Object.hash(testId, passed);

  @override
  String toString() => 'TestResult($testId: ${passed ? 'PASS' : 'FAIL'})';
}

/// A single cell in the Platform Verification Matrix (Req 6.8).
class MatrixCell {
  /// Status of this cell: pass, fail, or na.
  final CategoryStatus status;

  /// Reason, required when status is [CategoryStatus.na].
  final String? reason;

  const MatrixCell({required this.status, this.reason});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatrixCell && status == other.status && reason == other.reason;

  @override
  int get hashCode => Object.hash(status, reason);

  @override
  String toString() =>
      'MatrixCell(${status.name}'
      '${reason != null ? ', $reason' : ''})';
}

/// One row in the Platform Verification Matrix (Req 6.8).
///
/// `resultPass` is a computed getter: true iff no cell is [CategoryStatus.fail].
class MatrixRow {
  /// The target platform for this row.
  final TargetPlatform platform;

  /// Light color mode cell.
  final MatrixCell light;

  /// Dark color mode cell.
  final MatrixCell dark;

  /// Portrait orientation cell.
  final MatrixCell portrait;

  /// Landscape orientation cell.
  final MatrixCell landscape;

  const MatrixRow({
    required this.platform,
    required this.light,
    required this.dark,
    required this.portrait,
    required this.landscape,
  });

  /// Result = Pass ⇔ no cell in the row is Fail (Property 9).
  bool get resultPass => [
    light,
    dark,
    portrait,
    landscape,
  ].every((c) => c.status != CategoryStatus.fail);

  @override
  String toString() => 'MatrixRow(${platform.label}, pass: $resultPass)';
}

/// Sign-off outcome (Req 6.9–6.11).
class SignOff {
  /// Whether sign-off is complete (all sub-conditions hold).
  final bool isComplete;

  /// Conditions preventing sign-off; empty when [isComplete] is true.
  final List<String> withholdingConditions;

  const SignOff({
    required this.isComplete,
    this.withholdingConditions = const [],
  });

  @override
  String toString() =>
      'SignOff(complete: $isComplete'
      '${withholdingConditions.isNotEmpty ? ', blockers: ${withholdingConditions.length}' : ''})';
}

/// The full state accumulated for one Cycle of a Business_Type.
class CycleState {
  /// The active business type for this cycle.
  final BusinessType businessType;

  /// Screen inventory produced before analysis.
  final ScreenInventory inventory;

  /// All findings recorded during analysis.
  final List<Finding> findings;

  /// Fix log entries for resolved findings.
  final List<FixLogEntry> fixLog;

  /// Test results from the Business_Type_Test_Suite.
  final List<TestResult> testLog;

  /// Shared/core widget impact notes.
  final List<SharedImpactNote> sharedImpact;

  /// Platform verification matrix rows.
  final List<MatrixRow> matrix;

  /// Blocked items (findings that cannot be resolved this cycle).
  final List<BlockedItem> blocked;

  /// Deferred items (findings deferred to another cycle).
  final List<DeferredItem> deferred;

  const CycleState({
    required this.businessType,
    required this.inventory,
    required this.findings,
    this.fixLog = const [],
    this.testLog = const [],
    this.sharedImpact = const [],
    this.matrix = const [],
    this.blocked = const [],
    this.deferred = const [],
  });

  @override
  String toString() =>
      'CycleState(${businessType.displayName}, '
      'findings: ${findings.length}, fixes: ${fixLog.length})';
}
