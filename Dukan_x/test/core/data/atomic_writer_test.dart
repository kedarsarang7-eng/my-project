// Reproduction tests for D4 (data-flow / persistence defects).
//
// These tests fail on F (the unfixed codebase had no central atomic
// write helper, so multi-step writes hand-rolled rollback ladders that
// drifted out of sync — see `delivery_challan_service.dart` for the
// canonical hand-rolled example) and pass on F' (this file exercises
// `AtomicWriter.run` from `lib/core/data/atomic_writer.dart` which is
// introduced as the D4 fix per `design.md` § "D4 Data-flow fixes").
//
// Per clause 2.19 every D4 inventory entry ships with a reproduction
// test. The single inventory row is `D4-MANUAL-runtime-investigation`,
// covering the cross-cutting "atomic local + remote + provider
// invalidation, with rollback on partial failure" pattern (clauses
// 2.7, 2.8). The cases below exercise that pattern directly.

import 'package:dukanx/core/data/atomic_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtomicWriter.run', () {
    test(
      'happy path runs local, remote, then invalidate exactly once',
      () async {
        final order = <String>[];

        final result = await AtomicWriter.run<int>(
          label: 'test.happy',
          local: () async {
            order.add('local');
            return 42;
          },
          remote: () async => order.add('remote'),
          invalidate: () => order.add('invalidate'),
        );

        expect(result, 42);
        expect(order, ['local', 'remote', 'invalidate']);
      },
    );

    test(
      'local failure short-circuits; remote and invalidate never run',
      () async {
        var remoteCalls = 0;
        var invalidateCalls = 0;

        AtomicWriteFailure? caught;
        try {
          await AtomicWriter.run<void>(
            label: 'test.local_fail',
            local: () async => throw StateError('disk full'),
            remote: () async => remoteCalls++,
            invalidate: () => invalidateCalls++,
          );
        } on AtomicWriteFailure catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(caught!.step, AtomicWriteStep.local);
        expect(caught.partial, isFalse);
        expect(remoteCalls, 0);
        expect(invalidateCalls, 0);
      },
    );

    test(
      'remote failure rolls back local via compensateLocal; invalidate never runs',
      () async {
        var compensateCalls = 0;
        var invalidateCalls = 0;

        AtomicWriteFailure? caught;
        try {
          await AtomicWriter.run<void>(
            label: 'test.remote_fail',
            local: () async {},
            remote: () async => throw StateError('http 500'),
            compensateLocal: () async => compensateCalls++,
            invalidate: () => invalidateCalls++,
          );
        } on AtomicWriteFailure catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(caught!.step, AtomicWriteStep.remote);
        expect(
          caught.partial,
          isFalse,
          reason: 'compensateLocal succeeded so the system is consistent',
        );
        expect(compensateCalls, 1);
        expect(invalidateCalls, 0);
      },
    );

    test('remote failure with no compensator returns partial=true', () async {
      AtomicWriteFailure? caught;
      try {
        await AtomicWriter.run<void>(
          label: 'test.remote_no_comp',
          local: () async {},
          remote: () async => throw StateError('http 500'),
          invalidate: () {},
        );
      } on AtomicWriteFailure catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.step, AtomicWriteStep.remote);
      expect(
        caught.partial,
        isTrue,
        reason: 'no compensateLocal supplied — local write is dirty',
      );
    });

    test('compensateLocal failure escalates to partial=true', () async {
      AtomicWriteFailure? caught;
      try {
        await AtomicWriter.run<void>(
          label: 'test.comp_fail',
          local: () async {},
          remote: () async => throw StateError('http 500'),
          compensateLocal: () async => throw StateError('rollback failed'),
          invalidate: () {},
        );
      } on AtomicWriteFailure catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(
        caught!.step,
        AtomicWriteStep.remote,
        reason:
            'caller still sees the original cause; compensator failure'
            ' escalates partial flag',
      );
      expect(caught.partial, isTrue);
    });

    test(
      'invalidate failure surfaces but does not roll back committed writes',
      () async {
        var compensateCalls = 0;

        AtomicWriteFailure? caught;
        try {
          await AtomicWriter.run<void>(
            label: 'test.invalidate_fail',
            local: () async {},
            remote: () async {},
            compensateLocal: () async => compensateCalls++,
            invalidate: () => throw StateError('provider missing'),
          );
        } on AtomicWriteFailure catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(caught!.step, AtomicWriteStep.invalidate);
        expect(
          caught.partial,
          isFalse,
          reason: 'data is consistent; only the cache invalidation failed',
        );
        expect(
          compensateCalls,
          0,
          reason:
              'committed writes are NOT rolled back for an invalidation '
              'glitch — caller can force a refresh later',
        );
      },
    );
  });
}
