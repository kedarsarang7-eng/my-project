// ============================================
// Staff Onboarding Controller — Invite, Claim & Tenant-Scoped Operations
// ============================================

import { Router, Request, Response } from 'express';
import { query, queryOne } from '../config/database';
import { requireCognitoAuth } from '../middleware/cognitoAuth';
import { requireOwnerRole } from '../middleware/requireRole';
import { resolveStaffTenant } from '../middleware/staffTenantResolver';
import { withTenant } from '../middleware/tenantMiddleware';
import { checkPermission } from '../middleware/checkPermission';
import { logger } from '../utils/logger';
import crypto from 'crypto';

const router = Router();

function generateLinkingCode(): string {
    const num = crypto.randomInt(0, 10000);
    return `DX-${num.toString().padStart(4, '0')}`;
}

async function generateUniqueLinkingCode(): Promise<string> {
    let code: string;
    let attempts = 0;
    const MAX_ATTEMPTS = 20;
    do {
        code = generateLinkingCode();
        const existing = await queryOne(`SELECT id FROM staff_invitations WHERE linking_code = $1 AND status = 'pending'`, [code]);
        if (!existing) return code;
        attempts++;
    } while (attempts < MAX_ATTEMPTS);
    const fallbackNum = crypto.randomInt(0, 1000000);
    return `DX-${fallbackNum.toString().padStart(6, '0')}`;
}

// POST /api/staff-onboard/generate-invite
router.post('/generate-invite', requireCognitoAuth, requireOwnerRole, async (req: Request, res: Response) => {
    try {
        const ownerSub = req.cognitoUser!.sub;
        const tenantId = req.cognitoUser!.tenantId;
        if (!tenantId) {
            res.status(400).json({ error: 'Your account is not associated with a business.', code: 'MISSING_TENANT' });
            return;
        }

        let staffId: string;
        let staffRecord: any;

        if (req.body.staff_id) {
            staffId = req.body.staff_id;
            staffRecord = await queryOne(
                `SELECT id, name, email, phone, invite_status, cognito_sub FROM staff_members WHERE id = $1 AND tenant_id = $2`,
                [staffId, tenantId]
            );
            if (!staffRecord) { res.status(404).json({ error: 'Staff member not found in your business', code: 'STAFF_NOT_FOUND' }); return; }
            if (staffRecord.cognito_sub && staffRecord.invite_status === 'accepted') {
                res.status(409).json({ error: 'This staff member has already claimed their profile.', code: 'ALREADY_CLAIMED' }); return;
            }
        } else {
            const { name, email, phone, role_id } = req.body;
            if (!name || !role_id) {
                res.status(400).json({ error: 'Provide either staff_id or { name, role_id }', code: 'MISSING_FIELDS' }); return;
            }
            const role = await queryOne<{ name: string }>(`SELECT name FROM roles WHERE id = $1 AND tenant_id = $2`, [role_id, tenantId]);
            if (!role) { res.status(404).json({ error: 'Role not found', code: 'ROLE_NOT_FOUND' }); return; }
            if (role.name === 'owner') { res.status(403).json({ error: 'Cannot assign owner role to staff', code: 'OWNER_ROLE_FORBIDDEN' }); return; }

            staffRecord = await queryOne(
                `INSERT INTO staff_members (tenant_id, owner_id, name, email, phone, role_id, invite_status, created_by)
                 VALUES ($1, $2, $3, $4, $5, $6, 'pending', $2) RETURNING id, name, email, phone, invite_status`,
                [tenantId, ownerSub, name, email || null, phone || null, role_id]
            );
            staffId = staffRecord.id;
        }

        await query(`UPDATE staff_invitations SET status = 'revoked', updated_at = NOW() WHERE staff_id = $1 AND status = 'pending'`, [staffId]);
        const linkingCode = await generateUniqueLinkingCode();
        const expiryHours = parseInt(req.body.expiry_hours || '72', 10);
        const expiryDate = new Date(Date.now() + expiryHours * 60 * 60 * 1000);

        const invitation = await queryOne(
            `INSERT INTO staff_invitations (staff_id, business_id, owner_id, linking_code, status, expiry_date)
             VALUES ($1, $2, $3, $4, 'pending', $5) RETURNING id, linking_code, status, expiry_date, created_at`,
            [staffId, tenantId, ownerSub, linkingCode, expiryDate.toISOString()]
        );

        await query(`UPDATE staff_members SET invite_code = $1, owner_id = $2, updated_at = NOW() WHERE id = $3`, [linkingCode, ownerSub, staffId]);

        logger.info('Staff invite generated', { staffId, businessId: tenantId, linkingCode, expiresAt: expiryDate.toISOString() });
        res.status(201).json({
            success: true,
            invitation: { id: invitation!.id, linking_code: invitation!.linking_code, status: invitation!.status, expiry_date: invitation!.expiry_date, created_at: invitation!.created_at },
            staff: { id: staffRecord.id, name: staffRecord.name, email: staffRecord.email, phone: staffRecord.phone },
            message: `Share this code with your staff member: ${linkingCode}`,
        });
    } catch (error: any) {
        if (error.constraint) { res.status(409).json({ error: 'Duplicate entry.', code: 'DUPLICATE' }); return; }
        logger.error('Generate invite failed', { error: error.message });
        res.status(500).json({ error: 'Failed to generate invite', code: 'INTERNAL_ERROR' });
    }
});

