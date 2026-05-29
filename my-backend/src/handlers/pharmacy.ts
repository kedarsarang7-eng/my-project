// ============================================================================
// Lambda Handler — Pharmacy
// ============================================================================
// Endpoints:
//   POST /pharmacy/batch-intake        — Record drug batch stock received
//   POST /pharmacy/narcotic-register   — Record narcotic (Schedule X) sale entry
//   GET  /pharmacy/narcotic-register   — Paginated register with date filter
//
// Security:
//   - Business type guard: pharmacy only
//   - Feature guard: pharmacy_basic_batch_expiry
//   - Role guards: per-endpoint (see individual handlers)
//   - CloudWatch metric: NarcoticRegisterAccess on every narcotic API call
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { FeatureKey } from '../config/plan-feature-registry';
import {
    Keys, TABLE_NAME, getItem, transactWrite, queryItems, putItem, updateItem,
} from '../config/dynamodb.config';
import { parseBody, parseQuery } from '../middleware/validation';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { AuthContext, BusinessType, UserRole } from '../types/tenant.types';
import {
    batchIntakeSchema,
    narcoticRegisterSchema,
    narcoticRegisterQuerySchema,
    narcoticRegisterExportQuerySchema,
    h1RegisterSchema,
    h1RegisterQuerySchema,
    h1RegisterExportQuerySchema,
    fefoOverrideAuthorizeSchema,
    refillRequestSchema,
    refillListQuerySchema,
    refillStatusUpdateSchema,
    refillBackfillSchema,
    refillIncompleteQuerySchema,
    refillBulkBackfillSchema,
    partialFillSchema,
    claimTransmitSchema,
    claimAdjudicationSchema,
    claimCobNextSchema,
    claimListQuerySchema,
    priorAuthCreateSchema,
    priorAuthUpdateSchema,
    priorAuthListQuerySchema,
    cdsScreenSchema,
    drugMasterMappingSchema,
    formularyUpsertSchema,
    formularyListQuerySchema,
    drugMasterListQuerySchema,
    programTrackEventSchema,
} from '../schemas/pharmacy.schema';
import { medBatchSK } from '../services/pharmacy-batch.service';
import { recordRevision } from '../services/revision-history.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { logAudit } from '../middleware/audit';
import { v4 as uuidv4 } from 'uuid';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { config } from '../config/environment';

// PERF-9 FIX: Lazy-load CloudWatchClient — initialized on first use only
let _cwClient: CloudWatchClient | null = null;
function getCloudWatchClient(): CloudWatchClient {
    if (!_cwClient) {
        _cwClient = new CloudWatchClient({ region: config.aws.region });
    }
    return _cwClient;
}

const PHARMACY_OPTS = {
    requiredBusinessType: BusinessType.PHARMACY,
    requiredFeature: FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY,
};

function encodeCursor(lastKey?: Record<string, unknown>): string | null {
    if (!lastKey) return null;
    return Buffer.from(JSON.stringify(lastKey), 'utf8').toString('base64');
}

function decodeCursor(cursor?: string): Record<string, unknown> | undefined {
    if (!cursor) return undefined;
    try {
        const parsed = JSON.parse(Buffer.from(cursor, 'base64').toString('utf8'));
        if (parsed && typeof parsed === 'object') return parsed as Record<string, unknown>;
    } catch (_) {
        return undefined;
    }
    return undefined;
}

function sortByRecent(items: Record<string, any>[], keys: string[]): Record<string, any>[] {
    return [...items].sort((a, b) => {
        const aVal = keys.map((k) => String(a?.[k] || '')).find((v) => v) || '';
        const bVal = keys.map((k) => String(b?.[k] || '')).find((v) => v) || '';
        return bVal.localeCompare(aVal);
    });
}

async function queryFilteredPage(
    pk: string,
    skPrefix: string,
    pageSize: number,
    cursor: string | undefined,
    filterFn: (item: Record<string, any>) => boolean,
    indexName?: 'GSI1' | 'GSI2' | 'GSI3',
): Promise<{ rows: Record<string, any>[]; nextCursor: string | null; hasMore: boolean }> {
    const cursorPayload = decodeCursor(cursor);
    const localIdx = Number(cursorPayload?.localIdx);
    if (Number.isFinite(localIdx) && localIdx >= 0) {
        const chunk = await queryItems<Record<string, any>>(pk, skPrefix, {
            scanIndexForward: false,
            limit: Math.max(pageSize + localIdx + 10, 100),
            indexName,
        });
        const filtered = chunk.items.filter(filterFn);
        const start = Math.floor(localIdx);
        const end = start + pageSize;
        const hasMore = end < filtered.length;
        return {
            rows: filtered.slice(start, end),
            nextCursor: hasMore ? encodeCursor({ localIdx: end }) : null,
            hasMore,
        };
    }

    const collected: Record<string, any>[] = [];
    let startKey = decodeCursor(cursor);
    let lastKey: Record<string, unknown> | undefined = startKey;

    do {
        const chunk = await queryItems<Record<string, any>>(pk, skPrefix, {
            scanIndexForward: false,
            limit: Math.max(pageSize * 2, 50),
            exclusiveStartKey: startKey,
            indexName,
        });
        const filtered = chunk.items.filter(filterFn);
        collected.push(...filtered);
        startKey = chunk.lastKey;
        lastKey = chunk.lastKey;
    } while (collected.length < pageSize && startKey);

    const rows = collected.slice(0, pageSize);
    const hasMore = collected.length > pageSize || !!lastKey;
    return {
        rows,
        nextCursor: lastKey
            ? encodeCursor(lastKey)
            : (collected.length > pageSize ? encodeCursor({ localIdx: pageSize }) : null),
        hasMore,
    };
}

// -- CloudWatch metric for NDPS / D&C Schedule audit trail ------------------

async function emitScheduleRegisterMetric(
    metricName: 'NarcoticRegisterAccess' | 'H1RegisterAccess',
    action: 'POST' | 'GET',
    tenantId: string,
    actorId: string,
): Promise<void> {
    try {
        await getCloudWatchClient().send(new PutMetricDataCommand({
            Namespace: 'DukanX/Pharmacy',
            MetricData: [{
                MetricName: metricName,
                Value: 1,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'Action', Value: action },
                    { Name: 'TenantId', Value: tenantId },
                    { Name: 'ActorId', Value: actorId },
                ],
                Timestamp: new Date(),
            }],
        }));
    } catch (err) {
        logger.warn(`Failed to emit ${metricName} metric`, {
            error: (err as Error).message,
        });
    }
}

async function emitNarcoticMetric(
    action: 'POST' | 'GET',
    tenantId: string,
    actorId: string,
): Promise<void> {
    return emitScheduleRegisterMetric('NarcoticRegisterAccess', action, tenantId, actorId);
}

async function emitH1RegisterMetric(
    action: 'POST' | 'GET',
    tenantId: string,
    actorId: string,
): Promise<void> {
    return emitScheduleRegisterMetric('H1RegisterAccess', action, tenantId, actorId);
}

// ============================================================================
// POST /pharmacy/batch-intake
// ============================================================================

/**
 * POST /pharmacy/batch-intake
 *
 * Record drug batch stock received from a supplier (purchase/GRN).
 * Creates or updates MEDBATCH# records and atomically increments
 * the product's aggregate currentStock.
 */
