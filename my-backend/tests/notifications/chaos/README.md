# UNS Chaos Tests

> Spec: `unified-notification-system` (Task 18.3)
> Tests scoped to: `my-backend/tests/notifications/chaos/`
> Validates: REQ 5.10, 9.3, 9.4, 9.7, 9.8, 13.6, 14.6, 15.4
> Hand-off from: `phase5-load-plan.md` §2.6 (SCN-SLOW-CHANNEL)

## What these tests assert

| File | Scenario | Assertions | REQs |
|---|---|---|---|
| `event-bus-restart.test.ts` | Steady producer flow → publisher kill mid-flight → recovery → flush | Outbox buffers during outage; flush replays in `created_at` ascending; zero accepted-event loss; bumped `retry_count` survives still-down flushes | 9.7, 9.8, 13.6, 15.4 |
| `slow-channel-composition.test.ts` | Slow + transient-failing email channel composed with publisher restart | Zero event loss across restart; dedup correctness across the recovery boundary (no double-delivery of the same `(notification_id, recipient_id, channel)` tuple); failure-rate alert fires for `email` only, never for the healthy channels | 9.7, 9.8, 14.6, 15.4 (composes §2.6 SCN-SLOW-CHANNEL with §15.4 chaos) |
| `dlq-recovery.test.ts` | Channel exhaust retry budget → DLQ via SQS native redrive → operator replay | DLQ entry preserves original payload byte-for-byte, last error, retry count, last attempt timestamp; backoff visibility extensions follow `backoffSeconds(attempt)`; operator replay re-delivers exactly once; malformed payload → first-attempt DLQ (no retry) | 5.10, 9.3, 9.4, 9.8, 13.6, 15.4 |
| `chaos-harness.ts` | AWS fault-injection orchestrator (scenarios 2.4, 2.5, 2.6) | Zero permanent event loss; unaffected channels within normal thresholds; recovery time within bounds (60s channel, 30s bus/store); DLQ depth returns to 0 | 13, 15.4 |

## Running

### In-process Jest tests (CI-safe, deterministic)

The chaos tests run under the same Jest configuration the rest of `my-backend` uses (no extra setup). From the workspace root:

```bash
npm --prefix my-backend run test -- tests/notifications/chaos
```

Or run a single file:

```bash
npm --prefix my-backend run test -- tests/notifications/chaos/event-bus-restart.test.ts
```

### AWS fault-injection harness (staging/loadtest environment)

The `chaos-harness.ts` orchestrator performs real AWS fault injection against a deployed stack. It implements scenarios 2.4, 2.5, and 2.6 from `phase5-load-plan.md`:

```bash
# Run all chaos scenarios against the loadtest stage
npx ts-node --transpile-only tests/notifications/chaos/chaos-harness.ts \
  --scenario all --region us-east-1 --stage loadtest

# Run a single scenario
npx ts-node --transpile-only tests/notifications/chaos/chaos-harness.ts \
  --scenario 2.5 --stage loadtest

# See all options
npx ts-node --transpile-only tests/notifications/chaos/chaos-harness.ts --help
```

The harness requires AWS credentials with permissions to:
- `lambda:ListEventSourceMappings`, `lambda:UpdateEventSourceMapping`, `lambda:GetEventSourceMapping`
- `lambda:UpdateFunctionConfiguration`, `lambda:GetFunctionConfiguration`
- `cloudwatch:GetMetricData`
- `sqs:GetQueueAttributes`

**Never run against production.** Use the `loadtest` or `staging` stage only.

## Why the tests are in-process (no real AWS)

REQ 15.4 says the chaos test SHALL terminate the Event_Bus process during in-flight delivery. Three options exist:

1. **Real-AWS**: stand up a staging SNS+SQS+DLQ and orchestrate the kill via the AWS Console / CLI. Highest-fidelity, but unsuitable for CI (slow, expensive, flaky on quotas) and cannot be deterministic across runs.
2. **Localstack / containerized AWS**: better than real-AWS for CI, but still depends on a docker dependency the wider project does not currently require.
3. **In-process surface stubs that exercise the production retry / outbox / DLQ-redrive code paths**: the production logic for "did we lose an event?" is not in the AWS plumbing — it is in `OutboxPublisher`, `consumer.ts`, and the audit hook. Stubbing the SDK boundary (`SNSClient.send` / `SQSClient.send`) and toggling availability flags lets the test drive the same control flow with millisecond determinism.

