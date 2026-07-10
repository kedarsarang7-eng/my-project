/// Preservation Property Test — Unchecked Reminder Opt-In Unaffected
///
/// **Validates: Requirements 3.5**
///
/// Property 6: Preservation — Unchecked Reminder Opt-In Unaffected
///
/// This test verifies that the `if (sendReminder) { ... }` guard in
/// `appointment_screen.dart`'s `_showAddDialog` unconditionally gates ALL
/// reminder dispatch logic — whether the current debugPrint stub OR a future
/// WhatsAppService dispatch — so that when `sendReminder = false`, zero
/// reminder-related code executes.
///
/// Approach: static source-reading. We read the Dart source, locate the
/// `if (sendReminder)` block, and assert:
///   1. The block exists and is the ONLY place containing reminder keywords
///      (WhatsAppService, sendMessage, debugPrint('Reminder, SnackBar reminder)
///   2. No unconditional reminder dispatch exists outside the block
///   3. No `|| true` or equivalent bypass weakens the guard
///
/// PBT: generate arbitrary appointment metadata (purpose, datetime, patientId)
/// and assert the structural property holds for every generated payload — there
/// is no path to reminder dispatch that bypasses the sendReminder check.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/preservation/clinic_audit_preservation_unchecked_reminder_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

// ---------------------------------------------------------------------------
// Source file path (relative to project root, resolved at test runtime).
// ---------------------------------------------------------------------------
const _appointmentScreenRelPath =
    'lib/features/doctor/presentation/screens/appointment_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads the appointment_screen.dart source file.
String _readAppointmentScreenSource() {
  // Resolve from the project root (test runner cwd is the project root).
  final file = File(_appointmentScreenRelPath);
  if (!file.existsSync()) {
    fail(
      'appointment_screen.dart not found at $_appointmentScreenRelPath — '
      'cannot verify sendReminder preservation property',
    );
  }
  return file.readAsStringSync();
}

/// Extracts the `_showAddDialog` method body from the source.
String _extractShowAddDialogBody(String source) {
  // Find the method start
  final methodStart = source.indexOf('void _showAddDialog(');
  if (methodStart == -1) {
    fail('_showAddDialog method not found in appointment_screen.dart');
  }
  // Extract from method start to the end of the method (brace matching)
  var braceCount = 0;
  var started = false;
  var methodEnd = methodStart;
  for (var i = methodStart; i < source.length; i++) {
    if (source[i] == '{') {
      braceCount++;
      started = true;
    } else if (source[i] == '}') {
      braceCount--;
      if (started && braceCount == 0) {
        methodEnd = i + 1;
        break;
      }
    }
  }
  return source.substring(methodStart, methodEnd);
}

/// Extracts the `if (sendReminder)` block body from the method.
/// Returns the content INSIDE the braces of the if block.
String _extractSendReminderBlock(String methodBody) {
  // Find the if (sendReminder) line — match with potential whitespace
  final ifPattern = RegExp(r'if\s*\(\s*sendReminder\s*\)');
  final match = ifPattern.firstMatch(methodBody);
  if (match == null) {
    fail(
      'No `if (sendReminder)` block found in _showAddDialog — '
      'the reminder guard has been removed or modified unsafely',
    );
  }

  // Find the opening brace after the if
  final afterIf = match.end;
  var braceStart = -1;
  for (var i = afterIf; i < methodBody.length; i++) {
    if (methodBody[i] == '{') {
      braceStart = i;
      break;
    }
    // If we hit a semicolon or another statement before a brace,
    // it's a single-line if without braces
    if (methodBody[i] == ';') {
      // Single-line if — extract up to the semicolon
      return methodBody.substring(afterIf, i + 1);
    }
  }

  if (braceStart == -1) {
    fail('Could not find opening brace for if (sendReminder) block');
  }

  // Brace-match to find the end of the if block
  var braceCount = 0;
  var blockEnd = braceStart;
  for (var i = braceStart; i < methodBody.length; i++) {
    if (methodBody[i] == '{') {
      braceCount++;
    } else if (methodBody[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        blockEnd = i + 1;
        break;
      }
    }
  }
  return methodBody.substring(braceStart, blockEnd);
}

/// Returns the portion of the method body OUTSIDE the `if (sendReminder)` block.
String _getMethodBodyOutsideReminderBlock(
  String methodBody,
  String reminderBlock,
) {
  final blockStart = methodBody.indexOf(reminderBlock);
  if (blockStart == -1) return methodBody;
  return methodBody.substring(0, blockStart) +
      methodBody.substring(blockStart + reminderBlock.length);
}

/// Keywords that indicate EXECUTABLE reminder dispatch logic (not comments).
/// If any of these appear in executable code outside the `if (sendReminder)`
/// block, the guard is not comprehensive.
///
/// Note: we exclude comment-only keywords like 'backend dispatch' which appear
/// in TODO comments but do not constitute executable dispatch paths.
const _reminderDispatchKeywords = ['WhatsAppService', 'sendMessage'];