export const batchIntake = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        // 1. Parse and validate input
        const parsed = parseBody(batchIntakeSchema, event);
        if (!parsed.success) return parsed.error;

        const { productId, batches, purchaseDate } = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);
        const now = new Date().toISOString();
        const effectivePurchaseDate = purchaseDate || now.split('T')[0];

        // 2. Validate product exists and belongs to tenant
        const product = await getItem<Record<string, any>>(pk, Keys.productSK(productId));

        if (!product || product.isDeleted) {
            return response.error(404, 'PRODUCT_NOT_FOUND', `Product '${productId}' not found`);
        }

        // 3. Check existing MEDBATCH# records for this product (to detect duplicates)
        const existingBatches = await queryItems<Record<string, any>>(
            pk,
            `MEDBATCH#${productId}#`,
        );

        // Build lookup map: batchNumber ? existing DynamoDB record
        const existingBatchMap = new Map<string, Record<string, any>>();
        for (const b of existingBatches.items) {
            if (b.batchNumber) {
                existingBatchMap.set(b.batchNumber, b);
            }
        }

        // 4. Build transactWrite operations
        const tableName = config.dynamodb.tableName;
        const transactItems: any[] = [];
        let totalQtyReceived = 0;
        let batchesCreated = 0;
        let batchesUpdated = 0;

        for (const batch of batches) {
            totalQtyReceived += batch.quantityReceived;
            const batchSK = medBatchSK(productId, batch.batchNumber);
            const existing = existingBatchMap.get(batch.batchNumber);

            if (existing) {
                // 4a. Existing batch ? increment batchStock
                transactItems.push({
                    Update: {
                        TableName: tableName,
                        Key: { PK: pk, SK: batchSK },
                        UpdateExpression:
                            'SET batchStock = batchStock + :qty, ' +
                            'currentQty = if_not_exists(currentQty, :zero) + :qty, ' +
                            'updatedAt = :now, ' +
                            'lastReceiveDate = :purchaseDate' +
                            (batch.costPricePaise ? ', costPricePaise = :cost' : ''),
                        ConditionExpression: 'attribute_exists(PK)',
                        ExpressionAttributeValues: {
                            ':qty': batch.quantityReceived,
                            ':zero': 0,
                            ':now': now,
                            ':purchaseDate': effectivePurchaseDate,
                            ...(batch.costPricePaise ? { ':cost': batch.costPricePaise } : {}),
                        },
                    },
                });

                // If batch was previously depleted, reactivate it
                if (existing.status === 'depleted') {
                    transactItems.push({
                        Update: {
                            TableName: tableName,
                            Key: { PK: pk, SK: batchSK },
                            UpdateExpression: 'SET #batchStatus = :active',
                            ExpressionAttributeNames: { '#batchStatus': 'status' },
                            ExpressionAttributeValues: { ':active': 'active' },
                        },
                    });
                }

                batchesUpdated++;
            } else {
                // 4b. New batch ? create MEDBATCH# record
                const medBatchItem: Record<string, any> = {
                    PK: pk,
                    SK: batchSK,
                    entityType: 'MED_BATCH',
                    tenantId,
                    productId,
                    productName: product.name,
                    batchNumber: batch.batchNumber,
                    expiryDate: batch.expiryDate,
                    batchStock: batch.quantityReceived,
                    currentQty: batch.quantityReceived,
                    costPricePaise: batch.costPricePaise,
                    status: 'active',
                    supplierName: batch.supplierName || null,
                    invoiceRef: batch.invoiceRef || null,
                    purchaseDate: effectivePurchaseDate,
                    createdBy: auth.sub,
                    createdAt: now,
                    updatedAt: now,
                };

                transactItems.push({
                    Put: {
                        TableName: tableName,
                        Item: medBatchItem,
                        ConditionExpression: 'attribute_not_exists(PK)',
                    },
                });

                batchesCreated++;
            }
        }

        // 5. Atomically increment product's aggregate currentStock
        transactItems.push({
            Update: {
                TableName: tableName,
                Key: { PK: pk, SK: Keys.productSK(productId) },
                UpdateExpression: 'SET currentStock = currentStock + :totalQty, updatedAt = :now',
                ConditionExpression: 'attribute_exists(PK)',
                ExpressionAttributeValues: {
                    ':totalQty': totalQtyReceived,
                    ':now': now,
                },
            },
        });

        // 6. Execute atomic transaction
        if (transactItems.length > 100) {
            return response.error(
                400, 'TOO_MANY_BATCHES',
                'Too many batch operations to process atomically. Reduce batch count.',
            );
        }

        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                const reasons = err.CancellationReasons || [];

                for (const reason of reasons) {
                    if (reason?.Code === 'ConditionalCheckFailed') {
                        logger.warn('Batch intake race condition detected', {
                            tenantId, productId, reasons,
                        });
                        return response.error(
                            409, 'BATCH_CONFLICT',
                            'A batch was created concurrently. Please retry the operation.',
                        );
                    }
                }

                return response.error(
                    409, 'INTAKE_CONFLICT',
                    'Batch intake failed due to concurrent modification. Please retry.',
                );
            }
            throw err;
        }

        // 7. Calculate new total stock for response
        const newTotalStock = (Number(product.currentStock) || 0) + totalQtyReceived;
        await recordRevision(
            tenantId,
            'pharmacy_batches',
            productId,
            'update',
            auth.sub,
            {
                currentStock: Number(product.currentStock) || 0,
            },
            {
                currentStock: newTotalStock,
                batchesCreated,
                batchesUpdated,
                totalQtyReceived,
            },
            { source: 'pharmacy.batchIntake', purchaseDate: effectivePurchaseDate },
        );

        // 8. Audit log
        logAudit({
            action: 'BATCH_INTAKE',
            resource: 'pharmacy_batch',
            resourceId: productId,
            metadata: {
                productName: product.name,
                batches: batches.map(b => ({
                    batchNumber: b.batchNumber,
                    quantityReceived: b.quantityReceived,
                    expiryDate: b.expiryDate,
                    costPricePaise: b.costPricePaise,
                    supplierName: b.supplierName,
                })),
                totalQtyReceived,
                batchesCreated,
                batchesUpdated,
                purchaseDate: effectivePurchaseDate,
                newTotalStock,
            },
        }).catch(() => { });

        logger.info('Pharmacy batch intake completed', {
            tenantId,
            productId,
            productName: product.name,
            batchesCreated,
            batchesUpdated,
            totalQtyReceived,
            newTotalStock,
        });

        return response.success({
            batchesCreated,
            batchesUpdated,
            newTotalStock,
            productId,
            productName: product.name,
        }, 201);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/narcotic-register
// ============================================================================
// Records a narcotic drug sale entry per NDPS Act requirements.
// Can be called standalone (manual register entry) OR auto-called from
// invoice.service.ts when a Schedule X line item is created.
//
// Role guard: owner, manager, staff (pharmacist)
// ============================================================================

export const createNarcoticEntry = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        // 1. Parse and validate input
        const parsed = parseBody(narcoticRegisterSchema, event);
        if (!parsed.success) return parsed.error;

        const data = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);
        const now = new Date().toISOString();

        // 2. Emit CloudWatch metric for NDPS audit trail
        emitNarcoticMetric('POST', tenantId, auth.sub).catch(() => { });

        // 3. Create NARCOTICLOG# record
        const narcoticLogItem: Record<string, any> = {
            PK: pk,
            SK: `NARCOTICLOG#${data.invoiceId}#${now}`,
            entityType: 'NARCOTIC_LOG',
            tenantId,
            patientName: data.patientName,
            patientAddress: data.patientAddress,
            prescribingDoctorName: data.prescribingDoctorName,
            doctorRegNo: data.doctorRegNo,
            prescriptionId: data.prescriptionId,
            drugName: data.drugName,
            scheduleType: 'X',
            quantitySold: data.quantitySold,
            batchNumber: data.batchNumber,
            expiryDate: data.expiryDate,
            dispensedBy: auth.sub,
            dispensedAt: now,
            invoiceId: data.invoiceId,
            createdAt: now,
        };

        await putItem(narcoticLogItem);
        await recordRevision(
            tenantId,
            'pharmacy_narcotic_log',
            `${data.invoiceId}#${now}`,
            'create',
            auth.sub,
            null,
            {
                invoiceId: data.invoiceId,
                prescriptionId: data.prescriptionId,
                drugName: data.drugName,
                quantitySold: data.quantitySold,
                batchNumber: data.batchNumber,
                doctorRegNo: data.doctorRegNo,
            },
            { source: 'pharmacy.createNarcoticEntry' },
        );

        // 4. Audit log
        logAudit({
            action: 'NARCOTIC_REGISTER_ENTRY',
            resource: 'narcotic_register',
            resourceId: data.invoiceId,
            metadata: {
                drugName: data.drugName,
                quantitySold: data.quantitySold,
                patientName: data.patientName,
                prescriptionId: data.prescriptionId,
                doctorRegNo: data.doctorRegNo,
                batchNumber: data.batchNumber,
            },
        }).catch(() => { });

        logger.info('Narcotic register entry created', {
            tenantId,
            invoiceId: data.invoiceId,
            drugName: data.drugName,
            quantitySold: data.quantitySold,
            dispensedBy: auth.sub,
        });

        return response.success({
            id: narcoticLogItem.SK,
            drugName: data.drugName,
            quantitySold: data.quantitySold,
            patientName: data.patientName,
            dispensedAt: now,
            invoiceId: data.invoiceId,
        }, 201);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// GET /pharmacy/narcotic-register
// ============================================================================
// Paginated narcotic drug register with date-range filter.
// Restricted to owner/manager only — NOT accessible to cashier or staff.
// ============================================================================

export const getNarcoticRegister = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        // 1. Parse query params
        const parsed = parseQuery(narcoticRegisterQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { startDate, endDate, page, pageSize } = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);

        // 2. Emit CloudWatch metric for NDPS audit trail
        emitNarcoticMetric('GET', tenantId, auth.sub).catch(() => { });

        // 3. Query NARCOTICLOG# records
        const filterParts: string[] = [];
        const exprValues: Record<string, unknown> = {};

        if (startDate) {
            filterParts.push('dispensedAt >= :startDate');
            exprValues[':startDate'] = new Date(startDate + 'T00:00:00Z').toISOString();
        }
        if (endDate) {
            // Include the entire end date (up to 23:59:59.999)
            filterParts.push('dispensedAt <= :endDate');
            exprValues[':endDate'] = new Date(endDate + 'T23:59:59.999Z').toISOString();
        }

        const result = await queryItems<Record<string, any>>(
            pk,
            'NARCOTICLOG#',
            {
                scanIndexForward: false, // newest first
                filterExpression: filterParts.length > 0
                    ? filterParts.join(' AND ')
                    : undefined,
                expressionAttributeValues: Object.keys(exprValues).length > 0
                    ? exprValues
                    : undefined,
            },
        );

        // 4. Sort by dispensedAt descending
        const allItems = result.items.sort((a, b) =>
            (b.dispensedAt || '').localeCompare(a.dispensedAt || ''),
        );

        // 5. Paginate
        const total = allItems.length;
        const startIdx = (page - 1) * pageSize;
        const paged = allItems.slice(startIdx, startIdx + pageSize);

        // 6. Map to response shape (exclude PK/SK internals)
        const entries = paged.map(item => ({
            id: item.SK,
            patientName: item.patientName,
            patientAddress: item.patientAddress,
            prescribingDoctorName: item.prescribingDoctorName,
            doctorRegNo: item.doctorRegNo,
            prescriptionId: item.prescriptionId,
            drugName: item.drugName,
            scheduleType: item.scheduleType || 'X',
            quantitySold: item.quantitySold,
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate,
            dispensedBy: item.dispensedBy,
            dispensedAt: item.dispensedAt,
            invoiceId: item.invoiceId,
        }));

        logger.info('Narcotic register queried', {
            tenantId,
            total,
            page,
            pageSize,
            startDate: startDate || 'all',
            endDate: endDate || 'all',
            queriedBy: auth.sub,
        });

        return response.paginated(entries, total, page, pageSize);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// GET /pharmacy/narcotic-register/export
