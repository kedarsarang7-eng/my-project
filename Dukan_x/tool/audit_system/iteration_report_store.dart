// AUDIT_SYSTEM — ITERATION REPORT STORE (Task 10.2)
//
// Persists each Iteration_Report as a READ-ONLY JSON record and retrieves it
// later by Iteration identifier, Business_Type, or Screen (Req 2.6, 15.1, 15.2).
//
// Storage layout: one file per Iteration_Report, keyed by `iterationId`, under
//
//     .kiro/specs/per-screen-business-type-audit-remediation/reports/
//
// Each record is written once and then marked read-only on disk so a persisted
// Iteration_Report is retained, unchanged, for the full duration of the
// initiative (Req 15.2).
//
// Failure handling (Req 2.9, 15.5): persistence NEVER throws an uncaught error.
// If writing the record fails for any reason, `persist` returns a FAILURE
// [PersistResult] carrying the error. This lets the caller retain the current
// Iteration_Target as active, leave the completed-Screens record unchanged,
// surface the error, and NOT advance to the next Iteration.
//
// This file uses only `dart:io` + `dart:convert` (mirroring the rest of the
// Audit_System governance core) plus the pure `IterationReport` model.
//
// Part of: per-screen-business-type-audit-remediation (Task 10.2)
// _Requirements: 2.6, 2.9, 15.1, 15.2, 15.5_

import 'dart:convert';
import 'dart:io';

import 'iteration_report.dart' show IterationReport;

/// The outcome of attempting to persist an [IterationReport].
///
/// Persistence is fallible (a full disk, a permission error, ...), so rather
/// than throwing, [IterationReportStore.persist] always returns a result. On
/// failure ([succeeded] == false) the caller MUST keep the current
/// Iteration_Target active, leave the completed-Screens record unchanged,
/// surface [error], and NOT advance (Req 2.9, 15.5).
class PersistResult {
  PersistResult._({
    required this.succeeded,
    required this.iterationId,
    this.path,
    this.error,
  });

  /// A successful persist: the record was written to [path] and marked
  /// read-only.
  factory PersistResult.success({
    required String iterationId,
    required String path,
  }) => PersistResult._(succeeded: true, iterationId: iterationId, path: path);

  /// A failed persist: nothing durable should be assumed; [error] describes
  /// what went wrong (Req 2.9, 15.5).
  factory PersistResult.failure({
    required String iterationId,
    required String error,
  }) =>
      PersistResult._(succeeded: false, iterationId: iterationId, error: error);

  /// True iff the record was written and marked read-only successfully.
  final bool succeeded;

  /// True iff persistence failed — convenience inverse of [succeeded].
  bool get failed => !succeeded;

  /// The Iteration identifier the persist was attempted for.
  final String iterationId;

  /// Absolute path of the written record, present only when [succeeded].
  final String? path;

  /// Human-readable error describing the failure, present only when [failed].
  final String? error;

  @override
  String toString() => succeeded
      ? 'PersistResult.success($iterationId -> $path)'
      : 'PersistResult.failure($iterationId: $error)';
}

/// Persists and retrieves [IterationReport]s as read-only JSON records
/// (Req 2.6, 15.1, 15.2).
class IterationReportStore {
  /// Creates a store rooted at [reportsDir]. When omitted, the default
  /// directory is resolved relative to the workspace root:
  /// `.kiro/specs/per-screen-business-type-audit-remediation/reports/`.
  ///
  /// The directory parameter exists primarily for testability: tests can point
  /// the store at a temporary directory and assert on the written records.
  IterationReportStore({Directory? reportsDir})
    : reportsDir = reportsDir ?? _defaultReportsDir();

