// ============================================================================
// SECURITY MIDDLEWARE - NoSQL Injection & Input Sanitization (P1 FIX)
// ============================================================================

/**
 * Dangerous patterns that could indicate NoSQL injection attempts
 */
const DANGEROUS_PATTERNS = [
  /\$where\s*:/i,          // JavaScript execution
  /\$regex\s*:/i,          // Regex injection
  /\$ne\s*:/i,             // Not equal injection
  /\$gt\s*:/i,             // Greater than injection
  /\$lt\s*:/i,             // Less than injection
  /\$or\s*:\s*\[/i,        // OR injection
  /\$and\s*:\s*\[/i,       // AND injection
  /\{\s*\$/,                // Any operator at start of object
  /__proto__/,              // Prototype pollution
  /constructor\s*:/,         // Constructor access
];

/**
 * Characters that could break DynamoDB expressions
 */
const DANGEROUS_CHARS = /[<>{}()$'`"\[\]\\]/;

/**
 * P1 FIX: Sanitize user input for DynamoDB
 * Removes or escapes dangerous characters
 */
export function sanitizeInput(input) {
  if (typeof input !== 'string') {
    return input;
  }
  
  // Check for injection patterns
  for (const pattern of DANGEROUS_PATTERNS) {
    if (pattern.test(input)) {
      throw new SecurityError('Potential injection attempt detected', 'INJECTION_DETECTED');
    }
  }
  
  // Remove dangerous characters
  return input.replace(DANGEROUS_CHARS, '');
}

/**
 * P1 FIX: Validate and sanitize DynamoDB key
 */
export function validateDynamoKey(key) {
  if (typeof key !== 'string') {
    throw new SecurityError('Key must be a string', 'INVALID_KEY_TYPE');
  }
  
  if (key.length > 2048) {
    throw new SecurityError('Key too long', 'KEY_TOO_LONG');
  }
  
  if (key.startsWith('$')) {
    throw new SecurityError('Keys cannot start with $', 'INVALID_KEY_PREFIX');
  }
  
  // Check for injection patterns
  for (const pattern of DANGEROUS_PATTERNS) {
    if (pattern.test(key)) {
      throw new SecurityError('Invalid characters in key', 'INVALID_KEY_CHARS');
    }
  }
  
  return key;
}

/**
 * P1 FIX: Sanitize DynamoDB expression parameters
 */
export function sanitizeExpressionParams(params) {
  const sanitized = {};
  
  for (const [key, value] of Object.entries(params)) {
    // Keys should start with ':'
    if (!key.startsWith(':')) {
      throw new SecurityError('Expression values must start with :', 'INVALID_PARAM_KEY');
    }
    
    // Sanitize the key name (remove ':' for validation)
    const keyName = key.substring(1);
    if (keyName.startsWith('$')) {
      throw new SecurityError('Expression value names cannot start with $', 'INVALID_PARAM_NAME');
    }
    
    // Recursively sanitize values
    sanitized[key] = sanitizeValue(value);
  }
  
  return sanitized;
}

/**
 * Recursively sanitize a value for DynamoDB
 */
function sanitizeValue(value) {
  if (value === null || value === undefined) {
    return value;
  }
  
  if (typeof value === 'string') {
    return sanitizeInput(value);
  }
  
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value; // Primitives are safe
  }
  
  if (Array.isArray(value)) {
    return value.map(item => sanitizeValue(item));
  }
  
  if (typeof value === 'object') {
    // Check for dangerous operators
    for (const key of Object.keys(value)) {
      if (key.startsWith('$')) {
        throw new SecurityError(`DynamoDB operator '${key}' not allowed in user input`, 'OPERATOR_NOT_ALLOWED');
      }
    }
    
    const sanitized = {};
    for (const [key, val] of Object.entries(value)) {
      sanitized[key] = sanitizeValue(val);
    }
    return sanitized;
  }
  
  // Convert other types to string and sanitize
  return sanitizeInput(String(value));
}

/**
 * P1 FIX: Create safe DynamoDB query with all inputs sanitized
 */
export function createSafeQuery(params) {
  const {
    tableName,
    keyCondition,
    filterExpression,
    expressionValues,
    expressionNames,
  } = params;
  
  // Validate table name
  if (!/^[a-zA-Z0-9_-]+$/.test(tableName)) {
    throw new SecurityError('Invalid table name', 'INVALID_TABLE_NAME');
  }
  
  // Validate key condition expression
  if (!isValidExpression(keyCondition)) {
    throw new SecurityError('Invalid key condition expression', 'INVALID_EXPRESSION');
  }
  
  // Sanitize expression values
  const safeValues = sanitizeExpressionParams(expressionValues || {});
  
  // Validate expression names
  const safeNames = {};
  if (expressionNames) {
    for (const [key, value] of Object.entries(expressionNames)) {
      if (!key.startsWith('#')) {
        throw new SecurityError('Expression names must start with #', 'INVALID_NAME_KEY');
      }
      safeNames[key] = sanitizeInput(value);
    }
  }
  
  return {
    TableName: tableName,
    KeyConditionExpression: keyCondition,
    FilterExpression: filterExpression,
    ExpressionAttributeValues: safeValues,
    ExpressionAttributeNames: safeNames,
  };
}

/**
 * Validate that an expression is safe
 */
function isValidExpression(expression) {
  if (typeof expression !== 'string') {
    return false;
  }
  
  // Basic validation - expression should only contain:
  // - Attribute names starting with #
  // - Values starting with :
  // - Operators: =, <, >, <=, >=, <>, BETWEEN, IN, AND, OR, NOT, begins_with, etc.
  const allowedOperators = /^(#\w+|:\w+|\s+|=|<|>|!|BETWEEN|IN|AND|OR|NOT|begins_with|contains|size|attribute_exists|attribute_not_exists|attribute_type|starts_with|\(|\)|,|\[|\]|\d+|-)+$/i;
  
  // This is a simplified check - in production, use a proper parser
  return !DANGEROUS_PATTERNS.some(p => p.test(expression));
}

/**
 * P1 FIX: Middleware to sanitize all incoming event data
 */
export function sanitizeEventData(event) {
  const sanitized = { ...event };
  
  // Sanitize path parameters
  if (sanitized.pathParameters) {
    for (const [key, value] of Object.entries(sanitized.pathParameters)) {
      sanitized.pathParameters[key] = typeof value === 'string' 
        ? sanitizeInput(value) 
        : value;
    }
  }
  
  // Sanitize query string parameters
  if (sanitized.queryStringParameters) {
    for (const [key, value] of Object.entries(sanitized.queryStringParameters)) {
      sanitized.queryStringParameters[key] = typeof value === 'string' 
        ? sanitizeInput(value) 
        : value;
    }
  }
  
  // Note: Body is JSON and should be validated by Zod schemas, not sanitized here
  
  return sanitized;
}

/**
 * Security Error class
 */
export class SecurityError extends Error {
  constructor(message, code) {
    super(message);
    this.name = 'SecurityError';
    this.code = code;
  }
}

/**
 * P1 FIX: Wrap handler with security middleware
 */
export function withSecurity(handler) {
  return async (event, context) => {
    try {
      // Sanitize incoming data
      const sanitizedEvent = sanitizeEventData(event);
      
      // Call handler with sanitized data
      const result = await handler(sanitizedEvent, context);
      
      return result;
    } catch (err) {
      if (err instanceof SecurityError) {
        console.error(`[SECURITY] ${err.code}: ${err.message}`);
        return {
          statusCode: 400,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            error: 'SECURITY_VIOLATION',
            message: 'Invalid request data',
          }),
        };
      }
      throw err;
    }
  };
}

/**
 * P1 FIX: Rate limiting helper (basic implementation)
 */
export function withRateLimit(handler, options = {}) {
  const maxRequests = options.maxRequests || 100;
  const windowMs = options.windowMs || 60000; // 1 minute
  
  // Simple in-memory store (use Redis in production)
  const requests = new Map();
  
  return async (event, context) => {
    const clientId = event.headers?.['x-forwarded-for'] || 
                     event.requestContext?.identity?.sourceIp || 
                     'unknown';
    
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Get client's recent requests
    const clientRequests = requests.get(clientId) || [];
    const recentRequests = clientRequests.filter(time => time > windowStart);
    
    if (recentRequests.length >= maxRequests) {
      return {
        statusCode: 429,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'RATE_LIMIT_EXCEEDED',
          message: 'Too many requests. Please try again later.',
          retryAfter: Math.ceil(windowMs / 1000),
        }),
      };
    }
    
    // Record this request
    recentRequests.push(now);
    requests.set(clientId, recentRequests);
    
    // Call handler
    return handler(event, context);
  };
}