// ============================================================================
// Exports narcotic register rows for compliance filings.
// Current response is structured JSON/CSV payload metadata.
// PDF binary generation can be added behind same endpoint contract.
// ============================================================================
export const exportNarcoticRegister = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(narcoticRegisterExportQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { startDate, endDate, format } = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);

        emitNarcoticMetric('GET', tenantId, auth.sub).catch(() => { });

        const filterParts: string[] = [];
        const exprValues: Record<string, unknown> = {};

        if (startDate) {
            filterParts.push('dispensedAt >= :startDate');
            exprValues[':startDate'] = new Date(startDate + 'T00:00:00Z').toISOString();
        }
        if (endDate) {
            filterParts.push('dispensedAt <= :endDate');
            exprValues[':endDate'] = new Date(endDate + 'T23:59:59.999Z').toISOString();
        }

        const result = await queryItems<Record<string, any>>(
            pk,
            'NARCOTICLOG#',
            {
                scanIndexForward: false,
                filterExpression: filterParts.length > 0 ? filterParts.join(' AND ') : undefined,
                expressionAttributeValues: Object.keys(exprValues).length > 0 ? exprValues : undefined,
            },
        );

        const rows = result.items
            .sort((a, b) => (b.dispensedAt || '').localeCompare(a.dispensedAt || ''))
            .map(item => ({
                dispensedAt: item.dispensedAt,
                drugName: item.drugName,
                batchNumber: item.batchNumber,
                quantitySold: item.quantitySold,
                patientName: item.patientName,
                patientAddress: item.patientAddress,
                prescribingDoctorName: item.prescribingDoctorName,
                doctorRegNo: item.doctorRegNo,
                invoiceId: item.invoiceId,
                prescriptionId: item.prescriptionId,
            }));

        const generatedAt = new Date().toISOString();
        const fileName = `narcotic-register-${tenantId}-${generatedAt.slice(0, 10)}.${format === 'pdf' ? 'pdf' : format}`;

        // Keep same endpoint stable even before PDF generator is integrated.
        // FE uses success state + payload for submission workflow.
        if (format === 'csv') {
            const header = 'dispensedAt,drugName,batchNumber,quantitySold,patientName,patientAddress,prescribingDoctorName,doctorRegNo,invoiceId,prescriptionId';
            const csvRows = rows.map(r => [
                r.dispensedAt, r.drugName, r.batchNumber, r.quantitySold, r.patientName,
                r.patientAddress, r.prescribingDoctorName, r.doctorRegNo, r.invoiceId, r.prescriptionId,
            ].map(v => `"${String(v ?? '').replace(/"/g, '""')}"`).join(','));
            return response.success({
                format,
                fileName,
                generatedAt,
                totalRows: rows.length,
                csv: [header, ...csvRows].join('\n'),
            });
        }

        return response.success({
            format,
            fileName,
            generatedAt,
            totalRows: rows.length,
            rows,
        });
    },
    PHARMACY_OPTS,
);

// ============================================================================
// Schedule H1 Register — POST / GET / EXPORT
// ============================================================================
// Per Drugs and Cosmetics Rules, 1945 (Schedule H1 Rule), pharmacies must
// maintain a separate register for H1 drugs (certain antibiotics, anti-TB,
// habit-forming drugs) capturing patient + prescriber + drug + qty + date
// for at least 3 years. Drug Inspector audits this register independently
// from the Schedule X narcotic register.
// ============================================================================

export const createH1Entry = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(h1RegisterSchema, event);
        if (!parsed.success) return parsed.error;

        const data = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);
        const now = new Date().toISOString();

        emitH1RegisterMetric('POST', tenantId, auth.sub).catch(() => { });

        const h1LogItem: Record<string, any> = {
            PK: pk,
            SK: `H1LOG#${data.invoiceId}#${now}`,
            entityType: 'H1_LOG',
            tenantId,
            patientName: data.patientName,
            patientAddress: data.patientAddress || null,
            prescribingDoctorName: data.prescribingDoctorName,
            doctorRegNo: data.doctorRegNo,
            prescriptionId: data.prescriptionId,
            drugName: data.drugName,
            scheduleType: 'H1',
            quantitySold: data.quantitySold,
            batchNumber: data.batchNumber,
            expiryDate: data.expiryDate,
            dispensedBy: auth.sub,
            dispensedAt: now,
            invoiceId: data.invoiceId,
            createdAt: now,
        };

        await putItem(h1LogItem);
        await recordRevision(
            tenantId,
            'pharmacy_h1_log',
            `${data.invoiceId}#${now}`,
            'create',
            auth.sub,
            null,
            {
                invoiceId: data.invoiceId,
                prescriptionId: data.prescriptionId,
                drugName: data.drugName,
                quantitySold: data.quantitySold,
                batchNumber: data.batchNumber,
                doctorRegNo: data.doctorRegNo,
            },
            { source: 'pharmacy.createH1Entry' },
        );

        logAudit({
            action: 'H1_REGISTER_ENTRY',
            resource: 'h1_register',
            resourceId: data.invoiceId,
            metadata: {
                drugName: data.drugName,
                quantitySold: data.quantitySold,
                patientName: data.patientName,
                prescriptionId: data.prescriptionId,
                doctorRegNo: data.doctorRegNo,
                batchNumber: data.batchNumber,
            },
        }).catch(() => { });

        logger.info('H1 register entry created', {
            tenantId,
            invoiceId: data.invoiceId,
            drugName: data.drugName,
            quantitySold: data.quantitySold,
            dispensedBy: auth.sub,
        });

        return response.success({
            id: h1LogItem.SK,
            drugName: data.drugName,
            quantitySold: data.quantitySold,
            patientName: data.patientName,
            dispensedAt: now,
            invoiceId: data.invoiceId,
        }, 201);
    },
    PHARMACY_OPTS,
);

export const getH1Register = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(h1RegisterQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { startDate, endDate, page, pageSize } = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);

        emitH1RegisterMetric('GET', tenantId, auth.sub).catch(() => { });

        const filterParts: string[] = [];
        const exprValues: Record<string, unknown> = {};

        if (startDate) {
            filterParts.push('dispensedAt >= :startDate');
            exprValues[':startDate'] = new Date(startDate + 'T00:00:00Z').toISOString();
        }
        if (endDate) {
            filterParts.push('dispensedAt <= :endDate');
            exprValues[':endDate'] = new Date(endDate + 'T23:59:59.999Z').toISOString();
        }

        const result = await queryItems<Record<string, any>>(
            pk,
            'H1LOG#',
            {
                scanIndexForward: false,
                filterExpression: filterParts.length > 0
                    ? filterParts.join(' AND ')
                    : undefined,
                expressionAttributeValues: Object.keys(exprValues).length > 0
                    ? exprValues
                    : undefined,
            },
        );

        const allItems = result.items.sort((a, b) =>
            (b.dispensedAt || '').localeCompare(a.dispensedAt || ''),
        );

        const total = allItems.length;
        const startIdx = (page - 1) * pageSize;
        const paged = allItems.slice(startIdx, startIdx + pageSize);

        const entries = paged.map(item => ({
            id: item.SK,
            patientName: item.patientName,
            patientAddress: item.patientAddress,
            prescribingDoctorName: item.prescribingDoctorName,
            doctorRegNo: item.doctorRegNo,
            prescriptionId: item.prescriptionId,
            drugName: item.drugName,
            scheduleType: item.scheduleType || 'H1',
            quantitySold: item.quantitySold,
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate,
            dispensedBy: item.dispensedBy,
            dispensedAt: item.dispensedAt,
            invoiceId: item.invoiceId,
        }));

        logger.info('H1 register queried', {
            tenantId,
            total,
            page,
            pageSize,
            startDate: startDate || 'all',
            endDate: endDate || 'all',
            queriedBy: auth.sub,
        });

        return response.paginated(entries, total, page, pageSize);
    },
    PHARMACY_OPTS,
);

export const exportH1Register = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(h1RegisterExportQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { startDate, endDate, format } = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);

        emitH1RegisterMetric('GET', tenantId, auth.sub).catch(() => { });

        const filterParts: string[] = [];
        const exprValues: Record<string, unknown> = {};

        if (startDate) {
            filterParts.push('dispensedAt >= :startDate');
            exprValues[':startDate'] = new Date(startDate + 'T00:00:00Z').toISOString();
        }
        if (endDate) {
            filterParts.push('dispensedAt <= :endDate');
            exprValues[':endDate'] = new Date(endDate + 'T23:59:59.999Z').toISOString();
        }

        const result = await queryItems<Record<string, any>>(
            pk,
            'H1LOG#',
            {
                scanIndexForward: false,
                filterExpression: filterParts.length > 0 ? filterParts.join(' AND ') : undefined,
                expressionAttributeValues: Object.keys(exprValues).length > 0 ? exprValues : undefined,
            },
        );

        const rows = result.items
            .sort((a, b) => (b.dispensedAt || '').localeCompare(a.dispensedAt || ''))
            .map(item => ({
                dispensedAt: item.dispensedAt,
                drugName: item.drugName,
                batchNumber: item.batchNumber,
                quantitySold: item.quantitySold,
                patientName: item.patientName,
                patientAddress: item.patientAddress,
                prescribingDoctorName: item.prescribingDoctorName,
                doctorRegNo: item.doctorRegNo,
                invoiceId: item.invoiceId,
                prescriptionId: item.prescriptionId,
            }));

        const generatedAt = new Date().toISOString();
        const fileName = `h1-register-${tenantId}-${generatedAt.slice(0, 10)}.${format === 'pdf' ? 'pdf' : format}`;

        if (format === 'csv') {
            const header = 'dispensedAt,drugName,batchNumber,quantitySold,patientName,patientAddress,prescribingDoctorName,doctorRegNo,invoiceId,prescriptionId';
            const csvRows = rows.map(r => [
                r.dispensedAt, r.drugName, r.batchNumber, r.quantitySold, r.patientName,
                r.patientAddress, r.prescribingDoctorName, r.doctorRegNo, r.invoiceId, r.prescriptionId,
            ].map(v => `"${String(v ?? '').replace(/"/g, '""')}"`).join(','));
            return response.success({
                format,
                fileName,
                generatedAt,
                totalRows: rows.length,
                csv: [header, ...csvRows].join('\n'),
            });
        }

        return response.success({
            format,
            fileName,
            generatedAt,
            totalRows: rows.length,
            rows,
        });
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/prescriptions/refills
// ============================================================================
// Creates refill request workflow entry.
// ============================================================================
export const createRefillRequest = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(refillRequestSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const id = uuidv4();
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);
        const payload = parsed.data;

        await putItem({
            PK: pk,
            SK: `RXREFILL#${id}`,
            entityType: 'RX_REFILL',
            id,
            tenantId,
            status: 'requested',
            prescriptionId: payload.prescriptionId,
            productId: payload.productId,
            patientName: payload.patientName,
            patientPhone: payload.patientPhone || null,
            drugName: payload.drugName,
            requestedQty: payload.requestedQty,
            prescribedQty: payload.prescribedQty,
            notes: payload.notes || null,
            requestedBy: auth.sub,
            requestedAt: now,
            updatedAt: now,
            createdAt: now,
        });
        await recordRevision(
            tenantId,
            'pharmacy_refills',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                status: 'requested',
                prescriptionId: payload.prescriptionId,
                productId: payload.productId,
                requestedQty: payload.requestedQty,
                prescribedQty: payload.prescribedQty,
            },
            { source: 'pharmacy.createRefillRequest' },
        );

        return response.success({
            id,
            status: 'requested',
            prescriptionId: payload.prescriptionId,
            requestedAt: now,
        }, 201);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// GET /pharmacy/prescriptions/refills
