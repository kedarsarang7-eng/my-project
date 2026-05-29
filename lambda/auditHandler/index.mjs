import { success, error, verifyToken, queryItems, putItem, requireAdminRole, getPaginationParams, createPaginationResponse } from '../shared/utils.mjs';

// GET /audit/logs
export async function queryLogs(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const { limit, nextToken } = getPaginationParams(event);
    const queryParams = event.queryStringParameters || {};

    let keyCondition = 'tenantId = :tenantId';
    let expressionAttributeValues = { ':tenantId': tenantId };
    let filterExpression = '';

    // Add time range filter
    if (queryParams.startDate && queryParams.endDate) {
      keyCondition += ' AND SK between :start AND :end';
      expressionAttributeValues[':start'] = `${queryParams.startDate}T00:00:00.000Z`;
      expressionAttributeValues[':end'] = `${queryParams.endDate}T23:59:59.999Z`;
    }

    // Add user filter
    if (queryParams.userId) {
      filterExpression = 'userId = :userId';
      expressionAttributeValues[':userId'] = queryParams.userId;
    }

    // Add action filter
    if (queryParams.action) {
      const actionFilter = filterExpression ? ' AND action = :action' : 'action = :action';
      filterExpression += actionFilter;
      expressionAttributeValues[':action'] = queryParams.action;
    }

    // Add resource filter
    if (queryParams.resource) {
      const resourceFilter = filterExpression ? ' AND resource = :resource' : 'resource = :resource';
      filterExpression += resourceFilter;
      expressionAttributeValues[':resource'] = queryParams.resource;
    }

    const logs = await queryItems(
      process.env.DYNAMODB_TABLE_AUDIT,
      keyCondition,
      expressionAttributeValues,
      filterExpression || undefined
    );

    // Sort by timestamp descending
    logs.sort((a, b) => b.SK.localeCompare(a.SK));

    return success(createPaginationResponse(logs.slice(0, limit), limit));
  } catch (err) {
    console.error('Query logs error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to query logs', 500);
  }
}

// GET /audit/export
export async function exportLogs(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const queryParams = event.queryStringParameters || {};

    let keyCondition = 'tenantId = :tenantId';
    let expressionAttributeValues = { ':tenantId': tenantId };

    // Add time range filter
    if (queryParams.startDate && queryParams.endDate) {
      keyCondition += ' AND SK between :start AND :end';
      expressionAttributeValues[':start'] = `${queryParams.startDate}T00:00:00.000Z`;
      expressionAttributeValues[':end'] = `${queryParams.endDate}T23:59:59.999Z`;
    }

    const logs = await queryItems(
      process.env.DYNAMODB_TABLE_AUDIT,
      keyCondition,
      expressionAttributeValues
    );

    // Convert to CSV
    const csvHeaders = ['timestamp', 'userId', 'action', 'resource', 'resourceId', 'ipAddress', 'userAgent', 'severity'];
    const csvRows = logs.map(log => [
      log.SK.split('#')[0],
      log.userId,
      log.action,
      log.resource,
      log.resourceId || '',
      log.ipAddress || '',
      log.userAgent || '',
      log.severity,
    ]);

    const csvContent = [csvHeaders, ...csvRows]
      .map(row => row.map(field => `"${field}"`).join(','))
      .join('\n');

    // In a real implementation, you'd upload this to S3 and return a presigned URL
    // For now, return the CSV content directly
    return success({
      csvContent,
      filename: `audit-logs-${tenantId}-${new Date().toISOString().split('T')[0]}.csv`,
      message: 'In production, this would return a presigned S3 URL for download'
    });
  } catch (err) {
    console.error('Export logs error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to export logs', 500);
  }
}

