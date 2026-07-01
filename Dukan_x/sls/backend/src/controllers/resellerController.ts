// ============================================
// Reseller Controller — Sub-Account Management
// ============================================

import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { requireCognitoAuth as requireAuth, requireCognitoAdmin as requireAdmin } from '../middleware/cognitoAuth';
import { query, queryOne } from '../config/database';
import * as licenseService from '../services/licenseService';
import {
    createResellerSchema, resellerGenerateSchema, validateBody
} from '../utils/validators';
import { Reseller } from '../models/types';
import { logger } from '../utils/logger';

const router = Router();

/**
 * GET /api/resellers
 * List all resellers (admin only).
 */
router.get('/', requireAuth, requireAdmin, async (req: Request, res: Response) => {
    try {
        const resellers = await query<Reseller>(
            `SELECT id, email, company_name, display_name, total_credits, used_credits, 
              allowed_tiers, max_trial_days, is_active, last_login_at, created_at
       FROM resellers ORDER BY created_at DESC`
        );
        res.json({ data: resellers, total: resellers.length });
    } catch (error: any) {
        logger.error('List resellers error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * GET /api/resellers/:id
 * Get a single reseller's details.
 */
router.get('/:id', requireAuth, requireAdmin, async (req: Request, res: Response) => {
    try {
        const reseller = await queryOne<Reseller>(
            `SELECT id, email, company_name, display_name, total_credits, used_credits,
              allowed_tiers, max_trial_days, is_active, last_login_at, created_at
       FROM resellers WHERE id = $1`,
            [req.params.id]
        );
        if (!reseller) {
            res.status(404).json({ error: 'Reseller not found' });
            return;
        }
        res.json(reseller);
    } catch (error: any) {
        logger.error('Get reseller error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/resellers
 * Create a new reseller sub-account (admin only).
 */
router.post('/', requireAuth, requireAdmin, async (req: Request, res: Response) => {
    try {
        const data = validateBody(createResellerSchema, req.body);

        // Check duplicate email
        const existing = await queryOne('SELECT id FROM resellers WHERE email = $1', [data.email]);
        if (existing) {
            res.status(409).json({ error: 'A reseller with this email already exists' });
            return;
        }

        // Hash password
        const passwordHash = await bcrypt.hash(data.password, 12);

        const reseller = await queryOne<Reseller>(
            `INSERT INTO resellers (
        email, password_hash, company_name, display_name,
        total_credits, allowed_tiers, max_trial_days, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING 
        id, email, company_name, display_name, total_credits, used_credits,
        allowed_tiers, max_trial_days, is_active, created_at`,
            [
                data.email, passwordHash, data.company_name, data.display_name,
                data.total_credits, data.allowed_tiers, data.max_trial_days || 7,
                req.user!.sub,
            ]
        );

        logger.info('Reseller created', { id: reseller!.id, company: data.company_name });
        res.status(201).json(reseller);
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Create reseller error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * PUT /api/resellers/:id
 * Update reseller credits, allowed tiers, or active status.
 */
router.put('/:id', requireAuth, requireAdmin, async (req: Request, res: Response) => {
    try {
        const { total_credits, allowed_tiers, max_trial_days, is_active } = req.body;
        const updates: string[] = [];
        const values: any[] = [];
        let paramIndex = 1;

        if (total_credits !== undefined) {
            updates.push(`total_credits = $${paramIndex++}`);
            values.push(total_credits);
        }
        if (allowed_tiers !== undefined) {
            updates.push(`allowed_tiers = $${paramIndex++}`);
            values.push(allowed_tiers);
        }
        if (max_trial_days !== undefined) {
            updates.push(`max_trial_days = $${paramIndex++}`);
            values.push(max_trial_days);
        }
        if (is_active !== undefined) {
            updates.push(`is_active = $${paramIndex++}`);
            values.push(is_active);
        }

        if (updates.length === 0) {
            res.status(400).json({ error: 'No fields to update' });
            return;
        }

        values.push(req.params.id);
        const reseller = await queryOne<Reseller>(
            `UPDATE resellers SET ${updates.join(', ')} WHERE id = $${paramIndex}
       RETURNING id, email, company_name, display_name, total_credits, used_credits,
       allowed_tiers, max_trial_days, is_active`,
            values
        );

        if (!reseller) {
            res.status(404).json({ error: 'Reseller not found' });
            return;
        }

        res.json(reseller);
    } catch (error: any) {
        logger.error('Update reseller error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

/**
 * POST /api/resellers/:id/generate
 * Reseller generates a license key (uses their credits).
 * This can be called by the reseller themselves.
 */
router.post('/:id/generate', requireAuth, async (req: Request, res: Response) => {
    try {
        const resellerId = req.params.id;

        // Resellers can only generate for themselves
        if (req.user!.role === 'reseller' && req.user!.sub !== resellerId) {
            res.status(403).json({ error: 'Cannot generate keys for another reseller' });
            return;
        }

        // Get reseller and check credits
        const reseller = await queryOne<Reseller>(
            'SELECT * FROM resellers WHERE id = $1 AND is_active = TRUE',
            [resellerId]
        );

        if (!reseller) {
            res.status(404).json({ error: 'Reseller not found or inactive' });
            return;
        }

        const remainingCredits = reseller.total_credits - reseller.used_credits;
        if (remainingCredits <= 0) {
            res.status(403).json({
                error: 'No credits remaining. Contact admin to add more credits.',
                code: 'NO_CREDITS',
                remaining: 0,
            });
            return;
        }

        // Validate the license request
        const data = validateBody(resellerGenerateSchema, req.body);

        // Enforce tier restrictions
        if (!reseller.allowed_tiers.includes(data.tier)) {
            res.status(403).json({
                error: `You are not authorized to generate ${data.tier} tier licenses`,
                allowed_tiers: reseller.allowed_tiers,
            });
            return;
        }

        // Enforce trial day limits
        if (data.trial_days && data.trial_days > reseller.max_trial_days) {
            res.status(403).json({
                error: `Maximum trial period is ${reseller.max_trial_days} days`,
                max_trial_days: reseller.max_trial_days,
            });
            return;
        }

        // Generate the license
        const license = await licenseService.createLicense(
            data as any,
            req.user!.sub,  // issued_by
            resellerId       // reseller_id
        );

        // Deduct credit
        await queryOne(
            'UPDATE resellers SET used_credits = used_credits + 1 WHERE id = $1',
            [resellerId]
        );

        logger.info('Reseller generated license', {
            resellerId,
            licenseId: license.id,
            remainingCredits: remainingCredits - 1,
        });

        res.status(201).json({
            license,
            credits: {
                total: reseller.total_credits,
                used: reseller.used_credits + 1,
                remaining: remainingCredits - 1,
            },
        });
    } catch (error: any) {
        if (error.name === 'ZodError') {
            res.status(400).json({ error: 'Validation failed', details: error.errors });
            return;
        }
        logger.error('Reseller generate error', { error: error.message });
        res.status(500).json({ error: 'Internal server error' });
    }
});

export default router;
