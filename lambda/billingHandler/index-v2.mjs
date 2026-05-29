/**
 * BILLING HANDLER v2 - With P0 Fixes
 * 
 * Changes from v1:
 * 1. Added Zod input validation (P0)
 * 2. Added JWT verification with Cognito (P0)
 * 3. Added tenant isolation (P0)
 * 4. Added pagination to list endpoints (P0)
 * 5. Added conditional writes (P0)
 */

import { randomUUID } from 'crypto';
import { 
  success, 
  error, 
  verifyToken, 
  requireRole,
  getItem, 
  putItem, 
  updateItem, 
  queryItems,
  getPaginationParams,
  createPaginationResponse,
  enforceTenantScope,
  withTenantIsolation,
  createConditionalUpdate,
  withVersionIncrement,
  logAuditEvent 
} from '../shared/utils.mjs';

import { 
  validate, 
  SubscriptionSchema, 
  CancelSubscriptionSchema,
} from '../shared/validation.mjs';

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const PLAN_CYCLES = {
  monthly: 1, quarterly: 3, biannual: 6, yearly: 12, biennial: 24, triennial: 36,
};

const PLANS = [
  {
    id: 'basic', name: 'Basic', currency: 'INR',
    features: ['1 user', '1 branch', 'Basic billing', 'Basic support'],
    maxUsers: 1, storageGb: 5,
    pricing: { monthly: 249, quarterly: 699, biannual: 1299, yearly: 2399, biennial: 4299, triennial: 5999 },
  },
  {
    id: 'pro', name: 'Pro', currency: 'INR',
    features: ['3 users', '1 branch', 'Advanced billing', 'Priority support', 'Reports'],
    maxUsers: 3, storageGb: 20,
    pricing: { monthly: 499, quarterly: 1399, biannual: 2699, yearly: 4999, biennial: 8999, triennial: 12999 },
  },
  {
    id: 'premium', name: 'Premium', currency: 'INR',
    features: ['10 users', '3 branches', 'Multi-branch', '24/7 support', 'Custom integrations'],
    maxUsers: 10, storageGb: 100,
    pricing: { monthly: 999, quarterly: 2799, biannual: 5299, yearly: 9999, biennial: 17999, triennial: 24999 },
  },
  {
    id: 'enterprise', name: 'Enterprise', currency: 'INR',
    features: ['Unlimited users', '10 branches', 'Dedicated support', 'Custom integrations', 'Advanced security', 'SLA'],
    maxUsers: null, storageGb: 500,
    pricing: { monthly: 1999, quarterly: 5499, biannual: 10499, yearly: 19999, biennial: 35999, triennial: 49999 },
  },
];

// ============================================================================
// AUTH MIDDLEWARE
// ============================================================================

const requireBillingAdmin = requireRole('admin', 'superadmin', 'manager');

// ============================================================================
// HANDLERS WITH P0 FIXES
// ============================================================================

// GET /billing/plans - Public endpoint (no auth required for listing)
export async function listPlans(event) {
  try {
    return success({ plans: PLANS });
  } catch (err) {
    console.error('List plans error:', err);
    return error('Failed to list plans', 500);
  }
}

