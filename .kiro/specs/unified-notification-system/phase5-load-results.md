# Phase 5 — Load and Capacity Test Results

> Spec: Unified Notification System (UNS)
> Companion plan: [`phase5-load-plan.md`](./phase5-load-plan.md)
> Companion runner: [`my-backend/tests/notifications/load/`](../../my-backend/tests/notifications/load/)
> Validates: REQ 13.5, 13.6 (load benchmark results), REQ 14.5 (latency), REQ 18.4 / 18.6 (feature-complete gate)

This is the human-readable result artifact. CI runs append one block per scenario per the §8 template in `phase5-load-plan.md`. Each block records the configuration, the latency table, the throughput / queue depth / availability table, the correctness table, the failures / DLQ table, and the verdict (PASS / FAIL / INCONCLUSIVE).

A scenario passes only when every threshold in §7.1 of the load plan holds; a single hard-threshold breach fails the scenario fail-closed. Regressions are flagged per §8.2 of the plan.

This skeleton is committed alongside the harness. Until a non-prod SUT environment is provisioned (§5.2 of the plan) the result blocks below are placeholders showing the template each future run will fill.

---

## Status: not yet executed

- **Harness**: implemented under `my-backend/tests/notifications/load/` (task 18.2).
- **SUT environment**: pending non-prod AWS stack provisioning (§5.2 of the plan).
- **First scheduled run**: TBD — gated on the staging stack and the credentials store.

## Run ledger

| run_id | scenarios run | git_sha | environment | started_at | verdict |
|---|---|---|---|---|---|
| _(no runs yet — skeleton)_ | — | — | — | — | — |

---

## Result blocks (template — populated by future runs)

### SCN-STEADY @ 100 — `<run_id>` — `<ISO timestamp>`

#### Configuration

- concurrent_users: 100
- events_per_second: 200
- duration_seconds: 300
- recipient_scale: 100
- git_sha: `<commit>`
- environment: `<stack name>`
- knobs: `<verbatim CLI flags>`

#### Latency

| Metric                                | p50 | p95 | p99 | Threshold              | Pass |
|---------------------------------------|-----|-----|-----|------------------------|------|
| in-app end-to-end (ms)                | —   | —   | —   | p95 ≤ 500, p95 ≥ 1     | —    |
| unread-count query (ms)               | —   | —   | —   | p95 ≤ 50               | —    |
| history query (ms)                    | —   | —   | —   | p95 ≤ 200              | —    |
| unread-count projection lag (ms)      | —   | —   | —   | p95 ≤ 100              | —    |
| preference resolution (ms)            | —   | —   | —   | p95 ≤ 10               | —    |

#### Throughput, queue depth, availability

| Metric                          | Value | Threshold                  | Pass |
|---------------------------------|-------|----------------------------|------|
| events_accepted_total           | —     | ≥ 60 000                   | —    |
| events_delivered_total          | —     | = events_accepted_total    | —    |
| max sqs_visible_messages        | —     | ≤ 60 000                   | —    |
| availability_pct                | —     | > 99.9 %                   | —    |

#### Correctness

| Metric                            | Value | Threshold | Pass |
|-----------------------------------|-------|-----------|------|
| dedup_violation_count             | —     | = 0       | —    |
| authorization_violation_count     | —     | = 0       | —    |
| preference_violation_count        | —     | = 0       | —    |
| replay_omission_count             | —     | = 0       | —    |
| lifecycle_ordering_violation_count| —     | = 0       | —    |

#### Failures and DLQ

| Channel  | failed_total | dispatched_total | failure_rate | DLQ depth |
|----------|-------------|------------------|--------------|-----------|
| in_app   | —           | —                | —            | —         |
| push     | —           | —                | —            | —         |
| email    | —           | —                | —            | —         |
| sms      | —           | —                | —            | —         |
| webhook  | —           | —                | —            | —         |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-STEADY @ 1 000 — `<run_id>` — `<ISO timestamp>`

_(same template; CI fills on first run)_

---

### SCN-STEADY @ 10 000 — `<run_id>` — `<ISO timestamp>`

_(same template; CI fills on first run)_

---

### SCN-BURST — `<run_id>` — `<ISO timestamp>`

#### Configuration

- baseline_eps: 2000
- burst_peak_eps: 20000
- ramp_up_seconds: 30
- hold_seconds: 60
- ramp_down_seconds: 30
- drain_seconds: 180
- git_sha: `<commit>`
- environment: `<stack name>`
- knobs: `<verbatim CLI flags>`

#### Burst absorption

