// ============================================================================
// DynamoDB Client — Re-exports from my-backend's existing dynamodb.config.ts
// ============================================================================
// Instead of duplicating the DDB client, we re-export from the existing config.
// This ensures a single connection pool across all handlers.
//
// The app-backend's CRUD factory expects specific function signatures —
// this file adapts them to my-backend's existing client functions.
// ============================================================================

import {
  docClient,
  TABLE_NAME,
  getItem as _getItem,
  putItem as _putItem,
  updateItem as _updateItem,
  queryItems as _queryItems,
  transactWrite as _transactWrite,
  batchWrite as _batchWriteItems,
} from '../config/dynamodb.config';

export { docClient, TABLE_NAME };

// ---- Adapted getItem (app-backend signature) ----

export async function getItem<T>(
  pk: string,
  sk: string,
  options?: { consistentRead?: boolean; projectionExpression?: string },
): Promise<T | null> {
  // my-backend's getItem doesn't support options — use raw docClient for advanced cases
  if (options?.consistentRead || options?.projectionExpression) {
    const { GetCommand } = await import('@aws-sdk/lib-dynamodb');
    const params: any = {
      TableName: TABLE_NAME,
      Key: { PK: pk, SK: sk },
      ConsistentRead: options?.consistentRead ?? false,
    };
    if (options?.projectionExpression) {
      params.ProjectionExpression = options.projectionExpression;
    }
    const result = await docClient.send(new GetCommand(params));
    return (result.Item as T) ?? null;
  }
  return _getItem<T>(pk, sk);
}

// ---- Adapted putItem (app-backend signature) ----

export async function putItem(
  item: Record<string, unknown>,
  options?: {
    conditionExpression?: string;
    expressionAttributeNames?: Record<string, string>;
  },
): Promise<void> {
  if (options?.expressionAttributeNames) {
    const { PutCommand } = await import('@aws-sdk/lib-dynamodb');
    const params: any = {
      TableName: TABLE_NAME,
      Item: item,
    };
    if (options.conditionExpression) params.ConditionExpression = options.conditionExpression;
    if (options.expressionAttributeNames) params.ExpressionAttributeNames = options.expressionAttributeNames;
    await docClient.send(new PutCommand(params));
    return;
  }
  await _putItem(item, options?.conditionExpression);
}

// ---- Adapted updateItem (app-backend signature) ----

export async function updateItem(
  pk: string,
  sk: string,
  updateExpression: string,
  expressionAttributeValues: Record<string, unknown>,
  options?: {
    conditionExpression?: string;
    expressionAttributeNames?: Record<string, string>;
    returnValues?: 'ALL_NEW' | 'ALL_OLD' | 'UPDATED_NEW' | 'UPDATED_OLD' | 'NONE';
  },
): Promise<Record<string, unknown> | null> {
  return _updateItem(pk, sk, {
    updateExpression,
    expressionAttributeValues,
    conditionExpression: options?.conditionExpression,
    expressionAttributeNames: options?.expressionAttributeNames,
  });
}

// ---- Adapted queryItems (app-backend signature with richer options) ----

