// ============================================================================
// Lambda Handler — Stock Management
// ============================================================================
// Endpoints:
//   POST /stock/lookup-barcode  — Lookup product by barcode
//   POST /stock/analyze-image   — Analyze product image (placeholder)
//   POST /stock/add             — Add new stock item
//
// Uses Zod validation for all input payloads.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { parseBody } from '../middleware/validation';
import { lookupBarcodeSchema, addStockSchema, analyzeImageSchema } from '../schemas';
import * as stockService from '../services/stock.service';
import * as response from '../utils/response';

/**
 * POST /stock/lookup-barcode
 * Lookup a product by barcode (local DB + external API fallback).
 * SEC-5.4: Per-tenant rate limited to prevent barcode enumeration attacks.
 */
export const lookupBarcode = authorizedHandler([], async (event, _context, auth) => {
    try {
        // SEC-5.4 AUDIT FIX: Per-tenant rate limiting on barcode lookup
        // Uses DynamoDB sliding window counter — 100 lookups/minute/tenant
        const rateLimitKey = `RATELIMIT#BARCODE#${auth.tenantId}`;
        const currentMinute = new Date().toISOString().slice(0, 16); // YYYY-MM-DDTHH:MM
        try {
            const { getItem: rlGetItem, updateItem: rlUpdateItem } = await import('../config/dynamodb.config');
            const rlRecord = await rlGetItem<Record<string, any>>(rateLimitKey, currentMinute);
            const currentCount = Number(rlRecord?.count) || 0;
            if (currentCount >= 100) {
                return response.error(429, 'RATE_LIMITED', 'Too many barcode lookups. Please wait 1 minute.');
            }
            // Increment counter (fire-and-forget, don't block the lookup)
            rlUpdateItem(rateLimitKey, currentMinute, {
                updateExpression: 'SET #c = if_not_exists(#c, :zero) + :one, #ttl = :ttl',
                expressionAttributeNames: { '#c': 'count', '#ttl': 'ttl' },
                expressionAttributeValues: {
                    ':zero': 0, ':one': 1,
                    ':ttl': Math.floor(Date.now() / 1000) + 120, // TTL: 2 minutes
                },
            }).catch(() => {}); // Non-blocking
        } catch { /* Rate limit check failed — allow request through */ }

        const parsed = parseBody(lookupBarcodeSchema, event);
        if (!parsed.success) return parsed.error;

        const result = await stockService.lookupBarcode(auth.tenantId, parsed.data.barcode.trim());
        return response.success(result);
    } catch (err: unknown) {
        if (err instanceof stockService.StockError) {
            return response.error(err.statusCode, 'STOCK_ERROR', err.message);
        }
        throw err;
    }
});

/**
 * POST /stock/analyze-image
 * Analyze a product image to extract name/category.
 * Expects base64-encoded image in the body.
 */
export const analyzeImage = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CASHIER],
    async (event, _context, auth) => {
    try {
        // SECURITY FIX S-7: Validate input with Zod schema (max ~7.5MB base64)
        const body = JSON.parse(event.body || '{}');
        const validated = analyzeImageSchema.parse(body);
        const { image } = validated;

        const imageBuffer = Buffer.from(image, 'base64');
        const result = await stockService.analyzeImage(auth.tenantId, imageBuffer);
        return response.success(result);
    } catch (err: unknown) {
        if (err instanceof stockService.StockError) {
            return response.error(err.statusCode, 'STOCK_ERROR', err.message);
        }
        throw err;
    }
});

/**
 * POST /stock/add
 * Add a new stock item to inventory.
 */
export const addStock = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        try {
            const parsed = parseBody(addStockSchema, event);
            if (!parsed.success) return parsed.error;

            const result = await stockService.addStockItem(auth.tenantId, parsed.data);
            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof stockService.StockError) {
                return response.error(err.statusCode, 'STOCK_ERROR', err.message);
            }
            throw err;
        }
    }
);
