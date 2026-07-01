// AUDIT_SYSTEM — AUDIT-CATEGORY EVALUATOR
//
// Pure, dependency-free governance logic for the Audit phase's category
// coverage. Every Screen is audited across all 13 Audit_Categories exactly
// once (Req 3.1); each category records an outcome of evaluated or
// not-applicable (Req 3.2); a not-applicable outcome must carry a substantive
// reason (Req 3.5); and the Audit phase is complete only when all 13 categories
// have a recorded outcome (Req 3.6).
//
// Keep this file pure: depends on NOTHING but `dart:core`, so it imports
// cleanly into `flutter_test` + `dartproptest` suites, exactly like
// `types.dart` and `tool/responsive_audit.dart`.
//
// Part of: per-screen-business-type-audit-remediation (Task 4.1)
// _Requirements: 3.1, 3.2, 3.5, 3.6_

/// The 13 Audit_Categories, evaluated exactly once per Screen (Req 3.1).
///
/// The order and membership of this enum is the single source of truth for the
/// full-coverage check in [AuditCategoryEvaluator.phaseStatus].
enum AuditCategory {
  feature,
  uiUx,
  widgets,
  routingNavigation,
  workflow,
  dataFlow,
  backendIntegration,
  offline,
  performance,
  security,
  validation,
  responsiveDesign,
  accessibility,
}

/// The evaluation outcome recorded for an Audit_Category on a Screen (Req 3.2).
enum CategoryOutcome { evaluated, notApplicable }

/// Whether the Audit phase has a recorded outcome for all 13 categories.
enum AuditPhaseStatus { incomplete, complete }

/// The minimum length of a not-applicable reason (Req 3.5).
const int kMinNaReasonLength = 10;

/// A single category's evaluation result for a Screen.
///
/// When [outcome] is [CategoryOutcome.notApplicable], [naReason] must be a
/// non-empty reason of at least [kMinNaReasonLength] characters explaining why
/// the category does not apply to the Screen (Req 3.5).
class CategoryResult {
  CategoryResult({
    required this.category,
    required this.outcome,
    this.naReason,
  });

  /// One of the 13 Audit_Categories.
  final AuditCategory category;

  /// Either evaluated or not-applicable (Req 3.2).
  final CategoryOutcome outcome;

  /// Required, length >= [kMinNaReasonLength], when [outcome] is
  /// [CategoryOutcome.notApplicable] (Req 3.5). Null/ignored otherwise.
  final String? naReason;

  @override
  bool operator ==(Object other) =>
      other is CategoryResult &&
      other.category == category &&
      other.outcome == outcome &&
      other.naReason == naReason;

  @override
  int get hashCode => Object.hash(category, outcome, naReason);

  @override
  String toString() =>
      'CategoryResult(${category.name}, ${outcome.name}'
      '${naReason == null ? '' : ', $naReason'})';

  Map<String, Object?> toJson() => <String, Object?>{
    'category': category.name,
    'outcome': outcome.name,
    if (naReason != null) 'naReason': naReason,
  };
}

/// Evaluates audit-category coverage and not-applicable reason validity for a
/// Screen. All methods are pure and static so they import cleanly into tests.
class AuditCategoryEvaluator {
  const AuditCategoryEvaluator._();

  /// The Audit phase status for a Screen.
  ///
  /// Returns [AuditPhaseStatus.complete] **iff** every one of the 13
  /// Audit_Categories has at least one recorded result whose outcome is
  /// evaluated or not-applicable; otherwise [AuditPhaseStatus.incomplete]
  /// (Req 3.6). Because [CategoryOutcome] has only those two values, presence of
  /// a result for a category is sufficient — but we still ignore any
  /// not-applicable result whose reason is invalid, since an invalid
  /// not-applicable record is not a valid recorded outcome (Req 3.5).
  static AuditPhaseStatus phaseStatus(List<CategoryResult> results) {
    final covered = <AuditCategory>{};
    for (final r in results) {
      if (r.outcome == CategoryOutcome.notApplicable && !naReasonValid(r)) {
        // An invalid not-applicable record does not count as a recorded outcome.
        continue;
      }
      covered.add(r.category);
    }
    final allCovered = AuditCategory.values.every(covered.contains);
    return allCovered ? AuditPhaseStatus.complete : AuditPhaseStatus.incomplete;
  }

  /// True iff a not-applicable result carries a non-empty reason of at least
  /// [kMinNaReasonLength] characters (Req 3.5).
  ///
  /// Results whose outcome is [CategoryOutcome.evaluated] are trivially valid
  /// since they require no reason.
  static bool naReasonValid(CategoryResult r) {
    if (r.outcome != CategoryOutcome.notApplicable) return true;
    final reason = r.naReason;
    return reason != null && reason.length >= kMinNaReasonLength;
  }
}