export async function queryItems<T>(
  pkValue: string,
  options?: {
    skBeginsWith?: string;
    skBetween?: { start: string; end: string };
    indexName?: string;
    limit?: number;
    scanForward?: boolean;
    filterExpression?: string;
    expressionAttributeValues?: Record<string, unknown>;
    expressionAttributeNames?: Record<string, string>;
    projectionExpression?: string;
    exclusiveStartKey?: Record<string, unknown>;
  },
): Promise<{ items: T[]; lastEvaluatedKey?: Record<string, unknown> }> {
  // Handle skBetween (app-backend feature not in my-backend's queryItems)
  if (options?.skBetween) {
    const { QueryCommand } = await import('@aws-sdk/lib-dynamodb');

    // Determine correct PK/SK attribute names based on GSI
    const gsiPkAttr = options.indexName === 'GSI1Index' ? 'GSI1PK'
      : options.indexName === 'GSI2Index' ? 'GSI2PK'
      : options.indexName === 'GSI3Index' ? 'GSI3PK'
      : 'PK';

    const skAttr = options.indexName === 'GSI1Index' ? 'GSI1SK'
      : options.indexName === 'GSI2Index' ? 'GSI2SK'
      : options.indexName === 'GSI3Index' ? 'GSI3SK'
      : 'SK';

    const keyCondition = `${gsiPkAttr} = :pk AND ${skAttr} BETWEEN :skStart AND :skEnd`;
    const exprValues: Record<string, unknown> = {
      ':pk': pkValue,
      ':skStart': options.skBetween.start,
      ':skEnd': options.skBetween.end,
      ...options.expressionAttributeValues,
    };

    const params: any = {
      TableName: TABLE_NAME,
      KeyConditionExpression: keyCondition,
      ExpressionAttributeValues: exprValues,
      ScanIndexForward: options.scanForward ?? true,
    };

    if (options.indexName) params.IndexName = options.indexName;
    if (options.limit) params.Limit = options.limit;
    if (options.filterExpression) params.FilterExpression = options.filterExpression;
    if (options.expressionAttributeNames) params.ExpressionAttributeNames = options.expressionAttributeNames;
    if (options.projectionExpression) params.ProjectionExpression = options.projectionExpression;
    if (options.exclusiveStartKey) params.ExclusiveStartKey = options.exclusiveStartKey;

    const result = await docClient.send(new QueryCommand(params));
    return {
      items: (result.Items as T[]) ?? [],
      lastEvaluatedKey: result.LastEvaluatedKey as Record<string, unknown> | undefined,
    };
  }

  // Delegate to existing queryItems for skBeginsWith / simple queries
  // Map indexName conventions: app-backend uses 'GSI1Index', my-backend uses 'GSI1'
  const mappedIndex = options?.indexName
    ? options.indexName.replace('Index', '')
    : undefined;

  const result = await _queryItems<T>(pkValue, options?.skBeginsWith, {
    limit: options?.limit,
    scanIndexForward: options?.scanForward,
    filterExpression: options?.filterExpression,
    expressionAttributeValues: options?.expressionAttributeValues,
    expressionAttributeNames: options?.expressionAttributeNames,
    indexName: mappedIndex,
    exclusiveStartKey: options?.exclusiveStartKey,
  });

  return {
    items: result.items,
    lastEvaluatedKey: result.lastKey,
  };
}

// ---- Adapted transactWrite (app-backend signature) ----

export async function transactWrite(
  params: { TransactItems: any[] },
): Promise<void> {
  await _transactWrite(params.TransactItems);
}

// ---- batchWrite ----

export async function batchWrite(
  items: any,
): Promise<void> {
  const { BatchWriteCommand } = await import('@aws-sdk/lib-dynamodb');
  let unprocessed = items;

  for (let attempt = 0; attempt < 3; attempt++) {
    const result = await docClient.send(new BatchWriteCommand(unprocessed));
    if (
      !result.UnprocessedItems ||
      Object.keys(result.UnprocessedItems).length === 0
    ) {
      return;
    }
    await new Promise((resolve) =>
      setTimeout(resolve, Math.pow(2, attempt) * 100),
    );
    unprocessed = { RequestItems: result.UnprocessedItems };
  }

  throw new Error(
    'DynamoDB batch write failed after 3 retries — unprocessed items remain',
  );
}

// ---- softDelete ----

export async function softDelete(
  pk: string,
  sk: string,
  userId: string,
  currentVersion: number,
): Promise<void> {
  await updateItem(
    pk,
    sk,
    'SET is_deleted = :deleted, updated_at = :now, updated_by = :user, version = version + :inc',
    {
      ':deleted': true,
      ':now': new Date().toISOString(),
      ':user': userId,
      ':inc': 1,
      ':expectedVersion': currentVersion,
      ':notDeleted': false,
    },
    {
      conditionExpression: 'version = :expectedVersion AND is_deleted = :notDeleted',
    },
  );
}