// POST /api/staff-onboard/claim-profile
router.post('/claim-profile', requireCognitoAuth, async (req: Request, res: Response) => {
    try {
        const cognitoSub = req.cognitoUser!.sub;
        const { linking_code } = req.body;
        if (!linking_code || typeof linking_code !== 'string') {
            res.status(400).json({ error: 'linking_code is required', code: 'MISSING_CODE' }); return;
        }
        const cleanCode = linking_code.trim().toUpperCase();

        const existingLink = await queryOne(
            `SELECT sm.id, sm.tenant_id, sm.name FROM staff_members sm WHERE sm.cognito_sub = $1 AND sm.is_active = TRUE`,
            [cognitoSub]
        );
        if (existingLink) {
            res.status(409).json({ error: 'Your account is already linked to a business.', code: 'ALREADY_LINKED', current_business_id: (existingLink as any).tenant_id });
            return;
        }

        const invitation = await queryOne<{ id: string; staff_id: string; business_id: string; owner_id: string; status: string; expiry_date: Date }>(
            `SELECT id, staff_id, business_id, owner_id, status, expiry_date FROM staff_invitations WHERE linking_code = $1`,
            [cleanCode]
        );
        if (!invitation) { res.status(404).json({ error: 'Invalid linking code.', code: 'CODE_NOT_FOUND' }); return; }

        if (invitation.status !== 'pending') {
            const statusMessages: Record<string, string> = {
                active: 'This code has already been used.', expired: 'This code has expired.', revoked: 'This code has been revoked.',
            };
            res.status(410).json({ error: statusMessages[invitation.status] || 'This code is no longer valid.', code: 'CODE_INVALID_STATUS', status: invitation.status });
            return;
        }

        if (new Date() > new Date(invitation.expiry_date)) {
            await query(`UPDATE staff_invitations SET status = 'expired', updated_at = NOW() WHERE id = $1`, [invitation.id]);
            res.status(410).json({ error: 'This linking code has expired.', code: 'CODE_EXPIRED' }); return;
        }

        await withTenant(invitation.business_id, async (client) => {
            await client.query(
                `UPDATE staff_members SET cognito_sub = $1, owner_id = $2, invite_status = 'accepted', is_active = TRUE, last_login_at = NOW(), updated_at = NOW() WHERE id = $3`,
                [cognitoSub, invitation.owner_id, invitation.staff_id]
            );
            await client.query(
                `UPDATE staff_invitations SET status = 'active', claimed_by_cognito_sub = $1, claimed_at = NOW(), updated_at = NOW() WHERE id = $2`,
                [cognitoSub, invitation.id]
            );
        });

        const profile = await queryOne(
            `SELECT sm.id AS staff_id, sm.name, sm.email, sm.phone, sm.tenant_id AS business_id, sm.owner_id,
                    r.name AS role_name, r.display_name AS role_display_name
             FROM staff_members sm JOIN roles r ON r.id = sm.role_id WHERE sm.id = $1`,
            [invitation.staff_id]
        );

        logger.info('Staff profile claimed', { staffId: invitation.staff_id, businessId: invitation.business_id, cognitoSub, linkingCode: cleanCode });
        res.json({ success: true, message: 'Profile linked successfully!', profile });
    } catch (error: any) {
        logger.error('Claim profile failed', { error: error.message });
        res.status(500).json({ error: 'Failed to claim profile', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/staff-onboard/my-profile
router.get('/my-profile', requireCognitoAuth, resolveStaffTenant, async (req: Request, res: Response) => {
    try {
        const ctx = req.staffContext!;
        const profile = await queryOne(
            `SELECT sm.id AS staff_id, sm.name, sm.email, sm.phone, sm.tenant_id AS business_id, sm.owner_id,
                    sm.invite_status, sm.last_login_at, r.name AS role_name, r.display_name AS role_display_name,
                    t.name AS business_name, t.business_type, t.phone AS business_phone
             FROM staff_members sm JOIN roles r ON r.id = sm.role_id LEFT JOIN tenants t ON t.id = sm.tenant_id WHERE sm.id = $1`,
            [ctx.staffId]
        );
        if (!profile) { res.status(404).json({ error: 'Profile not found', code: 'PROFILE_NOT_FOUND' }); return; }
        res.json({ profile });
    } catch (error: any) {
        logger.error('Fetch profile failed', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch profile', code: 'INTERNAL_ERROR' });
    }
});

// POST /api/staff-onboard/meter-reading
router.post('/meter-reading', requireCognitoAuth, resolveStaffTenant, async (req: Request, res: Response) => {
    try {
        const ctx = req.staffContext!;
        const { nozzle_id, reading_type, reading_value, shift_number, notes, latitude, longitude, photo_url } = req.body;

        if (!nozzle_id || !reading_type || reading_value === undefined) {
            res.status(400).json({ error: 'nozzle_id, reading_type, and reading_value are required', code: 'MISSING_FIELDS' }); return;
        }
        if (!['opening', 'closing'].includes(reading_type)) {
            res.status(400).json({ error: 'reading_type must be "opening" or "closing"', code: 'INVALID_READING_TYPE' }); return;
        }
        if (typeof reading_value !== 'number' || reading_value < 0) {
            res.status(400).json({ error: 'reading_value must be a non-negative number', code: 'INVALID_READING_VALUE' }); return;
        }

        const reading = await queryOne(
            `INSERT INTO meter_readings (business_id, owner_id, staff_id, nozzle_id, reading_type, reading_value, shift_number, notes, latitude, longitude, photo_url)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
             RETURNING id, business_id, owner_id, staff_id, nozzle_id, reading_type, reading_value, shift_date, shift_number, created_at`,
            [ctx.businessId, ctx.ownerId, ctx.staffId, nozzle_id, reading_type, reading_value, shift_number || 1, notes || null, latitude || null, longitude || null, photo_url || null]
        );

        logger.info('Meter reading recorded', { readingId: reading!.id, businessId: ctx.businessId, staffId: ctx.staffId, nozzle: nozzle_id, type: reading_type, value: reading_value });
        res.status(201).json({ success: true, reading, message: `${reading_type} reading recorded for nozzle ${nozzle_id}` });
    } catch (error: any) {
        logger.error('Meter reading failed', { error: error.message });
        res.status(500).json({ error: 'Failed to record meter reading', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/staff-onboard/meter-readings
router.get('/meter-readings', requireCognitoAuth, resolveStaffTenant, async (req: Request, res: Response) => {
    try {
        const ctx = req.staffContext!;
        const { shift_date, nozzle_id, limit } = req.query;

        let sql = `SELECT mr.id, mr.nozzle_id, mr.reading_type, mr.reading_value, mr.shift_date, mr.shift_number, mr.notes,
                          mr.latitude, mr.longitude, mr.created_at, sm.name AS staff_name
                   FROM meter_readings mr JOIN staff_members sm ON sm.id = mr.staff_id WHERE mr.business_id = $1`;
        const params: any[] = [ctx.businessId];
        let idx = 2;

        if (shift_date) { sql += ` AND mr.shift_date = $${idx++}`; params.push(shift_date); }
        if (nozzle_id) { sql += ` AND mr.nozzle_id = $${idx++}`; params.push(nozzle_id); }

        sql += ` ORDER BY mr.created_at DESC LIMIT $${idx}`;
        params.push(Math.min(parseInt((limit as string) || '50', 10), 200));

        const readings = await query(sql, params);
        res.json({ readings, count: readings.length, business_id: ctx.businessId });
    } catch (error: any) {
        logger.error('List meter readings failed', { error: error.message });
        res.status(500).json({ error: 'Failed to fetch meter readings', code: 'INTERNAL_ERROR' });
    }
});

export default router;
