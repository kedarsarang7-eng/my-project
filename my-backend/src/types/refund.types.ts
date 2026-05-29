// ============================================================================
// Refund Types
// ============================================================================

export interface RefundRecord {
    // Primary Keys
    PK: string; // REFUND#<refundId>
    SK: string; // META

    // GSI Keys
    GSI1PK: string; // BILL#<billId>
    GSI1SK: string; // REFUND#<timestamp>

    // Refund Details
    id: string;
    billId: string;
    businessId: string;
    paymentId: string;
    razorpayRefundId: string;
    razorpayPaymentId: string;

    // Financial
    amount: number; // In rupees
    currency: string; // INR
    status: 'Pending' | 'Completed' | 'Failed';

    // Metadata
    reason: string;
    notes?: string;
    processedBy: string; // User ID
    processedByName: string;

    // Timestamps
    createdAt: string;
    updatedAt: string;
}

export interface RefundRequest {
    billId: string;
    businessId: string;
    amount?: number; // Optional - full refund if not specified
    reason?: string;
    notes?: string;
}

export interface RefundResponse {
    success: boolean;
    refundId?: string;
    billId?: string;
    amount?: number;
    status?: string;
    razorpayRefundId?: string;
    remainingRefundable?: number;
    isFullyRefunded?: boolean;
    error?: string;
    message?: string;
}

export interface RefundWebhookPayload {
    entity: string;
    event: string;
    contains: string[];
    payload: {
        refund: {
            id: string;
            entity: string;
            amount: number;
            currency: string;
            payment_id: string;
            status: string;
            created_at: number;
            notes?: Record<string, string>;
        };
    };
}
