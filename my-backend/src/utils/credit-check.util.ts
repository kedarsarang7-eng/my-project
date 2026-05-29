// ============================================================================
// Shared Credit Limit Enforcement — Udhar Sales
// ============================================================================
// Reusable utility for checking credit limits before allowing credit (udhar)
// transactions. Used by pump.ts, staff-sale.ts, and invoice.service.ts.
//
// BUG-PP-008 FIX: Pump sales now enforce credit limits (previously bypassed).
// ============================================================================

import { Keys, getItem, queryAllItems } from '../config/dynamodb.config';
import { CreditLimitExceededError, NotFoundError } from './errors';
import { logger } from './logger';

/**
 * Enforce credit limit for an udhar (credit) transaction.
 *
 * 1. Fetches the customer record by ID
 * 2. Computes real-time outstanding from UDHARTXN# ledger entries
 * 3. Rejects if outstanding + newAmount > creditLimit
 *
 * @throws NotFoundError — if customer does not exist (prevents ghost debt)
 * @throws CreditLimitExceededError — if credit limit would be exceeded
 */
export async function enforceUdharCreditLimit(
    tenantId: string,
    customerId: string,
    newAmountCents: number,
): Promise<void> {
    const pk = Keys.tenantPK(tenantId);

    // 1. Fetch customer record
    const customer = await getItem<Record<string, any>>(pk, Keys.customerSK(customerId));

    if (!customer || customer.isDeleted) {
        throw new NotFoundError(`Customer ${customerId}`);
    }

    const creditLimitCents = Number(customer.creditLimitCents || 0);
    const creditMaxAgeDays = Number(customer.creditMaxAgeDays || 0);
    const creditMaxOpenBills = Number(customer.creditMaxOpenBills || 0);

    // If no credit limit is set, allow the transaction (unlimited credit)
    if (creditLimitCents <= 0) {
        logger.info('No credit limit set for customer — allowing udhar', {
            tenantId, customerId, newAmountCents,
        });
        return;
    }

    // 2. Compute real-time outstanding from UDHARTXN# ledger entries
    //    (Don't trust denormalized outstanding fields — they can be stale)
    let computedOutstandingCents = 0;

    try {
        const udharTxns = await queryAllItems<Record<string, any>>(pk, 'UDHARTXN#', {
            filterExpression: 'udharPersonId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':cid': customerId, ':false': false },
        });

        for (const txn of udharTxns) {
            const amt = Number(txn.amountCents || 0);
            if (txn.type === 'given') {
                computedOutstandingCents += amt;
            } else if (txn.type === 'received' || txn.type === 'collected') {
                computedOutstandingCents -= amt;
            }
        }

        // Never go below zero
        computedOutstandingCents = Math.max(computedOutstandingCents, 0);
    } catch (err) {
        // Fallback to denormalized fields if ledger query fails
        logger.warn('UDHARTXN ledger query failed — falling back to denormalized balance', {
            tenantId, customerId, error: (err as Error).message,
        });
        computedOutstandingCents = Math.max(
            Number(customer.outstandingCents ?? customer.outstandingBalanceCents ?? 0),
            0
        );
    }

    // 3. Check open bill count + maximum bill age policies (if configured)
    const invoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: 'customerId = :cid AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        expressionAttributeValues: { ':cid': customerId, ':false': false },
    });
    const openInvoices = invoices.filter((inv) => Number(inv.balanceCents || 0) > 0);

    if (creditMaxOpenBills > 0 && openInvoices.length >= creditMaxOpenBills) {
        throw new CreditLimitExceededError(
            `Credit blocked: open bill count ${openInvoices.length} reached configured limit ${creditMaxOpenBills}.`,
            {
                invoiceTotalCents: newAmountCents,
                availableCreditCents: Math.max(creditLimitCents - computedOutstandingCents, 0),
                creditLimitCents,
                outstandingBalanceCents: computedOutstandingCents,
            },
        );
    }

    if (creditMaxAgeDays > 0 && openInvoices.length > 0) {
        const nowMs = Date.now();
        const maxAgeMs = creditMaxAgeDays * 24 * 60 * 60 * 1000;
        const oldestOverdue = openInvoices.find((inv) => {
            const createdAt = new Date(inv.createdAt || inv.invoiceDate || 0).getTime();
            if (!createdAt || Number.isNaN(createdAt)) return false;
            return (nowMs - createdAt) > maxAgeMs;
        });

        if (oldestOverdue) {
            throw new CreditLimitExceededError(
                `Credit blocked: invoice ${oldestOverdue.invoiceNumber || oldestOverdue.id} exceeds max age ${creditMaxAgeDays} day(s).`,
                {
                    invoiceTotalCents: newAmountCents,
                    availableCreditCents: Math.max(creditLimitCents - computedOutstandingCents, 0),
                    creditLimitCents,
                    outstandingBalanceCents: computedOutstandingCents,
                },
            );
        }
    }

    // 4. Check amount limit
    const availableCreditCents = creditLimitCents - computedOutstandingCents;

    if (newAmountCents > availableCreditCents) {
        throw new CreditLimitExceededError(
            `Udhar sale ₹${(newAmountCents / 100).toFixed(2)} exceeds available credit ₹${(availableCreditCents / 100).toFixed(2)} ` +
            `(limit ₹${(creditLimitCents / 100).toFixed(2)}, outstanding ₹${(computedOutstandingCents / 100).toFixed(2)}).`,
            {
                invoiceTotalCents: newAmountCents,
                availableCreditCents,
                creditLimitCents,
                outstandingBalanceCents: computedOutstandingCents,
            },
        );
    }

    logger.info('Credit limit check passed', {
        tenantId, customerId, newAmountCents,
        creditLimitCents, computedOutstandingCents, availableCreditCents,
        creditMaxAgeDays, creditMaxOpenBills,
    });
}
