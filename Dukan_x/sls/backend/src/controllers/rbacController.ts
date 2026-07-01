// ============================================
// RBAC Controller — Staff & Permission Management
// ============================================
// Endpoints for managing staff members, roles, and granular permissions.
// All endpoints require Cognito auth + tenant context.
// Only Owners can manage staff and permissions.
// ============================================

import { Router, Request, Response } from 'express';
import { query, queryOne } from '../config/database';
import { requireCognitoAuth } from '../middleware/cognitoAuth';
import { requireTenant, withTenant } from '../middleware/tenantMiddleware';
import { checkPermission } from '../middleware/checkPermission';
import { logger } from '../utils/logger';
import crypto from 'crypto';

const router = Router();

// All routes require auth + tenant
router.use(requireCognitoAuth, requireTenant);

// ============================================
// PERMISSIONS CATALOG
// ============================================

/**
 * GET /api/rbac/permissions
 * List all available permissions (master catalog).
 * Any authenticated user can see the catalog.
 */
router.get('/permissions', async (_req: Request, res: Response) => {
    try {
        const permissions = await query(
            `SELECT id, category, display_name, description, sort_order, is_sensitive
             FROM permissions
             ORDER BY category, sort_order`
        );

        // Group by category
        const grouped: Record<string, any[]> = {};
        for (const p of permissions) {
            if (!grouped[p.category]) grouped[p.category] = [];
            grouped[p.category].push(p);
        }

        res.json({ permissions, grouped });
    } catch (error: any) {
        logger.error('Failed to fetch permissions catalog', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch permissions' });
    }
});

// ============================================
// ROLES
// ============================================

/**
 * GET /api/rbac/roles
 * List all roles for the current tenant.
 */
router.get('/roles', async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const roles = await query(
            `SELECT r.id, r.name, r.display_name, r.description, r.is_system, r.is_active,
                    r.created_at, r.updated_at,
                    (SELECT COUNT(*) FROM staff_members sm WHERE sm.role_id = r.id AND sm.is_active = TRUE) AS staff_count
             FROM roles r
             WHERE r.tenant_id = $1
             ORDER BY r.is_system DESC, r.display_name`,
            [tenantId]
        );

        res.json({ roles });
    } catch (error: any) {
        logger.error('Failed to fetch roles', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch roles' });
    }
});

/**
 * GET /api/rbac/roles/:roleId/permissions
 * Get all permissions assigned to a role.
 */
router.get('/roles/:roleId/permissions', async (req: Request, res: Response) => {
    try {
        const { roleId } = req.params;
        const tenantId = req.shopId!;

        const permissions = await query(
            `SELECT rp.permission_id, p.category, p.display_name, p.description, p.is_sensitive
             FROM role_permissions rp
             JOIN permissions p ON p.id = rp.permission_id
             WHERE rp.role_id = $1 AND rp.tenant_id = $2
             ORDER BY p.category, p.sort_order`,
            [roleId, tenantId]
        );

        res.json({ role_id: roleId, permissions });
    } catch (error: any) {
        logger.error('Failed to fetch role permissions', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch role permissions' });
    }
});

/**
 * PUT /api/rbac/roles/:roleId/permissions
 * Update permissions for a role (batch replace).
 * Owner only.
 * Body: { permission_ids: string[] }
 */
router.put('/roles/:roleId/permissions', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const { roleId } = req.params;
        const tenantId = req.shopId!;
        const { permission_ids } = req.body;
        const grantedBy = req.cognitoUser?.sub || (req as any).user?.sub;

        if (!Array.isArray(permission_ids)) {
            res.status(400).json({ error: 'permission_ids must be an array' });
            return;
        }

        // Verify role belongs to this tenant and is not 'owner'
        const role = await queryOne<{ name: string }>(
            `SELECT name FROM roles WHERE id = $1 AND tenant_id = $2`,
            [roleId, tenantId]
        );

        if (!role) {
            res.status(404).json({ error: 'Role not found' });
            return;
        }

        if (role.name === 'owner') {
            res.status(403).json({ error: 'Cannot modify owner role permissions' });
            return;
        }

        // Transaction: delete old, insert new
        await withTenant(tenantId, async (client) => {
            await client.query(
                `DELETE FROM role_permissions WHERE role_id = $1 AND tenant_id = $2`,
                [roleId, tenantId]
            );

            if (permission_ids.length > 0) {
                const values = permission_ids.map(
                    (pid: string, i: number) =>
                        `(gen_random_uuid(), $1, $${i + 3}, $2, NOW(), $${permission_ids.length + 3})`
                ).join(', ');

                await client.query(
                    `INSERT INTO role_permissions (id, role_id, permission_id, tenant_id, granted_at, granted_by)
                     VALUES ${values}`,
                    [roleId, tenantId, ...permission_ids, grantedBy]
                );
            }
        });

        logger.info('Role permissions updated', { roleId, tenantId, count: permission_ids.length });
        res.json({ success: true, role_id: roleId, permission_count: permission_ids.length });
    } catch (error: any) {
        logger.error('Failed to update role permissions', { error: error.message });
        res.status(500).json({ error: 'Failed to update role permissions' });
    }
});

