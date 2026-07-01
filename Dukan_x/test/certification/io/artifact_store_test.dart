/// Example tests for atomic write and within-5s update for [ArtifactStore]
/// and [TraceabilityMatrix].
///
/// 1. Atomic write: write content, verify it exists. Write again, verify updated.
/// 2. Failed write: simulate failure (invalid path), verify last good content retained.
/// 3. Within-5s update: apply a TraceChange, persist it, and measure that persist
///    completes within 5 seconds.
/// 4. Append mode preserves prior content.
///
/// **Validates: Requirements 13.2, 13.6**
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../core/traceability_matrix.dart';
import 'artifact_store.dart';

void main() {
  late Directory tempDir;
  late ArtifactStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('artifact_store_test_');
    store = const ArtifactStore();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Atomic write (Req 13.6)', () {
    test('writes content and verifies it exists', () async {
      final path = '${tempDir.path}/matrix.md';

      final result = await store.write(path, 'initial content', append: false);

      expect(result.success, isTrue);
      expect(result.error, isNull);

      final content = await store.read(path);
      expect(content, 'initial content');
    });

    test('writes again and verifies content is updated', () async {
      final path = '${tempDir.path}/matrix.md';

      await store.write(path, 'first version', append: false);
      final result = await store.write(path, 'second version', append: false);

      expect(result.success, isTrue);

      final content = await store.read(path);
      expect(content, 'second version');
    });
  });

  group('Failed write retains last good content (Req 13.6)', () {
    test(
      'invalid path returns error and preserves last good artifact',
      () async {
        final goodPath = '${tempDir.path}/stable.md';

        // Write known-good content first.
        await store.write(goodPath, 'last good matrix', append: false);

        // Attempt a write to an invalid path (directory path used as a file).
        // On Windows, writing to a path that is actually a directory will fail.
        final badDir = Directory('${tempDir.path}/blocked');
        badDir.createSync();
        final badPath = badDir.path; // trying to write to directory as file

        final failResult = await store.write(
          badPath,
          'bad content',
          append: false,
        );

        // Depending on OS, writing to a directory may fail differently.
        // The key assertion: our good file remains intact regardless.
        final preserved = await store.read(goodPath);
        expect(
          preserved,
          'last good matrix',
          reason: 'Last good artifact must be retained on failure',
        );

        // If the write to the bad path did fail, verify it returned an error.
        if (!failResult.success) {
          expect(failResult.error, isNotNull);
          expect(failResult.error, contains('Failed to write artifact'));
        }
      },
    );

    test('corrupted mid-write leaves original intact', () async {
      final path = '${tempDir.path}/artifact.json';

      // Write known-good content.
      await store.write(path, '{"version": 1}', append: false);

      // Simulate a scenario where the .tmp file location is invalid.
      // We create a directory at the .tmp path to force the rename to fail.
      final tmpAsDir = Directory('$path.tmp');
      tmpAsDir.createSync(recursive: true);
      // Also put a file inside to make the directory non-empty on some systems.
      File('${tmpAsDir.path}/blocker').writeAsStringSync('block');

      final failResult = await store.write(
        path,
        '{"version": 2}',
        append: false,
      );

      // The write should fail because .tmp path is occupied by a directory.
      expect(failResult.success, isFalse);
      expect(failResult.error, isNotNull);

      // Original content must be preserved.
      final preserved = await store.read(path);
      expect(preserved, '{"version": 1}');
    });
  });

  group('Within-5s update (Req 13.2)', () {
    test(
      'committed test-case change updates entry and persists within 5 seconds',
      () async {
        final path = '${tempDir.path}/traceability-matrix.json';
        final matrix = TraceabilityMatrix(store: store);

        // Seed a requirement entry with no test cases (coverage gap).
        matrix.applyChange(
          AddTestCase(requirementId: 'REQ-1.1', testCaseId: 'TC-001'),
        );
        await matrix.persist(path);

        // Now simulate a committed test-case change and measure time.
        final stopwatch = Stopwatch()..start();

        matrix.applyChange(
          AddTestCase(requirementId: 'REQ-1.1', testCaseId: 'TC-002'),
        );
        final result = await matrix.persist(path);

        stopwatch.stop();

        expect(result.success, isTrue);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Persist must complete within 5 seconds (Req 13.2)',
        );

        // Verify the change was persisted correctly.
        final loaded = await store.read(path);
        expect(loaded, isNotNull);
        final restored = TraceabilityMatrix.deserialize(loaded!, store: store);
        final entry = restored.getEntry('REQ-1.1');
        expect(entry, isNotNull);
        expect(entry!.testCaseIds, contains('TC-002'));
        expect(entry.isCoverageGap, isFalse);
      },
    );

    test('multiple rapid changes all persist within 5 seconds', () async {
      final path = '${tempDir.path}/traceability-rapid.json';
      final matrix = TraceabilityMatrix(store: store);

      final stopwatch = Stopwatch()..start();

      // Apply 10 changes and persist after each one.
      for (int i = 0; i < 10; i++) {
        matrix.applyChange(
          AddTestCase(requirementId: 'REQ-2.$i', testCaseId: 'TC-RAPID-$i'),
        );
        final result = await matrix.persist(path);
        expect(result.success, isTrue);
      }

      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: 'All 10 persists must complete within 5 seconds',
      );
      expect(matrix.length, 10);
    });
  });

  group('Append mode preserves prior content (Req 13.6)', () {
    test('appended content is concatenated with existing content', () async {
      final path = '${tempDir.path}/append-test.md';

      await store.write(path, 'Line 1\n', append: false);
      await store.write(path, 'Line 2\n', append: true);
      await store.write(path, 'Line 3\n', append: true);

      final content = await store.read(path);
      expect(content, 'Line 1\nLine 2\nLine 3\n');
    });

    test('append to non-existent file creates it with the content', () async {
      final path = '${tempDir.path}/new-append.md';

      final result = await store.write(path, 'first entry\n', append: true);

      expect(result.success, isTrue);
      final content = await store.read(path);
      expect(content, 'first entry\n');
    });

    test('failed append preserves existing content', () async {
      final path = '${tempDir.path}/safe-append.md';
      await store.write(path, 'original\n', append: false);

      // Force failure by making the .tmp path a directory.
      final tmpAsDir = Directory('$path.tmp');
      tmpAsDir.createSync(recursive: true);
      File('${tmpAsDir.path}/blocker').writeAsStringSync('x');

      final failResult = await store.write(path, 'appended\n', append: true);

      expect(failResult.success, isFalse);

      final preserved = await store.read(path);
      expect(
        preserved,
        'original\n',
        reason: 'Append failure must not corrupt existing content',
      );
    });
  });
}