// ============================================================================
export const listRefillRequests = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(refillListQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { status, page, pageSize, cursor } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const filterExpression = status ? '#status = :status' : undefined;
        const expressionAttributeNames = status ? { '#status': 'status' } : undefined;
        const expressionAttributeValues = status ? { ':status': status } : undefined;

        let startKey = decodeCursor(cursor);
        if (!startKey && page > 1) {
            let skipPages = page - 1;
            while (skipPages > 0) {
                let skipped = 0;
                while (skipped < pageSize) {
                    const prefetch: { items: Record<string, any>[]; lastKey?: Record<string, unknown> } =
                        await queryItems<Record<string, any>>(pk, 'RXREFILL#', {
                            scanIndexForward: false,
                            limit: Math.max(pageSize * 2, 100),
                            exclusiveStartKey: startKey,
                            filterExpression,
                            expressionAttributeNames,
                            expressionAttributeValues,
                        });
                    skipped += prefetch.items.length;
                    startKey = prefetch.lastKey;
                    if (!startKey) break;
                }
                if (!startKey) break;
                skipPages--;
            }
        }

        const collected: Record<string, any>[] = [];
        let pageLastKey = startKey;
        do {
            const chunk = await queryItems<Record<string, any>>(pk, 'RXREFILL#', {
                scanIndexForward: false,
                limit: Math.max(pageSize * 2, 100),
                exclusiveStartKey: pageLastKey,
                filterExpression,
                expressionAttributeNames,
                expressionAttributeValues,
            });
            collected.push(...chunk.items);
            pageLastKey = chunk.lastKey;
        } while (collected.length < pageSize && pageLastKey);

        const rows = collected.slice(0, pageSize);
        const nextCursor = encodeCursor(pageLastKey);
        const hasMore = !!pageLastKey;

        return response.success(
            rows.map((r) => ({
                id: r.id,
                status: r.status,
                prescriptionId: r.prescriptionId,
                productId: r.productId,
                patientName: r.patientName,
                patientPhone: r.patientPhone,
                drugName: r.drugName,
                requestedQty: r.requestedQty,
                prescribedQty: r.prescribedQty ?? r.requestedQty,
                notes: r.notes,
                requestedAt: r.requestedAt,
                updatedAt: r.updatedAt,
            })),
            200,
            {
                page,
                limit: pageSize,
                nextCursor,
                hasMore,
            },
        );
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/prescriptions/refills/{id}/status
// ============================================================================
// Refill state transitions:
// requested -> approved|rejected
// approved  -> dispensed
// rejected/dispensed are terminal.
// ============================================================================
export const updateRefillStatus = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const refillId = event.pathParameters?.id;
        if (!refillId) return response.badRequest('Missing refill id');

        const parsed = parseBody(refillStatusUpdateSchema, event);
        if (!parsed.success) return parsed.error;

        const { status, reason, invoiceId, dispensedQty } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `RXREFILL#${refillId}`;
        const current = await getItem<Record<string, any>>(pk, sk);
        if (!current) return response.notFound('Refill request');

        const currentStatus = String(current.status || 'requested');
        const allowedTransitions: Record<string, string[]> = {
            requested: ['approved', 'rejected'],
            approved: ['dispensed'],
            rejected: [],
            dispensed: [],
        };

        if (!allowedTransitions[currentStatus]?.includes(status)) {
            return response.error(
                409,
                'INVALID_REFILL_TRANSITION',
                `Cannot move refill from '${currentStatus}' to '${status}'`,
            );
        }

        if (status === 'dispensed' && !(invoiceId || current.invoiceId)) {
            return response.error(
                400,
                'INVOICE_ID_REQUIRED',
                'Invoice ID is required when marking refill as dispensed',
            );
        }
        if (status === 'dispensed') {
            const prescribed = Number(current.prescribedQty ?? current.requestedQty ?? 0);
            if (!Number.isFinite(prescribed) || prescribed <= 0) {
                return response.error(
                    400,
                    'PRESCRIBED_QTY_REQUIRED',
                    'Prescribed quantity is required before dispensing refill',
                );
            }
            const effectiveDispensedQty = Number(dispensedQty ?? prescribed);
            if (!Number.isFinite(effectiveDispensedQty) || effectiveDispensedQty <= 0) {
                return response.error(
                    400,
                    'INVALID_DISPENSE_QTY',
                    'Dispensed quantity must be greater than 0',
                );
            }
            if (effectiveDispensedQty > prescribed) {
                return response.error(
                    400,
                    'DISPENSE_QTY_EXCEEDS_PRESCRIBED',
                    'Dispensed quantity cannot exceed prescribed quantity',
                );
            }
            if (
                effectiveDispensedQty < prescribed &&
                (!current.productId || String(current.productId).trim() === '')
            ) {
                return response.error(
                    400,
                    'PRODUCT_ID_REQUIRED_FOR_PARTIAL',
                    'Product ID is required before recording partial dispense',
                );
            }
        }

        const now = new Date().toISOString();
        const transitionByKey = `statusBy_${status}`;
        const transitionAtKey = `statusAt_${status}`;
        const statusReasonKey = `statusReason_${status}`;
        const prescribedForTransition = Number(current.prescribedQty ?? current.requestedQty ?? 0);
        const effectiveDispensedQty = status === 'dispensed'
            ? Number(dispensedQty ?? prescribedForTransition)
            : null;

        const updated = await updateItem(pk, sk, {
            updateExpression: 'SET #status = :status, updatedAt = :now, #statusBy = :actor, #statusAt = :now, #statusReason = :reason, invoiceId = :invoiceId, dispensedQty = :dispensedQty',
            expressionAttributeNames: {
                '#status': 'status',
                '#statusBy': transitionByKey,
                '#statusAt': transitionAtKey,
                '#statusReason': statusReasonKey,
            },
            expressionAttributeValues: {
                ':status': status,
                ':now': now,
                ':actor': auth.sub,
                ':reason': reason || null,
                ':invoiceId': invoiceId || current.invoiceId || null,
                ':dispensedQty': effectiveDispensedQty,
            },
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_refills',
            refillId,
            'status_change',
            auth.sub,
            {
                status: currentStatus,
                invoiceId: current.invoiceId || null,
                dispensedQty: current.dispensedQty ?? null,
            },
            {
                status: updated?.status || status,
                invoiceId: updated?.invoiceId || invoiceId || current.invoiceId || null,
                dispensedQty: effectiveDispensedQty,
            },
            { source: 'pharmacy.updateRefillStatus' },
        );

        logAudit({
            action: 'REFILL_STATUS_TRANSITION',
            resource: 'pharmacy_refill',
            resourceId: refillId,
            metadata: {
                prescriptionId: current.prescriptionId,
                patientName: current.patientName,
                drugName: current.drugName,
                previousStatus: currentStatus,
                nextStatus: status,
                dispensedQty: effectiveDispensedQty,
                reason: reason || null,
                invoiceId: updated?.invoiceId || invoiceId || current.invoiceId || null,
                actorId: auth.sub,
                transitionedAt: now,
            },
        }).catch(() => { });

        return response.success({
            id: refillId,
            previousStatus: currentStatus,
            status: updated?.status || status,
            updatedAt: now,
            invoiceId: updated?.invoiceId || invoiceId || null,
        });
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/prescriptions/refills/backfill
// ============================================================================
// Legacy data repair endpoint for old refill rows missing productId/prescribedQty.
// Restricted to owner/manager. No status transition.
// ============================================================================
export const backfillRefillTrace = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(refillBackfillSchema, event);
        if (!parsed.success) return parsed.error;

        const { refillId, productId, prescribedQty } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `RXREFILL#${refillId}`;
        const current = await getItem<Record<string, any>>(pk, sk);
        if (!current) return response.notFound('Refill request');

        const now = new Date().toISOString();
        const updated = await updateItem(pk, sk, {
            updateExpression: 'SET productId = :productId, prescribedQty = :prescribedQty, updatedAt = :now, traceBackfilledBy = :actor, traceBackfilledAt = :now',
            expressionAttributeValues: {
                ':productId': productId,
                ':prescribedQty': prescribedQty,
                ':now': now,
                ':actor': auth.sub,
            },
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_refills',
            refillId,
            'update',
            auth.sub,
            {
                productId: current.productId ?? null,
                prescribedQty: current.prescribedQty ?? null,
            },
            {
                productId: updated?.productId || productId,
                prescribedQty: updated?.prescribedQty || prescribedQty,
            },
            { source: 'pharmacy.backfillRefillTrace' },
        );

        logAudit({
            action: 'REFILL_TRACE_BACKFILL',
            resource: 'pharmacy_refill',
            resourceId: refillId,
            metadata: {
                previousProductId: current.productId ?? null,
                nextProductId: updated?.productId || productId,
                previousPrescribedQty: current.prescribedQty ?? null,
                nextPrescribedQty: updated?.prescribedQty || prescribedQty,
                actorId: auth.sub,
                backfilledAt: now,
            },
        }).catch(() => { });

        return response.success({
            id: refillId,
            productId: updated?.productId || productId,
            prescribedQty: updated?.prescribedQty || prescribedQty,
            updatedAt: now,
        });
    },
    PHARMACY_OPTS,
);

// ============================================================================
// GET /pharmacy/prescriptions/refills/incomplete
// ============================================================================
// Lists legacy refill rows that still miss product traceability fields.
// ============================================================================
export const listIncompleteRefills = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(refillIncompleteQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { page, pageSize, cursor } = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const filterExpression = '(attribute_not_exists(productId) OR productId = :emptyProductId) OR (attribute_not_exists(prescribedQty) OR prescribedQty <= :zeroQty)';
        const expressionAttributeValues = {
            ':emptyProductId': '',
            ':zeroQty': 0,
        };

        let startKey = decodeCursor(cursor);
        if (!startKey && page > 1) {
            let skipPages = page - 1;
            while (skipPages > 0) {
                let skipped = 0;
                while (skipped < pageSize) {
                    const prefetch: { items: Record<string, any>[]; lastKey?: Record<string, unknown> } =
                        await queryItems<Record<string, any>>(pk, 'RXREFILL#', {
                            scanIndexForward: false,
                            limit: Math.max(pageSize * 2, 100),
                            exclusiveStartKey: startKey,
                            filterExpression,
                            expressionAttributeValues,
                        });
                    skipped += prefetch.items.length;
                    startKey = prefetch.lastKey;
                    if (!startKey) break;
                }
                if (!startKey) break;
                skipPages--;
            }
        }

        const collected: Record<string, any>[] = [];
        let pageLastKey = startKey;
        do {
            const chunk = await queryItems<Record<string, any>>(pk, 'RXREFILL#', {
                scanIndexForward: false,
                limit: Math.max(pageSize * 2, 100),
                exclusiveStartKey: pageLastKey,
                filterExpression,
                expressionAttributeValues,
            });
            collected.push(...chunk.items);
            pageLastKey = chunk.lastKey;
        } while (collected.length < pageSize && pageLastKey);

        const rows = collected.slice(0, pageSize);
        const nextCursor = encodeCursor(pageLastKey);
        const hasMore = !!pageLastKey;

        return response.success(
            rows.map((r) => ({
                id: r.id,
                status: r.status,
                prescriptionId: r.prescriptionId,
                patientName: r.patientName,
                drugName: r.drugName,
                requestedQty: r.requestedQty,
                productId: r.productId ?? null,
                prescribedQty: r.prescribedQty ?? null,
                requestedAt: r.requestedAt,
            })),
            200,
            {
                page,
                limit: pageSize,
                nextCursor,
                hasMore,
            },
        );
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/prescriptions/refills/backfill/bulk
// ============================================================================
// Bulk legacy refill patch endpoint.
// Best-effort update with per-row status.
// ============================================================================
export const bulkBackfillRefillTrace = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(refillBulkBackfillSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const pk = Keys.tenantPK(auth.tenantId);
        const isPreview = parsed.data.preview === true;
        const results: Array<{
            refillId: string;
            ok: boolean;
            code?: 'NOT_FOUND' | 'VALIDATION_ERROR' | 'UPDATE_FAILED';
            error?: string;
        }> = [];

        for (const item of parsed.data.items) {
            try {
                const productId = String(item.productId || '').trim();
                const prescribedQty = Number(item.prescribedQty);
                if (!productId || !Number.isFinite(prescribedQty) || prescribedQty <= 0) {
                    results.push({
                        refillId: item.refillId,
                        ok: false,
                        code: 'VALIDATION_ERROR',
                        error: 'Invalid productId or prescribedQty',
                    });
                    continue;
                }

                const sk = `RXREFILL#${item.refillId}`;
                const exists = await getItem<Record<string, any>>(pk, sk);
                if (!exists) {
                    results.push({
                        refillId: item.refillId,
                        ok: false,
                        code: 'NOT_FOUND',
                        error: 'NOT_FOUND',
                    });
                    continue;
                }
                if (isPreview) {
                    results.push({ refillId: item.refillId, ok: true });
                    continue;
                }
                await updateItem(pk, sk, {
                    updateExpression: 'SET productId = :productId, prescribedQty = :prescribedQty, updatedAt = :now, traceBackfilledBy = :actor, traceBackfilledAt = :now',
                    expressionAttributeValues: {
                        ':productId': productId,
                        ':prescribedQty': prescribedQty,
                        ':now': now,
                        ':actor': auth.sub,
                    },
                });
                results.push({ refillId: item.refillId, ok: true });
            } catch (err) {
                results.push({
                    refillId: item.refillId,
                    ok: false,
                    code: 'UPDATE_FAILED',
                    error: (err as Error).message,
                });
            }
        }

        const successCount = results.filter((r) => r.ok).length;
        const failedRows = results.filter((r) => !r.ok);
        await recordRevision(
            auth.tenantId,
            'pharmacy_refill_bulk',
            `bulk-${now}`,
            isPreview ? 'update' : 'status_change',
            auth.sub,
            null,
            {
                preview: isPreview,
                total: results.length,
                successCount,
                failedCount: failedRows.length,
                failedRows: failedRows.slice(0, 50),
            },
            { source: 'pharmacy.bulkBackfillRefillTrace' },
        );
        logAudit({
            action: isPreview ? 'REFILL_BULK_BACKFILL_PREVIEW' : 'REFILL_BULK_BACKFILL_APPLY',
            resource: 'pharmacy_refill_bulk',
            resourceId: `bulk-${now}`,
            metadata: {
                total: results.length,
                successCount,
                failedCount: failedRows.length,
                failedRows: failedRows.slice(0, 50),
                actorId: auth.sub,
                processedAt: now,
            },
        }).catch(() => { });

        return response.success({
            preview: isPreview,
            total: results.length,
            successCount,
            failedCount: results.length - successCount,
            wouldUpdateCount: isPreview ? successCount : undefined,
            updatedCount: !isPreview ? successCount : undefined,
            results,
            processedAt: now,
        });
    },
    PHARMACY_OPTS,
);

// ============================================================================
// POST /pharmacy/prescriptions/partial-fills
// ============================================================================
// Tracks partial dispense ledger for legal completion monitoring.
// ============================================================================
export const recordPartialFill = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(partialFillSchema, event);
        if (!parsed.success) return parsed.error;

        const payload = parsed.data;
        const now = new Date().toISOString();
        const id = uuidv4();
        const remainingQty = payload.prescribedQty - payload.dispensedQty;
        const completionStatus = remainingQty > 0 ? 'partial' : 'completed';

        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `RXPARTIAL#${payload.prescriptionId}#${now}#${id}`,
            entityType: 'RX_PARTIAL_FILL',
            id,
            tenantId: auth.tenantId,
            prescriptionId: payload.prescriptionId,
            invoiceId: payload.invoiceId,
            productId: payload.productId,
            productName: payload.productName,
            prescribedQty: payload.prescribedQty,
            dispensedQty: payload.dispensedQty,
            remainingQty,
            completionStatus,
            reason: payload.reason || null,
            recordedBy: auth.sub,
            recordedAt: now,
            createdAt: now,
            updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_partial_fills',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                prescriptionId: payload.prescriptionId,
                invoiceId: payload.invoiceId,
                productId: payload.productId,
                prescribedQty: payload.prescribedQty,
                dispensedQty: payload.dispensedQty,
                remainingQty,
                completionStatus,
            },
            { source: 'pharmacy.recordPartialFill' },
        );

        return response.success({
            id,
            prescriptionId: payload.prescriptionId,
            dispensedQty: payload.dispensedQty,
            remainingQty,
            completionStatus,
            recordedAt: now,
        }, 201);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// Exported helper for invoice.service.ts integration
