# UNS Phase 5 — Load Test Harness

This directory implements the load test runner for the Unified Notification System (UNS), per [`phase5-load-plan.md`](../../../../.kiro/specs/unified-notification-system/phase5-load-plan.md). It satisfies task **18.2** of the spec and pairs with task **18.3** (chaos test, under `tests/notifications/chaos/`).

## What's in here

```
tests/notifications/load/
├── README.md                    ← this file
├── k6/                          ← k6 scenario scripts (one per SCN-* in §2)
│   ├── steady.js                  SCN-STEADY (incl. 100 / 1 000 / 10 000 sweep)  [working]
│   ├── burst.js                   SCN-BURST                                       [working]
│   ├── correctness.js             SCN-CORRECTNESS sidecar                         [working]
│   ├── sustained-high.js          SCN-SUSTAINED-HIGH                              [stub: §2.3 TODO]
│   ├── hotkey.js                  SCN-HOTKEY                                      [stub: §2.4 TODO]
│   ├── mix.js                     SCN-MIX                                         [stub: §2.5 TODO]
│   ├── slow-channel.js            SCN-SLOW-CHANNEL                                [stub: §2.6 TODO]
│   ├── dedup.js                   SCN-DEDUP                                       [stub: §2.7 TODO]
│   ├── prefs.js                   SCN-PREFS                                       [stub: §2.8 TODO]
│   └── lib/
│       ├── thresholds.ts            §6.2 / §7 SLOs as k6 thresholds
│       ├── workload-mix.ts          §3.2 / §3.3 / §3.4 / §3.5 generators
│       └── recipients.ts            10 000-user seed + role / tenant partitioning
├── shim/                        ← Node/TypeScript adjuncts driven by k6
│   ├── publisher.ts               SNS publisher proxy (loopback HTTP)
│   ├── channel-fault.ts           latency-spike + transient-failure injector
│   ├── offline-replay.ts          offline / reconnect controller
│   └── verifier.ts                post-run dedup / authz / preference / replay checks
└── seeds/
    └── users.json                 representative seed shape (§3.3 / §3.4)
```

The 3 working scripts (`steady.js`, `burst.js`, `correctness.js`) exercise the highest-value scenarios end-to-end. The 6 stub scripts have a wired-up configuration block, threshold map, and `setup()` so they are runnable as smoke tests; their scenario logic carries `TODO` comments listing the remaining §2 expectations to implement once a non-prod SUT environment is provisioned (§5.2).

## Prerequisites

