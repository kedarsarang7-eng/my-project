// ============================================================================
// Custom Error Classes — Centralized Error Handling
// ============================================================================
// All errors should extend AppError so the handler wrapper can properly
// categorize and format them in the API response.
// ============================================================================

/**
 * Base application error with HTTP status code and error code.
 */
export class AppError extends Error {
    public readonly statusCode: number;
    public readonly code: string;
    public readonly details?: unknown;

    constructor(message: string, statusCode: number, code: string, details?: unknown) {
        super(message);
        this.name = 'AppError';
        this.statusCode = statusCode;
        this.code = code;
        this.details = details;
    }
}

/**
 * Authentication/authorization error (401/403).
 */
export class AuthError extends AppError {
    constructor(message: string, statusCode = 401) {
        super(message, statusCode, statusCode === 401 ? 'AUTH_ERROR' : 'FORBIDDEN');
        this.name = 'AuthError';
    }
}

/**
 * Input validation error (400).
 */
export class ValidationError extends AppError {
    constructor(message: string, details?: unknown) {
        super(message, 400, 'VALIDATION_ERROR', details);
        this.name = 'ValidationError';
    }
}

/**
 * Resource not found error (404).
 */
export class NotFoundError extends AppError {
    constructor(resource: string) {
        super(`${resource} not found`, 404, 'NOT_FOUND');
        this.name = 'NotFoundError';
    }
}

/**
 * Conflict error — duplicate resource (409).
 */
export class ConflictError extends AppError {
    constructor(message: string) {
        super(message, 409, 'CONFLICT');
        this.name = 'ConflictError';
    }
}

/**
 * Tenant isolation error — attempted cross-tenant access (403).
 */
export class TenantError extends AppError {
    constructor(message = 'Tenant access denied') {
        super(message, 403, 'TENANT_ERROR');
        this.name = 'TenantError';
    }
}

/**
 * Rate limit exceeded (429).
 */
export class RateLimitError extends AppError {
    constructor(message = 'Too many requests') {
        super(message, 429, 'RATE_LIMIT_EXCEEDED');
        this.name = 'RateLimitError';
    }
}

/**
 * Price validation error — client-submitted total doesn't match server-side calculation (400).
 * Used by petrol pump sales to prevent price manipulation.
 */
export class PriceValidationError extends AppError {
    public readonly expectedCents: number;
    public readonly receivedCents: number;
    public readonly toleranceCents: number;

    constructor(message: string, details: { expectedCents: number; receivedCents: number; toleranceCents: number }) {
        super(message, 400, 'PRICE_MISMATCH', details);
        this.name = 'PriceValidationError';
        this.expectedCents = details.expectedCents;
        this.receivedCents = details.receivedCents;
        this.toleranceCents = details.toleranceCents;
    }
}

/**
 * Credit limit exceeded for udhar/credit sales (400).
 * Shared across invoice service and petrol pump handlers.
 */
export class CreditLimitExceededError extends AppError {
    public readonly invoiceTotalCents: number;
    public readonly availableCreditCents: number;
    public readonly creditLimitCents: number;
    public readonly outstandingBalanceCents: number;

    constructor(message: string, details: { invoiceTotalCents: number; availableCreditCents: number; creditLimitCents: number; outstandingBalanceCents: number }) {
        super(message, 400, 'CREDIT_LIMIT_EXCEEDED', details);
        this.name = 'CreditLimitExceededError';
        this.invoiceTotalCents = details.invoiceTotalCents;
        this.availableCreditCents = details.availableCreditCents;
        this.creditLimitCents = details.creditLimitCents;
        this.outstandingBalanceCents = details.outstandingBalanceCents;
    }
}

/**
 * HSN/GST rate mismatch error (422).
 * Returned when submitted CGST/SGST rates don't match the HSN master table.
 */
export class HsnGstMismatchError extends AppError {
    public readonly hsnCode: string;
    public readonly expectedCgstRateBp: number;
    public readonly expectedSgstRateBp: number;
    public readonly submittedCgstRateBp: number;
    public readonly submittedSgstRateBp: number;

    constructor(
        hsnCode: string,
        details: {
            expectedCgstRateBp: number;
            expectedSgstRateBp: number;
            submittedCgstRateBp: number;
            submittedSgstRateBp: number;
        },
    ) {
        super(
            `GST rate mismatch for HSN code ${hsnCode}: expected CGST ${details.expectedCgstRateBp}bp/SGST ${details.expectedSgstRateBp}bp, received CGST ${details.submittedCgstRateBp}bp/SGST ${details.submittedSgstRateBp}bp`,
            422,
            'HSN_GST_MISMATCH',
            details,
        );
        this.name = 'HsnGstMismatchError';
        this.hsnCode = hsnCode;
        this.expectedCgstRateBp = details.expectedCgstRateBp;
        this.expectedSgstRateBp = details.expectedSgstRateBp;
        this.submittedCgstRateBp = details.submittedCgstRateBp;
        this.submittedSgstRateBp = details.submittedSgstRateBp;
    }
}

/**
 * Invoice validation error — business-type compliance enforcement (422).
 * Used when IMEI/serial number requirements are not met per Consumer Protection Act.
 */
export class InvoiceValidationError extends AppError {
    constructor(message: string, details?: unknown) {
        super(message, 422, 'INVOICE_VALIDATION_ERROR', details);
        this.name = 'InvoiceValidationError';
    }
}
