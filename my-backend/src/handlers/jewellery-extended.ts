// ============================================================================
// Lambda Handler — Jewellery Extended Features (COMPLETE IMPLEMENTATION)
// ============================================================================
// Features: Gold Rate Alerts, Making Charges, Repair Jobs, Gold Schemes
// Total: 21 Lambda handlers (28 API endpoints)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, putItem, updateItem, getItem, deleteItem } from '../config/dynamodb.config';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as crypto from 'crypto';
import { z } from 'zod';

const JEWELLERY_OPTS = { 
  requiredBusinessType: BusinessType.JEWELLERY, 
  requiredFeature: FeatureKey.JEWELLERY_PURITY_TRACKING 
};

const generateId = () => crypto.randomUUID();
const nowISO = () => new Date().toISOString();

async function dynamicallyUpdate(pk: string, sk: string, updates: Record<string, any>) {
  const updateExpr = Object.keys(updates).map((k, i) => `#${k} = :v${i}`).join(', ');
  const exprNames: Record<string, string> = {};
  const exprValues: Record<string, unknown> = {};
  
  Object.entries(updates).forEach(([k, v], i) => {
    exprNames[`#${k}`] = k;
    exprValues[`:v${i}`] = v;
  });
  
  return updateItem(pk, sk, {
    updateExpression: `SET ${updateExpr}`,
    expressionAttributeNames: exprNames,
    expressionAttributeValues: exprValues,
  });
}

// ============================================================================
// ZOD SCHEMAS
// ============================================================================

const goldRateAlertSchema = z.object({
  metalType: z.enum(['GOLD_24K', 'GOLD_22K', 'GOLD_18K', 'SILVER', 'PLATINUM']),
  thresholdRatePaisaPerGram: z.number().int().min(0),
  direction: z.enum(['above', 'below', 'both']),
  method: z.enum(['push', 'email', 'sms', 'whatsapp']),
  note: z.string().max(500).optional(),
  isRecurring: z.boolean().default(false),
  recurrenceHours: z.number().int().min(1).optional(),
  expiryDate: z.string().datetime().optional(),
});

const makingChargesConfigSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  type: z.enum(['perGram', 'percentage', 'fixed', 'tiered', 'complexity', 'combination']),
  ratePaisaPerGram: z.number().int().min(0).optional(),
  percentageOfMetalValue: z.number().min(0).max(100).optional(),
  fixedAmountPaisa: z.number().int().min(0).optional(),
  minimumChargePaisa: z.number().int().min(0).optional(),
  maximumChargePaisa: z.number().int().min(0).optional(),
  applyOnWastage: z.boolean().default(false),
  includeStoneWeight: z.boolean().default(false),
  isActive: z.boolean().default(true),
});

const createRepairSchema = z.object({
  customerId: z.string().uuid(),
  customerName: z.string().min(1).max(200),
  customerPhone: z.string().max(20).optional(),
  itemDescription: z.string().min(1).max(1000),
  itemCategory: z.string().max(100).optional(),
  metalType: z.string().optional(),
  weightGrams: z.number().min(0).optional(),
  productId: z.string().uuid().optional(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).default('normal'),
  promisedDate: z.string().datetime().optional(),
  estimatedDays: z.number().int().min(1).optional(),
  estimatedCostPaisa: z.number().int().min(0).optional(),
});

const updateRepairSchema = z.object({
  status: z.enum(['pending', 'assessed', 'approved', 'inProgress', 'qualityCheck', 'ready', 'delivered', 'cancelled', 'returned']).optional(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).optional(),
  assignedTo: z.string().optional(),
  assignedToName: z.string().optional(),
  actualCostPaisa: z.number().int().min(0).optional(),
  materialCostPaisa: z.number().int().min(0).optional(),
  laborCostPaisa: z.number().int().min(0).optional(),
});

const createGoldSchemeSchema = z.object({
  customerId: z.string().uuid(),
  customerName: z.string().min(1).max(200),
  customerPhone: z.string().max(20).optional(),
  schemeName: z.string().min(1).max(200).optional(),
  installmentAmountPaisa: z.number().int().min(1000),
  totalInstallments: z.number().int().min(3).max(60),
  frequency: z.enum(['monthly', 'weekly', 'daily']).default('monthly'),
  vendorBonusPaisa: z.number().int().min(0).optional(),
  bonusPercentage: z.number().min(0).max(100).optional(),
  isGoldLinked: z.boolean().default(false),
});

const recordPaymentSchema = z.object({
  installmentNumber: z.number().int().min(1),
  paidAmountPaisa: z.number().int().min(0),
  paymentMode: z.string().optional(),
});

