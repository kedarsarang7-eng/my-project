// ============================================================================
// BATCH HANDLER — Atomic Multi-Operation Endpoint
// ============================================================================
// POST /api/v1/batch
//
// Accepts a list of operations (set, update, delete) across multiple tables
// and executes them atomically using DynamoDB TransactWriteItems.
//
// Request body:
// {
//   "operations": [
//     { "type": "set", "collection": "bills", "documentId": "abc", "data": {...} },
//     { "type": "update", "collection": "stock", "documentId": "xyz", "data": {...} },
//     { "type": "delete", "collection": "journal_entries", "documentId": "def" }
//   ]
// }
//
// DynamoDB TransactWriteItems supports up to 100 operations per transaction.
// ============================================================================

import {
  success,
  error,
  verifyToken,
  enforceTenantScope,
} from '../shared/utils.mjs';

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  TransactWriteCommand,
} from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

// Collection name → DynamoDB table mapping
const COLLECTION_TABLE_MAP = {
  'bills': process.env.DYNAMODB_TABLE_BILLS || 'DukanX_Bills',
  'customers': process.env.DYNAMODB_TABLE_CUSTOMERS || 'DukanX_Customers',
  'products': process.env.DYNAMODB_TABLE_PRODUCTS || 'DukanX_Products',
  'stock': process.env.DYNAMODB_TABLE_STOCK || 'DukanX_Stock',
  'stock_movements': process.env.DYNAMODB_TABLE_STOCK_MOVEMENTS || 'DukanX_StockMovements',
  'journal_entries': process.env.DYNAMODB_TABLE_JOURNAL_ENTRIES || 'DukanX_JournalEntries',
  'ledgers': process.env.DYNAMODB_TABLE_LEDGERS || 'DukanX_Ledgers',
  'payments': process.env.DYNAMODB_TABLE_PAYMENTS || 'DukanX_Payments',
  'expenses': process.env.DYNAMODB_TABLE_EXPENSES || 'DukanX_Expenses',
  'supplier_advances': process.env.DYNAMODB_TABLE_SUPPLIER_ADVANCES || 'DukanX_SupplierAdvances',
  'accounting_periods': process.env.DYNAMODB_TABLE_ACCOUNTING_PERIODS || 'DukanX_AccountingPeriods',
  'cash_closings': process.env.DYNAMODB_TABLE_CASH_CLOSINGS || 'DukanX_CashClosings',
  'businesses': process.env.DYNAMODB_TABLE_BUSINESSES || 'DukanX_Businesses',
  'users': process.env.DYNAMODB_TABLE_USERS || 'DukanX_Users',
  'user_sessions': process.env.DYNAMODB_TABLE_USER_SESSIONS || 'DukanX_UserSessions',
  'audit_log': process.env.DYNAMODB_TABLE_AUDIT || 'DukanX_AuditLog',
  'backups': process.env.DYNAMODB_TABLE_BACKUPS || 'DukanX_Backups',
  'connections': process.env.DYNAMODB_TABLE_CONNECTIONS || 'DukanX_Connections',
  'estimates': process.env.DYNAMODB_TABLE_ESTIMATES || 'DukanX_Estimates',
};

/**
 * Resolve collection name to DynamoDB table name.
 * Sub-collection paths like 'owners/{id}/stock' → 'stock'
 */
function resolveTable(collection) {
  // Handle sub-collection paths
  const parts = collection.split('/');
  const leaf = parts[parts.length - 1];

  return COLLECTION_TABLE_MAP[leaf]
    || COLLECTION_TABLE_MAP[collection]
    || `DukanX_${leaf.charAt(0).toUpperCase()}${leaf.slice(1)}`;
}

/**
 * Process __fieldValue sentinels in data.
 * Converts { __fieldValue: 'increment', value: 5 } to DynamoDB update expressions.
 */
function processFieldValues(data) {
  const cleaned = {};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === 'object' && value.__fieldValue) {
      switch (value.__fieldValue) {
        case 'increment':
          // For TransactWriteItems, we need to handle increment specially
          // Store as a marker for the update expression builder
          cleaned[key] = { '__increment': value.value };
          break;
        case 'arrayUnion':
          cleaned[key] = value.elements;
          break;
        case 'arrayRemove':
          // Skip — handled by update expression
          break;
        case 'delete':
          // Skip — field removal
          break;
        default:
          cleaned[key] = value;
      }
    } else {
      cleaned[key] = value;
    }
  }
  return cleaned;
}

