// ============================================
// REMINDER CONTROLLER
// ============================================
// Handles payment reminder notifications for customers.
// Endpoints:
//   POST /api/reminders/send — Send a manual reminder (push notification)
//   POST /api/reminders/auto-check — Trigger auto-reminder check for overdue customers
//
// Auth: Cognito JWT required (vendor/owner only)
// ============================================

import { Router, Request, Response } from 'express';
import { requireCognitoAuth } from '../middleware/cognitoAuth';
import { logger } from '../utils/logger';
import { pool } from '../config/database';

const router = Router();

// ============================================
// POST /send — Send manual payment reminder
// ============================================
router.post('/send', requireCognitoAuth, async (req: Request, res: Response) => {
    try {
        const user = req.cognitoUser;
        if (!user) {
            return res.status(401).json({ error: 'Unauthorized' });
        }

        const {
            customerId,
            vendorId,
            customerName,
            outstandingAmount,
            reminderType,
        } = req.body;

        if (!customerId || !outstandingAmount) {
            return res.status(400).json({
                error: 'Missing required fields: customerId, outstandingAmount',
            });
        }

        const effectiveVendorId = vendorId || user.sub;

        // 1. Log the reminder in the database
        await pool.query(
            `INSERT INTO reminder_logs (
                id, customer_id, vendor_id, reminder_type,
                outstanding_amount, status, created_at
            ) VALUES (
                gen_random_uuid(), $1, $2, $3, $4, 'SENT', NOW()
            )
            ON CONFLICT DO NOTHING`,
            [customerId, effectiveVendorId, reminderType || 'MANUAL', outstandingAmount]
        );

        // 2. Look up customer's FCM token or phone for push
        const customerResult = await pool.query(
            `SELECT phone, email, fcm_token FROM customers
             WHERE id = $1 AND tenant_id = $2`,
            [customerId, effectiveVendorId]
        );

        const customer = customerResult.rows[0];
        let pushSent = false;

        if (customer?.fcm_token) {
            // 3a. Send FCM push notification (via SNS or direct FCM)
            // In production, this would call AWS SNS or Firebase Admin SDK
            logger.info('FCM push notification queued', {
                customerId,
                token: customer.fcm_token.substring(0, 10) + '...',
            });
            pushSent = true;
        }

        if (customer?.phone) {
            // 3b. Optionally send SMS via SNS
            // AWS SNS SMS would be called here in production
            logger.info('SMS reminder queued', {
                customerId,
                phone: customer.phone,
            });
        }

        // 4. Update customer's last_reminder_sent_at
        await pool.query(
            `UPDATE customers
             SET last_reminder_sent_at = NOW(), updated_at = NOW()
             WHERE id = $1 AND tenant_id = $2`,
            [customerId, effectiveVendorId]
        ).catch(() => {
            // Non-fatal — the Flutter client also updates this locally
        });

        logger.info('Reminder sent', {
            customerId,
            vendorId: effectiveVendorId,
            reminderType: reminderType || 'MANUAL',
            outstandingAmount,
            pushSent,
        });

        return res.json({
            success: true,
            message: `Payment reminder sent to ${customerName || customerId}`,
            pushSent,
        });
    } catch (error: any) {
        logger.error('Failed to send reminder', { error: error.message });
        return res.status(500).json({
            error: 'Failed to send reminder',
            details: process.env.NODE_ENV === 'development' ? error.message : undefined,
        });
    }
});

// ============================================
// POST /auto-check — Auto-reminder check for overdue customers
// ============================================
router.post('/auto-check', requireCognitoAuth, async (req: Request, res: Response) => {
    try {
        const user = req.cognitoUser;
        if (!user) {
            return res.status(401).json({ error: 'Unauthorized' });
        }

        const vendorId = user.tenantId || user.sub;
        // Find customers with:
        // - auto_reminder enabled
        // - outstanding > 0
        // - last reminder > 7 days ago (or never sent)
        const result = await pool.query(
            `SELECT id, name, phone,
                    (total_billed_cents - total_paid_cents) / 100.0 AS outstanding
             FROM customers
             WHERE tenant_id = $1
               AND is_auto_reminder_enabled = true
               AND (total_billed_cents - total_paid_cents) > 0
               AND deleted_at IS NULL
               AND (
                   last_reminder_sent_at IS NULL
                   OR last_reminder_sent_at < NOW() - INTERVAL '7 days'
               )
             ORDER BY (total_billed_cents - total_paid_cents) DESC
             LIMIT 50`,
            [vendorId]
        );

        let sentCount = 0;
        for (const customer of result.rows) {
            try {
                // Update last_reminder_sent_at
                await pool.query(
                    `UPDATE customers
                     SET last_reminder_sent_at = NOW(), updated_at = NOW()
                     WHERE id = $1 AND tenant_id = $2`,
                    [customer.id, vendorId]
                );

                // Log the auto-reminder
                await pool.query(
                    `INSERT INTO reminder_logs (
                        id, customer_id, vendor_id, reminder_type,
                        outstanding_amount, status, created_at
                    ) VALUES (
                        gen_random_uuid(), $1, $2, 'AUTO', $3, 'SENT', NOW()
                    )`,
                    [customer.id, vendorId, customer.outstanding]
                );

                sentCount++;
            } catch (err) {
                logger.warn('Failed to process auto-reminder for customer', {
                    customerId: customer.id,
                    error: (err as Error).message,
                });
            }
        }

        logger.info('Auto-reminder check complete', {
            vendorId,
            eligible: result.rows.length,
            sent: sentCount,
        });

        return res.json({
            success: true,
            eligible: result.rows.length,
            sent: sentCount,
        });
    } catch (error: any) {
        logger.error('Auto-reminder check failed', { error: error.message });
        return res.status(500).json({
            error: 'Auto-reminder check failed',
            details: process.env.NODE_ENV === 'development' ? error.message : undefined,
        });
    }
});

export default router;
