/// Unit tests for [DefectStore].
///
/// Validates:
/// - Only validated defects are persisted (Req 7.3)
/// - [allClosed] reports correctly (Req 7.4)
/// - [resolve] updates status and links into traceability matrix in one
///   operation (Req 7.5)
/// - Rollback on failed matrix linkage
///
/// Requirements: 7.4, 7.5
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../core/defect.dart';
import 'artifact_store.dart';
import 'defect_store.dart';

void main() {
  late Directory tempDir;
  late DefectStore store;
  late _RecordingLinker linker;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('defect_store_test_');
    linker = _RecordingLinker();
    store = DefectStore(basePath: tempDir.path, matrixLinker: linker);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('upsert', () {
    test('persists a valid defect and can retrieve it', () async {
      final defect = _validDefect('DEF-001');

      final result = await store.upsert(defect);

      expect(result, isTrue);

      final all = await store.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'DEF-001');
      expect(all.first.severity, Severity.high);
      expect(all.first.status, ResolutionStatus.open);
      expect(all.first.category, GapCategory.incorrectCalculation);
      expect(all.first.reproSteps, ['Step 1', 'Step 2']);
    });

    test('rejects a defect with empty id', () async {
      final defect = Defect(
        id: '',
        severity: Severity.medium,
        reproSteps: ['Step 1'],
        status: ResolutionStatus.open,
        category: GapCategory.feature,
      );

      final result = await store.upsert(defect);

      expect(result, isFalse);
      final all = await store.getAll();
      expect(all, isEmpty);
    });

    test('rejects a defect with empty reproSteps', () async {
      final defect = Defect(
        id: 'DEF-002',
        severity: Severity.low,
        reproSteps: [],
        status: ResolutionStatus.open,
        category: GapCategory.workflow,
      );

      final result = await store.upsert(defect);

      expect(result, isFalse);
      final all = await store.getAll();
      expect(all, isEmpty);
    });

    test('overwrites an existing defect on upsert', () async {
      final defect1 = _validDefect('DEF-003');
      await store.upsert(defect1);

      final defect2 = Defect(
        id: 'DEF-003',
        severity: Severity.critical,
        reproSteps: ['Updated step'],
        status: ResolutionStatus.inProgress,
        category: GapCategory.dataIntegrity,
      );
      await store.upsert(defect2);

      final all = await store.getAll();
      expect(all, hasLength(1));
      expect(all.first.severity, Severity.critical);
      expect(all.first.status, ResolutionStatus.inProgress);
    });
  });

  group('allClosed', () {
    test('returns true when no defects exist', () async {
      expect(await store.allClosed, isTrue);
    });

    test('returns false when at least one defect is open', () async {
      await store.upsert(_validDefect('DEF-010'));
      expect(await store.allClosed, isFalse);
    });

    test('returns true when all defects are closed', () async {
      final closedDefect = Defect(
        id: 'DEF-011',
        severity: Severity.low,
        reproSteps: ['Step 1'],
        status: ResolutionStatus.closed,
        category: GapCategory.feature,
      );
      await store.upsert(closedDefect);
      expect(await store.allClosed, isTrue);
    });

    test('returns false when one of many defects is not closed', () async {
      final closed1 = Defect(
        id: 'DEF-012',
        severity: Severity.low,
        reproSteps: ['Step 1'],
        status: ResolutionStatus.closed,
        category: GapCategory.feature,
      );
      final openDefect = Defect(
        id: 'DEF-013',
        severity: Severity.high,
        reproSteps: ['Step 1'],
        status: ResolutionStatus.open,
        category: GapCategory.workflow,
      );
      await store.upsert(closed1);
      await store.upsert(openDefect);
      expect(await store.allClosed, isFalse);
    });
  });

  group('getAll', () {
    test('returns empty list when defects directory does not exist', () async {
      expect(await store.getAll(), isEmpty);
    });

    test('returns all persisted defects', () async {
      await store.upsert(_validDefect('DEF-020'));
      await store.upsert(_validDefect('DEF-021'));
      await store.upsert(_validDefect('DEF-022'));

      final all = await store.getAll();
      expect(all, hasLength(3));
      final ids = all.map((d) => d.id).toSet();
      expect(ids, containsAll(['DEF-020', 'DEF-021', 'DEF-022']));
    });
  });

  group('resolve', () {
    test('updates defect status to resolved and links into matrix', () async {
      await store.upsert(_validDefect('DEF-030'));

      await store.resolve(
        'DEF-030',
        ResolutionStatus.resolved,
        'fix-commit-abc123',
      );

      final all = await store.getAll();
      expect(all.first.status, ResolutionStatus.resolved);
      expect(linker.calls, hasLength(1));
      expect(linker.calls.first.defectId, 'DEF-030');
      expect(linker.calls.first.resolutionLink, 'fix-commit-abc123');
    });

    test('updates defect status to closed and links into matrix', () async {
      await store.upsert(_validDefect('DEF-031'));

      await store.resolve(
        'DEF-031',
        ResolutionStatus.closed,
        'verified-in-prod',
      );

      final all = await store.getAll();
      expect(all.first.status, ResolutionStatus.closed);
      expect(linker.calls, hasLength(1));
    });

    test('throws ArgumentError for non-resolution status', () async {
      await store.upsert(_validDefect('DEF-032'));

      expect(
        () => store.resolve('DEF-032', ResolutionStatus.open, 'link'),
        throwsArgumentError,
      );
      expect(
        () => store.resolve('DEF-032', ResolutionStatus.inProgress, 'link'),
        throwsArgumentError,
      );
    });

    test('throws StateError when defect does not exist', () async {
      expect(
        () => store.resolve('NON-EXISTENT', ResolutionStatus.resolved, 'link'),
        throwsStateError,
      );
    });

    test('rolls back defect on failed matrix linkage', () async {
      linker.shouldFail = true;
      await store.upsert(_validDefect('DEF-033'));

      expect(
        () => store.resolve('DEF-033', ResolutionStatus.resolved, 'link'),
        throwsStateError,
      );

      // Status should be rolled back to the original (open).
      final all = await store.getAll();
      expect(all.first.status, ResolutionStatus.open);
    });
  });
}

// ─── Test Helpers ──────────────────────────────────────────────────────────────

Defect _validDefect(String id) => Defect(
  id: id,
  severity: Severity.high,
  reproSteps: ['Step 1', 'Step 2'],
  status: ResolutionStatus.open,
  category: GapCategory.incorrectCalculation,
);

/// Records calls to [linkResolution] for assertion.
class _RecordingLinker implements TraceabilityMatrixLinker {
  final List<_LinkCall> calls = [];
  bool shouldFail = false;

  @override
  Future<bool> linkResolution(String defectId, String resolutionLink) async {
    calls.add(_LinkCall(defectId: defectId, resolutionLink: resolutionLink));
    return !shouldFail;
  }
}

class _LinkCall {
  final String defectId;
  final String resolutionLink;
  _LinkCall({required this.defectId, required this.resolutionLink});
}