const redeemSchemeSchema = z.object({
  redemptionType: z.enum(['goldJewellery', 'goldCoin', 'cashPayout', 'bankTransfer']),
  finalAmountPaisa: z.number().int().min(0).optional(),
});

// ============================================================================
// GOLD RATE ALERTS (4 handlers)
// ============================================================================

export const createGoldRateAlert = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const valid = parseBody(goldRateAlertSchema, event);
  if (!valid.success) return valid.error;

  const id = generateId();
  const timestamp = nowISO();

  const item = {
    PK: Keys.tenantPK(auth.tenantId),
    SK: Keys.goldRateAlertSK(id),
    GSI1PK: `USER#${auth.sub}#ALERTS`,
    GSI1SK: `CREATED#${timestamp}`,
    entityType: 'GOLD_RATE_ALERT',
    id,
    tenantId: auth.tenantId,
    userId: auth.sub,
    ...valid.data,
    status: 'active',
    triggerCount: 0,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await putItem(item);
  logger.info('Gold rate alert created', { alertId: id });

  return response.success({ id, message: 'Alert created successfully' }, 201);
}, JEWELLERY_OPTS);

export const listGoldRateAlerts = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.VIEWER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const result = await queryItems(Keys.tenantPK(auth.tenantId), 'ALERT#');
  return response.success({ data: result.items });
}, JEWELLERY_OPTS);

export const updateGoldRateAlert = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Alert ID required');

  const valid = parseBody(goldRateAlertSchema.partial(), event);
  if (!valid.success) return valid.error;

  const timestamp = nowISO();
  const updateExpr = Object.keys(valid.data).map((k, i) => `#${k} = :v${i}`).join(', ');
  const exprNames: Record<string, string> = {};
  const exprValues: Record<string, unknown> = {};
  
  Object.entries(valid.data).forEach(([k, v], i) => {
    exprNames[`#${k}`] = k;
    exprValues[`:v${i}`] = v;
  });
  exprNames['#updatedAt'] = 'updatedAt';
  exprValues[':updatedAt'] = timestamp;
  
  await updateItem(Keys.tenantPK(auth.tenantId), Keys.goldRateAlertSK(id), {
    updateExpression: `SET ${updateExpr}, #updatedAt = :updatedAt`,
    expressionAttributeNames: exprNames,
    expressionAttributeValues: exprValues,
  });

  return response.success({ message: 'Alert updated' });
}, JEWELLERY_OPTS);

export const deleteGoldRateAlert = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Alert ID required');

  await deleteItem(Keys.tenantPK(auth.tenantId), Keys.goldRateAlertSK(id));
  return response.success({ message: 'Alert deleted' });
}, JEWELLERY_OPTS);

// ============================================================================
// MAKING CHARGES CONFIGS (4 handlers)
// ============================================================================

export const createMakingChargesConfig = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const valid = parseBody(makingChargesConfigSchema, event);
  if (!valid.success) return valid.error;

  const id = generateId();
  const timestamp = nowISO();

  const item = {
    PK: Keys.tenantPK(auth.tenantId),
    SK: Keys.makingChargesConfigSK(id),
    GSI1PK: `TENANT#${auth.tenantId}#MAKING_CONFIGS`,
    GSI1SK: `NAME#${valid.data.name}`,
    entityType: 'MAKING_CHARGES_CONFIG',
    id,
    tenantId: auth.tenantId,
    createdBy: auth.sub,
    ...valid.data,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await putItem(item);
  return response.success({ id, message: 'Configuration created' }, 201);
}, JEWELLERY_OPTS);

export const listMakingChargesConfigs = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const result = await queryItems(Keys.tenantPK(auth.tenantId), 'MAKING_CONFIG#');
  return response.success({ data: result.items });
}, JEWELLERY_OPTS);

export const updateMakingChargesConfig = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Config ID required');

  const valid = parseBody(makingChargesConfigSchema.partial(), event);
  if (!valid.success) return valid.error;

  const timestamp = nowISO();
  const updateExpr = Object.keys(valid.data).map((k, i) => `#${k} = :v${i}`).join(', ');
  const exprNames: Record<string, string> = {};
  const exprValues: Record<string, unknown> = {};
  
  Object.entries(valid.data).forEach(([k, v], i) => {
    exprNames[`#${k}`] = k;
    exprValues[`:v${i}`] = v;
  });
  exprNames['#updatedAt'] = 'updatedAt';
  exprValues[':updatedAt'] = timestamp;
  
  await updateItem(Keys.tenantPK(auth.tenantId), Keys.makingChargesConfigSK(id), {
    updateExpression: `SET ${updateExpr}, #updatedAt = :updatedAt`,
    expressionAttributeNames: exprNames,
    expressionAttributeValues: exprValues,
  });

  return response.success({ message: 'Configuration updated' });
}, JEWELLERY_OPTS);

