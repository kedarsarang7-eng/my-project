// ============================================================================
// TypeScript Types — Payment Gateway Architecture
// ============================================================================
// Defines all types for the multi-tenant, gateway-agnostic payment system.
// ============================================================================

// ── Enums ───────────────────────────────────────────────────────────────────

export enum GatewayType {
    PHONEPE = 'phonepe',
    RAZORPAY = 'razorpay',
}

export enum GatewayConfigStatus {
    PENDING_VERIFICATION = 'pending_verification',
    ACTIVE = 'active',
    INACTIVE = 'inactive',
    FAILED = 'failed',
}

export enum PaymentOrderStatus {
    CREATED = 'created',
    QR_GENERATED = 'qr_generated',
    PENDING = 'pending',
    SUCCESS = 'success',
    FAILED = 'failed',
    EXPIRED = 'expired',
    REFUNDED = 'refunded',
}

// ── Gateway Credential Shapes (Decrypted) ───────────────────────────────────

export interface PhonePeCredentials {
    merchantId: string;
    saltKey: string;
    saltIndex: string;
    webhookSecret: string;
}

export interface RazorpayCredentials {
    keyId: string;
    keySecret: string;
    webhookSecret: string;
}

export type GatewayCredentials = PhonePeCredentials | RazorpayCredentials;

// ── Gateway Config (DB Row) ─────────────────────────────────────────────────

export interface TenantPaymentConfig {
    id: string;
    tenantId: string;
    gatewayType: GatewayType;
    status: GatewayConfigStatus;
    displayName?: string;
    isDefault: boolean;
    verifiedAt?: Date;
    createdAt: Date;
    updatedAt: Date;
}

// ── Create Order Request/Response ───────────────────────────────────────────

export interface CreateOrderRequest {
    orderId: string;               // Our internal payment_order ID
    invoiceId: string;
    amountCents: number;           // Amount in paise
    currency: string;              // 'INR'
    customerName?: string;
    customerPhone?: string;
    customerEmail?: string;
    callbackUrl: string;           // Webhook URL
    redirectUrl?: string;          // Post-payment redirect
    description?: string;
}

export interface CreateOrderResult {
    gatewayOrderId: string;        // PhonePe merchantTransactionId / Razorpay order_id
    qrPayload?: string;           // UPI intent URL or QR code data
    paymentUrl?: string;          // Redirect URL for web payment
    expiresAt?: Date;
    gatewayResponse: Record<string, unknown>;
}

// ── Webhook Verification ────────────────────────────────────────────────────

export interface WebhookVerificationResult {
    isValid: boolean;
    gatewayOrderId?: string;       // Extracted order ID from webhook
    gatewayTransactionId?: string; // Gateway's own transaction ID
    amountCents?: number;          // Amount from webhook (for validation)
    status?: PaymentOrderStatus;   // Mapped status
    rawPayload?: Record<string, unknown>;
    error?: string;
}

// ── Payment Order (DB Row) ──────────────────────────────────────────────────

export interface PaymentOrder {
    id: string;
    tenantId: string;
    invoiceId: string;
    configId: string;
    gatewayType: GatewayType;
    gatewayOrderId?: string;
    amountCents: number;
    currency: string;
    status: PaymentOrderStatus;
    qrPayload?: string;
    paymentUrl?: string;
    idempotencyKey: string;
    gatewayResponse: Record<string, unknown>;
    webhookReceivedAt?: Date;
    webhookVerified: boolean;
    gatewayTransactionId?: string;
    expiresAt?: Date;
    createdAt: Date;
    updatedAt: Date;
}

// ── Audit Log ───────────────────────────────────────────────────────────────

export type PaymentAuditEventType =
    | 'config_saved'
    | 'config_verified'
    | 'config_failed'
    | 'config_deleted'
    | 'order_created'
    | 'qr_generated'
    | 'webhook_received'
    | 'webhook_verified'
    | 'webhook_failed'
    | 'payment_success'
    | 'payment_failed'
    | 'payment_expired'
    | 'reconciliation_run'
    | 'amount_mismatch'
    | 'replay_blocked';

export interface PaymentAuditEntry {
    tenantId: string;
    paymentOrderId?: string;
    invoiceId?: string;
    eventType: PaymentAuditEventType;
    eventData: Record<string, unknown>;
    sourceIp?: string;
    userAgent?: string;
    userId?: string;
}
