/// OperationState Widget Tests — Task 16.3
///
/// Tests cover:
/// 1. All 10 operation states are distinct and carry correct metadata
/// 2. Recovery actions are typed and context-aware
/// 3. GR-3 enforcement: no false success without AuthoritativeConfirmation
/// 4. Mappers correctly bridge ConsistencyOutcome, CommerceOutcome,
///    ScreenState, and KpiState
/// 5. OperationStateCard renders correct visuals per state
/// 6. OperationProgressBanner announces to screen readers
///
/// Requirements validated: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/billing/mobile_sale_consistency_orchestrator.dart';
import 'package:dukanx/features/mobile_shop/kpi/kpi_state.dart';
import 'package:dukanx/features/mobile_shop/models/confirmation_models.dart';
import 'package:dukanx/features/mobile_shop/screens/commerce/mobile_commerce_service.dart';
import 'package:dukanx/features/mobile_shop/screens/screen_state.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_state.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_state_card.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_state_mappers.dart';
import 'package:dukanx/features/mobile_shop/widgets/operation_state/operation_progress_banner.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. OPERATION STATE SEALED CLASS — All 10 states are distinct
  // ═══════════════════════════════════════════════════════════════════════════

  group('OperationState hierarchy', () {
    test('loading carries optional progress and timeout info', () {
      const state = OperationLoading(message: 'Fetching data…', progress: 0.5);
      expect(state.label, 'Fetching data…');
      expect(state.isTerminal, isFalse);
      expect(state.recoveryActions, isEmpty);
      expect(state.accessibilityAnnouncement, contains('50 percent'));
    });

    test('empty is terminal with appropriate message', () {
      const state = OperationEmpty(message: 'No devices found');
      expect(state.label, 'No devices found');
      expect(state.isTerminal, isTrue);
      expect(state.recoveryActions, isEmpty);
    });

    test('disabled carries reason and recovery for sign-in', () {
      const state = OperationDisabled(
        reason: 'Session required',
        disabledReason: DisabledReason.signInRequired,
      );
      expect(state.label, 'Session required');
      expect(state.isTerminal, isTrue);
      expect(state.recoveryActions.length, 1);
      expect(state.recoveryActions.first.type, RecoveryActionType.signIn);
    });

    test('pending is not terminal and carries operation ID', () {
      const state = OperationPending(
        message: 'Syncing…',
        operationId: 'op-123',
        kind: PendingKind.localQueued,
      );
      expect(state.label, 'Pending Sync');
      expect(state.isTerminal, isFalse);
      expect(state.accessibilityAnnouncement, contains('Pending Sync'));
    });

    test('stale carries last-confirmed timestamp', () {
      final now = DateTime.now();
      final state = OperationStale(
        message: 'Outdated',
        lastConfirmedAt: now,
        refreshStatus: StaleRefreshStatus.retryPending,
      );
      expect(state.label, 'Stale');
      expect(state.isTerminal, isFalse);
      expect(state.accessibilityAnnouncement, contains('retryPending'));
    });

    test('conflicted carries correlation and view-conflicts action', () {
      const state = OperationConflicted(
        message: 'Version mismatch',
        correlationId: 'corr-456',
        operationId: 'op-789',
      );
      expect(state.label, 'Conflict');
      expect(state.isTerminal, isFalse);
      expect(state.recoveryActions.length, 2);
      expect(state.recoveryActions[0].type, RecoveryActionType.viewConflicts);
      expect(state.recoveryActions[1].type, RecoveryActionType.contactSupport);
    });

    test('unavailable carries support contact when correlation present', () {
      const state = OperationUnavailable(
        message: 'Server down',
        correlationId: 'corr-xyz',
      );
      expect(state.label, 'Unavailable');
      expect(state.isTerminal, isFalse);
      expect(state.recoveryActions.length, 1);
      expect(state.recoveryActions.first.correlationId, 'corr-xyz');
    });

    test('failed with retryable exposes retry action', () {
      const state = OperationFailed(
        message: 'Network timeout',
        retryable: true,
        operationId: 'op-retry',
        correlationId: 'corr-net',
      );
      expect(state.label, 'Failed');
      expect(state.isTerminal, isFalse);
      expect(state.recoveryActions.length, 1);
      expect(state.recoveryActions.first.type, RecoveryActionType.retry);
      expect(state.recoveryActions.first.operationId, 'op-retry');
    });

    test('failed non-retryable exposes support action', () {
      const state = OperationFailed(
        message: 'Permanent error',
        retryable: false,
        correlationId: 'corr-perm',
      );
      expect(state.isTerminal, isTrue);
      expect(state.recoveryActions.length, 1);
      expect(
        state.recoveryActions.first.type,
        RecoveryActionType.contactSupport,
      );
    });

    test('complete requires confirmedAt (GR-3 enforcement)', () {
      final confirmed = DateTime(2025, 1, 15, 10, 30);
      final state = OperationComplete(
        message: 'Sale confirmed',
        confirmedAt: confirmed,
        operationId: 'op-done',
      );
      expect(state.label, 'Complete');
      expect(state.isTerminal, isTrue);
      expect(state.recoveryActions, isEmpty);
      expect(state.accessibilityAnnouncement, contains('2025'));
    });

    test('signedOut is terminal and offers sign-in recovery', () {
      const state = OperationSignedOut();
      expect(state.label, 'Signed Out');
      expect(state.isTerminal, isTrue);
      expect(state.recoveryActions.length, 1);
      expect(state.recoveryActions.first.type, RecoveryActionType.signIn);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. GR-3 — No false success
  // ═══════════════════════════════════════════════════════════════════════════

  group('GR-3: No false success', () {
    test('committed without confirmation maps to pending, not complete', () {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.committed,
        operationId: 'op-no-confirm',
        // confirmation is NULL — must NOT show as complete
      );

      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationPending>());
      expect(mapped, isNot(isA<OperationComplete>()));
    });

    test('committed WITH confirmation maps to complete', () {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.committed,
        operationId: 'op-confirmed',
        confirmation: const AuthoritativeConfirmation(
          authority: ConfirmationAuthority.awsDynamoDb,
          state: ConfirmationState.committed,
          confirmedAt: '2025-01-15T10:30:00Z',
          dataModelVersion: 1,
          entityVersions: {'imei-001': 2},
        ),
      );

      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationComplete>());
      final complete = mapped as OperationComplete;
      expect(complete.operationId, 'op-confirmed');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MAPPERS — ConsistencyOutcome
  // ═══════════════════════════════════════════════════════════════════════════

  group('mapConsistencyOutcome', () {
    test('localPending maps to OperationPending(localQueued)', () {
      const outcome = ConsistencyOutcome(
        state: SaleOutcomeState.localPending,
        operationId: 'op-1',
      );
      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationPending>());
      expect((mapped as OperationPending).kind, PendingKind.localQueued);
    });

    test('offlineQueued maps to OperationPending(localQueued)', () {
      const outcome = ConsistencyOutcome(
        state: SaleOutcomeState.offlineQueued,
        operationId: 'op-2',
      );
      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationPending>());
    });

    test('acceptedPending maps to OperationPending(reconciling)', () {
      const outcome = ConsistencyOutcome(
        state: SaleOutcomeState.acceptedPending,
        operationId: 'op-3',
      );
      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationPending>());
      expect((mapped as OperationPending).kind, PendingKind.reconciling);
    });

    test('conflict maps to OperationConflicted', () {
      const outcome = ConsistencyOutcome(
        state: SaleOutcomeState.conflict,
        operationId: 'op-4',
        errorMessage: 'IMEI already sold',
      );
      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationConflicted>());
      expect((mapped as OperationConflicted).message, 'IMEI already sold');
    });

    test('rejected maps to OperationFailed', () {
      const outcome = ConsistencyOutcome(
        state: SaleOutcomeState.rejected,
        operationId: 'op-5',
        errorCode: 'VALIDATION_FAILED',
        errorMessage: 'IMEI invalid',
        retryable: false,
      );
      final mapped = mapConsistencyOutcome(outcome);
      expect(mapped, isA<OperationFailed>());
      final failed = mapped as OperationFailed;
      expect(failed.errorCode, 'VALIDATION_FAILED');
      expect(failed.retryable, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. MAPPERS — CommerceOutcome
  // ═══════════════════════════════════════════════════════════════════════════

  group('mapCommerceOutcome', () {
    test('success maps to OperationComplete', () {
      const outcome = CommerceOutcome(
        state: CommerceOutcomeState.success,
        operationId: 'op-c1',
      );
      final mapped = mapCommerceOutcome(outcome);
      expect(mapped, isA<OperationComplete>());
    });

    test('featureDisabled maps to OperationDisabled', () {
      const outcome = CommerceOutcome(
        state: CommerceOutcomeState.featureDisabled,
        operationId: '',
        errorMessage: 'OCR not enabled',
      );
      final mapped = mapCommerceOutcome(outcome);
      expect(mapped, isA<OperationDisabled>());
    });

    test('offlinePreserved maps to OperationPending(localQueued)', () {
      const outcome = CommerceOutcome(
        state: CommerceOutcomeState.offlinePreserved,
        operationId: 'op-off',
      );
      final mapped = mapCommerceOutcome(outcome);
      expect(mapped, isA<OperationPending>());
      expect((mapped as OperationPending).kind, PendingKind.localQueued);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. MAPPERS — ScreenState
  // ═══════════════════════════════════════════════════════════════════════════

  group('mapScreenState', () {
    test('ScreenLoading maps to OperationLoading', () {
      const state = ScreenLoading<String>();
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationLoading>());
    });

    test('ScreenEmpty maps to OperationEmpty', () {
      const state = ScreenEmpty<String>(message: 'No results');
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationEmpty>());
      expect((mapped as OperationEmpty).message, 'No results');
    });

    test('ScreenError retryable maps to OperationFailed retryable', () {
      const state = ScreenError<String>(
        errorCode: 'NET_ERR',
        message: 'Network',
        isRetryable: true,
        correlationId: 'corr-1',
      );
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationFailed>());
      final failed = mapped as OperationFailed;
      expect(failed.retryable, isTrue);
      expect(failed.correlationId, 'corr-1');
    });

    test('ScreenSessionLost maps to OperationSignedOut', () {
      const state = ScreenSessionLost<String>();
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationSignedOut>());
    });

    test('ScreenData stale maps to OperationStale', () {
      final state = ScreenData<String>(
        data: 'some data',
        isStale: true,
        lastRefreshed: DateTime(2025, 1, 10),
      );
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationStale>());
    });

    test('ScreenData fresh maps to OperationComplete', () {
      final state = ScreenData<String>(
        data: 'some data',
        isStale: false,
        lastRefreshed: DateTime(2025, 1, 15),
      );
      final mapped = mapScreenState(state);
      expect(mapped, isA<OperationComplete>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. MAPPERS — KpiState
  // ═══════════════════════════════════════════════════════════════════════════

  group('mapKpiState', () {
    test('KpiLoading maps to OperationLoading', () {
      final mapped = mapKpiState(const KpiLoading<int>());
      expect(mapped, isA<OperationLoading>());
    });

    test('KpiCurrent maps to OperationComplete', () {
      final watermark = KpiWatermark(
        dataVersion: 3,
        confirmedAt: DateTime(2025, 1, 15),
        refreshedAt: DateTime(2025, 1, 15),
        dataModelVersion: 1,
      );
      final state = KpiCurrent<int>(value: 42, watermark: watermark);
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationComplete>());
    });

    test('KpiEmpty maps to OperationEmpty', () {
      final watermark = KpiWatermark(
        dataVersion: 1,
        confirmedAt: DateTime(2025, 1, 10),
        refreshedAt: DateTime(2025, 1, 10),
        dataModelVersion: 1,
      );
      final state = KpiEmpty<int>(watermark: watermark, showZero: true);
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationEmpty>());
      expect((mapped as OperationEmpty).showZero, isTrue);
    });

    test('KpiStale maps to OperationStale', () {
      final watermark = KpiWatermark(
        dataVersion: 2,
        confirmedAt: DateTime(2025, 1, 1),
        refreshedAt: DateTime(2025, 1, 1),
        dataModelVersion: 1,
      );
      final state = KpiStale<int>(
        lastValue: 10,
        lastWatermark: watermark,
        refreshStatus: KpiRefreshStatus.refreshing,
      );
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationStale>());
    });

    test('KpiUnavailable maps to OperationUnavailable', () {
      const state = KpiUnavailable<int>(reason: 'Feature disabled');
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationUnavailable>());
    });

    test('KpiError network maps to retryable OperationFailed', () {
      const state = KpiError<int>(
        error: KpiErrorInfo(
          kind: KpiErrorKind.network,
          message: 'Timeout',
          correlationId: 'c-1',
        ),
      );
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationFailed>());
      expect((mapped as OperationFailed).retryable, isTrue);
    });

    test('KpiError non-network maps to non-retryable OperationFailed', () {
      const state = KpiError<int>(
        error: KpiErrorInfo(
          kind: KpiErrorKind.authorization,
          message: 'Permission denied',
        ),
      );
      final mapped = mapKpiState(state);
      expect(mapped, isA<OperationFailed>());
      expect((mapped as OperationFailed).retryable, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. WIDGET — OperationStateCard renders each state
  // ═══════════════════════════════════════════════════════════════════════════

  group('OperationStateCard widget', () {
    Widget buildCard(OperationState state, {bool compact = false}) {
      return MaterialApp(
        home: Scaffold(
          body: OperationStateCard(state: state, compact: compact),
        ),
      );
    }

    testWidgets('renders loading with progress indicator', (tester) async {
      await tester.pumpWidget(
        buildCard(const OperationLoading(message: 'Fetching…')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state with inbox icon', (tester) async {
      await tester.pumpWidget(
        buildCard(const OperationEmpty(message: 'No devices')),
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.textContaining('No devices'), findsWidgets);
    });

    testWidgets('renders complete state with check icon', (tester) async {
      await tester.pumpWidget(
        buildCard(
          OperationComplete(
            message: 'Done',
            confirmedAt: DateTime(2025, 1, 15),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('renders failed state with error icon', (tester) async {
      await tester.pumpWidget(
        buildCard(
          const OperationFailed(message: 'Network error', retryable: true),
        ),
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('renders signedOut state with lock icon', (tester) async {
      await tester.pumpWidget(buildCard(const OperationSignedOut()));
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('compact mode renders inline row', (tester) async {
      await tester.pumpWidget(
        buildCard(const OperationLoading(), compact: true),
      );
      // In compact mode, the progress indicator is 16x16
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 2);
    });

    testWidgets('exposes liveRegion semantics', (tester) async {
      await tester.pumpWidget(
        buildCard(const OperationFailed(message: 'Error')),
      );
      // Verify that the OperationStateCard wraps content in a Semantics
      // widget — the widget tree should have our Semantics with label
      expect(find.bySemanticsLabel(RegExp('Operation failed')), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. WIDGET — OperationProgressBanner
  // ═══════════════════════════════════════════════════════════════════════════

  group('OperationProgressBanner', () {
    testWidgets('shows banner for non-dismissed state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationProgressBanner(
              state: const OperationLoading(message: 'Loading…'),
            ),
          ),
        ),
      );
      expect(find.byType(OperationStateCard), findsOneWidget);
    });

    testWidgets('hides when visible is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationProgressBanner(
              state: const OperationLoading(),
              visible: false,
            ),
          ),
        ),
      );
      expect(find.byType(OperationStateCard), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. WIDGET — OperationBusyGuard
  // ═══════════════════════════════════════════════════════════════════════════

  group('OperationBusyGuard', () {
    testWidgets('renders child normally when not busy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationBusyGuard(
              isBusy: false,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Submit'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Submit'), findsOneWidget);
      // Button should be tappable
      await tester.tap(find.text('Submit'));
    });

    testWidgets('disables child and shows indicator when busy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationBusyGuard(
              isBusy: true,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Submit'),
              ),
            ),
          ),
        ),
      );
      // Should find IgnorePointer with ignoring=true (our guard)
      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.byType(IgnorePointer),
      );
      final hasBlockingPointer = ignorePointers.any((ip) => ip.ignoring);
      expect(hasBlockingPointer, isTrue);
      // Should find a loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. MAPPER — Confirmation status string
  // ═══════════════════════════════════════════════════════════════════════════

  group('mapConfirmationStatus', () {
    test('null maps to loading', () {
      final result = mapConfirmationStatus(null);
      expect(result, isA<OperationLoading>());
    });

    test('"serverConfirmed" maps to complete', () {
      final result = mapConfirmationStatus('serverConfirmed');
      expect(result, isA<OperationComplete>());
    });

    test('"conflict" maps to conflicted', () {
      final result = mapConfirmationStatus('conflict');
      expect(result, isA<OperationConflicted>());
    });

    test('"pending" maps to pending', () {
      final result = mapConfirmationStatus('pending');
      expect(result, isA<OperationPending>());
    });

    test('"rejected" maps to failed', () {
      final result = mapConfirmationStatus('rejected');
      expect(result, isA<OperationFailed>());
    });

    test('unknown string maps to loading', () {
      final result = mapConfirmationStatus('unknown_state');
      expect(result, isA<OperationLoading>());
    });
  });
}
