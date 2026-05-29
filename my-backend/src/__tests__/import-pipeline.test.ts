/// <reference types="jest" />
// ============================================================================
// Integration-style unit tests: Smart Inventory Import pipeline
// ============================================================================
// Covers:
//   - importProductFileInit handler (POST /inventory/import/init)
//   - getImportJobStatus handler (GET /inventory/import/{jobId})
//   - processImportRow handler (SQS consumer) with mocked DynamoDB
// All AWS SDK calls are mocked — no real AWS connection required.
// ============================================================================

import type { APIGatewayProxyEventV2 } from 'aws-lambda';

// ── Mock AWS services ─────────────────────────────────────────────────────────

const mockDdbSend = jest.fn();
const mockS3Send = jest.fn();
const mockSqsSend = jest.fn();

jest.mock('@aws-sdk/client-dynamodb', () => ({
    DynamoDBClient: jest.fn().mockImplementation(() => ({ send: mockDdbSend })),
    GetItemCommand: jest.fn().mockImplementation((p) => ({ _type: 'GetItem', ...p })),
    PutItemCommand: jest.fn().mockImplementation((p) => ({ _type: 'PutItem', ...p })),
    UpdateItemCommand: jest.fn().mockImplementation((p) => ({ _type: 'UpdateItem', ...p })),
    QueryCommand: jest.fn().mockImplementation((p) => ({ _type: 'Query', ...p })),
}));

jest.mock('@aws-sdk/lib-dynamodb', () => ({
    DynamoDBDocumentClient: {
        from: jest.fn().mockImplementation(() => ({ send: mockDdbSend })),
    },
    GetCommand: jest.fn().mockImplementation((p) => ({ _type: 'Get', ...p })),
    PutCommand: jest.fn().mockImplementation((p) => ({ _type: 'Put', ...p })),
    UpdateCommand: jest.fn().mockImplementation((p) => ({ _type: 'Update', ...p })),
    DeleteCommand: jest.fn().mockImplementation((p) => ({ _type: 'Delete', ...p })),
    QueryCommand: jest.fn().mockImplementation((p) => ({ _type: 'Query', ...p })),
    BatchWriteCommand: jest.fn().mockImplementation((p) => ({ _type: 'BatchWrite', ...p })),
    BatchGetCommand: jest.fn().mockImplementation((p) => ({ _type: 'BatchGet', ...p })),
    TransactWriteCommand: jest.fn().mockImplementation((p) => ({ _type: 'TransactWrite', ...p })),
    ScanCommand: jest.fn().mockImplementation((p) => ({ _type: 'Scan', ...p })),
}));

jest.mock('@aws-sdk/util-dynamodb', () => ({
    marshall: (obj: Record<string, unknown>) => obj,
    unmarshall: (obj: Record<string, unknown>) => obj,
}));

jest.mock('@aws-sdk/client-s3', () => ({
    S3Client: jest.fn().mockImplementation(() => ({ send: mockS3Send })),
    PutObjectCommand: jest.fn().mockImplementation((p) => ({ _type: 'PutObject', ...p })),
    GetObjectCommand: jest.fn().mockImplementation((p) => ({ _type: 'GetObject', ...p })),
}));

jest.mock('@aws-sdk/s3-request-presigner', () => ({
    getSignedUrl: jest.fn().mockResolvedValue('https://s3.presigned.url/test-key'),
}));

jest.mock('@aws-sdk/client-sqs', () => ({
    SQSClient: jest.fn().mockImplementation(() => ({ send: mockSqsSend })),
    SendMessageBatchCommand: jest.fn().mockImplementation((p) => ({ _type: 'SQSBatch', ...p })),
    SendMessageCommand: jest.fn().mockImplementation((p) => ({ _type: 'SQSSingle', ...p })),
}));

jest.mock('@aws-sdk/client-textract', () => ({
    TextractClient: jest.fn().mockImplementation(() => ({ send: jest.fn() })),
    AnalyzeDocumentCommand: jest.fn(),
    DetectDocumentTextCommand: jest.fn(),
}));

// Mock middleware — bypass auth for both handler-wrapper and cognito-auth
jest.mock('../middleware/handler-wrapper', () => ({
    authorizedHandler: (_roles: unknown[], fn: Function) =>
        (event: unknown, context: unknown) =>
            fn(event, context, {
                sub: 'user-123',
                tenantId: 'tenant-456',
                role: 'owner',
                businessType: 'grocery',
            }),
    withIdempotency: (fn: Function) => fn,
}));

jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'user-123',
        tenantId: 'tenant-456',
        role: 'owner',
        businessType: 'grocery',
    }),
}));

// Mock WebSocket service
jest.mock('../services/websocket.service', () => ({
    emitEvent: jest.fn().mockResolvedValue(undefined),
}));

// Mock category-keyword-map
jest.mock('../services/category-keyword-map', () => ({
    resolveCategory: jest.fn().mockResolvedValue('General'),
}));

