// ============================================================================
// Cognito JWT custom:role → UserRole (aliases + safe fallback)
// ============================================================================

import { UserRole } from '../types/tenant.types';
import { logger } from './logger';

/** Non-canonical Cognito strings → canonical UserRole value */
const ROLE_ALIASES: Record<string, UserRole> = {
    ca: UserRole.CHARTERED_ACCOUNTANT,
    chartered_accountant: UserRole.CHARTERED_ACCOUNTANT,
    charteredaccountant: UserRole.CHARTERED_ACCOUNTANT,
    accountant: UserRole.ACCOUNTANT,
    admin_user: UserRole.ADMIN,
    business_owner: UserRole.OWNER,
    pump_boy: UserRole.PUMPBOY,
    'pump-boy': UserRole.PUMPBOY,
    pumpboy: UserRole.PUMPBOY,
    fuel_attendant: UserRole.PUMPBOY,
    fuelattendant: UserRole.PUMPBOY,
    attendant: UserRole.PUMPBOY,
};

/**
 * Map JWT `custom:role` (and similar) to UserRole.
 * Unknown strings → STAFF + warn (avoid silent privilege escalation).
 */
export function normalizeJwtRole(raw: string | undefined | null): UserRole {
    if (raw === undefined || raw === null) {
        return UserRole.STAFF;
    }
    const trimmed = String(raw).trim();
    if (!trimmed) {
        return UserRole.STAFF;
    }

    const compact = trimmed.toLowerCase().replace(/[\s-]+/g, '_');
    const aliased = ROLE_ALIASES[compact];
    if (aliased) {
        return aliased;
    }

    const allowed = new Set<string>(Object.values(UserRole));
    if (allowed.has(trimmed)) {
        return trimmed as UserRole;
    }
    if (allowed.has(compact)) {
        return compact as UserRole;
    }

    logger.warn('JWT custom:role unrecognized — defaulting to staff', { raw: trimmed });
    return UserRole.STAFF;
}
