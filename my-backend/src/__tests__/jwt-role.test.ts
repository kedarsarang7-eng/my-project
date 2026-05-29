import { UserRole } from '../types/tenant.types';
import { normalizeJwtRole } from '../utils/jwt-role';

describe('normalizeJwtRole', () => {
    it('maps pump aliases to PUMPBOY', () => {
        expect(normalizeJwtRole('pump_boy')).toBe(UserRole.PUMPBOY);
        expect(normalizeJwtRole('pump-boy')).toBe(UserRole.PUMPBOY);
        expect(normalizeJwtRole('PUMPBOY')).toBe(UserRole.PUMPBOY);
        expect(normalizeJwtRole('fuel_attendant')).toBe(UserRole.PUMPBOY);
    });

    it('accepts canonical enum strings', () => {
        expect(normalizeJwtRole('owner')).toBe(UserRole.OWNER);
        expect(normalizeJwtRole('cashier')).toBe(UserRole.CASHIER);
        expect(normalizeJwtRole('super_admin')).toBe(UserRole.SUPER_ADMIN);
    });

    it('defaults unknown or empty to STAFF', () => {
        expect(normalizeJwtRole('')).toBe(UserRole.STAFF);
        expect(normalizeJwtRole(undefined)).toBe(UserRole.STAFF);
        expect(normalizeJwtRole('not_a_real_role_xyz')).toBe(UserRole.STAFF);
    });
});
