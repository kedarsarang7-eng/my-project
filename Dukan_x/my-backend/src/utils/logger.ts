// ============================================================================
// Logger — Structured JSON Logging for Lambda / CloudWatch
// ============================================================================

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVELS: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
};

const currentLevel: LogLevel = (process.env.LOG_LEVEL as LogLevel) || 'info';

function shouldLog(level: LogLevel): boolean {
    return LEVELS[level] >= LEVELS[currentLevel];
}

function log(level: LogLevel, message: string, meta?: Record<string, unknown>): void {
    if (!shouldLog(level)) return;

    const entry = {
        level,
        message,
        timestamp: new Date().toISOString(),
        service: 'bizmate-backend',
        ...(meta || {}),
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
