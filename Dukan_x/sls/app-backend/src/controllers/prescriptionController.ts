// ============================================================================
// Prescription Controller — Shared Prescription Endpoints
// ============================================================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth as requireAuth } from '../middleware/cognitoAuth';
import { query, queryOne } from '../config/database';
import { logger } from '../utils/logger';

const router = Router();

// POST /api/prescriptions — Upload a shared prescription (Clinic side)
router.post('/', requireAuth, async (req: Request, res: Response) => {
    try {
        const {
            rx_id, clinic_shop_id, doctor_id, doctor_name, clinic_name,
            patient_name, patient_phone, prescription_date, advice, items,
        } = req.body;

        if (!rx_id || !clinic_shop_id || !doctor_id || !doctor_name || !patient_name) {
            res.status(400).json({
                error: 'Missing required fields: rx_id, clinic_shop_id, doctor_id, doctor_name, patient_name',
                code: 'VALIDATION_ERROR',
            });
            return;
        }

        if (!items || !Array.isArray(items) || items.length === 0) {
            res.status(400).json({ error: 'Prescription must have at least one medicine item', code: 'VALIDATION_ERROR' });
            return;
        }

        const existing = await queryOne('SELECT rx_id FROM shared_prescriptions WHERE rx_id = $1', [rx_id]);
        if (existing) {
            res.status(409).json({ error: 'Prescription with this ID already exists', code: 'DUPLICATE_RX_ID' });
            return;
        }

        await query(
            `INSERT INTO shared_prescriptions 
             (rx_id, clinic_shop_id, doctor_id, doctor_name, clinic_name, 
              patient_name, patient_phone, prescription_date, advice, items, status, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending', NOW())`,
            [rx_id, clinic_shop_id, doctor_id, doctor_name, clinic_name || 'Clinic',
             patient_name, patient_phone || null, prescription_date || new Date().toISOString(),
             advice || null, JSON.stringify(items)]
        );

        logger.info('Prescription uploaded', { rx_id, clinic_shop_id, items_count: items.length });
        res.status(201).json({ success: true, rx_id, message: 'Prescription uploaded successfully' });
    } catch (error: any) {
        logger.error('Failed to upload prescription', { error: error.message });
        res.status(500).json({ error: 'Failed to upload prescription', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/prescriptions/:rxId — Fetch a prescription by rxId (Pharmacy side)
router.get('/:rxId', async (req: Request, res: Response) => {
    try {
        const { rxId } = req.params;
        const row = await queryOne<any>(
            `SELECT rx_id, clinic_shop_id, doctor_id, doctor_name, clinic_name,
                    patient_name, patient_phone, prescription_date, advice, items,
                    status, fulfilled_by, fulfilled_at, created_at
             FROM shared_prescriptions WHERE rx_id = $1`,
            [rxId]
        );

        if (!row) {
            res.status(404).json({ error: 'Prescription not found', code: 'NOT_FOUND' });
            return;
        }

        res.json({
            prescription: {
                ...row,
                items: typeof row.items === 'string' ? JSON.parse(row.items) : row.items,
            },
        });
    } catch (error: any) {
        logger.error('Failed to fetch prescription', { error: error.message, rxId: req.params.rxId });
        res.status(500).json({ error: 'Failed to fetch prescription', code: 'INTERNAL_ERROR' });
    }
});

// GET /api/prescriptions/check/:rxId — Check dispensed status
router.get('/check/:rxId', async (req: Request, res: Response) => {
    try {
        const { rxId } = req.params;
        const row = await queryOne<any>('SELECT status FROM shared_prescriptions WHERE rx_id = $1', [rxId]);
        if (!row) {
            res.json({ exists: false, dispensed: false });
            return;
        }
        res.json({ exists: true, dispensed: row.status === 'dispensed', status: row.status });
    } catch (error: any) {
        logger.error('Failed to check prescription status', { error: error.message });
        res.status(500).json({ error: 'Failed to check status', code: 'INTERNAL_ERROR' });
    }
});

// PATCH /api/prescriptions/:rxId/dispense — Mark as dispensed (Pharmacy side)
router.patch('/:rxId/dispense', requireAuth, async (req: Request, res: Response) => {
    try {
        const { rxId } = req.params;
        const { pharmacy_shop_id } = req.body;

        if (!pharmacy_shop_id) {
            res.status(400).json({ error: 'pharmacy_shop_id is required', code: 'VALIDATION_ERROR' });
            return;
        }

        const row = await queryOne<any>('SELECT status FROM shared_prescriptions WHERE rx_id = $1', [rxId]);
        if (!row) {
            res.status(404).json({ error: 'Prescription not found', code: 'NOT_FOUND' });
            return;
        }

        if (row.status === 'dispensed') {
            res.status(409).json({ error: 'Prescription has already been dispensed', code: 'ALREADY_DISPENSED' });
            return;
        }

        await query(
            `UPDATE shared_prescriptions SET status = 'dispensed', fulfilled_by = $1, fulfilled_at = NOW() WHERE rx_id = $2`,
            [pharmacy_shop_id, rxId]
        );

        logger.info('Prescription dispensed', { rx_id: rxId, pharmacy_shop_id });
        res.json({ success: true, message: 'Prescription marked as dispensed' });
    } catch (error: any) {
        logger.error('Failed to mark prescription as dispensed', { error: error.message });
        res.status(500).json({ error: 'Failed to update prescription', code: 'INTERNAL_ERROR' });
    }
});

export default router;