export const deleteMakingChargesConfig = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Config ID required');

  await deleteItem(Keys.tenantPK(auth.tenantId), Keys.makingChargesConfigSK(id));
  return response.success({ message: 'Configuration deleted' });
}, JEWELLERY_OPTS);

// ============================================================================
// REPAIR JOBS (7 handlers)
// ============================================================================

export const createRepairJob = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const valid = parseBody(createRepairSchema, event);
  if (!valid.success) return valid.error;

  const id = generateId();
  const timestamp = nowISO();
  const year = new Date().getFullYear();
  const jobNumber = `JOB-${year}-${Math.floor(Math.random() * 10000).toString().padStart(4, '0')}`;

  const item = {
    PK: Keys.tenantPK(auth.tenantId),
    SK: Keys.repairJobSK(id),
    GSI1PK: `TENANT#${auth.tenantId}#REPAIRS`,
    GSI1SK: `STATUS#pending#${timestamp}`,
    GSI2PK: `CUSTOMER#${valid.data.customerId}`,
    GSI2SK: `REPAIR#${timestamp}`,
    entityType: 'JEWELLERY_REPAIR',
    id,
    tenantId: auth.tenantId,
    jobNumber,
    createdBy: auth.sub,
    updatedBy: auth.sub,
    status: 'pending',
    receivedDate: timestamp,
    ...valid.data,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await putItem(item);
  return response.success({ id, jobNumber, message: 'Repair job created' }, 201);
}, JEWELLERY_OPTS);

export const listRepairJobs = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const customerId = event.queryStringParameters?.customerId;
  
  const result = await queryItems(Keys.tenantPK(auth.tenantId), 'REPAIR#');
  let items = result.items;
  if (customerId) {
    items = items.filter((i: any) => i.customerId === customerId);
  }
  return response.success({ data: items });
}, JEWELLERY_OPTS);

export const getRepairJob = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Job ID required');

  const item = await getItem(Keys.tenantPK(auth.tenantId), Keys.repairJobSK(id));
  if (!item) return response.error(404, 'NOT_FOUND', 'Repair job not found');

  return response.success({ data: item });
}, JEWELLERY_OPTS);

export const updateRepairJob = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Job ID required');

  const valid = parseBody(updateRepairSchema, event);
  if (!valid.success) return valid.error;

  const timestamp = nowISO();
  const updates: any = { ...valid.data, updatedAt: timestamp, updatedBy: auth.sub };

  if (valid.data.status) {
    updates.GSI1SK = `STATUS#${valid.data.status}#${timestamp}`;
  }
  
  const updateExpr = Object.keys(updates).map((k, i) => `#${k} = :v${i}`).join(', ');
  const exprNames: Record<string, string> = {};
  const exprValues: Record<string, unknown> = {};
  
  Object.entries(updates).forEach(([k, v], i) => {
    exprNames[`#${k}`] = k;
    exprValues[`:v${i}`] = v;
  });
  
  await updateItem(Keys.tenantPK(auth.tenantId), Keys.repairJobSK(id), {
    updateExpression: `SET ${updateExpr}`,
    expressionAttributeNames: exprNames,
    expressionAttributeValues: exprValues,
  });
  return response.success({ message: 'Repair job updated' });
}, JEWELLERY_OPTS);

export const deleteRepairJob = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Job ID required');

  await updateItem(Keys.tenantPK(auth.tenantId), Keys.repairJobSK(id), {
    updateExpression: 'SET #status = :status, #updatedAt = :updatedAt, #updatedBy = :updatedBy',
    expressionAttributeNames: {
      '#status': 'status',
      '#updatedAt': 'updatedAt',
      '#updatedBy': 'updatedBy',
    },
    expressionAttributeValues: {
      ':status': 'cancelled',
      ':updatedAt': nowISO(),
      ':updatedBy': auth.sub,
    },
  });

  return response.success({ message: 'Repair job cancelled' });
}, JEWELLERY_OPTS);

