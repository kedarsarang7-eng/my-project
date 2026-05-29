import { describe, test, expect } from '@jest/globals';
import { normalizeRole, permissionsForRole } from '../services/auth.service';

describe('auth RBAC mapping', () => {
    test('normalizes legacy Cognito groups to target roles', () => {
        expect(normalizeRole('BusinessOwner')).toBe('Admin');
        expect(normalizeRole('SuperAdmin')).toBe('Admin');
        expect(normalizeRole('CharteredAccountant')).toBe('CA');
        expect(normalizeRole('Viewer')).toBe('Staff');
        expect(normalizeRole('Manager')).toBe('Manager');
    });

    test('returns expected permissions for roles', () => {
        expect(permissionsForRole('Staff')).toEqual([
            'view_invoices',
            'create_invoices',
            'view_clients',
        ]);
        expect(permissionsForRole('CA')).toEqual([
            'view_invoices',
            'create_invoices',
            'view_reports',
            'export_reports',
            'view_clients',
        ]);
        expect(permissionsForRole('Manager')).toEqual([
            'view_invoices',
            'create_invoices',
            'view_reports',
            'export_reports',
            'view_clients',
            'manage_staff',
            'view_analytics',
        ]);
        expect(permissionsForRole('Admin')).toEqual(['ALL_PERMISSIONS']);
    });

    test('unknown role gets no permissions', () => {
        expect(permissionsForRole('UnknownRole')).toEqual([]);
    });
});
