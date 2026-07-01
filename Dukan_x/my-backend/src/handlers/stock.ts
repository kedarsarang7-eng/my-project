// ============================================================================
// Lambda Handler — Stock Management
// ============================================================================
// Endpoints:
//   POST /stock/lookup-barcode  — Lookup product by barcode
//   POST /stock/analyze-image   — Analyze product image (placeholder)
//   POST /stock/add             — Add new stock item
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as stockService from '../services/stock.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /stock/lookup-barcode
 * Lookup a product by barcode (local DB + external API fallback).
 */
export const lookupBarcode = authorizedHandler([], async (event, _context, auth) => {
    try {
        const body = JSON.parse(event.body || '{}');
        const { barcode } = body;

        if (!barcode || typeof barcode !== 'string') {
            return response.badRequest('Missing required field: barcode');
        }

        const result = await stockService.lookupBarcode(auth.tenantId, barcode.trim());
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
 * Note: Multipart upload is handled differently in Lambda — 
 * expects base64-encoded image in the body for simplicity.
 */
export const analyzeImage = authorizedHandler([], async (event, _context, auth) => {
    try {
        // For Lambda, we expect base64-encoded image in body
        const body = JSON.parse(event.body || '{}');
        const { image } = body; // base64 string

        if (!image) {
            return response.badRequest('Missing required field: image (base64)');
        }

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
            const body = JSON.parse(event.body || '{}');
            const { item_data } = body;

            if (!item_data || typeof item_data !== 'object') {
                return response.badRequest('Missing required field: item_data');
            }

            const result = await stockService.addStockItem(auth.tenantId, item_data);
            return response.success(result, 201);
        } catch (err: unknown) {
            if (err instanceof stockService.StockError) {
                return response.error(err.statusCode, 'STOCK_ERROR', err.message);
            }
            throw err;
        }
    }
);
