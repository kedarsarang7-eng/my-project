// ============================================================================
// Tenant Context Middleware
// ============================================================================
// After auth verification, this sets the PostgreSQL RLS context so all
// subsequent queries are automatically scoped to the tenant.
// ============================================================================

import { AuthContext } from '../types/tenant.types';
import { setTenantContext } from '../config/db.config';
import { logger } from '../utils/logger';

/**
 * Initialize the database-level tenant context for RLS.
 *
 * Call this AFTER verifyAuth() and BEFORE any database queries.
 * It sets `app.tenant_id` as a PostgreSQL session variable that
 * RLS policies reference via `current_setting('app.tenant_id')`.
 */
export async function initTenantContext(auth: AuthContext): Promise<void> {
    logger.debug('Setting tenant context', {
        tenantId: auth.tenantId,
        businessType: auth.businessType,
    });

    await setTenantContext(auth.tenantId);
}
