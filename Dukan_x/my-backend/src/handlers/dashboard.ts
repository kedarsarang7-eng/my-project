// ============================================================================
// Lambda Handler — Dashboard (Business-Type Aware)
// ============================================================================
// The "Multi-Business Switch" — routes to the correct strategy based on
// the tenant's business_type extracted from the Cognito JWT.
// Uses `authorizedHandler` for consistent security enforcement.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { DashboardService } from '../services/dashboard.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const dashboardService = new DashboardService();

/**
 * GET /dashboard
 *
 * Returns business-type-specific dashboard data:
 * - PETROL_PUMP → Fuel tanks, nozzle sales, shift summaries, lube stock
 * - PHARMACY   → Near-expiry medicines, batch stock, drug compliance
 * - GROCERY    → Low stock alerts, top sellers, daily revenue
 * - RESTAURANT → Active orders, table status, kitchen queue
 * - etc.
 */
export const getDashboard = authorizedHandler([], async (_event, _context, auth) => {
    logger.info('Dashboard request', {
        tenantId: auth.tenantId,
        businessType: auth.businessType,
    });

    const dashboardData = await dashboardService.getDashboard(
        auth.tenantId,
        auth.businessType,
    );

    return response.success(dashboardData);
});
