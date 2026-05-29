// ============================================================================
// Lambda Handler — Petrol Pump (DynamoDB)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryItems, queryAllItems, putItem, updateItem, getItem, transactWrite, TABLE_NAME } from '../config/dynamodb.config';
import { getCached, invalidateCache } from '../utils/cache';
import { parseBody } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import * as schemas from '../schemas/mobile.schema';
import { normalizeVehicleNumber } from '../utils/vehicle.util';
import * as response from '../utils/response';
import { PriceValidationError, CreditLimitExceededError, NotFoundError, ValidationError } from '../utils/errors';
import { enforceUdharCreditLimit } from '../utils/credit-check.util';
import { logger } from '../utils/logger';
import { logAudit } from '../middleware/audit';
import { recordRevision } from '../services/revision-history.service';
import crypto from 'crypto';
import * as wsService from '../services/websocket.service';
import { WSEventName } from '../types/websocket.types';
// UNS event_bus — task 14.9 migration of T-PMP-1..5 producers
import { emitUnsEvent } from '../notifications/event-bus';

const PUMP_OPTS = { requiredBusinessType: BusinessType.PETROL_PUMP, requiredFeature: FeatureKey.PETROL_BASIC_SHIFT_ENTRY };
const PUMP_FLOOR_ROLES = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.PUMPBOY];

async function resolveEffectiveFuelRateSnapshot(
    pk: string,
    fuelType: string,
    saleTimestamp: string,
): Promise<{ rateLogId: string | null; effectiveFrom: string | null; source: 'price_log' | 'product_fallback' }> {
    const logs = await queryItems<Record<string, any>>(pk, `FUELPRICELOG#${fuelType}#`, {
        scanIndexForward: false,
        limit: 200,
    });
    const matched = logs.items.find((log) => {
        const effectiveFrom = String(log.effectiveFrom || '');
        return !!effectiveFrom && effectiveFrom <= saleTimestamp;
    });
    if (matched) {
        return {
            rateLogId: String(matched.id || ''),
            effectiveFrom: String(matched.effectiveFrom || ''),
            source: 'price_log',
        };
    }
    return { rateLogId: null, effectiveFrom: null, source: 'product_fallback' };
}

async function generatePumpInvoiceNumber(
    pk: string,
    nowIso: string,
): Promise<{ invoiceNumber: string; counterSk: string; currentCounter: number; nextCounter: number }> {
    const yyyymm = nowIso.substring(0, 7).replace('-', '');
    const counterSk = `COUNTER#PUMP_INVOICE#${yyyymm}`;
    const current = await getItem<Record<string, any>>(pk, counterSk);
    const currentCounter = Number(current?.counterValue || 0);
    const nextCounter = currentCounter + 1;
    const invoiceNumber = `PUMP-${yyyymm}-${nextCounter.toString().padStart(6, '0')}`;
    return { invoiceNumber, counterSk, currentCounter, nextCounter };
}

/**
 * GET /pump/nozzles — Nozzles assigned to logged-in staff today
 */
export const getMyNozzles = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const todayStr = new Date().toISOString().slice(0, 10);

    // Get staff nozzle assignments
    const assignments = await queryItems<Record<string, any>>(pk, 'STAFFNOZZLEASSIGN#', {
        filterExpression: 'staffId = :staffId AND assignmentDate = :today',
        expressionAttributeValues: { ':staffId': auth.sub, ':today': todayStr },
    });

    // Enrich with nozzle + dispenser info
    const result = await Promise.all(assignments.items.map(async a => {
        const nozzle = await getItem<Record<string, any>>(pk, `NOZZLE#${a.nozzleId}`);
        const dispenser = nozzle?.dispenserId ? await getItem<Record<string, any>>(pk, `DISPENSER#${nozzle.dispenserId}`) : null;
        return {
            id: nozzle?.id, dispenserId: nozzle?.dispenserId, name: nozzle?.name,
            fuelType: nozzle?.fuelType, currentMeterReading: nozzle?.currentMeterReading,
            dispenserName: dispenser?.name,
        };
    }));

    return response.success(result.filter(Boolean));
}, PUMP_OPTS);

/**
 * POST /pump/readings — Record opening/closing meters
 */
export const recordReadings = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.pumpReadingSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        for (const reading of body.readings) {
            // ============================================================
            // PP-007 FIX: Validate closing reading >= previous reading
            // Prevents negative dispensation (catches meter tampering)
            // ============================================================
            if (reading.readingType === 'closing') {
                const nozzle = await getItem<Record<string, any>>(pk, `NOZZLE#${reading.nozzleId}`);
                const lastReading = nozzle?.currentMeterReading;

                if (lastReading !== undefined && lastReading !== null && reading.readingValue < lastReading) {
                    throw new ValidationError(
                        `Closing reading (${reading.readingValue}) must be >= previous reading (${lastReading}) for nozzle ${reading.nozzleId}.`,
                        { nozzleId: reading.nozzleId, closingReading: reading.readingValue, previousReading: lastReading },
                    );
                }
            }

            const readingId = crypto.randomUUID();
            await putItem({
                PK: pk, SK: `NOZZLEREADING#${readingId}`,
                entityType: 'NOZZLE_READING', tenantId: auth.tenantId,
                nozzleId: reading.nozzleId, dispenserId: reading.dispenserId,
                tankId: reading.tankId, recordedBy: auth.sub,
                readingType: reading.readingType, readingValue: reading.readingValue,
                testingAmount: reading.testingAmount || 0,
                notes: reading.notes || null, shiftId: body.shiftId,
                readingDate: now.substring(0, 10),
                createdAt: now,
            });
            await recordRevision(
                auth.tenantId,
                'nozzle_readings',
                readingId,
                'create',
                auth.sub,
                null,
                {
                    id: readingId,
                    nozzleId: reading.nozzleId,
                    tankId: reading.tankId,
                    readingType: reading.readingType,
                    readingValue: reading.readingValue,
                    shiftId: body.shiftId,
                    readingDate: now.substring(0, 10),
                },
                { source: 'pump.recordReadings' },
            );

            if (reading.readingType === 'closing') {
                await updateItem(pk, `NOZZLE#${reading.nozzleId}`, {
                    updateExpression: 'SET currentMeterReading = :val, updatedAt = :now',
                    conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(currentMeterReading) OR currentMeterReading = :expected)',
                    expressionAttributeValues: {
                        ':val': reading.readingValue,
                        ':now': now,
                        ':expected': Number((await getItem<Record<string, any>>(pk, `NOZZLE#${reading.nozzleId}`))?.currentMeterReading ?? 0),
                    },
                });
            }
        }

        wsService.emitEvent(auth.tenantId, WSEventName.STAFF_ACTIVITY, {
            action: 'readings_recorded', staffId: auth.sub,
            readingCount: body.readings.length, shiftId: body.shiftId,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        return response.success({ message: `${body.readings.length} readings recorded successfully` }, 201);
    } catch (err) {
        // PP-007 FIX: surface domain errors with proper HTTP codes instead of generic 500.
        if (err instanceof ValidationError) {
            return response.error(400, 'VALIDATION_ERROR', err.message);
        }
        logger.error('Failed to record pump readings', { error: err });
        return response.internalError('Failed to record readings');
    }
}, PUMP_OPTS);

