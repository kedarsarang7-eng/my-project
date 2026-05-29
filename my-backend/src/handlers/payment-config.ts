// ============================================================================
// Lambda Handler — Payment Config (Merchant Onboarding)
// ============================================================================
// Endpoints:
//   POST   /payment-config         — Save gateway credentials (KMS encrypted)
//   GET    /payment-config         — List gateway configs (status only, no secrets)
//   POST   /payment-config/verify  — Verify & activate gateway credentials
//   DELETE /payment-config/{gateway} — Remove gateway config
//
// SECURITY:
//   - Only Owner/Admin can manage payment configs
//   - Credentials are encrypted via KMS before storage
//   - Secrets are NEVER returned in API responses
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { GatewayType } from '../types/payment.types';
import { parseBody } from '../middleware/validation';
import {
    saveGatewayConfigSchema,
    verifyGatewayConfigSchema,
} from '../schemas/payment.schema';
import * as paymentConfigService from '../services/payment-config.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

/**
 * POST /payment-config
 * Save payment gateway credentials for the tenant.
 * Credentials are KMS-encrypted before storage.
 */
export const saveConfig = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const parsed = parseBody(saveGatewayConfigSchema, event);
        if (!parsed.success) return parsed.error;

        const data = parsed.data;
        const gatewayType = data.gatewayType as GatewayType;

        // Extract credentials (strip gatewayType and displayName)
        let credentials: Record<string, string>;
        if (gatewayType === GatewayType.PHONEPE) {
            credentials = {
                merchantId: (data as any).merchantId,
                saltKey: (data as any).saltKey,
                saltIndex: (data as any).saltIndex,
                webhookSecret: (data as any).webhookSecret || '',
            };
        } else {
            credentials = {
                keyId: (data as any).keyId,
                keySecret: (data as any).keySecret,
                webhookSecret: (data as any).webhookSecret,
            };
        }

        const result = await paymentConfigService.saveGatewayConfig(
            auth.tenantId,
            gatewayType,
            credentials as any,
            (data as any).displayName
        );

        logger.info('Payment config saved', {
            tenantId: auth.tenantId,
            gatewayType,
        });

        return response.success(result, 201);
    }
);

/**
 * GET /payment-config
 * List all gateway configs for the tenant (status & metadata only).
 * NEVER returns encrypted credentials.
 */
export const getConfigs = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, auth) => {
        const configs = await paymentConfigService.getGatewayConfigs(auth.tenantId);
        return response.success(configs);
    }
);

/**
 * POST /payment-config/verify
 * Verify gateway credentials by making a test API call to the gateway.
 * If successful, activates the config for payment processing.
 */
export const verifyConfig = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const parsed = parseBody(verifyGatewayConfigSchema, event);
        if (!parsed.success) return parsed.error;

        const { gatewayType } = parsed.data;

        const result = await paymentConfigService.verifyAndActivate(
            auth.tenantId,
            gatewayType as GatewayType
        );

        return response.success(result);
    }
);

/**
 * DELETE /payment-config/{gateway}
 * Soft-delete a gateway config.
 */
export const deleteConfig = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (event, _context, auth) => {
        const gateway = event.pathParameters?.gateway;
        if (!gateway) {
            return response.badRequest('Missing gateway type in path');
        }

        if (!['phonepe', 'razorpay'].includes(gateway)) {
            return response.badRequest('Invalid gateway type. Must be phonepe or razorpay');
        }

        await paymentConfigService.deleteGatewayConfig(
            auth.tenantId,
            gateway as GatewayType
        );

        return response.success({ message: 'Gateway config removed' });
    }
);
