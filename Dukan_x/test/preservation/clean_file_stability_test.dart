// CLEAN-FILE STABILITY ASSERTION — clause 3.7 of bugfix.md
//
// "Files with no pre-existing diagnostics are left unchanged."
//
// This test captures content digests of ALL Dukan_x/lib/ dart files
// (excluding generated/build artifacts). On UNFIXED code the golden is
// written and the test passes — establishing the baseline. After each
// fix batch, the test re-runs: any file whose digest changes is flagged.
//
// The fix implementation (Task 3) is only allowed to modify files that
// HAD in-scope diagnostics. Any change to a file that was already clean
// is a preservation regression and must be investigated.
//
// **Validates: Requirements 3.7**

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'preservation_walker.dart';

void main() {
  late final Directory ws;

  setUpAll(() {
    ws = resolveWorkspaceRoot();
  });

  // -------------------------------------------------------------------------
  // Clause 3.7 — Clean-file content-digest stability
  //
  // For every .dart file under Dukan_x/lib/ that is NOT a generated file,
  // compute a deterministic content digest. Store the full map as a golden.
  // On subsequent runs, compare live digests against the golden. Any
  // mismatch indicates a file was modified that should have been left
  // untouched (unless it contained in-scope diagnostics and was fixed).
  //
  // On UNFIXED code (Task 2), this golden is written for the first time
  // and the test passes trivially. After each fix batch (Task 3.x), only
  // files that had diagnostics should differ — the test alerts on anything
  // else changing.
  // -------------------------------------------------------------------------
  test('preservation: clean-file digests are stable — files with no in-scope '
      'diagnostics must not change after each batch (clause 3.7)', () {
    final libDir = Directory('${ws.path}/Dukan_x/lib');
    expect(libDir.existsSync(), isTrue, reason: 'Dukan_x/lib/ must exist');

    final observations = <Map<String, dynamic>>[];
    final allFiles = listDartFiles(libDir);

    for (final f in allFiles) {
      final content = safeRead(f);
      if (content.isEmpty) continue;

      observations.add({
        'path': relPath(ws, f),
        'digest': contentDigest(content),
        'size': content.length,
      });
    }

    // Sort for deterministic golden output
    observations.sort(
      (a, b) => (a['path'] as String).compareTo(b['path'] as String),
    );

    // Use the standard golden mechanism: write on first run, compare on
    // subsequent runs. Any file whose digest changes between F and F'
    // will cause a mismatch here.
    expectMatchesGolden(ws, 'clean_file_digests', observations);
  });

  // -------------------------------------------------------------------------
  // Additional clause 3.7 guard: verify that the total file count under
  // Dukan_x/lib/ is stable. File additions during the fix are permitted
  // only if they are net-new helper files documented in the fix scope.
  // File deletions (dead code removal) are only permitted for files that
  // had diagnostics.
  // -------------------------------------------------------------------------
  test('preservation: Dukan_x/lib/ file count is stable across F -> F\' '
      '(clause 3.7)', () {
    final libDir = Directory('${ws.path}/Dukan_x/lib');
    expect(libDir.existsSync(), isTrue);

    final allFiles = listDartFiles(libDir);
    final count = allFiles.length;

    // Record the file count as a simple golden value
    expectMatchesGolden(ws, 'lib_file_count', {'count': count});
  });
}