/**
 * POST /pump/sales — Fuel sale at nozzle
 * BUG-PP-003 FIX: Server-side price validation (fetches canonical price from product master)
 * BUG-PP-008 FIX: Credit limit enforcement for udhar sales
 * Refactored to single atomic transactWrite.
 */
export const recordPumpSale = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.pumpSaleSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const tableName = TABLE_NAME;

    // PP-009 FIX: Normalize vehicle number for consistent storage & querying
    const vehicleNumber = body.vehicleNumber ? normalizeVehicleNumber(body.vehicleNumber) : null;

    // ================================================================
    // BUG-PP-003: Server-side price validation
    // PERF-12 FIX: Cache product-by-fuelType lookup — avoids full PRODUCT# scan
    // on every fuel sale. Cache TTL 60s (price changes are infrequent).
    // ================================================================
    const PRICE_TOLERANCE_CENTS = 100; // ±₹1 tolerance for rounding

    const fuelProduct = await getCached<Record<string, any> | null>(
        `fuel-product:${auth.tenantId}:${body.fuelType}`,
        60, // 60s TTL — fuel prices change daily at most
        async () => {
            const products = await queryItems<Record<string, any>>(pk, 'PRODUCT#', {
                filterExpression: 'productType = :pt AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':pt': body.fuelType, ':false': false },
                limit: 1,
            });
            return products.items.length > 0 ? products.items[0] : null;
        },
    );

    let canonicalPriceCents: number | null = null;
    let productId: string | null = null;

    if (fuelProduct) {
        canonicalPriceCents = Number(fuelProduct.salePriceCents || 0);
        productId = fuelProduct.id || fuelProduct.SK?.replace('PRODUCT#', '');

        if (canonicalPriceCents > 0) {
            const expectedTotalCents = Math.round(body.volumeLiters * canonicalPriceCents);

            if (Math.abs(body.totalAmountCents - expectedTotalCents) > PRICE_TOLERANCE_CENTS) {
                throw new PriceValidationError(
                    `Price mismatch: expected ₹${(expectedTotalCents / 100).toFixed(2)} ` +
                    `(${body.volumeLiters}L × ₹${(canonicalPriceCents / 100).toFixed(2)}/L), ` +
                    `received ₹${(body.totalAmountCents / 100).toFixed(2)}.`,
                    {
                        expectedCents: expectedTotalCents,
                        receivedCents: body.totalAmountCents,
                        toleranceCents: PRICE_TOLERANCE_CENTS,
                    },
                );
            }
        } else {
            logger.warn('Product has no salePriceCents — price validation skipped', {
                tenantId: auth.tenantId, fuelType: body.fuelType, productId,
            });
        }
    } else {
        logger.warn('No product found for fuel type — price validation skipped', {
            tenantId: auth.tenantId, fuelType: body.fuelType,
        });
    }

    // ================================================================
    // BUG-PP-008: Credit limit check for udhar sales
    // ================================================================
    if (body.paymentMode === 'udhar') {
        await enforceUdharCreditLimit(auth.tenantId, body.customerId, body.totalAmountCents);
    }
    const rateSnapshot = await resolveEffectiveFuelRateSnapshot(pk, body.fuelType, now);

    // ================================================================
    // Atomic transaction: invoice + line item + udhar entry + stock deduction
    // ================================================================
    try {
        let attempts = 0;
        while (attempts < 5) {
            attempts++;
            const txnId = crypto.randomUUID();
            const { invoiceNumber, counterSk, currentCounter, nextCounter } = await generatePumpInvoiceNumber(pk, now);
            const transactItems: any[] = [];

            transactItems.push(currentCounter === 0
                ? {
                    Put: {
                        TableName: tableName,
                        Item: {
                            PK: pk,
                            SK: counterSk,
                            entityType: 'COUNTER',
                            counterType: 'PUMP_INVOICE',
                            counterValue: nextCounter,
                            createdAt: now,
                            updatedAt: now,
                        },
                        ConditionExpression: 'attribute_not_exists(PK)',
                    },
                }
                : {
                    Update: {
                        TableName: tableName,
                        Key: { PK: pk, SK: counterSk },
                        UpdateExpression: 'SET counterValue = :next, updatedAt = :now',
                        ConditionExpression: 'counterValue = :current',
                        ExpressionAttributeValues: {
                            ':next': nextCounter,
                            ':current': currentCounter,
                            ':now': now,
                        },
                    },
                });

            // 1. Invoice record
            // Tag with shiftId / fuelType / volumeLiters so downstream
            // shift close, dashboard, and reports can compute totals + variance.
            transactItems.push({
                Put: {
                    TableName: tableName,
                    Item: {
                        PK: pk, SK: Keys.invoiceSK(txnId),
                        entityType: 'INVOICE', id: txnId, tenantId: auth.tenantId,
                        invoiceNumber, type: 'sale', status: 'completed',
                        totalCents: body.totalAmountCents,
                        paidCents: body.paymentMode === 'udhar' ? 0 : body.totalAmountCents,
                        balanceCents: body.paymentMode === 'udhar' ? body.totalAmountCents : 0,
                        paymentMode: body.paymentMode,
                        paymentReference: (body as any).paymentReference || null,
                        customerId: body.customerId || null,
                        nozzleId: body.nozzleId,
                        shiftId: body.shiftId,
                        fuelType: body.fuelType,
                        productType: body.fuelType,
                        productId: productId || null,
                        fuelRateLogId: rateSnapshot.rateLogId,
                        fuelRateEffectiveFrom: rateSnapshot.effectiveFrom,
                        fuelRateSnapshotSource: rateSnapshot.source,
                        volumeLiters: body.volumeLiters,
                        pricePerLiterCents: body.pricePerLiterCents,
                        vehicleNumber: vehicleNumber || null,
                        saleDate: now.substring(0, 10),
                        metadata: { source: 'pump_sale' },
                        createdBy: auth.sub, isDeleted: false, createdAt: now, updatedAt: now,
                    },
                },
            });

        // 2. Line item
        transactItems.push({
            Put: {
                TableName: tableName,
                Item: {
                    PK: Keys.invoiceLineItemPK(txnId), SK: Keys.lineItemSK(crypto.randomUUID()),
                    entityType: 'LINEITEM', tenantId: auth.tenantId, transactionId: txnId,
                    name: `${body.fuelType.toUpperCase()} Sale (${vehicleNumber || 'Walk-in'})`,
                    quantity: body.volumeLiters, unitPriceCents: body.pricePerLiterCents,
                    totalCents: body.totalAmountCents, createdAt: now,
                },
            },
        });

        // 3. Udhar ledger entry + customer outstanding aggregate
        if (body.paymentMode === 'udhar') {
            transactItems.push({
                Put: {
                    TableName: tableName,
                    Item: {
                        PK: pk, SK: `UDHARTXN#${crypto.randomUUID()}`,
                        entityType: 'UDHAR_TXN', tenantId: auth.tenantId,
                        udharPersonId: body.customerId, type: 'given',
                        amountCents: body.totalAmountCents, transactionDate: now,
                        notes: `Fuel Sale - ${body.vehicleNumber || 'Nozzle ' + body.nozzleId}`,
                        relatedTransactionId: txnId, isDeleted: false, createdAt: now,
                    },
                },
            });
            transactItems.push({
                Update: {
                    TableName: tableName,
                    Key: { PK: pk, SK: Keys.customerSK(body.customerId) },
                    UpdateExpression:
                        'SET outstandingCents = if_not_exists(outstandingCents, :zero) + :amt, ' +
                        'outstandingBalanceCents = if_not_exists(outstandingBalanceCents, :zero) + :amt, ' +
                        'totalBilledCents = if_not_exists(totalBilledCents, :zero) + :amt, ' +
                        'lastBilledAt = :now, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK)',
                    ExpressionAttributeValues: {
                        ':amt': body.totalAmountCents,
                        ':now': now,
                        ':zero': 0,
                    },
                },
            });
        }

        // 4. Tank stock deduction (if product found)
        if (productId) {
            transactItems.push({
                Update: {
                    TableName: tableName,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK) AND currentStock >= :qty',
                    ExpressionAttributeValues: { ':qty': body.volumeLiters, ':now': now },
                },
            });
        }

            // Execute atomic transaction
            try {
                await transactWrite(transactItems);
            } catch (err: any) {
                if (err.name === 'TransactionCanceledException') {
                    if (attempts < 5) continue; // counter race retry
                    logger.warn('Pump sale transaction failed — possibly insufficient tank stock', {
                        txnId, productId, volumeLiters: body.volumeLiters,
                    });
                    return response.error(409, 'STOCK_INSUFFICIENT', 'Insufficient tank stock for this sale');
                }
                throw err;
            }
            await recordRevision(
                auth.tenantId,
                'transactions',
                txnId,
                'create',
                auth.sub,
                null,
                {
                    id: txnId,
                    invoiceNumber,
                    type: 'sale',
                    paymentMode: body.paymentMode,
                    customerId: body.customerId || null,
                    fuelType: body.fuelType,
                    shiftId: body.shiftId,
                    fuelRateLogId: rateSnapshot.rateLogId,
                    fuelRateEffectiveFrom: rateSnapshot.effectiveFrom,
                    volumeLiters: body.volumeLiters,
                    totalCents: body.totalAmountCents,
                    createdAt: now,
                },
                { source: 'pump.recordPumpSale' },
            );

        // Broadcast events (fire-and-forget)
        const saleEvent = body.fuelType === 'diesel' ? WSEventName.DIESEL_SALE_UPDATE : WSEventName.PETROL_SALE_UPDATE;
        wsService.emitEvent(auth.tenantId, saleEvent, {
            transactionId: txnId, invoiceNumber, fuelType: body.fuelType,
            volumeLiters: body.volumeLiters, totalAmountCents: body.totalAmountCents,
            staffId: auth.sub, vehicleNumber: body.vehicleNumber,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        wsService.emitEvent(auth.tenantId, WSEventName.STAFF_ACTIVITY, {
            action: 'pump_sale', staffId: auth.sub, fuelType: body.fuelType,
            totalAmountCents: body.totalAmountCents,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-PMP-1: reports.pump_sale.recorded)
        emitUnsEvent({
            eventName: 'reports.pump_sale.recorded',
            category: 'reports',
            subCategory: 'pump_sale',
            priority: 'low',
            actorId: auth.sub,
            targetId: txnId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                transactionId: txnId,
                invoiceNumber,
                fuelType: body.fuelType,
                volumeLiters: body.volumeLiters,
                totalAmountCents: body.totalAmountCents,
                staffId: auth.sub,
                vehicleNumber: body.vehicleNumber,
            },
            sourceModule: 'my-backend/src/handlers/pump.ts',
            dedupScopeFields: ['transactionId'],
        }).catch(() => { /* non-fatal during migration window */ });

        // UNS canonical emit (T-PMP-2: users.pump_staff_activity.recorded — sale by staff)
        emitUnsEvent({
            eventName: 'users.pump_staff_activity.recorded',
            category: 'users',
            subCategory: 'pump_staff_activity',
            priority: 'low',
            actorId: auth.sub,
            targetId: txnId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                action: 'pump_sale',
                staffId: auth.sub,
                fuelType: body.fuelType,
                totalAmountCents: body.totalAmountCents,
            },
            sourceModule: 'my-backend/src/handlers/pump.ts',
            dedupScopeFields: ['transactionId'],
        }).catch(() => { /* non-fatal during migration window */ });

            return response.success({ transactionId: txnId, invoiceNumber }, 201);
        }
        return response.error(409, 'INVOICE_COUNTER_RACE', 'Could not allocate sequential invoice number. Retry.');
    } catch (err) {
        // Re-throw domain errors for proper HTTP responses
        if (err instanceof PriceValidationError || err instanceof CreditLimitExceededError || err instanceof NotFoundError) {
            throw err;
        }
        logger.error('Failed to record pump sale', { error: err });
        return response.internalError('Failed to record sale');
    }
}, PUMP_OPTS);