/**
 * POST /api/rbac/roles
 * Create a custom role.
 * Body: { name, display_name, description?, permission_ids? }
 */
router.post('/roles', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const { name, display_name, description, permission_ids } = req.body;

        if (!name || !display_name) {
            res.status(400).json({ error: 'name and display_name are required' });
            return;
        }

        const role = await queryOne<{ id: string }>(
            `INSERT INTO roles (tenant_id, name, display_name, description, is_system)
             VALUES ($1, $2, $3, $4, FALSE)
             RETURNING id`,
            [tenantId, name.toLowerCase(), display_name, description || null]
        );

        // Optionally assign permissions
        if (role && Array.isArray(permission_ids) && permission_ids.length > 0) {
            const grantedBy = req.cognitoUser?.sub || (req as any).user?.sub;
            for (const pid of permission_ids) {
                await query(
                    `INSERT INTO role_permissions (role_id, permission_id, tenant_id, granted_by)
                     VALUES ($1, $2, $3, $4)
                     ON CONFLICT DO NOTHING`,
                    [role.id, pid, tenantId, grantedBy]
                );
            }
        }

        res.status(201).json({ success: true, role });
    } catch (error: any) {
        if (error.constraint?.includes('roles_tenant_id_name_key')) {
            res.status(409).json({ error: 'A role with this name already exists' });
            return;
        }
        logger.error('Failed to create role', { error: error.message });
        res.status(500).json({ error: 'Failed to create role' });
    }
});

// ============================================
// STAFF MEMBERS
// ============================================

/**
 * GET /api/rbac/staff
 * List all staff members for the current tenant.
 */
router.get('/staff', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;

        const staff = await query(
            `SELECT sm.id, sm.cognito_sub, sm.email, sm.phone, sm.name,
                    sm.is_active, sm.invite_status, sm.last_login_at,
                    sm.created_at, sm.updated_at,
                    r.id AS role_id, r.name AS role_name, r.display_name AS role_display_name
             FROM staff_members sm
             JOIN roles r ON r.id = sm.role_id
             WHERE sm.tenant_id = $1
             ORDER BY sm.is_active DESC, sm.name`,
            [tenantId]
        );

        res.json({ staff });
    } catch (error: any) {
        logger.error('Failed to fetch staff', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch staff' });
    }
});

/**
 * POST /api/rbac/staff
 * Invite a new staff member.
 * Body: { name, email?, phone?, role_id }
 */
