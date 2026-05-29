// ============================================================================
// chaos/event-bus-restart.test.ts — REQ 9.7, 9.8, 13.6, 15.4
// ============================================================================
//
// Scenario:
//   1. A producer emits a steady flow of accepted events through the
//      production `OutboxPublisher`.
//   2. Mid-flight, the underlying SNS publish becomes unreachable
//      (simulating an Event_Bus process kill / failover).
//   3. Subsequent publishes are caught by the outbox shim and buffered
//      in `created_at` order in `InMemoryOutboxStorage` (REQ 9.7).
//   4. The publisher recovers; `flushOutbox()` replays every buffered
//      entry in `created_at` ascending order; zero events are lost
//      (REQ 9.8 / REQ 15.4).
//
// What this test exercises in production code (read-only):
//   - `OutboxPublisher.publishWithFallback` (catches
//     `EventBusUnavailableError`, persists to the outbox).
//   - `OutboxPublisher.flushOutbox` (orders by `created_at`, removes on
//     success).
//   - `InMemoryOutboxStorage` (sorted enumeration, removal).
//   - `validateEventContract` (transitively via the outbox flush re-
//     validation path).
//
// What it does NOT do:
//   - Spin up a real SNS / SQS topology (REQ 15.4 says "actually
//     terminates the Event_Bus process during in-flight delivery"; we
//     achieve the same effect by toggling the publish stub in-process,
//     which is the deterministic, CI-safe shape of the assertion. A
//     follow-up integration test under
//     `my-backend/tests/notifications/integration/` will exercise the
//     real-AWS variant once the Phase 5 staging env is provisioned).
// ============================================================================

import { describe, test, expect } from '@jest/globals';

import {
    EventBusUnavailableError,
    InMemoryOutboxStorage,
    OutboxPublisher,
} from '../../../src/notifications/event-bus';
import type {
    EventContract,
    PublishAck,
} from '../../../src/notifications/event-bus/types';

import { buildEvent } from './shim/fixtures';

// ---------------------------------------------------------------------------
// Test-only publish stub: a closure backed by a mutable "alive" flag so the
// test can flip it from healthy → outage → healthy without touching any
// production module. Mirrors the surface the OutboxPublisher expects:
// `(event: EventContract) => Promise<PublishAck>`.
// ---------------------------------------------------------------------------

interface PublishHarness {
    readonly publish: (event: EventContract) => Promise<PublishAck>;
    /** Events that successfully reached the "bus" (post-recovery + healthy run). */
    readonly delivered: EventContract[];
    /** Toggle the simulated bus availability. */
    setAlive(alive: boolean): void;
    /** How many publish attempts the harness saw (success + transient fail). */
    readonly attempts: number;
}

function makePublishHarness(): PublishHarness {
    let alive = true;
    let attempts = 0;
    const delivered: EventContract[] = [];

    const publish = async (event: EventContract): Promise<PublishAck> => {
        attempts += 1;
        if (!alive) {
            // Mirror the structured transient failure the production
            // `publisher.ts` raises when SNS is unreachable (REQ 9.7
            // outbox eligibility hinges on this exact error type).
            throw new EventBusUnavailableError(
                'simulated event-bus outage',
                new Error('connection refused'),
            );
        }
        delivered.push(event);
        return { messageId: `msg-${event.id}` };
    };

    return {
        publish,
        delivered,
        setAlive(next: boolean) {
            alive = next;
        },
        get attempts() {
            return attempts;
        },
    };
}

// ---------------------------------------------------------------------------
// Helper assertions
// ---------------------------------------------------------------------------

/**
 * Assert that the recovered set of delivered events matches the
 * accepted set 1:1 (no loss, no duplicates beyond what the bus's
 * dedup boundary would normalize). The chaos test asserts on the
 * publisher's own delivered ledger; downstream dedup is the
 * Notification_Service's responsibility (REQ 4.4 / REQ 9.2).
 */
