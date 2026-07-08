/// Bug Condition Exploration Test — rbac.readingPermissionBypass
///
/// **Validates: Requirements 1.9**
///
/// Property 9: Bug Condition — Reading Permission Enforced
///
/// This test confirms that:
/// 1. `updateOpeningReading` wraps its permission check inside
///    `if (employeeId != null) { ... }` — meaning a null employeeId
///    causes the ENTIRE permission check to be SKIPPED.
/// 2. No caller of `updateOpeningReading` actually passes an employeeId,
///    so the check is dead code on the live path.
///
/// On UNFIXED code this test FAILS — the guard `if (employeeId != null)`
/// means a null/missing employeeId never triggers PermissionDeniedException;
/// the update proceeds unconditionally.
/// After the fix this same test PASSES — the permission check is
/// unconditional: a missing employeeId defaults to denial, not bypass.
///
/// Run: flutter test test/bug_condition/petrol_pump_reading_permission_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ===========================================================================
  // rbac.readingPermissionBypass / 1.9 / 2.9 — When
  // DispenserService.updateOpeningReading is called with employeeId == null
  // (which is every call site today, since no caller passes one), the
  // canEditReadings permission check is skipped entirely and the reading update
  // proceeds unconditionally.
  //
  // Expected (post-fix): The permission check is unconditional — a missing
  // employeeId causes denial (throws PermissionDeniedException), NOT bypass.
  //
  // Bug condition: `if (employeeId != null)` wraps the permission check,
  // so null employeeId = no check = unconditional update.
  // ===========================================================================
  group('Bug Condition 1.9 — rbac.readingPermissionBypass', () {
    late String dispenserServiceSrc;

    setUpAll(() {
      dispenserServiceSrc = _readSource(
        'lib/features/petrol_pump/services/dispenser_service.dart',
      );
      assert(
        dispenserServiceSrc.isNotEmpty,
        'dispenser_service.dart must exist',
      );
    });

    test(
      'updateOpeningReading permission check is NOT conditional on employeeId != null',
      () {
        // On FIXED code: the permission check should be unconditional —
        // a null employeeId should throw PermissionDeniedException, not
        // skip the check entirely.
        //
        // On UNFIXED code: the permission check is wrapped in
        //   `if (employeeId != null) { ... }`
        // meaning that when employeeId is null, the entire permission
        // enforcement block is bypassed and the update proceeds.

        // Locate the updateOpeningReading method definition
        final methodPattern = 'updateOpeningReading(';
        final methodIdx = dispenserServiceSrc.indexOf(methodPattern);
        expect(
          methodIdx,
          isNot(-1),
          reason:
              'updateOpeningReading method must exist in dispenser_service.dart',
        );

        // Extract the method body — look for the next top-level method
        // (Future<void> at column 2 after a blank line) or end of class
        final methodBodyStart = dispenserServiceSrc.indexOf('{', methodIdx);

        // Find the end of this method by locating the next method definition
        // or end of class. Methods in this file start with `Future<void>` or
        // `Stream<` at indent level 2 after the opening brace.
        final nextMethodPatterns = [
          'Future<void> updateClosingReading',
          'Future<void> _validateShiftOpen',
          'Future<bool> _checkPermission',
        ];

        int methodEndIdx = dispenserServiceSrc.length;
        for (final pat in nextMethodPatterns) {
          final idx = dispenserServiceSrc.indexOf(pat, methodBodyStart + 1);
          if (idx != -1 && idx < methodEndIdx) {
            methodEndIdx = idx;
          }
        }

        final methodBody = dispenserServiceSrc.substring(
          methodBodyStart,
          methodEndIdx,
        );

        // The bug: permission check is guarded by `if (employeeId != null)`
        // which means null employeeId = no check at all.
        //
        // Post-fix: the check should be unconditional. Either:
        // - There's no `if (employeeId != null)` before the permission check, OR
        // - A null employeeId triggers denial directly (throw PermissionDeniedException)
        //
        // Detect the bug pattern: `if (employeeId != null)` followed by
        // the permission check logic.
        final conditionalBypassPattern = RegExp(
          r'if\s*\(\s*employeeId\s*!=\s*null\s*\)',
        );
        final hasConditionalBypass = conditionalBypassPattern.hasMatch(
          methodBody,
        );

        // For the fix to be correct, a null employeeId must cause denial.
        // Check if there's an unconditional denial path for null employeeId:
        // e.g., `if (effectiveEmployeeId == null || !await _checkPermission(...))`
        // or `if (employeeId == null) throw PermissionDeniedException(...)`
        final unconditionalDenialPatterns = [
          // Pattern: throw when employeeId is null
          RegExp(r'employeeId\s*==\s*null.*throw\s+PermissionDeniedException'),
          RegExp(
            r'effectiveEmployeeId\s*==\s*null.*throw\s+PermissionDeniedException',
          ),
          // Pattern: combined null-or-no-permission check
          RegExp(
            r'if\s*\(\s*\w+\s*==\s*null\s*\|\|.*_checkPermission.*\).*throw',
          ),
          // Pattern: unconditional call without if-null guard
          RegExp(
            r'(?<!if\s*\(\s*employeeId\s*!=\s*null\s*\)\s*\{)_checkPermission',
          ),
        ];

        bool hasUnconditionalDenial = false;
        for (final pattern in unconditionalDenialPatterns) {
          if (pattern.hasMatch(methodBody)) {
            hasUnconditionalDenial = true;
            break;
          }
        }

        // The test asserts that the permission check is NOT conditional on
        // employeeId != null. On unfixed code, this FAILS because the check
        // IS conditional (wrapped in `if (employeeId != null)`).
        expect(
          hasConditionalBypass,
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.9): updateOpeningReading wraps the '
              'canEditReadings permission check inside '
              '`if (employeeId != null) { ... }`. Since NO caller passes an '
              'employeeId (all call sites use the default null), the permission '
              'check is NEVER executed. Any user can update nozzle readings '
              'without canEditReadings permission.\n\n'
              'Relevant code in updateOpeningReading:\n'
              '  if (employeeId != null) {\n'
              '    final hasPermission = await _checkPermission(\n'
              '      employeeId, \'canEditReadings\',\n'
              '    );\n'
              '    if (!hasPermission) { ... throw PermissionDeniedException ... }\n'
              '  }\n\n'
              'The fix must make the permission check unconditional: a null '
              'employeeId should default to DENIAL (throw '
              'PermissionDeniedException), not BYPASS.',
        );
      },
    );

    test(
      'updateClosingReading (non-system) permission check is NOT conditional on employeeId != null',
      () {
        // The same bug pattern exists in updateClosingReading for the
        // non-system-update path: `if (!isSystemUpdate && employeeId != null)`
        // means a null employeeId skips permission even for manual edits.

        // Locate updateClosingReading method
        final methodPattern = 'updateClosingReading(';
        final methodIdx = dispenserServiceSrc.indexOf(methodPattern);
        expect(
          methodIdx,
          isNot(-1),
          reason:
              'updateClosingReading method must exist in dispenser_service.dart',
        );

        // Extract the method body up to the next method
        final methodBodyStart = dispenserServiceSrc.indexOf('{', methodIdx);
        final nextMethodPatterns = [
          'Future<void> _validateShiftOpen',
          'Future<bool> _checkPermission',
          'Future<void> _logUnauthorizedAttempt',
        ];

        int methodEndIdx = dispenserServiceSrc.length;
        for (final pat in nextMethodPatterns) {
          final idx = dispenserServiceSrc.indexOf(pat, methodBodyStart + 1);
          if (idx != -1 && idx < methodEndIdx) {
            methodEndIdx = idx;
          }
        }

        final methodBody = dispenserServiceSrc.substring(
          methodBodyStart,
          methodEndIdx,
        );

        // The bug pattern in updateClosingReading:
        // `if (!isSystemUpdate && employeeId != null) { ... permission check ... }`
        // The `employeeId != null` part means null = bypass for manual updates.
        final conditionalBypassPattern = RegExp(
          r'if\s*\(\s*!isSystemUpdate\s*&&\s*employeeId\s*!=\s*null\s*\)',
        );
        final hasConditionalBypass = conditionalBypassPattern.hasMatch(
          methodBody,
        );

        expect(
          hasConditionalBypass,
          isFalse,
          reason:
              'COUNTEREXAMPLE (1.9): updateClosingReading wraps the '
              'canEditReadings permission check inside '
              '`if (!isSystemUpdate && employeeId != null) { ... }`. '
              'For manual edits (isSystemUpdate == false), a null employeeId '
              'STILL bypasses the permission check entirely. Since no caller '
              'passes an employeeId, any manual closing reading update '
              'proceeds without canEditReadings authorization.\n\n'
              'Relevant code in updateClosingReading:\n'
              '  if (!isSystemUpdate && employeeId != null) {\n'
              '    final hasPermission = await _checkPermission(\n'
              '      employeeId, \'canEditReadings\',\n'
              '    );\n'
              '    if (!hasPermission) { ... throw PermissionDeniedException ... }\n'
              '  }\n\n'
              'The fix must make the permission check unconditional for manual '
              'updates: a null employeeId on a non-system-update path should '
              'default to DENIAL, not BYPASS. The isSystemUpdate bypass for '
              'PetrolPumpBillingService-initiated updates is correct and must '
              'be preserved.',
        );
      },
    );
  });
}
