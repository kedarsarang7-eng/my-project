import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, DeleteCommand, QueryCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { CognitoJwtVerifier } from 'aws-jwt-verify/cognito-verifier';
import { randomUUID } from 'crypto';

// DynamoDB Client with retry configuration
const client = new DynamoDBClient({
  maxAttempts: 3,
  retryMode: 'adaptive',
});
export const docClient = DynamoDBDocumentClient.from(client);

/**
 * Retry wrapper for DynamoDB operations with exponential backoff
 * @param {Function} operation - Async operation to retry
 * @param {number} maxRetries - Maximum number of retries (default: 3)
 * @param {number} baseDelay - Base delay in ms (default: 100)
 */
export async function withRetry(operation, maxRetries = 3, baseDelay = 100) {
  let lastError;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      // Don't retry on certain errors
      if (error.name === 'ConditionalCheckFailedException' ||
          error.name === 'ValidationException' ||
          error.name === 'ResourceNotFoundException') {
        throw error;
      }
      
      // Don't retry after last attempt
      if (attempt === maxRetries) {
        break;
      }
      
      // Exponential backoff with jitter
      const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 100;
      console.warn(`Retry attempt ${attempt + 1}/${maxRetries} after ${delay}ms. Error: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  
  throw lastError;
}

// JWT Verifier - uses environment variables without TypeScript non-null assertions
const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID,
  tokenUse: 'access',
  clientId: process.env.COGNITO_CLIENT_ID,
});

// Response Helpers
export function success(data, statusCode = 200) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': randomUUID(),
    },
    body: JSON.stringify(data),
  };
}

export function error(message, statusCode = 400, requestId) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': requestId || randomUUID(),
    },
    body: JSON.stringify({
      error: getErrorType(statusCode),
      message,
      requestId: requestId || randomUUID(),
    }),
  };
}

function getErrorType(statusCode) {
  switch (statusCode) {
    case 400: return 'BAD_REQUEST';
    case 401: return 'UNAUTHORIZED';
    case 403: return 'FORBIDDEN';
    case 404: return 'NOT_FOUND';
    case 409: return 'CONFLICT';
    case 422: return 'VALIDATION_ERROR';
    case 500: return 'INTERNAL_ERROR';
    default: return 'UNKNOWN_ERROR';
  }
}

// JWT Verifier with full Cognito integration (P0 FIX)
export async function verifyToken(token) {
  try {
    const payload = await verifier.verify(token);
    
    // Extract and normalize user context
    const userContext = {
      userId: payload.sub,
      tenantId: payload['custom:tenantId'] || payload.tenantId,
      role: payload['custom:role'] || payload.role,
      email: payload.email,
      phone: payload.phone_number,
      name: payload.name || payload['custom:name'],
      groups: payload['cognito:groups'] || [],
      // Session tracking
      sessionId: payload.jti,
      issuedAt: new Date(payload.iat * 1000).toISOString(),
      expiresAt: new Date(payload.exp * 1000).toISOString(),
    };
    
    // Validate required fields
    if (!userContext.tenantId) {
      throw new Error('Token missing tenantId');
    }
    
    if (!userContext.role) {
      throw new Error('Token missing role');
    }
    
    return userContext;
  } catch (err) {
    console.error('Token verification failed:', err.message);
    throw new Error('INVALID_TOKEN: ' + err.message);
  }
}

// Role-based access control helper (P0 FIX)
export function requireRole(...allowedRoles) {
  return async (event) => {
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new Error('AUTH_REQUIRED: Authorization header required');
    }
    
    const token = authHeader.substring(7);
    const user = await verifyToken(token);
    
    // Check role
    const normalizedUserRole = (user.role || '').toLowerCase().trim();
    const normalizedAllowed = allowedRoles.map(r => r.toLowerCase().trim());
    
    if (!normalizedAllowed.includes(normalizedUserRole)) {
      console.error(`Role denied: ${user.role} not in [${allowedRoles.join(', ')}]`);
      throw new Error(`FORBIDDEN: Required role: ${allowedRoles.join(' or ')}`);
    }
    
    // Attach user context to event
    event.user = user;
    return user;
  };
}

// Extract user context — prefers Lambda Authorizer context injected by CustomerJwtAuthorizer,
// falls back to full JWT verification from Authorization header.
export async function extractUserContext(event) {
  // Path 1: context injected by Lambda Authorizer (CustomerJwtAuthorizer)
  const authorizerCtx =
    event.requestContext?.authorizer?.lambda ||
    event.requestContext?.authorizer;
  if (authorizerCtx?.userId) {
    return {
      userId: authorizerCtx.userId,
      role: authorizerCtx.role,
      phone: authorizerCtx.phone || '',
      email: authorizerCtx.email || '',
      tenantId: authorizerCtx.tenantId || authorizerCtx.userId,
      groups: [],
    };
  }

  // Path 2: raw Bearer token (owner-app Lambdas that skip the Lambda Authorizer)
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  try {
    const token = authHeader.substring(7);
    return await verifyToken(token);
  } catch (err) {
    console.warn('Failed to extract user context:', err.message);
    return null;
  }
}

// DynamoDB Helpers
export async function getItem(tableName, key) {
  const command = new GetCommand({
    TableName: tableName,
    Key: key,
  });
  const result = await docClient.send(command);
  return result.Item;
}

export async function putItem(tableName, item) {
  const command = new PutCommand({
    TableName: tableName,
    Item: item,
  });
  await docClient.send(command);
  return item;
}

// updateItem — two call signatures:
//   (tableName, key, updatesObject)  — auto-builds SET expression
//   (tableName, key, updateExpression, attrNames, attrValues) — explicit expression
export async function updateItem(tableName, key, updatesOrExpr, attrNames, attrValues) {
  let updateExpression, expressionAttributeNames, expressionAttributeValues;

  if (typeof updatesOrExpr === 'string') {
    // Explicit expression form used by customer handlers
    updateExpression = updatesOrExpr;
    expressionAttributeNames = attrNames || undefined;
    expressionAttributeValues = attrValues || undefined;
  } else {
    // Object form — auto-build SET expression
    expressionAttributeNames = {};
    expressionAttributeValues = {};
    const setParts = [];
    Object.entries(updatesOrExpr).forEach(([k, v], i) => {
      expressionAttributeNames[`#attr${i}`] = k;
      expressionAttributeValues[`:val${i}`] = v;
      setParts.push(`#attr${i} = :val${i}`);
    });
    updateExpression = 'SET ' + setParts.join(', ');
  }

  const command = new UpdateCommand({
    TableName: tableName,
    Key: key,
    UpdateExpression: updateExpression,
    ...(expressionAttributeNames ? { ExpressionAttributeNames: expressionAttributeNames } : {}),
    ...(expressionAttributeValues ? { ExpressionAttributeValues: expressionAttributeValues } : {}),
    ReturnValues: 'ALL_NEW',
  });
  const result = await docClient.send(command);
  return result.Attributes;
}

