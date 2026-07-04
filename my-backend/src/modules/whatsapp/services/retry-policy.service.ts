// ============================================================================
// WhatsApp Automation Module — Retry Policy Service (Task 11.1)
// ============================================================================
// Pure function `nextAttempt(state, policy)` that determines whether a failed
// dispatch should be retried or permanently marked as failed.
//
// DESIGN CONTRACTS:
// - Transient errors (network timeout, gateway error) → retry with backoff
// - Permanent errors (invalid recipient, invalid number) → immediately fail, NO retry
// - Attempt count configurable 1..10, default 3
// - Backoff delay configurable 1..3600s, default 60s
// - Message expiry configurable 1min..168h — expired messages are NEVER dispatched
// - The function is PURE (no side effects) for testability and determinism
// - This is critical for ensuring retries don't send to wrong recipients
//
// Requirements: 4.7, 8.1, 8.2, 8.8, 9.4, 10.7
// ============================================================================

// ── Error Classification ──────────────────────────────────────────────────────

/**
 * Known transient error codes that warrant retry with backoff.
 * These are typically recoverable network/gateway issues.
 */
export const TRANSIENT_ERROR_CODES: readonly string[] = [
  'NETWORK_TIMEOUT',
  'GATEWAY_ERROR',
  'GATEWAY_UNAVAILABLE',
  'CONNECTION_RESET',
  'SERVICE_UNAVAILABLE',
  'RATE_LIMITED',
  'SOCKET_TIMEOUT',
  'DNS_RESOLUTION_FAILED',
  'ECONNREFUSED',
  'ECONNRESET',
  'ETIMEDOUT',
  'EHOSTUNREACH',
  'HTTP_500',
  'HTTP_502',
  'HTTP_503',
  'HTTP_504',
] as const;

/**
 * Known permanent error codes that should NEVER be retried.
 * These indicate the message can never succeed as-is.
 */
export const PERMANENT_ERROR_CODES: readonly string[] = [
  'INVALID_RECIPIENT',
  'INVALID_NUMBER',
  'NUMBER_NOT_ON_WHATSAPP',
  'RECIPIENT_BLOCKED',
  'INVALID_TEMPLATE',
  'MEDIA_TOO_LARGE',
  'CONTENT_REJECTED',
  'FORBIDDEN',
  'UNAUTHORIZED',
  'INVALID_API_KEY',
  'HTTP_400',
  'HTTP_401',
  'HTTP_403',
  'HTTP_404',
] as const;

// ── Types ─────────────────────────────────────────────────────────────────────

/** Retry policy configuration. All fields have validated bounds. */
export interface RetryPolicy {
  /** Maximum number of dispatch attempts (1..10). Default: 3. */
  maxAttempts: number;
  /** Backoff delay in seconds between retries (1..3600). Default: 60. */
  backoffSeconds: number;
  /** Message expiry duration in seconds (60..604800 i.e. 1min..168h). */
  expirySeconds: number;
}

/** Current state of a dispatch attempt relevant to retry decisions. */
export interface DispatchAttemptState {
  /** Number of attempts already made (0-based: 0 means no attempt yet made). */
  attempts: number;
  /** The error code from the latest failed dispatch. */
  errorCode: string;
  /** ISO-8601 UTC timestamp when the message was first enqueued (createdAt). */
  enqueuedAt: string;
  /** ISO-8601 UTC timestamp of the current evaluation moment. */
  now: string;
  /** Optional ISO-8601 UTC timestamp when the message expires. */
  expiresAt?: string;
}

/** Result: retry at a specific time. */
export interface RetryDecision {
  action: 'retry';
  /** ISO-8601 UTC timestamp for the next retry attempt. */
  retryAt: string;
  /** Reason for retrying. */
  reason: string;
}

/** Result: mark as permanently failed, no further retries. */
export interface FailedDecision {
  action: 'failed';
  /** Reason the message is marked as permanently failed. */
  reason: string;
}

/** Result: message has expired and must not be dispatched. */
export interface ExpiredDecision {
  action: 'expired';
  /** Reason the message is marked as expired. */
  reason: string;
}

/** The union of all possible retry decisions. */
export type RetryDecisionResult = RetryDecision | FailedDecision | ExpiredDecision;

// ── Constants & Defaults ──────────────────────────────────────────────────────

/** Minimum allowed max attempts. */
export const MIN_MAX_ATTEMPTS = 1;
/** Maximum allowed max attempts. */
export const MAX_MAX_ATTEMPTS = 10;
/** Default max attempts when not configured. */
export const DEFAULT_MAX_ATTEMPTS = 3;