/**
 * POST /pump/cash-drop — Driver cash turn-in
 * PP-001/PP-005 FIX: Now computes expectedAmount from shift cash sales.
 */
export const recordCashDrop = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.cashDropSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        // ================================================================
        // PP-001/PP-005 FIX: Compute expected cash from shift sales
        // Query all STAFFSALE# + INVOICE# (pump sales) for this staff
        // where paymentMode=cash and shiftId matches
        // ================================================================
        let expectedAmountCents = 0;

        // 1. Staff sales (cash only)
        const staffSales = await queryAllItems<Record<string, any>>(pk, 'STAFFSALE#', {
            filterExpression: 'staffId = :staffId AND paymentMode = :cash AND shiftId = :shiftId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':staffId': auth.sub,
                ':cash': 'cash',
                ':false': false,
                ':shiftId': body.shiftId,
            },
        });

        for (const sale of staffSales) {
            expectedAmountCents += Number(sale.amountCents || 0);
        }

        // 2. Pump nozzle sales (cash only, created by this staff)
        const pumpInvoices = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
            filterExpression: 'createdBy = :staffId AND shiftId = :shiftId AND paymentMode = :cash AND begins_with(SK, :inv) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: {
                ':staffId': auth.sub,
                ':cash': 'cash',
                ':inv': 'INVOICE#',
                ':false': false,
                ':shiftId': body.shiftId,
            },
        });

        for (const inv of pumpInvoices) {
            // Avoid double counting — only pump invoices (not staff sale linked)
            if (!inv.metadata?.source || inv.metadata?.source !== 'staff_sale') {
                expectedAmountCents += Number(inv.totalCents || 0);
            }
        }

        const differenceAmountCents = body.amountCents - expectedAmountCents;

        const settlementId = crypto.randomUUID();
        await putItem({
            PK: pk, SK: `CASHSETTLEMENT#${settlementId}`,
            entityType: 'CASH_SETTLEMENT', tenantId: auth.tenantId,
            staffId: auth.sub, shiftId: body.shiftId,
            expectedAmount: expectedAmountCents,
            actualAmount: body.amountCents,
            declaredDenominations: body.denominations || {},
            differenceAmount: differenceAmountCents,
            status: Math.abs(differenceAmountCents) <= 100 ? 'approved' : 'pending', // Auto-approve if within ±₹1
            submittedAt: now, notes: body.notes || null,
            createdAt: now, updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'cash_settlements',
            settlementId,
            'create',
            auth.sub,
            null,
            {
                id: settlementId,
                staffId: auth.sub,
                shiftId: body.shiftId,
                expectedAmountCents,
                actualAmountCents: body.amountCents,
                differenceAmountCents,
                createdAt: now,
            },
            { source: 'pump.recordCashDrop' },
        );

        wsService.emitEvent(auth.tenantId, WSEventName.STAFF_ACTIVITY, {
            action: 'cash_drop', staffId: auth.sub,
            amountCents: body.amountCents, expectedAmountCents,
            differenceAmountCents, shiftId: body.shiftId,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-PMP-3: payment.cash_drop.recorded)
        emitUnsEvent({
            eventName: 'payment.cash_drop.recorded',
            category: 'payments',
            subCategory: 'cash_drop',
            priority: 'normal',
            actorId: auth.sub,
            targetId: body.shiftId ?? null,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                shiftId: body.shiftId,
                staffId: auth.sub,
                amountCents: body.amountCents,
                expectedAmountCents,
                differenceAmountCents,
            },
            sourceModule: 'my-backend/src/handlers/pump.ts',
            dedupScopeFields: ['shiftId', 'amountCents'],
        }).catch(() => { /* non-fatal during migration window */ });

        logger.info('Cash drop recorded', {
            tenantId: auth.tenantId, staffId: auth.sub,
            actual: body.amountCents, expected: expectedAmountCents,
            difference: differenceAmountCents,
        });

        return response.success({
            message: 'Cash drop submitted for manager review',
            expectedAmountCents,
            actualAmountCents: body.amountCents,
            differenceAmountCents,
        }, 201);
    } catch (err) {
        logger.error('Failed to submit cash drop', { error: err });
        return response.internalError('Failed to submit cash drop');
    }
}, PUMP_OPTS);

