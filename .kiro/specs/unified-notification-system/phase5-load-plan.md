# Phase 5 — Load-Test Plan

> Unified Notification System (UNS) — Performance and Chaos Verification

## 1. Objectives

This plan defines the load and chaos tests that verify the UNS meets the performance and reliability guarantees stated in Requirements 13, 15.3, and 15.4.

| Objective | What we're proving |
|---|---|
| **Throughput** | The system sustains the target notification rate at 100, 1 000, and 10 000 concurrent users without degradation. |
| **Latency under load** | End-to-end in-app delivery stays within p95 ≤ 500 ms; unread-count queries stay within p95 ≤ 50 ms; history queries stay within p95 ≤ 200 ms. |
| **Failure behavior** | When a channel adapter fails or the Event_Bus restarts, the system degrades gracefully with zero permanent event loss and availability > 99.9%. |
| **Scalability ceiling** | Identify the concurrency level at which the system first breaches a threshold, providing a capacity planning baseline. |

## 2. Scenarios

### 2.1 Normal Load — Sustained Throughput

| Parameter | Value |
|---|---|
| Concurrent users | 500 |
| Duration | 5 minutes (minimum) |
| Notification rate | 100 notifications/sec sustained |
| Event mix | 60% `normal`, 25% `high`, 10% `low`, 5% `critical` |
| Channels exercised | `in_app` (all users), `push` (20% of users), `email` (10% of users) |

Each virtual user:
1. Connects via WebSocket (in-app channel).
2. Emits events at a randomized interval averaging 1 event every 5 seconds.
3. Reads unread count every 2 seconds.
4. Fetches paginated history (50 items) every 30 seconds.
5. Marks one notification as read every 10 seconds.

### 2.2 Peak Load — Burst

| Parameter | Value |
|---|---|
| Concurrent users | 1 000 |
| Burst window | 10 seconds |
| Notifications in burst | 5 000 (500 notifications/sec) |
| Ramp profile | 0 → 1 000 users in 30 seconds, hold 10 s burst, then sustain at 100 notif/sec for 3 minutes |

This scenario simulates a flash event (e.g., end-of-day billing batch, school exam results publication) where many notifications fire simultaneously.

### 2.3 Scale Ceiling — 10 000 Concurrent Users

| Parameter | Value |
|---|---|
| Concurrent users | 10 000 |
| Duration | 5 minutes |
| Notification rate | 200 notifications/sec sustained |
| Event mix | Same as 2.1 |

Purpose: Verify that the system maintains availability > 99.9% and zero event loss at the maximum documented capacity (REQ 13.6).

### 2.4 Degraded Mode — Channel Adapter Failure

| Parameter | Value |
|---|---|
| Concurrent users | 500 |
| Duration | 5 minutes |
| Injected fault | Kill the `push` channel adapter at T+60 s; restore at T+180 s |
| Expected behavior | `in_app` and `email` channels continue unaffected; `push` notifications queue and retry; after adapter recovery, queued push notifications drain; no event is permanently lost |

### 2.5 Chaos — Event_Bus Restart

| Parameter | Value |
|---|---|
| Concurrent users | 500 |
| Duration | 5 minutes |
| Injected fault | Terminate the SQS consumer Lambda at T+90 s; restart at T+150 s |
| Expected behavior | Events published during the outage remain in SQS; after consumer restart, all events are processed and delivered; zero permanent event loss (REQ 3.5, 9.8, 15.4) |

### 2.6 Degraded Mode — Notification_Store Latency Spike

| Parameter | Value |
|---|---|
| Concurrent users | 500 |
| Duration | 5 minutes |
| Injected fault | Add 2 000 ms artificial latency to DynamoDB calls from T+60 s to T+120 s |
| Expected behavior | Throughput drops but no errors propagate to clients; system recovers within 30 s of fault removal; no data loss |

## 3. Metrics to Capture

### 3.1 Latency Metrics

| Metric | Percentiles | Source |
|---|---|---|
| `delivery_latency_ms` (end-to-end, createNotification → client receipt) | p50, p95, p99 | Load-test client timestamps vs. server `created_at` |
| `unread_count_latency_ms` | p50, p95, p99 | HTTP response time for `GET /notifications/unread-count` |
| `history_query_latency_ms` | p50, p95, p99 | HTTP response time for `GET /notifications?cursor=...&limit=50` |
| `preference_resolution_ms` | p50, p95, p99 | Internal Notification_Service instrumentation |

### 3.2 Throughput Metrics

| Metric | Unit |
|---|---|
| `events_emitted_total` | count/sec |
| `notifications_dispatched_total` | count/sec |
| `notifications_delivered_total` | count/sec |
| `websocket_messages_sent_total` | count/sec |

