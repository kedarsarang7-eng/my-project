/// Benchmark validation for the Certification_System.
///
/// Defines the six required practice categories, concrete actions mapped to
/// them, the BenchmarkDocument container, and the pure BenchmarkValidator that
/// ensures every category has at least one mapped action.
///
/// Requirements: 12.2, 12.3
library;

/// The six required practice categories that must each map to at least one
/// concrete named action (Req 12.2).
enum PracticeCategory {
  /// Layered test pyramid with automated coverage ≥70% at unit layer.
  layeredTestPyramid,

  /// Nightly regression execution scheduled once per 24-hour period.
  nightlyRegression,

  /// Per-release real-world scenario suites.
  perReleaseScenarios,

  /// Staged rollout (internal → beta → phased production) with
  /// telemetry-driven rollback.
  stagedRollout,

  /// Dedicated correctness suites for tax and accounting calculations.
  taxAccountingCorrectness,

  /// Mandatory pre-release performance and security gates.
  preReleaseGates,
}

/// A concrete, named action mapped to a practice category.
///
/// Each action has an [actionName] identifying it and a [description] explaining
/// what it entails.
class ConcreteAction {
  /// The practice category this action belongs to.
  final PracticeCategory category;

  /// A short, unique name identifying this action.
  final String actionName;

  /// A description of what this action entails.
  final String description;

  const ConcreteAction({
    required this.category,
    required this.actionName,
    required this.description,
  });
}

/// A benchmark document mapping practice categories to concrete actions.
///
/// Represents the content of `benchmark/industry-standards.md` which maps QA
/// practices adapted from reference products (Vyapar, myBillBook, Zoho, Tally
/// Solutions) to concrete named actions (Req 12.1, 12.2).
class BenchmarkDocument {
  /// Mapping from each practice category to its list of concrete actions.
  /// A category absent from the map or mapped to an empty list is considered
  /// unmapped.
  final Map<PracticeCategory, List<ConcreteAction>> mappings;

  const BenchmarkDocument({required this.mappings});
}

/// Result of validating a [BenchmarkDocument].
///
/// When [accepted] is true, every practice category has at least one mapped
/// concrete action. When [accepted] is false, [unmappedCategories] lists each
/// category that has no mapped action.
class BenchmarkValidation {
  /// Whether the benchmark document passed validation.
  final bool accepted;

  /// The practice categories that have no mapped concrete action.
  /// Empty when [accepted] is true.
  final List<PracticeCategory> unmappedCategories;

  const BenchmarkValidation({
    required this.accepted,
    required this.unmappedCategories,
  });

  /// Convenience constructor for an accepted result.
  const BenchmarkValidation.accepted()
    : accepted = true,
      unmappedCategories = const [];

  /// Convenience constructor for a rejected result naming unmapped categories.
  const BenchmarkValidation.rejected(this.unmappedCategories)
    : accepted = false;
}

/// Pure validator for [BenchmarkDocument] instances.
///
/// Succeeds if and only if each of the six [PracticeCategory] values maps to
/// at least one concrete, named action. Otherwise rejects the document and
/// names each unmapped category. Retains any previously generated valid content
/// (the caller is responsible for not overwriting prior valid content on
/// rejection) (Req 12.2, 12.3).
class BenchmarkValidator {
  const BenchmarkValidator();

  /// Validates that [doc] maps every practice category to ≥1 concrete action.
  ///
  /// Returns [BenchmarkValidation.accepted] when all six categories are mapped.
  /// Returns [BenchmarkValidation.rejected] listing each unmapped category when
  /// one or more categories have no mapped action.
  BenchmarkValidation validate(BenchmarkDocument doc) {
    final unmapped = <PracticeCategory>[];

    for (final category in PracticeCategory.values) {
      final actions = doc.mappings[category];
      if (actions == null || actions.isEmpty) {
        unmapped.add(category);
      }
    }

    if (unmapped.isEmpty) {
      return const BenchmarkValidation.accepted();
    }

    return BenchmarkValidation.rejected(unmapped);
  }
}