// ==========================================================================
// SHIFT LIFECYCLE — PP-004 FIX
// ==========================================================================

/**
 * POST /pump/shift/open — Open a new shift for the logged-in staff member.
 * PP-004 FIX: Creates a real SHIFT# entity that the dashboard queries.
 */
export const openShift = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.shiftOpenSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();
    const shiftId = crypto.randomUUID();
    const shiftDate = now.substring(0, 10);

    try {
        // Station-wide non-overlap: only one open shift per tenant at a time.
        const existing = await queryItems<Record<string, any>>(pk, 'SHIFT#', {
            filterExpression: 'shiftStatus = :open AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':open': 'open', ':false': false },
            limit: 1,
        });

        if (existing.items.length > 0) {
            if (existing.items[0].staffId !== auth.sub) {
                return response.error(409, 'STATION_SHIFT_ALREADY_OPEN',
                    `Station already has active shift (${existing.items[0].id}) opened by another staff member.`);
            }
            return response.error(409, 'SHIFT_ALREADY_OPEN',
                `Staff already has an active shift (${existing.items[0].id}). Close it before opening a new one.`);
        }

        // Look up staff name
        const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
        const staffName = user?.fullName || user?.name || auth.email || '';

        // Capture opening meter readings from client-supplied assignments
        const nozzleSnapshots: any[] = [];
        const nozzleIds: string[] = [];
        for (const assignment of body.nozzleAssignments) {
            const nozzle = await getItem<Record<string, any>>(pk, `NOZZLE#${assignment.nozzleId}`);
            nozzleIds.push(assignment.nozzleId);
            nozzleSnapshots.push({
                nozzleId: assignment.nozzleId,
                nozzleName: nozzle?.name || assignment.nozzleId,
                fuelType: nozzle?.fuelType || 'unknown',
                openingReading: assignment.openingReading,
                closingReading: null, // Filled at shift close
            });
        }

        await putItem({
            PK: pk, SK: `SHIFT#${shiftId}`,
            entityType: 'SHIFT', id: shiftId, tenantId: auth.tenantId,
            staffId: auth.sub, staffName,
            shiftDate, shiftLabel: body.shiftLabel || 'Custom',
            shiftStatus: 'open',
            openedAt: now, closedAt: null,
            nozzleIds,
            nozzleSnapshots,
            totalSalesCents: 0, totalCashCents: 0, totalUpiCents: 0, totalUdharCents: 0,
            totalVolumeLiters: 0, saleCount: 0,
            notes: body.notes || null,
            isDeleted: false, createdAt: now, updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'shifts',
            shiftId,
            'create',
            auth.sub,
            null,
            {
                id: shiftId,
                staffId: auth.sub,
                shiftDate,
                shiftStatus: 'open',
                openedAt: now,
                nozzleIds,
            },
            { source: 'pump.openShift' },
        );

        // Audit log
        logAudit({
            action: 'SHIFT_OPENED',
            resource: 'shift',
            resourceId: shiftId,
            metadata: { staffId: auth.sub, staffName, shiftLabel: body.shiftLabel, nozzleIds },
        }).catch(() => { });

        wsService.emitEvent(auth.tenantId, WSEventName.SHIFT_OPENED, {
            shiftId, staffId: auth.sub, staffName,
            shiftLabel: body.shiftLabel, openedAt: now,
            nozzleIds,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-PMP-4: users.pump_shift.opened)
        emitUnsEvent({
            eventName: 'users.pump_shift.opened',
            category: 'users',
            subCategory: 'pump_shift',
            priority: 'normal',
            actorId: auth.sub,
            targetId: shiftId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                shiftId,
                staffId: auth.sub,
                staffName,
                shiftLabel: body.shiftLabel,
                openedAt: now,
                nozzleIds,
            },
            sourceModule: 'my-backend/src/handlers/pump.ts',
            dedupScopeFields: ['shiftId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({
            shiftId,
            staffName,
            openedAt: now,
            nozzleSnapshots,
            message: 'Shift opened successfully',
        }, 201);
    } catch (err) {
        logger.error('Failed to open shift', { error: err });
        return response.internalError('Failed to open shift');
    }
}, PUMP_OPTS);

