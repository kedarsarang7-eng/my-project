// ============================================================================
// Lambda Handlers — Loyalty Points API
// ============================================================================
// GET  /loyalty/{customerId}         — Get customer points balance
// POST /loyalty/earn                 — Award points (auto-called post-invoice)
// POST /loyalty/redeem               — Redeem points for discount
// GET  /loyalty/history/{customerId} — Point transaction history
//
// Access: All roles for lookup, Owner/Admin/Manager for earn/redeem
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as loyaltyService from '../services/loyalty.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { z } from 'zod';
import { parseBody } from '../middleware/validation';

const earnSchema = z.object({
    customerId: z.string().min(1),
    invoiceTotalCents: z.number().int().positive(),
    invoiceId: z.string().min(1),
    invoiceNumber: z.string().min(1),
});

const redeemSchema = z.object({
    customerId: z.string().min(1),
    points: z.number().int().positive(),
    invoiceId: z.string().optional(),
});

/**
 * GET /loyalty/{customerId}
 */
export const getBalance = authorizedHandler([], async (event, _context, auth) => {
    const customerId = event.pathParameters?.customerId;
    if (!customerId) return response.badRequest('Missing customerId');

    const balance = await loyaltyService.getBalance(auth.tenantId, customerId);
    if (!balance) {
        return response.success({
            customerId,
            totalPoints: 0,
            lifetimePoints: 0,
            redeemedPoints: 0,
            tier: 'bronze',
        });
    }

    return response.success(balance);
});

/**
 * POST /loyalty/earn
 */
export const earnPoints = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const parsed = parseBody(earnSchema, event);
        if (!parsed.success) return parsed.error;

        try {
            const result = await loyaltyService.earnPoints(
                auth.tenantId,
                parsed.data.customerId,
                parsed.data.invoiceTotalCents,
                parsed.data.invoiceId,
                parsed.data.invoiceNumber,
                auth.sub,
            );

            return response.success(result, 201);
        } catch (err) {
            if (err instanceof loyaltyService.LoyaltyError) {
                return response.error(err.statusCode, 'LOYALTY_ERROR', err.message);
            }
            throw err;
        }
    },
);

/**
 * POST /loyalty/redeem
 */
export const redeemPoints = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.CASHIER],
    async (event, _context, auth) => {
        const parsed = parseBody(redeemSchema, event);
        if (!parsed.success) return parsed.error;

        try {
            const result = await loyaltyService.redeemPoints(
                auth.tenantId,
                parsed.data.customerId,
                parsed.data.points,
                auth.sub,
                parsed.data.invoiceId,
            );

            return response.success(result);
        } catch (err) {
            if (err instanceof loyaltyService.LoyaltyError) {
                return response.error(err.statusCode, 'LOYALTY_ERROR', err.message);
            }
            throw err;
        }
    },
);

/**
 * GET /loyalty/history/{customerId}
 */
export const getHistory = authorizedHandler([], async (event, _context, auth) => {
    const customerId = event.pathParameters?.customerId;
    if (!customerId) return response.badRequest('Missing customerId');

    const limit = Math.min(
        parseInt(event.queryStringParameters?.limit || '50', 10) || 50,
        200,
    );

    const history = await loyaltyService.getHistory(auth.tenantId, customerId, limit);
    return response.success({ customerId, transactions: history });
});
