// ============================================================================
// Zod Schemas — Payment Gateway Configuration & Orders
// ============================================================================

import { z } from 'zod';

// ── Gateway Type ────────────────────────────────────────────────────────────

export const gatewayTypeEnum = z.enum(['phonepe', 'razorpay']);

// ── PhonePe Credentials ─────────────────────────────────────────────────────

export const phonePeCredentialsSchema = z.object({
    gatewayType: z.literal('phonepe'),
    merchantId: z.string().min(1).max(100).trim(),
    saltKey: z.string().min(1).max(200).trim(),
    saltIndex: z.string().min(1).max(10).trim(),
    webhookSecret: z.string().max(200).trim().optional(),
    displayName: z.string().max(100).trim().optional(),
});

// ── Razorpay Credentials ────────────────────────────────────────────────────

export const razorpayCredentialsSchema = z.object({
    gatewayType: z.literal('razorpay'),
    keyId: z.string().min(1).max(100).trim(),
    keySecret: z.string().min(1).max(200).trim(),
    webhookSecret: z.string().min(1).max(200).trim(),
    displayName: z.string().max(100).trim().optional(),
});

// ── Discriminated Union — Save Gateway Config ───────────────────────────────

export const saveGatewayConfigSchema = z.discriminatedUnion('gatewayType', [
    phonePeCredentialsSchema,
    razorpayCredentialsSchema,
]);

// ── Verify Gateway Config ───────────────────────────────────────────────────

export const verifyGatewayConfigSchema = z.object({
    gatewayType: gatewayTypeEnum,
});

// ── Delete Gateway Config ───────────────────────────────────────────────────

export const deleteGatewayConfigSchema = z.object({
    gatewayType: gatewayTypeEnum,
});

// ── Initiate Payment (QR Generation) ────────────────────────────────────────

export const initiatePaymentOrderSchema = z.object({
    invoiceId: z.string().uuid(),
    gatewayType: gatewayTypeEnum.optional(), // Auto-selects if not provided
});

// ── Get Payment Order Status ────────────────────────────────────────────────

export const getPaymentOrderStatusSchema = z.object({
    orderId: z.string().uuid().optional(),
    invoiceId: z.string().uuid().optional(),
}).refine(
    (data) => !!data.orderId || !!data.invoiceId,
    { message: 'Either orderId or invoiceId is required' }
);

// ── Reconciliation ──────────────────────────────────────────────────────────

export const reconcileSchema = z.object({
    // No required fields — reconciles all pending orders for the tenant
    maxOrders: z.number().int().min(1).max(100).default(50),
});