// ============================================================================
// Called from createInvoice() when a Schedule X drug line item is detected.
// Returns a DynamoDB Put transactItem for NARCOTICLOG# that gets included
// in the same transactWrite() as the invoice for atomicity.
// ============================================================================

export interface NarcoticLogTransactInput {
    tenantId: string;
    invoiceId: string;
    productName: string;
    quantitySold: number;
    batchNumber: string | null;
    expiryDate: string | null;
    dispensedBy: string;
    /** Invoice-level metadata containing patient/doctor info */
    metadata: Record<string, unknown>;
}

/**
 * Build a DynamoDB Put transactItem for NARCOTICLOG#.
 * Returns null if required NDPS fields are missing (caller should reject the invoice).
 */
export function buildNarcoticLogTransactItem(
    input: NarcoticLogTransactInput,
): { Put: any } | null {
    const {
        tenantId, invoiceId, productName, quantitySold,
        batchNumber, expiryDate, dispensedBy, metadata,
    } = input;

    const patientName = metadata.patientName as string | undefined;
    const patientAddress = metadata.patientAddress as string | undefined;
    const prescribingDoctorName = (metadata.doctorName || metadata.prescribingDoctorName) as string | undefined;
    const doctorRegNo = metadata.doctorRegNo as string | undefined;
    const prescriptionId = metadata.prescriptionId as string | undefined;

    // All fields are mandatory for Schedule X per NDPS Act
    if (!patientName || !patientAddress || !prescribingDoctorName || !doctorRegNo || !prescriptionId) {
        return null; // Caller will throw InvoiceError
    }

    const now = new Date().toISOString();
    const tableName = config.dynamodb.tableName;

    return {
        Put: {
            TableName: tableName,
            Item: {
                PK: Keys.tenantPK(tenantId),
                SK: `NARCOTICLOG#${invoiceId}#${now}`,
                entityType: 'NARCOTIC_LOG',
                tenantId,
                patientName,
                patientAddress,
                prescribingDoctorName,
                doctorRegNo,
                prescriptionId,
                drugName: productName,
                scheduleType: 'X',
                quantitySold,
                batchNumber: batchNumber || 'N/A',
                expiryDate: expiryDate || 'N/A',
                dispensedBy,
                dispensedAt: now,
                invoiceId,
                createdAt: now,
            },
        },
    };
}