/**
 * POST /pump/shift/close — Close an active shift. Computes sales summary,
 * expected cash collection, and nozzle meter reconciliation.
 * PP-004/PP-006 FIX: Creates comprehensive shift close summary with meter-vs-sales reconciliation.
 */
export const closeShift = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.shiftCloseSchema, event);
    if (!valid.success) return valid.error;

    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    try {
        // 1. Fetch and validate the shift
        const shift = await getItem<Record<string, any>>(pk, `SHIFT#${body.shiftId}`);

        if (!shift || shift.isDeleted) {
            return response.notFound('Shift');
        }
        if (shift.shiftStatus !== 'open') {
            return response.error(409, 'SHIFT_NOT_OPEN', 'This shift is already closed.');
        }
        if (shift.staffId !== auth.sub) {
            return response.forbidden('You can only close your own shift');
        }

        // 2. Compute sales summary from BOTH staff sales (STAFFSALE#) and pump
        //    nozzle sales (INVOICE# rows tagged with this shiftId).
        //    PP-CLOSE FIX: previous logic excluded pump invoices, missed volume.
        const [staffSalesRows, pumpInvoiceRows] = await Promise.all([
            queryAllItems<Record<string, any>>(pk, 'STAFFSALE#', {
                filterExpression: 'staffId = :staffId AND shiftId = :shiftId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: {
                    ':staffId': auth.sub,
                    ':shiftId': body.shiftId,
                    ':false': false,
                },
            }),
            queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: 'shiftId = :shiftId AND #t = :sale AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeNames: { '#t': 'type' },
                expressionAttributeValues: {
                    ':shiftId': body.shiftId,
                    ':sale': 'sale',
                    ':false': false,
                },
            }),
        ]);

        // Normalize invoices to the same shape so reconciliation/loops can
        // treat both row sources uniformly.
        const normalizedInvoices = pumpInvoiceRows.map((inv) => ({
            staffId: inv.createdBy,
            shiftId: inv.shiftId,
            nozzleId: inv.nozzleId,
            productType: inv.productType || inv.fuelType,
            paymentMode: inv.paymentMode,
            volumeLiters: Number(inv.volumeLiters || 0),
            amountCents: Number(inv.totalCents || 0),
            createdAt: inv.createdAt,
            __source: 'invoice',
        }));

        const shiftSales: Array<Record<string, any>> = [
            ...staffSalesRows.map((s) => ({ ...s, __source: 'staff_sale' })),
            ...normalizedInvoices,
        ];

        let totalSalesCents = 0, totalCashCents = 0, totalUpiCents = 0, totalUdharCents = 0;
        let totalCardCents = 0, totalChequeCents = 0, totalNeftCents = 0, totalFleetCardCents = 0;
        let totalVolumeLiters = 0, saleCount = 0;
        const byFuelType: Record<string, { volumeLiters: number; amountCents: number }> = {};

        for (const sale of shiftSales) {
            const amt = Number(sale.amountCents || 0);
            const vol = Number(sale.volumeLiters || 0);
            totalSalesCents += amt;
            totalVolumeLiters += vol;
            saleCount++;

            switch (sale.paymentMode) {
                case 'cash': totalCashCents += amt; break;
                case 'upi':
                case 'online': totalUpiCents += amt; break;
                case 'card': totalCardCents += amt; break;
                case 'cheque': totalChequeCents += amt; break;
                case 'neft':
                case 'bank_transfer': totalNeftCents += amt; break;
                case 'petro_card':
                case 'fleet_card': totalFleetCardCents += amt; break;
                case 'udhar': totalUdharCents += amt; break;
            }

            const ft = sale.productType || 'unknown';
            if (!byFuelType[ft]) byFuelType[ft] = { volumeLiters: 0, amountCents: 0 };
            byFuelType[ft].amountCents += amt;
            byFuelType[ft].volumeLiters += vol;
        }

        // Round volume to 3 decimal places (millilitre precision).
        totalVolumeLiters = Math.round(totalVolumeLiters * 1000) / 1000;

        // 3. PP-006 FIX: Nozzle meter-vs-sales reconciliation
        //    PP-007 FIX: Validate closing >= opening for each nozzle
        const nozzleReconciliation: any[] = [];
        const nozzleSnapshots = shift.nozzleSnapshots || [];

        // Build a lookup from shift nozzle readings (from the request body)
        const closingReadingsMap = new Map<string, { closingReading: number; testingAmount: number }>();
        for (const nr of body.nozzleReadings) {
            closingReadingsMap.set(nr.nozzleId, {
                closingReading: nr.closingReading,
                testingAmount: nr.testingAmount || 0,
            });
        }

        for (const snap of nozzleSnapshots) {
            const submitted = closingReadingsMap.get(snap.nozzleId);
            const closingReading = submitted?.closingReading ?? snap.openingReading;

            // PP-007 FIX: Validate closing >= opening
            if (closingReading < snap.openingReading) {
                throw new ValidationError(
                    `Closing reading (${closingReading}) is less than opening reading (${snap.openingReading}) for nozzle ${snap.nozzleName || snap.nozzleId}.`,
                    { nozzleId: snap.nozzleId, openingReading: snap.openingReading, closingReading },
                );
            }

            const meterDispensedLiters = closingReading - snap.openingReading;
            const testingAmountLiters = submitted?.testingAmount || 0;
            const netMeterDispensedLiters = meterDispensedLiters - testingAmountLiters;

            // Sum up recorded sales for this nozzle during the shift
            let recordedSalesLiters = 0;
            for (const sale of shiftSales) {
                if (sale.nozzleId === snap.nozzleId) {
                    recordedSalesLiters += Number(sale.volumeLiters || 0);
                }
            }

            const varianceLiters = netMeterDispensedLiters - recordedSalesLiters;
            const varianceThresholdLiters = 0.5; // 500ml tolerance

            nozzleReconciliation.push({
                nozzleId: snap.nozzleId,
                nozzleName: snap.nozzleName,
                fuelType: snap.fuelType,
                openingReading: snap.openingReading,
                closingReading,
                testingAmountLiters,
                meterDispensedLiters: Math.round(meterDispensedLiters * 1000) / 1000,
                netMeterDispensedLiters: Math.round(netMeterDispensedLiters * 1000) / 1000,
                recordedSalesLiters: Math.round(recordedSalesLiters * 1000) / 1000,
                varianceLiters: Math.round(varianceLiters * 1000) / 1000,
                status: Math.abs(varianceLiters) <= varianceThresholdLiters ? 'OK' : 'VARIANCE',
            });

            // Update snapshot with closing reading
            snap.closingReading = closingReading;

            // Update nozzle currentMeterReading in DB
            await updateItem(pk, `NOZZLE#${snap.nozzleId}`, {
                updateExpression: 'SET currentMeterReading = :val, updatedAt = :now',
                conditionExpression: 'attribute_exists(PK) AND (attribute_not_exists(currentMeterReading) OR currentMeterReading = :expected)',
                expressionAttributeValues: {
                    ':val': closingReading,
                    ':now': now,
                    ':expected': Number(snap.openingReading || 0),
                },
            });
        }

        const dsrSnapshotPayload = JSON.stringify({
            shiftId: body.shiftId,
            totalSalesCents,
            totalCashCents,
            totalUpiCents,
            totalCardCents,
            totalChequeCents,
            totalNeftCents,
            totalFleetCardCents,
            totalUdharCents,
            totalVolumeLiters,
            saleCount,
            fuelSummary: byFuelType,
            nozzleReconciliation,
        });
        const dsrSnapshotHash = crypto.createHash('sha256').update(dsrSnapshotPayload).digest('hex');

        // 4. Update the SHIFT# entity with summary + digital sign-off metadata.
        await updateItem(pk, `SHIFT#${body.shiftId}`, {
            updateExpression: `SET shiftStatus = :closed, closedAt = :now, updatedAt = :now,
                totalSalesCents = :totalSales, totalCashCents = :totalCash,
                totalUpiCents = :totalUpi, totalCardCents = :totalCard,
                totalChequeCents = :totalCheque, totalNeftCents = :totalNeft,
                totalFleetCardCents = :totalFleet, totalUdharCents = :totalUdhar,
                totalVolumeLiters = :totalVol, saleCount = :saleCount,
                nozzleSnapshots = :snapshots, nozzleReconciliation = :recon,
                fuelSummary = :fuelSummary, closingNotes = :notes,
                cashierSignatureUrl = :sigUrl,
                cashierAcknowledgedAt = :sigAt,
                handoverNotes = :handNotes,
                handoverStatus = :handStatus,
                dsrStatus = :dsrPending,
                dsrApprovedBy = :dsrApprovedBy,
                dsrApprovedAt = :dsrApprovedAt,
                dsrApprovalNotes = :dsrApprovalNotes,
                dsrSnapshotHash = :dsrSnapshotHash`,
            expressionAttributeValues: {
                ':closed': 'closed',
                ':now': now,
                ':totalSales': totalSalesCents,
                ':totalCash': totalCashCents,
                ':totalUpi': totalUpiCents,
                ':totalCard': totalCardCents,
                ':totalCheque': totalChequeCents,
                ':totalNeft': totalNeftCents,
                ':totalFleet': totalFleetCardCents,
                ':totalUdhar': totalUdharCents,
                ':totalVol': totalVolumeLiters,
                ':saleCount': saleCount,
                ':snapshots': nozzleSnapshots,
                ':recon': nozzleReconciliation,
                ':fuelSummary': byFuelType,
                ':notes': body.notes || null,
                ':sigUrl': (body as any).cashierSignatureUrl || null,
                ':sigAt': (body as any).cashierAcknowledgedAt || now,
                ':handNotes': (body as any).handoverNotes || null,
                ':handStatus': (body as any).cashierSignatureUrl ? 'signed' : 'pending_signature',
                ':dsrPending': 'pending_approval',
                ':dsrApprovedBy': null,
                ':dsrApprovedAt': null,
                ':dsrApprovalNotes': null,
                ':dsrSnapshotHash': dsrSnapshotHash,
            },
        });
        await recordRevision(
            auth.tenantId,
            'shifts',
            body.shiftId,
            'status_change',
            auth.sub,
            {
                id: shift.id,
                shiftStatus: shift.shiftStatus,
                closedAt: shift.closedAt ?? null,
                handoverStatus: shift.handoverStatus ?? null,
                dsrStatus: shift.dsrStatus ?? null,
            },
            {
                id: body.shiftId,
                shiftStatus: 'closed',
                closedAt: now,
                handoverStatus: (body as any).cashierSignatureUrl ? 'signed' : 'pending_signature',
                dsrStatus: 'pending_approval',
                dsrSnapshotHash,
                totalSalesCents,
                totalVolumeLiters,
                saleCount,
            },
            { source: 'pump.closeShift' },
        );

        // Audit log
        logAudit({
            action: 'SHIFT_CLOSED',
            resource: 'shift',
            resourceId: body.shiftId,
            metadata: {
                staffId: auth.sub, saleCount, totalSalesCents, totalCashCents,
                varianceFlags: nozzleReconciliation.filter(n => n.status === 'VARIANCE').length,
            },
        }).catch(() => { });

        wsService.emitEvent(auth.tenantId, WSEventName.SHIFT_CLOSED, {
            shiftId: body.shiftId, staffId: auth.sub,
            totalSalesCents, totalCashCents, saleCount,
            nozzleReconciliation, closedAt: now,
        }).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

        // UNS canonical emit (T-PMP-5: users.pump_shift.closed)
        emitUnsEvent({
            eventName: 'users.pump_shift.closed',
            category: 'users',
            subCategory: 'pump_shift',
            priority: 'normal',
            actorId: auth.sub,
            targetId: body.shiftId,
            recipients: [
                { user_id: auth.tenantId, role: 'admin' },
            ],
            payload: {
                tenantId: auth.tenantId,
                shiftId: body.shiftId,
                staffId: auth.sub,
                totalSalesCents,
                totalCashCents,
                saleCount,
                closedAt: now,
            },
            sourceModule: 'my-backend/src/handlers/pump.ts',
            dedupScopeFields: ['shiftId'],
        }).catch(() => { /* non-fatal during migration window */ });

        return response.success({
            shiftId: body.shiftId,
            closedAt: now,
            summary: {
                totalSalesCents, totalCashCents, totalUpiCents, totalCardCents,
                totalChequeCents, totalNeftCents, totalFleetCardCents, totalUdharCents,
                totalVolumeLiters, saleCount, fuelSummary: byFuelType,
            },
            nozzleReconciliation,
            handoverStatus: (body as any).cashierSignatureUrl ? 'signed' : 'pending_signature',
            dsrStatus: 'pending_approval',
            dsrSnapshotHash,
            message: 'Shift closed successfully',
        });
    } catch (err) {
        if (err instanceof ValidationError) {
            return response.error(400, 'VALIDATION_ERROR', err.message);
        }
        if ((err as any)?.name === 'ConditionalCheckFailedException') {
            return response.error(409, 'NOZZLE_READING_CONFLICT', 'Nozzle meter changed by another writer. Refresh and retry.');
        }
        logger.error('Failed to close shift', { error: err });
        return response.internalError('Failed to close shift');
    }
}, PUMP_OPTS);

