// ============================================================================
// Transaction Repository — DynamoDB Data Access Layer
// ============================================================================

import { BaseRepository, PaginationOpts, PaginatedResult } from './base.repository';
import { Keys, queryItems, getItem } from '../config/dynamodb.config';

export interface Transaction {
    id: string;
    tenantId: string;
    customerId?: string;
    invoiceNumber: string;
    customerName?: string;
    customerPhone?: string;
    subtotalCents: number;
    discountCents: number;
    taxCents: number;
    cgstCents: number;
    sgstCents: number;
    igstCents: number;
    roundOffCents: number;
    totalCents: number;
    paidCents: number;
    balanceCents: number;
    paymentMode: string;
    status: string;
    metadata: Record<string, unknown>;
    notes?: string;
    createdBy: string;
    isDeleted: boolean;
    createdAt: string;
    updatedAt: string;
}

export class TransactionRepository extends BaseRepository<Transaction> {
    constructor() {
        super('TRANSACTION', 'INVOICE#');
    }

    /**
     * List transactions with optional status filter.
     */
    async listFiltered(
        tenantId: string,
        opts: PaginationOpts & { status?: string },
    ): Promise<PaginatedResult<Transaction>> {
        return this.findAll(tenantId, opts, opts.status
            ? (item) => item.status === opts.status
            : undefined
        );
    }

    /**
     * Get a transaction with its line items.
     */
    async findWithItems(tenantId: string, id: string): Promise<(Transaction & { items: unknown[] }) | null> {
        const invoice = await this.findById(tenantId, id);
        if (!invoice) return null;

        const lineItems = await queryItems<Record<string, any>>(
            Keys.invoiceLineItemPK(id),
            'LINEITEM#',
        );

        return {
            ...invoice,
            items: lineItems.items.map(li => ({
                id: li.id,
                name: li.name,
                quantity: li.quantity,
                unit: li.unit,
                unitPriceCents: li.unitPriceCents,
                totalCents: li.totalCents,
            })),
        };
    }
}
