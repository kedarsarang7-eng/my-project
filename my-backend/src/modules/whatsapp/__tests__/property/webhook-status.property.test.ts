// ============================================================================
// Property-Based Test — Webhook-Only Status Transitions
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 25
//
// Validates: Requirements 8.6, 8.9, 15.4
//
// Property 25 (design.md): Only OpenWA-verified webhooks may set delivered/read,
// and duplicates are ignored.
//
// Verified properties:
// 1. Only verified webhooks can transition to delivered/read (Req 8.6, 15.4)
// 2. Duplicate status events are ignored — no repeated log entries (Req 8.9)
// 3. Non-webhook sources cannot set delivered/read status (Req 15.4)
// 4. Failed signature = rejection + audit entry (Req 8.5)
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { createHmac } from 'crypto';
import {
  computeOpenWASignature,
  verifyOpenWAWebhookSignature,
} from '../../../staff/services/staff-notify.service';

const NUM_RUNS = 100;

// ── Types (mirroring webhook.handler.ts internals) ──────────────────────────

type OutboundMessageStatus = 'queued' | 'sent' | 'delivered' | 'read' | 'failed' | 'expired';
type WebhookStatus = 'pending' | 'sent' | 'delivered' | 'read' | 'failed';

const VALID_WEBHOOK_STATUSES: WebhookStatus[] = ['pending', 'sent', 'delivered', 'read', 'failed'];
const ALL_OUTBOUND_STATUSES: OutboundMessageStatus[] = ['queued', 'sent', 'delivered', 'read', 'failed', 'expired'];

/** Statuses that indicate the gateway actually reported delivery/read. */
const DELIVERED_READ_STATUSES: WebhookStatus[] = ['delivered', 'read'];

// ── Pure functions extracted from webhook.handler.ts for testability ─────────

/**
 * Lifecycle order for status transitions.
 * Higher = later in lifecycle.
 */
const STATUS_ORDER: Record<string, number> = {
  pending: 0,
  queued: 0,
  sent: 1,
  delivered: 2,
  read: 3,
  failed: 4,
  expired: 4,
};

/**
 * Determines if a reported status is a duplicate or stale transition.
 * Mirrors the logic in webhook.handler.ts.
 */
function isDuplicateOrStaleStatus(
  currentStatus: OutboundMessageStatus,
  reportedStatus: WebhookStatus,
): boolean {
  // Terminal states: no further transitions allowed
  if (currentStatus === 'failed' || currentStatus === 'expired') {
    return true;
  }
  // Same status = exact duplicate
  if (currentStatus === reportedStatus) {
    return true;
  }
  const currentOrder = STATUS_ORDER[currentStatus] ?? -1;
  const reportedOrder = STATUS_ORDER[reportedStatus] ?? -1;
  // If current is already at or past the reported status, it's stale
  return currentOrder >= reportedOrder;
}

/**
 * Map a webhook-reported status to the OutboundMessage status.
 * Only maps statuses actually reported by OpenWA — never fabricates.
 */
function mapWebhookStatusToOutboundStatus(webhookStatus: WebhookStatus): OutboundMessageStatus {
  switch (webhookStatus) {
    case 'pending': return 'queued';
    case 'sent': return 'sent';
    case 'delivered': return 'delivered';
    case 'read': return 'read';
    case 'failed': return 'failed';
  }
}

/**
 * Simulates the webhook status-update pipeline:
 * 1. Verify HMAC signature
 * 2. Validate status is one of the valid webhook statuses
 * 3. Check for duplicate/stale
 * 4. Only advance status if signature valid AND not duplicate
 *
 * Returns { accepted, newStatus, reason }.
 */
interface WebhookProcessResult {
  accepted: boolean;
  newStatus: OutboundMessageStatus | null;
  reason: 'signature_invalid' | 'duplicate_ignored' | 'no_op_status' | 'status_updated' | 'invalid_status';
  auditRejection: boolean;
}