// ==========================================================================
// SHIFT HANDOVER ACK — digital sign-off by receiving staff/manager
// ==========================================================================

/**
 * POST /pump/shift/handover-ack — Receiving staff signs off on shift handover.
 * Locks the shift to handoverStatus=acknowledged once accepted.
 */
export const acknowledgeShiftHandover = authorizedHandler(PUMP_FLOOR_ROLES, async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.shiftHandoverAckSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const shift = await getItem<Record<string, any>>(pk, `SHIFT#${body.shiftId}`);
    if (!shift || shift.isDeleted) return response.notFound('Shift');
    if (shift.shiftStatus !== 'closed') {
        return response.error(409, 'SHIFT_NOT_CLOSED', 'Shift must be closed before handover can be acknowledged.');
    }
    if (shift.dsrStatus === 'approved') {
        return response.error(409, 'SHIFT_IMMUTABLE', 'Shift already manager-approved; handover data immutable.');
    }
    const canAcknowledgeForAnyStaff = [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER].includes(auth.role);
    if (!canAcknowledgeForAnyStaff && body.receiverStaffId !== auth.sub) {
        return response.forbidden('You can acknowledge handover only for your own staff identity');
    }

    await updateItem(pk, `SHIFT#${body.shiftId}`, {
        updateExpression: 'SET handoverStatus = :st, receiverStaffId = :rs, receiverSignatureUrl = :rsig, receiverAcknowledgedAt = :rat, discrepancyNotes = :dn, updatedAt = :now',
        expressionAttributeValues: {
            ':st': body.accepted ? 'acknowledged' : 'disputed',
            ':rs': body.receiverStaffId,
            ':rsig': body.receiverSignatureUrl,
            ':rat': now,
            ':dn': body.discrepancyNotes || null,
            ':now': now,
        },
    });
    await recordRevision(
        auth.tenantId,
        'shifts',
        body.shiftId,
        'status_change',
        auth.sub,
        {
            id: shift.id,
            handoverStatus: shift.handoverStatus ?? null,
            receiverStaffId: shift.receiverStaffId ?? null,
        },
        {
            id: body.shiftId,
            handoverStatus: body.accepted ? 'acknowledged' : 'disputed',
            receiverStaffId: body.receiverStaffId,
            receiverAcknowledgedAt: now,
        },
        { source: 'pump.acknowledgeShiftHandover' },
    );

    logAudit({
        action: body.accepted ? 'SHIFT_HANDOVER_ACK' : 'SHIFT_HANDOVER_DISPUTED',
        resource: 'shift',
        resourceId: body.shiftId,
        metadata: { receiverStaffId: body.receiverStaffId, discrepancyNotes: body.discrepancyNotes },
    }).catch(() => { });

    return response.success({
        shiftId: body.shiftId,
        handoverStatus: body.accepted ? 'acknowledged' : 'disputed',
        acknowledgedAt: now,
    });
}, PUMP_OPTS);

