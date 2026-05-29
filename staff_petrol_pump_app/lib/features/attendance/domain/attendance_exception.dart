// ============================================================================
// p28(d) AttendanceException — typed error codes mirroring the server
// ============================================================================
//
// Mirrors lambda/staff-attendance/src/constants/errorCodes.ts.
// Clients MUST branch on [code], not on [message].
// ============================================================================

/// Machine-readable error codes returned by the staff-attendance backend.
///
/// These values correspond 1:1 to the `errorCode` field in every error
/// response body from the Lambda handlers.  Treat the human-readable
/// [AttendanceException.message] as display-only — it may change wording.
enum AttendanceErrorCode {
  // ── Auth / RBAC ────────────────────────────────────────────────────────────
  unauthorized,        // 401 — no/invalid JWT claims
  forbiddenRole,       // 403 — caller lacks required role
  forbiddenSelfOnly,   // 403 — caller is not the target staff
  accountInactive,     // 403 — staff account disabled by manager

  // ── Not found ──────────────────────────────────────────────────────────────
  staffNotFound,       // 404 — staffId not in DB
  shiftNotFound,       // 404 — shiftId not found
  leaveNotFound,       // 404 — leaveId not found

  // ── Conflict / state machine ───────────────────────────────────────────────
  shiftAlreadyActive,     // 409 — open shift already exists (retryable via idempotency)
  shiftAlreadyClosed,     // 409 — shift was already checked out
  leaveOverlap,           // 409 — approved leave covers same dates
  leaveDuplicatePending,  // 409 — pending leave already exists
  leaveAlreadyProcessed,  // 409 — leave not in PENDING state

  // ── Validation ────────────────────────────────────────────────────────────
  validationFailed,    // 400 — Zod schema / business-rule validation failure
  missingParam,        // 400 — required path/query param absent

  // ── Server / transient ────────────────────────────────────────────────────
  internalError,       // 500 — unexpected server error — safe to retry
  dbTransactionFailed, // 500 — DynamoDB TransactWrite failure — safe to retry

  // ── Client-side fallback ──────────────────────────────────────────────────
  networkError,        // no HTTP response received (timeout, no connection)
  unknown,             // errorCode present but not in this enum
}

/// True when a client should retry after receiving this error code.
bool isRetryable(AttendanceErrorCode code) {
  return code == AttendanceErrorCode.internalError ||
      code == AttendanceErrorCode.dbTransactionFailed ||
      code == AttendanceErrorCode.networkError;
}

/// Returns a short, user-facing action hint for the given code.
String actionHintFor(AttendanceErrorCode code) {
  switch (code) {
    case AttendanceErrorCode.unauthorized:
      return 'Please log in again.';
    case AttendanceErrorCode.forbiddenRole:
    case AttendanceErrorCode.forbiddenSelfOnly:
      return 'You do not have permission to perform this action.';
    case AttendanceErrorCode.accountInactive:
      return 'Your account is inactive. Contact your manager.';
    case AttendanceErrorCode.staffNotFound:
      return 'Staff ID not recognised. Please scan again.';
    case AttendanceErrorCode.shiftNotFound:
      return 'Shift not found. It may have been cancelled.';
    case AttendanceErrorCode.shiftAlreadyActive:
      return 'A shift is already active. Opening your dashboard.';
    case AttendanceErrorCode.shiftAlreadyClosed:
      return 'This shift has already been closed.';
    case AttendanceErrorCode.validationFailed:
    case AttendanceErrorCode.missingParam:
      return 'Invalid request. Please try again.';
    case AttendanceErrorCode.internalError:
    case AttendanceErrorCode.dbTransactionFailed:
      return 'Server error. Please retry in a moment.';
    case AttendanceErrorCode.networkError:
      return 'No connection. Check your network and retry.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// Parses a raw `errorCode` string from the API response body into an
/// [AttendanceErrorCode] enum value.
AttendanceErrorCode parseErrorCode(String? raw) {
  switch (raw) {
    case 'UNAUTHORIZED':           return AttendanceErrorCode.unauthorized;
    case 'FORBIDDEN_ROLE':         return AttendanceErrorCode.forbiddenRole;
    case 'FORBIDDEN_SELF_ONLY':    return AttendanceErrorCode.forbiddenSelfOnly;
    case 'ACCOUNT_INACTIVE':       return AttendanceErrorCode.accountInactive;
    case 'STAFF_NOT_FOUND':        return AttendanceErrorCode.staffNotFound;
    case 'SHIFT_NOT_FOUND':        return AttendanceErrorCode.shiftNotFound;
    case 'LEAVE_NOT_FOUND':        return AttendanceErrorCode.leaveNotFound;
    case 'SHIFT_ALREADY_ACTIVE':   return AttendanceErrorCode.shiftAlreadyActive;
    case 'SHIFT_ALREADY_CLOSED':   return AttendanceErrorCode.shiftAlreadyClosed;
    case 'LEAVE_OVERLAP':          return AttendanceErrorCode.leaveOverlap;
    case 'LEAVE_DUPLICATE_PENDING':return AttendanceErrorCode.leaveDuplicatePending;
    case 'LEAVE_ALREADY_PROCESSED':return AttendanceErrorCode.leaveAlreadyProcessed;
    case 'VALIDATION_FAILED':      return AttendanceErrorCode.validationFailed;
    case 'MISSING_PARAM':          return AttendanceErrorCode.missingParam;
    case 'INTERNAL_ERROR':         return AttendanceErrorCode.internalError;
    case 'DB_TRANSACTION_FAILED':  return AttendanceErrorCode.dbTransactionFailed;
    default:                       return AttendanceErrorCode.unknown;
  }
}

/// Structured exception thrown by [AttendanceService] for all non-success
/// responses.  Callers branch on [code]; [message] is display-only.
class AttendanceException implements Exception {
  /// Machine-readable code — branch on this, not [message].
  final AttendanceErrorCode code;

  /// Human-readable description (may change between releases).
  final String message;

  /// HTTP status code from the response, if available.
  final int? statusCode;

  /// Extra fields forwarded from the response body (e.g. shiftId on 409).
  final Map<String, dynamic> extra;

  const AttendanceException({
    required this.code,
    required this.message,
    this.statusCode,
    this.extra = const {},
  });

  /// True when the caller should retry automatically (with backoff).
  bool get retryable => isRetryable(code);

  /// Short user-facing action hint.
  String get actionHint => actionHintFor(code);

  @override
  String toString() => 'AttendanceException($code, $statusCode): $message';
}
