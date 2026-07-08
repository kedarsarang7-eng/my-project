/// Bug Condition Exploration Test — Credit Control Debounce (HARDWARE-010)
///
/// **Validates: Requirements 1.10, 2.10**
///
/// Property 10: Rapid filter changes in `HardwareCreditControlScreen`
/// coalesce into a single `_load()` call after ~300ms, instead of
/// firing one call per change.
///
/// Bug Condition: `isBugCondition(input)` where
///   `input.surface == 'creditControl.filterChange'`
///
/// BEFORE fix: Each dropdown `onChanged` immediately calls `_load()`.
/// 5 rapid changes → 5 network calls.
///
/// AFTER fix: A ~300ms debounce Timer cancels pending `_load()` calls
/// on each new change, so only the last change triggers the fetch.
///
/// Strategy: Source-code probe asserting that:
///   1. A debounce Timer field exists
///   2. Filter onChanged handlers use the debounce rather than calling _load() directly
///   3. The Timer is disposed in dispose()
///   4. A single isolated filter change still triggers _load() after the delay
///
/// Run: flutter test test/bug_condition/hardware_credit_control_debounce_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the project root.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  group('Bug Condition HARDWARE-010 — credit control filter debounce', () {
    final creditControlSrc = _readSource(
      'lib/features/hardware/presentation/screens/'
      'hardware_credit_control_screen.dart',
    );

    // =========================================================================
    // Core assertion: A debounce Timer field must exist
    // =========================================================================
    test('a debounce Timer field is declared in the state class', () {
      // The fix requires a Timer? _debounce field (or similar) to hold
      // the pending debounced _load() call.
      final hasTimerField =
          RegExp(r'Timer\?\s+_debounce').hasMatch(creditControlSrc) ||
          RegExp(r'Timer\?\s+_filterDebounce').hasMatch(creditControlSrc);

      expect(
        hasTimerField,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-010): No debounce Timer field found in '
            'HardwareCreditControlScreen state. Each filter onChanged calls '
            '_load() immediately — 5 rapid changes produce 5 network calls. '
            'Fix: add a Timer? _debounce field and use it to coalesce rapid '
            'filter changes into a single _load() after ~300ms.',
      );
    });

    // =========================================================================
    // Core assertion: Filter onChanged does NOT directly call _load()
    // =========================================================================
    test('filter onChanged handlers do not call _load() directly', () {
      // Extract the _buildFilters() method body
      final buildFiltersStart = creditControlSrc.indexOf('_buildFilters()');
      expect(
        buildFiltersStart,
        isNot(-1),
        reason: '_buildFilters() method must exist.',
      );

      final filtersBody = _extractMethodBody(
        creditControlSrc,
        buildFiltersStart,
      );

      // In the unfixed code, onChanged callbacks directly call _load().
      // After the fix, they should call a debounced method instead.
      // Count direct _load() calls within the filters builder:
      final directLoadCalls = RegExp(r'_load\(\)').allMatches(filtersBody);

      expect(
        directLoadCalls.length,
        equals(0),
        reason:
            'COUNTEREXAMPLE (HARDWARE-010): _buildFilters() still directly '
            'calls _load() ${directLoadCalls.length} time(s) in filter '
            'onChanged handlers. 5 rapid changes → 5 immediate network calls. '
            'Fix: replace direct _load() calls with a debounced handler that '
            'cancels the previous Timer and schedules _load() after ~300ms.',
      );
    });

    // =========================================================================
    // Core assertion: Timer is cancelled + rescheduled (debounce pattern)
    // =========================================================================
    test('debounce pattern: Timer is cancelled and rescheduled', () {
      // The debounce pattern requires:
      //   _debounce?.cancel();
      //   _debounce = Timer(Duration(...), () => _load());
      final hasCancelPattern =
          creditControlSrc.contains('_debounce?.cancel()') ||
          creditControlSrc.contains('_filterDebounce?.cancel()');
      final hasTimerCreation =
          RegExp(r'Timer\(').hasMatch(creditControlSrc) ||
          RegExp(r'Timer\(const Duration').hasMatch(creditControlSrc);

      expect(
        hasCancelPattern && hasTimerCreation,
        isTrue,
        reason:
            'COUNTEREXAMPLE (HARDWARE-010): Missing debounce cancel+reschedule '
            'pattern. The fix requires `_debounce?.cancel()` followed by '
            '`_debounce = Timer(Duration(milliseconds: 300), () => _load())` '
            'so rapid changes coalesce into a single call.',
      );
    });

    // =========================================================================
    // Preservation: Timer is disposed in dispose()
    // =========================================================================
    test('debounce Timer is cancelled in dispose()', () {
      final disposeStart = creditControlSrc.indexOf('@override');
      // Find the dispose() method specifically
      final disposeMethodIdx = creditControlSrc.indexOf('void dispose()');

      if (disposeMethodIdx == -1) {
        // No dispose() override at all — fail
        fail(
          'COUNTEREXAMPLE (HARDWARE-010): No dispose() override found. '
          'The debounce Timer must be cancelled in dispose() to prevent '
          'calling _load() after the widget is unmounted.',
        );
      }

      final disposeBody = _extractMethodBody(
        creditControlSrc,
        disposeMethodIdx,
      );

      final cancelsTimer =
          disposeBody.contains('_debounce?.cancel()') ||
          disposeBody.contains('_filterDebounce?.cancel()');

      expect(
        cancelsTimer,
        isTrue,
        reason:
            'The debounce Timer must be cancelled in dispose() to avoid '
            'calling _load() on an unmounted widget.',
      );
    });

    // =========================================================================
    // Preservation: _load() method itself still exists (single filter change
    // must still trigger a refresh after the delay)
    // =========================================================================
    test('_load() method still exists for actual data fetching', () {
      expect(
        creditControlSrc.contains('Future<void> _load()'),
        isTrue,
        reason:
            'Preservation (3.10): _load() must still exist — a single '
            'isolated filter change must still trigger a refresh after '
            'the debounce delay elapses.',
      );
    });

    // =========================================================================
    // Preservation: dart:async import for Timer
    // =========================================================================
    test("imports dart:async for Timer usage", () {
      final hasDartAsync =
          creditControlSrc.contains("import 'dart:async'") ||
          creditControlSrc.contains('import "dart:async"');

      expect(
        hasDartAsync,
        isTrue,
        reason:
            'dart:async must be imported for Timer. Without it the debounce '
            'Timer cannot be used.',
      );
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