/** Minimum backoff delay in seconds. */
export const MIN_BACKOFF_SECONDS = 1;
/** Maximum backoff delay in seconds. */
export const MAX_BACKOFF_SECONDS = 3600;
/** Default backoff delay in seconds when not configured. */
export const DEFAULT_BACKOFF_SECONDS = 60;

/** Minimum message expiry in seconds (1 minute). */
export const MIN_EXPIRY_SECONDS = 60;
/** Maximum message expiry in seconds (168 hours = 7 days). */
export const MAX_EXPIRY_SECONDS = 604800;
/** Default message expiry in seconds (24 hours). */
export const DEFAULT_EXPIRY_SECONDS = 86400;

// ── Policy Validation & Defaults ──────────────────────────────────────────────

/**
 * Clamps a value to [min, max]. If the value is NaN or not finite,
 * returns the defaultValue.
 */
function clamp(value: number, min: number, max: number, defaultValue: number): number {
  if (!Number.isFinite(value)) {
    return defaultValue;
  }
  const rounded = Math.round(value);
  if (rounded < min) return min;
  if (rounded > max) return max;
  return rounded;
}

/**
 * Creates a validated retry policy with all values clamped to valid bounds.
 * Any out-of-range or missing values fall back to safe defaults.
 *
 * @param partial - Optional partial policy with overrides.
 * @returns A fully validated RetryPolicy with all bounds enforced.
 */
export function createRetryPolicy(partial?: Partial<RetryPolicy>): RetryPolicy {
  return {
    maxAttempts: clamp(
      partial?.maxAttempts ?? DEFAULT_MAX_ATTEMPTS,
      MIN_MAX_ATTEMPTS,
      MAX_MAX_ATTEMPTS,
      DEFAULT_MAX_ATTEMPTS,
    ),
    backoffSeconds: clamp(
      partial?.backoffSeconds ?? DEFAULT_BACKOFF_SECONDS,
      MIN_BACKOFF_SECONDS,
      MAX_BACKOFF_SECONDS,
      DEFAULT_BACKOFF_SECONDS,
    ),
    expirySeconds: clamp(
      partial?.expirySeconds ?? DEFAULT_EXPIRY_SECONDS,
      MIN_EXPIRY_SECONDS,
      MAX_EXPIRY_SECONDS,
      DEFAULT_EXPIRY_SECONDS,
    ),
  };
}

// ── Error Classification ──────────────────────────────────────────────────────

/**
 * Classifies a dispatch error as transient (retryable) or permanent (non-retryable).
 *
 * - Transient errors (network timeout, gateway error, rate limiting) → retry
 * - Permanent errors (invalid recipient, invalid number, forbidden) → fail immediately
 * - Unknown error codes default to transient (fail-safe: prefer retry over silent loss)
 *
 * @param errorCode - The error code string from the dispatch failure.
 * @returns `true` if the error is transient and dispatch should be retried.
 */
export function isTransientError(errorCode: string): boolean {
  if (!errorCode || typeof errorCode !== 'string') {
    // Defensive: treat missing/invalid error codes as transient (fail-safe)
    return true;
  }

  const normalized = errorCode.trim().toUpperCase();

  // Check permanent first — if it's known permanent, never retry
  if ((PERMANENT_ERROR_CODES as readonly string[]).includes(normalized)) {
    return false;
  }

  // Check if it's a known transient error
  if ((TRANSIENT_ERROR_CODES as readonly string[]).includes(normalized)) {
    return true;
  }

  // Unknown errors default to transient (fail-safe: retry rather than silently lose)
  return true;
}

/**
 * Classifies a dispatch error as permanent (non-retryable).
 * Convenience inverse of `isTransientError`.
 */
export function isPermanentError(errorCode: string): boolean {
  return !isTransientError(errorCode);
}

// ── Expiry Check ──────────────────────────────────────────────────────────────

/**
 * Determines whether a message has expired based on its enqueue time and
 * the configured expiry duration.
 *
 * A message is expired if:
 * - `now >= enqueuedAt + expirySeconds`, OR
 * - `now >= expiresAt` (if an explicit expiresAt is set)
 *
 * Expired messages are NEVER dispatched (Req 9.4).
 *
 * @param state - The current dispatch attempt state.
 * @param policy - The validated retry policy.
 * @returns `true` if the message has expired and must not be dispatched.
 */