- **k6 v0.53+** — required for native TypeScript support of the `lib/*.ts` modules. ([k6 install docs](https://grafana.com/docs/k6/latest/set-up/install-k6/))
  ```bash
  # macOS
  brew install k6
  # Linux (apt)
  sudo apt-get install k6
  # Windows (choco)
  choco install k6
  ```
  If you are stuck on an older k6, build the lib files into JS first:
  ```bash
  npx tsc --project tsconfig.k6lib.json
  ```
- **Node.js ≥ 20** — the shim files run on the same Node version as `my-backend/`.
- **AWS access** (only for `live` mode of the publisher shim) — non-prod credentials with permission to publish to the configured SNS topic. Per §5.2, do NOT run against the production stack.

## Running the harness

The harness is a hybrid: k6 runs the load and the Node-side shim handles AWS calls k6 cannot drive natively.

### 1. Start the publisher shim

```bash
# In one terminal — local dev, no AWS calls
NOTIFICATIONS_LOAD_PUBLISHER_MODE=record \
  npx ts-node --transpile-only my-backend/tests/notifications/load/shim/publisher.ts

# Or, against a non-prod AWS stack
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:000:uns-events-staging \
  NOTIFICATIONS_LOAD_PUBLISHER_MODE=live \
  npx ts-node --transpile-only my-backend/tests/notifications/load/shim/publisher.ts
```

The shim listens on `http://localhost:8787` by default. Configure with:

| Env                                       | Default  | Purpose                                                                    |
|-------------------------------------------|----------|----------------------------------------------------------------------------|
| `NOTIFICATIONS_LOAD_PUBLISHER_PORT`       | `8787`   | HTTP port the shim binds to.                                                |
| `NOTIFICATIONS_LOAD_PUBLISHER_MODE`       | `record` | `live` — call real `publishEvent`. `record` — synthetic ack, ledger only. `dryrun` — validate only. |
| `SNS_TOPIC_ARN`                           | _(unset)_ | Required for `live` mode.                                                   |

### 2. Run a scenario

```bash
# SCN-STEADY at 1 000 recipients (REQ 13.5 mid-scale mark)
k6 run \
  --env RUN_ID=$(date -u +%Y%m%dT%H%M%S) \
  --env PUBLISHER_URL=http://localhost:8787 \
  --env CONCURRENT_USERS=500 \
  --env EVENTS_PER_SECOND=2000 \
  --env DURATION_SECONDS=300 \
  --env RECIPIENT_SCALE=1000 \
  --summary-export=phase5-load-results/$RUN_ID/k6-summary.json \
  my-backend/tests/notifications/load/k6/steady.js

# SCN-BURST
k6 run \
  --env RUN_ID=$RUN_ID \
  --env PUBLISHER_URL=http://localhost:8787 \
  --env BASELINE_EPS=2000 \
  --env BURST_PEAK_EPS=20000 \
  --summary-export=phase5-load-results/$RUN_ID/burst-summary.json \
  my-backend/tests/notifications/load/k6/burst.js

# SCN-CORRECTNESS sidecar (run alongside any of the above)
k6 run \
  --env RUN_ID=$RUN_ID \
  --env PUBLISHER_URL=http://localhost:8787 \
  --env SUT_BASE_URL=https://api.staging.uns.example.com \
  --env AUTH_TOKEN=<bearer> \
  --env DURATION_SECONDS=300 \
  --env OFFLINE_RATIO=0.05 \
  my-backend/tests/notifications/load/k6/correctness.js
```

### 3. Run the verifier (post-scenario)

```bash
# Verifier takes the captured deliveries NDJSON and emits violations.ndjson
node -e '
const v = require("./my-backend/tests/notifications/load/shim/verifier");
const fs = require("fs");
const deliveries = fs.readFileSync(process.env.DELIVERIES_FILE, "utf8")
  .split("\n").filter(Boolean).map(JSON.parse);
v.verify({ deliveries, outDir: process.env.OUT_DIR })
  .then(({ summary }) => console.log(JSON.stringify(summary, null, 2)));
'
```

## Configuration knobs (§4.3)

Every knob is surfaced as an env / `--env` CLI flag and recorded verbatim in the result file's `Configuration` block:

| Knob                            | Used by                                | Default   | Source            |
|---------------------------------|----------------------------------------|-----------|-------------------|
| `RUN_ID`                        | every script                           | `local-dev` | required for namespacing per §5.4 |
| `CONCURRENT_USERS`              | `steady.js`                            | `500`     | G-T2              |
| `EVENTS_PER_SECOND`             | `steady`, `mix`, `hotkey`, `dedup`, `prefs`, `slow-channel` | `2000` | G-T3 |
| `DURATION_SECONDS`              | every script (except `burst`, `sustained-high`) | `300` | §2.1 |
| `BURST_PEAK_EPS`                | `burst.js`                             | `20000`   | G-T4              |
| `BASELINE_EPS`                  | `burst.js`                             | `2000`    | G-T3              |
| `SUSTAINED_HIGH_EPS`            | `sustained-high.js`                    | `6000`    | G-T5              |
| `SUSTAINED_HIGH_MINUTES`        | `sustained-high.js`                    | `30`      | G-T5              |
| `HOTKEY_TENANT_SHARE`           | `hotkey.js`                            | `0.4`     | §2.4 (proposed)   |
| `HOTKEY_EVENT_SHARE`            | `hotkey.js`                            | `0.35`    | §2.4 (proposed)   |
| `CHANNEL_FAULT_TARGET`          | `slow-channel.js`                      | `email`   | §2.6              |
| `CHANNEL_FAULT_LATENCY_MS`      | `slow-channel.js`                      | `2000`    | §2.6              |
| `CHANNEL_FAULT_WINDOW_SECONDS`  | `slow-channel.js`                      | `120`     | §2.6              |
| `DEDUP_DUPLICATE_RATIO`         | `dedup.js`                             | `0.25`    | §2.7              |
| `PREFERENCE_SHAPE`              | `prefs.js`                             | `default` | §2.8              |
| `RECIPIENT_SCALE`               | every script                           | `10000`   | G-T1 / REQ 13.5   |
| `TENANT_COUNT`                  | every script                           | `50`      | §3.3              |
| `SEED`                          | every script                           | _(derived from RUN_ID)_ | reproducibility |

## What each scenario validates

| Script                | Scenario          | Hard SLOs                                                                                  | Soft SLOs (proposed)                                |
|-----------------------|-------------------|--------------------------------------------------------------------------------------------|----------------------------------------------------|
| `steady.js`           | SCN-STEADY        | in-app p95 ≤ 500 ms; p95 ≥ 1 ms; unread p95 ≤ 50 ms; history p95 ≤ 200 ms; availability > 99.9 %; zero event loss / dedup / authz / preference / replay violations | error budget ≤ 1 %                                |
| `burst.js`            | SCN-BURST         | zero event loss; in-app returns to ≤ 500 ms within drain window                            | drain ≤ 120 s; peak ≥ 18 000 eps                   |
| `correctness.js`      | SCN-CORRECTNESS   | zero authz / replay / lifecycle-ordering violations                                        | —                                                  |
| `sustained-high.js`   | SCN-SUSTAINED-HIGH| latency table holds for 30 min; max queue depth ≤ 60 000                                   | no observable memory leak                           |
| `hotkey.js`           | SCN-HOTKEY        | hot-tenant in-app p95 ≤ 500 ms; non-hot within ±10 % of SCN-STEADY                         | dedup G-C3 holds                                    |
| `mix.js`              | SCN-MIX           | per-channel p95 within §6.2 budgets; failure isolation invariant                          | —                                                  |
| `slow-channel.js`     | SCN-SLOW-CHANNEL  | non-faulted channels within ±10 %; faulted DLQ payload preserved; alert correctness G-C7   | —                                                  |
| `dedup.js`            | SCN-DEDUP         | dedup violations = 0; dispatched ≤ unique × recipients                                    | —                                                  |
| `prefs.js`            | SCN-PREFS         | preference violations = 0; preference resolution p95 ≤ 10 ms                              | —                                                  |

## Output artefacts (§8)

After each run the harness publishes:

```
.kiro/specs/unified-notification-system/phase5-load-results/<RUN_ID>/
├── k6-summary.json       raw k6 JSON output (--summary-export)
├── metrics.json          captured metric series (5-min windowed values)
├── violations.ndjson     verifier output (empty on a clean run)
└── logs.ndjson           structured lifecycle logs from REQ 14.1
```

The human-readable summary lives at:

```
.kiro/specs/unified-notification-system/phase5-load-results.md
```

with one block per scenario per the §8 template. The skeleton is committed; CI fills the per-run blocks.

## Design notes

- **k6 is the primary load runner**, hybrid with Node/TypeScript shim per §4.1 — this is the choice the load plan locked in.
- **`shim/channel-fault.ts` is the shared fault-injection surface** between this load harness and the chaos test under `tests/notifications/chaos/`. Once the chaos test's local copy is migrated to a re-export from this directory (header note in that file), there is exactly one implementation.
- **`shim/verifier.ts` REUSES the production authz and preference modules** rather than re-implementing them, per §9.1 risk row. This means a behavioural change in the SUT propagates to the verifier without a corresponding shim change.
- **Determinism**: every generator (population, workload mix, dedup duplicates) is seeded by `RUN_ID` so a re-run is bit-identical absent a SUT change.
- **Namespace safety**: every emitted event carries `loadtest-<run_id>-` prefixed identifiers per §5.4 and the verifier asserts that prefix exists.

## Out-of-scope (§9.2)

- Production load testing (non-prod stack only, §5.2).
- Real provider quota validation — channels are stubbed (§5.3).
- Multi-region failover under load (single-region in Phase 3).
- Browser-side WebSocket scaling beyond 10 000 (G-T1 ceiling).

## Related work

- Load plan: [`.kiro/specs/unified-notification-system/phase5-load-plan.md`](../../../../.kiro/specs/unified-notification-system/phase5-load-plan.md)
- Results doc: [`.kiro/specs/unified-notification-system/phase5-load-results.md`](../../../../.kiro/specs/unified-notification-system/phase5-load-results.md)
- Chaos test: `my-backend/tests/notifications/chaos/`
- Reference k6 example: `my-backend/tests/k6-load-test.js`
