// ============================================================================
// Order Worker — Serverless Replacement
// ============================================================================
// In the serverless architecture, BullMQ is replaced by SQS/EventBridge.
// This module provides backward-compatible exports while the queue system
// is migrated to AWS-native event processing.
// ============================================================================

import { createInvoice } from '../services/invoice.service';
import { logger } from '../utils/logger';

interface OrderEventPayload {
    eventId: string;
    tenantId: string;
    customerId?: string;
    customerName?: string;
    customerPhone?: string;
    paymentMode?: string;
    notes?: string;
    items: Array<{ itemId?: string; quantity: number; unitPriceCents: number }>;
}

/**
 * Process an order event (called from SQS Lambda trigger or direct invocation).
 */
export async function processOrderEvent(data: OrderEventPayload): Promise<void> {
    logger.info('Processing order event', { eventId: data.eventId, tenantId: data.tenantId });

    try {
        const invoiceItems = data.items
            .map((i: any) => ({ productId: i.itemId!, quantity: i.quantity, unitPrice: i.unitPriceCents }))
            .filter((i: any) => i.productId);

        if (invoiceItems.length > 0) {
            const invoice = await createInvoice(
                data.tenantId,
                data.customerId || 'system-async',
                {
                    items: invoiceItems,
                    customerName: data.customerName,
                    customerPhone: data.customerPhone,
                    paymentMode: data.paymentMode,
                    notes: `Async Order: ${data.notes || ''}`,
                }
            );
            logger.info('Order processed', { eventId: data.eventId, invoiceId: invoice.id });
        }
    } catch (err: any) {
        logger.error('Order processing failed', { eventId: data.eventId, error: err.message });
        throw err;
    }
}

/** @deprecated Use SQS Lambda trigger instead */
export function startOrderWorker(): void {
    logger.info('[OrderWorker] BullMQ worker disabled in serverless mode. Use SQS trigger.');
}
