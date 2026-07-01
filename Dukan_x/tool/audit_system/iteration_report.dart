// AUDIT_SYSTEM — ITERATION REPORT MODEL + JSON (DE)SERIALIZATION (Task 10.1)
//
// An Iteration_Report is the read-only record persisted when a Screen is
// classified `done` and the Iteration advances. It captures everything a
// reviewer needs to audit the iteration after the fact (Req 2.6):
//   * the (Business_Type, Screen) that was remediated,
//   * the per-category audit results,
//   * the Gaps found (with their final lifecycle status),
//   * the per-item Definition_Of_Done results, each with an ISO-8601 timestamp
//     (Req 14.3),
//   * the fixes applied with their verification pass/fail outcome (Req 15.1),
//   * the advance decision (next target | none).
//
// The report is a plain, serializable value: `toJson()` produces the exact JSON
// shape documented in design.md ("Iteration_Report (persisted JSON, read-only)")
// and `fromJson(Map)` reconstructs an equivalent report — a clean round-trip
// that the store (Task 10.2) and Property 43 rely on (Req 15.2).
//
// This file is PURE, dependency-light Dart (only `dart:core` + the Audit_System
// core models), so it imports cleanly into `flutter_test` + `dartproptest` VM
// suites, mirroring the rest of the governance core.
//
// Part of: per-screen-business-type-audit-remediation (Task 10.1)
// _Requirements: 2.6, 14.3, 15.1, 15.2_

import 'audit_categories.dart'
    show AuditCategory, CategoryResult, CategoryOutcome;
import 'definition_of_done.dart' show DodItem, DodResult;
import 'gap_registry.dart' show Gap, GapStatus;
import 'target_selector.dart' show AdvanceDecision;

/// The recorded result for a single Definition_Of_Done item, paired with the
/// ISO-8601 timestamp at which the result was recorded (Req 14.3).
///
/// The timestamp is stored as the raw ISO-8601 string exactly as produced by
/// `DateTime.toIso8601String()` so the round-trip is lossless and diff-friendly.
class DodResultRecord {
  DodResultRecord({required this.result, required this.timestamp});

  /// The recorded Definition_Of_Done result for the item.
  final DodResult result;

  /// ISO-8601 timestamp string for when the result was recorded (Req 14.3).
  final String timestamp;

  @override
  bool operator ==(Object other) =>
      other is DodResultRecord &&
      other.result == result &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(result, timestamp);

  @override
  String toString() => 'DodResultRecord(${result.name}, $timestamp)';

  Map<String, Object?> toJson() => <String, Object?>{
    'result': result.name,
    'timestamp': timestamp,
  };

  static DodResultRecord fromJson(Map<String, Object?> json) => DodResultRecord(
    result: _dodResultByName(json['result'] as String),
    timestamp: json['timestamp'] as String,
  );
}

/// A fix applied against a Gap during the Fix phase, paired with the
/// verification outcome (pass/fail) recorded for it (Req 15.1).
class AppliedFix {
  AppliedFix({required this.gapId, required this.verification});

  /// The [Gap.id] this fix was applied to.
  final String gapId;

  /// The verification outcome for the fix, e.g. `pass` / `fail` (Req 15.1).
  final String verification;

  @override
  bool operator ==(Object other) =>
      other is AppliedFix &&
      other.gapId == gapId &&
      other.verification == verification;

  @override
  int get hashCode => Object.hash(gapId, verification);

  @override
  String toString() => 'AppliedFix($gapId, $verification)';

  Map<String, Object?> toJson() => <String, Object?>{
    'gapId': gapId,
    'verification': verification,
  };

  static AppliedFix fromJson(Map<String, Object?> json) => AppliedFix(
    gapId: json['gapId'] as String,
    verification: json['verification'] as String,
  );
}

/// The full, persisted Iteration_Report (Req 2.6).
///
/// `toJson()` emits the exact shape documented in design.md and `fromJson(Map)`
/// reconstructs an equivalent report. Together they guarantee a clean round-trip
/// (Req 15.2, Property 43): the Business_Type, Screen, per-category results,
/// Gaps (with descriptions and final status), Definition_Of_Done results with
/// their timestamps (Req 14.3), applied fixes with verification outcome
/// (Req 15.1), and the advance decision are all preserved.
class IterationReport {
  IterationReport({
    required this.iterationId,
    required this.businessType,
    required this.screenPath,
    required this.categoryResults,
    required this.gaps,
    required this.dodResults,
    required this.fixes,
    required this.advanceDecision,
  });

  /// Stable identifier for this iteration, e.g. `iter-0001`.
  final String iterationId;

  /// Module folder under `lib/modules/`, never `_template`.
  final String businessType;

  /// Forward-slash, package-relative `.dart` path of the remediated Screen.
  final String screenPath;

  /// Per-category audit results for the Screen.
  final List<CategoryResult> categoryResults;

  /// Gaps found for the Screen, with their final lifecycle status.
  final List<Gap> gaps;

  /// Per-item Definition_Of_Done results, each with an ISO-8601 timestamp
  /// (Req 14.3).
  final Map<DodItem, DodResultRecord> dodResults;

