// ============================================================================
// chaos/slow-channel-composition.test.ts — REQ 9.7, 9.8, 14.6, 15.4 (compose)
// ============================================================================
//
// Scenario:
//   1. Steady event flow targets recipients on three healthy channels
//      (`in_app`, `push`, `webhook`) and one slow channel (`email`).
//   2. The `email` adapter is wrapped via the load harness shim
//      (`shim/channel-fault.ts`) to inject a fixed virtual latency and
//      a transient failure burst — modelling the SCN-SLOW-CHANNEL
//      hand-off in `phase5-load-plan.md` §2.6.
//   3. Mid-flight, the Event_Bus is killed via the OutboxPublisher
//      (publishes start buffering); after the kill window, the bus
//      recovers and `flushOutbox()` replays every buffered event.
//   4. Assertions:
//      - zero event loss across the full composition (REQ 9.8 / REQ 15.4),
//      - dedup correctness held across the restart (no double-delivery
//        of the same `(notification_id, recipient_id)` after replay),
//      - the failure-rate alert (REQ 14.6) fires for `email` only — not
//        for the healthy channels — and only while the failed/dispatched
//        ratio exceeds the configured threshold.
//
// What this test exercises in production code (read-only):
//   - `OutboxPublisher` + `InMemoryOutboxStorage` (REQ 9.7).
//   - `FailureRateAlertEngine` (REQ 14.6) with a custom
//     `DispatchOutcomeProvider` so the test owns the sample stream.
//   - `recordDeliveryOutcome` flow against per-channel adapters wrapped
//     with the load harness shim.
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
import {
    ALERT_EVENT_NAME,
    createFailureRateAlertEngine,
    type ChannelDispatchCounts,
    type DispatchOutcomeProvider,
    type FailureRateAlert,
} from '../../../src/notifications/observability/alerts';
import type { NotificationChannel } from '../../../src/notifications/store/types';
import type {
    DispatchChannelAdapter,
    DispatchChannelArgs,
} from '../../../src/notifications/service/types';

import {
    failingChannel,
    realtimeChaosClock,
    recordingChannel,
    slowChannel,
} from './shim/channel-fault';
import {
    buildEvent,
    buildNotificationRecord,
} from './shim/fixtures';

// ---------------------------------------------------------------------------
// Per-channel counters used both by the test driver (asserts) and by the
// alert engine (provider-driven mode).
// ---------------------------------------------------------------------------

interface ChannelCounters {
    successes: number;
    failures: number;
}

function newCounters(): Record<NotificationChannel, ChannelCounters> {
    return {
        in_app: { successes: 0, failures: 0 },
        push: { successes: 0, failures: 0 },
        email: { successes: 0, failures: 0 },
        sms: { successes: 0, failures: 0 },
        webhook: { successes: 0, failures: 0 },
    };
}

function snapshotProvider(
    counters: Record<NotificationChannel, ChannelCounters>,
): DispatchOutcomeProvider {
    return () => {
        const out = new Map<NotificationChannel, ChannelDispatchCounts>();
        for (const [channel, c] of Object.entries(counters) as Array<
            [NotificationChannel, ChannelCounters]
        >) {
            out.set(channel, {
                successes: c.successes,
                failures: c.failures,
            });
        }
        return out;
    };
}

// ---------------------------------------------------------------------------
// Bus harness — same toggle pattern used by event-bus-restart.test.ts.
// ---------------------------------------------------------------------------

interface BusHarness {
    publish: (event: EventContract) => Promise<PublishAck>;
    setAlive(alive: boolean): void;
    readonly delivered: readonly EventContract[];
}

function makeBusHarness(): BusHarness {
    let alive = true;
    const delivered: EventContract[] = [];
    return {
        async publish(event) {
            if (!alive) {
                throw new EventBusUnavailableError('simulated bus outage');
            }
            delivered.push(event);
            return { messageId: `msg-${event.id}` };
        },
        setAlive(next) {
            alive = next;
        },
        delivered,
    };
}

// ---------------------------------------------------------------------------
// Per-channel dispatcher — instruments delivery outcomes for the alert
// engine and routes through the supplied adapter for that channel.
// ---------------------------------------------------------------------------