// POST /billing/subscribe - With validation & tenant isolation
export async function subscribe(event) {
  try {
    // P0 FIX: Validate auth and role
    const user = await requireBillingAdmin(event);
    
    // P0 FIX: Validate input with Zod
    const body = JSON.parse(event.body || '{}');
    const validation = validate(SubscriptionSchema, body);
    
    if (!validation.success) {
      return error({
        code: 'VALIDATION_ERROR',
        message: 'Invalid subscription data',
        details: validation.errors,
      }, 400);
    }
    
    const { planId, seats, billingCycle } = validation.data;
    const tenantId = user.tenantId;
    
    // P0 FIX: Tenant isolation check
    enforceTenantScope({ tenantId }, user);
    
    const plan = PLANS.find((p) => p.id === planId);
    if (!plan) {
      return error('Invalid plan', 400);
    }
    
    if (seats > plan.maxUsers) {
      return error(`Maximum ${plan.maxUsers} seats allowed for this plan`, 400);
    }
    
    const now = new Date().toISOString();
    const subscriptionId = randomUUID();
    
    // P0 FIX: Add version for optimistic locking
    const subscription = {
      tenantId,
      SK: 'SUB',
      subscriptionId,
      plan: planId,
      status: 'active',
      startDate: now,
      seats,
      pricePerSeat: plan.price,
      currency: plan.currency,
      billingCycle,
      version: 1,
      createdAt: now,
      updatedAt: now,
    };
    
    await putItem(process.env.DYNAMODB_TABLE_BILLING, subscription);
    
    // Update tenant plan
    await updateItem(
      process.env.DYNAMODB_TABLE_TENANTS,
      { tenantId },
      { plan: planId, updatedAt: now }
    );
    
    await logAuditEvent(
      tenantId,
      user.userId,
      'SUBSCRIBE_PLAN',
      'billing',
      subscriptionId,
      { planId, seats, billingCycle },
      event.requestContext?.http?.sourceIp,
      event.requestContext?.http?.userAgent
    );
    
    return success(subscription, 201);
    
  } catch (err) {
    console.error('Subscribe error:', err);
    
    if (err.message?.includes('FORBIDDEN')) {
      return error('Access denied', 403);
    }
    if (err.message?.includes('VALIDATION')) {
      return error(err.message, 400);
    }
    if (err.message?.includes('TENANT_ISOLATION')) {
      return error('Access denied', 403);
    }
    
    return error('Failed to subscribe', 500);
  }
}

// GET /billing/invoices - With pagination (P0 FIX)
export async function listInvoices(event) {
  try {
    // Validate auth
    const user = await requireBillingAdmin(event);
    const tenantId = user.tenantId;
    
    // P0 FIX: Get pagination parameters
    const { limit, cursor, sortBy, sortOrder } = getPaginationParams(event);
    
    // P0 FIX: Use QueryCommand with pagination
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');
    
    const command = new QueryCommand({
      TableName: process.env.DYNAMODB_TABLE_BILLING,
      KeyConditionExpression: 'tenantId = :tenantId AND begins_with(SK, :inv)',
      ExpressionAttributeValues: {
        ':tenantId': tenantId,
        ':inv': 'INV#',
      },
      Limit: limit,
      ExclusiveStartKey: cursor,
      ScanIndexForward: sortOrder === 'asc',
    });
    
    const result = await docClient.send(command);
    
    // P0 FIX: Create paginated response
    const response = createPaginationResponse(
      result.Items || [],
      limit,
      result.LastEvaluatedKey
    );
    
    return success(response);
    
  } catch (err) {
    console.error('List invoices error:', err);
    
    if (err.message?.includes('FORBIDDEN')) {
      return error('Access denied', 403);
    }
    
    return error('Failed to list invoices', 500);
  }
}

// GET /billing/invoices/{id} - With tenant isolation
export async function getInvoice(event) {
  try {
    // Extract user context (any authenticated user can view invoices)
    const user = await verifyToken(
      (event.headers?.authorization || event.headers?.Authorization || '').substring(7)
    );
    
    const tenantId = user.tenantId;
    const invoiceId = event.pathParameters?.id;
    
    if (!invoiceId) {
      return error('Invoice ID required', 400);
    }
    
    const invoice = await getItem(process.env.DYNAMODB_TABLE_BILLING, {
      tenantId,
      SK: `INV#${invoiceId}`,
    });
    
    if (!invoice) {
      return error('Invoice not found', 404);
    }
    
    // Schema drift protection
    const mapped = {
      ...invoice,
      status: invoice.status || 'unknown',
      currency: invoice.currency || 'INR',
      amount: invoice.amount ?? 0,
    };
    
    return success(mapped);
    
  } catch (err) {
    console.error('Get invoice error:', err);
    
    if (err.message?.includes('INVALID_TOKEN')) {
      return error('Unauthorized', 401);
    }
    
    return error('Failed to get invoice', 500);
  }
}