export async function deleteItem(tableName, key) {
  const command = new DeleteCommand({
    TableName: tableName,
    Key: key,
  });
  await docClient.send(command);
}

// queryItems — two call signatures:
//   (tableName, keyCondition, exprValues, filterExpr, options)  — original
//   (tableName, keyCondition, exprValues, options)  — object options (used by customer handlers)
export async function queryItems(
  tableName,
  keyConditionExpression,
  expressionAttributeValues,
  filterOrOptions,
  optionsArg = {}
) {
  let filterExpression, options;
  if (typeof filterOrOptions === 'string' || filterOrOptions == null) {
    filterExpression = filterOrOptions;
    options = optionsArg;
  } else {
    // Called with (tableName, key, values, optionsObj)
    filterExpression = undefined;
    options = filterOrOptions;
  }

  // Merge ExpressionAttributeValues from options if present
  const mergedValues = {
    ...expressionAttributeValues,
    ...(options.ExpressionAttributeValues || {}),
  };
  const { ExpressionAttributeValues: _, ...restOptions } = options;

  const command = new QueryCommand({
    TableName: tableName,
    KeyConditionExpression: keyConditionExpression,
    ExpressionAttributeValues: Object.keys(mergedValues).length ? mergedValues : undefined,
    ...(filterExpression ? { FilterExpression: filterExpression } : {}),
    ...restOptions,
  });
  const result = await docClient.send(command);
  return result.Items || [];
}

