// ============================================================
// Dukan Marketplace - DynamoDB Client
// Single-table design utilities with proper scoping
// ============================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { 
  DynamoDBDocumentClient, 
  GetCommand, 
  PutCommand, 
  UpdateCommand, 
  DeleteCommand,
  QueryCommand,
  TransactWriteCommand,
  BatchGetCommand,
  ScanCommand,
  type TransactWriteCommandInput,
} from '@aws-sdk/lib-dynamodb';
import { PK, SK, GSI1PK, GSI1SK } from './types';

// ---------- CLIENT SETUP ----------

const client = new DynamoDBClient({});
export const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    convertEmptyValues: false,
    removeUndefinedValues: true,
    convertClassInstanceToMap: true,
  },
  unmarshallOptions: {
    wrapNumbers: false,
  },
});

const TABLE_NAME = process.env.TABLE_NAME || 'DukanMarketplace';

// ---------- SINGLE OPERATIONS ----------

export async function getItem<T>(pk: string, sk: string): Promise<T | null> {
  const result = await docClient.send(new GetCommand({
    TableName: TABLE_NAME,
    Key: { PK: pk, SK: sk },
  }));

  return (result.Item as T) || null;
}

export async function putItem<T extends Record<string, unknown>>(item: T): Promise<void> {
  await docClient.send(new PutCommand({
    TableName: TABLE_NAME,
    Item: item,
  }));
}

export async function deleteItem(pk: string, sk: string): Promise<void> {
  await docClient.send(new DeleteCommand({
    TableName: TABLE_NAME,
    Key: { PK: pk, SK: sk },
  }));
}

// ---------- UPDATE WITH EXPRESSION ----------

interface UpdateOptions {
  set?: Record<string, unknown>;
  remove?: string[];
  add?: Record<string, number>;
  condition?: string;
  conditionValues?: Record<string, unknown>;
}

export async function updateItem(
  pk: string, 
  sk: string, 
  options: UpdateOptions
): Promise<void> {
  const updateExpressions: string[] = [];
  const expressionAttributeNames: Record<string, string> = {};
  const expressionAttributeValues: Record<string, unknown> = {};

  // Build SET expression
  if (options.set) {
    const sets = Object.entries(options.set).map(([key, value], idx) => {
      const nameKey = `#f${idx}`;
      const valueKey = `:v${idx}`;
      expressionAttributeNames[nameKey] = key;
      expressionAttributeValues[valueKey] = value;
      return `${nameKey} = ${valueKey}`;
    });
    if (sets.length) {
      updateExpressions.push(`SET ${sets.join(', ')}`);
    }
  }

  // Build REMOVE expression
  if (options.remove?.length) {
    const removes = options.remove.map((field, idx) => {
      const nameKey = `#r${idx}`;
      expressionAttributeNames[nameKey] = field;
      return nameKey;
    });
    updateExpressions.push(`REMOVE ${removes.join(', ')}`);
  }

  // Build ADD expression
  if (options.add) {
    const adds = Object.entries(options.add).map(([key, value], idx) => {
      const nameKey = `#a${idx}`;
      const valueKey = `:av${idx}`;
      expressionAttributeNames[nameKey] = key;
      expressionAttributeValues[valueKey] = value;
      return `${nameKey} ${valueKey}`;
    });
    if (adds.length) {
      updateExpressions.push(`ADD ${adds.join(', ')}`);
    }
  }

  interface UpdateParams {
    TableName: string;
    Key: { PK: string; SK: string };
    UpdateExpression: string;
    ExpressionAttributeValues: Record<string, unknown>;
    ExpressionAttributeNames?: Record<string, string>;
    ConditionExpression?: string;
  }

  const params: UpdateParams = {
    TableName: TABLE_NAME,
    Key: { PK: pk, SK: sk },
    UpdateExpression: updateExpressions.join(' '),
    ExpressionAttributeValues: expressionAttributeValues,
  };

  if (Object.keys(expressionAttributeNames).length > 0) {
    params.ExpressionAttributeNames = expressionAttributeNames;
  }

  if (options.condition) {
    params.ConditionExpression = options.condition;
    if (options.conditionValues) {
      params.ExpressionAttributeValues = {
        ...params.ExpressionAttributeValues,
        ...options.conditionValues,
      };
    }
  }

  await docClient.send(new UpdateCommand(params));
}