function instrumentedDispatch(
    adapters: Record<NotificationChannel, DispatchChannelAdapter>,
    counters: Record<NotificationChannel, ChannelCounters>,
): DispatchChannelAdapter {
    return async (args: DispatchChannelArgs) => {
        const adapter = adapters[args.channel];
        try {
            await adapter(args);
            counters[args.channel].successes += 1;
        } catch (err) {
            counters[args.channel].failures += 1;
            throw err;
        }
    };
}

// ===========================================================================
// Tests
// ===========================================================================

describe('chaos: slow-channel composition with publisher restart', () => {
    test(
        'no event loss; dedup correctness held; failure-rate alert fires for slow email only',
        async () => {
            // -----------------------------------------------------------------
            // Setup
            //
            // The "slow channel" uses the realtime clock with a small
            // fixed wait (10 ms). It's still deterministic — every test
            // run takes the same number of milliseconds — and avoids the
            // virtual-clock deadlock that would happen if we awaited a
            // ManualChaosClock inside a sequential dispatch loop.
            //
            // The alert engine's window math uses `Date.now` directly
            // because its 60_000 ms window dwarfs the test's wall-clock
            // duration (~100 ms), so every event lands in the current
            // window without flakiness.
            // -----------------------------------------------------------------
            const bus = makeBusHarness();
            const outboxStorage = new InMemoryOutboxStorage();
            const publisher = new OutboxPublisher({
                storage: outboxStorage,
                publish: bus.publish,
            });

            const counters = newCounters();

            // Per-channel delivery sink — a recording adapter feeds a
            // single ledger so we can assert exactly-once delivery
            // across the restart boundary.
            interface DeliveredEntry {
                readonly notification_id: string;
                readonly recipient_id: string;
                readonly channel: NotificationChannel;
                readonly at: number;
            }
            const ledger: DeliveredEntry[] = [];
            const recorder = recordingChannel(
                ledger as DeliveredEntry[],
                realtimeChaosClock,
            );

            // Slow + failing email adapter — first 4 attempts throw;
            // every later attempt waits 10 ms (real time) and then
            // delegates to the recorder. This is the SCN-SLOW-CHANNEL
            // shape with an extra transient failure burst, so the
            // failure-rate alert has something to fire on (REQ 14.6).
            const failingEmail = failingChannel(
                slowChannel(recorder, {
                    latencyMs: 10,
                    clock: realtimeChaosClock,
                }),
                {
                    failuresBeforeRecovery: 4,
                    errorMessage: 'email: SMTP transient',
                },
            );

            const adapters: Record<NotificationChannel, DispatchChannelAdapter> = {
                in_app: recorder,
                push: recorder,
                webhook: recorder,
                sms: recorder,
                email: failingEmail.adapter,
            };

            const dispatch = instrumentedDispatch(adapters, counters);

            // -----------------------------------------------------------------
            // Alert engine — provider-driven, evaluating the four primary
            // channels involved in the test. The slow channel must fire;
            // the healthy ones must NOT.
            // -----------------------------------------------------------------
            const firedAlerts: FailureRateAlert[] = [];
            const alerts = createFailureRateAlertEngine({
                threshold: 0.05,
                minSampleSize: 1,
                windowMs: 60_000,
                channels: ['in_app', 'push', 'email', 'webhook'],
                provider: snapshotProvider(counters),
                sink: (alert) => firedAlerts.push(alert),
                // Real wall-clock — the 60_000 ms window covers the
                // entire test runtime (~100 ms) so every recorded
                // outcome lands in the same window deterministically.
                now: () => Date.now(),
            });

            // -----------------------------------------------------------------
            // Phase A — publish 6 events with multi-channel recipients.
            // Half land before the bus dies; the rest are pushed during
            // the outage and must survive via the outbox.
            // -----------------------------------------------------------------
            const baseEpochMs = Date.UTC(2025, 0, 1, 12, 0, 0);
            const accepted: EventContract[] = [];
            for (let i = 0; i < 6; i += 1) {
                accepted.push(
                    buildEvent({
                        seed: i + 1,
                        baseEpochMs,
                        offsetMs: i * 50,
                        priority: 'high',
                        recipients: [
                            {
                                user_id: 'recipient-1',
                                role: 'admin',
                                channels: ['in_app', 'push', 'email', 'webhook'],
                            },
                        ],
                        channels: ['in_app', 'push', 'email', 'webhook'],
                    }),
                );
            }

            // Helper — drain publishes through the OutboxPublisher and
            // (when the bus is alive) immediately dispatch via the
            // per-channel adapters to simulate a downstream consumer.
            async function drainPublish(event: EventContract): Promise<void> {
                const result = await publisher.publishWithFallback(event);
                if (!result.buffered) {
                    await dispatchAll(event);
                }
            }

            async function dispatchAll(event: EventContract): Promise<void> {
                const record = buildNotificationRecord({
                    seed: parseInt(event.id.replace(/[^0-9]/g, ''), 10) || 0,
                    baseEpochMs: new Date(event.created_at).getTime(),
                    priority: event.priority,
                    channels: event.channels as NotificationChannel[],
                    recipients: event.recipients.map((r) => ({
                        user_id: r.user_id,
                        role: r.role,
                        channels: (r.channels ??
                            event.channels) as NotificationChannel[],
                        status: 'emitted',
                        delivered_at: null,
                        read_at: null,
                    })),
                });
                // Replace the seed-derived id with the event id so dedup
                // assertions can compare on the exact accepted id.
                const recordWithId = {
                    ...record,
                    notification_id: event.id,
                };
                for (const recipient of recordWithId.recipients) {
                    for (const channel of recipient.channels) {
                        try {
                            await dispatch({
                                notification: recordWithId,
                                recipient: {
                                    user_id: recipient.user_id,
                                    role: recipient.role,
                                },
                                channel,
                            });
                        } catch {
                            // Per Phase 3 §9.3, a single channel failure
                            // does not block the others; the test driver
                            // mirrors the service-loop's behaviour. The
                            // counters track it for the alert.
                        }
                    }
                }
            }

            // -- 3 events while healthy ---------------------------------------
            for (let i = 0; i < 3; i += 1) {
                await drainPublish(accepted[i]);
            }

            // -- Bus dies; remaining 3 events must buffer ---------------------
            bus.setAlive(false);
            for (let i = 3; i < 6; i += 1) {
                await drainPublish(accepted[i]);
            }
            expect(await publisher.pendingCount()).toBe(3);
            // Nothing reached the bus during the outage.
            expect(bus.delivered).toHaveLength(3);

            // -- Bus recovers; flush replays buffered events ------------------
            bus.setAlive(true);
            const flushSummary = await publisher.flushOutbox();
            expect(flushSummary.attempted).toBe(3);
            expect(flushSummary.published).toBe(3);
            expect(flushSummary.stillBuffered).toBe(0);
            expect(flushSummary.failures).toEqual([]);

            // Re-emit the post-flush dispatches (in production a downstream
            // SQS consumer triggers the dispatch on replay; in this in-process
            // test we mirror that explicitly to keep the dispatch path
            // exercised under chaos).
            for (let i = 3; i < 6; i += 1) {
                await dispatchAll(accepted[i]);
            }

            // -----------------------------------------------------------------
            // Assertions — REQ 9.8 / REQ 15.4: zero event loss
            // -----------------------------------------------------------------
            expect(bus.delivered.map((e) => e.id).sort()).toEqual(
                accepted.map((e) => e.id).sort(),
            );

            // -----------------------------------------------------------------
            // Assertions — dedup correctness across the restart.
            // For every (notification_id, recipient_id, channel) tuple we
            // must see at most one successful delivery. Email's transient
            // failures may have re-attempted, but only successful
            // attempts land in the recorder ledger.
            // -----------------------------------------------------------------
            const seen = new Set<string>();
            for (const entry of ledger) {
                const key = `${entry.notification_id}|${entry.recipient_id}|${entry.channel}`;
                expect(seen.has(key)).toBe(false);
                seen.add(key);
            }

            // -----------------------------------------------------------------
            // Assertions — REQ 14.6: failure-rate alert fires for email
            // only, never for the healthy channels.
            // -----------------------------------------------------------------
            const fired = alerts.evaluate();

            const emailFires = fired.filter((a) => a.channel === 'email');
            expect(emailFires.length).toBeGreaterThanOrEqual(1);
            expect(emailFires[0].event_name).toBe(ALERT_EVENT_NAME);

            for (const channel of ['in_app', 'push', 'webhook'] as const) {
                const breach = fired.find((a) => a.channel === channel);
                expect(breach).toBeUndefined();
                // Sanity — the healthy channels recorded zero failures.
                expect(counters[channel].failures).toBe(0);
                expect(counters[channel].successes).toBeGreaterThan(0);
            }

            // The sink received the same firing alert(s) the evaluate()
            // call returned.
            expect(firedAlerts.some((a) => a.channel === 'email')).toBe(true);
            expect(
                firedAlerts.every(
                    (a) => a.event_name === ALERT_EVENT_NAME,
                ),
            ).toBe(true);
            expect(firedAlerts.every((a) => a.channel !== 'in_app')).toBe(true);
            expect(firedAlerts.every((a) => a.channel !== 'push')).toBe(true);
            expect(firedAlerts.every((a) => a.channel !== 'webhook')).toBe(true);

            // Sanity — the failing-email shim recorded the right
            // number of failures (the alert engine sees these via the
            // counters provider).
            expect(failingEmail.tracker.failures).toBe(4);
            expect(failingEmail.tracker.successes).toBeGreaterThanOrEqual(1);
        },
    );

    test(
        'healthy channels remain unaffected even when slow channel saturates its retry budget',
        async () => {
            // Variant: the slow channel is fully unrecoverable for the
            // duration of the run (every attempt fails), but the other
            // three channels keep delivering. The alert MUST fire only
            // for the slow channel — failure isolation is a hard
            // guarantee in REQ 5.x and Phase 3 §9.3.
            const bus = makeBusHarness();
            const publisher = new OutboxPublisher({
                storage: new InMemoryOutboxStorage(),
                publish: bus.publish,
            });
            const counters = newCounters();

            const ledger: Array<{
                readonly notification_id: string;
                readonly recipient_id: string;
                readonly channel: string;
                readonly at: number;
            }> = [];
            const recorder = recordingChannel(ledger, realtimeChaosClock);

            const slowEmail = failingChannel(
                slowChannel(recorder, {
                    latencyMs: 5,
                    clock: realtimeChaosClock,
                }),
                {
                    failuresBeforeRecovery: 0,
                    permanent: true,
                    errorMessage: 'email: SMTP down',
                },
            );

            const adapters: Record<NotificationChannel, DispatchChannelAdapter> = {
                in_app: recorder,
                push: recorder,
                webhook: recorder,
                sms: recorder,
                email: slowEmail.adapter,
            };
            const dispatch = instrumentedDispatch(adapters, counters);

            const alerts = createFailureRateAlertEngine({
                threshold: 0.05,
                minSampleSize: 1,
                windowMs: 60_000,
                channels: ['in_app', 'push', 'email', 'webhook'],
                provider: snapshotProvider(counters),
                now: () => Date.now(),
            });

            const baseEpochMs = Date.UTC(2025, 0, 2, 12, 0, 0);
            const events = Array.from({ length: 4 }, (_, i) =>
                buildEvent({
                    seed: i + 1,
                    baseEpochMs,
                    offsetMs: i * 100,
                    priority: 'high',
                    recipients: [
                        {
                            user_id: 'recipient-1',
                            role: 'admin',
                            channels: ['in_app', 'push', 'email', 'webhook'],
                        },
                    ],
                    channels: ['in_app', 'push', 'email', 'webhook'],
                }),
            );

            // Bus stays healthy; we only test channel isolation here.
            for (const event of events) {
                await publisher.publishWithFallback(event);
                const record = buildNotificationRecord({
                    seed: 0,
                    baseEpochMs: new Date(event.created_at).getTime(),
                    priority: event.priority,
                    channels: event.channels as NotificationChannel[],
                    recipients: [
                        {
                            user_id: 'recipient-1',
                            role: 'admin',
                            channels: event.channels as NotificationChannel[],
                            status: 'emitted',
                            delivered_at: null,
                            read_at: null,
                        },
                    ],
                });
                const recordWithId = { ...record, notification_id: event.id };
                for (const channel of event.channels as NotificationChannel[]) {
                    try {
                        await dispatch({
                            notification: recordWithId,
                            recipient: {
                                user_id: 'recipient-1',
                                role: 'admin',
                            },
                            channel,
                        });
                    } catch {
                        // expected for email
                    }
                }
            }

            const fired = alerts.evaluate();
            // Only email breaches.
            expect(fired.map((a) => a.channel)).toEqual(['email']);

            // Healthy channels delivered every event.
            for (const channel of ['in_app', 'push', 'webhook'] as const) {
                expect(counters[channel].successes).toBe(events.length);
                expect(counters[channel].failures).toBe(0);
            }

            // Email failed every attempt.
            expect(counters.email.failures).toBe(events.length);
            expect(counters.email.successes).toBe(0);
        },
    );
});
