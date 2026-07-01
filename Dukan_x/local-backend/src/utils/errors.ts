// ============================================================================
// Errors — minimal typed application error
// ============================================================================
// Mirrors the shape of my-backend/src/utils/errors.ts (`AppError`) so the
// packaged Local_Backend reports failures with the same code/status/message
// triple the AWS backend uses. Kept tiny and dependency-free.
//
// Used for *operational misconfiguration* (e.g. a missing RS256 signing key),
// which is a server fault — NOT for expected outcomes such as invalid login
// credentials, which are returned as a normal result so no exception leaks a
// timing/identity signal.
// ============================================================================

export class AppError extends Error {
    /** HTTP-style status code for the failure. */
    public readonly statusCode: number;
    /** Stable machine-readable error code (parity with the AWS envelope). */
    public readonly code: string;

    constructor(message: string, statusCode = 500, code = 'INTERNAL_ERROR') {
        super(message);
        this.name = 'AppError';
        this.statusCode = statusCode;
        this.code = code;
        // Restore prototype chain for instanceof across compiled targets.
        Object.setPrototypeOf(this, AppError.prototype);
    }
}
