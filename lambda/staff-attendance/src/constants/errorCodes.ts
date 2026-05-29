// ============================================================================
// p28(d) Structured error codes for all staff-attendance handlers
// ============================================================================
//
// Clients MUST match on errorCode, not on the human-readable `error` string.
// The `error` field is for logging/display only and may change wording.
//
// Retryability guide (for client offline-queue / retry logic):
//   RETRYABLE     — transient; client should retry with backoff
//   NOT_RETRYABLE — permanent; retry will not help, surface to user
//   CONFLICT      — server has state; client should read current state first
// ============================================================================

export const ErrorCodes = {
  // ── Auth / RBAC ────────────────────────────────────────────────────────────
  UNAUTHORIZED:               'UNAUTHORIZED',            // 401 — no/invalid JWT claims
  FORBIDDEN_ROLE:             'FORBIDDEN_ROLE',          // 403 — caller lacks required role
  FORBIDDEN_SELF_ONLY:        'FORBIDDEN_SELF_ONLY',     // 403 — caller not the target staff
  ACCOUNT_INACTIVE:           'ACCOUNT_INACTIVE',        // 403 — staff account disabled

  // ── Not found ──────────────────────────────────────────────────────────────
  STAFF_NOT_FOUND:            'STAFF_NOT_FOUND',         // 404 — staffId not in DB
  SHIFT_NOT_FOUND:            'SHIFT_NOT_FOUND',         // 404 — shiftId not found
  LEAVE_NOT_FOUND:            'LEAVE_NOT_FOUND',         // 404 — leaveId not found

  // ── Conflict / state machine ───────────────────────────────────────────────
  SHIFT_ALREADY_ACTIVE:       'SHIFT_ALREADY_ACTIVE',    // 409 — open shift exists (CONFLICT)
  SHIFT_ALREADY_CLOSED:       'SHIFT_ALREADY_CLOSED',    // 409 — shift closed already (CONFLICT)
  LEAVE_OVERLAP:              'LEAVE_OVERLAP',           // 409 — approved leave covers same dates (CONFLICT)
  LEAVE_DUPLICATE_PENDING:    'LEAVE_DUPLICATE_PENDING', // 409 — pending leave already exists (CONFLICT)
  LEAVE_ALREADY_PROCESSED:    'LEAVE_ALREADY_PROCESSED', // 409 — leave not PENDING (CONFLICT)

  // ── Validation ────────────────────────────────────────────────────────────
  VALIDATION_FAILED:          'VALIDATION_FAILED',       // 400 — Zod schema failure (NOT_RETRYABLE)
  MISSING_PARAM:              'MISSING_PARAM',           // 400 — required path/query param absent (NOT_RETRYABLE)

  // ── Server / transient ────────────────────────────────────────────────────
  INTERNAL_ERROR:             'INTERNAL_ERROR',          // 500 — unexpected error (RETRYABLE)
  DB_TRANSACTION_FAILED:      'DB_TRANSACTION_FAILED',   // 500 — DDB TransactWrite failed (RETRYABLE)
} as const;

export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

/** Returns true if a client should retry after receiving this error code. */
export function isRetryable(code: ErrorCode): boolean {
  return code === ErrorCodes.INTERNAL_ERROR || code === ErrorCodes.DB_TRANSACTION_FAILED;
}