/**
 * Build a DynamoDB Put transactItem for H1LOG#.
 *
 * Per Drugs and Cosmetics Rules, 1945 (Schedule H1 Rule), pharmacies must
 * record patientName, prescribingDoctorName, doctorRegNo, prescriptionId,
 * drugName, qty, batchNumber, expiryDate for every H1 sale. patientAddress
 * is recommended but not strictly mandated.
 *
 * Returns null if any required H1 register field is missing — caller MUST
 * reject the invoice.
 */
export function buildH1RegisterTransactItem(
    input: NarcoticLogTransactInput,
): { Put: any } | null {
    const {
        tenantId, invoiceId, productName, quantitySold,
        batchNumber, expiryDate, dispensedBy, metadata,
    } = input;

    const patientName = metadata.patientName as string | undefined;
    const patientAddress = (metadata.patientAddress as string | undefined) || null;
    const prescribingDoctorName = (metadata.doctorName || metadata.prescribingDoctorName) as string | undefined;
    const doctorRegNo = metadata.doctorRegNo as string | undefined;
    const prescriptionId = metadata.prescriptionId as string | undefined;

    if (!patientName || !prescribingDoctorName || !doctorRegNo || !prescriptionId) {
        return null;
    }

    const now = new Date().toISOString();
    const tableName = config.dynamodb.tableName;

    return {
        Put: {
            TableName: tableName,
            Item: {
                PK: Keys.tenantPK(tenantId),
                SK: `H1LOG#${invoiceId}#${now}`,
                entityType: 'H1_LOG',
                tenantId,
                patientName,
                patientAddress,
                prescribingDoctorName,
                doctorRegNo,
                prescriptionId,
                drugName: productName,
                scheduleType: 'H1',
                quantitySold,
                batchNumber: batchNumber || 'N/A',
                expiryDate: expiryDate || 'N/A',
                dispensedBy,
                dispensedAt: now,
                invoiceId,
                createdAt: now,
            },
        },
    };
}

function nextCoordinationLevel(current: 'primary' | 'secondary' | 'tertiary'): 'secondary' | 'tertiary' | null {
    if (current === 'primary') return 'secondary';
    if (current === 'secondary') return 'tertiary';
    return null;
}

export const transmitNcpdpClaim = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(claimTransmitSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const claimId = uuidv4();
        const payload = parsed.data;
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `RXCLAIM#${claimId}`;

        await putItem({
            PK: pk,
            SK: sk,
            entityType: 'RX_CLAIM',
            GSI1PK: `TENANT#${auth.tenantId}#ENTITY#RX_CLAIM`,
            GSI1SK: `${now}#${claimId}`,
            id: claimId,
            tenantId: auth.tenantId,
            patientId: payload.patientId,
            prescriptionId: payload.prescriptionId,
            pharmacyNpi: payload.pharmacyNpi,
            payerId: payload.payerId,
            lines: payload.lines,
            standard: 'NCPDP_D0',
            status: 'submitted',
            coordinationLevel: payload.coordinationLevel,
            priorAuthId: payload.priorAuthId || null,
            metadata: payload.metadata || {},
            submittedAt: now,
            adjudicatedAt: null,
            createdAt: now,
            updatedAt: now,
            submittedBy: auth.sub,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_claims',
            claimId,
            'create',
            auth.sub,
            null,
            {
                id: claimId,
                status: 'submitted',
                prescriptionId: payload.prescriptionId,
                payerId: payload.payerId,
                coordinationLevel: payload.coordinationLevel,
            },
            { source: 'pharmacy.transmitNcpdpClaim' },
        );

        return response.success({
            id: claimId,
            status: 'submitted',
            standard: 'NCPDP_D0',
            coordinationLevel: payload.coordinationLevel,
            submittedAt: now,
        }, 201);
    },
    PHARMACY_OPTS,
);

export const adjudicateClaim = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const claimId = event.pathParameters?.id;
        if (!claimId) return response.badRequest('Missing claim id');

        const parsed = parseBody(claimAdjudicationSchema, event);
        if (!parsed.success) return parsed.error;

        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `RXCLAIM#${claimId}`;
        const claim = await getItem<Record<string, any>>(pk, sk);
        if (!claim) return response.notFound('Claim');
        if (claim.status === 'approved' || claim.status === 'rejected') {
            return response.error(409, 'CLAIM_ALREADY_FINALIZED', 'Claim already finalized');
        }

        const now = new Date().toISOString();
        const updated = await updateItem(pk, sk, {
            updateExpression: 'SET #status = :status, payerClaimRef = :payerClaimRef, rejectCodes = :rejectCodes, approvedAmountPaise = :approvedAmountPaise, patientPayPaise = :patientPayPaise, adjudicationNotes = :notes, adjudicatedBy = :actor, adjudicatedAt = :now, updatedAt = :now',
            expressionAttributeNames: { '#status': 'status' },
            expressionAttributeValues: {
                ':status': parsed.data.outcome,
                ':payerClaimRef': parsed.data.payerClaimRef || null,
                ':rejectCodes': parsed.data.rejectCodes || [],
                ':approvedAmountPaise': parsed.data.approvedAmountPaise ?? null,
                ':patientPayPaise': parsed.data.patientPayPaise ?? null,
                ':notes': parsed.data.notes || null,
                ':actor': auth.sub,
                ':now': now,
            },
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_claims',
            claimId,
            'status_change',
            auth.sub,
            {
                status: claim.status,
                payerClaimRef: claim.payerClaimRef || null,
            },
            {
                status: updated?.status || parsed.data.outcome,
                payerClaimRef: updated?.payerClaimRef || parsed.data.payerClaimRef || null,
            },
            { source: 'pharmacy.adjudicateClaim' },
        );

        return response.success({
            id: claimId,
            status: updated?.status || parsed.data.outcome,
            payerClaimRef: updated?.payerClaimRef || parsed.data.payerClaimRef || null,
            adjudicatedAt: now,
        });
    },
    PHARMACY_OPTS,
);

export const createNextCobClaim = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const claimId = event.pathParameters?.id;
        if (!claimId) return response.badRequest('Missing claim id');

        const parsed = parseBody(claimCobNextSchema, event);
        if (!parsed.success) return parsed.error;

        const pk = Keys.tenantPK(auth.tenantId);
        const current = await getItem<Record<string, any>>(pk, `RXCLAIM#${claimId}`);
        if (!current) return response.notFound('Claim');
        if (String(current.status || '').toLowerCase() !== 'rejected') {
            return response.error(409, 'COB_ALLOWED_ONLY_AFTER_REJECT', 'COB next claim allowed only after rejection');
        }

        const currentLevel = (current.coordinationLevel || 'primary') as 'primary' | 'secondary' | 'tertiary';
        const nextLevel = nextCoordinationLevel(currentLevel);
        if (!nextLevel) {
            return response.error(409, 'COB_CHAIN_COMPLETE', 'Claim already at tertiary COB level');
        }
        if (String(current.payerId || '') === String(parsed.data.nextPayerId || '')) {
            return response.error(409, 'COB_DUPLICATE_PAYER', 'Next COB payer must be different from current payer');
        }

        const now = new Date().toISOString();
        const nextId = uuidv4();
        await putItem({
            PK: pk,
            SK: `RXCLAIM#${nextId}`,
            entityType: 'RX_CLAIM',
            GSI1PK: `TENANT#${auth.tenantId}#ENTITY#RX_CLAIM`,
            GSI1SK: `${now}#${nextId}`,
            id: nextId,
            tenantId: auth.tenantId,
            parentClaimId: claimId,
            patientId: current.patientId,
            prescriptionId: current.prescriptionId,
            pharmacyNpi: current.pharmacyNpi,
            payerId: parsed.data.nextPayerId,
            lines: current.lines || [],
            standard: 'NCPDP_D0',
            status: 'submitted',
            coordinationLevel: nextLevel,
            cobReason: parsed.data.reason || null,
            submittedAt: now,
            adjudicatedAt: null,
            createdAt: now,
            updatedAt: now,
            submittedBy: auth.sub,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_claims',
            nextId,
            'create',
            auth.sub,
            null,
            {
                id: nextId,
                parentClaimId: claimId,
                status: 'submitted',
                payerId: parsed.data.nextPayerId,
                coordinationLevel: nextLevel,
            },
            { source: 'pharmacy.createNextCobClaim' },
        );

        return response.success({
            id: nextId,
            parentClaimId: claimId,
            coordinationLevel: nextLevel,
            status: 'submitted',
        }, 201);
    },
    PHARMACY_OPTS,
);

