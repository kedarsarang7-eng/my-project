/// DefectStore — persists validated defects and manages resolution lifecycle.
///
/// Responsibilities:
/// - Persist only validated defects as JSON files under `defects/`.
/// - Expose [allClosed] to drive "not production-ready" while any defect is open.
/// - On status change to Resolved/Closed, update the defect AND link the
///   resolution into the traceability matrix in one atomic operation (Req 7.5).
///
/// Uses [ArtifactStore] for atomic file writes and [DefectValidator] for
/// structural validation before persistence.
///
/// Requirements: 7.4, 7.5
library;

import 'dart:convert';
import 'dart:io';

import '../core/defect.dart';
import 'artifact_store.dart';

/// Minimal interface for linking defect resolutions into the traceability matrix.
///
/// The full [TraceabilityMatrix] implementation (task 10.2) will implement this.
/// DefectStore depends on this abstraction to perform the matrix linkage within
/// the same operation as the status update (Req 7.5).
abstract class TraceabilityMatrixLinker {
  /// Links a defect resolution into the traceability matrix.
  ///
  /// [defectId] — the defect being resolved.
  /// [resolutionLink] — the resolution reference to link.
  ///
  /// Returns true if the linkage succeeded, false otherwise.
  Future<bool> linkResolution(String defectId, String resolutionLink);
}

/// A no-op linker for environments where the traceability matrix is not yet
/// wired. Always succeeds. Replace with the real implementation in task 10.2.
class NoOpTraceabilityMatrixLinker implements TraceabilityMatrixLinker {
  const NoOpTraceabilityMatrixLinker();

  @override
  Future<bool> linkResolution(String defectId, String resolutionLink) async {
    return true;
  }
}

/// Persists validated defects under `defects/` and manages resolution lifecycle.
///
/// Each defect is stored as `{basePath}/defects/{id}.json`. The store rejects
/// defects that fail structural validation (Req 7.3) and never writes a partial
/// record.
class DefectStore {
  /// Base directory path under which the `defects/` folder is created.
  final String basePath;

  /// Validator for structural integrity checks.
  final DefectValidator _validator;

  /// Atomic file writer.
  final ArtifactStore _artifactStore;

  /// Linker for traceability matrix updates on resolution.
  final TraceabilityMatrixLinker _matrixLinker;

  DefectStore({
    required this.basePath,
    DefectValidator? validator,
    ArtifactStore? artifactStore,
    TraceabilityMatrixLinker? matrixLinker,
  }) : _validator = validator ?? const DefectValidator(),
       _artifactStore = artifactStore ?? const ArtifactStore(),
       _matrixLinker = matrixLinker ?? const NoOpTraceabilityMatrixLinker();

  /// The directory path where defect JSON files are stored.
  String get _defectsDir => '$basePath/defects';

  /// Persists only validated defects under defects/.
  ///
  /// Returns `true` if the defect was validated and persisted successfully.
  /// Returns `false` if validation fails (no partial record is written).
  Future<bool> upsert(Defect defect) async {
    // Validate structural integrity before persisting.
    final validation = _validator.validate(defect);
    if (!validation.accepted) {
      return false;
    }

    // Serialize defect to JSON.
    final json = _defectToJson(defect);
    final filePath = '$_defectsDir/${defect.id}.json';

    // Atomic write — replaces the entire file (not append).
    final result = await _artifactStore.write(filePath, json, append: false);
    return result.success;
  }

  /// True iff every stored defect has status == Closed.
  ///
  /// Drives "not production-ready" while at least one defect is not Closed
  /// (Req 7.4).
  Future<bool> get allClosed async {
    final defects = await getAll();
    if (defects.isEmpty) {
      return true;
    }
    return defects.every((d) => d.status == ResolutionStatus.closed);
  }

