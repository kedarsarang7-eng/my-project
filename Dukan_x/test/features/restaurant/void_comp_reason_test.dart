// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Bug Condition: When an order is voided or comped, no reason is captured or
// audited beyond the generic `cancelled` status — no void/comp reason tracking.
//
// **Validates: Requirements 2.25**
//
// Run: flutter test test/features/restaurant/void_comp_reason_test.dart
library;

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Files in the restaurant cancel/void flow.
const String kKdsPath =
    'lib/features/restaurant/presentation/screens/kitchen_display_screen.dart';
const String kTableOpsPath =
    'lib/features/restaurant/presentation/screens/restaurant_table_ops_screen.dart';
const String kOrderRepoPath =
    'lib/features/restaurant/data/repositories/food_order_repository.dart';

void main() {
  late String kdsSource;
  late String tableOpsSource;
  late String orderRepoSource;

  setUpAll(() {
    final kdsFile = File(kKdsPath);
    expect(kdsFile.existsSync(), isTrue, reason: 'KDS screen must exist');
    kdsSource = kdsFile.readAsStringSync();

    final tableOpsFile = File(kTableOpsPath);
    expect(
      tableOpsFile.existsSync(),
      isTrue,
      reason: 'Table ops screen must exist',
    );
    tableOpsSource = tableOpsFile.readAsStringSync();

    final orderRepoFile = File(kOrderRepoPath);
    expect(
      orderRepoFile.existsSync(),
      isTrue,
      reason: 'Order repository must exist',
    );
    orderRepoSource = orderRepoFile.readAsStringSync();
  });

  // ===========================================================================
  // GROUP 1: Reason-capture UI must exist in the cancel/void flow.
  // On UNFIXED code: FAILS — no reason dialog exists.
  // ===========================================================================
  group('Void/comp reason UI (Req 2.25)', () {
    test('KDS has cancel action with reason capture', () {
      // KDS must have a cancel/void action AND capture a reason
      final hasCancelAction =
          kdsSource.contains('cancelOrder') ||
          kdsSource.contains('_cancelOrder') ||
          kdsSource.contains('_voidOrder');

      final hasReasonCapture =
          kdsSource.contains('cancellationReason') ||
          kdsSource.contains('cancelReason') ||
          kdsSource.contains('voidReason');

      expect(
        hasCancelAction && hasReasonCapture,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.25): KDS has NO cancel/void action '
            'that captures a reason. Only accept/ready/served exist.',
      );
    });

    test('Table ops cancel shows reason dialog', () {
      // Table ops has 'cancelled' status but no reason dialog
      final hasCancel = tableOpsSource.contains("'cancelled'");
      final hasReasonDialog =
          tableOpsSource.contains('cancellationReason') ||
          tableOpsSource.contains('cancelReason') ||
          tableOpsSource.contains('voidReason');

      expect(
        hasCancel && hasReasonDialog,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.25): Table ops sets status to '
            '"cancelled" directly without any reason-capture dialog.',
      );
    });

    test('cancelOrder called with reason from UI', () {
      // Check restaurant presentation files for cancelOrder with reason
      final presDir = Directory('lib/features/restaurant/presentation');
      expect(presDir.existsSync(), isTrue);

      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final hasReasonCall = dartFiles.any((file) {
        final src = file.readAsStringSync();
        return src.contains('cancelOrder') &&
            src.contains('reason:') &&
            !src.contains('reason: null');
      });

      expect(
        hasReasonCall,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.25): No restaurant UI screen calls '
            'cancelOrder with a non-null reason parameter.',
      );
    });
  });

  // ===========================================================================
  // GROUP 2: Local Drift write must persist cancellationReason.
  // On UNFIXED code: FAILS — local write misses cancellationReason.
  // ===========================================================================
  group('cancelOrder local persistence (Req 2.25)', () {
    test('Drift write includes cancellationReason', () {
      // cancelOrder writes FoodOrdersCompanion with only:
      //   orderStatus, updatedAt, isSynced
      // It does NOT persist cancelledAt or cancellationReason locally.
      final start = orderRepoSource.indexOf(
        'Future<RepositoryResult<void>> cancelOrder',
      );
      expect(start, isNot(-1), reason: 'cancelOrder must exist');

      final end = orderRepoSource.indexOf("}, 'cancelOrder')", start);
      final methodBody = orderRepoSource.substring(start, end + 20);

      // Find the FoodOrdersCompanion write block
      final compStart = methodBody.indexOf('FoodOrdersCompanion(');
      expect(compStart, isNot(-1));

      // Get companion fields (up to closing paren of the companion)
      final afterComp = methodBody.substring(compStart);
      final compEnd = afterComp.indexOf('),');
      final companionBlock = afterComp.substring(0, compEnd + 1);

      final persistsReason = companionBlock.contains('cancellationReason');

      expect(
        persistsReason,
        isTrue,
        reason:
            'COUNTEREXAMPLE (Req 2.25): cancelOrder FoodOrdersCompanion '
            'only writes {orderStatus, updatedAt, isSynced}. '
            'cancellationReason is only in the sync payload, not local DB.',
      );
    });
  });

  // ===========================================================================
  // GROUP 3: PBT — structural property test.
  // On UNFIXED code: FAILS — no UI path sets a reason.
  // ===========================================================================
  group('PBT: Reason persists (Req 2.25)', () {
    test('PBT: reason-capture path exists for any reason', () {
      final presDir = Directory('lib/features/restaurant/presentation');
      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final allSource = dartFiles.map((f) => f.readAsStringSync()).join('\n');

      final held = forAll(
        (int reasonLen) {
          // For ANY non-empty reason (length 1+), the system must
          // structurally support capturing and persisting it:
          //   1. Calls cancelOrder from a UI context
          //   2. Passes a reason parameter
          //   3. Has a text input for the reason
          final callsCancel = allSource.contains('cancelOrder');
          final passesReason =
              allSource.contains('cancelOrder') &&
              allSource.contains('reason:');
          final hasInput =
              allSource.contains('cancellationReason') ||
              allSource.contains('voidReason') ||
              allSource.contains('cancelReason');

          return callsCancel && passesReason && hasInput;
        },
        [Gen.interval(1, 100)],
        numRuns: 50,
      );

      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE (PBT, Req 2.25): No restaurant UI calls '
            'cancelOrder with a reason. The reason parameter exists in '
            'the repository but is never used from any screen.',
      );
    });
  });
}
