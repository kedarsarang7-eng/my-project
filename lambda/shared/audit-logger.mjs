// ============================================================================
// AUDIT LOGGER - Comprehensive Audit Trail (P3 FIX)
// ============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

/**
 * Audit event types
 */
export const AuditEventTypes = {
  // Authentication
  USER_LOGIN: 'USER_LOGIN',
  USER_LOGOUT: 'USER_LOGOUT',
  USER_REGISTERED: 'USER_REGISTERED',
  PASSWORD_CHANGED: 'PASSWORD_CHANGED',
  MFA_ENABLED: 'MFA_ENABLED',
  MFA_DISABLED: 'MFA_DISABLED',
  
  // Billing
  BILL_CREATED: 'BILL_CREATED',
  BILL_UPDATED: 'BILL_UPDATED',
  BILL_CANCELLED: 'BILL_CANCELLED',
  BILL_PRINTED: 'BILL_PRINTED',
  PAYMENT_PROCESSED: 'PAYMENT_PROCESSED',
  REFUND_PROCESSED: 'REFUND_PROCESSED',
  
  // Inventory
  STOCK_ADDED: 'STOCK_ADDED',
  STOCK_REMOVED: 'STOCK_REMOVED',
  STOCK_ADJUSTED: 'STOCK_ADJUSTED',
  PRODUCT_CREATED: 'PRODUCT_CREATED',
  PRODUCT_UPDATED: 'PRODUCT_UPDATED',
  PRODUCT_DELETED: 'PRODUCT_DELETED',
  
  // Customers
  CUSTOMER_CREATED: 'CUSTOMER_CREATED',
  CUSTOMER_UPDATED: 'CUSTOMER_UPDATED',
  CUSTOMER_DELETED: 'CUSTOMER_DELETED',
  CREDIT_LIMIT_CHANGED: 'CREDIT_LIMIT_CHANGED',
  
  // Staff
  STAFF_CREATED: 'STAFF_CREATED',
  STAFF_UPDATED: 'STAFF_UPDATED',
  STAFF_DELETED: 'STAFF_DELETED',
  ATTENDANCE_MARKED: 'ATTENDANCE_MARKED',
  ROLE_CHANGED: 'ROLE_CHANGED',
  
  // Security
  PERMISSION_DENIED: 'PERMISSION_DENIED',
  TENANT_ACCESS_ATTEMPT: 'TENANT_ACCESS_ATTEMPT',
  RATE_LIMIT_HIT: 'RATE_LIMIT_HIT',
  SUSPICIOUS_ACTIVITY: 'SUSPICIOUS_ACTIVITY',
  
  // Configuration
  SETTINGS_CHANGED: 'SETTINGS_CHANGED',
  PLAN_CHANGED: 'PLAN_CHANGED',
  SUBSCRIPTION_CANCELLED: 'SUBSCRIPTION_CANCELLED',
};

/**
 * Severity levels for audit events
 */
export const AuditSeverity = {
  INFO: 'info',
  WARNING: 'warning',
  CRITICAL: 'critical',
};

/**
 * P3 FIX: Log audit event asynchronously (fire-and-forget)
 */
export async function logAuditEvent(eventType, params) {
  const {
    tenantId,
    userId,
    userRole,
    resourceType,
    resourceId,
    action,
    status,
    details = {},
    ipAddress,
    userAgent,
    requestId,
    severity = AuditSeverity.INFO,
    metadata = {},
  } = params;

  const auditTable = process.env.DYNAMODB_TABLE_AUDIT;
  
  if (!auditTable) {
    console.warn('AUDIT: DYNAMODB_TABLE_AUDIT not configured');
    return;
  }

  const auditId = randomUUID();
  const timestamp = new Date().toISOString();
  const ttlSeconds = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 90 days retention

  const auditItem = {
    // Primary keys
    PK: `AUDIT#${tenantId}`,
    SK: `EVENT#${timestamp}#${auditId}`,
    
    // GSI1: Query by event type
    GSI1PK: `TYPE#${eventType}`,
    GSI1SK: `TENANT#${tenantId}#${timestamp}`,
    
    // GSI2: Query by user
    GSI2PK: `USER#${userId}`,
    GSI2SK: `EVENT#${timestamp}`,
    
    // GSI3: Query by resource
    GSI3PK: `RESOURCE#${resourceType}#${resourceId || 'unknown'}`,
    GSI3SK: `TIME#${timestamp}`,
    
    // Event details
    auditId,
    eventType,
    tenantId,
    userId,
    userRole,
    resourceType,
    resourceId,
    action,
    status,
    details,
    
    // Request context
    ipAddress: ipAddress || 'unknown',
    userAgent: userAgent || 'unknown',
    requestId: requestId || 'unknown',
    
    // Metadata
    severity,
    metadata,
    
    // Timestamps
    createdAt: timestamp,
    ttl: ttlSeconds,
  };

  // Fire-and-forget: Don't await, don't block
  docClient.send(new PutCommand({
    TableName: auditTable,
    Item: auditItem,
  })).catch(err => {
    console.error('AUDIT: Failed to log event:', err.message);
  });
}

/**
 * P3 FIX: Log authentication event
 */
export function logAuthEvent(eventType, params) {
  return logAuditEvent(eventType, {
    ...params,
    resourceType: 'auth',
    severity: eventType.includes('DENIED') || eventType.includes('FAILED')
      ? AuditSeverity.WARNING
      : AuditSeverity.INFO,
  });
}

/**
 * P3 FIX: Log billing event
 */
