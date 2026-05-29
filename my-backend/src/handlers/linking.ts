// ============================================================================
// Lambda Handler — Vendor-Customer Linking (QR Handshake)
// ============================================================================
// Endpoints:
//   POST   /linking/generate-token  — Vendor generates QR token
//   POST   /linking/link            — Customer links via scanned token
//   GET    /linking/my-vendors      — Customer gets linked vendors
//   GET    /linking/my-customers    — Vendor gets linked customers
//   DELETE /linking/{userId}        — Vendor revokes a customer link
//
// Uses Zod validation for token generation and linking.
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { parseBody } from '../middleware/validation';
import { generateLinkTokenSchema, linkSchema } from '../schemas';
import * as linkingService from '../services/linking.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /linking/generate-token
 * Vendor generates a signed token for QR code display.
 */
export const generateToken = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event, _context, auth) => {
        const parsed = parseBody(generateLinkTokenSchema, event);
        if (!parsed.success) return parsed.error;

        const token = await linkingService.generateToken(
            auth.tenantId,
            auth.sub,
            parsed.data.expiresInMinutes,
        );

        logger.info('Link token generated');

        return response.success(token, 201);
    }
);

/**
 * POST /linking/link
 * Customer scans QR and links to vendor.
 */
export const link = authorizedHandler([], async (event, _context, auth) => {
    try {
        const parsed = parseBody(linkSchema, event);
        if (!parsed.success) return parsed.error;

        const result = await linkingService.linkToVendor(
            parsed.data.token,
            auth.sub,
            auth.email
        );

        return response.success(result);
    } catch (err: unknown) {
        if (err instanceof linkingService.LinkingError) {
            return response.error(err.statusCode, 'LINKING_ERROR', err.message);
        }
        throw err;
    }
});

/**
 * GET /linking/my-vendors
 * Customer retrieves all vendors they are linked to.
 */
export const myVendors = authorizedHandler([], async (_event, _context, auth) => {
    const vendors = await linkingService.getMyVendors(auth.sub);
    return response.success(vendors);
});

/**
 * GET /linking/my-customers
 * Vendor retrieves all customers linked to their business.
 */
export const myCustomers = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (_event, _context, auth) => {
        const customers = await linkingService.getMyCustomers(auth.tenantId);
        return response.success(customers);
    }
);

/**
 * DELETE /linking/{userId}
 * Vendor revokes a customer's link.
 */
export const revokeLink = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const customerUserId = event.pathParameters?.userId;
        if (!customerUserId) {
            return response.badRequest('Missing userId path parameter');
        }

        const revoked = await linkingService.revokeCustomerLink(
            auth.tenantId,
            decodeURIComponent(customerUserId)
        );

        if (!revoked) {
            return response.notFound('Customer link');
        }

        return response.success({ message: 'Customer link revoked' });
    }
);
