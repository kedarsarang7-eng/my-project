// ============================================================================
// shim/publisher.ts — SNS publisher proxy for the k6 load harness
// ============================================================================
//
// k6 cannot drive AWS SDK calls natively (the SDK is Node-only and pulls
// crypto / streams k6's runtime does not expose). The Node-side shim
// listens on loopback HTTP, accepts an EventContract envelope, runs it
// through the production validators (so the harness's surface matches
// the real publish boundary), then forwards to the production
// `publishEvent()` (or to a deterministic in-process recorder when
// `NOTIFICATIONS_LOAD_PUBLISHER_MODE=record`).
//
// Modes:
//   - `live`     — call the real `publishEvent` against the configured
//                  AWS account. Requires `SNS_TOPIC_ARN` to be set.
//                  Use only against the non-prod stack per §5.2.
//   - `record`   — bypass AWS; record every publish into an in-memory
//                  ledger and return a synthetic ack. Default for local
//                  dev so a developer can run the k6 scripts without
//                  AWS credentials.
//   - `dryrun`   — validate only; never call AWS, never record. Useful
//                  for verifier rehearsals.
//
// Usage:
//   npx ts-node my-backend/tests/notifications/load/shim/publisher.ts
//
// The HTTP surface is tiny — three endpoints — so we use raw `http`
// rather than dragging in Express. The shim is test infrastructure only;
// production callers must go through `Notification_Service` directly.
//
// All knobs (port, mode, max-payload) are surfaced as env vars so the
// k6 runner / CI workflow controls them without code changes.
//
// Validates: phase5-load-plan.md §4.1 ("a thin Node/TypeScript shim for
// protocol pieces k6 cannot drive natively"), §4.2 (file location).
// ============================================================================

import * as http from 'http';

import {
    publishEvent,
    type PublishAck,
} from '../../../src/notifications/event-bus/publisher';
import {
    EventContractValidationError,
    EventBusUnavailableError,
} from '../../../src/notifications/event-bus/errors';
import {
    redactPayload,
    STRICT_REDACTION_CONFIG,
} from '../../../src/notifications/service/redaction';
import { sanitizePayload } from '../../../src/notifications/service/sanitization';
import type { EventContract } from '../../../src/notifications/event-bus/types';

// ----------------------------------------------------------------------------
// Configuration
// ----------------------------------------------------------------------------

type ShimMode = 'live' | 'record' | 'dryrun';

interface ShimConfig {
    readonly port: number;
    readonly mode: ShimMode;
    readonly maxPayloadBytes: number;
}

function readConfig(env: NodeJS.ProcessEnv = process.env): ShimConfig {
    const rawPort = env.NOTIFICATIONS_LOAD_PUBLISHER_PORT ?? '8787';
    const port = Number.parseInt(rawPort, 10);
    if (!Number.isFinite(port) || port <= 0 || port > 65_535) {
        throw new Error(
            `publisher.ts: invalid NOTIFICATIONS_LOAD_PUBLISHER_PORT=${rawPort}`,
        );
    }
    const rawMode = (env.NOTIFICATIONS_LOAD_PUBLISHER_MODE ?? 'record').toLowerCase();
    if (rawMode !== 'live' && rawMode !== 'record' && rawMode !== 'dryrun') {
        throw new Error(
            `publisher.ts: invalid NOTIFICATIONS_LOAD_PUBLISHER_MODE=${rawMode} ` +
                `(expected 'live' | 'record' | 'dryrun')`,
        );
    }
    // §3.5 — refuse anything above the 16 KB SNS soft ceiling.
    const maxPayloadBytes = 16 * 1024;
    return { port, mode: rawMode as ShimMode, maxPayloadBytes };
}

// ----------------------------------------------------------------------------
// In-memory ledger (used by `record` and `dryrun` modes)
// ----------------------------------------------------------------------------

export interface PublishLedgerEntry {
    readonly id: string;
    readonly event_name: string;
    readonly priority: string;
    readonly category: string;
    readonly source_app: string;
    readonly received_at: string;
    readonly mode: ShimMode;
    readonly bytes: number;
}

class PublishLedger {
    private readonly entries: PublishLedgerEntry[] = [];