export function logBillingEvent(eventType, params) {
  return logAuditEvent(eventType, {
    ...params,
    resourceType: 'billing',
    severity: eventType.includes('CANCELLED') || eventType.includes('REFUND')
      ? AuditSeverity.WARNING
      : AuditSeverity.INFO,
  });
}

/**
 * P3 FIX: Log inventory event
 */
export function logInventoryEvent(eventType, params) {
  return logAuditEvent(eventType, {
    ...params,
    resourceType: 'inventory',
    severity: eventType.includes('DELETED') || eventType.includes('ADJUSTED')
      ? AuditSeverity.WARNING
      : AuditSeverity.INFO,
  });
}

/**
 * P3 FIX: Log security event
 */
export function logSecurityEvent(eventType, params) {
  return logAuditEvent(eventType, {
    ...params,
    resourceType: 'security',
    severity: AuditSeverity.CRITICAL,
  });
}

/**
 * P3 FIX: Query audit log for tenant
 */
export async function queryAuditLog(tenantId, options = {}) {
  const {
    eventTypes = [],
    startDate,
    endDate,
    userId,
    limit = 50,
    cursor,
  } = options;

  const auditTable = process.env.DYNAMODB_TABLE_AUDIT;
  
  if (!auditTable) {
    throw new Error('DYNAMODB_TABLE_AUDIT not configured');
  }

  let keyCondition = 'PK = :pk';
  const expressionValues = {
    ':pk': `AUDIT#${tenantId}`,
  };

  // Add date range if specified
  if (startDate && endDate) {
    keyCondition += ' AND SK BETWEEN :start AND :end';
    expressionValues[':start'] = `EVENT#${startDate}`;
    expressionValues[':end'] = `EVENT#${endDate}`;
  }

  const params = {
    TableName: auditTable,
    KeyConditionExpression: keyCondition,
    ExpressionAttributeValues: expressionValues,
    ScanIndexForward: false, // Newest first
    Limit: limit,
  };

  if (cursor) {
    params.ExclusiveStartKey = cursor;
  }

  // Filter by event types if specified
  if (eventTypes.length > 0) {
    params.FilterExpression = eventTypes
      .map((_, i) => `eventType = :type${i}`)
      .join(' OR ');
    
    eventTypes.forEach((type, i) => {
      params.ExpressionAttributeValues[`:type${i}`] = type;
    });
  }

  const result = await docClient.send(new QueryCommand(params));

  return {
    events: result.Items || [],
    nextCursor: result.LastEvaluatedKey,
    count: result.Count,
  };
}

/**
 * P3 FIX: Get user activity summary
 */
export async function getUserActivitySummary(tenantId, userId, days = 7) {
  const auditTable = process.env.DYNAMODB_TABLE_AUDIT;
  
  if (!auditTable) {
    return null;
  }

  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - (days * 24 * 60 * 60 * 1000)).toISOString();

  const result = await docClient.send(new QueryCommand({
    TableName: auditTable,
    IndexName: 'GSI2',
    KeyConditionExpression: 'GSI2PK = :pk AND GSI2SK BETWEEN :start AND :end',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`,
      ':start': `EVENT#${startDate}`,
      ':end': `EVENT#${endDate}`,
    },
    ScanIndexForward: false,
  }));

  const events = result.Items || [];
  
  // Calculate summary
  const summary = {
    totalActions: events.length,
    byType: {},
    byDay: {},
    securityEvents: events.filter(e => e.resourceType === 'security').length,
  };

  events.forEach(event => {
    // Count by type
    summary.byType[event.eventType] = (summary.byType[event.eventType] || 0) + 1;
    
    // Count by day
    const day = event.createdAt.split('T')[0];
    summary.byDay[day] = (summary.byDay[day] || 0) + 1;
  });

  return summary;
}

/**
 * P3 FIX: Middleware to automatically log API calls
 */
export function withAuditLogging(handler, eventType, options = {}) {
  return async (event, context) => {
    const startTime = Date.now();
    const requestId = context.awsRequestId;
    
    // Extract user info
    const user = event.user || {};
    const tenantId = user.tenantId;
    const userId = user.userId;
    
    // Extract IP and user agent
    const ipAddress = event.headers?.['x-forwarded-for'] || 
                      event.requestContext?.http?.sourceIp ||
                      event.requestContext?.identity?.sourceIp;
    const userAgent = event.headers?.['user-agent'] ||
                        event.requestContext?.http?.userAgent;
    
    try {
      // Call handler
      const result = await handler(event, context);
      
      // Log success
      const duration = Date.now() - startTime;
      logAuditEvent(eventType, {
        tenantId,
        userId,
        userRole: user.role,
        resourceType: options.resourceType || 'api',
        resourceId: options.getResourceId?.(event) || event.pathParameters?.id,
        action: options.action || event.requestContext?.http?.method,
        status: 'success',
        details: {
          statusCode: result.statusCode,
          duration: `${duration}ms`,
        },
        ipAddress,
        userAgent,
        requestId,
        metadata: options.metadata?.(event, result),
      });
      
      return result;
      
    } catch (err) {
      // Log failure
      const duration = Date.now() - startTime;
      logAuditEvent(eventType, {
        tenantId,
        userId,
        userRole: user.role,
        resourceType: options.resourceType || 'api',
        action: options.action || event.requestContext?.http?.method,
        status: 'failed',
        details: {
          error: err.message,
          errorCode: err.code,
          duration: `${duration}ms`,
        },
        ipAddress,
        userAgent,
        requestId,
        severity: AuditSeverity.WARNING,
      });
      
      throw err;
    }
  };
}
