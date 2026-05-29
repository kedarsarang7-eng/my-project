export interface OrderItem {
    itemId?: string;
    name: string;
    quantity: number;
    unit?: string;
    unitPriceCents: number;
    discountCents?: number;
    taxCents?: number;
}

export interface OrderEventPayload {
    eventId: string;
    tenantId: string;
    customerId?: string;
    customerName?: string;
    customerPhone?: string;
    items: OrderItem[];
    discountCents?: number;
    paymentMode?: 'cash' | 'upi' | 'card' | 'bank_transfer' | 'cheque' | 'credit' | 'wallet';
    notes?: string;
    timestamp: string;
}

export const QUEUE_NAME_ORDERS = 'tenant-orders';