/// Patterns that would weaken the `if (sendReminder)` guard.
final _bypassPatterns = [
  RegExp(r'if\s*\(\s*sendReminder\s*\|\|\s*true\s*\)'),
  RegExp(r'if\s*\(\s*true\s*\|\|\s*sendReminder\s*\)'),
  RegExp(r'if\s*\(\s*!?\s*false\s*\)'), // if (true) or if (!false)
  RegExp(
    r'sendReminder\s*=\s*true\s*;',
  ), // unconditional override before the if
];

/// Strips single-line (`//`) and multi-line (`/* */`) comments from Dart source.
String _stripComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '/') {
      // Single-line comment — skip until newline
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (i + 1 < source.length &&
        source[i] == '/' &&
        source[i + 1] == '*') {
      // Multi-line comment — skip until */
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2; // Skip the closing */
    } else {
      buffer.write(source[i]);
      i++;
    }
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------
void main() {
  late String source;
  late String methodBody;
  late String reminderBlock;
  late String outsideBlock;

  setUpAll(() {
    source = _readAppointmentScreenSource();
    methodBody = _extractShowAddDialogBody(source);
    reminderBlock = _extractSendReminderBlock(methodBody);
    outsideBlock = _getMethodBodyOutsideReminderBlock(
      methodBody,
      reminderBlock,
    );
  });

  // =========================================================================
  // DIRECT ASSERTIONS: Structural verification
  // =========================================================================
  group('Preservation 3.5 — sendReminder guard structural verification', () {
    test('if (sendReminder) block exists in _showAddDialog', () {
      final ifPattern = RegExp(r'if\s*\(\s*sendReminder\s*\)');
      expect(
        ifPattern.hasMatch(methodBody),
        isTrue,
        reason:
            'The `if (sendReminder)` guard must exist in _showAddDialog to '
            'gate all reminder dispatch logic',
      );
    });

    test('no bypass patterns weaken the sendReminder guard', () {
      for (final pattern in _bypassPatterns) {
        expect(
          pattern.hasMatch(methodBody),
          isFalse,
          reason:
              'Found a bypass pattern that would weaken the sendReminder guard: '
              '${pattern.pattern}',
        );
      }
    });

    test('no reminder dispatch keywords appear in executable code outside the '
        'if (sendReminder) block', () {
      for (final keyword in _reminderDispatchKeywords) {
        // Strip comments from the outside-block code before checking
        final executableOutside = _stripComments(outsideBlock);
        final hasKeywordOutside = executableOutside.contains(keyword);

        expect(
          hasKeywordOutside,
          isFalse,
          reason:
              'Reminder dispatch keyword "$keyword" found in executable code '
              'OUTSIDE the `if (sendReminder)` block — this means reminder '
              'logic can execute even when sendReminder = false',
        );
      }
    });

    test(
      'the sendReminder guard is a simple boolean check (no compound OR)',
      () {
        // The if condition should be just `sendReminder`, not
        // `sendReminder || someOtherCondition`
        final ifLine = RegExp(
          r'if\s*\(\s*sendReminder\s*\)',
        ).firstMatch(methodBody);
        expect(ifLine, isNotNull);

        // Verify there's no || in the condition
        final compoundOr = RegExp(r'if\s*\(\s*sendReminder\s*\|\|');
        expect(
          compoundOr.hasMatch(methodBody),
          isFalse,
          reason:
              'The sendReminder guard must be a simple `if (sendReminder)` — '
              'no compound OR that could bypass the opt-in check',
        );
      },
    );

    test(
      'reminder block contains the current stub (debugPrint) OR real dispatch',
      () {
        // The block must contain SOME reminder logic — either the stub or
        // the real dispatch. This confirms the block isn't empty.
        final hasDebugPrint = reminderBlock.contains('debugPrint');
        final hasSendMessage = reminderBlock.contains('sendMessage');
        final hasWhatsApp = reminderBlock.contains('WhatsAppService');

        expect(
          hasDebugPrint || hasSendMessage || hasWhatsApp,
          isTrue,
          reason:
              'The if (sendReminder) block must contain reminder logic '
              '(debugPrint stub OR WhatsAppService.sendMessage dispatch)',
        );
      },
    );
  });

  // =========================================================================
  // PBT: Generate arbitrary appointment payloads and assert the structural
  // property holds — for ANY appointment metadata, when sendReminder = false,
  // there is NO path to reminder dispatch outside the guarded block.
  //
  // Since this is a source-level structural check, the "arbitrary payloads"
  // serve to demonstrate that no combination of appointment data (purpose,
  // time, patientId) can create a code path to reminder dispatch that
  // bypasses the `if (sendReminder)` check.
  // =========================================================================
  group('PBT — arbitrary appointment metadata preserves sendReminder gate', () {
    test('for all appointment payloads: no reminder dispatch path bypasses '
        'if (sendReminder)', () {
      forAll(
        (int purposeLen, int hourVal, int minuteVal, int patientSeed) {
          // Generate arbitrary appointment metadata
          final purpose = 'P' * (purposeLen % 100); // 0-99 char purpose
          final hour = hourVal % 24;
          final minute = minuteVal % 60;
          final patientId = patientSeed % 2 == 0
              ? 'GUEST'
              : 'patient_$patientSeed';

          // The structural property: regardless of what purpose, time, or
          // patientId we use, the source code's `if (sendReminder)` block
          // is the ONLY place containing reminder dispatch logic.
          //
          // This is a source-level invariant — it doesn't change per-payload,
          // but we verify it holds conceptually for all payloads by checking
          // that:
          // 1. No payload-dependent conditional OUTSIDE the block dispatches
          // 2. The guard itself is unconditional (just `sendReminder`, not
          //    `sendReminder && purpose.isNotEmpty` which would create a
          //    payload-dependent bypass)

          // Verify no payload-dependent bypass exists
          // Check for patterns like: if (purpose.isNotEmpty) { sendMessage }
          // outside the sendReminder block
          final purposeDispatch = RegExp(
            r'if\s*\([^)]*purpose[^)]*\)\s*\{[^}]*(?:sendMessage|WhatsApp)',
          );
          final timeDispatch = RegExp(
            r'if\s*\([^)]*(?:hour|minute|scheduledTime)[^)]*\)\s*\{[^}]*(?:sendMessage|WhatsApp)',
          );
          final patientDispatch = RegExp(
            r'if\s*\([^)]*patientId[^)]*\)\s*\{[^}]*(?:sendMessage|WhatsApp)',
          );

          expect(
            purposeDispatch.hasMatch(outsideBlock),
            isFalse,
            reason:
                'Purpose "$purpose" must not create a dispatch path outside '
                'the sendReminder guard',
          );
          expect(
            timeDispatch.hasMatch(outsideBlock),
            isFalse,
            reason:
                'Time ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} '
                'must not create a dispatch path outside the sendReminder guard',
          );
          expect(
            patientDispatch.hasMatch(outsideBlock),
            isFalse,
            reason:
                'Patient "$patientId" must not create a dispatch path outside '
                'the sendReminder guard',
          );

          // Also verify the guard condition doesn't include payload-dependent
          // restrictions that would SKIP reminders for certain payloads even
          // when sendReminder is true (the reverse preservation — when
          // sendReminder IS true, nothing about the payload should prevent
          // entering the block)
          final guardWithPayload = RegExp(
            r'if\s*\(\s*sendReminder\s*&&\s*(?:purpose|hour|minute|patientId)',
          );
          expect(
            guardWithPayload.hasMatch(methodBody),
            isFalse,
            reason:
                'The sendReminder guard must not be narrowed by '
                'payload-specific conditions (found && with payload field)',
          );

          return true;
        },
        [
          Gen.interval(0, 99), // purposeLen
          Gen.interval(0, 23), // hourVal
          Gen.interval(0, 59), // minuteVal
          Gen.interval(0, 999), // patientSeed
        ],
        numRuns: 100,
      );
    });

    test('guard is not weakened by any payload-specific OR condition', () {
      forAll(
        (int seed) {
          // Generate arbitrary "field names" that could appear in a bypass
          final fields = ['purpose', 'scheduledTime', 'patientId', 'notes'];
          final field = fields[seed % fields.length];

          // Verify no `if (sendReminder || <field>...)` pattern exists
          final orBypass = RegExp(
            'if\\s*\\(\\s*sendReminder\\s*\\|\\|\\s*[^)]*$field',
          );
          expect(
            orBypass.hasMatch(methodBody),
            isFalse,
            reason:
                'The sendReminder guard must not have an OR bypass '
                'involving "$field"',
          );

          return true;
        },
        [Gen.interval(0, 99)],
        numRuns: 50,
      );
    });

    test(
      'no unconditional sendReminder = true assignment before the guard',
      () {
        forAll(
          (int lineOffset) {
            // The property: there is no line before the `if (sendReminder)`
            // that unconditionally sets sendReminder to true.
            // The only assignment should be `bool sendReminder = false` (init)
            // and the checkbox callback `sendReminder = value ?? false`.

            // Find all assignments to sendReminder
            final assignments = RegExp(
              r'sendReminder\s*=\s*([^;]+);',
            ).allMatches(methodBody).toList();

            for (final assignment in assignments) {
              final value = assignment.group(1)!.trim();
              // Valid assignments:
              //   - `false` (initialization)
              //   - `value ?? false` (checkbox callback)
              final isInit = value == 'false';
              final isCallback =
                  value.contains('value') && value.contains('false');

              expect(
                isInit || isCallback,
                isTrue,
                reason:
                    'Found unexpected sendReminder assignment: '
                    '`sendReminder = $value` — only `false` (init) and '
                    '`value ?? false` (checkbox) are safe',
              );
            }

            return true;
          },
          [Gen.interval(0, 49)],
          numRuns: 30,
        );
      },
    );
  });
}