### 3.3 Error and Reliability Metrics

| Metric | Unit |
|---|---|
| `notifications_failed_total` | count (by channel, error_reason) |
| `error_rate` | % (failed / dispatched over rolling 1-min window) |
| `dlq_depth` | count |
| `retry_count_total` | count (by channel) |
| `events_lost` | count (expected: 0) |

### 3.4 Resource Metrics

| Metric | Source |
|---|---|
| Lambda concurrent executions | CloudWatch |
| Lambda duration (p50, p95, p99) | CloudWatch |
| Lambda throttles | CloudWatch |
| SQS queue depth (ApproximateNumberOfMessagesVisible) | CloudWatch |
| SQS oldest message age | CloudWatch |
| DynamoDB consumed RCU / WCU | CloudWatch |
| DynamoDB throttled requests | CloudWatch |
| WebSocket connection count | Application metric |
| Memory usage (per Lambda invocation) | CloudWatch |

## 4. Tools

### 4.1 Primary: k6 (Grafana)

**Rationale:** k6 is purpose-built for load testing, supports WebSocket connections natively, runs locally or in CI, outputs structured metrics, and integrates with Grafana dashboards for real-time visualization.

| Capability | k6 feature |
|---|---|
| HTTP load | Built-in HTTP/1.1 and HTTP/2 |
| WebSocket | Native `ws` module |
| Scripting | JavaScript ES6 |
| Thresholds | Declarative pass/fail in script |
| Output | JSON, CSV, InfluxDB, Prometheus remote-write, Grafana Cloud |
| CI integration | Exit code reflects threshold pass/fail |

### 4.2 Secondary: Custom Node.js Harness

For the chaos scenarios (2.5, 2.6) that require programmatic fault injection (killing Lambda consumers, injecting DynamoDB latency), a custom Node.js script orchestrates:
1. AWS SDK calls to disable/enable SQS event-source mappings.
2. DynamoDB request interceptor (via a test-only middleware flag) for latency injection.
3. Coordination with the k6 run via a shared timeline file.

### 4.3 Monitoring Stack

| Layer | Tool |
|---|---|
| Metrics collection | CloudWatch Metrics + custom `delivery_latency_ms` histogram |
| Dashboards | Grafana (or CloudWatch Dashboards) |
| Alerting during test | CloudWatch Alarms (high failure rate, DLQ depth) |
| Log aggregation | CloudWatch Logs Insights |

## 5. Success Criteria

### 5.1 Pass/Fail Thresholds

| Criterion | Threshold | Applies to scenarios |
|---|---|---|
| In-app delivery p95 | ≤ 500 ms | 2.1, 2.2, 2.3 |
| In-app delivery p99 | ≤ 1 000 ms | 2.1, 2.2, 2.3 |
| Unread-count query p95 | ≤ 50 ms | 2.1, 2.2, 2.3 |
| History query p95 (50 items) | ≤ 200 ms | 2.1, 2.2, 2.3 |
| Preference resolution p95 | ≤ 10 ms | 2.1 |
| Error rate (rolling 1-min) | < 1% | 2.1, 2.2, 2.3 |
| Events permanently lost | 0 | All scenarios |
| Availability | > 99.9% | 2.3 (10k users) |
| p95 below 1 ms (measurement error) | FAIL if p95 < 1 ms | 2.1 (REQ 15.3) |

### 5.2 Degraded-Mode Criteria

| Criterion | Threshold | Applies to scenarios |
|---|---|---|
| Unaffected channels continue within normal thresholds | Same as 5.1 | 2.4 |
| Failed channel recovers within 60 s of adapter restoration | Recovery time ≤ 60 s | 2.4 |
| Zero permanent event loss after Event_Bus restart | Lost events = 0 | 2.5 |
| System recovers within 30 s of fault removal | Recovery time ≤ 30 s | 2.5, 2.6 |
| DLQ depth returns to 0 after recovery | DLQ = 0 within 5 min | 2.4, 2.5 |

### 5.3 Overall Verdict

The load test **passes** if and only if:
- All thresholds in 5.1 are met for scenarios 2.1, 2.2, and 2.3.
- All degraded-mode criteria in 5.2 are met for scenarios 2.4, 2.5, and 2.6.
- No scenario produces a permanently lost event.

## 6. Environment

### 6.1 Test Environment

