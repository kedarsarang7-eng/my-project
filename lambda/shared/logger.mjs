/**
 * Structured JSON Logger for Lambda functions
 * Replaces console.log with structured logging for better observability
 */

const isProduction = process.env.NODE_ENV === 'production' || process.env.ENVIRONMENT === 'prod';

/**
 * Create a structured log entry
 */
function createLogEntry(level, message, meta = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level: level.toUpperCase(),
    message,
    service: process.env.AWS_LAMBDA_FUNCTION_NAME || 'unknown',
    environment: process.env.ENVIRONMENT || 'dev',
    awsRequestId: process.env.AWS_REQUEST_ID,
    ...meta,
  };

  // In production, log JSON. In dev, log pretty-printed
  if (isProduction) {
    return JSON.stringify(entry);
  }
  return `[${entry.timestamp}] ${entry.level}: ${message} ${JSON.stringify(meta)}`;
}

/**
 * Logger interface with structured logging
 */
export const logger = {
  info(message, meta = {}) {
    console.info(createLogEntry('info', message, meta));
  },

  warn(message, meta = {}) {
    console.warn(createLogEntry('warn', message, meta));
  },

  error(message, meta = {}) {
    console.error(createLogEntry('error', message, {
      ...meta,
      stack: meta.error?.stack,
    }));
  },

  debug(message, meta = {}) {
    if (!isProduction) {
      console.debug(createLogEntry('debug', message, meta));
    }
  },

  /**
   * Log API request with structured data
   */
  request(method, path, userId, meta = {}) {
    this.info(`${method} ${path}`, {
      type: 'request',
      method,
      path,
      userId,
      ...meta,
    });
  },

  /**
   * Log API response with structured data
   */
  response(method, path, statusCode, duration, meta = {}) {
    this.info(`${method} ${path} ${statusCode}`, {
      type: 'response',
      method,
      path,
      statusCode,
      durationMs: duration,
      ...meta,
    });
  },

  /**
   * Log payment events
   */
  payment(event, transactionId, amount, meta = {}) {
    this.info(`Payment ${event}: ${transactionId}`, {
      type: 'payment',
      event,
      transactionId,
      amount,
      ...meta,
    });
  },

  /**
   * Log security events
   */
  security(event, userId, details = {}) {
    this.warn(`Security: ${event}`, {
      type: 'security',
      event,
      userId,
      ...details,
    });
  },
};

export default logger;
