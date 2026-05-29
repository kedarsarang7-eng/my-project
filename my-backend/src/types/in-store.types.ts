// ============================================================================
// TypeScript Types — In-Store Self Scan & Checkout
// ============================================================================

export enum InStoreSessionStatus {
    ACTIVE = 'ACTIVE',
    COMPLETED = 'COMPLETED',
    ABANDONED = 'ABANDONED',
    PAYMENT_FAILED = 'PAYMENT_FAILED',
}

export enum InStoreOrderType {
    IN_STORE_SCAN = 'IN_STORE_SCAN',
    ONLINE = 'ONLINE',
    POS = 'POS',
}

export enum GstSlab {
    ZERO = 0,
    FIVE = 5,
    TWELVE = 12,
    EIGHTEEN = 18,
    TWENTY_EIGHT = 28,
}

export interface CartItem {
    productId: string;
    barcode: string;
    name: string;
    brand?: string;
    imageUrl?: string;
    mrp: number;
    sellingPrice: number;
    discountPercent: number;
    gstSlab: number;
    unit: string;
    category?: string;
    quantity: number;
    lineTotalCents: number;
    gstAmountCents: number;
}

export interface GstBreakup {
    slab: number;
    taxableAmount: number;
    cgst: number;
    sgst: number;
    total: number;
}

export interface CartSummary {
    subtotalCents: number;
    discountCents: number;
    gstBreakup: GstBreakup[];
    totalGstCents: number;
    totalCents: number;
    itemCount: number;
}

export interface InStoreSession {
    PK: string;
    SK: string;
    sessionId: string;
    customerId: string;
    storeId: string;
    tenantId: string;
    status: InStoreSessionStatus;
    cartItems: CartItem[];
    startedAt: string;
    completedAt?: string;
    TTL: number;
    GSI1PK: string;
    GSI1SK: string;
    GSI2PK: string;
    GSI2SK: string;
}

export interface ExitQRPayload {
    orderId: string;
    sessionId: string;
    storeId: string;
    tenantId: string;
    totalItems: number;
    totalAmount: number;
    paidAt: string;
    expiresAt: string;
    signature: string;
}

export interface InStoreOrder {
    orderId: string;
    sessionId: string;
    customerId: string;
    tenantId: string;
    storeId: string;
    orderType: InStoreOrderType;
    cartItems: CartItem[];
    subtotalCents: number;
    discountCents: number;
    gstBreakup: GstBreakup[];
    totalGstCents: number;
    totalCents: number;
    status: 'PAYMENT_PENDING' | 'CONFIRMED' | 'CANCELLED';
    paymentOrderId?: string;
    paymentGateway?: string;
    exitQR?: {
        payload: string;
        signature: string;
        expiresAt: string;
        verified: boolean;
        verifiedAt?: string;
        verifiedBy?: string;
    };
    invoiceUrl?: string;
    createdAt: string;
    updatedAt: string;
}

/**
 * Business types that support Self Scan & Checkout.
 * Determined by: has barcoded packaged products + physical store.
 */
export const SELF_SCAN_ELIGIBLE_BUSINESS_TYPES = [
    'grocery',
    'pharmacy',
    'wholesale',
    'clothing',
    'book_store',
    'hardware',
    'auto_parts',
    'electronics',
    'mobile_shop',
    'computer_shop',
] as const;

export type SelfScanBusinessType = typeof SELF_SCAN_ELIGIBLE_BUSINESS_TYPES[number];
