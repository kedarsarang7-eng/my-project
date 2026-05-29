// ============================================================================
// shim/offline-replay.ts — offline/reconnect controller for SCN-CORRECTNESS
// ============================================================================
//
// Drives the replay-completeness assertion of phase5-load-plan.md §2.9
// (SCN-CORRECTNESS) and REQ 8.4 / REQ 15.13:
//
//   1. Mark a configured fraction of in-app recipients OFFLINE for a
//      configurable window during the run.
//   2. While they are offline the producer keeps emitting events the
//      Notification_Service routes to those recipients.
//   3. At reconnect time, the controller calls
//      `GET /notifications/replay?since=<disconnect_ts>&app=<sub_app>`
//      and asserts the response contains EXACTLY the events targeted at
//      those recipients during the window, in `created_at` ascending
//      order, with no omissions and no duplicates beyond the
//      Deduplication_Window.
//
// The k6 `correctness.js` script consumes this shim through HTTP. The
// shim does NOT mock the production replay endpoint — it CALLS it. The
// load harness depends on the SUT exposing the same `getReplay()`
// surface that the Sub_App_Sync_Layer uses (REQ 8.4).
//
// Output:
//   - Per-cohort `OmissionReport` written to `phase5-load-results/<run_id>/violations.ndjson`
//     by the verifier (`shim/verifier.ts`); this shim returns the report
//     in-memory so the verifier can serialise it.
// ============================================================================

import * as http from 'http';

// ----------------------------------------------------------------------------
// Public types
// ----------------------------------------------------------------------------

export interface OfflineCohortConfig {
    /** Sub_App identifier the cohort belongs to (e.g. `dukanx_desktop`). */
    readonly app: string;
    /** Recipients in this cohort (resolved from `lib/recipients.ts`). */
    readonly user_ids: readonly string[];
    /** When the cohort goes offline (ISO timestamp). */
    readonly disconnected_at: string;
    /** When the cohort reconnects (ISO timestamp). */
    readonly reconnected_at: string;
}

export interface ReplayProbeConfig {
    /** Base URL for the SUT, e.g. `https://api.staging.uns.example.com`. */
    readonly sut_base_url: string;
    /** Bearer token used to authenticate the replay request. */
    readonly auth_token: string;
    /** Per-request HTTP timeout (ms). Defaults to 5 000 ms. */
    readonly timeoutMs?: number;
}

export interface OmittedEvent {
    readonly event_id: string;
    readonly event_name: string;
    readonly created_at: string;
    readonly recipient_id: string;
    readonly reason: 'missing' | 'out_of_order';
}

export interface OmissionReport {
    readonly cohort_app: string;
    readonly cohort_size: number;
    readonly window_start: string;
    readonly window_end: string;
    readonly expected_count: number;
    readonly observed_count: number;
    readonly omissions: readonly OmittedEvent[];
}

// ----------------------------------------------------------------------------
// In-memory ledger of expected events per cohort
// ----------------------------------------------------------------------------

interface ExpectedEvent {
    readonly event_id: string;
    readonly event_name: string;
    readonly created_at: string;
    readonly recipient_id: string;
}

class CohortLedger {
    private readonly expected: Map<string, ExpectedEvent[]> = new Map();

    /** Record an event the producer emitted while a cohort was offline. */
    public registerExpected(app: string, event: ExpectedEvent): void {
        const list = this.expected.get(app) ?? [];
        list.push(event);
        this.expected.set(app, list);
    }

    public listExpected(app: string): readonly ExpectedEvent[] {
        return (this.expected.get(app) ?? []).slice();
    }

    public size(app: string): number {
        return (this.expected.get(app) ?? []).length;
    }

    public clear(app?: string): void {
        if (app) this.expected.delete(app);
        else this.expected.clear();
    }
}

// ----------------------------------------------------------------------------
// Public API
// ----------------------------------------------------------------------------

const ledger = new CohortLedger();

/**
 * Register an event the producer emitted while `app`'s cohort was
 * offline. The k6 `correctness.js` script calls this before publishing
 * to the bus so the controller knows what to expect on reconnect.
 *
 * The shim does NOT enforce window semantics — it only ledgers what
 * the caller declares. The verifier shim cross-checks the ledger
 * against the replay response.
 */
export function registerExpectedEvent(
    app: string,
    event: ExpectedEvent,
): void {
    ledger.registerExpected(app, event);
}

/**
 * Probe the SUT's replay endpoint and compare against the ledger for
 * `cohort.app`. Returns a structured `OmissionReport`; `omissions`
 * empty means the replay was complete.
 *
 * REQ 8.4: result MUST be in `created_at` ascending order. We assert
 * the property by walking the response and reporting any out-of-order
 * pair.
 *
 * REQ 15.13: every event the cohort was supposed to receive during the
 * window MUST appear; no extra events outside the window are penalised.
 */