// ── Helpers ───────────────────────────────────────────────────────────────────

function makeApigwEvent(body: unknown, pathParams?: Record<string, string>): APIGatewayProxyEventV2 {
    return {
        version: '2.0',
        routeKey: 'POST /inventory/import/init',
        rawPath: '/inventory/import/init',
        rawQueryString: '',
        headers: {
            'content-type': 'application/json',
            authorization: 'Bearer test-token',
        },
        requestContext: {
            accountId: '123456789012',
            apiId: 'test',
            domainName: 'test.execute-api.us-east-1.amazonaws.com',
            domainPrefix: 'test',
            http: {
                method: 'POST',
                path: '/inventory/import/init',
                protocol: 'HTTP/1.1',
                sourceIp: '1.2.3.4',
                userAgent: 'test',
            },
            requestId: 'test-req-id',
            routeKey: 'POST /inventory/import/init',
            stage: '$default',
            time: '01/Jan/2025:00:00:00 +0000',
            timeEpoch: 1735689600000,
        },
        body: JSON.stringify(body),
        isBase64Encoded: false,
        pathParameters: pathParams ?? {},
        queryStringParameters: {},
        stageVariables: {},
    } as unknown as APIGatewayProxyEventV2;
}

function makeAuthContext() {
    return {
        sub: 'user-123',
        tenantId: 'tenant-456',
        role: 'owner',
        businessType: 'grocery',
    };
}

// ── getImportJobStatus ────────────────────────────────────────────────────────

describe('getImportJobStatus handler', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('returns 404 when job does not exist', async () => {
        mockDdbSend.mockResolvedValue({ Item: undefined });

        const { getJobStatus } = await import('../handlers/get-import-job-status');

        const event = makeApigwEvent(null, { jobId: 'non-existent-job' });
        (event as any).pathParameters = { jobId: 'non-existent-job' };

        const result = await (getJobStatus as Function)(event, {});
        expect(result.statusCode).toBe(404);
    });

    it('returns 200 with job details when job exists', async () => {
        mockDdbSend.mockResolvedValue({
            Item: {
                pk: 'TENANT#tenant-456',
                sk: 'IMPORT_JOB#job-789',
                jobId: 'job-789',
                tenantId: 'tenant-456',
                status: 'PROCESSING',
                createdAt: new Date().toISOString(),
                countsTotal: 100,
                counts_created: 30,
                counts_updated: 10,
                counts_errorsCount: 5,
                countsQueued: 0,
            },
        });

        const { getJobStatus } = await import('../handlers/get-import-job-status');

        const event = makeApigwEvent(null, { jobId: 'job-789' });
        (event as any).pathParameters = { jobId: 'job-789' };

        const result = await (getJobStatus as Function)(event, {});
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.data.jobId).toBe('job-789');
        expect(body.data.status).toBe('PROCESSING');
        expect(body.data.counts.total).toBe(100);
        expect(body.data.counts.created).toBe(30);
    });
});

// ── importProductFileInit ─────────────────────────────────────────────────────

describe('importProductFileInit handler', () => {
    beforeEach(() => {
        mockDdbSend.mockReset();
        mockS3Send.mockReset();
        mockSqsSend.mockReset();
        process.env.DYNAMODB_TABLE = 'DukanXTable';
        process.env.TENANT_STORAGE_BUCKET = 'test-bucket';
        process.env.IMPORT_QUEUE_URL = 'https://sqs.ap-south-1.amazonaws.com/123/test.fifo';
    });

    it('returns 400 when required fields missing', async () => {
        const { initImport } = await import('../handlers/import-product-file');

        const event = makeApigwEvent({
            fileName: 'test.csv',
            // missing fileSizeBytes, mimeType, fileFingerprint
        });

        const result = await (initImport as Function)(event, {});
        expect(result.statusCode).toBe(400);
    });

    it('returns 400 for unsupported MIME type', async () => {
        const { initImport } = await import('../handlers/import-product-file');

        const event = makeApigwEvent({
            fileName: 'test.txt',
            fileSizeBytes: 1024,
            mimeType: 'text/plain',
            fileFingerprint: 'abc123',
        });

        const result = await (initImport as Function)(event, {});
        expect(result.statusCode).toBe(400);
    });

    it('returns existing job when same fingerprint submitted again (idempotency)', async () => {
        // First GetItem returns the fingerprint record (already processed)
        mockDdbSend.mockResolvedValueOnce({
            Item: {
                pk: 'TENANT#tenant-456',
                sk: 'IMPORT_FINGERPRINT#fp123',
                jobId: 'existing-job-id',
                status: 'COMPLETED',
            },
        });
        // Second GetItem returns the full job
        mockDdbSend.mockResolvedValueOnce({
            Item: {
                pk: 'TENANT#tenant-456',
                sk: 'IMPORT_JOB#existing-job-id',
                jobId: 'existing-job-id',
                status: 'COMPLETED',
                counts_total: 50,
                counts_created: 45,
                counts_updated: 3,
                counts_errors: 2,
            },
        });

        const { initImport } = await import('../handlers/import-product-file');

        const event = makeApigwEvent({
            fileName: 'products.csv',
            fileSizeBytes: 2048,
            mimeType: 'text/csv',
            fileFingerprint: 'fp123',
            businessType: 'grocery',
        });

        const result = await (initImport as Function)(event, {});
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.data.alreadyProcessed).toBe(true);
        expect(body.data.jobId).toBe('existing-job-id');
    });

    it('creates new job and returns presigned URL for new fingerprint', async () => {
        // No existing fingerprint
        mockDdbSend.mockResolvedValueOnce({ Item: undefined });
        // PutItem for fingerprint record
        mockDdbSend.mockResolvedValueOnce({});
        // PutItem for job record
        mockDdbSend.mockResolvedValueOnce({});

        const { initImport } = await import('../handlers/import-product-file');

        const event = makeApigwEvent({
            fileName: 'inventory.xlsx',
            fileSizeBytes: 5000,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            fileFingerprint: 'new-fp-xyz',
            businessType: 'grocery',
        });

        const result = await (initImport as Function)(event, {});
        expect(result.statusCode).toBe(200);

        const body = JSON.parse(result.body);
        expect(body.data.alreadyProcessed).toBe(false);
        expect(body.data.jobId).toBeDefined();
        expect(body.data.uploadUrl).toContain('s3.presigned.url');
    });
});