/**
 * POST /pump/shift/approve-dsr — Manager/owner/admin approves and locks DSR snapshot.
 */
export const approveShiftDsr = authorizedHandler([UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER], async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
    const valid = parseBody(schemas.shiftDsrApproveSchema, event);
    if (!valid.success) return valid.error;
    const body = valid.data;
    const pk = Keys.tenantPK(auth.tenantId);
    const now = new Date().toISOString();

    const shift = await getItem<Record<string, any>>(pk, `SHIFT#${body.shiftId}`);
    if (!shift || shift.isDeleted) return response.notFound('Shift');
    if (shift.shiftStatus !== 'closed') {
        return response.error(409, 'SHIFT_NOT_CLOSED', 'Only closed shifts can be approved.');
    }
    if (shift.dsrStatus === 'approved') {
        return response.error(409, 'DSR_ALREADY_APPROVED', 'DSR already approved and immutable.');
    }
    if (auth.role === UserRole.MANAGER && shift.staffId === auth.sub) {
        return response.error(409, 'DUAL_CONTROL_REQUIRED', 'Manager cannot self-approve own shift.');
    }

    await updateItem(pk, `SHIFT#${body.shiftId}`, {
        updateExpression: 'SET dsrStatus = :approved, dsrApprovedBy = :approver, dsrApprovedAt = :at, dsrApprovalNotes = :notes, updatedAt = :now',
        conditionExpression: '(attribute_not_exists(dsrStatus) OR dsrStatus <> :approved)',
        expressionAttributeValues: {
            ':approved': 'approved',
            ':approver': auth.sub,
            ':at': now,
            ':notes': body.approvalNotes || null,
            ':now': now,
        },
    });

    await recordRevision(
        auth.tenantId,
        'shifts',
        body.shiftId,
        'status_change',
        auth.sub,
        {
            id: shift.id,
            dsrStatus: shift.dsrStatus ?? null,
            dsrApprovedBy: shift.dsrApprovedBy ?? null,
            dsrApprovedAt: shift.dsrApprovedAt ?? null,
        },
        {
            id: body.shiftId,
            dsrStatus: 'approved',
            dsrApprovedBy: auth.sub,
            dsrApprovedAt: now,
        },
        { source: 'pump.approveShiftDsr' },
    );

    logAudit({
        action: 'SHIFT_DSR_APPROVED',
        resource: 'shift',
        resourceId: body.shiftId,
        metadata: { approvedBy: auth.sub, approvalNotes: body.approvalNotes || null },
    }).catch(() => { });

    return response.success({
        shiftId: body.shiftId,
        dsrStatus: 'approved',
        approvedBy: auth.sub,
        approvedAt: now,
        message: 'DSR approved and locked',
    });
}, PUMP_OPTS);

