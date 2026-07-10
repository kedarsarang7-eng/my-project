// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: reminders.dispatchStub (Requirement 1.3)
//
// The clinic appointment_screen.dart's _showAddDialog method captures a
// `sendReminder` checkbox but the confirmed path is a `debugPrint` stub.
// No WhatsAppService.sendMessage call is ever made regardless of the
// sendReminder state. The patient receives nothing.
//
// This test asserts the POSITIVE expectation: that the reminder branch
// (`if (sendReminder) { ... }`) references `WhatsAppService` and `sendMessage`.
// On UNFIXED code this FAILS because the block is only a debugPrint stub
// with no real messaging dispatch.
//
// **Validates: Requirements 1.3**
//
// COUNTEREXAMPLE (documented after first run):
// sendReminder=true produced zero WhatsAppService.sendMessage calls; only a
// debugPrint ran. The `if (sendReminder) { ... }` block contains `debugPrint`
// and does NOT reference `WhatsAppService` or `sendMessage`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition 1.3 — reminders.dispatchStub', () {
    late String sourceContent;
    late String reminderBranchBody;

    setUpAll(() {
      // Read the appointment screen source
      final file = File(
        'lib/features/doctor/presentation/screens/appointment_screen.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'appointment_screen.dart must exist',
      );
      sourceContent = file.readAsStringSync();

      // Locate _showAddDialog method
      final methodIdx = sourceContent.indexOf('_showAddDialog');
      expect(
        methodIdx,
        isNot(-1),
        reason: '_showAddDialog must exist in appointment_screen.dart',
      );

      // Find the `if (sendReminder)` block within _showAddDialog
      final reminderIfIdx = sourceContent.indexOf(
        'if (sendReminder)',
        methodIdx,
      );
      expect(
        reminderIfIdx,
        isNot(-1),
        reason: 'if (sendReminder) block must exist in _showAddDialog',
      );

      // Extract the if-block body (find the opening brace, match to closing)
      final blockStart = sourceContent.indexOf('{', reminderIfIdx);
      expect(
        blockStart,
        isNot(-1),
        reason: 'if (sendReminder) must have a body block',
      );

      int depth = 0;
      int blockEnd = -1;
      for (int i = blockStart; i < sourceContent.length; i++) {
        if (sourceContent[i] == '{') depth++;
        if (sourceContent[i] == '}') {
          depth--;
          if (depth == 0) {
            blockEnd = i + 1;
            break;
          }
        }
      }
      expect(
        blockEnd,
        isNot(-1),
        reason:
            'Could not find matching closing brace for if (sendReminder) block',
      );

      reminderBranchBody = sourceContent.substring(blockStart, blockEnd);
    });

    // =========================================================================
    // Sub-Test 1: The reminder branch must reference WhatsAppService.
    // On UNFIXED code this FAILS — the branch is a debugPrint stub with no
    // WhatsAppService reference at all.
    // =========================================================================
    test('reminder branch references WhatsAppService', () {
      final hasWhatsAppService =
          reminderBranchBody.contains('WhatsAppService') ||
          reminderBranchBody.contains('whatsAppService') ||
          reminderBranchBody.contains('whatsapp_service');

      expect(
        hasWhatsAppService,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): The if (sendReminder) { ... } block does '
            'NOT reference WhatsAppService.\n\n'
            'Current block content is a debugPrint stub:\n'
            '  if (sendReminder) {\n'
            '    debugPrint("Reminder opt-in: patient reminder requested for '
            'appointment \${appt.id} at \$scheduledTime — backend dispatch '
            'not yet wired");\n'
            '  }\n\n'
            'sendReminder=true produces zero WhatsAppService.sendMessage calls; '
            'only a debugPrint ran. The patient receives nothing.\n\n'
            'The fix must replace the debugPrint stub with a real dispatch '
            'via sl<WhatsAppService>().sendMessage(phoneNumber: ..., '
            'message: ...).',
      );
    });

    // =========================================================================
    // Sub-Test 2: The reminder branch must call sendMessage.
    // On UNFIXED code this FAILS — no sendMessage call exists in the block.
    // =========================================================================
    test('reminder branch calls sendMessage', () {
      final hasSendMessage = reminderBranchBody.contains('sendMessage');

      expect(
        hasSendMessage,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): The if (sendReminder) { ... } block does '
            'NOT call sendMessage.\n\n'
            'The marketing-package WhatsAppService exposes:\n'
            '  sendMessage({required String phoneNumber, required String message})\n\n'
            'But the current branch only calls debugPrint(...). No message '
            'is ever dispatched to the patient regardless of the sendReminder '
            'checkbox state.\n\n'
            'The fix must invoke WhatsAppService.sendMessage with the '
            'patient\'s phone number and a reminder message.',
      );
    });

    // =========================================================================
    // Sub-Test 3: The reminder branch must NOT be a debugPrint-only stub.
    // This is framed as an assertion that the block contains REAL dispatch
    // logic (WhatsAppService + sendMessage) AND NOT just debugPrint as the
    // sole action. On UNFIXED code, the block IS debugPrint-only, so we
    // assert the positive expectation that it has real dispatch.
    //
    // We combine the checks: the block must have WhatsAppService AND
    // sendMessage (proven dispatch), confirming it is no longer a stub.
    // =========================================================================
    test('reminder branch is not a debugPrint-only stub', () {
      // Confirm debugPrint IS present (it is in the stub)
      final hasDebugPrint = reminderBranchBody.contains('debugPrint');

      // The block should have REAL dispatch (WhatsAppService + sendMessage)
      // in addition to or instead of debugPrint.
      final hasRealDispatch =
          reminderBranchBody.contains('WhatsAppService') &&
          reminderBranchBody.contains('sendMessage');

      // On unfixed code: hasDebugPrint = true, hasRealDispatch = false
      // This assertion FAILS on unfixed code because the stub has no dispatch.
      expect(
        hasRealDispatch,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): The reminder branch is a debugPrint-only '
            'stub with no real dispatch logic.\n\n'
            'Current state:\n'
            '  - debugPrint present: $hasDebugPrint\n'
            '  - WhatsAppService + sendMessage present: $hasRealDispatch\n\n'
            'The TODO comment says: "backend dispatch out of scope this pass"\n'
            'The patient never receives any appointment reminder. The '
            'sendReminder checkbox is a no-op beyond logging to console.\n\n'
            'The fix must wire sl<WhatsAppService>().sendMessage(...) and '
            'surface delivery failures via SnackBar.',
      );
    });

    // =========================================================================
    // Sub-Test 4: The reminder branch must handle delivery failure with a
    // SnackBar (not swallow silently). On UNFIXED code this FAILS because
    // there is no SnackBar or error handling — just a debugPrint.
    // =========================================================================
    test('reminder branch surfaces delivery failure via SnackBar', () {
      final hasSnackBar =
          reminderBranchBody.contains('SnackBar') ||
          reminderBranchBody.contains('showSnackBar') ||
          reminderBranchBody.contains('ScaffoldMessenger');

      expect(
        hasSnackBar,
        isTrue,
        reason:
            'COUNTEREXAMPLE (1.3): The if (sendReminder) { ... } block has '
            'no SnackBar or ScaffoldMessenger for failure notification.\n\n'
            'When WhatsAppService.sendMessage returns false or the patient '
            'has no phone, the user should see a SnackBar explaining the '
            'reminder could not be sent. Currently, nothing happens — only '
            'debugPrint runs.\n\n'
            'The fix must add SnackBar notifications for:\n'
            '  1. sendMessage returns false (dispatch failed)\n'
            '  2. Patient has no phone number on file',
      );
    });
  });
}
