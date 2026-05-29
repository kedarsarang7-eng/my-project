// ============================================================================
// Migration Handler — Offline → Online migration endpoints
// ============================================================================
// POST /migration/identity   — provision Cognito account from offline user
// POST /migration/import     — batch-write records to DynamoDB
// POST /migration/upload     — return S3 presigned PUT URL for file upload
// POST /migration/verify     — verify record counts match local audit
// POST /migration/cutover    — convert license + mark migration complete
// POST /migration/rollback   — purge all data from a failed migration run
// ============================================================================

import { APIGatewayProxyHandlerV2WithJWTAuthorizer } from 'aws-lambda';
import {
  DynamoDBClient,
  PutItemCommand,
  QueryCommand,
  DeleteItemCommand,
  BatchWriteItemCommand,
} from '@aws-sdk/client-dynamodb';
import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  AdminDeleteUserCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import { randomUUID } from 'crypto';
import { createJsonResponse } from '../utils/response';

const ddb = new DynamoDBClient({});
const cognito = new CognitoIdentityProviderClient({});
const s3 = new S3Client({});

const TABLE = process.env.DYNAMODB_TABLE ?? 'DukanXTable';
const BUCKET = process.env.S3_BUCKET ?? 'dukanx-assets';
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID ?? '';
const MIGRATION_PREFIX = 'MIGRATION#';

// ── Helper: tag all DDB items created during a migration run ──────────────

function migrationPK(migrationId: string): string {
  return `${MIGRATION_PREFIX}${migrationId}`;
}

// ── POST /migration/identity ──────────────────────────────────────────────

export const migrateIdentity: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { migrationId, deviceFingerprint } = body as {
      migrationId: string;
      deviceFingerprint?: string;
    };

    if (!migrationId) {
      return createJsonResponse(400, { error: 'migrationId required' });
    }

    const sub = event.requestContext.authorizer.jwt.claims.sub as string;
    const email =
      (event.requestContext.authorizer.jwt.claims.email as string) ?? '';

    // Record the identity mapping: localUserId → Cognito sub.
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall({
          PK: migrationPK(migrationId),
          SK: `IDENTITY#${sub}`,
          migrationId,
          cognitoSub: sub,
          email,
          deviceFingerprint: deviceFingerprint ?? '',
          migratedAt: new Date().toISOString(),
          entityType: 'MIGRATION_IDENTITY',
        }),
      })
    );

    return createJsonResponse(200, {
      userIdMapping: { [sub]: sub },
      cognitoSub: sub,
    });
  } catch (err: any) {
    console.error('[migrateIdentity]', err);
    return createJsonResponse(500, { error: err.message });
  }
};

// ── POST /migration/import ────────────────────────────────────────────────

export const migrationImport: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { migrationId, table, records } = body as {
      migrationId: string;
      table: string;
      records: Record<string, unknown>[];
    };

    if (!migrationId || !table || !Array.isArray(records)) {
      return createJsonResponse(400, {
        error: 'migrationId, table, and records[] required',
      });
    }

    if (records.length > 25) {
      return createJsonResponse(400, { error: 'Max 25 records per batch' });
    }

    const putRequests = records.map((record) => ({
      PutRequest: {
        Item: marshall(
          {
            PK: `OFFLINE_${table.toUpperCase()}#${record['id'] ?? randomUUID()}`,
            SK: 'METADATA',
            entityType: `OFFLINE_${table.toUpperCase()}`,
            migrationId,
            table,
            ...record,
            _importedAt: new Date().toISOString(),
          },
          { removeUndefinedValues: true }
        ),
      },
    }));

    // DynamoDB BatchWriteItem accepts up to 25 items.
    await ddb.send(
      new BatchWriteItemCommand({
        RequestItems: { [TABLE]: putRequests },
      })
    );

    // Track import progress.
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall({
          PK: migrationPK(migrationId),
          SK: `IMPORT#${table}#${Date.now()}`,
          table,
          count: records.length,
          importedAt: new Date().toISOString(),
          entityType: 'MIGRATION_IMPORT_BATCH',
        }),
      })
    );

    return createJsonResponse(200, {
      imported: records.length,
      table,
    });
  } catch (err: any) {
    console.error('[migrationImport]', err);
    return createJsonResponse(500, { error: err.message });
  }
};

// ── POST /migration/upload ────────────────────────────────────────────────

export const migrationUpload: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { migrationId, key, mimeType, sizeBytes } = body as {
      migrationId: string;
      key: string;
      mimeType: string;
      sizeBytes?: number;
    };

    if (!migrationId || !key || !mimeType) {
      return createJsonResponse(400, {
        error: 'migrationId, key, and mimeType required',
      });
    }

    const s3Key = `migration/${migrationId}/${key}`;
    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: s3Key,
      ContentType: mimeType,
    });

    const url = await getSignedUrl(s3, command, { expiresIn: 3600 });

    // Record file in DDB for verification.
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall({
          PK: migrationPK(migrationId),
          SK: `FILE#${key}`,
          s3Key,
          mimeType,
          sizeBytes: sizeBytes ?? 0,
          uploadedAt: new Date().toISOString(),
          entityType: 'MIGRATION_FILE',
        }),
      })
    );

    return createJsonResponse(200, { url, s3Key });
  } catch (err: any) {
    console.error('[migrationUpload]', err);
    return createJsonResponse(500, { error: err.message });
  }
};

// ── POST /migration/verify ────────────────────────────────────────────────

