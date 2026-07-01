// ============================================================================
// Lambda Handler — Admin (Kill Switch & System Status)
// ============================================================================
// Endpoints:
//   POST /admin/kill-switch  — Emergency disable a tenant
//   GET  /admin/status       — System health & tenant stats
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { getPool } from '../config/db.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /admin/kill-switch
 * Emergency disable a tenant (set is_active = false).
 * Only OWNER can kill their own tenant.
 */
export const killSwitch = authorizedHandler(
    [UserRole.OWNER],
    async (event, _context, auth) => {
        const db = getPool();
        const body = JSON.parse(event.body || '{}');
        const { action, reason } = body;

        if (!action || !['disable', 'enable'].includes(action)) {
            return response.badRequest('Missing or invalid action. Must be "disable" or "enable".');
        }

        const isActive = action === 'enable';

        await db.query(
            `UPDATE tenants SET is_active = $1, updated_at = NOW() WHERE id = $2`,
            [isActive, auth.tenantId]
        );

        logger.info('Kill switch activated', {
            tenantId: auth.tenantId,
            action,
            reason,
            triggeredBy: auth.sub,
        });

        return response.success({
            tenantId: auth.tenantId,
            isActive,
            action,
            message: action === 'disable'
                ? 'Tenant has been disabled. All API access is now blocked.'
                : 'Tenant has been re-enabled.',
        });
    }
);

/**
 * GET /admin/status
 * System health check and tenant statistics.
 */
export const systemStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, auth) => {
        const db = getPool();

        // Tenant info
        const tenantResult = await db.query(
            `SELECT id, name, business_type, subscription_plan,
                    subscription_valid_until, is_active, created_at,
                    (SELECT COUNT(*)::int FROM users WHERE tenant_id = $1) AS user_count,
                    (SELECT COUNT(*)::int FROM inventory WHERE tenant_id = $1 AND NOT is_deleted) AS product_count,
                    (SELECT COUNT(*)::int FROM transactions WHERE tenant_id = $1 AND NOT is_deleted) AS transaction_count
             FROM tenants WHERE id = $1`,
            [auth.tenantId]
        );

        if (tenantResult.rows.length === 0) {
            return response.notFound('Tenant');
        }

        const tenant = tenantResult.rows[0];

        // Today's stats
        const todayResult = await db.query(
            `SELECT
                COUNT(*)::int AS bills_today,
                COALESCE(SUM(total_cents), 0)::bigint AS revenue_today_cents
             FROM transactions
             WHERE tenant_id = $1 AND DATE(created_at) = CURRENT_DATE
               AND NOT is_deleted AND status != 'voided'`,
            [auth.tenantId]
        );

        // Storage estimate (approximate row counts)
        const storageResult = await db.query(
            `SELECT
                pg_size_pretty(pg_total_relation_size('transactions')) AS transactions_size,
                pg_size_pretty(pg_total_relation_size('inventory')) AS inventory_size`
        );

        return response.success({
            system: {
                status: 'healthy',
                serverTime: new Date().toISOString(),
                version: '1.0.0',
            },
            tenant: {
                id: tenant.id,
                name: tenant.name,
                businessType: tenant.business_type,
                plan: tenant.subscription_plan,
                subscriptionValidUntil: tenant.subscription_valid_until,
                isActive: tenant.is_active,
                createdAt: tenant.created_at,
            },
            counts: {
                users: tenant.user_count,
                products: tenant.product_count,
                transactions: tenant.transaction_count,
            },
            today: todayResult.rows[0],
            storage: storageResult.rows[0],
        });
    }
);