router.post('/staff', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const createdBy = req.cognitoUser?.sub || (req as any).user?.sub;
        const { name, email, phone, role_id } = req.body;

        if (!name || !role_id) {
            res.status(400).json({ error: 'name and role_id are required' });
            return;
        }

        // Verify role belongs to this tenant
        const role = await queryOne<{ name: string }>(
            `SELECT name FROM roles WHERE id = $1 AND tenant_id = $2`,
            [role_id, tenantId]
        );

        if (!role) {
            res.status(404).json({ error: 'Role not found for this business' });
            return;
        }

        if (role.name === 'owner') {
            res.status(403).json({ error: 'Cannot assign owner role to staff' });
            return;
        }

        // Generate invite code
        const inviteCode = crypto.randomBytes(6).toString('hex').toUpperCase();

        const staff = await queryOne(
            `INSERT INTO staff_members (tenant_id, name, email, phone, role_id, invite_code, invite_status, created_by)
             VALUES ($1, $2, $3, $4, $5, $6, 'pending', $7)
             RETURNING id, name, email, phone, invite_code, invite_status`,
            [tenantId, name, email || null, phone || null, role_id, inviteCode, createdBy]
        );

        logger.info('Staff invited', { tenantId, staffName: name, roleId: role_id });
        res.status(201).json({ success: true, staff });
    } catch (error: any) {
        if (error.constraint) {
            res.status(409).json({ error: 'A staff member with this email or phone already exists' });
            return;
        }
        logger.error('Failed to invite staff', { error: error.message });
        res.status(500).json({ error: 'Failed to invite staff' });
    }
});

/**
 * PUT /api/rbac/staff/:staffId
 * Update a staff member (role, active status, name).
 * Body: { name?, role_id?, is_active? }
 */
router.put('/staff/:staffId', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const { staffId } = req.params;
        const { name, role_id, is_active } = req.body;

        // Build dynamic update
        const updates: string[] = [];
        const params: any[] = [];
        let idx = 1;

        if (name !== undefined) {
            updates.push(`name = $${idx++}`);
            params.push(name);
        }
        if (role_id !== undefined) {
            // Verify role
            const role = await queryOne<{ name: string }>(
                `SELECT name FROM roles WHERE id = $1 AND tenant_id = $2`,
                [role_id, tenantId]
            );
            if (!role) {
                res.status(404).json({ error: 'Role not found' });
                return;
            }
            if (role.name === 'owner') {
                res.status(403).json({ error: 'Cannot assign owner role' });
                return;
            }
            updates.push(`role_id = $${idx++}`);
            params.push(role_id);
        }
        if (is_active !== undefined) {
            updates.push(`is_active = $${idx++}`);
            params.push(is_active);
        }

        if (updates.length === 0) {
            res.status(400).json({ error: 'No fields to update' });
            return;
        }

        updates.push(`updated_at = NOW()`);
        params.push(staffId, tenantId);

        const staff = await queryOne(
            `UPDATE staff_members
             SET ${updates.join(', ')}
             WHERE id = $${idx++} AND tenant_id = $${idx}
             RETURNING id, name, role_id, is_active`,
            params
        );

        if (!staff) {
            res.status(404).json({ error: 'Staff member not found' });
            return;
        }

        res.json({ success: true, staff });
    } catch (error: any) {
        logger.error('Failed to update staff', { error: error.message });
        res.status(500).json({ error: 'Failed to update staff' });
    }
});

/**
 * DELETE /api/rbac/staff/:staffId
 * Remove a staff member (soft-delete by deactivating).
 */
router.delete('/staff/:staffId', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const { staffId } = req.params;

        const result = await queryOne(
            `UPDATE staff_members
             SET is_active = FALSE, invite_status = 'revoked', updated_at = NOW()
             WHERE id = $1 AND tenant_id = $2
             RETURNING id, name`,
            [staffId, tenantId]
        );

        if (!result) {
            res.status(404).json({ error: 'Staff member not found' });
            return;
        }

        res.json({ success: true, message: `Staff '${result.name}' deactivated` });
    } catch (error: any) {
        logger.error('Failed to deactivate staff', { error: error.message });
        res.status(500).json({ error: 'Failed to deactivate staff' });
    }
});