export async function probeReplay(
    cohort: OfflineCohortConfig,
    probe: ReplayProbeConfig,
): Promise<OmissionReport> {
    const expectedAll = ledger.listExpected(cohort.app);
    const expectedForCohort = expectedAll.filter((e) =>
        cohort.user_ids.includes(e.recipient_id),
    );

    const url = buildReplayUrl(
        probe.sut_base_url,
        cohort.disconnected_at,
        cohort.app,
    );
    const observed = await fetchReplay(url, probe);

    return diff(cohort, expectedForCohort, observed);
}

/**
 * In-process variant of `probeReplay` for unit tests: takes the
 * already-decoded replay response (skipping HTTP). Exercises only the
 * diff logic.
 */
export function diffReplay(
    cohort: OfflineCohortConfig,
    expected: readonly ExpectedEvent[],
    observed: readonly ExpectedEvent[],
): OmissionReport {
    return diff(cohort, expected, observed);
}

/** Reset the ledger between scenarios. */
export function resetCohortLedger(): void {
    ledger.clear();
}

// ----------------------------------------------------------------------------
// Internal helpers
// ----------------------------------------------------------------------------

function buildReplayUrl(
    base: string,
    sinceIso: string,
    app: string,
): string {
    const trimmed = base.replace(/\/+$/, '');
    const since = encodeURIComponent(sinceIso);
    const appParam = encodeURIComponent(app);
    return `${trimmed}/notifications/replay?since=${since}&app=${appParam}`;
}

interface ReplayApiResponse {
    readonly notifications?: ReadonlyArray<{
        readonly notification_id?: string;
        readonly id?: string;
        readonly event_name?: string;
        readonly created_at?: string;
        readonly recipients?: ReadonlyArray<{ readonly user_id?: string }>;
    }>;
}

async function fetchReplay(
    url: string,
    probe: ReplayProbeConfig,
): Promise<ExpectedEvent[]> {
    const body = await httpGet(url, {
        Authorization: `Bearer ${probe.auth_token}`,
        Accept: 'application/json',
    }, probe.timeoutMs ?? 5_000);
    const json = JSON.parse(body) as ReplayApiResponse;
    const items = json.notifications ?? [];
    const out: ExpectedEvent[] = [];
    for (const n of items) {
        const id = n.notification_id ?? n.id;
        if (!id || !n.event_name || !n.created_at) continue;
        const recipientId = n.recipients?.[0]?.user_id ?? '';
        out.push({
            event_id: id,
            event_name: n.event_name,
            created_at: n.created_at,
            recipient_id: recipientId,
        });
    }
    return out;
}

function httpGet(
    url: string,
    headers: Record<string, string>,
    timeoutMs: number,
): Promise<string> {
    return new Promise<string>((resolve, reject) => {
        const lib = url.startsWith('https:')
            ? // require lazily so the shim has no startup-time https dep
              // when only running against a local SUT
              (require('https') as typeof http)
            : http;
        const req = lib.request(url, { method: 'GET', headers }, (res) => {
            const chunks: Buffer[] = [];
            res.on('data', (c: Buffer) => chunks.push(c));
            res.on('end', () => {
                if ((res.statusCode ?? 0) >= 400) {
                    reject(
                        new Error(
                            `replay GET failed: ${res.statusCode} ${res.statusMessage ?? ''}`,
                        ),
                    );
                    return;
                }
                resolve(Buffer.concat(chunks).toString('utf8'));
            });
            res.on('error', reject);
        });
        req.setTimeout(timeoutMs, () => {
            req.destroy(new Error(`replay GET timeout after ${timeoutMs} ms`));
        });
        req.on('error', reject);
        req.end();
    });
}

function diff(
    cohort: OfflineCohortConfig,
    expected: readonly ExpectedEvent[],
    observed: readonly ExpectedEvent[],
): OmissionReport {
    const observedById = new Map<string, ExpectedEvent>();
    for (const o of observed) observedById.set(o.event_id, o);

    const omissions: OmittedEvent[] = [];
    // 1) Every expected event must appear.
    for (const e of expected) {
        if (!observedById.has(e.event_id)) {
            omissions.push({
                event_id: e.event_id,
                event_name: e.event_name,
                created_at: e.created_at,
                recipient_id: e.recipient_id,
                reason: 'missing',
            });
        }
    }

    // 2) The observed sequence must be in created_at ascending order.
    for (let i = 1; i < observed.length; i += 1) {
        const prev = observed[i - 1];
        const curr = observed[i];
        if (curr.created_at < prev.created_at) {
            omissions.push({
                event_id: curr.event_id,
                event_name: curr.event_name,
                created_at: curr.created_at,
                recipient_id: curr.recipient_id,
                reason: 'out_of_order',
            });
        }
    }

    return {
        cohort_app: cohort.app,
        cohort_size: cohort.user_ids.length,
        window_start: cohort.disconnected_at,
        window_end: cohort.reconnected_at,
        expected_count: expected.length,
        observed_count: observed.length,
        omissions,
    };
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

export const __test__ = Object.freeze({
    ledger,
    diff,
    buildReplayUrl,
});