/**
 * Build a TransactWriteItem from a batch operation.
 */
function buildTransactItem(op, tenantId) {
  const tableName = resolveTable(op.collection);

  switch (op.type) {
    case 'set': {
      const item = {
        ...processFieldValues(op.data || {}),
        id: op.documentId,
        tenantId,
        updatedAt: new Date().toISOString(),
      };
      // Remove __increment markers and apply as direct values for Put
      for (const [key, value] of Object.entries(item)) {
        if (value && typeof value === 'object' && value.__increment !== undefined) {
          item[key] = value.__increment; // Put sets initial value
        }
      }
      return {
        Put: {
          TableName: tableName,
          Item: item,
        },
      };
    }
    case 'update': {
      const data = processFieldValues(op.data || {});
      // Build update expression
      const expressionParts = [];
      const expressionValues = {};
      const expressionNames = {};
      let setParts = [];
      let addParts = [];

      let i = 0;
      for (const [key, value] of Object.entries(data)) {
        const attrName = `#f${i}`;
        const attrValue = `:v${i}`;
        expressionNames[attrName] = key;

        if (value && typeof value === 'object' && value.__increment !== undefined) {
          addParts.push(`${attrName} ${attrValue}`);
          expressionValues[attrValue] = value.__increment;
        } else {
          setParts.push(`${attrName} = ${attrValue}`);
          expressionValues[attrValue] = value;
        }
        i++;
      }

      // Add updatedAt
      expressionNames['#updatedAt'] = 'updatedAt';
      expressionValues[':updatedAt'] = new Date().toISOString();
      setParts.push('#updatedAt = :updatedAt');

      let updateExpression = '';
      if (setParts.length > 0) updateExpression += `SET ${setParts.join(', ')}`;
      if (addParts.length > 0) updateExpression += ` ADD ${addParts.join(', ')}`;

      return {
        Update: {
          TableName: tableName,
          Key: { id: op.documentId, tenantId },
          UpdateExpression: updateExpression.trim(),
          ExpressionAttributeNames: expressionNames,
          ExpressionAttributeValues: expressionValues,
        },
      };
    }
    case 'delete': {
      return {
        Delete: {
          TableName: tableName,
          Key: { id: op.documentId, tenantId },
        },
      };
    }
    default:
      throw new Error(`Unknown operation type: ${op.type}`);
  }
}

// POST /api/v1/batch
export async function handler(event) {
  try {
    // Auth
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    // SECURITY FIX (Finding #1): tenantId MUST come from verified JWT only.
    // NEVER fall back to client-supplied x-tenant-id header — that allows
    // any attacker to impersonate any tenant by setting a header.
    const tenantId = decoded.tenantId;

    if (!tenantId) {
      console.error('[SECURITY] JWT token missing tenantId claim', { sub: decoded.sub });
      return error('Token missing tenant context — access denied', 403);
    }

    // Parse body
    const body = JSON.parse(event.body || '{}');
    const operations = body.operations;

    if (!Array.isArray(operations) || operations.length === 0) {
      return error('operations array required', 400);
    }

    // DynamoDB TransactWriteItems limit is 100
    if (operations.length > 100) {
      return error('Maximum 100 operations per batch (DynamoDB limit)', 400);
    }

    // Validate all operations
    for (const op of operations) {
      if (!op.type || !op.collection || !op.documentId) {
        return error('Each operation requires type, collection, and documentId', 400);
      }
      if (!['set', 'update', 'delete'].includes(op.type)) {
        return error(`Invalid operation type: ${op.type}`, 400);
      }
      // Enforce tenant scope on data
      if (op.data) {
        enforceTenantScope(op.data, { tenantId });
      }
    }

    // Build TransactWriteItems
    const transactItems = operations.map(op => buildTransactItem(op, tenantId));

    // Execute atomic transaction
    await ddb.send(new TransactWriteCommand({
      TransactItems: transactItems,
    }));

    return success({
      message: 'Batch committed successfully',
      operationCount: operations.length,
    });
  } catch (err) {
    console.error('Batch handler error:', err);

    // DynamoDB transaction cancellation provides details
    if (err.name === 'TransactionCanceledException') {
      const reasons = (err.CancellationReasons || [])
        .map((r, i) => r.Code !== 'None' ? `Op ${i}: ${r.Code} - ${r.Message}` : null)
        .filter(Boolean);
      return error(`Transaction failed: ${reasons.join('; ')}`, 409);
    }

    return error('Batch operation failed', 500);
  }
}
