/// Example tests for DefectStore transactional resolution update.
///
/// Validates that a status change to Resolved/Closed updates the defect
/// status AND links the resolution into the Traceability_Matrix within the
/// same operation. Also verifies rollback on failed matrix linkage.
///
/// **Validates: Requirements 7.5**
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
    tempDir = Directory.systemTemp.createTempSync('defect_resolution_test_');
    linker = _RecordingLinker();
    store = DefectStore(basePath: tempDir.path, matrixLinker: linker);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Transactional resolution update (Req 7.5)', () {
    test(
      'resolve to Resolved updates status and links into matrix in one operation',
      () async {
        // 1) Upsert a defect in Open status.
        final defect = Defect(
          id: 'DEF-RES-001',
          severity: Severity.high,
          reproSteps: ['Open app', 'Navigate to billing', 'Observe crash'],
          status: ResolutionStatus.open,
          category: GapCategory.incorrectCalculation,
        );
        final upserted = await store.upsert(defect);
        expect(upserted, isTrue);

        // 2) Call resolve with Resolved status + resolution link.
        await store.resolve(
          'DEF-RES-001',
          ResolutionStatus.resolved,
          'commit:abc123-fix-billing-crash',
        );

        // 3) Assert the defect status is updated.
        final all = await store.getAll();
        expect(all, hasLength(1));
        expect(all.first.id, 'DEF-RES-001');
        expect(all.first.status, ResolutionStatus.resolved);

        // 3b) Assert the matrix linker was called in the same operation.
        expect(linker.calls, hasLength(1));
        expect(linker.calls.first.defectId, 'DEF-RES-001');
        expect(
          linker.calls.first.resolutionLink,
          'commit:abc123-fix-billing-crash',
        );
      },
    );

    test(
      'resolve to Closed updates status and links into matrix in one operation',
      () async {
        // 1) Upsert a defect in Open status.
        final defect = Defect(
          id: 'DEF-RES-002',
          severity: Severity.critical,
          reproSteps: ['Login', 'Create invoice', 'Payment mismatch'],
          status: ResolutionStatus.open,
          category: GapCategory.dataIntegrity,
        );
        await store.upsert(defect);

        // 2) Call resolve with Closed status + resolution link.
        await store.resolve(
          'DEF-RES-002',
          ResolutionStatus.closed,
          'verified-in-production-v2.1.0',
        );

        // 3) Assert status updated to Closed.
        final all = await store.getAll();
        expect(all, hasLength(1));
        expect(all.first.status, ResolutionStatus.closed);

        // 3b) Assert matrix linker called with correct arguments.
        expect(linker.calls, hasLength(1));
        expect(linker.calls.first.defectId, 'DEF-RES-002');
        expect(
          linker.calls.first.resolutionLink,
          'verified-in-production-v2.1.0',
        );
      },
    );

    test('rollback on failed matrix linkage preserves original status', () async {
      // 1) Upsert a defect in Open status.
      final defect = Defect(
        id: 'DEF-RES-003',
        severity: Severity.medium,
        reproSteps: ['Open reports', 'Filter by date', 'Numbers wrong'],
        status: ResolutionStatus.open,
        category: GapCategory.incorrectCalculation,
      );
      await store.upsert(defect);

      // 2) Configure the linker to fail.
      linker.shouldFail = true;

      // 3) Attempt resolution — should throw StateError due to link failure.
      await expectLater(
        store.resolve(
          'DEF-RES-003',
          ResolutionStatus.resolved,
          'commit:xyz789',
        ),
        throwsStateError,
      );

      // 4) Assert defect status was rolled back to original (open).
      final all = await store.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'DEF-RES-003');
      expect(all.first.status, ResolutionStatus.open);

      // 4b) The linker was still invoked (the failure happened during linkage).
      expect(linker.calls, hasLength(1));
    });

    test(
      'rollback preserves inProgress status when linkage fails mid-resolution',
      () async {
        // 1) Upsert a defect already in InProgress status.
        final defect = Defect(
          id: 'DEF-RES-004',
          severity: Severity.low,
          reproSteps: ['Trigger sync', 'Observe stale data'],
          status: ResolutionStatus.inProgress,
          category: GapCategory.workflow,
        );
        await store.upsert(defect);

        // 2) Configure the linker to fail.
        linker.shouldFail = true;

        // 3) Attempt resolution — should throw.
        await expectLater(
          store.resolve(
            'DEF-RES-004',
            ResolutionStatus.closed,
            'hotfix-deployed',
          ),
          throwsStateError,
        );

        // 4) Assert the original inProgress status is preserved.
        final all = await store.getAll();
        expect(all, hasLength(1));
        expect(all.first.status, ResolutionStatus.inProgress);
      },
    );

    test('resolve throws ArgumentError for non-resolution statuses', () async {
      final defect = Defect(
        id: 'DEF-RES-005',
        severity: Severity.high,
        reproSteps: ['Step 1'],
        status: ResolutionStatus.open,
        category: GapCategory.feature,
      );
      await store.upsert(defect);

      // Open is not a resolution status.
      await expectLater(
        store.resolve('DEF-RES-005', ResolutionStatus.open, 'link'),
        throwsArgumentError,
      );

      // InProgress is not a resolution status.
      await expectLater(
        store.resolve('DEF-RES-005', ResolutionStatus.inProgress, 'link'),
        throwsArgumentError,
      );

      // Neither status update nor matrix linkage should have occurred.
      expect(linker.calls, isEmpty);
      final all = await store.getAll();
      expect(all.first.status, ResolutionStatus.open);
    });

    test('resolve throws StateError when defect does not exist', () async {
      await expectLater(
        store.resolve(
          'NON-EXISTENT-999',
          ResolutionStatus.resolved,
          'some-link',
        ),
        throwsStateError,
      );

      // No linkage attempted for a non-existent defect.
      expect(linker.calls, isEmpty);
    });
  });
}

// ─── Test Helpers ──────────────────────────────────────────────────────────────

/// Records calls to [linkResolution] for assertion and can simulate failures.
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
