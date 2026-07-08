/// Bug Condition Exploration Test — Workspace Parallel Load (HARDWARE-009)
///
/// **Validates: Requirements 1.9, 2.9**
///
/// Property 9: Workspace `_load()` completes in approximately the time of
/// the slowest single call, NOT the sum of all 7 calls.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'workspace.load'`
///
/// BEFORE fix: `_load()` uses 7 sequential `await _safe(...)` calls.
/// Each call must wait for the previous to complete, so total load time
/// ≈ sum of all 7 individual call durations.
///
/// AFTER fix: All 7 independent fetches are wrapped in `Future.wait([...])`
/// so they execute concurrently. Total load time ≈ max(individual durations).
///
/// Strategy: Source-code probe asserting that _load() uses Future.wait to
/// dispatch all 7 calls concurrently, matching HardwareOperationsScreen._refreshAll().
///
/// Run: flutter test test/bug_condition/hardware_workspace_parallel_load_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-009 — workspace sequential load', () {
    final workspaceSrc = _readSource(
      'lib/features/hardware/presentation/screens/'
      'hardware_phase12_workspace_screen.dart',
    );

    // =========================================================================
    // Core assertion: _load() must use Future.wait for parallel execution
    // =========================================================================
    test('_load() uses Future.wait to parallelize all 7 fetches', () {
      // Extract the _load() method body from source
      final loadMethodStart = workspaceSrc.indexOf('Future<void> _load()');
      expect(
        loadMethodStart,
        isNot(-1),
        reason: '_load() method must exist in the workspace screen source.',
      );

      // Get the body of _load() — find the matching closing brace
      // We look for Future.wait within _load()'s body
      final loadBody = _extractMethodBody(workspaceSrc, loadMethodStart);

      expect(
        loadBody.contains('Future.wait'),
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-009): _load() in '
            'HardwarePhase12WorkspaceScreen does NOT use Future.wait — '
            'all 7 fetches are awaited sequentially. Total load time equals '
            'the SUM of all call durations (~3500ms for 7 × 500ms calls) '
            'instead of the MAX (~500ms). '
            'Fix: wrap all _safe(...) calls in Future.wait([...]) like '
            'HardwareOperationsScreen._refreshAll() does.',
      );
    });

    // =========================================================================
    // Preservation: per-call error isolation must be maintained
    // =========================================================================
    test('_safe() helper still exists for per-call error isolation', () {
      // The _safe helper provides per-call error isolation — each call can
      // fail independently without aborting others. It must remain even after
      // parallelization.
      expect(
        workspaceSrc.contains('Future<_LoadOutcome<T>> _safe<T>('),
        isTrue,
        reason:
            'The _safe() helper must remain present for per-call error '
            'isolation — each of the 7 fetches should still handle its own '
            'errors independently via _safe().',
      );
    });

    // =========================================================================
    // Preservation: all 7 data assignments must remain (per-call data)
    // =========================================================================
    test('all 7 section data variables are still assigned after load', () {
      // Each section must still get its own result assigned
      final expectedAssignments = [
        '_purchaseOrders =',
        '_parties =',
        '_pendingPurchaseOrders =',
        '_rateComparison =',
        '_salesOrders =',
        '_velocity =',
        '_deadStock =',
      ];

      for (final assignment in expectedAssignments) {
        expect(
          workspaceSrc.contains(assignment),
          isTrue,
          reason:
              'Per-call data preservation: "$assignment" must still be '
              'present — each section gets its own result from _load().',
        );
      }
    });
  });
}

/// Extracts a method body from the source starting at [methodStart].
/// Finds the first `{` after the method signature and matches braces
/// until the closing `}`.
String _extractMethodBody(String source, int methodStart) {
  final openBrace = source.indexOf('{', methodStart);
  if (openBrace == -1) return '';

  int depth = 0;
  int i = openBrace;
  while (i < source.length) {
    if (source[i] == '{') {
      depth++;
    } else if (source[i] == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBrace, i + 1);
      }
    }
    i++;
  }
  return source.substring(openBrace);
}