    public record(entry: PublishLedgerEntry): void {
        this.entries.push(entry);
    }

    public list(): readonly PublishLedgerEntry[] {
        return this.entries.slice();
    }

    public size(): number {
        return this.entries.length;
    }

    public clear(): void {
        this.entries.length = 0;
    }
}

const ledger = new PublishLedger();

// ----------------------------------------------------------------------------
// HTTP wiring
// ----------------------------------------------------------------------------

interface PublishResponse {
    readonly ok: true;
    readonly mode: ShimMode;
    readonly messageId: string;
    readonly bytes: number;
}

interface ValidationResponse {
    readonly ok: false;
    readonly code: 'validation_error';
    readonly issues: readonly { field: string; message: string }[];
}

interface PayloadTooLargeResponse {
    readonly ok: false;
    readonly code: 'payload_too_large';
    readonly bytes: number;
    readonly limit: number;
}

interface BusUnavailableResponse {
    readonly ok: false;
    readonly code: 'bus_unavailable';
    readonly message: string;
}

type PublishOutcome =
    | PublishResponse
    | ValidationResponse
    | PayloadTooLargeResponse
    | BusUnavailableResponse;

/**
 * Process a single publish request. Exposed for unit tests and for the
 * verifier shim, which exercises the same code path without going
 * through HTTP.
 *
 * The function applies the same defense-in-depth chain as
 * `Notification_Service.createNotification`: sanitise → redact → publish.
 * It does NOT persist a NotificationRecord — the SUT's `consumer.ts`
 * remains responsible for that on the real path.
 */
export async function processPublish(
    rawEvent: unknown,
    config: ShimConfig,
): Promise<PublishOutcome> {
    const bytes = Buffer.byteLength(JSON.stringify(rawEvent ?? null), 'utf8');
    if (bytes > config.maxPayloadBytes) {
        return {
            ok: false,
            code: 'payload_too_large',
            bytes,
            limit: config.maxPayloadBytes,
        };
    }

    // Defense-in-depth: sanitise + redact the payload field BEFORE the
    // bus-side validators see it. Mirrors the `notification.service.ts`
    // pre-persist chain so the harness exercises the production guards.
    let event: EventContract;
    try {
        const cloned = cloneAndCleanse(rawEvent);
        event = cloned;
    } catch (err) {
        return {
            ok: false,
            code: 'validation_error',
            issues: [
                {
                    field: '<root>',
                    message:
                        err instanceof Error
                            ? err.message
                            : 'unknown sanitisation error',
                },
            ],
        };
    }

    // Per-mode dispatch.
    if (config.mode === 'dryrun') {
        return {
            ok: true,
            mode: 'dryrun',
            messageId: `dryrun-${event.id}`,
            bytes,
        };
    }
    if (config.mode === 'record') {
        ledger.record({
            id: event.id,
            event_name: event.event_name,
            priority: event.priority,
            category: event.category,
            source_app: event.source_app,
            received_at: new Date().toISOString(),
            mode: 'record',
            bytes,
        });
        return {
            ok: true,
            mode: 'record',
            messageId: `record-${event.id}`,
            bytes,
        };
    }

    // `live` mode — call the real production publisher.
    try {
        const ack: PublishAck = await publishEvent(event);
        ledger.record({
            id: event.id,
            event_name: event.event_name,
            priority: event.priority,
            category: event.category,
            source_app: event.source_app,
            received_at: new Date().toISOString(),
            mode: 'live',
            bytes,
        });
        return { ok: true, mode: 'live', messageId: ack.messageId, bytes };
    } catch (err) {
        if (err instanceof EventContractValidationError) {
            return {
                ok: false,
                code: 'validation_error',
                issues: err.issues.map((i) => ({
                    field: i.field,
                    message: i.message,
                })),
            };
        }
        if (err instanceof EventBusUnavailableError) {
            return {
                ok: false,
                code: 'bus_unavailable',
                message: err.message,
            };
        }
        return {
            ok: false,
            code: 'bus_unavailable',
            message: err instanceof Error ? err.message : String(err),
        };
    }
}