  /// Retrieve all stored defects.
  Future<List<Defect>> getAll() async {
    final dir = Directory(_defectsDir);
    if (!await dir.exists()) {
      return [];
    }

    final defects = <Defect>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final defect = _defectFromJson(content);
          if (defect != null) {
            defects.add(defect);
          }
        } catch (_) {
          // Skip files that cannot be parsed — don't crash the store.
        }
      }
    }
    return defects;
  }

  /// Resolve a defect: update status to resolved/closed AND link resolution
  /// into the traceability matrix in one operation (Req 7.5).
  ///
  /// [defectId] — the unique identifier of the defect to resolve.
  /// [newStatus] — must be [ResolutionStatus.resolved] or [ResolutionStatus.closed].
  /// [resolutionLink] — the resolution reference to link into the matrix.
  ///
  /// Throws [ArgumentError] if [newStatus] is not resolved or closed.
  /// Throws [StateError] if the defect does not exist.
  Future<void> resolve(
    String defectId,
    ResolutionStatus newStatus,
    String resolutionLink,
  ) async {
    // Only resolved/closed are valid resolution statuses.
    if (newStatus != ResolutionStatus.resolved &&
        newStatus != ResolutionStatus.closed) {
      throw ArgumentError(
        'resolve() requires status resolved or closed, got: $newStatus',
      );
    }

    // Read the existing defect.
    final filePath = '$_defectsDir/$defectId.json';
    final content = await _artifactStore.read(filePath);
    if (content == null) {
      throw StateError('Defect "$defectId" not found in store.');
    }

    final existingDefect = _defectFromJson(content);
    if (existingDefect == null) {
      throw StateError('Defect "$defectId" could not be parsed.');
    }

    // Create the updated defect with the new status.
    final updatedDefect = Defect(
      id: existingDefect.id,
      severity: existingDefect.severity,
      reproSteps: existingDefect.reproSteps,
      status: newStatus,
      category: existingDefect.category,
    );

    // Perform both operations together — status update + matrix linkage.
    // This satisfies Req 7.5: "within the same operation".
    final writeResult = await _artifactStore.write(
      filePath,
      _defectToJson(updatedDefect),
      append: false,
    );

    if (!writeResult.success) {
      throw StateError(
        'Failed to persist resolved defect "$defectId": ${writeResult.error}',
      );
    }

    // Link the resolution into the traceability matrix.
    final linkSuccess = await _matrixLinker.linkResolution(
      defectId,
      resolutionLink,
    );

    if (!linkSuccess) {
      // Rollback: restore the original defect to maintain consistency.
      await _artifactStore.write(filePath, content, append: false);
      throw StateError(
        'Failed to link resolution for "$defectId" into traceability matrix. '
        'Defect status rolled back.',
      );
    }
  }

  // ─── JSON Serialization ────────────────────────────────────────────────────

  /// Serializes a [Defect] to a JSON string.
  String _defectToJson(Defect defect) {
    final map = <String, dynamic>{
      'id': defect.id,
      'severity': defect.severity.name,
      'reproSteps': defect.reproSteps,
      'status': defect.status.name,
      'category': defect.category.name,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Deserializes a [Defect] from a JSON string.
  /// Returns null if the JSON is malformed or contains invalid enum values.
  Defect? _defectFromJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final id = map['id'] as String?;
      if (id == null || id.isEmpty) return null;

      final severityStr = map['severity'] as String?;
      final severity = _parseSeverity(severityStr);
      if (severity == null) return null;

      final reproSteps = (map['reproSteps'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();
      if (reproSteps == null || reproSteps.isEmpty) return null;

      final statusStr = map['status'] as String?;
      final status = _parseResolutionStatus(statusStr);
      if (status == null) return null;

      final categoryStr = map['category'] as String?;
      final category = _parseGapCategory(categoryStr);
      if (category == null) return null;

      return Defect(
        id: id,
        severity: severity,
        reproSteps: reproSteps,
        status: status,
        category: category,
      );
    } catch (_) {
      return null;
    }
  }

  Severity? _parseSeverity(String? value) {
    if (value == null) return null;
    for (final s in Severity.values) {
      if (s.name == value) return s;
    }
    return null;
  }

  ResolutionStatus? _parseResolutionStatus(String? value) {
    if (value == null) return null;
    for (final s in ResolutionStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }

  GapCategory? _parseGapCategory(String? value) {
    if (value == null) return null;
    for (final c in GapCategory.values) {
      if (c.name == value) return c;
    }
    return null;
  }
}
