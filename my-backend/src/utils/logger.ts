import { config } from '../config/environment';
// ============================================================================
// Logger — Structured JSON Logging for Lambda / CloudWatch
// ============================================================================
// Automatically includes correlation ID and tenant ID from AsyncLocalStorage
// context when available — enables distributed tracing across services.
// ============================================================================

import * as context from './context';

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVELS: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
};

const currentLevel: LogLevel = (config.app.logLevel as LogLevel) || 'info';

function shouldLog(level: LogLevel): boolean {
    return LEVELS[level] >= LEVELS[currentLevel];
}

// AUDIT FIX #13: Redact sensitive fields from log output
const SENSITIVE_KEYS = new Set([
    'password', 'previouspassword', 'proposedpassword', 'newpassword',
    'accesstoken', 'idtoken', 'refreshtoken', 'token', 'secret',
    'secretcode', 'confirmationcode', 'authorization', 'apikey',
    'creditcard', 'cardnumber', 'cvv', 'ssn',
]);

function redactSensitiveFields(obj: Record<string, unknown>): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj)) {
        if (SENSITIVE_KEYS.has(key.toLowerCase())) {
            result[key] = '[REDACTED]';
        } else if (value && typeof value === 'object' && !Array.isArray(value)) {
            result[key] = redactSensitiveFields(value as Record<string, unknown>);
        } else {
            result[key] = value;
        }
    }
    return result;
}

function log(level: LogLevel, message: string, meta?: Record<string, unknown>): void {
    if (!shouldLog(level)) return;

    // Auto-inject context from AsyncLocalStorage
    const tenantId = context.getTenantId();
    const correlationId = context.getCorrelationId();
    const userId = context.getUserId();

    // AUDIT FIX #13: Redact sensitive fields from log metadata
    const sanitizedMeta = meta ? redactSensitiveFields(meta) : {};

    const entry: Record<string, unknown> = {
        level,
        message,
        timestamp: new Date().toISOString(),
        service: 'bizmate-backend',
        ...(correlationId ? { correlationId } : {}),
        ...(tenantId ? { tenantId } : {}),
        ...(userId ? { userId } : {}),
        ...sanitizedMeta,
    };

    // CloudWatch picks up JSON from stdout/stderr automatically
    if (level === 'error') {
        console.error(JSON.stringify(entry));
    } else {
        console.log(JSON.stringify(entry));
    }
}

export const logger = {
    debug: (msg: string, meta?: Record<string, unknown>) => log('debug', msg, meta),
    info: (msg: string, meta?: Record<string, unknown>) => log('info', msg, meta),
    warn: (msg: string, meta?: Record<string, unknown>) => log('warn', msg, meta),
    error: (msg: string, meta?: Record<string, unknown>) => log('error', msg, meta),
};
