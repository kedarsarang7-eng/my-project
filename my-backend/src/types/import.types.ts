// ============================================================================
// Smart Inventory Import — Shared TypeScript Types
// ============================================================================
// Covers: ImportJob, ImportRow, ProductMatch, ImportResult, VariantSpec
// All DynamoDB PK patterns: TENANT#{tenantId}#IMPORTJOB#{jobId}
// Assumption: price/cost stored as integer paise (cents) to match InventoryItem convention.
// ============================================================================

// ── Import Job ───────────────────────────────────────────────────────────────

export type ImportJobStatus =
    | 'PENDING'      // Job record created, file not yet processed
    | 'PARSING'      // File download + parsing in progress
    | 'PROCESSING'   // Row-level matching + writes in progress
    | 'COMPLETED'    // All rows processed (may still have errors)
    | 'FAILED';      // Fatal failure (parse error, bad MIME type, etc.)

export type ImportSource = 'manual' | 'file_csv' | 'file_xlsx' | 'ocr_image' | 'ocr_pdf';

export interface ImportJobCounts {
    total: number;
    created: number;
    updated: number;
    skipped: number;
    errors: number;
    queued: number;      // Rows sent to SQS (fan-out mode, not yet processed)
}

export interface ImportJobError {
    rowIndex: number;
    rawData: Record<string, unknown>;
    reason: string;
    field?: string;
}

export interface ImportJob {
    jobId: string;
    tenantId: string;
    status: ImportJobStatus;
    source: ImportSource;

    /** SHA-256 of the raw file bytes — used for idempotency */
    fileFingerprint: string;

    /** S3 key: uploads/{tenantId}/{jobId}/{filename} */
    s3Key: string;
    originalFileName: string;
    fileSizeBytes: number;

    counts: ImportJobCounts;
    errors: ImportJobError[];

    businessType: string;
    createdAt: number;   // Unix ms
    updatedAt: number;
    completedAt?: number;

    /** DynamoDB TTL — 7 days from createdAt (seconds) */
    ttl: number;
}

// ── Import Row ───────────────────────────────────────────────────────────────

export interface ImportRow {
    rowIndex: number;
    jobId: string;
    tenantId: string;
    businessType: string;

    /** Normalized values extracted from the raw file row */
    name: string;
    nameNormalized: string;   // lowercase, trimmed, diacritics stripped
    quantity: number;
    unit: string;
    sku?: string;
    barcode?: string;
    sellingPriceCents?: number;
    costPriceCents?: number;
    category?: string;
    vendor?: string;

    /** Raw column data for error reporting */
    rawData: Record<string, unknown>;

    /** Variant tokens detected by vertical-specific parser */
    variantSpec?: VariantSpec;
}

// ── Product Match ────────────────────────────────────────────────────────────

export type MatchStrategy =
    | 'BARCODE'       // Exact barcode/SKU match
    | 'EXACT_NAME'    // Exact normalized name match
    | 'FUZZY_NAME'    // Levenshtein similarity >= FUZZY_THRESHOLD
    | 'VENDOR_NAME'   // Vendor + normalized name compound match
    | 'NEW_PRODUCT';  // No match — create as new

export interface ProductMatch {
    strategy: MatchStrategy;
    existingProductId?: string;
    existingProductName?: string;
    similarityScore?: number;   // 0–1; only set for FUZZY_NAME
    requiresReview: boolean;    // true when flagged for owner review
}

// ── Import Result (per row) ──────────────────────────────────────────────────

export type ImportRowAction = 'CREATED' | 'UPDATED' | 'SKIPPED' | 'ERROR';

export interface ImportRowResult {
    rowIndex: number;
    action: ImportRowAction;
    productId?: string;
    productName?: string;
    match?: ProductMatch;
    error?: string;
}

// ── Variant Spec ─────────────────────────────────────────────────────────────

export type VariantDimension = 'size' | 'color' | 'edition' | 'author' | 'strength' | 'flavor';

export interface VariantToken {
    dimension: VariantDimension;
    value: string;
    /** Portion of the product name consumed by this token */
    rawToken: string;
}

export interface VariantSpec {
    /** Product name with all variant tokens stripped */
    parentName: string;
    tokens: VariantToken[];
    /** Business vertical that produced this spec */
    vertical: string;
}

// ── LLM Category Cache Record ────────────────────────────────────────────────

export interface CategoryCacheRecord {
    /** DynamoDB PK: CATCACHE#{hash(normalizedName+vertical)} */
    cacheKey: string;
    normalizedName: string;
    vertical: string;
    category: string;
    resolvedBy: 'keyword_map' | 'llm';
    createdAt: number;
    /** TTL: 30 days — LLM decisions are stable */
    ttl: number;
}

// ── SQS Message ──────────────────────────────────────────────────────────────

export interface ImportRowSqsMessage {
    row: ImportRow;
    /** WebSocket connectionId of the uploading user (for targeted progress push) */
    connectionId?: string;
}

// ── Upload Init Request/Response (from Flutter → API Gateway) ────────────────

export interface ImportUploadInitRequest {
    fileName: string;
    fileSizeBytes: number;
    mimeType: string;
    businessType: string;
    /** SHA-256 hex of file content (computed client-side before upload) */
    fileFingerprint: string;
}

export interface ImportUploadInitResponse {
    jobId: string;
    /** Presigned S3 PUT URL — valid for 15 minutes */
    uploadUrl: string;
    s3Key: string;
    /** true if this fingerprint was already processed (idempotency shortcut) */
    alreadyProcessed: boolean;
    previousJobId?: string;
}