  /// Directory under which one JSON record per Iteration is stored.
  final Directory reportsDir;

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Persist [report] as a read-only JSON record keyed by its `iterationId`.
  ///
  /// On success the record is written to `<reportsDir>/<iterationId>.json` and
  /// marked read-only, and a success [PersistResult] is returned. On ANY
  /// failure this method does NOT throw: it returns a failure [PersistResult]
  /// carrying the error so the caller can keep the current target active and
  /// avoid advancing (Req 2.9, 15.5).
  PersistResult persist(IterationReport report) {
    final id = report.iterationId;
    try {
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final file = _fileFor(id);

      // If a read-only record already exists, clear the read-only bit so the
      // (re)write can succeed before we re-apply it.
      if (file.existsSync()) {
        _setReadOnly(file, false);
      }

      file.writeAsStringSync('${_encoder.convert(report.toJson())}\n');

      // Mark the record read-only so it is retained unchanged (Req 15.2).
      _setReadOnly(file, true);

      return PersistResult.success(iterationId: id, path: file.path);
    } catch (e) {
      // Req 2.9 / 15.5: never throw — surface the failure to the caller.
      return PersistResult.failure(iterationId: id, error: e.toString());
    }
  }

  /// Retrieve the single Iteration_Report keyed by [iterationId], or `null`
  /// when no such record exists (or it cannot be read/parsed).
  IterationReport? get(String iterationId) {
    final file = _fileFor(iterationId);
    if (!file.existsSync()) return null;
    try {
      return _readReport(file);
    } catch (_) {
      return null;
    }
  }

  /// Retrieve every persisted Iteration_Report matching the given filters.
  ///
  /// A `null` filter matches anything; when both are `null` all records are
  /// returned. Filtering by [businessType] and/or [screenPath] supports
  /// retrieval by Business_Type and Screen (Req 15.2). Results are sorted by
  /// `iterationId` for a stable, deterministic order.
  List<IterationReport> findBy({String? businessType, String? screenPath}) {
    if (!reportsDir.existsSync()) return <IterationReport>[];

    final reports = <IterationReport>[];
    for (final entity in reportsDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      IterationReport report;
      try {
        report = _readReport(entity);
      } catch (_) {
        // Skip unreadable/corrupt records rather than failing the whole query.
        continue;
      }
      if (businessType != null && report.businessType != businessType) continue;
      if (screenPath != null && report.screenPath != screenPath) continue;
      reports.add(report);
    }

    reports.sort((a, b) => a.iterationId.compareTo(b.iterationId));
    return reports;
  }

  // --- internals -------------------------------------------------------------

  File _fileFor(String iterationId) =>
      File('${reportsDir.path}/${_sanitize(iterationId)}.json');

  IterationReport _readReport(File file) {
    final decoded =
        json.decode(file.readAsStringSync()) as Map<String, Object?>;
    return IterationReport.fromJson(decoded);
  }

  /// Keep filenames filesystem-safe: an `iterationId` is normally something
  /// like `iter-0001`, but we defensively replace any path separators or other
  /// awkward characters so the key can never escape [reportsDir].
  static String _sanitize(String iterationId) =>
      iterationId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Best-effort toggle of the OS read-only attribute on [file].
  ///
  /// `dart:io` has no portable read-only API, so we shell out: `attrib` on
  /// Windows, `chmod` elsewhere. Failures here are swallowed — the record is
  /// already written; the read-only bit is a retention safeguard, not a
  /// correctness requirement, and we must not turn it into a persist failure.
  static void _setReadOnly(File file, bool readOnly) {
    try {
      if (Platform.isWindows) {
        Process.runSync('attrib', [readOnly ? '+R' : '-R', file.path]);
      } else {
        Process.runSync('chmod', [readOnly ? '0444' : '0644', file.path]);
      }
    } catch (_) {
      // Ignore: read-only marking is best-effort.
    }
  }

  /// Resolve the default reports directory relative to the workspace root.
  ///
  /// Walks up from the current directory looking for the `.kiro` spec folder
  /// (tests/CLIs run with cwd at the Flutter package root, e.g. `Dukan_x/`, so
  /// the workspace root is typically one level up). Falls back to a path
  /// relative to the current directory if the root cannot be located.
  static Directory _defaultReportsDir() {
    const rel =
        '.kiro/specs/per-screen-business-type-audit-remediation/reports';
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      if (Directory('${dir.path}/.kiro').existsSync()) {
        return Directory('${dir.path}/$rel');
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return Directory('${Directory.current.path}/$rel');
  }
}