export const updateRepairStatus = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Job ID required');

  const schema = z.object({ 
    status: z.enum(['pending', 'assessed', 'approved', 'inProgress', 'qualityCheck', 'ready', 'delivered', 'cancelled', 'returned']), 
    notes: z.string().optional() 
  });
  const valid = parseBody(schema, event);
  if (!valid.success) return valid.error;

  const { status, notes } = valid.data;
  const timestamp = nowISO();

  const updates: any = {
    status,
    updatedAt: timestamp,
    updatedBy: auth.sub,
    GSI1SK: `STATUS#${status}#${timestamp}`,
  };

  if (status === 'inProgress') {
    updates.workStartedDate = timestamp;
  }
  if (status === 'ready') {
    updates.workCompletedDate = timestamp;
    updates.completedDate = timestamp;
  }
  if (status === 'delivered') {
    updates.deliveredDate = timestamp;
  }

  await dynamicallyUpdate(Keys.tenantPK(auth.tenantId), Keys.repairJobSK(id), updates);
  return response.success({ message: `Status updated to ${status}` });
}, JEWELLERY_OPTS);

export const getRepairStatistics = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const result = await queryItems(Keys.tenantPK(auth.tenantId), 'REPAIR#');
  const items = result.items;

  const stats = {
    totalJobs: items.length,
    pendingJobs: items.filter((r: any) => r.status === 'pending').length,
    inProgressJobs: items.filter((r: any) => r.status === 'inProgress').length,
    completedJobs: items.filter((r: any) => r.status === 'ready').length,
    deliveredJobs: items.filter((r: any) => r.status === 'delivered').length,
    overdueJobs: items.filter((r: any) => r.promisedDate && new Date(r.promisedDate) < new Date() && r.status !== 'delivered' && r.status !== 'cancelled').length,
    totalRevenuePaisa: items.reduce((sum: number, r: any) => sum + (r.actualCostPaisa || 0), 0),
    totalMaterialCostPaisa: items.reduce((sum: number, r: any) => sum + (r.materialCostPaisa || 0), 0),
    totalLaborCostPaisa: items.reduce((sum: number, r: any) => sum + (r.laborCostPaisa || 0), 0),
  };

  return response.success({ data: stats });
}, JEWELLERY_OPTS);

// ============================================================================
// GOLD SCHEMES (6 handlers)
// ============================================================================

export const createGoldScheme = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const valid = parseBody(createGoldSchemeSchema, event);
  if (!valid.success) return valid.error;

  const id = generateId();
  const timestamp = nowISO();
  const year = new Date().getFullYear();
  const schemeNumber = `GS-${year}-${Math.floor(Math.random() * 10000).toString().padStart(4, '0')}`;

  // Generate payment schedule
  const payments = [];
  const startDate = new Date();
  const intervalDays = valid.data.frequency === 'monthly' ? 30 : valid.data.frequency === 'weekly' ? 7 : 1;
  
  for (let i = 1; i <= valid.data.totalInstallments; i++) {
    const dueDate = new Date(startDate);
    dueDate.setDate(dueDate.getDate() + (i - 1) * intervalDays);
    
    payments.push({
      id: generateId(),
      installmentNumber: i,
      amountPaisa: valid.data.installmentAmountPaisa,
      dueDate: dueDate.toISOString(),
      isPaid: false,
      isLate: false,
    });
  }

  const item = {
    PK: Keys.tenantPK(auth.tenantId),
    SK: Keys.goldSchemeSK(id),
    GSI1PK: `TENANT#${auth.tenantId}#GOLD_SCHEMES`,
    GSI1SK: `STATUS#active#${timestamp}`,
    GSI2PK: `CUSTOMER#${valid.data.customerId}`,
    GSI2SK: `SCHEME#${timestamp}`,
    entityType: 'GOLD_SCHEME',
    id,
    tenantId: auth.tenantId,
    schemeNumber,
    createdBy: auth.sub,
    updatedBy: auth.sub,
    status: 'active',
    payments,
    completedInstallments: 0,
    missedInstallments: 0,
    lateInstallments: 0,
    totalPaidPaisa: 0,
    totalLateFeesPaisa: 0,
    ...valid.data,
    startDate: startDate.toISOString(),
    promisedRedemptionDate: payments[payments.length - 1].dueDate,
    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await putItem(item);
  return response.success({ id, schemeNumber, message: 'Gold scheme created' }, 201);
}, JEWELLERY_OPTS);

export const listGoldSchemes = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const customerId = event.queryStringParameters?.customerId;
  
  const result = await queryItems(Keys.tenantPK(auth.tenantId), 'GOLD_SCHEME#');
  let items = result.items;
  if (customerId) {
    items = items.filter((i: any) => i.customerId === customerId);
  }
  return response.success({ data: items });
}, JEWELLERY_OPTS);

export const getGoldScheme = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Scheme ID required');

  const item = await getItem(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id));
  if (!item) return response.error(404, 'NOT_FOUND', 'Gold scheme not found');

  return response.success({ data: item });
}, JEWELLERY_OPTS);