export async function scanItems(tableName, filterExpression, expressionAttributeValues) {
  let items = [];
  let lastKey = undefined;

  do {
    const command = new ScanCommand({
      TableName: tableName,
      FilterExpression: filterExpression,
      ExpressionAttributeValues: expressionAttributeValues,
      ExclusiveStartKey: lastKey,
    });
    const result = await docClient.send(command);
    items.push(...(result.Items || []));
    lastKey = result.LastEvaluatedKey;
  } while (lastKey);

  return items;
}

// Validation Helpers
export function validateTenantAccess(userTenantId, requestedTenantId) {
  if (requestedTenantId && userTenantId !== requestedTenantId) {
    throw new Error('FORBIDDEN');
  }
  return userTenantId;
}

export function requireAdminRole(role) {
  const normalized = String(role || '').trim().toLowerCase();
  if (!['admin', 'superadmin'].includes(normalized)) {
    throw new Error('FORBIDDEN');
  }
}

// Audit Logging — two signatures:
//   logAuditEvent(tenantId, userId, action, resource, resourceId, changes, ip, ua)  — positional
//   logAuditEvent({ action, userId, resourceId, details })  — object (used by customer handlers)
export async function logAuditEvent(
  tenantIdOrObj,
  userId,
  action,
  resource,
  resourceId,
  changes,
  ipAddress,
  userAgent
) {
  let item;
  const eventId = randomUUID();
  const timestamp = new Date().toISOString();
  const expiresAt = Math.floor(Date.now() / 1000) + 90 * 24 * 60 * 60;

  if (typeof tenantIdOrObj === 'object' && tenantIdOrObj !== null) {
    // Object form
    const { action: act, userId: uid, resourceId: rid, details, tenantId } = tenantIdOrObj;
    item = {
      tenantId: tenantId || uid || 'unknown',
      SK: `${timestamp}#${eventId}`,
      eventId,
      userId: uid,
      action: act,
      resource: rid,
      resourceId: rid,
      changes: details || {},
      severity: 'info',
      expiresAt,
    };
  } else {
    // Positional form
    item = {
      tenantId: tenantIdOrObj,
      SK: `${timestamp}#${eventId}`,
      eventId,
      userId,
      action,
      resource,
      resourceId,
      changes,
      ipAddress,
      userAgent,
      severity: 'info',
      expiresAt,
    };
  }

  const auditTable = process.env.DYNAMODB_TABLE_AUDIT || process.env.AUDIT_LOGS_TABLE;
  if (!auditTable) {
    console.warn('Audit table not configured, skipping audit log');
    return;
  }
  await putItem(auditTable, item);
}

// ============================================================================
// PAGINATION HELPERS (P0 FIX)
// ============================================================================

export function getPaginationParams(event) {
  const queryParams = event.queryStringParameters || {};
  
  // Validate and sanitize limit (default 50, max 100)
  let limit = parseInt(queryParams.limit) || 50;
  limit = Math.max(1, Math.min(limit, 100));
  
  // Decode cursor if present
  let cursor = null;
  if (queryParams.cursor) {
    try {
      cursor = JSON.parse(Buffer.from(queryParams.cursor, 'base64').toString());
    } catch (err) {
      console.warn('Invalid pagination cursor:', err.message);
      // Continue without cursor (will return first page)
    }
  }
  
  return {
    limit,
    cursor,
    sortBy: queryParams.sortBy || 'createdAt',
    sortOrder: queryParams.sortOrder || 'desc',
  };
}

