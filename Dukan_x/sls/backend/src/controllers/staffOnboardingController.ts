// ============================================
// Staff Onboarding Controller — Invite, Claim & Tenant-Scoped Operations
// ============================================
// Handles the complete staff onboarding lifecycle:
//
//   POST /api/staff-onboard/generate-invite   — Owner generates DX-XXXX linking code
//   POST /api/staff-onboard/claim-profile     — Staff validates code & links Cognito UUID
//   GET  /api/staff-onboard/my-profile        — Staff gets their linked profile
//   POST /api/staff-onboard/meter-reading     — Sample tenant-scoped transaction API
//   GET  /api/staff-onboard/meter-readings    — List readings (tenant-scoped)
//
// Security:
//   - generate-invite: Owner-only (requireCognitoAuth + requireOwnerRole)
//   - claim-profile:   Any authenticated Cognito user (staff signs up first, then claims)
//   - my-profile:      Any authenticated staff (resolveStaffTenant)
//   - meter-reading:   Linked staff only (resolveStaffTenant auto-injects business_id)
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

// ============================================
// HELPER: Generate DX-XXXX Linking Code
// ============================================

function generateLinkingCode(): string {
    // Cryptographically random 4-digit code with DX- prefix
    const num = crypto.randomInt(0, 10000);
    return `DX-${num.toString().padStart(4, '0')}`;
}

async function generateUniqueLinkingCode(): Promise<string> {
    let code: string;
    let attempts = 0;
    const MAX_ATTEMPTS = 20;

    do {
        code = generateLinkingCode();
        const existing = await queryOne(
            `SELECT id FROM staff_invitations WHERE linking_code = $1 AND status = 'pending'`,
            [code]
        );
        if (!existing) return code;
        attempts++;
    } while (attempts < MAX_ATTEMPTS);

    // Fallback: longer code for uniqueness
    const fallbackNum = crypto.randomInt(0, 1000000);
    return `DX-${fallbackNum.toString().padStart(6, '0')}`;
}

// ============================================
// POST /api/staff-onboard/generate-invite
// ============================================
// Owner generates a linking code for a staff member.
//
// Body: { staff_id: string }  (existing staff_members.id)
//   OR  { name, email?, phone?, role_id }  (creates new staff + invite in one shot)
//
// Returns: { linking_code, expiry_date, staff }

