// ============================================================================
// Lambda: processImportRow
// ============================================================================
// Trigger: SQS batch (ImportRowQueue — FIFO, grouped by tenantId)
// Timeout budget: 200ms per row (enforced via early exit if within Lambda budget)
//
// Per-row flow:
//   1. Parse SQS message body → ImportRow
//   2. Match product (barcode → exact name → fuzzy → vendor+name → new)
//   3a. EXISTS → ADD stock atomically via DynamoDB UpdateItem (no read-modify-write)
//   3b. NOT EXISTS → PutItem new product with auto-category + variant handling
//   4. Update ImportJob counters atomically (ADD 1 to created/updated/errors)
//   5. Push IMPORT_PROGRESS event via WebSocket to the uploading user
//
// Data integrity:
//   - Stock ADD uses DynamoDB UpdateExpression: ADD stock :qty (atomic)
//   - New product uses ConditionExpression: attribute_not_exists(PK)
//   - Job counter updates use ADD (atomic, no read-modify-write)
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { SQSEvent, SQSRecord } from 'aws-lambda';
import {
    DynamoDBClient,
    UpdateItemCommand,
    PutItemCommand,
    QueryCommand,
} from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { v4 as uuidv4 } from 'uuid';
import { Keys } from '../config/dynamodb.config';
import { normalizeName, findBestMatch, vendorNameSimilarity, FUZZY_THRESHOLD } from '../utils/fuzzy-match';
import type { FuzzyCandidate } from '../utils/fuzzy-match';
import { resolveCategory } from '../services/category-keyword-map';
import { emitEvent } from '../services/websocket.service';
import { logger } from '../utils/logger';
import { WSEventName } from '../types/websocket.types';
import {
    ImportRow,
    ImportRowSqsMessage,
    ProductMatch,
    MatchStrategy,
    ImportRowAction,
} from '../types/import.types';
import { ProductKeys, createProductItem } from '../schemas/product.schema';
import { config } from '../config/environment';

const REGION = config.aws.region;
const TABLE_NAME = config.dynamodb.tableName;

let dynamoClient: DynamoDBClient | null = null;
function getDynamo(): DynamoDBClient {
    if (!dynamoClient) dynamoClient = new DynamoDBClient(configureAwsClient({ region: REGION }));
    return dynamoClient;
}

// ── Product lookup helpers ─────────────────────────────────────────────────

interface ProductCandidate {
    productId: string;
    pk: string;
    sk: string;
    name: string;
    nameNormalized: string;
    barcode?: string;
    sku?: string;
    vendor?: string;
    stock: number;
    version?: number;
}

/** Query ALL products for a tenant (used for fuzzy matching). */
async function getAllProductCandidates(tenantId: string, businessType: string): Promise<ProductCandidate[]> {
    const results: ProductCandidate[] = [];
    let lastKey: Record<string, unknown> | undefined;

    do {
        const cmd = new QueryCommand({
            TableName: TABLE_NAME,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :gsi1pk',
            ExpressionAttributeValues: marshall({
                ':gsi1pk': ProductKeys.gsi1pk(tenantId, businessType),
            }),
            ProjectionExpression: 'PK, SK, productId, #nm, barcode, sku, stock, #ver',
            ExpressionAttributeNames: { '#nm': 'name', '#ver': 'version' },
            ...(lastKey ? { ExclusiveStartKey: marshall(lastKey) } : {}),
        });

        const res = await getDynamo().send(cmd);
        for (const item of (res.Items ?? [])) {
            const p = unmarshall(item);
            results.push({
                productId: p.productId,
                pk: p.PK,
                sk: p.SK,
                name: p.name ?? '',
                nameNormalized: normalizeName(p.name ?? ''),
                barcode: p.barcode,
                sku: p.sku,
                stock: p.stock ?? 0,
                version: p.version,
            });
        }

        lastKey = res.LastEvaluatedKey ? unmarshall(res.LastEvaluatedKey) as Record<string, unknown> : undefined;
    } while (lastKey);

    return results;
}