  /// Fixes applied during the Fix phase, with verification outcome (Req 15.1).
  final List<AppliedFix> fixes;

  /// The advance decision recorded for this iteration (next target | none).
  final AdvanceDecision advanceDecision;

  Map<String, Object?> toJson() => <String, Object?>{
    'iterationId': iterationId,
    'businessType': businessType,
    'screenPath': screenPath,
    'categoryResults': categoryResults
        .map((c) => c.toJson())
        .toList(growable: false),
    'gaps': gaps.map(_gapToJson).toList(growable: false),
    'dodResults': <String, Object?>{
      for (final entry in dodResults.entries)
        entry.key.name: entry.value.toJson(),
    },
    'fixes': fixes.map((f) => f.toJson()).toList(growable: false),
    'advanceDecision': advanceDecision.toJson(),
  };

  static IterationReport fromJson(Map<String, Object?> json) {
    final rawCategories = (json['categoryResults'] as List?) ?? const [];
    final rawGaps = (json['gaps'] as List?) ?? const [];
    final rawDod =
        (json['dodResults'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final rawFixes = (json['fixes'] as List?) ?? const [];

    return IterationReport(
      iterationId: json['iterationId'] as String,
      businessType: json['businessType'] as String,
      screenPath: json['screenPath'] as String,
      categoryResults: rawCategories
          .map(
            (c) => _categoryResultFromJson((c as Map).cast<String, Object?>()),
          )
          .toList(),
      gaps: rawGaps
          .map((g) => _gapFromJson((g as Map).cast<String, Object?>()))
          .toList(),
      dodResults: <DodItem, DodResultRecord>{
        for (final entry in rawDod.entries)
          _dodItemByName(entry.key): DodResultRecord.fromJson(
            (entry.value as Map).cast<String, Object?>(),
          ),
      },
      fixes: rawFixes
          .map((f) => AppliedFix.fromJson((f as Map).cast<String, Object?>()))
          .toList(),
      advanceDecision: AdvanceDecision.fromJson(
        (json['advanceDecision'] as Map).cast<String, Object?>(),
      ),
    );
  }

  // --- CategoryResult (de)serialization -------------------------------------
  //
  // `CategoryResult.toJson()` already exists in audit_categories.dart, so we
  // reuse it on the way out and reconstruct inline on the way in (the model has
  // no `fromJson` of its own).

  static CategoryResult _categoryResultFromJson(Map<String, Object?> json) {
    return CategoryResult(
      category: _auditCategoryByName(json['category'] as String),
      outcome: _categoryOutcomeByName(json['outcome'] as String),
      naReason: json['naReason'] as String?,
    );
  }

  // --- Gap (de)serialization ------------------------------------------------
  //
  // gap_registry.dart's `Gap` has NO toJson/fromJson, and per Task 10.1 we must
  // NOT modify it. So Gap JSON is handled inline here: id, screenPath,
  // businessType, categories (as enum name strings), status (name), description,
  // and optional fileLocation.

  static Map<String, Object?> _gapToJson(Gap gap) => <String, Object?>{
    'id': gap.id,
    'screenPath': gap.screenPath,
    'businessType': gap.businessType,
    'categories': gap.categories.map((c) => c.name).toList(growable: false),
    'status': gap.status.name,
    'description': gap.description,
    if (gap.fileLocation != null) 'fileLocation': gap.fileLocation,
  };

  static Gap _gapFromJson(Map<String, Object?> json) {
    final rawCats = (json['categories'] as List?) ?? const [];
    return Gap(
      id: json['id'] as String,
      screenPath: json['screenPath'] as String,
      businessType: json['businessType'] as String,
      categories: rawCats
          .map((c) => _auditCategoryByName(c as String))
          .toList(),
      status: _gapStatusByName(json['status'] as String),
      description: json['description'] as String,
      fileLocation: json['fileLocation'] as String?,
    );
  }
}

// --- Enum-by-name lookups -----------------------------------------------------
//
// Pure helpers that map a serialized enum `name` back to its value. They throw
// an ArgumentError on an unknown name so malformed JSON fails loudly rather than
// silently producing a wrong record.

AuditCategory _auditCategoryByName(String name) =>
    AuditCategory.values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw ArgumentError('Unknown AuditCategory: $name'),
    );

CategoryOutcome _categoryOutcomeByName(String name) =>
    CategoryOutcome.values.firstWhere(
      (v) => v.name == name,
      orElse: () => throw ArgumentError('Unknown CategoryOutcome: $name'),
    );

GapStatus _gapStatusByName(String name) => GapStatus.values.firstWhere(
  (v) => v.name == name,
  orElse: () => throw ArgumentError('Unknown GapStatus: $name'),
);

DodItem _dodItemByName(String name) => DodItem.values.firstWhere(
  (v) => v.name == name,
  orElse: () => throw ArgumentError('Unknown DodItem: $name'),
);

DodResult _dodResultByName(String name) => DodResult.values.firstWhere(
  (v) => v.name == name,
  orElse: () => throw ArgumentError('Unknown DodResult: $name'),
);
