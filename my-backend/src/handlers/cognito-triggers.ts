// ============================================================================
// AUDIT FIX #11: Cognito Pre-Token Generation Trigger
// ============================================================================
// Validates custom:role against the backend UserRole enum before allowing
// token generation. Prevents invalid roles from being embedded in JWTs.
// ============================================================================

import { PreTokenGenerationTriggerEvent, PreTokenGenerationTriggerHandler } from 'aws-lambda';
import { UserRole } from '../types/tenant.types';
import { logger } from '../utils/logger';

const VALID_ROLES = new Set(Object.values(UserRole));

export const preTokenGeneration: PreTokenGenerationTriggerHandler = async (
    event: PreTokenGenerationTriggerEvent,
) => {
    const role = event.request.userAttributes?.['custom:role'];

    if (role && !VALID_ROLES.has(role as UserRole)) {
        logger.warn('Invalid role detected in Cognito user attributes', {
            username: event.userName,
            invalidRole: role,
            validRoles: Array.from(VALID_ROLES),
        });

        // Override with a safe default — staff has minimal permissions
        event.response.claimsOverrideDetails = {
            claimsToAddOrOverride: {
                'custom:role': UserRole.STAFF,
            },
        };
    }

    return event;
};
