// ============================================================================
// Tenant Onboarding Service
// ============================================================================
// Handles creating new tenants in the shared database.
// ============================================================================

import { getPool } from '../config/db.config';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

export interface Tenant {
    id: string;
    name: string;
    email?: string;
    status: string;
    created_at: Date;
}

export interface OnboardTenantRequest {
    name: string;
    email?: string;
    businessType?: string; // e.g., 'retail', 'pharmacy'
}

/**
 * Onboards a new tenant.
 * 
 * 1. Generates a new UUID.
 * 2. Inserts the tenant record into the `tenants` table.
 * 3. Returns the new tenant details.
 * 
 * Note: This function runs as 'admin' (no specific tenant context needed to INSERT into tenants table),
 * assuming the db user has permissions.
 */
export async function onboardTenant(request: OnboardTenantRequest): Promise<Tenant> {
    const db = getPool();
    const tenantId = uuidv4();

    logger.info('Onboarding new tenant', { name: request.name, id: tenantId });

    const query = `
        INSERT INTO tenants (id, name, email, status)
        VALUES ($1, $2, $3, 'active')
        RETURNING id, name, email, status, created_at
    `;

    try {
        const result = await db.query(query, [
            tenantId,
            request.name,
            request.email || null
        ]);

        const newTenant = result.rows[0];
        logger.info('Tenant onboarded successfully', { tenantId: newTenant.id });

        return newTenant;

    } catch (error) {
        if (error instanceof Error) {
            logger.error('Failed to onboard tenant', { message: error.message, stack: error.stack });
        } else {
            logger.error('Failed to onboard tenant', { error });
        }
        throw new Error('Tenant onboarding failed');
    }
}