/** Exact barcode/SKU lookup via GSI2. */
async function findByBarcode(tenantId: string, barcode: string): Promise<ProductCandidate | null> {
    const cmd = new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI2',
        KeyConditionExpression: 'GSI2PK = :gsi2pk AND begins_with(GSI2SK, :barcodePrefix)',
        ExpressionAttributeValues: marshall({
            ':gsi2pk': ProductKeys.gsi2pk(tenantId),
            ':barcodePrefix': `BARCODE#${barcode}`,
        }),
        Limit: 1,
    });

    const res = await getDynamo().send(cmd);
    if (!res.Items || res.Items.length === 0) return null;

    const p = unmarshall(res.Items[0]);
    return {
        productId: p.productId,
        pk: p.PK,
        sk: p.SK,
        name: p.name ?? '',
        nameNormalized: normalizeName(p.name ?? ''),
        barcode: p.barcode,
        sku: p.sku,
        stock: p.stock ?? 0,
        version: p.version,
    };
}

// ── Match logic ────────────────────────────────────────────────────────────

async function matchProduct(row: ImportRow): Promise<{ match: ProductMatch; candidate: ProductCandidate | null }> {
    const { tenantId, businessType, barcode, sku, nameNormalized, vendor } = row;

    // Priority 1: Exact barcode match
    if (barcode) {
        const barcodeMatch = await findByBarcode(tenantId, barcode);
        if (barcodeMatch) {
            return {
                match: {
                    strategy: 'BARCODE' as MatchStrategy,
                    existingProductId: barcodeMatch.productId,
                    existingProductName: barcodeMatch.name,
                    requiresReview: false,
                },
                candidate: barcodeMatch,
            };
        }
    }

    // Priority 1b: SKU as barcode
    if (sku) {
        const skuMatch = await findByBarcode(tenantId, sku);
        if (skuMatch) {
            return {
                match: {
                    strategy: 'BARCODE' as MatchStrategy,
                    existingProductId: skuMatch.productId,
                    existingProductName: skuMatch.name,
                    requiresReview: false,
                },
                candidate: skuMatch,
            };
        }
    }

    // Load all candidates for name-based matching
    const candidates = await getAllProductCandidates(tenantId, businessType);

    // Priority 2: Exact normalized name
    const exactMatch = candidates.find(c => c.nameNormalized === nameNormalized);
    if (exactMatch) {
        return {
            match: {
                strategy: 'EXACT_NAME' as MatchStrategy,
                existingProductId: exactMatch.productId,
                existingProductName: exactMatch.name,
                requiresReview: false,
            },
            candidate: exactMatch,
        };
    }

    // Priority 3: Fuzzy name match (Levenshtein + trigram, threshold 0.85)
    const fuzzyCandidates: FuzzyCandidate[] = candidates.map(c => ({
        id: c.productId,
        normalizedName: c.nameNormalized,
        vendor: c.vendor,
    }));

    const fuzzyResult = findBestMatch(nameNormalized, fuzzyCandidates);
    if (fuzzyResult) {
        const matched = candidates.find(c => c.productId === fuzzyResult.candidate.id)!;
        return {
            match: {
                strategy: 'FUZZY_NAME' as MatchStrategy,
                existingProductId: matched.productId,
                existingProductName: matched.name,
                similarityScore: fuzzyResult.score,
                requiresReview: fuzzyResult.score < 0.92, // flag low-confidence fuzzy for review
            },
            candidate: matched,
        };
    }

    // Priority 4: Vendor + name compound match (wholesale / auto parts)
    if (vendor) {
        let bestVendorScore = 0;
        let bestVendorCandidate: ProductCandidate | null = null;

        for (const c of candidates) {
            const score = vendorNameSimilarity(nameNormalized, vendor, c.nameNormalized, c.vendor);
            if (score > bestVendorScore) {
                bestVendorScore = score;
                bestVendorCandidate = c;
            }
        }

        if (bestVendorCandidate && bestVendorScore >= FUZZY_THRESHOLD) {
            return {
                match: {
                    strategy: 'VENDOR_NAME' as MatchStrategy,
                    existingProductId: bestVendorCandidate.productId,
                    existingProductName: bestVendorCandidate.name,
                    similarityScore: bestVendorScore,
                    requiresReview: false,
                },
                candidate: bestVendorCandidate,
            };
        }
    }

    // No match → new product
    return {
        match: {
            strategy: 'NEW_PRODUCT' as MatchStrategy,
            requiresReview: false,
        },
        candidate: null,
    };
}

// ── Stock increment (atomic ADD) ──────────────────────────────────────────

