// ============================================================================
// V1 Petrol Pump Lambda Handler — Ported from sls/app-backend
// ============================================================================
// Serves: /api/v1/petrol/* — shifts, fuel types, tanks, nozzles, DSR
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, AuthContext, BusinessType } from '../types/tenant.types';
import { buildTenantContext } from '../dynamodb/tenant-guard';
import {
  openShift,
  closeShift,
  getShift,
  listShifts,
  updateFuelRate,
  listFuelTypes,
  listTanks,
  listNozzles,
  recordFuelReceipt,
  generateDsr,
} from '../dynamodb/petrol-pump-service';
import { logger } from '../utils/logger';
import * as response from '../utils/response';

function extractBusinessId(event: APIGatewayProxyEventV2): string {
  return (
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['x-shop-id'] ||
    ''
  );
}

// ---- SHIFTS ----

export const listShiftsHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const result = await listShifts(tenantContext, {
      startDate: event.queryStringParameters?.startDate,
      endDate: event.queryStringParameters?.endDate,
      limit: event.queryStringParameters?.limit ? parseInt(event.queryStringParameters.limit, 10) : undefined,
    });
    return response.success(result);
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const getShiftHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const shiftId = event.pathParameters?.id;
    if (!shiftId) return response.error(400, 'MISSING_ID', 'Shift ID required');
    const shift = await getShift(tenantContext, shiftId);
    if (!shift) return response.error(404, 'NOT_FOUND', 'Shift not found');
    return response.success({ shift });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const openShiftHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const body = JSON.parse(event.body || '{}');
    if (!body.shiftId || !body.shiftName) {
      return response.error(400, 'VALIDATION', 'shiftId and shiftName required');
    }
    const shift = await openShift(tenantContext, {
      shiftId: body.shiftId,
      shiftName: body.shiftName,
      employeeIds: body.employeeIds || [],
    });
    return response.success({ shift }, 201);
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const closeShiftHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const body = JSON.parse(event.body || '{}');
    await closeShift(tenantContext, body);
    return response.success({ status: 'success', message: 'Shift closed' });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

// ---- FUEL TYPES / PRICING ----

export const listFuelTypesHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const fuelTypes = await listFuelTypes(tenantContext);
    return response.success({ fuelTypes });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const updateFuelRateHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const body = JSON.parse(event.body || '{}');
    const priceChange = await updateFuelRate(tenantContext, body);
    return response.success({ priceChange });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

// ---- TANKS / NOZZLES ----

export const listTanksHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const tanks = await listTanks(tenantContext);
    return response.success({ tanks });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const listNozzlesHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const nozzles = await listNozzles(tenantContext);
    return response.success({ nozzles });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

export const recordFuelReceiptHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const body = JSON.parse(event.body || '{}');
    await recordFuelReceipt(tenantContext, body);
    return response.success({ status: 'success', message: 'Fuel receipt recorded' }, 201);
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);

// ---- DSR ----

export const generateDsrHandler = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER, UserRole.STAFF],
  async (event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext): Promise<APIGatewayProxyResultV2> => {
    const { tenantContext } = await buildTenantContext(auth, extractBusinessId(event));
    const date = event.queryStringParameters?.date;
    if (!date) return response.error(400, 'MISSING_DATE', 'date query param required');
    const dsr = await generateDsr(tenantContext, date);
    return response.success({ dsr });
  },
  { requiredBusinessType: BusinessType.PETROL_PUMP }
);