export function isMessageExpired(state: DispatchAttemptState, policy: RetryPolicy): boolean {
  const nowMs = Date.parse(state.now);
  if (isNaN(nowMs)) {
    // If we can't parse `now`, fail-safe: treat as expired to prevent stale dispatch
    return true;
  }

  // Check explicit expiresAt if provided
  if (state.expiresAt) {
    const expiresAtMs = Date.parse(state.expiresAt);
    if (!isNaN(expiresAtMs) && nowMs >= expiresAtMs) {
      return true;
    }
  }

  // Check computed expiry from enqueue time + policy expiry
  const enqueuedAtMs = Date.parse(state.enqueuedAt);
  if (isNaN(enqueuedAtMs)) {
    // If we can't parse enqueuedAt, fail-safe: treat as expired
    return true;
  }

  const computedExpiryMs = enqueuedAtMs + policy.expirySeconds * 1000;
  return nowMs >= computedExpiryMs;
}

// ── Core: nextAttempt ─────────────────────────────────────────────────────────

/**
 * Pure function that determines the next action for a failed dispatch.
 *
 * Decision logic (in priority order):
 * 1. If the message has expired → `expired` (NEVER dispatch, Req 9.4)
 * 2. If the error is permanent → `failed` (no retry, Req 8.8)
 * 3. If max attempts exhausted → `failed` (Req 8.2)
 * 4. Otherwise → `retry` at `now + backoffSeconds` (Req 8.1)
 *
 * This function is deterministic and side-effect-free: given the same inputs
 * it always produces the same output. It does not read clocks, write state,
 * or perform I/O.
 *
 * @param state - Current state of the dispatch attempt.
 * @param policy - Validated retry policy configuration.
 * @returns A decision: retry (with retryAt timestamp), failed, or expired.
 *
 * @example
 * ```ts
 * const state: DispatchAttemptState = {
 *   attempts: 1,
 *   errorCode: 'NETWORK_TIMEOUT',
 *   enqueuedAt: '2024-01-01T00:00:00Z',
 *   now: '2024-01-01T00:01:00Z',
 * };
 * const policy = createRetryPolicy({ maxAttempts: 3, backoffSeconds: 60 });
 * const decision = nextAttempt(state, policy);
 * // → { action: 'retry', retryAt: '2024-01-01T00:02:00Z', reason: '...' }
 * ```
 */
export function nextAttempt(
  state: DispatchAttemptState,
  policy: RetryPolicy,
): RetryDecisionResult {
  // 1. Expiry check — expired messages are NEVER dispatched
  if (isMessageExpired(state, policy)) {
    return {
      action: 'expired',
      reason: `Message expired: enqueued at ${state.enqueuedAt}, expiry ${policy.expirySeconds}s, current time ${state.now}`,
    };
  }

  // 2. Permanent error — immediately fail, no retry (Req 8.8)
  if (isPermanentError(state.errorCode)) {
    return {
      action: 'failed',
      reason: `Permanent error "${state.errorCode}": message will not be retried`,
    };
  }

  // 3. Max attempts exhausted — fail (Req 8.2)
  // `attempts` is the number of attempts already made (including the one that just failed).
  if (state.attempts >= policy.maxAttempts) {
    return {
      action: 'failed',
      reason: `Maximum retry attempts exhausted (${state.attempts}/${policy.maxAttempts})`,
    };
  }

  // 4. Transient error with retries remaining — schedule retry (Req 8.1)
  const nowMs = Date.parse(state.now);
  const retryAtMs = nowMs + policy.backoffSeconds * 1000;
  const retryAt = new Date(retryAtMs).toISOString();

  return {
    action: 'retry',
    retryAt,
    reason: `Transient error "${state.errorCode}": scheduling retry ${state.attempts + 1}/${policy.maxAttempts} at ${retryAt}`,
  };
}

// ── Convenience: compute expiresAt from enqueue time ──────────────────────────

/**
 * Computes the expiry timestamp for a newly enqueued message.
 * Used when creating an OutboundMessage to set the `expiresAt` field.
 *
 * @param enqueuedAt - ISO-8601 UTC timestamp when the message was enqueued.
 * @param policy - The retry policy (uses expirySeconds).
 * @returns ISO-8601 UTC timestamp when the message expires.
 */
export function computeExpiresAt(enqueuedAt: string, policy: RetryPolicy): string {
  const enqueuedMs = Date.parse(enqueuedAt);
  if (isNaN(enqueuedMs)) {
    throw new Error(`Invalid enqueuedAt timestamp: "${enqueuedAt}"`);
  }
  return new Date(enqueuedMs + policy.expirySeconds * 1000).toISOString();
}
