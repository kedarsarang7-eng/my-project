// ============================================================================
// Migration Handler — Unit Tests
// ============================================================================
// Tests cover:
//   MIG-001  migrateIdentity — happy path
//   MIG-002  migrateIdentity — missing migrationId → 400
//   MIG-003  migrationImport — happy path 3 records
//   MIG-004  migrationImport — over 25 records → 400
//   MIG-005  migrationImport — missing fields → 400
//   MIG-006  migrationUpload — returns presigned URL
//   MIG-007  migrationVerify — all counts match → allPassed: true
//   MIG-008  migrationVerify — count mismatch → allPassed: false
//   MIG-009  migrationCutover — records license conversion
//   MIG-010  migrationCutover — missing licenseId → 400
//   MIG-011  migrationRollback — deletes all migration items
//   MIG-012  migrationRollback — missing migrationId → 400
// ============================================================================

import {
  DynamoDBClient,
  PutItemCommand,
  QueryCommand,
  BatchWriteItemCommand,
} from '@aws-sdk/client-dynamodb';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { marshall } from '@aws-sdk/util-dynamodb';

// ── Mock AWS SDK ────────────────────────────────────────────────────────────

const mockDdbSend = jest.fn();
const mockS3Send = jest.fn();

jest.mock('@aws-sdk/client-dynamodb', () => ({
  DynamoDBClient: jest.fn().mockImplementation(() => ({ send: mockDdbSend })),
  PutItemCommand: jest.fn(),
  QueryCommand: jest.fn(),
  DeleteItemCommand: jest.fn(),
  BatchWriteItemCommand: jest.fn(),
}));

jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: jest.fn().mockImplementation(() => ({ send: mockS3Send })),
  PutObjectCommand: jest.fn(),
  DeleteObjectCommand: jest.fn(),
  ListObjectsV2Command: jest.fn(),
}));

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn().mockResolvedValue(
    'https://bucket.s3.amazonaws.com/presigned-upload?X-Amz-Signature=abc'
  ),
}));

jest.mock('@aws-sdk/util-dynamodb', () => ({
  marshall: jest.fn((o) => o),
  unmarshall: jest.fn((o) => o),
}));

jest.mock('../utils/response', () => ({
  createJsonResponse: jest.fn((status, body) => ({
    statusCode: status,
    body: JSON.stringify(body),
  })),
}));

// ── Import handlers AFTER mocks ─────────────────────────────────────────────

import {
  migrateIdentity,
  migrationImport,
  migrationUpload,
  migrationVerify,
  migrationCutover,
  migrationRollback,
} from '../handlers/migration';

// ── Helpers ─────────────────────────────────────────────────────────────────

interface JsonResponse {
  statusCode: number;
  body: string;
}

/** Cast handler result to a plain JsonResponse (mocked createJsonResponse returns this shape). */
function asJson(result: unknown): JsonResponse {
  return result as JsonResponse;
}