export function createPaginationResponse(items, limit, lastEvaluatedKey) {
  return {
    items,
    pagination: {
      cursor: lastEvaluatedKey 
        ? Buffer.from(JSON.stringify(lastEvaluatedKey)).toString('base64')
        : null,
      hasMore: !!lastEvaluatedKey,
      limit,
      count: items.length,
    },
  };
}

// ============================================================================
// TENANT ISOLATION HELPERS (P0 FIX)
// ============================================================================

/**
 * Enforces tenant isolation on any data operation
 * Must be called before every DynamoDB query/write
 */
export function enforceTenantScope(data, userContext) {
  if (!userContext || !userContext.tenantId) {
    throw new Error('TENANT_CONTEXT_MISSING: User context required');
  }
  
  // If data doesn't have tenantId, set it
  if (!data.tenantId) {
    data.tenantId = userContext.tenantId;
  }
  
  // Critical: Verify data belongs to user's tenant
  if (data.tenantId !== userContext.tenantId) {
    console.error(`TENANT_ISOLATION_VIOLATION: User ${userContext.userId} attempted cross-tenant access`);
    console.error(`  User tenant: ${userContext.tenantId}`);
    console.error(`  Data tenant: ${data.tenantId}`);
    throw new Error('TENANT_ISOLATION_VIOLATION: Cross-tenant access denied');
  }
  
  return data;
}

/**
 * Creates DynamoDB key condition with tenant enforcement
 */
export function withTenantCondition(keyCondition, tenantId) {
  return {
    expression: keyCondition,
    values: {
      ':tenantId': tenantId,
    },
  };
}

/**
 * Wraps a Lambda handler with tenant isolation
 */
export function withTenantIsolation(handler) {
  return async (event, context) => {
    try {
      // Extract user context
      const userContext = await extractUserContext(event);
      
      if (!userContext) {
        return error('Authentication required', 401);
      }
      
      // Attach to event for handlers
      event.user = userContext;
      
      // Call the handler
      const result = await handler(event, context);
      
      return result;
    } catch (err) {
      if (err.message.includes('TENANT_ISOLATION_VIOLATION')) {
        console.error('Security violation:', err.message);
        return error('Access denied', 403);
      }
      throw err;
    }
  };
}

// ============================================================================
// CONDITIONAL WRITE HELPERS (P0 FIX)
// ============================================================================

/**
 * Creates conditional update for optimistic locking
 */
export function createConditionalUpdate(params) {
  const { 
    tableName, 
    key, 
    updates, 
    expectedVersion,
    tenantId,
  } = params;
  
  const expressionAttributeNames = {};
  const expressionAttributeValues = {};
  const setParts = [];
  
  Object.entries(updates).forEach(([k, v], i) => {
    const nameKey = `#f${i}`;
    const valueKey = `:v${i}`;
    expressionAttributeNames[nameKey] = k;
    expressionAttributeValues[valueKey] = v;
    setParts.push(`${nameKey} = ${valueKey}`);
  });
  
  // Add updatedAt timestamp
  const timestamp = new Date().toISOString();
  expressionAttributeValues[':now'] = timestamp;
  setParts.push('#updatedAt = :now');
  expressionAttributeNames['#updatedAt'] = 'updatedAt';
  
  // Build condition expression
  let conditionExpression = '#tenantId = :tenantId';
  expressionAttributeNames['#tenantId'] = 'tenantId';
  expressionAttributeValues[':tenantId'] = tenantId;
  
  if (expectedVersion !== undefined) {
    conditionExpression += ' AND #version = :expectedVersion';
    expressionAttributeNames['#version'] = 'version';
    expressionAttributeValues[':expectedVersion'] = expectedVersion;
  }
  
  return {
    TableName: tableName,
    Key: key,
    UpdateExpression: `SET ${setParts.join(', ')}`,
    ConditionExpression: conditionExpression,
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
    ReturnValues: 'ALL_NEW',
  };
}

/**
 * Helper for optimistic locking version increment
 */
export function withVersionIncrement(updates, currentVersion) {
  return {
    ...updates,
    version: (currentVersion || 0) + 1,
  };
}