// ============================================
// STAFF PERMISSION OVERRIDES (Granular Toggles)
// ============================================

/**
 * GET /api/rbac/staff/:staffId/permissions
 * Get effective permissions for a staff member.
 * Returns all permissions with granted/denied status.
 */
router.get('/staff/:staffId/permissions', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const { staffId } = req.params;

        // Verify staff belongs to tenant
        const staff = await queryOne<{ cognito_sub: string; role_id: string }>(
            `SELECT cognito_sub, role_id FROM staff_members WHERE id = $1 AND tenant_id = $2`,
            [staffId, tenantId]
        );

        if (!staff) {
            res.status(404).json({ error: 'Staff member not found' });
            return;
        }

        // Get all permissions with effective state
        const permissions = await query(
            `SELECT
                p.id AS permission_id,
                p.category,
                p.display_name,
                p.description,
                p.is_sensitive,
                CASE
                    WHEN spo.granted IS NOT NULL THEN spo.granted
                    WHEN rp.permission_id IS NOT NULL THEN TRUE
                    ELSE FALSE
                END AS is_granted,
                CASE
                    WHEN spo.granted IS NOT NULL THEN 'override'
                    WHEN rp.permission_id IS NOT NULL THEN 'role'
                    ELSE 'none'
                END AS source
             FROM permissions p
             LEFT JOIN role_permissions rp ON rp.role_id = $1 AND rp.permission_id = p.id
             LEFT JOIN staff_permission_overrides spo ON spo.staff_id = $2 AND spo.permission_id = p.id
             ORDER BY p.category, p.sort_order`,
            [staff.role_id, staffId]
        );

        res.json({ staff_id: staffId, permissions });
    } catch (error: any) {
        logger.error('Failed to fetch staff permissions', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch staff permissions' });
    }
});

/**
 * PUT /api/rbac/staff/:staffId/permissions
 * Set permission overrides for a staff member.
 * Body: { overrides: [{ permission_id: string, granted: boolean }] }
 *
 * To remove an override (revert to role default), omit it from the list.
 */
router.put('/staff/:staffId/permissions', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;
        const { staffId } = req.params;
        const { overrides } = req.body;
        const updatedBy = req.cognitoUser?.sub || (req as any).user?.sub;

        if (!Array.isArray(overrides)) {
            res.status(400).json({ error: 'overrides must be an array' });
            return;
        }

        // Verify staff
        const staff = await queryOne(
            `SELECT id FROM staff_members WHERE id = $1 AND tenant_id = $2`,
            [staffId, tenantId]
        );

        if (!staff) {
            res.status(404).json({ error: 'Staff member not found' });
            return;
        }

        // Replace all overrides in a transaction
        await withTenant(tenantId, async (client) => {
            // Clear existing overrides
            await client.query(
                `DELETE FROM staff_permission_overrides WHERE staff_id = $1 AND tenant_id = $2`,
                [staffId, tenantId]
            );

            // Insert new overrides
            for (const override of overrides) {
                if (!override.permission_id || typeof override.granted !== 'boolean') continue;

                await client.query(
                    `INSERT INTO staff_permission_overrides (staff_id, permission_id, tenant_id, granted, updated_by)
                     VALUES ($1, $2, $3, $4, $5)`,
                    [staffId, override.permission_id, tenantId, override.granted, updatedBy]
                );
            }
        });

        logger.info('Staff permission overrides updated', { staffId, tenantId, count: overrides.length });
        res.json({ success: true, staff_id: staffId, override_count: overrides.length });
    } catch (error: any) {
        logger.error('Failed to update staff overrides', { error: error.message });
        res.status(500).json({ error: 'Failed to update staff permissions' });
    }
});

// ============================================
// SYNC — For Flutter Client
// ============================================

/**
 * GET /api/rbac/my-permissions
 * Get the calling user's effective permissions for the current tenant.
 * Used by Flutter client on login to build the UI.
 */