export const createPriorAuthorization = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(priorAuthCreateSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const id = uuidv4();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `RXPA#${id}`,
            entityType: 'RX_PRIOR_AUTH',
            GSI1PK: `TENANT#${auth.tenantId}#ENTITY#RX_PRIOR_AUTH`,
            GSI1SK: `${now}#${id}`,
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            status: 'submitted',
            authorizationCode: null,
            createdBy: auth.sub,
            createdAt: now,
            updatedAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_prior_auth',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                status: 'submitted',
                patientId: parsed.data.patientId,
                prescriptionId: parsed.data.prescriptionId,
                payerId: parsed.data.payerId,
            },
            { source: 'pharmacy.createPriorAuthorization' },
        );

        return response.success({ id, status: 'submitted', createdAt: now }, 201);
    },
    PHARMACY_OPTS,
);

export const listClaims = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(claimListQuerySchema, event);
        if (!parsed.success) return parsed.error;

        const { status, coordinationLevel, page, pageSize, cursor } = parsed.data;
        let { rows: filtered, nextCursor, hasMore } = await queryFilteredPage(
            `TENANT#${auth.tenantId}#ENTITY#RX_CLAIM`,
            '',
            pageSize,
            cursor,
            (item) => (!status || item.status === status) &&
                (!coordinationLevel || item.coordinationLevel === coordinationLevel),
            'GSI1',
        );
        if (!cursor && filtered.length === 0) {
            // Backward compatibility: support legacy rows written before GSI fields.
            const fallback = await queryFilteredPage(
                Keys.tenantPK(auth.tenantId),
                'RXCLAIM#',
                pageSize,
                undefined,
                (item) => (!status || item.status === status) &&
                    (!coordinationLevel || item.coordinationLevel === coordinationLevel),
            );
            filtered = fallback.rows;
            nextCursor = fallback.nextCursor;
            hasMore = fallback.hasMore;
        }

        const rows = sortByRecent(filtered, ['updatedAt', 'submittedAt', 'createdAt']).map((item) => ({
            id: item.id,
            parentClaimId: item.parentClaimId || null,
            prescriptionId: item.prescriptionId,
            payerId: item.payerId,
            status: item.status,
            coordinationLevel: item.coordinationLevel,
            submittedAt: item.submittedAt,
            adjudicatedAt: item.adjudicatedAt || null,
        }));
        return response.success(rows, 200, {
            page,
            limit: pageSize,
            hasMore,
            nextCursor,
        });
    },
    PHARMACY_OPTS,
);

export const getClaimById = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const claimId = event.pathParameters?.id;
        if (!claimId) return response.badRequest('Missing claim id');
        const item = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `RXCLAIM#${claimId}`);
        if (!item) return response.notFound('Claim');
        return response.success({
            id: item.id,
            parentClaimId: item.parentClaimId || null,
            patientId: item.patientId,
            prescriptionId: item.prescriptionId,
            payerId: item.payerId,
            payerBin: item.payerBin || null,
            payerPcn: item.payerPcn || null,
            memberId: item.memberId || null,
            groupId: item.groupId || null,
            standard: item.standard,
            status: item.status,
            coordinationLevel: item.coordinationLevel,
            lines: item.lines || [],
            adjudicatedAt: item.adjudicatedAt || null,
            submittedAt: item.submittedAt,
            updatedAt: item.updatedAt,
        });
    },
    PHARMACY_OPTS,
);

export const updatePriorAuthorization = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const priorAuthId = event.pathParameters?.id;
        if (!priorAuthId) return response.badRequest('Missing prior authorization id');

        const parsed = parseBody(priorAuthUpdateSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const current = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `RXPA#${priorAuthId}`);
        if (!current) return response.notFound('Prior authorization');
        const updated = await updateItem(Keys.tenantPK(auth.tenantId), `RXPA#${priorAuthId}`, {
            updateExpression: 'SET #status = :status, authorizationCode = :authorizationCode, notes = :notes, updatedBy = :actor, updatedAt = :now, GSI1SK = :gsi1sk',
            expressionAttributeNames: { '#status': 'status' },
            expressionAttributeValues: {
                ':status': parsed.data.status,
                ':authorizationCode': parsed.data.authorizationCode || null,
                ':notes': parsed.data.notes || null,
                ':actor': auth.sub,
                ':now': now,
                ':gsi1sk': `${now}#${priorAuthId}`,
            },
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_prior_auth',
            priorAuthId,
            'status_change',
            auth.sub,
            {
                status: current.status || null,
                authorizationCode: current.authorizationCode || null,
            },
            {
                status: updated?.status || parsed.data.status,
                authorizationCode: updated?.authorizationCode || parsed.data.authorizationCode || null,
            },
            { source: 'pharmacy.updatePriorAuthorization' },
        );

        return response.success({
            id: priorAuthId,
            status: updated?.status || parsed.data.status,
            authorizationCode: updated?.authorizationCode || parsed.data.authorizationCode || null,
            updatedAt: now,
        });
    },
    PHARMACY_OPTS,
);

export const listPriorAuthorizations = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(priorAuthListQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { status, page, pageSize, cursor } = parsed.data;
        let { rows: filtered, nextCursor, hasMore } = await queryFilteredPage(
            `TENANT#${auth.tenantId}#ENTITY#RX_PRIOR_AUTH`,
            '',
            pageSize,
            cursor,
            (item) => !status || item.status === status,
            'GSI1',
        );
        if (!cursor && filtered.length === 0) {
            const fallback = await queryFilteredPage(
                Keys.tenantPK(auth.tenantId),
                'RXPA#',
                pageSize,
                undefined,
                (item) => !status || item.status === status,
            );
            filtered = fallback.rows;
            nextCursor = fallback.nextCursor;
            hasMore = fallback.hasMore;
        }
        const rows = sortByRecent(filtered, ['updatedAt', 'createdAt']).map((item) => ({
            id: item.id,
            patientId: item.patientId,
            prescriptionId: item.prescriptionId,
            payerId: item.payerId,
            productId: item.productId,
            status: item.status,
            authorizationCode: item.authorizationCode || null,
            updatedAt: item.updatedAt,
        }));
        return response.success(rows, 200, {
            page,
            limit: pageSize,
            hasMore,
            nextCursor,
        });
    },
    PHARMACY_OPTS,
);

export const getPriorAuthorizationById = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const priorAuthId = event.pathParameters?.id;
        if (!priorAuthId) return response.badRequest('Missing prior authorization id');
        const item = await getItem<Record<string, any>>(Keys.tenantPK(auth.tenantId), `RXPA#${priorAuthId}`);
        if (!item) return response.notFound('Prior authorization');
        return response.success({
            id: item.id,
            patientId: item.patientId,
            prescriptionId: item.prescriptionId,
            productId: item.productId,
            payerId: item.payerId,
            reason: item.reason,
            diagnosisCodes: item.diagnosisCodes || [],
            status: item.status,
            authorizationCode: item.authorizationCode || null,
            notes: item.notes || null,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
        });
    },
    PHARMACY_OPTS,
);

export const runClinicalScreening = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, _auth: AuthContext) => {
        const parsed = parseBody(cdsScreenSchema, event);
        if (!parsed.success) return parsed.error;

        const alerts: Array<Record<string, unknown>> = [];
        const patientAllergies = new Set((parsed.data.patient.allergies || []).map((v) => v.toLowerCase()));

        for (const d of parsed.data.drugs) {
            if ((d.ingredients || []).some((i) => patientAllergies.has(i.toLowerCase()))) {
                alerts.push({ type: 'allergy', severity: 'high', drugName: d.drugName });
            }
            if ((d.maxDosePerDay || 0) > 0 && (d.dosePerDay || 0) > (d.maxDosePerDay || 0)) {
                alerts.push({
                    type: 'dose_adjustment',
                    severity: 'high',
                    drugName: d.drugName,
                    dosePerDay: d.dosePerDay,
                    maxDosePerDay: d.maxDosePerDay,
                });
            }
            if (parsed.data.patient.pregnant && d.pregnancyRisk === 'avoid') {
                alerts.push({ type: 'pregnancy', severity: 'high', drugName: d.drugName });
            }
            if (parsed.data.patient.lactating && d.lactationRisk === 'avoid') {
                alerts.push({ type: 'lactation', severity: 'high', drugName: d.drugName });
            }
            if (parsed.data.patient.renalImpairment && (d.contraindications || []).includes('renal_impairment')) {
                alerts.push({ type: 'contraindication', severity: 'high', drugName: d.drugName, condition: 'renal_impairment' });
            }
            if (parsed.data.patient.hepaticImpairment && (d.contraindications || []).includes('hepatic_impairment')) {
                alerts.push({ type: 'contraindication', severity: 'high', drugName: d.drugName, condition: 'hepatic_impairment' });
            }
        }

        for (let i = 0; i < parsed.data.drugs.length; i++) {
            for (let j = i + 1; j < parsed.data.drugs.length; j++) {
                const a = parsed.data.drugs[i];
                const b = parsed.data.drugs[j];
                const aTags = new Set((a.interactionTags || []).map((v) => v.toLowerCase()));
                const bTags = (b.interactionTags || []).map((v) => v.toLowerCase());
                if (bTags.some((tag) => aTags.has(tag))) {
                    alerts.push({
                        type: 'interaction',
                        severity: 'moderate',
                        drugs: [a.drugName, b.drugName],
                    });
                }
            }
        }

        return response.success({
            alertCount: alerts.length,
            alerts,
            categoriesCovered: ['interaction', 'allergy', 'contraindication', 'pregnancy', 'lactation', 'dose_adjustment'],
        });
    },
    PHARMACY_OPTS,
);