// ---------- QUERY OPERATIONS ----------

export interface QueryOptions {
  limit?: number;
  startKey?: Record<string, unknown>;
  scanIndexForward?: boolean;
}

export async function queryByPK<T>(
  pk: string, 
  options: QueryOptions = {}
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: { ':pk': pk },
    Limit: options.limit,
    ExclusiveStartKey: options.startKey,
    ScanIndexForward: options.scanIndexForward ?? false, // Default DESC
  }));

  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey,
  };
}

export async function queryByPKSKPrefix<T>(
  pk: string,
  skPrefix: string,
  options: QueryOptions = {}
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
    ExpressionAttributeValues: { 
      ':pk': pk, 
      ':prefix': skPrefix,
    },
    Limit: options.limit,
    ExclusiveStartKey: options.startKey,
    ScanIndexForward: options.scanIndexForward ?? false,
  }));

  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey,
  };
}

// Query by GSI1
export async function queryByGSI1<T>(
  gsi1pk: string,
  options: QueryOptions & { gsi1skPrefix?: string } = {}
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const keyCondition = options.gsi1skPrefix
    ? 'GSI1PK = :gsi1pk AND begins_with(GSI1SK, :prefix)'
    : 'GSI1PK = :gsi1pk';

  const expressionValues: Record<string, unknown> = { ':gsi1pk': gsi1pk };
  if (options.gsi1skPrefix) {
    expressionValues[':prefix'] = options.gsi1skPrefix;
  }

  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: 'GSI1',
    KeyConditionExpression: keyCondition,
    ExpressionAttributeValues: expressionValues,
    Limit: options.limit,
    ExclusiveStartKey: options.startKey,
    ScanIndexForward: options.scanIndexForward ?? false,
  }));

  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey,
  };
}

// Query by GSI2
export async function queryByGSI2<T>(
  gsi2pk: string,
  options: QueryOptions & { gsi2skPrefix?: string } = {}
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const keyCondition = options.gsi2skPrefix
    ? 'GSI2PK = :gsi2pk AND begins_with(GSI2SK, :prefix)'
    : 'GSI2PK = :gsi2pk';

  const expressionValues: Record<string, unknown> = { ':gsi2pk': gsi2pk };
  if (options.gsi2skPrefix) {
    expressionValues[':prefix'] = options.gsi2skPrefix;
  }

  const result = await docClient.send(new QueryCommand({
    TableName: TABLE_NAME,
    IndexName: 'GSI2',
    KeyConditionExpression: keyCondition,
    ExpressionAttributeValues: expressionValues,
    Limit: options.limit,
    ExclusiveStartKey: options.startKey,
    ScanIndexForward: options.scanIndexForward ?? false,
  }));

  return {
    items: (result.Items || []) as T[],
    lastKey: result.LastEvaluatedKey,
  };
}

// ---------- TRANSACTIONS ----------

export async function transactWrite(
  items: NonNullable<TransactWriteCommandInput['TransactItems']>
): Promise<void> {
  await docClient.send(new TransactWriteCommand({
    TransactItems: items,
  }));
}

// ---------- BATCH OPERATIONS ----------

export async function batchGetItems(
  keys: { PK: string; SK: string }[]
): Promise<Record<string, unknown>[]> {
  const result = await docClient.send(new BatchGetCommand({
    RequestItems: {
      [TABLE_NAME]: {
        Keys: keys,
      },
    },
  }));

  return result.Responses?.[TABLE_NAME] || [];
}

// ---------- UTILITY QUERIES ----------

// Check if customer is connected to business
export async function isCustomerConnected(
  businessId: string, 
  customerId: string
): Promise<boolean> {
  const connection = await getItem(
    PK.business(businessId),
    SK.connection(customerId)
  );
  return connection !== null && (connection as { status: string }).status === 'active';
}

// Get customer cart
export async function getCustomerCart(businessId: string, customerId: string) {
  return getItem(
    PK.business(businessId),
    SK.cart(customerId)
  );
}

// Get product
export async function getProduct(businessId: string, productId: string) {
  return getItem(
    PK.business(businessId),
    SK.product(productId)
  );
}

// Get order
export async function getOrder(businessId: string, orderId: string, customerId: string) {
  return getItem(
    PK.business(businessId),
    SK.order(orderId, customerId)
  );
}
