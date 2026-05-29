// ============================================================================
// Tenant Onboarding Service (DynamoDB)
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import { Keys, putItem } from '../config/dynamodb.config';
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
    businessType?: string;
}

export async function onboardTenant(request: OnboardTenantRequest): Promise<Tenant> {
    const tenantId = uuidv4();
    const now = new Date().toISOString();

    logger.info('Onboarding new tenant', { name: request.name, id: tenantId });

    try {
        await putItem({
            PK: Keys.tenantPK(tenantId),
            SK: Keys.tenantProfileSK(),
            entityType: 'TENANT',
            id: tenantId,
            tenantId,
            name: request.name,
            email: request.email || null,
            businessType: request.businessType || 'general',
            subscriptionPlan: 'free',
            isActive: true,
            status: 'active',
            settings: {
                currency: 'INR',
                timezone: 'Asia/Kolkata',
                fiscalYearStart: 4,
            },
            createdAt: now,
            updatedAt: now,
        });

        logger.info('Tenant onboarded successfully', { tenantId });

        return {
            id: tenantId,
            name: request.name,
            email: request.email,
            status: 'active',
            created_at: new Date(now),
        };
    } catch (error) {
        if (error instanceof Error) {
            logger.error('Failed to onboard tenant', { message: error.message, stack: error.stack });
        }
        throw new Error('Tenant onboarding failed');
    }
}