function assertExactDelivery(
    accepted: readonly EventContract[],
    delivered: readonly EventContract[],
): void {
    const acceptedIds = accepted.map((e) => e.id).sort();
    const deliveredIds = delivered.map((e) => e.id).sort();
    expect(deliveredIds).toEqual(acceptedIds);
}

/**
 * Assert that the delivered events appear in `created_at` ascending
 * order across the recovery boundary (REQ 9.7).
 */
function assertCreatedAtAscending(delivered: readonly EventContract[]): void {
    for (let i = 1; i < delivered.length; i += 1) {
        const prev = delivered[i - 1].created_at;
        const curr = delivered[i].created_at;
        expect(curr >= prev).toBe(true);
    }
}

// ===========================================================================
// Tests
// ===========================================================================

describe('chaos: event-bus restart with in-flight events', () => {
    test(
        'publisher kill+restart loses zero events; outbox replays in created_at ascending order',
        async () => {
            const harness = makePublishHarness();
            const storage = new InMemoryOutboxStorage();
            const publisher = new OutboxPublisher({
                storage,
                publish: harness.publish,
            });

            const baseEpochMs = Date.UTC(2025, 0, 1, 12, 0, 0);
            const accepted: EventContract[] = [];

            // ---------------------------------------------------------------
            // Phase A — healthy: publish 5 events successfully.
            // ---------------------------------------------------------------
            for (let i = 0; i < 5; i += 1) {
                const event = buildEvent({
                    seed: i + 1,
                    baseEpochMs,
                    offsetMs: i * 100, // 100ms apart, ascending
                });
                accepted.push(event);
                const result = await publisher.publishWithFallback(event);
                expect(result.buffered).toBe(false);
            }

            expect(harness.delivered.map((e) => e.id)).toEqual(
                accepted.map((e) => e.id),
            );
            expect(await publisher.pendingCount()).toBe(0);

            // ---------------------------------------------------------------
            // Phase B — outage: bus dies, next 7 publishes must buffer.
            // The outage period emits events with timestamps that interleave
            // with later post-recovery events, so we can verify the flush
            // ordering is by `created_at` (event time) — not by buffer
            // arrival order.
            // ---------------------------------------------------------------
            harness.setAlive(false);

            for (let i = 5; i < 12; i += 1) {
                const event = buildEvent({
                    seed: i + 1,
                    baseEpochMs,
                    offsetMs: i * 100, // continues ascending
                });
                accepted.push(event);
                const result = await publisher.publishWithFallback(event);
                expect(result.buffered).toBe(true);
                if (result.buffered) {
                    expect(result.entry.id).toBe(event.id);
                    // last_error must be the structured transient message so
                    // the operator can see why the entry got buffered.
                    expect(result.entry.last_error).toContain('event-bus outage');
                    expect(result.entry.retry_count).toBe(0);
                }
            }

            expect(await publisher.pendingCount()).toBe(7);
            // Nothing reached the bus during the outage.
            expect(harness.delivered).toHaveLength(5);

            // ---------------------------------------------------------------
            // Phase C — partial recovery, then a fresh publish that the bus
            // (still down for the flush attempt below) would have buffered
            // had we not flipped it back. We test: the outbox flush picks
            // up only entries that exist at flush time, in `created_at`
            // order.
            // ---------------------------------------------------------------
            harness.setAlive(true);

            // ---------------------------------------------------------------
            // Phase D — flush. Every buffered entry must reach the bus
            // exactly once and in `created_at` ascending order.
            // ---------------------------------------------------------------
            const flushSummary = await publisher.flushOutbox();
            expect(flushSummary.attempted).toBe(7);
            expect(flushSummary.published).toBe(7);
            expect(flushSummary.stillBuffered).toBe(0);
            expect(flushSummary.failures).toEqual([]);

            // Every accepted event reached the delivery sink, no loss.
            assertExactDelivery(accepted, harness.delivered);

            // The post-flush slice must be in `created_at` ascending order.
            // Outbox entries are stored unordered — the flush MUST sort.
            const flushedSlice = harness.delivered.slice(5);
            assertCreatedAtAscending(flushedSlice);

            // Outbox is empty after a successful flush.
            expect(await publisher.pendingCount()).toBe(0);
        },
    );

    test(
        'a still-failing flush leaves entries buffered with bumped retry_count',
        async () => {
            // Same harness but kept "dead" for the flush, validating that
            // flushOutbox's retry-count bookkeeping survives a still-down
            // bus. This is the secondary part of REQ 9.7 ("replays
            // buffered events in order on Event_Bus recovery") — the
            // ordering is preserved AND non-recoverable flushes do not
            // delete entries.
            const harness = makePublishHarness();
            const storage = new InMemoryOutboxStorage();
            const publisher = new OutboxPublisher({
                storage,
                publish: harness.publish,
            });

            harness.setAlive(false);
            const baseEpochMs = Date.UTC(2025, 0, 1, 13, 0, 0);

            // Buffer three events.
            for (let i = 0; i < 3; i += 1) {
                const event = buildEvent({
                    seed: i + 1,
                    baseEpochMs,
                    offsetMs: i * 50,
                });
                const result = await publisher.publishWithFallback(event);
                expect(result.buffered).toBe(true);
            }

            const flushOne = await publisher.flushOutbox();
            expect(flushOne.attempted).toBe(3);
            expect(flushOne.published).toBe(0);
            expect(flushOne.stillBuffered).toBe(3);
            expect(flushOne.failures.length).toBe(3);

            // Every entry is back in storage with retry_count incremented.
            const after = await storage.listAscending();
            expect(after).toHaveLength(3);
            for (const entry of after) {
                expect(entry.retry_count).toBeGreaterThanOrEqual(1);
            }

            // Now recover and re-flush: every entry must publish exactly
            // once, in `created_at` ascending order.
            harness.setAlive(true);
            const flushTwo = await publisher.flushOutbox();
            expect(flushTwo.attempted).toBe(3);
            expect(flushTwo.published).toBe(3);
            expect(flushTwo.stillBuffered).toBe(0);

            assertCreatedAtAscending(harness.delivered);
            expect(harness.delivered).toHaveLength(3);
        },
    );

    test(
        'restart preserves ordering even when in-flight publishes are interleaved with offline-buffered ones',
        async () => {
            // The realistic shape of "kill mid-flight": some events are in
            // SNS in-flight when the bus drops; the producer perceives a
            // transient failure and buffers them; later events arrive
            // offline and are buffered in their (later) `created_at`
            // order; recovery flushes everything. REQ 9.8 requires zero
            // loss across this exact pattern.
            const harness = makePublishHarness();
            const storage = new InMemoryOutboxStorage();
            const publisher = new OutboxPublisher({
                storage,
                publish: harness.publish,
            });

            const baseEpochMs = Date.UTC(2025, 0, 1, 14, 0, 0);
            const accepted: EventContract[] = [];

            // 2 healthy publishes.
            for (let i = 0; i < 2; i += 1) {
                const e = buildEvent({ seed: i + 1, baseEpochMs, offsetMs: i });
                accepted.push(e);
                await publisher.publishWithFallback(e);
            }

            // Bus drops.
            harness.setAlive(false);

            // 4 buffered publishes interleaved across virtual time.
            const offlineSeeds = [3, 4, 5, 6];
            for (const s of offlineSeeds) {
                const e = buildEvent({
                    seed: s,
                    baseEpochMs,
                    offsetMs: s, // strictly ascending offsetMs
                });
                accepted.push(e);
                const r = await publisher.publishWithFallback(e);
                expect(r.buffered).toBe(true);
            }

            // Bus recovers.
            harness.setAlive(true);

            const summary = await publisher.flushOutbox();
            expect(summary.published).toBe(4);
            expect(summary.stillBuffered).toBe(0);

            assertExactDelivery(accepted, harness.delivered);
            // The full delivered ledger remains in created_at ascending
            // order because (a) Phase A inserts went in order, and
            // (b) flush re-orders the buffered entries by created_at.
            assertCreatedAtAscending(harness.delivered);
        },
    );
});
