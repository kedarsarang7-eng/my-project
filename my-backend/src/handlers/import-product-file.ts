// ============================================================================
// Lambda: importProductFile
// ============================================================================
// Trigger: S3 PutObject event on uploads/{tenantId}/{jobId}/{filename}
// Also exposed as POST /inventory/import/init  (upload URL generation)
//            and PUT  /inventory/import/notify  (S3?Lambda direct call fallback)
//
// Flow:
//   1. Validate MIME type + file size (= 10MB)
//   2. Check idempotency: if SHA-256 fingerprint already processed ? return existing job
//   3. Create ImportJob record in DynamoDB (status=PARSING)
//   4. Parse file (CSV / Excel / OCR)
//   5. Normalize rows
//   6. If rows > SQS_FAN_OUT_THRESHOLD (500) ? publish each row to SQS
//      Else ? publish all rows to SQS regardless (processImportRow is the SQS consumer)
//   7. Update ImportJob status=PROCESSING
// ============================================================================

import { S3Event, APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { SQSClient, SendMessageBatchCommand } from '@aws-sdk/client-sqs';
import type { SendMessageBatchRequestEntry } from '@aws-sdk/client-sqs';
import { S3Client, PutObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import { Keys, getItem, putItem, updateItem } from '../config/dynamodb.config';
import { parseImportFile, validateMimeType } from '../services/import-file-parser';
import { normalizeName } from '../utils/fuzzy-match';
import { detectVariants } from '../utils/variant-detector';
import { verifyAuth } from '../middleware/cognito-auth';
import { logger } from '../utils/logger';
import * as response from '../utils/response';
import {
    ImportJob,
    ImportRow,
    ImportSource,
    ImportUploadInitRequest,
    ImportUploadInitResponse,
    ImportRowSqsMessage,
} from '../types/import.types';
import { config } from '../config/environment';

const REGION = config.aws.region;
const TABLE_NAME = config.dynamodb.tableName;
const S3_BUCKET = config.s3.bucketName;
const IMPORT_QUEUE_URL = config.awsQueue.importQueueUrl ?? '';
const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB
const SQS_BATCH_SIZE = 10; // SQS SendMessageBatch max
const JOB_TTL_DAYS = 7;

// Lazy SQS client
let sqsClient: SQSClient | null = null;
function getSQS(): SQSClient {
    if (!sqsClient) sqsClient = new SQSClient({ region: REGION });
    return sqsClient;
}

let s3Client: S3Client | null = null;
function getS3(): S3Client {
    if (!s3Client) s3Client = new S3Client({ region: REGION });
    return s3Client;
}

// -- MIME ? ImportSource map ---------------------------------------------------

function mimeToSource(mimeType: string): ImportSource {
    if (mimeType.includes('csv')) return 'file_csv';
    if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return 'file_xlsx';
    if (mimeType.includes('pdf')) return 'ocr_pdf';
    return 'ocr_image';
}

// -- Row normalization ---------------------------------------------------------

function parsePrice(raw: string | undefined): number | undefined {
    if (!raw) return undefined;
    const n = parseFloat(raw.replace(/[^0-9.]/g, ''));
    if (isNaN(n)) return undefined;
    // Assume input is in rupees — store as paise (cents)
    return Math.round(n * 100);
}

function parseQuantity(raw: string | undefined): number {
    if (!raw) return 0;
    const n = parseFloat(raw.replace(/[^0-9.]/g, ''));
    return isNaN(n) ? 0 : n;
}

function normalizeUnit(raw: string | undefined): string {
    if (!raw) return 'pcs';
    const u = raw.toLowerCase().trim();
    const unitMap: Record<string, string> = {
        'piece': 'pcs', 'pieces': 'pcs', 'unit': 'pcs', 'units': 'pcs', 'no': 'pcs', 'nos': 'pcs',
        'kilogram': 'kg', 'kilograms': 'kg', 'kgs': 'kg',
        'gram': 'g', 'grams': 'g', 'gm': 'g', 'gms': 'g',
        'liter': 'ltr', 'liters': 'ltr', 'litre': 'ltr', 'litres': 'ltr', 'l': 'ltr',
        'milliliter': 'ml', 'milliliters': 'ml', 'millilitre': 'ml',
        'meter': 'm', 'meters': 'm', 'metre': 'm', 'metres': 'm',
        'box': 'box', 'boxes': 'box', 'packet': 'pkt', 'packets': 'pkt', 'pack': 'pkt',
        'dozen': 'doz', 'pair': 'pair', 'pairs': 'pair',
        'bag': 'bag', 'bags': 'bag', 'bundle': 'bundle', 'bundles': 'bundle',
        'roll': 'roll', 'rolls': 'roll', 'sheet': 'sheet', 'sheets': 'sheet',
        'bottle': 'btl', 'bottles': 'btl', 'can': 'can', 'cans': 'can',
    };
    return unitMap[u] ?? u;
}

function buildImportRow(
    rawRow: Record<string, string>,
    rowIndex: number,
    jobId: string,
    tenantId: string,
    businessType: string,
): ImportRow | null {
    const name = rawRow['name']?.trim();
    if (!name || name === '') return null; // Skip rows with no product name

    const nameNormalized = normalizeName(name);
    const quantity = parseQuantity(rawRow['quantity']);
    const unit = normalizeUnit(rawRow['unit']);
    const barcode = rawRow['barcode']?.trim() || undefined;
    const sku = rawRow['sku']?.trim() || undefined;
    const vendor = rawRow['vendor']?.trim() || undefined;
    const category = rawRow['category']?.trim() || undefined;
    const sellingPriceCents = parsePrice(rawRow['selling_price']);
    const costPriceCents = parsePrice(rawRow['cost_price']);
    const variantSpec = detectVariants(name, businessType) ?? undefined;

    return {
        rowIndex,
        jobId,
        tenantId,
        businessType,
        name,
        nameNormalized,
        quantity,
        unit,
        sku,
        barcode,
        sellingPriceCents,
        costPriceCents,
        category,
        vendor,
        rawData: rawRow as Record<string, unknown>,
        variantSpec,
    };
}

// -- SQS fan-out ---------------------------------------------------------------

async function enqueueRows(rows: ImportRow[], connectionId?: string): Promise<void> {
    const sqs = getSQS();

    for (let i = 0; i < rows.length; i += SQS_BATCH_SIZE) {
        const batch = rows.slice(i, i + SQS_BATCH_SIZE);
        const entries: SendMessageBatchRequestEntry[] = batch.map(row => {
            const msg: ImportRowSqsMessage = { row, connectionId };
            return {
                Id: `${row.rowIndex}`,
                MessageBody: JSON.stringify(msg),
                MessageGroupId: row.tenantId,            // FIFO queue — group by tenant
                MessageDeduplicationId: `${row.jobId}-${row.rowIndex}`, // idempotent
            };
        });

        await sqs.send(new SendMessageBatchCommand({
            QueueUrl: IMPORT_QUEUE_URL,
            Entries: entries,
        }));
    }
}

// -- DynamoDB job helpers ------------------------------------------------------

async function createJobRecord(job: ImportJob): Promise<void> {
    await putItem(
        {
            PK: Keys.tenantPK(job.tenantId),
            SK: Keys.importJobSK(job.jobId),
            ...job,
        } as unknown as Record<string, unknown>,
        'attribute_not_exists(PK)',
    );
}

async function updateJobStatus(
    tenantId: string,
    jobId: string,
    status: string,
    extra?: Record<string, unknown>,
): Promise<void> {
    const exprParts = ['#st = :status', 'updatedAt = :now'];
    const exprValues: Record<string, unknown> = {
        ':status': status,
        ':now': Date.now(),
    };
    const exprNames: Record<string, string> = { '#st': 'status' };

    if (extra) {
        Object.entries(extra).forEach(([k, v]) => {
            exprParts.push(`${k} = :${k}`);
            exprValues[`:${k}`] = v;
        });
    }

    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.importJobSK(jobId),
        {
            updateExpression: `SET ${exprParts.join(', ')}`,
            expressionAttributeValues: exprValues,
            expressionAttributeNames: exprNames,
        },
    );
}

async function findExistingJobByFingerprint(
    tenantId: string,
    fingerprint: string,
): Promise<ImportJob | null> {
    // Idempotency: query for a IMPORTFINGERPRINT record under this tenant
    const result = await getItem<ImportJob>(
        Keys.tenantPK(tenantId),
        Keys.importJobFingerprintSK(fingerprint),
    );
    return result ?? null;
}

async function putFingerprintRecord(tenantId: string, fingerprint: string, jobId: string): Promise<void> {
    const ttl = Math.floor(Date.now() / 1000) + JOB_TTL_DAYS * 86400;
    await putItem({
        PK: Keys.tenantPK(tenantId),
        SK: Keys.importJobFingerprintSK(fingerprint),
        jobId,
        fingerprint,
        createdAt: Date.now(),
        ttl,
    } as unknown as Record<string, unknown>);
}

// -- Handler: POST /inventory/import/init -------------------------------------
// Called by Flutter to:
//   1. Check idempotency (fileFingerprint)
//   2. Create ImportJob record
//   3. Return presigned S3 PUT URL

export const initImport = async (
    event: APIGatewayProxyEventV2,
    _context: Context,
): Promise<APIGatewayProxyResultV2> => {
    try {
        const auth = await verifyAuth(event);
        const { tenantId } = auth;

        const body = JSON.parse(event.body ?? '{}') as ImportUploadInitRequest;
        const { fileName, fileSizeBytes, mimeType, fileFingerprint, businessType } = body;

        // Validate
        if (!fileName || !mimeType || !fileFingerprint) {
            return response.error(400, 'VALIDATION_ERROR', 'fileName, mimeType, fileFingerprint required');
        }
        if (fileSizeBytes > MAX_FILE_SIZE_BYTES) {
            return response.error(400, 'FILE_TOO_LARGE', `File must be = 10MB. Got ${(fileSizeBytes / 1024 / 1024).toFixed(2)}MB`);
        }
        if (!validateMimeType(mimeType)) {
            return response.error(400, 'INVALID_MIME_TYPE', `Unsupported file type: ${mimeType}. Allowed: csv, xlsx, jpeg, png, tiff, pdf`);
        }

        // Idempotency check
        const existing = await findExistingJobByFingerprint(tenantId, fileFingerprint);
        if (existing) {
            const res: ImportUploadInitResponse = {
                jobId: existing.jobId,
                uploadUrl: '',
                s3Key: existing.s3Key,
                alreadyProcessed: true,
                previousJobId: existing.jobId,
            };
            return response.success(res);
        }

        // Create job
        const jobId = randomUUID();
        const s3Key = `uploads/${tenantId}/${jobId}/${fileName}`;
        const now = Date.now();
        const ttl = Math.floor(now / 1000) + JOB_TTL_DAYS * 86400;

        const job: ImportJob = {
            jobId,
            tenantId,
            status: 'PENDING',
            source: mimeToSource(mimeType),
            fileFingerprint,
            s3Key,
            originalFileName: fileName,
            fileSizeBytes,
            counts: { total: 0, created: 0, updated: 0, skipped: 0, errors: 0, queued: 0 },
            errors: [],
            businessType,
            createdAt: now,
            updatedAt: now,
            ttl,
        };

        await createJobRecord(job);
        await putFingerprintRecord(tenantId, fileFingerprint, jobId);

        // Generate presigned PUT URL (valid 15 min)
        const uploadUrl = await getSignedUrl(
            getS3(),
            new PutObjectCommand({
                Bucket: S3_BUCKET,
                Key: s3Key,
                ContentType: mimeType,
            }),
            { expiresIn: 900 },
        );

        const res: ImportUploadInitResponse = {
            jobId,
            uploadUrl,
            s3Key,
            alreadyProcessed: false,
        };

        logger.info('[ImportInit] Job created', { jobId, tenantId, fileName });
        return response.success(res);

    } catch (err) {
        logger.error('[ImportInit] Error', { error: (err as Error).message, stack: (err as Error).stack });
        return response.internalError();
    }
};

// -- Handler: S3 PutObject Event -----------------------------------------------
// Triggered automatically when Flutter uploads the file to S3.
// Key pattern: uploads/{tenantId}/{jobId}/{filename}

export const processS3Upload = async (event: S3Event): Promise<void> => {
    for (const record of event.Records) {
        const bucket = record.s3.bucket.name;
        const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
        const sizeBytes = record.s3.object.size;

        // Extract tenantId + jobId from S3 key
        // uploads/{tenantId}/{jobId}/{filename}
        const parts = key.split('/');
        if (parts.length < 4 || parts[0] !== 'uploads') {
            logger.warn('[S3Upload] Unexpected key pattern — skipping', { key });
            continue;
        }

        const tenantId = parts[1];
        const jobId = parts[2];
        const fileName = parts.slice(3).join('/');

        logger.info('[S3Upload] Processing', { bucket, key, tenantId, jobId });

        try {
            // Get MIME type from S3 object metadata
            const headRes = await getS3().send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
            const mimeType = headRes.ContentType ?? 'application/octet-stream';

            // Validate size server-side (belt-and-suspenders)
            if (sizeBytes > MAX_FILE_SIZE_BYTES) {
                await updateJobStatus(tenantId, jobId, 'FAILED', { failReason: 'File exceeds 10MB limit' });
                logger.warn('[S3Upload] File too large', { key, sizeBytes });
                continue;
            }

            if (!validateMimeType(mimeType)) {
                await updateJobStatus(tenantId, jobId, 'FAILED', { failReason: `Invalid MIME type: ${mimeType}` });
                logger.warn('[S3Upload] Invalid MIME type', { key, mimeType });
                continue;
            }

            // Fetch job to get businessType and connectionId
            const job = await getItem<ImportJob>(Keys.tenantPK(tenantId), Keys.importJobSK(jobId));
            if (!job) {
                logger.error('[S3Upload] Job record not found', { tenantId, jobId });
                continue;
            }

            // Mark as PARSING
            await updateJobStatus(tenantId, jobId, 'PARSING');

            // Parse the file
            const parseResult = await parseImportFile(bucket, key, mimeType);

            if (parseResult.rows.length === 0) {
                // No valid rows — complete immediately
                await updateJobStatus(tenantId, jobId, 'COMPLETED', {
                    counts: { total: 0, created: 0, updated: 0, skipped: 0, errors: parseResult.errors.length, queued: 0 },
                    errors: parseResult.errors,
                    completedAt: Date.now(),
                });
                logger.info('[S3Upload] No rows found', { jobId });
                continue;
            }

            // Build normalized ImportRow objects
            const rows: ImportRow[] = [];
            const parseErrors = [...parseResult.errors];

            parseResult.rows.forEach((rawRow, idx) => {
                const row = buildImportRow(rawRow, idx, jobId, tenantId, job.businessType);
                if (row) {
                    rows.push(row);
                } else {
                    parseErrors.push({
                        rowIndex: idx,
                        rawData: rawRow as Record<string, unknown>,
                        reason: 'Missing required field: name',
                        field: 'name',
                    });
                }
            });

            // Update counts and status before enqueuing
            // Note: DynamoDB does not support dot-notation in SET expressions for nested maps this way;
            // We store counts as a flat serialized object and overwrite it atomically.
            await updateJobStatus(tenantId, jobId, 'PROCESSING', {
                countsTotal: rows.length,
                countsQueued: rows.length,
                countsErrors: parseErrors.length,
                errors: parseErrors,
            });

            // Enqueue all rows to SQS (always — processImportRow is the worker)
            // For > 500 rows this is fan-out; for smaller files it still uses the same path for consistency.
            await enqueueRows(rows);

            logger.info('[S3Upload] Enqueued rows', { jobId, count: rows.length });

        } catch (err) {
            logger.error('[S3Upload] Fatal error processing file', {
                key,
                error: (err as Error).message,
                stack: (err as Error).stack,
            });
            // Best-effort job failure update
            try {
                await updateJobStatus(tenantId, jobId, 'FAILED', { failReason: (err as Error).message });
            } catch { /* non-critical */ }
        }
    }
};