/**
 * Sanitise + redact the payload field of the inbound event. Returns a
 * fresh object — the input is never mutated.
 *
 * Rejects payloads where `payload` is not an object (the bus validator
 * would reject downstream anyway, but rejecting early keeps the error
 * shape consistent for the k6 client).
 */
function cloneAndCleanse(rawEvent: unknown): EventContract {
    if (!rawEvent || typeof rawEvent !== 'object') {
        throw new Error('event must be an object');
    }
    const event = { ...(rawEvent as Record<string, unknown>) } as Record<
        string,
        unknown
    >;
    const payload = event.payload;
    if (payload === undefined || payload === null) {
        event.payload = {};
    } else if (typeof payload !== 'object' || Array.isArray(payload)) {
        throw new Error('event.payload must be a plain object');
    } else {
        const sanitised = sanitizePayload(payload as Record<string, unknown>);
        const redacted = redactPayload(sanitised, STRICT_REDACTION_CONFIG);
        event.payload = redacted;
    }
    return event as unknown as EventContract;
}

// ----------------------------------------------------------------------------
// HTTP server
// ----------------------------------------------------------------------------

function createServer(config: ShimConfig): http.Server {
    return http.createServer(async (req, res) => {
        try {
            if (req.method === 'GET' && req.url === '/health') {
                writeJson(res, 200, { ok: true, mode: config.mode });
                return;
            }
            if (req.method === 'GET' && req.url === '/ledger') {
                writeJson(res, 200, {
                    ok: true,
                    mode: config.mode,
                    size: ledger.size(),
                    entries: ledger.list(),
                });
                return;
            }
            if (req.method === 'DELETE' && req.url === '/ledger') {
                ledger.clear();
                writeJson(res, 200, { ok: true, cleared: true });
                return;
            }
            if (req.method === 'POST' && req.url === '/publish') {
                const body = await readBody(req, config.maxPayloadBytes + 4096);
                const parsed: unknown = JSON.parse(body);
                const outcome = await processPublish(parsed, config);
                const status = outcome.ok
                    ? 200
                    : outcome.code === 'validation_error'
                        ? 400
                        : outcome.code === 'payload_too_large'
                            ? 413
                            : 503;
                writeJson(res, status, outcome);
                return;
            }
            writeJson(res, 404, { ok: false, code: 'not_found' });
        } catch (err) {
            // The shim is best-effort — we do NOT let a single bad
            // request crash the test runner. Surface a structured error
            // and keep the listener alive.
            writeJson(res, 500, {
                ok: false,
                code: 'shim_error',
                message: err instanceof Error ? err.message : String(err),
            });
        }
    });
}

function writeJson(
    res: http.ServerResponse,
    status: number,
    body: unknown,
): void {
    const json = JSON.stringify(body);
    res.statusCode = status;
    res.setHeader('content-type', 'application/json');
    res.setHeader('content-length', Buffer.byteLength(json, 'utf8'));
    res.end(json);
}

function readBody(req: http.IncomingMessage, limit: number): Promise<string> {
    return new Promise<string>((resolve, reject) => {
        const chunks: Buffer[] = [];
        let total = 0;
        req.on('data', (chunk: Buffer) => {
            total += chunk.length;
            if (total > limit) {
                req.destroy();
                reject(new Error('request body exceeds limit'));
                return;
            }
            chunks.push(chunk);
        });
        req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
        req.on('error', reject);
    });
}

// ----------------------------------------------------------------------------
// Entry point — only when invoked directly (e.g. `ts-node publisher.ts`)
// ----------------------------------------------------------------------------

export function startShim(env: NodeJS.ProcessEnv = process.env): http.Server {
    const config = readConfig(env);
    const server = createServer(config);
    server.listen(config.port, () => {
        // eslint-disable-next-line no-console
        console.log(
            `[load/shim/publisher] listening on :${config.port} (mode=${config.mode})`,
        );
    });
    return server;
}

// Run only when invoked as a script.
if (require.main === module) {
    startShim();
}

// ----------------------------------------------------------------------------
// Test seam
// ----------------------------------------------------------------------------

export const __test__ = Object.freeze({
    readConfig,
    cloneAndCleanse,
    ledger,
});