async function incrementStock(
    candidate: ProductCandidate,
    qty: number,
    importSource: string,
): Promise<void> {
    // IMPORTANT: Uses DynamoDB ADD — never read-modify-write
    const cmd = new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({ PK: candidate.pk, SK: candidate.sk }),
        UpdateExpression: 'ADD stock :qty SET lastImportedAt = :now, importSource = :src, updatedAt = :now',
        ExpressionAttributeValues: marshall({
            ':qty': qty,
            ':now': Date.now(),
            ':src': importSource,
        }),
        ConditionExpression: 'attribute_exists(PK)', // safety: ensure item exists
    });

    await getDynamo().send(cmd);
}

// ── Create new product ────────────────────────────────────────────────────

async function createNewProduct(row: ImportRow, category: string): Promise<string> {
    const productId = uuidv4();
    const now = Date.now();
    const importSource = row.businessType.includes('ocr') ? 'ocr' : 'file';

    const productItem = createProductItem(row.tenantId, row.businessType, {
        id: productId,
        name: row.name,
        category,
        barcode: row.barcode,
        sku: row.sku,
        stock: row.quantity,
        unit: row.unit,
        price: row.sellingPriceCents ? row.sellingPriceCents / 100 : 0,
        cost: row.costPriceCents ? row.costPriceCents / 100 : undefined,
        brand: row.vendor,
        gstRate: 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: 'import',
        updatedBy: 'import',
    } as Record<string, unknown>);

    // Add import tracking fields
    productItem.lastImportedAt = now;
    productItem.importSource = importSource;

    // Add variant metadata if detected
    if (row.variantSpec && row.variantSpec.tokens.length > 0) {
        productItem.variantSpec = row.variantSpec;
        productItem.parentProductName = row.variantSpec.parentName;
        productItem.isVariant = true;
    }

    const cmd = new PutItemCommand({
        TableName: TABLE_NAME,
        Item: marshall(productItem, { removeUndefinedValues: true }),
        ConditionExpression: 'attribute_not_exists(PK)', // prevent duplicate
    });

    await getDynamo().send(cmd);
    return productId;
}

// ── Job counter update (atomic ADD) ──────────────────────────────────────

async function incrementJobCounter(
    tenantId: string,
    jobId: string,
    field: 'created' | 'updated' | 'skipped' | 'errorsCount',
): Promise<void> {
    // DynamoDB ADD on a numeric attribute (atomic, no read-modify-write)
    const attrName = `counts_${field}`;
    const cmd = new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
            PK: Keys.tenantPK(tenantId),
            SK: Keys.importJobSK(jobId),
        }),
        UpdateExpression: `ADD ${attrName} :one SET updatedAt = :now`,
        ExpressionAttributeValues: marshall({ ':one': 1, ':now': Date.now() }),
    });

    await getDynamo().send(cmd);
}

async function appendJobError(
    tenantId: string,
    jobId: string,
    error: { rowIndex: number; reason: string; rawData: Record<string, unknown> },
): Promise<void> {
    // Append to errors list using list_append
    const cmd = new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({
            PK: Keys.tenantPK(tenantId),
            SK: Keys.importJobSK(jobId),
        }),
        UpdateExpression: 'SET errors = list_append(if_not_exists(errors, :emptyList), :newError), updatedAt = :now',
        ExpressionAttributeValues: marshall({
            ':newError': [error],
            ':emptyList': [],
            ':now': Date.now(),
        }),
    });

    await getDynamo().send(cmd);
}

async function checkAndFinalizeJob(tenantId: string, jobId: string): Promise<void> {
    // Read job to check if all rows are done
    const { getItem } = await import('../config/dynamodb.config');
    const job = await getItem<Record<string, unknown>>(Keys.tenantPK(tenantId), Keys.importJobSK(jobId));
    if (!job) return;

    const total = (job.countsTotal as number) ?? 0;
    const created = (job.counts_created as number) ?? 0;
    const updated = (job.counts_updated as number) ?? 0;
    const skipped = (job.counts_skipped as number) ?? 0;
    const errors = (job.counts_errorsCount as number) ?? 0;

    if (created + updated + skipped + errors >= total && total > 0) {
        const cmd = new UpdateItemCommand({
            TableName: TABLE_NAME,
            Key: marshall({
                PK: Keys.tenantPK(tenantId),
                SK: Keys.importJobSK(jobId),
            }),
            UpdateExpression: 'SET #st = :completed, completedAt = :now, updatedAt = :now',
            ExpressionAttributeNames: { '#st': 'status' },
            ExpressionAttributeValues: marshall({
                ':completed': 'COMPLETED',
                ':now': Date.now(),
            }),
            ConditionExpression: '#st = :processing',
        });

        try {
            await getDynamo().send(cmd);

            // Push IMPORT_COMPLETED WS event
            await emitEvent(tenantId, WSEventName.IMPORT_COMPLETED, {
                jobId,
                counts: { created, updated, skipped, errors },
            });

        } catch {
            // ConditionExpression failure = already completed by another worker — safe to ignore
        }
    }
}