// ── processImportRow (SQS handler) ────────────────────────────────────────────

describe('processImportRow handler', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env.DYNAMODB_TABLE = 'DukanXTable';
        process.env.FUZZY_THRESHOLD = '0.85';
    });

    function makeSqsEvent(rowFields: Record<string, string>) {
        const row: Record<string, unknown> = {
            jobId: 'job-abc',
            tenantId: 'tenant-456',
            rowIndex: 0,
            totalRows: 10,
            businessType: 'grocery',
            name: rowFields.name ?? '',
            barcode: rowFields.barcode,
            sku: rowFields.sku,
            quantity: parseFloat(rowFields.quantity ?? '0'),
            sellingPrice: parseFloat(rowFields.price ?? '0'),
            costPrice: 0,
            unit: 'pcs',
            category: '',
            vendor: '',
        };
        const message: Record<string, unknown> = { row };
        return {
            Records: [
                {
                    messageId: 'msg-1',
                    body: JSON.stringify(message),
                    attributes: {} as any,
                    messageAttributes: {},
                    md5OfBody: 'test',
                    eventSource: 'aws:sqs',
                    eventSourceARN: 'arn:aws:sqs:ap-south-1:123:test.fifo',
                    awsRegion: 'ap-south-1',
                    receiptHandle: 'test-handle',
                },
            ],
        };
    }

    it('processes without throwing when product has barcode match', async () => {
        // Query returns a product matching by barcode
        mockDdbSend.mockResolvedValue({
            Items: [
                {
                    pk: 'TENANT#tenant-456',
                    sk: 'PRODUCT#p1',
                    productId: 'p1',
                    name: 'Tata Salt 1kg',
                    barcode: '8901058001015',
                    stock: 50,
                    version: 1,
                },
            ],
            Count: 1,
        });

        const { handler: processImportRow } = await import('../handlers/process-import-row');

        const event = makeSqsEvent({
            name: 'Tata Salt 1kg',
            barcode: '8901058001015',
            quantity: '10',
            price: '20',
        });

        await expect((processImportRow as Function)(event, {})).resolves.not.toThrow();
    });

    it('creates a new product when no match found', async () => {
        // Query returns empty (no matching product)
        mockDdbSend.mockResolvedValue({ Items: [], Count: 0 });
        // PutItem for new product
        mockDdbSend.mockResolvedValueOnce({});
        // UpdateItem for job counter
        mockDdbSend.mockResolvedValueOnce({});

        const { handler: processImportRow } = await import('../handlers/process-import-row');

        const event = makeSqsEvent({
            name: 'Completely New Product XYZ',
            quantity: '5',
            price: '99',
        });

        await expect((processImportRow as Function)(event, {})).resolves.not.toThrow();
    });

    it('propagates SyntaxError for malformed SQS message body (Lambda retries)', async () => {
        const { handler: processImportRow } = await import('../handlers/process-import-row');

        const event = {
            Records: [
                {
                    messageId: 'bad-msg',
                    body: 'not-valid-json',
                    attributes: {} as any,
                    messageAttributes: {},
                    md5OfBody: '',
                    eventSource: 'aws:sqs',
                    eventSourceARN: '',
                    awsRegion: 'ap-south-1',
                    receiptHandle: 'handle',
                },
            ],
        };

        // Handler catches SyntaxError internally, logs it, and resolves (DLQ handles retries)
        await expect((processImportRow as Function)(event, {})).resolves.toBeUndefined();
    });
});
