import { randomUUID } from 'crypto';
import { success, error, verifyToken, getItem, putItem, updateItem, queryItems, logAuditEvent } from '../shared/utils.mjs';

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

function requireBillingAdmin(role) {
  const normalized = String(role || '').trim().toLowerCase();
  if (!['admin', 'superadmin', 'manager'].includes(normalized)) {
    throw new Error('FORBIDDEN');
  }
}

// Schema drift protection — normalize DynamoDB items with defaults
function mapSubscriptionFromDynamoDB(item) {
  if (!item) return null;
  return {
    ...item,
    status: item.status || 'unknown',
    seats: item.seats ?? 1,
    pricePerSeat: item.pricePerSeat ?? 0,
    currency: item.currency || 'INR',
    plan: item.plan || 'basic',
    startDate: item.startDate || null,
    createdAt: item.createdAt || null,
    updatedAt: item.updatedAt || null,
  };
}

// GET /billing/plans
export async function listPlans(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    await verifyToken(authHeader.substring(7));

    return success({ plans: PLANS });
  } catch (err) {
    console.error('List plans error:', err);
    return error('Failed to list plans', 500);
  }
}

// POST /billing/subscribe
export async function subscribe(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireBillingAdmin(decoded.role);

    const tenantId = decoded.tenantId;
    const { planId, seats = 1 } = JSON.parse(event.body || '{}');

    if (!planId) {
      return error('Plan ID is required', 400);
    }

    const plan = PLANS.find((p) => p.id === planId);

    if (!plan) {
      return error('Invalid plan', 400);
    }

    if (seats > plan.maxUsers) {
      return error(`Maximum ${plan.maxUsers} seats allowed for this plan`, 400);
    }

    const now = new Date().toISOString();
    const subscriptionId = randomUUID();

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
      decoded.sub,
      'SUBSCRIBE_PLAN',
      'billing',
      subscriptionId,
      { planId, seats },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(subscription, 201);
  } catch (err) {
    console.error('Subscribe error:', err);
    if (err.message === 'FORBIDDEN') return error('Access denied', 403);
    return error('Failed to subscribe', 500);
  }
}

// GET /billing/invoices
export async function listInvoices(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireBillingAdmin(decoded.role);

    const tenantId = decoded.tenantId;

    const invoices = await queryItems(
      process.env.DYNAMODB_TABLE_BILLING,
      'tenantId = :tenantId AND begins_with(SK, :inv)',
      {
        ':tenantId': tenantId,
        ':inv': 'INV#',
      }
    );

    return success({ invoices });
  } catch (err) {
    console.error('List invoices error:', err);
    return error('Failed to list invoices', 500);
  }
}

// GET /billing/invoices/{id}
export async function getInvoice(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    const tenantId = decoded.tenantId;
    const invoiceId = event.pathParameters.id;

    const invoice = await getItem(process.env.DYNAMODB_TABLE_BILLING, {
      tenantId,
      SK: `INV#${invoiceId}`,
    });

    if (!invoice) {
      return error('Invoice not found', 404);
    }

    // Apply defaults for schema drift protection
    const mapped = {
      ...invoice,
      status: invoice.status || 'unknown',
      currency: invoice.currency || 'USD',
      amount: invoice.amount ?? 0,
    };

    return success(mapped);
  } catch (err) {
    console.error('Get invoice error:', err);
    return error('Failed to get invoice', 500);
  }
}

// POST /billing/cancel
export async function cancelSubscription(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    const tenantId = decoded.tenantId;
    const { reason } = JSON.parse(event.body || '{}');

    // Get current subscription
    const raw = await getItem(process.env.DYNAMODB_TABLE_BILLING, {
      tenantId,
      SK: 'SUB',
    });
    const subscription = mapSubscriptionFromDynamoDB(raw);

    if (!subscription || subscription.status !== 'active') {
      return error('No active subscription found', 404);
    }

    const cancelAt = new Date().toISOString();

    const updatedSubscription = await updateItem(
      process.env.DYNAMODB_TABLE_BILLING,
      { tenantId, SK: 'SUB' },
      {
        status: 'cancelled',
        cancelAt,
        cancelReason: reason,
        updatedAt: cancelAt,
        expiresAt: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60), // TTL: cleanup 90 days after cancel
      }
    );

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'CANCEL_SUBSCRIPTION',
      'billing',
      subscription.subscriptionId,
      { reason },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(updatedSubscription);
  } catch (err) {
    console.error('Cancel subscription error:', err);
    if (err.message === 'FORBIDDEN') return error('Access denied', 403);
    return error('Failed to cancel subscription', 500);
  }
}

export async function handler(event) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;

  switch (route) {
    case 'GET /billing/plans':
      return listPlans(event);
    case 'POST /billing/subscribe':
      return subscribe(event);
    case 'GET /billing/invoices':
      return listInvoices(event);
    case 'GET /billing/invoices/{id}':
    case 'GET /billing/invoices/' + (event.pathParameters?.id || ''):
      return getInvoice(event);
    case 'POST /billing/cancel':
      return cancelSubscription(event);
    default:
      return error(`Unsupported billing route: ${route}`, 404);
  }
}