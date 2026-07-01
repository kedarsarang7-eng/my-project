/// Traceability matrix linking requirements to test cases, results, defects,
/// and resolutions for the Certification_System.
///
/// Maintains exactly one [TraceEntry] per requirement. Each entry links test
/// cases → latest results → defects → resolutions and flags [isCoverageGap]
/// when its test case list is empty. Changes are applied via [TraceChange]
/// subtypes and persisted atomically through [ArtifactStore].
///
/// Requirements: 13.1, 13.2, 13.3, 13.4, 13.5
library;

import 'dart:convert';

import '../io/artifact_store.dart';

/// A single test execution result.
class TestResult {
  /// The test case that produced this result.
  final String testCaseId;

  /// Whether the test passed.
  final bool passed;

  /// When this result was recorded.
  final DateTime runAt;

  const TestResult({
    required this.testCaseId,
    required this.passed,
    required this.runAt,
  });

  Map<String, dynamic> toJson() => {
    'testCaseId': testCaseId,
    'passed': passed,
    'runAt': runAt.toIso8601String(),
  };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
    testCaseId: json['testCaseId'] as String,
    passed: json['passed'] as bool,
    runAt: DateTime.parse(json['runAt'] as String),
  );
}

/// A traceability entry linking a single requirement to its associated
/// test cases, latest results, defects, and resolutions (Req 13.1).
///
/// [isCoverageGap] is true when [testCaseIds] is empty (Req 13.3).
class TraceEntry {
  /// The requirement this entry tracks — exactly one per requirement.
  final String requirementId;

  /// Test cases linked to this requirement.
  final List<String> testCaseIds;

  /// Latest test results for the linked test cases.
  final List<TestResult> latestResults;

  /// Defect IDs associated with this requirement.
  final List<String> defectIds;

  /// Links to defect resolutions.
  final List<String> resolutionLinks;

  /// True when [testCaseIds] is empty — signals a coverage gap (Req 13.3).
  final bool isCoverageGap;

  TraceEntry({
    required this.requirementId,
    List<String>? testCaseIds,
    List<TestResult>? latestResults,
    List<String>? defectIds,
    List<String>? resolutionLinks,
    bool? isCoverageGap,
  }) : testCaseIds = testCaseIds ?? [],
       latestResults = latestResults ?? [],
       defectIds = defectIds ?? [],
       resolutionLinks = resolutionLinks ?? [],
       isCoverageGap = isCoverageGap ?? (testCaseIds ?? []).isEmpty;

  /// Creates a copy with updated fields, recalculating [isCoverageGap].
  TraceEntry copyWith({
    String? requirementId,
    List<String>? testCaseIds,
    List<TestResult>? latestResults,
    List<String>? defectIds,
    List<String>? resolutionLinks,
  }) {
    final newTestCaseIds = testCaseIds ?? this.testCaseIds;
    return TraceEntry(
      requirementId: requirementId ?? this.requirementId,
      testCaseIds: newTestCaseIds,
      latestResults: latestResults ?? this.latestResults,
      defectIds: defectIds ?? this.defectIds,
      resolutionLinks: resolutionLinks ?? this.resolutionLinks,
      isCoverageGap: newTestCaseIds.isEmpty,
    );
  }

  Map<String, dynamic> toJson() => {
    'requirementId': requirementId,
    'testCaseIds': testCaseIds,
    'latestResults': latestResults.map((r) => r.toJson()).toList(),
    'defectIds': defectIds,
    'resolutionLinks': resolutionLinks,
    'isCoverageGap': isCoverageGap,
  };

  factory TraceEntry.fromJson(Map<String, dynamic> json) => TraceEntry(
    requirementId: json['requirementId'] as String,
    testCaseIds: (json['testCaseIds'] as List).cast<String>(),
    latestResults: (json['latestResults'] as List)
        .map((e) => TestResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    defectIds: (json['defectIds'] as List).cast<String>(),
    resolutionLinks: (json['resolutionLinks'] as List).cast<String>(),
    isCoverageGap: json['isCoverageGap'] as bool,
  );
}

// ---------------------------------------------------------------------------
// Trace changes — sealed hierarchy for type-safe mutation (Req 13.2).
// ---------------------------------------------------------------------------

/// A change to be applied to the traceability matrix.
/// Changes must be applied within 5s of being committed (Req 13.2).
sealed class TraceChange {
  /// The requirement this change targets.
  String get requirementId;
}

/// Add a test case to a requirement's entry.
class AddTestCase extends TraceChange {
  @override
  final String requirementId;

  /// The test case ID to add.
  final String testCaseId;

  AddTestCase({required this.requirementId, required this.testCaseId});
}

/// Remove a test case from a requirement's entry.
class RemoveTestCase extends TraceChange {
  @override
  final String requirementId;

  /// The test case ID to remove.
  final String testCaseId;

  RemoveTestCase({required this.requirementId, required this.testCaseId});
}

/// Update the latest test result for a requirement's entry.
class UpdateTestResult extends TraceChange {
  @override
  final String requirementId;

  /// The new test result to record.
  final TestResult result;

  UpdateTestResult({required this.requirementId, required this.result});
}

/// Link a defect to a requirement's entry.
class LinkDefect extends TraceChange {
  @override
  final String requirementId;

  /// The defect ID to link.
  final String defectId;

  LinkDefect({required this.requirementId, required this.defectId});
}

/// Link a resolution to a requirement's entry.
class LinkResolution extends TraceChange {
  @override
  final String requirementId;

  /// The resolution link to add.
  final String resolutionLink;

