// ============================================================================
// Payment Gateway Interface — Strategy Pattern
// ============================================================================
// Abstract contract that all payment gateways must implement.
// This enables gateway-agnostic payment processing across the system.
// ============================================================================

import {
    GatewayCredentials,
    CreateOrderRequest,
    CreateOrderResult,
    WebhookVerificationResult,
    PaymentOrderStatus,
} from '../../types/payment.types';

/**
 * Abstract payment gateway interface.
 * Each gateway (PhonePe, Razorpay, future gateways) implements this contract.
 */
export interface PaymentGateway {
    /**
     * Create a payment order and generate a QR code / payment link.
     * @param credentials - Decrypted merchant credentials
     * @param request - Order details (amount, invoice, callback URL, etc.)
     * @returns Gateway order ID, QR payload, and payment URL
     */
    createOrder(
        credentials: GatewayCredentials,
        request: CreateOrderRequest
    ): Promise<CreateOrderResult>;

    /**
     * Verify webhook signature and extract payment details.
     * @param credentials - Decrypted merchant credentials (for HMAC verification)
     * @param headers - Raw HTTP headers from the webhook request
     * @param rawBody - Raw request body string (before JSON parsing)
     * @returns Verification result with extracted payment details
     */
    verifyWebhook(
        credentials: GatewayCredentials,
        headers: Record<string, string>,
        rawBody: string
    ): WebhookVerificationResult;

    /**
     * Poll the gateway for payment status (for reconciliation).
     * @param credentials - Decrypted merchant credentials
     * @param gatewayOrderId - The gateway's order ID
     * @returns Current payment status
     */
    getPaymentStatus(
        credentials: GatewayCredentials,
        gatewayOrderId: string
    ): Promise<PaymentOrderStatus>;

    /**
     * Validate merchant credentials by making a test API call.
     * Called during onboarding before activating the config.
     * @param credentials - Decrypted merchant credentials to validate
     * @returns true if credentials are valid
     */
    validateCredentials(credentials: GatewayCredentials): Promise<boolean>;
}
