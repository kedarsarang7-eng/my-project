// ============================================================================
// Search Indexer V2 — DynamoDB Stream → DynamoDB SearchIndex
// ============================================================================
// Replaces OpenSearch indexing. Triggered by DynamoDB Streams on main table.
// Transforms entity writes into search tokens in the SearchIndex table.
//
// @author DukanX Engineering
// @version 2.0.0
// ============================================================================

import { DynamoDBStreamEvent, DynamoDBRecord, Context } from 'aws-lambda';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { AttributeValue } from '@aws-sdk/client-dynamodb';
import { logger } from '../utils/logger';
import {
  indexRecord,
  deleteIndex,
  productToSearchable,
  customerToSearchable,
  invoiceToSearchable,
  supplierToSearchable,
  SearchEntityType,
  SearchableEntity,
} from '../search/dynamo-search-index';

/**
 * Map SK prefixes to search entity types.
 */
const SK_TO_ENTITY: Record<string, SearchEntityType> = {
  PRODUCT: 'PRODUCT',
  CUSTOMER: 'CUSTOMER',
  INVOICE: 'INVOICE',
  BILL: 'INVOICE',
  VENDOR: 'SUPPLIER',
  SUPPLIER: 'SUPPLIER',
  PARTY: 'SUPPLIER',
};

/**
 * Main Lambda handler — DynamoDB Streams.
 */
export const handler = async (
  event: DynamoDBStreamEvent,
  context: Context
): Promise<{ batchItemFailures: { itemIdentifier: string }[] }> => {
  logger.info('SearchIndexer V2 processing', {
    recordCount: event.Records.length,
    requestId: context.awsRequestId,
  });

  const batchItemFailures: { itemIdentifier: string }[] = [];
  const operations: Promise<void>[] = [];

  for (const record of event.Records) {
    try {
      const op = processRecord(record);
      if (op) operations.push(op);
    } catch (error) {
      logger.error('Record processing error', {
        eventID: record.eventID,
        error: error instanceof Error ? error.message : String(error),
      });
      if (isRetryable(error)) {
        batchItemFailures.push({ itemIdentifier: record.eventID! });
      }
    }
  }

  // Wait for all indexing ops
  const results = await Promise.allSettled(operations);
  const failures = results.filter((r) => r.status === 'rejected');

  if (failures.length > 0) {
    logger.warn('Some indexing operations failed', {
      total: operations.length,
      failed: failures.length,
    });
  }

  logger.info('SearchIndexer V2 complete', {
    total: event.Records.length,
    indexed: operations.length - failures.length,
    failed: failures.length + batchItemFailures.length,
  });

  return { batchItemFailures };
};

/**
 * Process a single DynamoDB stream record.
 */
function processRecord(record: DynamoDBRecord): Promise<void> | null {
  const eventName = record.eventName;
  if (!eventName) return null;

  if (eventName === 'REMOVE') {
    return handleRemove(record);
  }

  // INSERT or MODIFY
  const newImage = record.dynamodb?.NewImage;
  if (!newImage) return null;

  const doc = unmarshall(newImage as Record<string, AttributeValue>);

  // Skip soft-deleted records
  if (doc.deletedAt || doc.isDeleted) {
    return handleRemove(record);
  }

  // Detect entity type from SK
  const entityType = detectEntityType(doc);
  if (!entityType) return null;

  const tenantId = extractTenantId(doc);
  if (!tenantId) {
    logger.warn('Missing tenantId, skipping', {
      eventID: record.eventID,
    });
    return null;
  }

  const businessId = doc.businessId as string | undefined;
  let entity: SearchableEntity;

  switch (entityType) {
    case 'PRODUCT':
      entity = productToSearchable(tenantId, doc, businessId);
      break;
    case 'CUSTOMER':
      entity = customerToSearchable(tenantId, doc, businessId);
      break;
    case 'INVOICE':
      entity = invoiceToSearchable(tenantId, doc, businessId);
      break;
    case 'SUPPLIER':
      entity = supplierToSearchable(tenantId, doc, businessId);
      break;
    default:
      return null;
  }

  if (!entity.entityId) {
    logger.warn('Entity missing ID, skipping', { entityType });
    return null;
  }

  return indexRecord(entity);
}

/**
 * Handle record deletion — clean up search tokens.
 */
function handleRemove(record: DynamoDBRecord): Promise<void> | null {
  const image =
    record.dynamodb?.OldImage || record.dynamodb?.NewImage;
  if (!image) return null;

  const doc = unmarshall(image as Record<string, AttributeValue>);
  const entityType = detectEntityType(doc);
  const tenantId = extractTenantId(doc);

  if (!entityType || !tenantId) return null;

  const entityId = extractEntityId(doc, entityType);
  if (!entityId) return null;

  return deleteIndex(entityType, entityId, tenantId);
}

/**
 * Detect entity type from document SK prefix.
 */
function detectEntityType(doc: Record<string, unknown>): SearchEntityType | null {
  const sk = (doc.SK || doc.sk || '') as string;
  if (sk) {
    const prefix = sk.split('#')[0].toUpperCase();
    const mapped = SK_TO_ENTITY[prefix];
    if (mapped) return mapped;
  }

  // Fallback: check explicit entityType field
  const explicit = doc.entityType || doc._type;
  if (explicit && typeof explicit === 'string') {
    const mapped = SK_TO_ENTITY[explicit.toUpperCase()];
    if (mapped) return mapped;
  }

  // Heuristic detection
  if (doc.sku !== undefined && doc.sellingPrice !== undefined) return 'PRODUCT';
  if (doc.phone && doc.totalDues !== undefined) return 'CUSTOMER';
  if (doc.invoiceNumber && doc.grandTotal !== undefined) return 'INVOICE';
  if (doc.creditDays !== undefined && doc.totalOutstanding !== undefined) return 'SUPPLIER';

  return null;
}

function extractTenantId(doc: Record<string, unknown>): string | null {
  const tid =
    doc.tenantId || doc.TenantId || doc.tenant_id;
  if (tid && typeof tid === 'string') return tid;

  // Extract from PK: "TENANT#abc123#BIZ#..." → "abc123"
  const pk = doc.PK || doc.pk;
  if (pk && typeof pk === 'string') {
    const match = pk.match(/^TENANT#([^#]+)/);
    if (match) return match[1];
  }

  return null;
}

function extractEntityId(doc: Record<string, unknown>, entityType: SearchEntityType): string | null {
  // Try explicit ID fields
  const idFields: Record<SearchEntityType, string[]> = {
    PRODUCT: ['id', 'productId'],
    CUSTOMER: ['id', 'customerId'],
    INVOICE: ['id', 'billId', 'invoiceId'],
    SUPPLIER: ['id', 'supplierId', 'vendorId'],
  };

  for (const field of idFields[entityType]) {
    if (doc[field] && typeof doc[field] === 'string') {
      return doc[field] as string;
    }
  }

  // Extract from SK: "PRODUCT#abc123" → "abc123"
  const sk = (doc.SK || doc.sk || '') as string;
  if (sk.includes('#')) {
    return sk.split('#').pop() || null;
  }

  return null;
}

function isRetryable(error: unknown): boolean {
  if (error instanceof Error) {
    return ['ECONNRESET', 'ETIMEDOUT', 'ThrottlingException', 'ProvisionedThroughputExceededException']
      .some((p) => error.message.includes(p) || error.name.includes(p));
  }
  return false;
}