  LinkResolution({required this.requirementId, required this.resolutionLink});
}

// ---------------------------------------------------------------------------
// TraceabilityMatrix — the in-memory matrix with change application and
// persistence via ArtifactStore (Req 13.1–13.6).
// ---------------------------------------------------------------------------

/// Maintains the traceability matrix linking requirements → test cases →
/// results → defects → resolutions.
///
/// - Exactly one entry per requirement (Req 13.1).
/// - Changes applied within 5s of commit (Req 13.2) — caller responsibility
///   to invoke [applyChange] promptly.
/// - [isCoverageGap] flag set when testCaseIds is empty (Req 13.3), cleared
///   when a test case is added (Req 13.4).
/// - Entries preserved across cycles until explicitly updated (Req 13.5).
/// - Failed write retains last good matrix via [ArtifactStore] (Req 13.6).
class TraceabilityMatrix {
  /// The artifact store used for atomic persistence.
  final ArtifactStore _store;

  /// Internal map of requirement ID → entry. Preserves entries across cycles.
  final Map<String, TraceEntry> _entries;

  /// Creates a new empty matrix backed by the given [ArtifactStore].
  TraceabilityMatrix({ArtifactStore? store})
    : _store = store ?? const ArtifactStore(),
      _entries = {};

  /// Creates a matrix pre-loaded with existing entries (e.g., from disk).
  TraceabilityMatrix.fromEntries(
    List<TraceEntry> entries, {
    ArtifactStore? store,
  }) : _store = store ?? const ArtifactStore(),
       _entries = {for (final e in entries) e.requirementId: e};

  /// Apply a [TraceChange] and update the [isCoverageGap] flag accordingly.
  ///
  /// If the target requirement has no entry yet, one is created automatically.
  /// Changes must be applied within 5s of being committed (Req 13.2) — the
  /// caller is responsible for timing; this method executes synchronously.
  void applyChange(TraceChange change) {
    final entry =
        _entries[change.requirementId] ??
        TraceEntry(requirementId: change.requirementId);

    final updated = switch (change) {
      AddTestCase(:final testCaseId) => _addTestCase(entry, testCaseId),
      RemoveTestCase(:final testCaseId) => _removeTestCase(entry, testCaseId),
      UpdateTestResult(:final result) => _updateTestResult(entry, result),
      LinkDefect(:final defectId) => _linkDefect(entry, defectId),
      LinkResolution(:final resolutionLink) => _linkResolution(
        entry,
        resolutionLink,
      ),
    };

    _entries[change.requirementId] = updated;
  }

  /// Persist the matrix to [path] via [ArtifactStore] (atomic temp-write + rename).
  ///
  /// Uses replace mode (not append) since the matrix is serialized as a whole.
  /// Failed write retains last good matrix (Req 13.6).
  /// Entries are preserved across cycles (Req 13.5).
  Future<ArtifactWriteResult> persist(String path) {
    final content = serialize();
    return _store.write(path, content, append: false);
  }

  /// Get the current entries as an unmodifiable list.
  List<TraceEntry> get entries => List.unmodifiable(_entries.values.toList());

  /// Look up a single entry by requirement ID.
  TraceEntry? getEntry(String requirementId) => _entries[requirementId];

  /// The number of tracked requirements.
  int get length => _entries.length;

  /// Whether any entry is flagged as a coverage gap.
  bool get hasCoverageGaps => _entries.values.any((e) => e.isCoverageGap);

  /// All entries currently flagged as coverage gaps.
  List<TraceEntry> get coverageGaps =>
      _entries.values.where((e) => e.isCoverageGap).toList();

  /// Serialize the matrix to a JSON string for persistence.
  String serialize() {
    final list = _entries.values.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Deserialize a matrix from a JSON string.
  /// Returns a new [TraceabilityMatrix] with the loaded entries.
  static TraceabilityMatrix deserialize(String json, {ArtifactStore? store}) {
    final list = jsonDecode(json) as List;
    final entries = list
        .map((e) => TraceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return TraceabilityMatrix.fromEntries(entries, store: store);
  }

  // -------------------------------------------------------------------------
  // Private change application methods
  // -------------------------------------------------------------------------

  /// Add a test case; clears isCoverageGap if was previously empty (Req 13.4).
  TraceEntry _addTestCase(TraceEntry entry, String testCaseId) {
    if (entry.testCaseIds.contains(testCaseId)) return entry;
    final updatedTestCases = [...entry.testCaseIds, testCaseId];
    return entry.copyWith(testCaseIds: updatedTestCases);
  }

  /// Remove a test case; sets isCoverageGap if list becomes empty (Req 13.3).
  TraceEntry _removeTestCase(TraceEntry entry, String testCaseId) {
    final updatedTestCases = entry.testCaseIds
        .where((id) => id != testCaseId)
        .toList();
    return entry.copyWith(testCaseIds: updatedTestCases);
  }

  /// Update or add a test result for the given test case.
  TraceEntry _updateTestResult(TraceEntry entry, TestResult result) {
    // Replace existing result for the same testCaseId, or add new.
    final updatedResults = [
      ...entry.latestResults.where((r) => r.testCaseId != result.testCaseId),
      result,
    ];
    return entry.copyWith(latestResults: updatedResults);
  }

  /// Link a defect to the entry (idempotent — no duplicates).
  TraceEntry _linkDefect(TraceEntry entry, String defectId) {
    if (entry.defectIds.contains(defectId)) return entry;
    return entry.copyWith(defectIds: [...entry.defectIds, defectId]);
  }

  /// Link a resolution to the entry (idempotent — no duplicates).
  TraceEntry _linkResolution(TraceEntry entry, String resolutionLink) {
    if (entry.resolutionLinks.contains(resolutionLink)) return entry;
    return entry.copyWith(
      resolutionLinks: [...entry.resolutionLinks, resolutionLink],
    );
  }
}
