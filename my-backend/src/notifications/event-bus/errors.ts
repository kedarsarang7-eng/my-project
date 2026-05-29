// ============================================================================
// UNS Event_Bus — Error Classes
// ============================================================================
// Structured error types thrown by the Event_Bus. Every error carries a stable
// machine-readable `code` so callers (publisher Lambda, SDK, operator tooling)
// can branch deterministically without regex-matching messages.
//
// Validates: REQ 3.6 (structured validation error on schema-invalid publish),
//            REQ 8.7 (sub_app publish rejected with field-level error),
//            REQ 9.7 (outbox fallback when Event_Bus unavailable).
// ============================================================================

import type { ValidationIssue } from './types';

/**
 * Base class for every Event_Bus error. Inherits from Error so stack traces are
 * preserved in CloudWatch / Lambda Insights, and exposes a stable `code`.
 */
export abstract class EventBusError extends Error {
    public abstract readonly code: string;

    constructor(message: string) {
        super(message);
        this.name = this.constructor.name;
        // Maintain proper prototype chain in transpiled ES2024 output.
        Object.setPrototypeOf(this, new.target.prototype);
    }

    /**
     * Serialize the error for structured logging and HTTP responses.
     * Never includes raw stack frames so secrets accidentally captured by
     * downstream stack walkers do not leak into AuditLog entries.
     */
    public toJSON(): Record<string, unknown> {
        return {
            code: this.code,
            message: this.message,
            name: this.name,
        };
    }
}

/**
 * Thrown when an event payload fails Event_Contract JSON Schema validation
 * (REQ 3.6, 8.7). The Event_Bus rejects the publish call and persists nothing.
 */
export class EventContractValidationError extends EventBusError {
    public readonly code = 'event_contract_validation_error';
    public readonly issues: readonly ValidationIssue[];

    constructor(message: string, issues: ValidationIssue[]) {
        super(message);
        // Defensive copy so callers cannot mutate the immutable issues list.
        this.issues = Object.freeze([...issues]);
    }

    public override toJSON(): Record<string, unknown> {
        return {
            ...super.toJSON(),
            issues: this.issues.map(issue => ({ ...issue })),
        };
    }
}

/**
 * Thrown when the Event_Bus is unreachable (network outage, throttle, IAM
 * misconfiguration, etc.). Producers handle this by buffering into the local
 * outbox per REQ 9.7.
 */
export class EventBusUnavailableError extends EventBusError {
    public readonly code = 'event_bus_unavailable';
    /** Original AWS / network error preserved for AuditLog. */
    public readonly cause?: Error;

    constructor(message: string, cause?: Error) {
        super(message);
        this.cause = cause;
    }

    public override toJSON(): Record<string, unknown> {
        return {
            ...super.toJSON(),
            cause: this.cause ? { name: this.cause.name, message: this.cause.message } : undefined,
        };
    }
}

/**
 * Thrown when the Event_Bus module is mis-configured (missing topic ARN /
 * queue URL / DLQ URL when those are required for the requested operation).
 */
export class EventBusConfigError extends EventBusError {
    public readonly code = 'event_bus_config_error';
}

/**
 * Thrown by the publisher's per-Producer rate-limit middleware (REQ 12.4)
 * when a Producer exceeds its configured publish budget within the window.
 *
 * The error is structured so the caller (or the emit-helper wrapper) can
 * distinguish a flood-control rejection from a schema-validation rejection
 * or a transient SNS outage. Producers that want stronger delivery
 * guarantees (e.g. critical events) can buffer the event into the local
 * outbox after catching this error and retry once the window has rolled
 * over (`retryAfterMs` indicates how long to wait).
 */
export class ProducerRateLimitExceededError extends EventBusError {
    public readonly code = 'producer_rate_limit_exceeded';
    /** Producer identifier (typically the event's `source_module`). */
    public readonly producerId: string;
    /** Configured limit (events per window). */
    public readonly limit: number;
    /** Configured window length in milliseconds. */
    public readonly windowMs: number;
    /** Suggested cool-off in milliseconds before another publish is likely to succeed. */
    public readonly retryAfterMs: number;

    constructor(
        message: string,
        params: {
            producerId: string;
            limit: number;
            windowMs: number;
            retryAfterMs: number;
        },
    ) {
        super(message);
        this.producerId = params.producerId;
        this.limit = params.limit;
        this.windowMs = params.windowMs;
        this.retryAfterMs = params.retryAfterMs;
    }

    public override toJSON(): Record<string, unknown> {
        return {
            ...super.toJSON(),
            producerId: this.producerId,
            limit: this.limit,
            windowMs: this.windowMs,
            retryAfterMs: this.retryAfterMs,
        };
    }
}

/**
 * Thrown by the consumer when a handler invocation exhausts the configured
 * retry budget. The consumer writes a `failed` AuditLog entry and lets the
 * SQS native DLQ redrive policy move the message to the DLQ (per REQ 3.10:
 * AWS-managed DLQ semantics preserve original payload, error reason, retry
 * count, timestamps).
 */
export class RetryBudgetExhaustedError extends EventBusError {
    public readonly code = 'retry_budget_exhausted';
    public readonly attempts: number;
    public readonly lastError: string;

    constructor(message: string, attempts: number, lastError: string) {
        super(message);
        this.attempts = attempts;
        this.lastError = lastError;
    }

    public override toJSON(): Record<string, unknown> {
        return {
            ...super.toJSON(),
            attempts: this.attempts,
            lastError: this.lastError,
        };
    }
}