function makeEvent(body: Record<string, unknown>, sub = 'user-123', email = 'owner@shop.com') {
  return {
    body: JSON.stringify(body),
    requestContext: {
      authorizer: {
        jwt: { claims: { sub, email } },
      },
    },
  } as any;
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Migration Handler', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockDdbSend.mockResolvedValue({ Items: [], Count: 0 });
    mockS3Send.mockResolvedValue({});
  });

  // ── MIG-001 ──────────────────────────────────────────────────────────────
  it('MIG-001: migrateIdentity — records identity mapping', async () => {
    const res = asJson(await migrateIdentity(
      makeEvent({ migrationId: 'MIG-001', deviceFingerprint: 'fp-abc' }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body).toHaveProperty('cognitoSub', 'user-123');
    expect(body).toHaveProperty('userIdMapping');
    expect(mockDdbSend).toHaveBeenCalledTimes(1);
  });

  // ── MIG-002 ──────────────────────────────────────────────────────────────
  it('MIG-002: migrateIdentity — missing migrationId → 400', async () => {
    const res = asJson(await migrateIdentity(makeEvent({}), {} as any, () => {}));
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).error).toMatch(/migrationId/i);
  });

  // ── MIG-003 ──────────────────────────────────────────────────────────────
  it('MIG-003: migrationImport — imports 3 records successfully', async () => {
    const records = [
      { id: 'p1', name: 'Product A', price: 100 },
      { id: 'p2', name: 'Product B', price: 200 },
      { id: 'p3', name: 'Product C', price: 300 },
    ];

    const res = asJson(await migrationImport(
      makeEvent({ migrationId: 'MIG-003', table: 'products', records }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.imported).toBe(3);
    expect(body.table).toBe('products');
    // BatchWriteItem + PutItem (progress) = 2 calls
    expect(mockDdbSend).toHaveBeenCalledTimes(2);
  });

  // ── MIG-004 ──────────────────────────────────────────────────────────────
  it('MIG-004: migrationImport — 26 records → 400', async () => {
    const records = Array.from({ length: 26 }, (_, i) => ({ id: `r${i}` }));
    const res = asJson(await migrationImport(
      makeEvent({ migrationId: 'MIG-004', table: 'products', records }),
      {} as any,
      () => {}
    ));
    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).error).toMatch(/max 25/i);
  });

  // ── MIG-005 ──────────────────────────────────────────────────────────────
  it('MIG-005: migrationImport — missing table → 400', async () => {
    const res = asJson(await migrationImport(
      makeEvent({ migrationId: 'MIG-005', records: [] }),
      {} as any,
      () => {}
    ));
    expect(res.statusCode).toBe(400);
  });

  // ── MIG-006 ──────────────────────────────────────────────────────────────
  it('MIG-006: migrationUpload — returns presigned URL', async () => {
    const res = asJson(await migrationUpload(
      makeEvent({
        migrationId: 'MIG-006',
        key: 'invoices/2024/INV-001.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 45000,
      }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.url).toContain('presigned-upload');
    expect(body.s3Key).toContain('migration/MIG-006');
    expect(mockDdbSend).toHaveBeenCalledTimes(1);
  });

  // ── MIG-007 ──────────────────────────────────────────────────────────────
  it('MIG-007: migrationVerify — counts match → allPassed: true', async () => {
    // Simulate DDB returning 2 import batches: bills×5, customers×3
    mockDdbSend
      .mockResolvedValueOnce({
        Items: [
          { PK: 'MIGRATION#MIG-007', SK: 'IMPORT#bills#1', table: 'bills', count: 5 },
          { PK: 'MIGRATION#MIG-007', SK: 'IMPORT#customers#1', table: 'customers', count: 3 },
        ],
        Count: 2,
      })
      // files query
      .mockResolvedValueOnce({ Count: 2 });

    const res = asJson(await migrationVerify(
      makeEvent({
        migrationId: 'MIG-007',
        expectedCounts: { bills: 5, customers: 3 },
        expectedFileCount: 2,
      }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    expect(JSON.parse(res.body).allPassed).toBe(true);
  });

  // ── MIG-008 ──────────────────────────────────────────────────────────────
  it('MIG-008: migrationVerify — count mismatch → allPassed: false', async () => {
    mockDdbSend
      .mockResolvedValueOnce({
        Items: [
          { PK: 'MIGRATION#MIG-008', SK: 'IMPORT#bills#1', table: 'bills', count: 2 },
        ],
        Count: 1,
      })
      .mockResolvedValueOnce({ Count: 0 });

    const res = asJson(await migrationVerify(
      makeEvent({
        migrationId: 'MIG-008',
        expectedCounts: { bills: 10 }, // only 2 imported → mismatch
        expectedFileCount: 0,
      }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.allPassed).toBe(false);
    expect(body.mismatches).toHaveProperty('bills');
  });

  // ── MIG-009 ──────────────────────────────────────────────────────────────
  it('MIG-009: migrationCutover — records license conversion', async () => {
    const res = asJson(await migrationCutover(
      makeEvent({
        migrationId: 'MIG-009',
        licenseId: 'LIC-XYZ',
        clientUUID: 'client-abc',
        onlinePlan: 'online-standard-monthly',
        creditsInMonths: 18,
        subscriptionExpiry: '2027-11-01T00:00:00.000Z',
      }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.success).toBe(true);
    expect(body.onlinePlan).toBe('online-standard-monthly');
    expect(body.creditsInMonths).toBe(18);
    // PutItem (license) + PutItem (migration status) = 2
    expect(mockDdbSend).toHaveBeenCalledTimes(2);
  });

  // ── MIG-010 ──────────────────────────────────────────────────────────────
  it('MIG-010: migrationCutover — missing licenseId → 400', async () => {
    const res = asJson(await migrationCutover(
      makeEvent({ migrationId: 'MIG-010' }),
      {} as any,
      () => {}
    ));
    expect(res.statusCode).toBe(400);
  });

  // ── MIG-011 ──────────────────────────────────────────────────────────────
  it('MIG-011: migrationRollback — deletes migration items and S3 files', async () => {
    // First query: migration metadata items
    mockDdbSend
      .mockResolvedValueOnce({
        Items: [
          { PK: 'MIGRATION#MIG-011', SK: 'IDENTITY#u1' },
          { PK: 'MIGRATION#MIG-011', SK: 'IMPORT#bills#1' },
          { PK: 'MIGRATION#MIG-011', SK: 'STATUS' },
        ],
      })
      // Batch delete
      .mockResolvedValueOnce({})
      // Second query: file items
      .mockResolvedValueOnce({
        Items: [
          { PK: 'MIGRATION#MIG-011', SK: 'FILE#doc.pdf', s3Key: 'migration/MIG-011/doc.pdf' },
        ],
      });

    const res = asJson(await migrationRollback(
      makeEvent({ migrationId: 'MIG-011', failedStep: 'file_migrate' }),
      {} as any,
      () => {}
    ));

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.rolledBack).toBe(true);
    expect(body.deletedItems).toBe(3);
    expect(mockS3Send).toHaveBeenCalledTimes(1);
  });

  // ── MIG-012 ──────────────────────────────────────────────────────────────
  it('MIG-012: migrationRollback — missing migrationId → 400', async () => {
    const res = asJson(await migrationRollback(makeEvent({}), {} as any, () => {}));
    expect(res.statusCode).toBe(400);
  });
});
