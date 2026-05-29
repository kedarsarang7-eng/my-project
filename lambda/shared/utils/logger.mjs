// ============================================================================
// STRUCTURED LOGGER - JSON output for CloudWatch
// ============================================================================

let currentContext = null;

/**
 * Set request context for all subsequent logs
 */
export function setLogContext(context) {
  currentContext = context;
}

/**
 * Create log entry with structured format
 */
function createLogEntry(level, message, metadata = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    requestId: currentContext?.requestId || 'unknown',
    tenantId: currentContext?.tenantId || 'unknown',
    userId: currentContext?.userId || 'unknown',
    sourceIp: currentContext?.sourceIp,
    metadata,
  };
  
  // Calculate duration if we have start time
  if (currentContext?.startTime) {
    entry.duration = Date.now() - currentContext.startTime;
  }
  
  return entry;
}

/**
 * Log at DEBUG level
 */
export function debug(message, metadata) {
  const entry = createLogEntry('DEBUG', message, metadata);
  console.log(JSON.stringify(entry));
}

/**
 * Log at INFO level
 */
export function info(message, metadata) {
  const entry = createLogEntry('INFO', message, metadata);
  console.log(JSON.stringify(entry));
}

/**
 * Log at WARN level
 */
export function warn(message, metadata) {
  const entry = createLogEntry('WARN', message, metadata);
  console.log(JSON.stringify(entry));
}

/**
 * Log at ERROR level
 */
export function error(message, err, metadata) {
  const entry = createLogEntry('ERROR', message, {
    ...metadata,
    errorMessage: err?.message,
    errorStack: err?.stack,
    errorCode: err?.code,
  });
  console.log(JSON.stringify(entry));
}

// Default export for compatibility
export default { debug, info, warn, error, setLogContext };