router.post(
    '/generate-invite',
    requireCognitoAuth,
    requireOwnerRole,
    async (req: Request, res: Response) => {
        try {
            const ownerSub = req.cognitoUser!.sub;
            const tenantId = req.cognitoUser!.tenantId;

            if (!tenantId) {
                res.status(400).json({
                    error: 'Your account is not associated with a business. Set custom:tenant_id in Cognito.',
                    code: 'MISSING_TENANT',
                });
                return;
            }

            let staffId: string;
            let staffRecord: any;

            if (req.body.staff_id) {
                // ---- Mode A: Generate invite for existing staff record ----
                staffId = req.body.staff_id;

                staffRecord = await queryOne(
                    `SELECT id, name, email, phone, invite_status, cognito_sub
                     FROM staff_members
                     WHERE id = $1 AND tenant_id = $2`,
                    [staffId, tenantId]
                );

                if (!staffRecord) {
                    res.status(404).json({ error: 'Staff member not found in your business', code: 'STAFF_NOT_FOUND' });
                    return;
                }

                if (staffRecord.cognito_sub && staffRecord.invite_status === 'accepted') {
                    res.status(409).json({
                        error: 'This staff member has already claimed their profile.',
                        code: 'ALREADY_CLAIMED',
                    });
                    return;
                }
            } else {
                // ---- Mode B: Create new staff + invite in one shot ----
                const { name, email, phone, role_id } = req.body;

                if (!name || !role_id) {
                    res.status(400).json({
                        error: 'Provide either staff_id (existing) or { name, role_id } (new staff)',
                        code: 'MISSING_FIELDS',
                    });
                    return;
                }

                // Verify role belongs to this tenant
                const role = await queryOne<{ name: string }>(
                    `SELECT name FROM roles WHERE id = $1 AND tenant_id = $2`,
                    [role_id, tenantId]
                );

                if (!role) {
                    res.status(404).json({ error: 'Role not found for your business', code: 'ROLE_NOT_FOUND' });
                    return;
                }

                if (role.name === 'owner') {
                    res.status(403).json({ error: 'Cannot assign owner role to staff', code: 'OWNER_ROLE_FORBIDDEN' });
                    return;
                }

                // Create staff_members record
                staffRecord = await queryOne(
                    `INSERT INTO staff_members (tenant_id, owner_id, name, email, phone, role_id, invite_status, created_by)
                     VALUES ($1, $2, $3, $4, $5, $6, 'pending', $2)
                     RETURNING id, name, email, phone, invite_status`,
                    [tenantId, ownerSub, name, email || null, phone || null, role_id]
                );

                staffId = staffRecord.id;
            }

            // Revoke any existing pending invites for this staff
            await query(
                `UPDATE staff_invitations
                 SET status = 'revoked', updated_at = NOW()
                 WHERE staff_id = $1 AND status = 'pending'`,
                [staffId]
            );

            // Generate unique linking code
            const linkingCode = await generateUniqueLinkingCode();

            // Default expiry: 72 hours from now
            const expiryHours = parseInt(req.body.expiry_hours || '72', 10);
            const expiryDate = new Date(Date.now() + expiryHours * 60 * 60 * 1000);

            // Insert invitation
            const invitation = await queryOne(
                `INSERT INTO staff_invitations (staff_id, business_id, owner_id, linking_code, status, expiry_date)
                 VALUES ($1, $2, $3, $4, 'pending', $5)
                 RETURNING id, linking_code, status, expiry_date, created_at`,
                [staffId, tenantId, ownerSub, linkingCode, expiryDate.toISOString()]
            );

            // Also update the staff_members invite_code for backward compat with existing RBAC flow
            await query(
                `UPDATE staff_members SET invite_code = $1, owner_id = $2, updated_at = NOW()
                 WHERE id = $3`,
                [linkingCode, ownerSub, staffId]
            );

            logger.info('Staff invite generated', {
                staffId,
                businessId: tenantId,
                linkingCode,
                expiresAt: expiryDate.toISOString(),
            });

            res.status(201).json({
                success: true,
                invitation: {
                    id: invitation!.id,
                    linking_code: invitation!.linking_code,
                    status: invitation!.status,
                    expiry_date: invitation!.expiry_date,
                    created_at: invitation!.created_at,
                },
                staff: {
                    id: staffRecord.id,
                    name: staffRecord.name,
                    email: staffRecord.email,
                    phone: staffRecord.phone,
                },
                message: `Share this code with your staff member: ${linkingCode}`,
            });
        } catch (error: any) {
            if (error.constraint) {
                res.status(409).json({ error: 'Duplicate entry. A staff member with this email/phone may already exist.', code: 'DUPLICATE' });
                return;
            }
            logger.error('Generate invite failed', { error: error.message });
            res.status(500).json({ error: 'Failed to generate invite', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// POST /api/staff-onboard/claim-profile
// ============================================
// Staff enters the DX-XXXX code to link their Cognito UUID to the business.
//
// Body: { linking_code: string }
//
// Flow:
//   1. Validate code exists & is pending & not expired
//   2. Map the staff's Cognito UUID → staff_members.cognito_sub
//   3. Set staff_members.owner_id, invite_status = 'accepted'
//   4. Update staff_invitations status = 'active'
//   5. Return the linked profile (businessId, ownerId, role)

router.post(
    '/claim-profile',
    requireCognitoAuth,
    async (req: Request, res: Response) => {
        try {
            const cognitoSub = req.cognitoUser!.sub;
            const { linking_code } = req.body;

            if (!linking_code || typeof linking_code !== 'string') {
                res.status(400).json({ error: 'linking_code is required', code: 'MISSING_CODE' });
                return;
            }

            const cleanCode = linking_code.trim().toUpperCase();

            // 1. Check if this Cognito user is already linked to a business
            const existingLink = await queryOne(
                `SELECT sm.id, sm.tenant_id, sm.name
                 FROM staff_members sm
                 WHERE sm.cognito_sub = $1 AND sm.is_active = TRUE`,
                [cognitoSub]
            );

            if (existingLink) {
                res.status(409).json({
                    error: 'Your account is already linked to a business. Contact admin to unlink first.',
                    code: 'ALREADY_LINKED',
                    current_business_id: (existingLink as any).tenant_id,
                });
                return;
            }

            // 2. Find the invitation
            const invitation = await queryOne<{
                id: string;
                staff_id: string;
                business_id: string;
                owner_id: string;
                status: string;
                expiry_date: Date;
            }>(
                `SELECT id, staff_id, business_id, owner_id, status, expiry_date
                 FROM staff_invitations
                 WHERE linking_code = $1`,
                [cleanCode]
            );

            if (!invitation) {
                res.status(404).json({
                    error: 'Invalid linking code. Please check the code and try again.',
                    code: 'CODE_NOT_FOUND',
                });
                return;
            }

            // 3. Validate status
            if (invitation.status !== 'pending') {
                const statusMessages: Record<string, string> = {
                    active: 'This code has already been used.',
                    expired: 'This code has expired. Ask the owner for a new one.',
                    revoked: 'This code has been revoked by the owner.',
                };
                res.status(410).json({
                    error: statusMessages[invitation.status] || 'This code is no longer valid.',
                    code: 'CODE_INVALID_STATUS',
                    status: invitation.status,
                });
                return;
            }

            // 4. Check expiry
            if (new Date() > new Date(invitation.expiry_date)) {
                // Auto-expire it
                await query(
                    `UPDATE staff_invitations SET status = 'expired', updated_at = NOW() WHERE id = $1`,
                    [invitation.id]
                );
                res.status(410).json({
                    error: 'This linking code has expired. Ask the owner to generate a new one.',
                    code: 'CODE_EXPIRED',
                });
                return;
            }

            // 5. Link the staff member — atomic transaction
            await withTenant(invitation.business_id, async (client) => {
                // Update staff_members: bind Cognito UUID + set active
                await client.query(
                    `UPDATE staff_members
                     SET cognito_sub = $1,
                         owner_id = $2,
                         invite_status = 'accepted',
                         is_active = TRUE,
                         last_login_at = NOW(),
                         updated_at = NOW()
                     WHERE id = $3`,
                    [cognitoSub, invitation.owner_id, invitation.staff_id]
                );

                // Update invitation: mark as active
                await client.query(
                    `UPDATE staff_invitations
                     SET status = 'active',
                         claimed_by_cognito_sub = $1,
                         claimed_at = NOW(),
                         updated_at = NOW()
                     WHERE id = $2`,
                    [cognitoSub, invitation.id]
                );
            });

            // 6. Fetch the linked profile to return
            const profile = await queryOne(
                `SELECT sm.id AS staff_id, sm.name, sm.email, sm.phone,
                        sm.tenant_id AS business_id, sm.owner_id,
                        r.name AS role_name, r.display_name AS role_display_name
                 FROM staff_members sm
                 JOIN roles r ON r.id = sm.role_id
                 WHERE sm.id = $1`,
                [invitation.staff_id]
            );

            logger.info('Staff profile claimed', {
                staffId: invitation.staff_id,
                businessId: invitation.business_id,
                cognitoSub,
                linkingCode: cleanCode,
            });

            res.json({
                success: true,
                message: 'Profile linked successfully! You are now connected to your employer.',
                profile,
            });
        } catch (error: any) {
            logger.error('Claim profile failed', { error: error.message });
            res.status(500).json({ error: 'Failed to claim profile', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/staff-onboard/my-profile
// ============================================
// Returns the staff member's linked profile (business info, role, permissions).
// Requires linked staff (resolveStaffTenant middleware).

router.get(
    '/my-profile',
    requireCognitoAuth,
    resolveStaffTenant,
    async (req: Request, res: Response) => {
        try {
            const ctx = req.staffContext!;

            // Fetch full profile with business details
            const profile = await queryOne(
                `SELECT sm.id AS staff_id, sm.name, sm.email, sm.phone,
                        sm.tenant_id AS business_id, sm.owner_id,
                        sm.invite_status, sm.last_login_at,
                        r.name AS role_name, r.display_name AS role_display_name,
                        t.name AS business_name, t.business_type, t.phone AS business_phone
                 FROM staff_members sm
                 JOIN roles r ON r.id = sm.role_id
                 LEFT JOIN tenants t ON t.id = sm.tenant_id
                 WHERE sm.id = $1`,
                [ctx.staffId]
            );

            if (!profile) {
                res.status(404).json({ error: 'Profile not found', code: 'PROFILE_NOT_FOUND' });
                return;
            }

            res.json({ profile });
        } catch (error: any) {
            logger.error('Fetch profile failed', { error: error.message });
            res.status(500).json({ error: 'Failed to fetch profile', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// POST /api/staff-onboard/meter-reading
// ============================================
// SAMPLE tenant-scoped transaction API.
// Demonstrates how business_id + owner_id are AUTO-INJECTED from staff context.
// Staff never passes business_id — it comes from resolveStaffTenant.
//
// Body: { nozzle_id, reading_type, reading_value, shift_number?, notes?, latitude?, longitude? }

router.post(
    '/meter-reading',
    requireCognitoAuth,
    resolveStaffTenant,
    async (req: Request, res: Response) => {
        try {
            const ctx = req.staffContext!;
            const {
                nozzle_id,
                reading_type,
                reading_value,
                shift_number,
                notes,
                latitude,
                longitude,
                photo_url,
            } = req.body;

            // Validate required fields
            if (!nozzle_id || !reading_type || reading_value === undefined) {
                res.status(400).json({
                    error: 'nozzle_id, reading_type, and reading_value are required',
                    code: 'MISSING_FIELDS',
                });
                return;
            }

            if (!['opening', 'closing'].includes(reading_type)) {
                res.status(400).json({
                    error: 'reading_type must be "opening" or "closing"',
                    code: 'INVALID_READING_TYPE',
                });
                return;
            }

            if (typeof reading_value !== 'number' || reading_value < 0) {
                res.status(400).json({
                    error: 'reading_value must be a non-negative number',
                    code: 'INVALID_READING_VALUE',
                });
                return;
            }

            // Insert with auto-injected business_id + owner_id from staff context
            const reading = await queryOne(
                `INSERT INTO meter_readings
                    (business_id, owner_id, staff_id, nozzle_id, reading_type,
                     reading_value, shift_number, notes, latitude, longitude, photo_url)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                 RETURNING id, business_id, owner_id, staff_id, nozzle_id,
                           reading_type, reading_value, shift_date, shift_number,
                           created_at`,
                [
                    ctx.businessId,    // Auto from staffContext — NEVER from user input
                    ctx.ownerId,       // Auto from staffContext — NEVER from user input
                    ctx.staffId,       // Auto from staffContext
                    nozzle_id,
                    reading_type,
                    reading_value,
                    shift_number || 1,
                    notes || null,
                    latitude || null,
                    longitude || null,
                    photo_url || null,
                ]
            );

            logger.info('Meter reading recorded', {
                readingId: reading!.id,
                businessId: ctx.businessId,
                staffId: ctx.staffId,
                nozzle: nozzle_id,
                type: reading_type,
                value: reading_value,
            });

            res.status(201).json({
                success: true,
                reading,
                message: `${reading_type} reading recorded for nozzle ${nozzle_id}`,
            });
        } catch (error: any) {
            logger.error('Meter reading failed', { error: error.message });
            res.status(500).json({ error: 'Failed to record meter reading', code: 'INTERNAL_ERROR' });
        }
    }
);

// ============================================
// GET /api/staff-onboard/meter-readings
// ============================================
// List meter readings — automatically scoped to the staff's business.
// Query params: ?shift_date=2025-02-16&nozzle_id=N1&limit=50

router.get(
    '/meter-readings',
    requireCognitoAuth,
    resolveStaffTenant,
    async (req: Request, res: Response) => {
        try {
            const ctx = req.staffContext!;
            const { shift_date, nozzle_id, limit } = req.query;

            let sql = `
                SELECT mr.id, mr.nozzle_id, mr.reading_type, mr.reading_value,
                       mr.shift_date, mr.shift_number, mr.notes,
                       mr.latitude, mr.longitude, mr.created_at,
                       sm.name AS staff_name
                FROM meter_readings mr
                JOIN staff_members sm ON sm.id = mr.staff_id
                WHERE mr.business_id = $1
            `;
            const params: any[] = [ctx.businessId];
            let idx = 2;

            if (shift_date) {
                sql += ` AND mr.shift_date = $${idx++}`;
                params.push(shift_date);
            }

            if (nozzle_id) {
                sql += ` AND mr.nozzle_id = $${idx++}`;
                params.push(nozzle_id);
            }

            sql += ` ORDER BY mr.created_at DESC LIMIT $${idx}`;
            params.push(Math.min(parseInt((limit as string) || '50', 10), 200));

            const readings = await query(sql, params);

            res.json({
                readings,
                count: readings.length,
                business_id: ctx.businessId,
            });
        } catch (error: any) {
            logger.error('List meter readings failed', { error: error.message });
            res.status(500).json({ error: 'Failed to fetch meter readings', code: 'INTERNAL_ERROR' });
        }
    }
);

export default router;