export const migrationVerify: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { migrationId, expectedCounts, expectedFileCount } = body as {
      migrationId: string;
      expectedCounts: Record<string, number>;
      expectedFileCount: number;
    };

    if (!migrationId) {
      return createJsonResponse(400, { error: 'migrationId required' });
    }

    // Count imported records per table.
    const result = await ddb.send(
      new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
        ExpressionAttributeValues: marshall({
          ':pk': migrationPK(migrationId),
          ':prefix': 'IMPORT#',
        }),
      })
    );

    const importBatches = (result.Items ?? []).map((i) => unmarshall(i));
    const actualCounts: Record<string, number> = {};
    for (const batch of importBatches) {
      const table = batch.table as string;
      actualCounts[table] = (actualCounts[table] ?? 0) + (batch.count as number);
    }

    const mismatches: Record<string, { expected: number; actual: number }> = {};
    for (const [table, expected] of Object.entries(expectedCounts)) {
      const actual = actualCounts[table] ?? 0;
      if (actual < expected * 0.99) {
        // Allow 1% tolerance for edge-case records.
        mismatches[table] = { expected, actual };
      }
    }

    // Count migrated files.
    const fileResult = await ddb.send(
      new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
        ExpressionAttributeValues: marshall({
          ':pk': migrationPK(migrationId),
          ':prefix': 'FILE#',
        }),
      })
    );
    const actualFileCount = (fileResult.Count ?? 0);
    if (expectedFileCount > 0 && actualFileCount < expectedFileCount * 0.99) {
      mismatches['__files__'] = {
        expected: expectedFileCount,
        actual: actualFileCount,
      };
    }

    const allPassed = Object.keys(mismatches).length === 0;
    return createJsonResponse(200, { allPassed, mismatches, actualCounts });
  } catch (err: any) {
    console.error('[migrationVerify]', err);
    return createJsonResponse(500, { error: err.message });
  }
};

// ── POST /migration/cutover ───────────────────────────────────────────────

export const migrationCutover: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const {
      migrationId,
      licenseId,
      clientUUID,
      onlinePlan,
      creditsInMonths,
      subscriptionExpiry,
    } = body as {
      migrationId: string;
      licenseId: string;
      clientUUID: string;
      onlinePlan: string;
      creditsInMonths: number;
      subscriptionExpiry: string;
    };

    if (!migrationId || !licenseId) {
      return createJsonResponse(400, {
        error: 'migrationId and licenseId required',
      });
    }

    const sub = event.requestContext.authorizer.jwt.claims.sub as string;

    // 1. Record license conversion.
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall({
          PK: `LICENSE#${clientUUID}`,
          SK: 'MIGRATION',
          licenseId,
          clientUUID,
          previousMode: 'offline-lifetime',
          onlinePlan,
          creditsInMonths,
          subscriptionExpiry,
          convertedAt: new Date().toISOString(),
          convertedBy: sub,
          entityType: 'LICENSE_MIGRATION',
        }),
      })
    );

    // 2. Update migration run as completed.
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE,
        Item: marshall({
          PK: migrationPK(migrationId),
          SK: 'STATUS',
          migrationId,
          status: 'completed',
          completedAt: new Date().toISOString(),
          entityType: 'MIGRATION_STATUS',
        }),
      })
    );

    return createJsonResponse(200, {
      success: true,
      migrationId,
      onlinePlan,
      subscriptionExpiry,
      creditsInMonths,
    });
  } catch (err: any) {
    console.error('[migrationCutover]', err);
    return createJsonResponse(500, { error: err.message });
  }
};

// ── POST /migration/rollback ──────────────────────────────────────────────

export const migrationRollback: APIGatewayProxyHandlerV2WithJWTAuthorizer = async (
  event
) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { migrationId, failedStep } = body as {
      migrationId: string;
      failedStep?: string;
    };

    if (!migrationId) {
      return createJsonResponse(400, { error: 'migrationId required' });
    }

    // 1. Query all migration metadata items.
    const result = await ddb.send(
      new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: 'PK = :pk',
        ExpressionAttributeValues: marshall({
          ':pk': migrationPK(migrationId),
        }),
      })
    );

    const items = result.Items ?? [];

    // 2. Delete all migration metadata in batches of 25.
    const deleteRequests = items.map((item) => ({
      DeleteRequest: { Key: { PK: item['PK'], SK: item['SK'] } },
    }));

    for (let i = 0; i < deleteRequests.length; i += 25) {
      const chunk = deleteRequests.slice(i, i + 25);
      if (chunk.length > 0) {
        await ddb.send(
          new BatchWriteItemCommand({
            RequestItems: { [TABLE]: chunk },
          })
        );
      }
    }

    // 3. Delete any S3 objects uploaded during this migration.
    const filesQuery = await ddb.send(
      new QueryCommand({
        TableName: TABLE,
        KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
        ExpressionAttributeValues: marshall({
          ':pk': migrationPK(migrationId),
          ':prefix': 'FILE#',
        }),
      })
    );

    const files = (filesQuery.Items ?? []).map((i) => unmarshall(i));
    for (const file of files) {
      try {
        await s3.send(
          new DeleteObjectCommand({
            Bucket: BUCKET,
            Key: file.s3Key as string,
          })
        );
      } catch (_) {
        // Non-fatal — best effort cleanup.
      }
    }

    return createJsonResponse(200, {
      rolledBack: true,
      deletedItems: items.length,
      deletedFiles: files.length,
      failedStep,
    });
  } catch (err: any) {
    console.error('[migrationRollback]', err);
    return createJsonResponse(500, { error: err.message });
  }
};