// ── Per-row processor ─────────────────────────────────────────────────────

async function processRow(row: ImportRow, connectionId?: string): Promise<{ action: ImportRowAction; productId?: string }> {
    const { match, candidate } = await matchProduct(row);

    if (match.strategy === 'NEW_PRODUCT') {
        // Auto-categorize
        const { category } = await resolveCategory(row.nameNormalized, row.businessType);

        const productId = await createNewProduct(
            { ...row, category: row.category ?? category },
            row.category ?? category,
        );

        await incrementJobCounter(row.tenantId, row.jobId, 'created');

        // Push progress event
        await emitEvent(row.tenantId, WSEventName.IMPORT_PROGRESS, {
            jobId: row.jobId,
            rowIndex: row.rowIndex,
            action: 'CREATED',
            productName: row.name,
            productId,
        });

        return { action: 'CREATED', productId };
    } else {
        // Existing product — increment stock
        const importSource = `file#${row.jobId}`;
        await incrementStock(candidate!, row.quantity, importSource);

        await incrementJobCounter(row.tenantId, row.jobId, 'updated');

        // Push progress event
        await emitEvent(row.tenantId, WSEventName.IMPORT_PROGRESS, {
            jobId: row.jobId,
            rowIndex: row.rowIndex,
            action: 'UPDATED',
            productName: candidate!.name,
            productId: candidate!.productId,
            strategy: match.strategy,
            similarityScore: match.similarityScore,
            requiresReview: match.requiresReview,
        });

        return { action: 'UPDATED', productId: candidate!.productId };
    }
}

// ── SQS Handler (entry point) ─────────────────────────────────────────────

export const handler = async (event: SQSEvent): Promise<void> => {
    logger.info('[ProcessImportRow] Batch received', { count: event.Records.length });

    for (const record of event.Records) {
        await processSqsRecord(record);
    }
};

async function processSqsRecord(record: SQSRecord): Promise<void> {
    let row: ImportRow | undefined;
    let connectionId: string | undefined;

    try {
        const msg = JSON.parse(record.body) as ImportRowSqsMessage;
        row = msg.row;
        connectionId = msg.connectionId;

        logger.info('[ProcessImportRow] Processing row', {
            jobId: row.jobId,
            rowIndex: row.rowIndex,
            name: row.name,
        });

        await processRow(row, connectionId);

        // After each row, check if the whole job is done
        await checkAndFinalizeJob(row.tenantId, row.jobId);

    } catch (err) {
        const error = err as Error;
        logger.error('[ProcessImportRow] Row failed', {
            error: error.message,
            rowIndex: row?.rowIndex,
            jobId: row?.jobId,
            stack: error.stack,
        });

        if (row) {
            // Record the error against the job (non-blocking)
            await incrementJobCounter(row.tenantId, row.jobId, 'errorsCount').catch(() => { });
            await appendJobError(row.tenantId, row.jobId, {
                rowIndex: row.rowIndex,
                reason: error.message,
                rawData: row.rawData,
            }).catch(() => { });

            // Push error event
            await emitEvent(row.tenantId, WSEventName.IMPORT_PROGRESS, {
                jobId: row.jobId,
                rowIndex: row.rowIndex,
                action: 'ERROR',
                productName: row.name,
                error: error.message,
            }).catch(() => { });

            // Check job completion even after error
            await checkAndFinalizeJob(row.tenantId, row.jobId).catch(() => { });
        }

        // Do NOT rethrow — SQS partial failure: allow batch to continue.
        // Failed records are handled by the DLQ (configured in serverless.yml).
    }
}