// Utility function for logging events (called by other handlers)
export async function logEvent(
  tenantId,
  userId,
  action,
  resource,
  resourceId,
  changes,
  ipAddress,
  userAgent
) {
  const eventId = Math.random().toString(36).substring(2, 15);
  const timestamp = new Date().toISOString();
  const expiresAt = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 90 days

  const auditItem = {
    tenantId,
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

  try {
    await putItem(process.env.DYNAMODB_TABLE_AUDIT, auditItem);
  } catch (err) {
    console.error('Failed to log audit event:', err);
    // Don't throw - audit logging failures shouldn't break the main operation
  }
}

// GET /audit/stats - System overview stats for admin dashboard
export async function getStats(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    // SECURITY FIX: Scope all queries to caller's tenant to prevent cross-tenant data leak
    const tenantId = decoded.tenantId;

    // Get users count — scoped to this tenant
    const userTable = process.env.DYNAMODB_TABLE_USERS || 'Users';
    const tenantUsers = await queryItems(
      userTable,
      'tenantId = :tenantId',
      { ':tenantId': tenantId },
      undefined,
      { IndexName: 'GSI_TenantRole' }
    );
    const totalUsers = tenantUsers.length;
    const activeUsers = tenantUsers.filter(u => u.status === 'active').length;

    // Calculate revenue — scoped to this tenant
    const billingTable = process.env.DYNAMODB_TABLE_BILLING || 'Billing';
    const billingRecords = await queryItems(billingTable, 'tenantId = :tenantId', { ':tenantId': tenantId });
    const totalRevenue = billingRecords.reduce((sum, r) => sum + (r.amount || 0), 0);
    
    // Monthly revenue (current month)
    const now = new Date();
    const currentMonth = now.toISOString().slice(0, 7); // YYYY-MM
    const monthlyRevenue = billingRecords
      .filter(r => r.month === currentMonth)
      .reduce((sum, r) => sum + (r.amount || 0), 0);

    return success({
      stats: {
        totalUsers,
        activeUsers,
        totalRevenue,
        monthlyRevenue,
      }
    });
  } catch (err) {
    console.error('Get stats error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to get stats', 500);
  }
}

// GET /audit/recent - Recent system activities for admin dashboard
export async function getRecentActivities(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const auditTable = process.env.DYNAMODB_TABLE_AUDIT || 'Audit';
    const { limit = 20 } = event.queryStringParameters || {};

    // SECURITY FIX: Scope to caller's tenant
    const tenantId = decoded.tenantId;
    const logs = await queryItems(
      auditTable,
      'tenantId = :tenantId',
      { ':tenantId': tenantId }
    );

    // Sort by timestamp descending and limit
    const recentLogs = logs
      .sort((a, b) => b.SK.localeCompare(a.SK))
      .slice(0, parseInt(limit))
      .map(log => ({
        type: getActivityType(log.action),
        message: formatActivityMessage(log),
        timestamp: log.SK.split('#')[0],
        userId: log.userId,
        severity: log.severity,
      }));

    return success({
      activities: recentLogs,
    });
  } catch (err) {
    console.error('Get recent activities error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to get recent activities', 500);
  }
}

// Helper to determine activity type from action
function getActivityType(action) {
  if (action?.includes('TENANT')) return 'tenant_created';
  if (action?.includes('USER')) return 'user_invited';
  if (action?.includes('SUBSCRIPTION') && action?.includes('CANCEL')) return 'subscription_cancelled';
  if (action?.includes('SUSPEND')) return 'tenant_suspended';
  return 'other';
}

// Helper to format activity message
function formatActivityMessage(log) {
  const action = log.action || 'Unknown action';
  const resource = log.resource || '';
  const userId = log.userId ? `by ${log.userId}` : '';
  return `${action} ${resource} ${userId}`.trim();
}

export async function handler(event) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;

  switch (route) {
    case 'GET /audit/logs':
      return queryLogs(event);
    case 'GET /audit/export':
      return exportLogs(event);
    case 'GET /audit/stats':
      return getStats(event);
    case 'GET /audit/recent':
      return getRecentActivities(event);
    default:
      return error(`Unsupported audit route: ${route}`, 404);
  }
}