export const updateGoldScheme = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Scheme ID required');

  const schema = z.object({ 
    status: z.enum(['active', 'paused', 'completed', 'redeemed', 'defaulted', 'cancelled']).optional(),
    plannedRedemptionType: z.enum(['goldJewellery', 'goldCoin', 'cashPayout', 'bankTransfer']).optional(),
  });
  const valid = parseBody(schema, event);
  if (!valid.success) return valid.error;

  const updates: any = { ...valid.data, updatedAt: nowISO(), updatedBy: auth.sub };
  if (valid.data.status) {
    updates.GSI1SK = `STATUS#${valid.data.status}#${new Date().toISOString()}`;
  }

  await dynamicallyUpdate(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id), updates);
  return response.success({ message: 'Gold scheme updated' });
}, JEWELLERY_OPTS);

export const recordSchemePayment = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Scheme ID required');

  const valid = parseBody(recordPaymentSchema, event);
  if (!valid.success) return valid.error;

  const existing = await getItem<any>(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id));
  if (!existing) return response.error(404, 'NOT_FOUND', 'Scheme not found');

  const { installmentNumber, paidAmountPaisa, paymentMode } = valid.data;
  const timestamp = nowISO();
  const now = new Date();

  // Find and update payment
  const payments = [...existing.payments];
  const paymentIndex = payments.findIndex((p: any) => p.installmentNumber === installmentNumber);
  
  if (paymentIndex === -1) {
    return response.error(400, 'BAD_REQUEST', 'Installment not found');
  }

  const payment = payments[paymentIndex];
  const isLate = now > new Date(payment.dueDate);

  payments[paymentIndex] = {
    ...payment,
    isPaid: true,
    paidDate: timestamp,
    paidAmountPaisa,
    isLate,
    paymentMode,
    receivedBy: auth.sub,
  };

  // Recalculate totals
  const completedInstallments = payments.filter((p: any) => p.isPaid).length;
  const totalPaid = payments.reduce((sum: number, p: any) => sum + (p.paidAmountPaisa || 0), 0);

  let newStatus = existing.status;
  if (completedInstallments === existing.totalInstallments) {
    newStatus = 'completed';
  }

  await dynamicallyUpdate(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id), {
    payments,
    status: newStatus,
    GSI1SK: `STATUS#${newStatus}#${existing.createdAt}`,
    completedInstallments,
    totalPaidPaisa: totalPaid,
    updatedAt: timestamp,
    updatedBy: auth.sub,
  });

  return response.success({ message: 'Payment recorded' });
}, JEWELLERY_OPTS);

export const redeemGoldScheme = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF], async (
  event: APIGatewayProxyEventV2, context: Context, auth: AuthContext
) => {
  const id = event.pathParameters?.id;
  if (!id) return response.error(400, 'BAD_REQUEST', 'Scheme ID required');

  const valid = parseBody(redeemSchemeSchema, event);
  if (!valid.success) return valid.error;

  const existing = await getItem<any>(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id));
  if (!existing) return response.error(404, 'NOT_FOUND', 'Scheme not found');

  if (existing.status === 'redeemed') {
    return response.error(400, 'BAD_REQUEST', 'Scheme already redeemed');
  }

  if (existing.completedInstallments < existing.totalInstallments) {
    return response.error(400, 'BAD_REQUEST', 'Scheme is not fully paid');
  }

  const timestamp = nowISO();
  const { redemptionType, finalAmountPaisa } = valid.data;

  // Calculate bonus
  let bonusAmount = existing.vendorBonusPaisa || 0;
  if (existing.bonusPercentage) {
    bonusAmount = Math.round(existing.totalPaidPaisa * (existing.bonusPercentage / 100));
  }

  const finalAmount = finalAmountPaisa || (existing.totalPaidPaisa + bonusAmount);

  const redemption = {
    id: generateId(),
    type: redemptionType,
    redemptionDate: timestamp,
    totalAmountPaisa: existing.totalPaidPaisa,
    bonusAmountPaisa: bonusAmount > 0 ? bonusAmount : undefined,
    finalAmountPaisa: finalAmount,
    processedBy: auth.sub,
  };

  await dynamicallyUpdate(Keys.tenantPK(auth.tenantId), Keys.goldSchemeSK(id), {
    status: 'redeemed',
    GSI1SK: `STATUS#redeemed#${existing.createdAt}`,
    redemption,
    endDate: timestamp,
    updatedAt: timestamp,
    updatedBy: auth.sub,
  });

  return response.success({ redemptionId: redemption.id, message: 'Scheme redeemed' });
}, JEWELLERY_OPTS);