| Aspect | Configuration |
|---|---|
| Environment | Isolated staging AWS account (or dedicated `uns-loadtest` stack in the staging account) |
| Infrastructure | Same CloudFormation/CDK stack as production, deployed with `STAGE=loadtest` |
| DynamoDB | On-demand capacity mode (mirrors production) |
| SNS + SQS | Standard queues with same retry/DLQ config as production |
| Lambda concurrency | Reserved concurrency matching production limits |
| WebSocket API | API Gateway WebSocket with same auth config |
| Data isolation | Dedicated DynamoDB tables prefixed `loadtest-`; no shared state with staging or production |
| Seed data | 10 000 pre-created user accounts with randomized roles and preferences |

### 6.2 Load Generator

| Aspect | Configuration |
|---|---|
| Machine | Dedicated EC2 instance (c5.2xlarge) or CI runner with sufficient network bandwidth |
| Location | Same AWS region as the test stack to minimize network variance |
| k6 version | Latest stable (pinned in `package.json`) |
| Parallelism | k6 VUs configured per scenario; custom harness runs on same machine |

### 6.3 Data Seeding

Before each test run:
1. Create 10 000 user records with roles distributed as: 5% admin, 15% cashier, 10% accountant, 5% delivery_agent, 10% vendor, 20% customer, 5% chef, 5% kitchen_staff, 5% school_admin, 10% teacher, 5% student, 5% parent.
2. Assign randomized `UserPreference` records (quiet hours, mute targets, per-category channels).
3. Pre-populate 100 notifications per user to simulate realistic history-query load.

## 7. Schedule

### 7.1 When to Run

| Trigger | Scenarios executed |
|---|---|
| **Pre-release** (before any production deployment) | All (2.1 – 2.6) |
| **Nightly CI** (scheduled pipeline) | 2.1 (normal load, 500 users, 5 min) |
| **Weekly CI** (scheduled pipeline) | 2.1, 2.2, 2.3 (full scale sweep) |
| **On-demand** (manual trigger) | Any subset; used for regression or capacity planning |

### 7.2 Duration Budget

| Run type | Estimated wall-clock time |
|---|---|
| Full suite (all scenarios) | ~35 minutes (including ramp, hold, cooldown, and fault windows) |
| Nightly (scenario 2.1 only) | ~7 minutes |
| Weekly (scenarios 2.1–2.3) | ~20 minutes |

### 7.3 Results Reporting

After each run:
1. k6 outputs a JSON summary to `phase5-load-results.md` (human-readable) and `load-results.json` (machine-readable).
2. The CI pipeline compares results against the thresholds in section 5 and sets the build status to PASS or FAIL.
3. Grafana dashboard link is included in the results file for drill-down.
4. Any threshold breach triggers a Slack/email notification to the UNS team channel.

## 8. Test Script Locations

| Script | Path | Purpose |
|---|---|---|
| k6 normal-load script | `my-backend/tests/notifications/load/normal-load.k6.js` | Scenario 2.1 |
| k6 peak-load script | `my-backend/tests/notifications/load/peak-load.k6.js` | Scenario 2.2 |
| k6 scale-ceiling script | `my-backend/tests/notifications/load/scale-ceiling.k6.js` | Scenario 2.3 |
| Chaos harness | `my-backend/tests/notifications/load/chaos-harness.ts` | Scenarios 2.4, 2.5, 2.6 |
| Data seeder | `my-backend/tests/notifications/load/seed-data.ts` | Pre-test data population |
| Results template | `.kiro/specs/unified-notification-system/phase5-load-results.md` | Results recording |

## 9. Requirements Traceability

| Requirement | Covered by |
|---|---|
| REQ 13.1 (unread-count p95 ≤ 50 ms) | Scenarios 2.1, 2.2, 2.3 — threshold in 5.1 |
| REQ 13.2 (history query p95 ≤ 200 ms) | Scenarios 2.1, 2.2, 2.3 — threshold in 5.1 |
| REQ 13.3 (in-app delivery p95 ≤ 500 ms at 500 concurrent) | Scenario 2.1 — threshold in 5.1 |
| REQ 13.5 (benchmark at 100, 1 000, 10 000 users) | Scenarios 2.1, 2.2, 2.3 |
| REQ 13.6 (availability > 99.9%, zero event loss up to 10k) | Scenario 2.3 — threshold in 5.1 |
| REQ 15.3 (500 concurrent, 5 min, p95 in [1 ms, 500 ms]) | Scenario 2.1 — threshold in 5.1 |
| REQ 15.4 (chaos: Event_Bus kill, no permanent loss) | Scenario 2.5 — threshold in 5.2 |
| REQ 3.5 / 9.8 (no event loss across restart) | Scenario 2.5 |
| REQ 5.7 (500 ms p95 in-app at 10k connections) | Scenario 2.3 |