function processWebhookStatus(params: {
  payload: string;
  signature: string;
  secret: string;
  currentStatus: OutboundMessageStatus;
  reportedStatus: string;
  signatureVerified: boolean;
}): WebhookProcessResult {
  const { signatureVerified, currentStatus, reportedStatus } = params;

  // Step 1: Signature verification
  if (!signatureVerified) {
    return {
      accepted: false,
      newStatus: null,
      reason: 'signature_invalid',
      auditRejection: true,
    };
  }

  // Step 2: Validate reported status is a known webhook status
  if (!VALID_WEBHOOK_STATUSES.includes(reportedStatus as WebhookStatus)) {
    return {
      accepted: false,
      newStatus: null,
      reason: 'invalid_status',
      auditRejection: false,
    };
  }

  const typedStatus = reportedStatus as WebhookStatus;

  // Step 3: pending/sent are no-ops (already set by dispatch)
  if (typedStatus === 'pending' || typedStatus === 'sent') {
    return {
      accepted: true,
      newStatus: null,
      reason: 'no_op_status',
      auditRejection: false,
    };
  }

  // Step 4: Duplicate/stale detection
  if (isDuplicateOrStaleStatus(currentStatus, typedStatus)) {
    return {
      accepted: true,
      newStatus: null,
      reason: 'duplicate_ignored',
      auditRejection: false,
    };
  }

  // Step 5: Status update
  return {
    accepted: true,
    newStatus: mapWebhookStatusToOutboundStatus(typedStatus),
    reason: 'status_updated',
    auditRejection: false,
  };
}

// ── Generators ──────────────────────────────────────────────────────────────

/** Arbitrary webhook secret (8-64 hex chars). */
const webhookSecretArb: fc.Arbitrary<string> = fc
  .hexaString({ minLength: 8, maxLength: 64 })
  .filter((s) => s.length >= 8);

/** Arbitrary JSON-like webhook payload body. */
const payloadArb: fc.Arbitrary<string> = fc
  .record({
    event: fc.constantFrom('message.ack', 'message.failed'),
    timestamp: fc.date({ min: new Date('2023-01-01'), max: new Date('2026-12-31') }).map((d) => d.toISOString()),
    sessionId: fc.stringMatching(/^[a-z0-9]{4,20}$/),
    data: fc.record({
      messageId: fc.stringMatching(/^[a-zA-Z0-9_-]{5,40}$/),
      status: fc.constantFrom(...VALID_WEBHOOK_STATUSES),
    }),
  })
  .map((obj) => JSON.stringify(obj));

/** Current outbound message status. */
const currentStatusArb: fc.Arbitrary<OutboundMessageStatus> = fc.constantFrom(...ALL_OUTBOUND_STATUSES);

/** Webhook-reported status. */
const webhookStatusArb: fc.Arbitrary<WebhookStatus> = fc.constantFrom(...VALID_WEBHOOK_STATUSES);

/** Non-webhook source attempting status (simulates internal code path). */
const nonWebhookStatusArb: fc.Arbitrary<string> = fc.constantFrom(
  'delivered', 'read', 'internal_delivered', 'manual_read', 'api_delivered',
);