| Metric                                       | Value | Threshold                        | Pass |
|----------------------------------------------|-------|----------------------------------|------|
| peak_eps_reached                             | —     | ≥ 18 000 (G-T4 −10 %)            | —    |
| events_accepted_total                        | —     | -                                | —    |
| events_delivered_total                       | —     | = events_accepted_total          | —    |
| drain_seconds_to_baseline_latency            | —     | ≤ 150 (G-T7 +30 s)               | —    |
| in-app p95 30 s post-drain (ms)              | —     | ≤ 500                            | —    |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-SUSTAINED-HIGH — `<run_id>` — `<ISO timestamp>`

_(same template; latency table is repeated 6× at 5-minute intervals across the 30-minute window per §2.3)_

---

### SCN-HOTKEY — `<run_id>` — `<ISO timestamp>`

#### Per-tenant latency

| Tenant class         | p50 | p95 | p99 | Threshold                            | Pass |
|----------------------|-----|-----|-----|--------------------------------------|------|
| hot tenant (n=1)     | —   | —   | —   | p95 ≤ 500                            | —    |
| non-hot (mean of 49) | —   | —   | —   | within ±10 % of SCN-STEADY p95       | —    |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-MIX — `<run_id>` — `<ISO timestamp>`

#### Per-channel latency

| Channel | p50 | p95 | p99 | Threshold (p95 / p99)              | Pass |
|---------|-----|-----|-----|------------------------------------|------|
| in_app  | —   | —   | —   | 500 / 1 000 ms                     | —    |
| push    | —   | —   | —   | 1 500 / 3 000 ms                   | —    |
| email   | —   | —   | —   | 5 000 / 10 000 ms                  | —    |
| sms     | —   | —   | —   | 5 000 / 12 000 ms                  | —    |
| webhook | —   | —   | —   | 2 500 / 6 000 ms                   | —    |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-SLOW-CHANNEL — `<run_id>` — `<ISO timestamp>`

#### Configuration

- channel_fault_target: email
- channel_fault_latency_ms: 2000
- channel_fault_window_seconds: 120
- channel_fault_start_seconds: 120
- duration_seconds: 300

#### Channel latency

| Channel | p95 inside fault window | p95 outside fault window | Deviation from SCN-STEADY | Pass |
|---------|-------------------------|--------------------------|---------------------------|------|
| in_app  | —                       | —                        | within ±10 %              | —    |
| push    | —                       | —                        | within ±10 %              | —    |
| sms     | —                       | —                        | within ±10 %              | —    |
| webhook | —                       | —                        | within ±10 %              | —    |
| email   | —                       | —                        | (faulted, no bound)       | —    |

#### DLQ

| Metric                              | Value | Threshold                  | Pass |
|-------------------------------------|-------|----------------------------|------|
| email DLQ depth                     | —     | -                          | —    |
| DLQ payload-shape integrity check   | —     | original payload preserved | —    |
| alert.notifications.high_failure_rate fired | — | iff failed/dispatched > 5 % | — |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-DEDUP — `<run_id>` — `<ISO timestamp>`

#### Dedup correctness

| Metric                                                        | Value | Threshold | Pass |
|---------------------------------------------------------------|-------|-----------|------|
| dedup_violation_count                                         | —     | = 0       | —    |
| dispatched_count vs unique(Deduplication_Key) × recipients    | —     | dispatched ≤ unique × recipients | — |
| skipped_duplicate audit entries vs duplicates emitted         | —     | equal     | —    |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-PREFS — `<run_id>` — `<ISO timestamp>`

#### Preference correctness

| Metric                              | Value | Threshold        | Pass |
|-------------------------------------|-------|------------------|------|
| preference_violation_count          | —     | = 0              | —    |
| preference_resolution_p95_ms        | —     | ≤ 10 (G-L10)     | —    |
| critical bypass count               | —     | every critical event in QH delivered | — |
| self-suppression count              | —     | every actor==recipient suppressed   | — |
| mute_target enforcement count       | —     | every muted event suppressed (except un-mutable critical) | — |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

### SCN-CORRECTNESS — `<run_id>` — `<ISO timestamp>`

#### Cross-cutting correctness

| Metric                              | Value | Threshold | Pass |
|-------------------------------------|-------|-----------|------|
| authorization_violation_count       | —     | = 0       | —    |
| lifecycle_ordering_violation_count  | —     | = 0       | —    |
| replay_omission_count               | —     | = 0       | —    |

#### Verdict

- Status: **TBD**
- Notes: _(populated on first run)_

---

## Regression history

| Date | run_id | scenario | exceeded threshold | resolution |
|---|---|---|---|---|
| _(no regressions yet)_ | — | — | — | — |

---

## Traceability

| Section          | Requirements          | Tasks  |
|------------------|-----------------------|--------|
| Result blocks    | REQ 13.5, 13.6, 14.5  | 18.2   |
| Regression history | REQ 18.4, 18.6      | 18.2   |
