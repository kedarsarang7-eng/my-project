// ============================================================================
// Dashboard V2 — Pixel-Perfect Dashboard API (7 Endpoints)
// ============================================================================
// All endpoints are tenant-isolated and business-type-aware.
// Data is aggregated server-side — never sends raw records.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import * as response from '../utils/response';
import { DashboardV2Service } from '../services/dashboard-v2.service';
import { UserRole, BusinessType, normalizeBusinessType } from '../types/tenant.types';

const service = new DashboardV2Service();

const dashboardRoles = [
    UserRole.OWNER,
    UserRole.ADMIN,
    UserRole.MANAGER,
    UserRole.ACCOUNTANT,
    UserRole.CASHIER,
    UserRole.STAFF,
];

function extractBusinessType(event: any, auth: any): BusinessType {
    const queryBt = event.queryStringParameters?.businessType;
    if (queryBt) return normalizeBusinessType(queryBt);
    return auth.businessType || BusinessType.OTHER;
}

// GET /dashboard/v2/summary?businessType=grocery&period=MTD
export const getDashboardV2Summary = authorizedHandler(dashboardRoles, async (event, _ctx, auth) => {
    const businessType = extractBusinessType(event, auth);
    const period = event.queryStringParameters?.period || 'MTD';
    const data = await service.getDashboardSummary(auth.tenantId, businessType, period);
    return response.success(data);
});

// GET /dashboard/v2/revenue-chart?businessType=grocery&months=6
export const getDashboardV2RevenueChart = authorizedHandler(dashboardRoles, async (event, _ctx, auth) => {
    const businessType = extractBusinessType(event, auth);
    const months = Math.min(Math.max(Number(event.queryStringParameters?.months || '6'), 3), 12);
    const data = await service.getRevenueChart(auth.tenantId, businessType, months);
    return response.success(data);
});

// GET /dashboard/v2/invoice-distribution?businessType=grocery
export const getDashboardV2InvoiceDistribution = authorizedHandler(dashboardRoles, async (event, _ctx, auth) => {
    const businessType = extractBusinessType(event, auth);
    const data = await service.getInvoiceDistribution(auth.tenantId, businessType);
    return response.success(data);
});

// GET /dashboard/v2/recent-invoices?businessType=grocery&range=10days
export const getDashboardV2RecentInvoices = authorizedHandler(dashboardRoles, async (event, _ctx, auth) => {
    const businessType = extractBusinessType(event, auth);
    const range = event.queryStringParameters?.range || '10days';
    const filter = event.queryStringParameters?.filter || 'all'; // today|this_week|date_range
    const data = await service.getRecentInvoices(auth.tenantId, businessType, range, filter);
    return response.success(data);
});

// GET /dashboard/v2/cashflow-forecast?businessType=grocery
export const getDashboardV2CashflowForecast = authorizedHandler(dashboardRoles, async (event, _ctx, auth) => {
    const businessType = extractBusinessType(event, auth);
    const data = await service.getCashflowForecast(auth.tenantId, businessType);
    return response.success(data);
});

// GET /dashboard/v2/notifications-count
export const getDashboardV2NotificationsCount = authorizedHandler(dashboardRoles, async (_event, _ctx, auth) => {
    const data = await service.getNotificationsCount(auth.tenantId);
    return response.success(data);
});

// GET /dashboard/v2/license-validate
export const getDashboardV2LicenseValidate = authorizedHandler([], async (_event, _ctx, auth) => {
    const data = await service.validateLicense(auth.tenantId, auth.sub);
    return response.success(data);
});