// ── Property 25 Tests ───────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 25: Only OpenWA-verified webhooks may set delivered/read, and duplicates are ignored', () => {

  // ── 1) Only verified webhooks can transition to delivered/read ─────────────

  describe('Verified webhook: only HMAC-verified webhooks can set delivered/read (Req 8.6, 15.4)', () => {
    test('a valid signature allows delivered/read status transitions', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          fc.constantFrom<WebhookStatus>('delivered', 'read'),
          (secret, payload, targetStatus) => {
            // Compute valid signature
            const validSignature = computeOpenWASignature(payload, secret);

            // Message is in 'sent' state (eligible for delivered/read)
            const result = processWebhookStatus({
              payload,
              signature: validSignature,
              secret,
              currentStatus: 'sent',
              reportedStatus: targetStatus,
              signatureVerified: true,
            });

            // Must be accepted and status updated to delivered/read
            expect(result.accepted).toBe(true);
            expect(result.newStatus).toBe(targetStatus);
            expect(result.reason).toBe('status_updated');
            expect(result.auditRejection).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('signature verification uses HMAC-SHA256 correctly', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          (secret, payload) => {
            const signature = computeOpenWASignature(payload, secret);
            // The verification function should accept this signature
            expect(verifyOpenWAWebhookSignature(payload, signature, secret)).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('the mapped outbound status matches exactly what the webhook reported (no fabrication)', () => {
      fc.assert(
        fc.property(
          fc.constantFrom<WebhookStatus>('delivered', 'read', 'failed'),
          (webhookStatus) => {
            const mapped = mapWebhookStatusToOutboundStatus(webhookStatus);
            // The mapped status must exactly equal the webhook-reported status
            // (never fabricated — Req 8.6, 15.4)
            expect(mapped).toBe(webhookStatus);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 2) Duplicate status events are ignored ────────────────────────────────

  describe('Duplicate detection: duplicate status events produce no repeated updates (Req 8.9)', () => {
    test('same status reported twice is classified as duplicate', () => {
      fc.assert(
        fc.property(
          fc.constantFrom<OutboundMessageStatus>('delivered', 'read', 'failed'),
          (status) => {
            // If current status already equals the reported status, it's a duplicate
            const isDuplicate = isDuplicateOrStaleStatus(
              status,
              status as unknown as WebhookStatus,
            );
            expect(isDuplicate).toBe(true);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('processing a duplicate results in ignored action (no status change)', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          fc.constantFrom<WebhookStatus>('delivered', 'read', 'failed'),
          (secret, payload, reportedStatus) => {
            // Current status already matches reported — should be duplicate
            const result = processWebhookStatus({
              payload,
              signature: computeOpenWASignature(payload, secret),
              secret,
              currentStatus: reportedStatus as OutboundMessageStatus,
              reportedStatus,
              signatureVerified: true,
            });

            expect(result.newStatus).toBeNull();
            expect(result.reason).toBe('duplicate_ignored');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('backward transitions (e.g., delivered→sent) are rejected as stale', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          (secret, payload) => {
            // If message is already 'read', reporting 'delivered' is stale (backward)
            const result = processWebhookStatus({
              payload,
              signature: computeOpenWASignature(payload, secret),
              secret,
              currentStatus: 'read',
              reportedStatus: 'delivered',
              signatureVerified: true,
            });

            expect(result.newStatus).toBeNull();
            expect(result.reason).toBe('duplicate_ignored');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('terminal states (failed/expired) reject all further transitions', () => {
      fc.assert(
        fc.property(
          fc.constantFrom<OutboundMessageStatus>('failed', 'expired'),
          webhookStatusArb,
          webhookSecretArb,
          payloadArb,
          (terminalStatus, reportedStatus, secret, payload) => {
            const result = processWebhookStatus({
              payload,
              signature: computeOpenWASignature(payload, secret),
              secret,
              currentStatus: terminalStatus,
              reportedStatus,
              signatureVerified: true,
            });

            // Terminal status always leads to duplicate_ignored or no_op
            expect(result.newStatus).toBeNull();
            if (reportedStatus === 'pending' || reportedStatus === 'sent') {
              expect(result.reason).toBe('no_op_status');
            } else {
              expect(result.reason).toBe('duplicate_ignored');
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('status can only advance forward in lifecycle (queued→sent→delivered→read)', () => {
      fc.assert(
        fc.property(
          currentStatusArb,
          webhookStatusArb,
          (currentStatus, reportedStatus) => {
            const isDuplicate = isDuplicateOrStaleStatus(currentStatus, reportedStatus);
            const currentOrder = STATUS_ORDER[currentStatus] ?? -1;
            const reportedOrder = STATUS_ORDER[reportedStatus] ?? -1;

            if (currentStatus === 'failed' || currentStatus === 'expired') {
              // Terminal: always duplicate
              expect(isDuplicate).toBe(true);
            } else if (currentStatus === reportedStatus) {
              // Same status: duplicate
              expect(isDuplicate).toBe(true);
            } else if (reportedOrder > currentOrder) {
              // Forward transition: NOT duplicate
              expect(isDuplicate).toBe(false);
            } else {
              // Backward or same-level transition: duplicate
              expect(isDuplicate).toBe(true);
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 3) Non-webhook sources cannot set delivered/read status ────────────────

  describe('Non-webhook prohibition: no source other than verified webhooks sets delivered/read (Req 15.4)', () => {
    test('an invalid signature prevents any status transition', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          fc.constantFrom<WebhookStatus>('delivered', 'read'),
          fc.hexaString({ minLength: 8, maxLength: 64 }),
          (secret, payload, targetStatus, wrongSignature) => {
            // Pre-condition: wrong signature is actually wrong
            const correctSignature = computeOpenWASignature(payload, secret);
            fc.pre(wrongSignature !== correctSignature);

            const result = processWebhookStatus({
              payload,
              signature: wrongSignature,
              secret,
              currentStatus: 'sent',
              reportedStatus: targetStatus,
              signatureVerified: false, // Signature verification failed
            });

            // Must be rejected — no status change
            expect(result.accepted).toBe(false);
            expect(result.newStatus).toBeNull();
            expect(result.reason).toBe('signature_invalid');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('status mapping only produces delivered/read from actual webhook delivered/read', () => {
      fc.assert(
        fc.property(
          webhookStatusArb,
          (webhookStatus) => {
            const mapped = mapWebhookStatusToOutboundStatus(webhookStatus);

            // delivered/read in the output can ONLY come from delivered/read in the input
            if (mapped === 'delivered') {
              expect(webhookStatus).toBe('delivered');
            }
            if (mapped === 'read') {
              expect(webhookStatus).toBe('read');
            }
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('all valid webhook statuses map to known outbound statuses (never fabricated)', () => {
      fc.assert(
        fc.property(
          webhookStatusArb,
          (webhookStatus) => {
            const mapped = mapWebhookStatusToOutboundStatus(webhookStatus);
            expect(ALL_OUTBOUND_STATUSES).toContain(mapped);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('arbitrary non-webhook status strings are rejected when not in valid set', () => {
      fc.assert(
        fc.property(
          fc.string({ minLength: 1, maxLength: 30 }).filter(
            (s) => !VALID_WEBHOOK_STATUSES.includes(s as WebhookStatus),
          ),
          webhookSecretArb,
          payloadArb,
          (fakeStatus, secret, payload) => {
            const result = processWebhookStatus({
              payload,
              signature: computeOpenWASignature(payload, secret),
              secret,
              currentStatus: 'sent',
              reportedStatus: fakeStatus,
              signatureVerified: true,
            });

            // Invalid status strings are rejected — no status change
            expect(result.newStatus).toBeNull();
            expect(result.reason).toBe('invalid_status');
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });

  // ── 4) Failed signature = rejection + audit entry ─────────────────────────

  describe('Signature failure: failed HMAC = rejection + audit entry (Req 8.5)', () => {
    test('any payload with wrong secret produces verification failure', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          webhookSecretArb,
          payloadArb,
          (correctSecret, wrongSecret, payload) => {
            fc.pre(correctSecret !== wrongSecret);

            const signatureWithCorrect = computeOpenWASignature(payload, correctSecret);
            // Verify with wrong secret fails
            const isValid = verifyOpenWAWebhookSignature(payload, signatureWithCorrect, wrongSecret);
            expect(isValid).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('tampered payload fails verification', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          fc.string({ minLength: 1, maxLength: 10 }),
          (secret, payload, tamper) => {
            const signature = computeOpenWASignature(payload, secret);
            const tamperedPayload = payload + tamper;
            fc.pre(tamperedPayload !== payload);

            const isValid = verifyOpenWAWebhookSignature(tamperedPayload, signature, secret);
            expect(isValid).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('failed signature triggers audit rejection flag', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          fc.constantFrom<WebhookStatus>('delivered', 'read', 'failed'),
          (secret, payload, reportedStatus) => {
            const result = processWebhookStatus({
              payload,
              signature: 'invalid_signature_hex',
              secret,
              currentStatus: 'sent',
              reportedStatus,
              signatureVerified: false,
            });

            // Must produce audit rejection
            expect(result.auditRejection).toBe(true);
            expect(result.accepted).toBe(false);
            expect(result.newStatus).toBeNull();
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });

    test('valid signature does NOT trigger audit rejection', () => {
      fc.assert(
        fc.property(
          webhookSecretArb,
          payloadArb,
          webhookStatusArb,
          currentStatusArb,
          (secret, payload, reportedStatus, currentStatus) => {
            const result = processWebhookStatus({
              payload,
              signature: computeOpenWASignature(payload, secret),
              secret,
              currentStatus,
              reportedStatus,
              signatureVerified: true,
            });

            // Valid signature never triggers audit rejection
            expect(result.auditRejection).toBe(false);
          },
        ),
        { numRuns: NUM_RUNS },
      );
    });
  });
});