router.get('/my-permissions', async (req: Request, res: Response) => {
    try {
        const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;
        const tenantId = req.shopId!;
        const userRole = req.cognitoUser?.role || (req as any).user?.role;

        // Owner gets everything
        if (userRole === 'owner' || userRole === 'admin' || userRole === 'superadmin') {
            const allPerms = await query(`SELECT id FROM permissions`);
            res.json({
                role: 'owner',
                role_display_name: 'Owner',
                permissions: allPerms.map((p: any) => p.id),
                is_owner: true,
            });
            return;
        }

        // Staff — get effective permissions
        const staff = await queryOne<{ id: string; role_id: string; name: string }>(
            `SELECT sm.id, sm.role_id, r.name AS role_name, r.display_name AS role_display_name
             FROM staff_members sm
             JOIN roles r ON r.id = sm.role_id
             WHERE sm.cognito_sub = $1 AND sm.tenant_id = $2 AND sm.is_active = TRUE`,
            [cognitoSub, tenantId]
        );

        if (!staff) {
            // No staff record — minimal permissions
            res.json({
                role: userRole || 'staff',
                role_display_name: 'Staff',
                permissions: [],
                is_owner: false,
            });
            return;
        }

        const perms = await query(
            `SELECT permission_id FROM get_effective_permissions($1, $2)`,
            [cognitoSub, tenantId]
        );

        res.json({
            role: (staff as any).role_name,
            role_display_name: (staff as any).role_display_name,
            permissions: perms.map((p: any) => p.permission_id),
            is_owner: false,
            staff_id: staff.id,
        });
    } catch (error: any) {
        logger.error('Failed to fetch user permissions', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch permissions' });
    }
});

// ============================================
// BOOTSTRAP — Initialize roles for a tenant
// ============================================

/**
 * POST /api/rbac/bootstrap
 * Initialize default roles and permissions for the current tenant.
 * Safe to call multiple times (idempotent check).
 * Owner only.
 */
router.post('/bootstrap', checkPermission('manage_staff'), async (req: Request, res: Response) => {
    try {
        const tenantId = req.shopId!;

        // Check if already bootstrapped
        const existing = await queryOne(
            `SELECT id FROM roles WHERE tenant_id = $1 LIMIT 1`,
            [tenantId]
        );

        if (existing) {
            res.json({ success: true, message: 'Roles already initialized', already_exists: true });
            return;
        }

        await query(`SELECT bootstrap_tenant_roles($1)`, [tenantId]);

        logger.info('Tenant RBAC bootstrapped', { tenantId });
        res.status(201).json({ success: true, message: 'Default roles and permissions initialized' });
    } catch (error: any) {
        logger.error('Failed to bootstrap RBAC', { error: error.message });
        res.status(500).json({ error: 'Failed to initialize roles' });
    }
});

/**
 * POST /api/rbac/staff/accept-invite
 * Staff member accepts an invite by providing their invite code.
 * Links their Cognito sub to the staff record.
 * Body: { invite_code: string }
 */
router.post('/staff/accept-invite', async (req: Request, res: Response) => {
    try {
        const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;
        const { invite_code } = req.body;

        if (!invite_code) {
            res.status(400).json({ error: 'invite_code is required' });
            return;
        }

        const staff = await queryOne(
            `UPDATE staff_members
             SET cognito_sub = $1, invite_status = 'accepted', last_login_at = NOW(), updated_at = NOW()
             WHERE invite_code = $2 AND invite_status = 'pending'
             RETURNING id, name, tenant_id`,
            [cognitoSub, invite_code.toUpperCase()]
        );

        if (!staff) {
            res.status(404).json({ error: 'Invalid or expired invite code' });
            return;
        }

        logger.info('Staff invite accepted', { staffId: staff.id, cognitoSub });
        res.json({ success: true, staff });
    } catch (error: any) {
        logger.error('Failed to accept invite', { error: error.message });
        res.status(500).json({ error: 'Failed to accept invite' });
    }
});

export default router;