export const listDrugMasterMappings = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(drugMasterListQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { productId, page, pageSize, cursor } = parsed.data;
        let { rows: filtered, nextCursor, hasMore } = await queryFilteredPage(
            `TENANT#${auth.tenantId}#ENTITY#DRUG_MASTER_MAPPING`,
            '',
            pageSize,
            cursor,
            (item) => !productId || item.productId === productId,
            'GSI1',
        );
        if (!cursor && filtered.length === 0) {
            const fallback = await queryFilteredPage(
                Keys.tenantPK(auth.tenantId),
                'DRUGMAP#',
                pageSize,
                undefined,
                (item) => !productId || item.productId === productId,
            );
            filtered = fallback.rows;
            nextCursor = fallback.nextCursor;
            hasMore = fallback.hasMore;
        }
        const rows = sortByRecent(filtered, ['updatedAt', 'createdAt']).map((item) => ({
            productId: item.productId,
            ndc: item.ndc,
            rxNorm: item.rxNorm,
            atc: item.atc,
            indiaBrandCode: item.indiaBrandCode || null,
            indiaBrandName: item.indiaBrandName || null,
            manufacturer: item.manufacturer || null,
            updatedAt: item.updatedAt,
        }));
        return response.success(rows, 200, {
            page,
            limit: pageSize,
            hasMore,
            nextCursor,
        });
    },
    PHARMACY_OPTS,
);

export const upsertDrugMasterMapping = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(drugMasterMappingSchema, event);
        if (!parsed.success) return parsed.error;
        const now = new Date().toISOString();
        const data = parsed.data;
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `DRUGMAP#${data.productId}`,
            entityType: 'DRUG_MASTER_MAPPING',
            GSI1PK: `TENANT#${auth.tenantId}#ENTITY#DRUG_MASTER_MAPPING`,
            GSI1SK: `${now}#${data.productId}`,
            tenantId: auth.tenantId,
            ...data,
            createdAt: now,
            updatedAt: now,
            updatedBy: auth.sub,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_drug_mapping',
            data.productId,
            'update',
            auth.sub,
            null,
            {
                productId: data.productId,
                ndc: data.ndc,
                rxNorm: data.rxNorm,
                atc: data.atc,
            },
            { source: 'pharmacy.upsertDrugMasterMapping' },
        );
        return response.success({ productId: data.productId, mapped: true, updatedAt: now }, 201);
    },
    PHARMACY_OPTS,
);

export const upsertFormulary = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(formularyUpsertSchema, event);
        if (!parsed.success) return parsed.error;
        const now = new Date().toISOString();
        const data = parsed.data;
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `FORMULARY#${data.formularyId}`,
            entityType: 'FORMULARY',
            GSI1PK: `TENANT#${auth.tenantId}#ENTITY#FORMULARY`,
            GSI1SK: `${now}#${data.formularyId}`,
            tenantId: auth.tenantId,
            ...data,
            createdAt: now,
            updatedAt: now,
            updatedBy: auth.sub,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_formulary',
            data.formularyId,
            'update',
            auth.sub,
            null,
            {
                formularyId: data.formularyId,
                payerId: data.payerId,
                name: data.name,
                productCount: Array.isArray(data.products) ? data.products.length : 0,
            },
            { source: 'pharmacy.upsertFormulary' },
        );
        return response.success({ formularyId: data.formularyId, productCount: data.products.length, updatedAt: now }, 201);
    },
    PHARMACY_OPTS,
);

export const listFormulary = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseQuery(formularyListQuerySchema, event);
        if (!parsed.success) return parsed.error;
        const { payerId, page, pageSize, cursor } = parsed.data;
        let { rows: filtered, nextCursor, hasMore } = await queryFilteredPage(
            `TENANT#${auth.tenantId}#ENTITY#FORMULARY`,
            '',
            pageSize,
            cursor,
            (item) => !payerId || item.payerId === payerId,
            'GSI1',
        );
        if (!cursor && filtered.length === 0) {
            const fallback = await queryFilteredPage(
                Keys.tenantPK(auth.tenantId),
                'FORMULARY#',
                pageSize,
                undefined,
                (item) => !payerId || item.payerId === payerId,
            );
            filtered = fallback.rows;
            nextCursor = fallback.nextCursor;
            hasMore = fallback.hasMore;
        }
        const rows = sortByRecent(filtered, ['updatedAt', 'createdAt']).map((item) => ({
            formularyId: item.formularyId,
            payerId: item.payerId,
            name: item.name,
            productCount: Array.isArray(item.products) ? item.products.length : 0,
            updatedAt: item.updatedAt,
        }));
        return response.success(rows, 200, {
            page,
            limit: pageSize,
            hasMore,
            nextCursor,
        });
    },
    PHARMACY_OPTS,
);

export const recordProgramTrackEvent = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(programTrackEventSchema, event);
        if (!parsed.success) return parsed.error;

        const now = new Date().toISOString();
        const id = uuidv4();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `RXPROGRAM#${parsed.data.programType}#${now}#${id}`,
            entityType: 'RX_PROGRAM_EVENT',
            id,
            tenantId: auth.tenantId,
            ...parsed.data,
            recordedBy: auth.sub,
            createdAt: now,
        });
        await recordRevision(
            auth.tenantId,
            'pharmacy_program_events',
            id,
            'create',
            auth.sub,
            null,
            {
                id,
                programType: parsed.data.programType,
                prescriptionId: parsed.data.prescriptionId,
            },
            { source: 'pharmacy.recordProgramTrackEvent' },
        );
        return response.success({ id, recordedAt: now }, 201);
    },
    PHARMACY_OPTS,
);

// ============================================================================
// FEFO OVERRIDE — Backend-Authorized Supervisor PIN Verification
// ----------------------------------------------------------------------------
// Replaces the previous client-side hardcoded supervisor PIN. The frontend
// posts the cashier-typed PIN here; the backend verifies against the caller
// user's stored `managerPin`/`overridePin`/`pin`, optionally falling back to
// a master env PIN, and writes a tamper-evident audit row.
//
// Roles allowed to call: OWNER, MANAGER, STAFF (the cashier requesting the
// override). The PIN itself is matched against the caller's user record;
// if a different supervisor PIN is required (e.g. shared device), the env
// PHARMACY_FEFO_OVERRIDE_MASTER_PIN may be configured.
// ============================================================================

const PHARMACY_FEFO_OVERRIDE_MASTER_PIN =
    config.pharmacy.fefoOverrideMasterPin || '';

export const authorizeFefoOverride = authorizedHandler(
    [UserRole.OWNER, UserRole.MANAGER, UserRole.STAFF],
    async (event: APIGatewayProxyEventV2, _context: Context, auth: AuthContext) => {
        const parsed = parseBody(fefoOverrideAuthorizeSchema, event);
        if (!parsed.success) return parsed.error;

        const data = parsed.data;
        const tenantId = auth.tenantId;
        const pk = Keys.tenantPK(tenantId);

        // 1. Fetch caller user record to obtain stored PIN.
        const user = await getItem<Record<string, any>>(pk, Keys.userSK(auth.sub));
        if (!user || user.isDeleted) {
            logger.warn('FEFO override: caller user not found', { tenantId, sub: auth.sub });
            return response.error(404, 'USER_NOT_FOUND', 'Caller user record not found');
        }

        const expectedPin = String(
            user.fefoOverridePin
            || user.managerPin
            || user.overridePin
            || user.pin
            || '',
        );
        const masterPin = PHARMACY_FEFO_OVERRIDE_MASTER_PIN.trim();

        const matchesUserPin = expectedPin && data.supervisorPin === expectedPin;
        const matchesMaster = masterPin && data.supervisorPin === masterPin;

        if (!matchesUserPin && !matchesMaster) {
            logger.warn('FEFO override: invalid PIN', { tenantId, sub: auth.sub });
            // Audit failed attempts so abuse is visible to drug-inspector audits.
            logAudit({
                action: 'FEFO_OVERRIDE_REJECTED',
                resource: 'pharmacy_fefo_override',
                resourceId: data.productId || 'unknown',
                metadata: {
                    productId: data.productId,
                    autoSelectedBatchId: data.autoSelectedBatchId,
                    selectedBatchId: data.selectedBatchId,
                    reason: data.reason,
                    rejectionCause: matchesMaster ? 'unexpected' : 'pin_mismatch',
                },
            }).catch(() => { });
            return response.error(401, 'INVALID_PIN', 'Invalid supervisor PIN');
        }

        const now = new Date().toISOString();
        const overrideId = uuidv4();

        // 2. Persist tamper-evident audit record (FEFOOVR# in single-table).
        await putItem({
            PK: pk,
            SK: `FEFOOVR#${now}#${overrideId}`,
            entityType: 'FEFO_OVERRIDE_AUDIT',
            tenantId,
            id: overrideId,
            authorizedBy: auth.sub,
            authorizedAt: now,
            authorizedRole: auth.role,
            productId: data.productId || null,
            autoSelectedBatchId: data.autoSelectedBatchId || null,
            selectedBatchId: data.selectedBatchId || null,
            reason: data.reason || null,
            usedMasterPin: !matchesUserPin && matchesMaster,
            createdAt: now,
        });

        logAudit({
            action: 'FEFO_OVERRIDE_APPROVED',
            resource: 'pharmacy_fefo_override',
            resourceId: overrideId,
            metadata: {
                productId: data.productId,
                autoSelectedBatchId: data.autoSelectedBatchId,
                selectedBatchId: data.selectedBatchId,
                usedMasterPin: !matchesUserPin && matchesMaster,
                reason: data.reason,
            },
        }).catch(() => { });

        return response.success({
            authorized: true,
            overrideId,
            authorizedAt: now,
            authorizedBy: auth.sub,
            usedMasterPin: !matchesUserPin && matchesMaster,
        });
    },
    PHARMACY_OPTS,
);