// POST /billing/cancel - With conditional write (P0 FIX)
export async function cancelSubscription(event) {
  try {
    // Validate auth
    const user = await requireBillingAdmin(event);
    const tenantId = user.tenantId;
    
    // Validate input
    const body = JSON.parse(event.body || '{}');
    const validation = validate(CancelSubscriptionSchema, body);
    
    if (!validation.success) {
      return error({
        code: 'VALIDATION_ERROR',
        message: 'Invalid cancellation data',
        details: validation.errors,
      }, 400);
    }
    
    const { reason, feedback, immediate } = validation.data;
    
    // Get current subscription with version check
    const raw = await getItem(process.env.DYNAMODB_TABLE_BILLING, {
      tenantId,
      SK: 'SUB',
    });
    
    if (!raw || raw.status !== 'active') {
      return error('No active subscription found', 404);
    }
    
    const cancelAt = new Date().toISOString();
    
    // P0 FIX: Use conditional update with optimistic locking
    const updates = {
      status: 'cancelled',
      cancelAt,
      cancelReason: reason,
      cancelFeedback: feedback,
      updatedAt: cancelAt,
      expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60), // TTL: cleanup 90 days after cancel
    };
    
    // Add version increment
    const updatesWithVersion = withVersionIncrement(updates, raw.version);
    
    try {
      const updateParams = createConditionalUpdate({
        tableName: process.env.DYNAMODB_TABLE_BILLING,
        key: { tenantId, SK: 'SUB' },
        updates: updatesWithVersion,
        expectedVersion: raw.version, // P0 FIX: Optimistic locking
        tenantId,
      });
      
      const result = await docClient.send(new UpdateCommand(updateParams));
      
      await logAuditEvent(
        tenantId,
        user.userId,
        'CANCEL_SUBSCRIPTION',
        'billing',
        raw.subscriptionId,
        { reason, immediate },
        event.requestContext?.http?.sourceIp,
        event.requestContext?.http?.userAgent
      );
      
      return success(result.Attributes);
      
    } catch (updateErr) {
      if (updateErr.name === 'ConditionalCheckFailedException') {
        return error({
          code: 'CONCURRENT_MODIFICATION',
          message: 'Subscription was modified by another request. Please retry.',
        }, 409);
      }
      throw updateErr;
    }
    
  } catch (err) {
    console.error('Cancel subscription error:', err);
    
    if (err.message?.includes('FORBIDDEN')) {
      return error('Access denied', 403);
    }
    
    return error('Failed to cancel subscription', 500);
  }
}

// ============================================================================
// MAIN HANDLER WITH ROUTING
// ============================================================================

export async function handler(event, context) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;
  
  // Add request ID for tracing
  const requestId = context.awsRequestId || randomUUID();
  console.log(`[${requestId}] ${route}`);
  
  try {
    switch (route) {
      case 'GET /billing/plans':
        return await listPlans(event);
        
      case 'POST /billing/subscribe':
        return await subscribe(event);
        
      case 'GET /billing/invoices':
        return await listInvoices(event);
        
      case 'GET /billing/invoices/{id}':
      case `GET /billing/invoices/${event.pathParameters?.id || ''}`:
        return await getInvoice(event);
        
      case 'POST /billing/cancel':
        return await cancelSubscription(event);
        
      default:
        return error({
          code: 'NOT_FOUND',
          message: `Unsupported billing route: ${route}`,
        }, 404, requestId);
    }
  } catch (err) {
    console.error(`[${requestId}] Unhandled error:`, err);
    return error({
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      requestId,
    }, 500, requestId);
  }
}

// Export for testing
export { PLANS };