This directory follows option 3. A follow-up integration test under `my-backend/tests/notifications/integration/` will exercise the real-AWS variant once the Phase 5 staging environment lands.

## Reuse of production modules (read-only)

These tests **do not modify** any source under `my-backend/src/notifications/`. They consume:

- `OutboxPublisher`, `InMemoryOutboxStorage` — `event-bus/outbox.ts`
- `EventBusUnavailableError`, `EventContract`, `PublishAck` — `event-bus/types.ts` / `errors.ts`
- `createConsumer`, `backoffSeconds`, `DEFAULT_MAX_RETRIES`, `_setSqsClientForTests` — `event-bus/consumer.ts`
- `validateEventContract` — `event-bus/schema-validator.ts` (transitively, through the outbox flush re-validation path)
- `createFailureRateAlertEngine`, `ALERT_EVENT_NAME`, `DispatchOutcomeProvider` — `observability/alerts.ts`
- `DispatchChannelAdapter`, `DispatchChannelArgs` — `service/types.ts`
- `NotificationRecord`, `NotificationChannel` — `store/types.ts`

## Determinism guarantees

- **Virtual clock for buffered/replay timing.** `shim/channel-fault.ts` exports `ManualChaosClock` — virtual `now()` and `wait(ms)`. Tests that need to assert on the order of buffered → flushed events use deterministic timestamps from `shim/fixtures.ts`, not real wall-clock time.
- **Realtime clock with small fixed delays for in-process slow-channel sleeps.** The slow-channel composition test uses `realtimeChaosClock` with a 5–10 ms latency. This avoids the virtual-clock deadlock that would happen if a sequential `await dispatch(...)` loop were forced to advance a clock between calls. The latency is fixed, deterministic, and small enough that the whole suite still runs in well under a second per file.
- **Stable identifiers.** `shim/fixtures.ts` uses `deterministicId(seed)` and `deterministicTimestamp(base, offset)` so the same input always produces the same Event_Contract envelope.
- **Captured side effects.** Every assertion is against an in-memory ledger / counter map; no test reads from the network or filesystem.

## Hand-off to / from sibling tasks

- **Task 18.2 (load harness).** `phase5-load-plan.md` §2.6 specifies a `channel-fault.ts` shim under `my-backend/tests/notifications/load/shim/`. **That shim has landed** and exposes the same surface (`slowChannel`, `failingChannel`, `flappingChannel`, `recordingChannel`, `slowChannelWindow`, `ManualChaosClock`, `realtimeChaosClock`, `flushMicrotasks`). The chaos directory keeps a byte-equivalent inline copy at `shim/channel-fault.ts` because ts-jest's `tsconfig.jest.json` (`rootDir: ./src`, `include: ["src/**/*.ts"]`) does not include arbitrary `tests/...` files in a single TypeScript program — a cross-tests re-export breaks isolated-module compilation. The two files MUST stay in surface-lockstep so a future tsconfig change can swap to a re-export with no test rewrites. The load shim's own header explicitly anticipates this duplication.
- **Task 14.10 (integration tests).** The chaos tests are scenario-level and assert on the recovery / failure-isolation contract. Per-event-type wiring is integration-suite scope (`tests/notifications/integration/`).

## What is intentionally not asserted here

- **Real AWS DLQ semantics.** REQ 3.10 ("SQS native DLQ redrive moves the message with original payload, attributes, and timestamps preserved") is a contract the consumer relies on; we mock the redrive boundary with `DlqMock` and assert against the `onAuditFailed` audit hook, which is the production surface the consumer emits before SQS takes over.
- **Cross-process kill / restart.** The production `EventBusUnavailableError` path is what producers actually take when the bus is dead in any AWS topology (network partition, IAM revocation, full availability-zone failover). Toggling that error in-process is the canonical chaos-test shape because it exercises the SAME control flow regardless of what caused the unavailability.
