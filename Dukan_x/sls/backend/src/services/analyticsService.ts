// ============================================
// Analytics Service — Dashboard Data Aggregation
// ============================================

import { query, queryOne } from '../config/database';
import { getTotalActiveSessions } from './sessionService';
import { DashboardAnalytics, AccessLog } from '../models/types';
import { logger } from '../utils/logger';

/**
 * Get comprehensive dashboard analytics.
 */
export async function getDashboardAnalytics(): Promise<DashboardAnalytics> {
    // Run all queries in parallel for speed
    const [
        totalLicenses,
        activeLicenses,
        expiredLicenses,
        suspendedLicenses,
        activeSessions,
        expiringKeys,
        validationsToday,
        totalResellers,
        tierDistribution,
        recentActivity,
    ] = await Promise.all([
        // Total licenses (not deleted)
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM licenses WHERE is_deleted = FALSE"
        ),
        // Active licenses
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM licenses WHERE status = 'active' AND is_deleted = FALSE"
        ),
        // Expired licenses
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM licenses WHERE (status = 'expired' OR (expires_at IS NOT NULL AND expires_at < NOW())) AND is_deleted = FALSE"
        ),
        // Suspended licenses
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM licenses WHERE status = 'suspended' AND is_deleted = FALSE"
        ),
        // Active sessions right now
        getTotalActiveSessions(),
        // Keys expiring in next 7 days
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM licenses WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days' AND is_deleted = FALSE"
        ),
        // Validations today
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM access_logs WHERE action = 'validate' AND created_at >= CURRENT_DATE"
        ),
        // Total resellers
        queryOne<{ count: string }>(
            "SELECT COUNT(*) as count FROM resellers WHERE is_active = TRUE"
        ),
        // Tier distribution
        query<{ tier: string; count: string }>(
            "SELECT tier, COUNT(*) as count FROM licenses WHERE is_deleted = FALSE GROUP BY tier ORDER BY count DESC"
        ),
        // Recent activity (last 20 logs)
        query<AccessLog>(
            "SELECT * FROM access_logs ORDER BY created_at DESC LIMIT 20"
        ),
    ]);

    return {
        total_licenses: parseInt(totalLicenses?.count || '0', 10),
        active_licenses: parseInt(activeLicenses?.count || '0', 10),
        expired_licenses: parseInt(expiredLicenses?.count || '0', 10),
        suspended_licenses: parseInt(suspendedLicenses?.count || '0', 10),
        active_sessions_now: activeSessions,
        keys_expiring_7_days: parseInt(expiringKeys?.count || '0', 10),
        validations_today: parseInt(validationsToday?.count || '0', 10),
        total_resellers: parseInt(totalResellers?.count || '0', 10),
        tier_distribution: tierDistribution.map(t => ({
            tier: t.tier,
            count: parseInt(t.count, 10),
        })),
        recent_activity: recentActivity,
    };
}

/**
 * Get access logs with pagination.
 */
export async function getAccessLogs(
    page: number = 1,
    limit: number = 50,
    filters?: { license_id?: string; action?: string; success?: boolean }
): Promise<{ data: AccessLog[]; total: number }> {
    const offset = (page - 1) * limit;
    const conditions: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (filters?.license_id) {
        conditions.push(`license_id = $${paramIndex++}`);
        values.push(filters.license_id);
    }
    if (filters?.action) {
        conditions.push(`action = $${paramIndex++}`);
        values.push(filters.action);
    }
    if (filters?.success !== undefined) {
        conditions.push(`success = $${paramIndex++}`);
        values.push(filters.success);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await queryOne<{ count: string }>(
        `SELECT COUNT(*) as count FROM access_logs ${whereClause}`,
        values
    );

    const data = await query<AccessLog>(
        `SELECT * FROM access_logs ${whereClause} ORDER BY created_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex}`,
        [...values, limit, offset]
    );

    return {
        data,
        total: parseInt(countResult?.count || '0', 10),
    };
}

/**
 * Log an access event (validation attempt, activation, etc.)
 */
export async function logAccess(
    licenseId: string | null,
    action: string,
    success: boolean,
    details: {
        ip_address?: string;
        country_code?: string;
        user_agent?: string;
        hwid_hash?: string;
        failure_reason?: string;
        response_data?: object;
    }
): Promise<void> {
    try {
        await query(
            `INSERT INTO access_logs (
        license_id, action, ip_address, country_code, user_agent,
        hwid_hash, success, failure_reason, response_data
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
            [
                licenseId,
                action,
                details.ip_address || null,
                details.country_code || null,
                details.user_agent || null,
                details.hwid_hash || null,
                success,
                details.failure_reason || null,
                JSON.stringify(details.response_data || {}),
            ]
        );
    } catch (error: any) {
        // Don't let logging failures affect the main flow
        logger.error('Failed to log access event', { error: error.message });
    }
}
