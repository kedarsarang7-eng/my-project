/// Defect model and structural validator for the Certification_System.
///
/// Defines the domain types for defect tracking (Severity, ResolutionStatus,
/// GapCategory, Defect) and the pure DefectValidator that enforces structural
/// integrity rules before a defect record can be persisted.
///
/// Requirements: 7.1, 7.2, 7.3
library;

/// Severity levels for defect records.
/// Critical and High are release-blocking.
enum Severity { critical, high, medium, low }

/// Resolution lifecycle statuses for defect records.
enum ResolutionStatus { open, inProgress, resolved, closed }

/// Gap categories — exactly one must be assigned per defect (Req 7.2).
enum GapCategory {
  feature,
  workflow,
  navigation,
  missingScreen,
  brokenRoute,
  uiInconsistency,
  incorrectCalculation,
  dataIntegrity,
  missingRequirement,
}

/// A recorded defect with a unique identifier, severity, reproduction steps,
/// resolution status, and exactly one gap category.
///
/// All fields are required and constrained by their enum types at compile time
/// except for [id] (must be non-empty) and [reproSteps] (must have ≥1 element).
class Defect {
  /// Unique identifier for this defect (required, must be non-empty).
  final String id;

  /// Severity level from the allowed set.
  final Severity severity;

  /// Ordered reproduction steps (must contain at least 1 step).
  final List<String> reproSteps;

  /// Current resolution status from the allowed set.
  final ResolutionStatus status;

  /// Exactly one gap category classifying this defect.
  final GapCategory category;

  const Defect({
    required this.id,
    required this.severity,
    required this.reproSteps,
    required this.status,
    required this.category,
  });
}

/// Result of structural validation on a [Defect] candidate.
///
/// When [accepted] is true, the defect record passed all checks.
/// When [accepted] is false, [errorField] names the first offending field.
class DefectValidation {
  /// Whether the defect record was accepted.
  final bool accepted;

  /// The name of the offending field when rejected; null when accepted.
  final String? errorField;

  const DefectValidation({required this.accepted, this.errorField});

  /// Convenience constructor for an accepted result.
  const DefectValidation.accepted() : accepted = true, errorField = null;

  /// Convenience constructor for a rejected result naming the offending field.
  const DefectValidation.rejected(String field)
    : accepted = false,
      errorField = field;
}

/// Pure structural validator for [Defect] records.
///
/// Rejects (and names the offending field) when:
/// - [Defect.id] is missing or empty
/// - [Defect.reproSteps] is empty (must have ≥1 ordered step)
///
/// Since Dart enums already constrain severity, status, and category to their
/// allowed sets at compile time, those checks pass implicitly for any non-null
/// Defect instance. The validator focuses on the runtime-checkable conditions.
///
/// No partial record is retained on rejection (Req 7.3) — the validator returns
/// a rejection result and the caller must not persist the candidate.
class DefectValidator {
  const DefectValidator();

  /// Validates the structural integrity of [candidate].
  ///
  /// Returns [DefectValidation.accepted] when all checks pass.
  /// Returns [DefectValidation.rejected] with the offending field name on failure.
  DefectValidation validate(Defect candidate) {
    // Check id is non-empty (Req 7.1 — unique identifier required)
    if (candidate.id.isEmpty) {
      return const DefectValidation.rejected('id');
    }

    // Check reproSteps has at least 1 element (Req 7.1 — at least 1 ordered step)
    if (candidate.reproSteps.isEmpty) {
      return const DefectValidation.rejected('reproSteps');
    }

    // All checks passed — severity, status, and category are guaranteed valid
    // by Dart's type system (enum constraints).
    return const DefectValidation.accepted();
  }
}
