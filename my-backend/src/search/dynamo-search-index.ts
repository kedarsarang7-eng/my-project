// ============================================================================
// DynamoDB Search Index — Token-Based Search Engine
// ============================================================================
// Replaces OpenSearch with a DynamoDB-native prefix + exact token index.
// Zero additional infrastructure cost. Uses existing DynamoDB client.
//
// Architecture:
//   - Separate DynamoDB table: DukanX-SearchIndex
//   - Prefix tokens for name fields (3→full word length per word)
//   - Exact tokens for identifiers (barcode, SKU, mobile, GST, invoice#)
//   - GSI1: type-scoped search (TENANT#tid#TYPE#PRODUCT → TOKEN#sam#pid)
//   - GSI2: reverse lookup for cleanup (ENTITY#PRODUCT#pid → TENANT#tid)
//
// @author DukanX Engineering
// @version 2.0.0 — OpenSearch removal
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { config } from '../config/environment';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  QueryCommand,
  BatchWriteCommand,
  DeleteCommand,
} from '@aws-sdk/lib-dynamodb';
import type { QueryCommandInput } from '@aws-sdk/lib-dynamodb';
import { logger } from '../utils/logger';

// ── Client (reuses same DynamoDB connection) ────────────────────────────────

const ddbClient = new DynamoDBClient(configureAwsClient({ region: config.aws.region }));
const docClient = DynamoDBDocumentClient.from(ddbClient, {
  marshallOptions: { removeUndefinedValues: true },
  unmarshallOptions: { wrapNumbers: false },
});

// ── Table Config ────────────────────────────────────────────────────────────

const SEARCH_TABLE = config.search.searchIndexTable || 'DukanX-SearchIndex';
const MAX_TOKENS_PER_ENTITY = 25;
const BATCH_SIZE = 25; // DynamoDB BatchWrite limit

// ── Types ───────────────────────────────────────────────────────────────────

export type SearchEntityType = 'PRODUCT' | 'CUSTOMER' | 'INVOICE' | 'SUPPLIER';

export interface SearchableEntity {
  tenantId: string;
  businessId?: string;
  entityType: SearchEntityType;
  entityId: string;
  displayName: string;
  /** Fields to index with prefix tokens (name searches) */
  prefixFields?: Record<string, string>;
  /** Fields to index with exact tokens (ID lookups) */
  exactFields?: Record<string, string>;
}

export interface SearchResult {
  entityType: SearchEntityType;
  entityId: string;
  displayName: string;
  matchField: string;
  businessId?: string;
}

export interface SearchResponse {
  results: {
    products: SearchResult[];
    customers: SearchResult[];
    invoices: SearchResult[];
    suppliers: SearchResult[];
  };
  pagination: {
    cursor: string | null;
    hasMore: boolean;
  };
  meta: {
    strategy: string;
    latencyMs: number;
    totalResults: number;
  };
}

interface SearchIndexItem {
  PK: string;
  SK: string;
  GSI1PK: string;
  GSI1SK: string;
  GSI2PK: string;
  GSI2SK: string;
  entityType: SearchEntityType;
  entityId: string;
  displayName: string;
  fieldSource: string;
  businessId?: string;
  updatedAt: string;
}

// ── Token Generation ────────────────────────────────────────────────────────

/**
 * Generate prefix tokens from a text field.
 * Each word → prefixes from 3 chars to full word length.
 *
 * "Samsung Charger" → [sam, sams, samsu, samsung, cha, char, charg, charge, charger]
 */
export function generatePrefixTokens(text: string): string[] {
  if (!text || text.trim().length < 3) return [];

  const tokens: string[] = [];
  const words = text
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s]/g, '') // strip special chars
    .split(/\s+/)
    .filter((w) => w.length >= 3);

  for (const word of words) {
    for (let len = 3; len <= Math.min(word.length, 15); len++) {
      tokens.push(word.substring(0, len));
    }
  }

  return [...new Set(tokens)];
}

/**
 * Generate exact token for identifier fields.
 * Returns the normalized value as-is (no prefix fragmentation).
 */
export function generateExactToken(value: string): string | null {
  if (!value || value.trim().length === 0) return null;
  return value.trim().toUpperCase();
}

/**
 * Normalize mobile number: strip country code, spaces, leading zeros.
 */
function normalizeMobile(phone: string): string {
  const digits = phone.replace(/\D/g, '');
  // Keep last 10 digits (Indian mobile numbers)
  return digits.length > 10 ? digits.slice(-10) : digits;
}

// ── Index Operations ────────────────────────────────────────────────────────

/**
 * Build search index items for a given entity.
 * Returns DynamoDB items ready for BatchWrite.
 */
function buildIndexItems(entity: SearchableEntity): SearchIndexItem[] {
  const items: SearchIndexItem[] = [];
  const now = new Date().toISOString();
  const { tenantId, entityType, entityId, displayName, businessId } = entity;

  // Prefix tokens (name fields)
  if (entity.prefixFields) {
    for (const [fieldName, fieldValue] of Object.entries(entity.prefixFields)) {
      if (!fieldValue) continue;
      const tokens = generatePrefixTokens(fieldValue);
      for (const token of tokens) {
        items.push({
          PK: `TENANT#${tenantId}`,
          SK: `TOKEN#${token}#${entityType}#${entityId}`,
          GSI1PK: `TENANT#${tenantId}#TYPE#${entityType}`,
          GSI1SK: `TOKEN#${token}#${entityId}`,
          GSI2PK: `ENTITY#${entityType}#${entityId}`,
          GSI2SK: `TENANT#${tenantId}`,
          entityType,
          entityId,
          displayName,
          fieldSource: fieldName,
          businessId,
          updatedAt: now,
        });
      }
    }
  }

  // Exact tokens (identifier fields)
  if (entity.exactFields) {
    for (const [fieldName, fieldValue] of Object.entries(entity.exactFields)) {
      if (!fieldValue) continue;

      let normalizedValue: string;
      if (fieldName === 'mobile' || fieldName === 'phone') {
        normalizedValue = normalizeMobile(fieldValue);
        if (normalizedValue.length < 10) continue;
      } else {
        const exact = generateExactToken(fieldValue);
        if (!exact) continue;
        normalizedValue = exact;
      }

      const fieldTag = fieldName.toUpperCase();
      items.push({
        PK: `TENANT#${tenantId}`,
        SK: `EXACT#${fieldTag}#${normalizedValue}#${entityType}#${entityId}`,
        GSI1PK: `TENANT#${tenantId}#TYPE#${entityType}`,
        GSI1SK: `EXACT#${fieldTag}#${normalizedValue}#${entityId}`,
        GSI2PK: `ENTITY#${entityType}#${entityId}`,
        GSI2SK: `TENANT#${tenantId}`,
        entityType,
        entityId,
        displayName,
        fieldSource: fieldName,
        businessId,
        updatedAt: now,
      });
    }
  }

  // Cap token count to prevent write explosion
  if (items.length > MAX_TOKENS_PER_ENTITY) {
    logger.warn('Token count exceeds limit, truncating', {
      entityType,
      entityId,
      tokenCount: items.length,
      limit: MAX_TOKENS_PER_ENTITY,
    });
    return items.slice(0, MAX_TOKENS_PER_ENTITY);
  }

  return items;
}

/**
 * Index a record into the SearchIndex table.
 * Deletes old tokens first (handles name changes), then writes new ones.
 */
export async function indexRecord(entity: SearchableEntity): Promise<void> {
  const start = Date.now();

  // Step 1: Delete existing tokens for this entity
  await deleteIndex(entity.entityType, entity.entityId, entity.tenantId);

  // Step 2: Build new token items
  const items = buildIndexItems(entity);
  if (items.length === 0) {
    logger.info('No tokens generated, skipping index', {
      entityType: entity.entityType,
      entityId: entity.entityId,
    });
    return;
  }

  // Step 3: BatchWrite in chunks of 25
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE);
    const requests = batch.map((item) => ({
      PutRequest: { Item: item },
    }));

    let retries = 0;
    let unprocessed = requests;

    while (unprocessed.length > 0 && retries < 3) {
      const result = await docClient.send(
        new BatchWriteCommand({
          RequestItems: { [SEARCH_TABLE]: unprocessed },
        })
      );

      const remaining = result.UnprocessedItems?.[SEARCH_TABLE];
      if (!remaining || remaining.length === 0) break;

      retries++;
      await new Promise((r) => setTimeout(r, 100 * Math.pow(2, retries)));
      unprocessed = remaining as typeof unprocessed;
    }

    if (unprocessed.length > 0 && retries >= 3) {
      logger.error('Failed to write all search tokens', {
        entityType: entity.entityType,
        entityId: entity.entityId,
        unprocessedCount: unprocessed.length,
      });
    }
  }

  logger.info('Search index updated', {
    entityType: entity.entityType,
    entityId: entity.entityId,
    tokenCount: items.length,
    latencyMs: Date.now() - start,
  });
}

/**
 * Delete all search index entries for an entity.
 * Uses GSI2 reverse lookup to find all tokens.
 */
export async function deleteIndex(
  entityType: SearchEntityType,
  entityId: string,
  tenantId: string
): Promise<void> {
  // Query GSI2 to find all tokens for this entity
  const result = await docClient.send(
    new QueryCommand({
      TableName: SEARCH_TABLE,
      IndexName: 'GSI2',
      KeyConditionExpression: 'GSI2PK = :gsi2pk',
      ExpressionAttributeValues: {
        ':gsi2pk': `ENTITY#${entityType}#${entityId}`,
      },
      ProjectionExpression: 'PK, SK',
    })
  );

  const items = result.Items || [];
  if (items.length === 0) return;

  // BatchDelete in chunks of 25
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE);
    const requests = batch.map((item) => ({
      DeleteRequest: {
        Key: { PK: item.PK, SK: item.SK },
      },
    }));

    let retries = 0;
    let unprocessed = requests;

    while (unprocessed.length > 0 && retries < 3) {
      const result = await docClient.send(
        new BatchWriteCommand({
          RequestItems: { [SEARCH_TABLE]: unprocessed },
        })
      );

      const remaining = result.UnprocessedItems?.[SEARCH_TABLE];
      if (!remaining || remaining.length === 0) break;

      retries++;
      await new Promise((r) => setTimeout(r, 100 * Math.pow(2, retries)));
      unprocessed = remaining as typeof unprocessed;
    }
  }

  logger.info('Search index cleaned', {
    entityType,
    entityId,
    deletedTokens: items.length,
  });
}

// ── Query Operations ────────────────────────────────────────────────────────

interface QueryStrategy {
  strategy: 'PREFIX' | 'EXACT' | 'MULTI_EXACT';
  field: string | null;
  fields?: string[];
  type: SearchEntityType | null;
}

/**
 * Classify a search query to determine the optimal lookup strategy.
 */
export function classifyQuery(query: string): QueryStrategy {
  const q = query.trim();

  // Pure 10-digit number → mobile
  if (/^\d{10}$/.test(q)) {
    return { strategy: 'EXACT', field: 'MOBILE', type: 'CUSTOMER' };
  }

  // Barcode (8-14 digits)
  if (/^\d{8,14}$/.test(q)) {
    return { strategy: 'EXACT', field: 'BARCODE', type: 'PRODUCT' };
  }

  // Invoice pattern
  if (/^(INV|BILL|DC|EST|CN)\d+$/i.test(q)) {
    return { strategy: 'EXACT', field: 'INVOICENUMBER', type: 'INVOICE' };
  }

  // GST number (15 chars)
  if (/^\d{2}[A-Z]{5}\d{4}[A-Z]\d[A-Z\d]{2}$/i.test(q)) {
    return { strategy: 'EXACT', field: 'GSTIN', type: null }; // search both customer & supplier
  }

  // SKU pattern
  if (/^[A-Z]{2,}-[A-Z\d]+$/i.test(q)) {
    return { strategy: 'EXACT', field: 'SKU', type: 'PRODUCT' };
  }

  // Short numeric — ambiguous
  if (/^\d{5,9}$/.test(q)) {
    return {
      strategy: 'MULTI_EXACT',
      field: null,
      fields: ['MOBILE', 'INVOICENUMBER', 'BARCODE'],
      type: null,
    };
  }

  // Default: prefix name search
  return { strategy: 'PREFIX', field: null, type: null };
}

/**
 * Search for entities matching a query within a tenant.
 */
export async function search(
  query: string,
  tenantId: string,
  opts?: {
    entityType?: SearchEntityType;
    limit?: number;
    cursor?: string;
  }
): Promise<{ results: SearchResult[]; cursor: string | null; hasMore: boolean }> {
  const limit = Math.min(opts?.limit || 20, 100);
  const strategy = classifyQuery(query);
  const q = query.trim().toLowerCase();

  let exclusiveStartKey: Record<string, unknown> | undefined;
  if (opts?.cursor) {
    try {
      exclusiveStartKey = JSON.parse(
        Buffer.from(opts.cursor, 'base64url').toString()
      );
    } catch {
      // Invalid cursor, ignore
    }
  }

  let results: SearchResult[] = [];

  if (strategy.strategy === 'PREFIX') {
    results = await prefixSearch(tenantId, q, opts?.entityType || null, limit, exclusiveStartKey);
  } else if (strategy.strategy === 'EXACT') {
    results = await exactSearch(
      tenantId,
      strategy.field!,
      query.trim().toUpperCase(),
      strategy.type,
      limit
    );
  } else if (strategy.strategy === 'MULTI_EXACT') {
    // Fan out to multiple exact fields
    const promises = (strategy.fields || []).map((field) =>
      exactSearch(tenantId, field, query.trim().toUpperCase(), null, limit)
    );
    const allResults = await Promise.allSettled(promises);
    for (const r of allResults) {
      if (r.status === 'fulfilled') {
        results.push(...r.value);
      }
    }
    // Deduplicate by entityId
    const seen = new Set<string>();
    results = results.filter((r) => {
      const key = `${r.entityType}#${r.entityId}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  return {
    results: results.slice(0, limit),
    cursor: null, // Simplified — extend with LastEvaluatedKey if needed
    hasMore: results.length > limit,
  };
}

/**
 * Global search: fan out across all entity types.
 */
export async function globalSearch(
  query: string,
  tenantId: string,
  limit: number = 10
): Promise<SearchResponse> {
  const start = Date.now();
  const strategy = classifyQuery(query);

  // For exact lookups with known type, skip fan-out
  if (strategy.strategy === 'EXACT' && strategy.type) {
    const results = await search(query, tenantId, {
      entityType: strategy.type,
      limit,
    });

    return formatGlobalResponse(results.results, strategy.strategy, start);
  }

  // Fan out across all entity types in parallel
  const entityTypes: SearchEntityType[] = ['PRODUCT', 'CUSTOMER', 'INVOICE', 'SUPPLIER'];
  const promises = entityTypes.map((type) =>
    search(query, tenantId, { entityType: type, limit })
      .then((r) => r.results)
      .catch((err) => {
        logger.error('Search failed for entity type', {
          entityType: type,
          error: err instanceof Error ? err.message : String(err),
        });
        return [] as SearchResult[];
      })
  );

  const results = await Promise.all(promises);
  const allResults = results.flat();

  return formatGlobalResponse(allResults, strategy.strategy, start);
}

// ── Internal Query Functions ────────────────────────────────────────────────

async function prefixSearch(
  tenantId: string,
  normalizedQuery: string,
  entityType: SearchEntityType | null,
  limit: number,
  exclusiveStartKey?: Record<string, unknown>
): Promise<SearchResult[]> {
  const token = normalizedQuery.split(/\s+/)[0]; // Use first word for prefix
  if (token.length < 3) return [];

  let params: QueryCommandInput;

  if (entityType) {
    // Type-scoped search via GSI1
    params = {
      TableName: SEARCH_TABLE,
      IndexName: 'GSI1',
      KeyConditionExpression:
        'GSI1PK = :gsi1pk AND begins_with(GSI1SK, :prefix)',
      ExpressionAttributeValues: {
        ':gsi1pk': `TENANT#${tenantId}#TYPE#${entityType}`,
        ':prefix': `TOKEN#${token}`,
      },
      Limit: limit * 3, // Over-fetch for dedup
      ExclusiveStartKey: exclusiveStartKey,
    };
  } else {
    // Global prefix search via main table
    params = {
      TableName: SEARCH_TABLE,
      KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
      ExpressionAttributeValues: {
        ':pk': `TENANT#${tenantId}`,
        ':prefix': `TOKEN#${token}`,
      },
      Limit: limit * 3,
      ExclusiveStartKey: exclusiveStartKey,
    };
  }

  const result = await docClient.send(new QueryCommand(params));
  const items = (result.Items || []) as SearchIndexItem[];

  // Deduplicate by entityId (multiple tokens can match same entity)
  const seen = new Set<string>();
  const results: SearchResult[] = [];

  for (const item of items) {
    const key = `${item.entityType}#${item.entityId}`;
    if (seen.has(key)) continue;
    seen.add(key);

    // Multi-word query: verify all words match the display name
    if (normalizedQuery.includes(' ')) {
      const words = normalizedQuery.split(/\s+/);
      const name = item.displayName.toLowerCase();
      const allMatch = words.every((w) => name.includes(w.substring(0, 3)));
      if (!allMatch) continue;
    }

    results.push({
      entityType: item.entityType,
      entityId: item.entityId,
      displayName: item.displayName,
      matchField: item.fieldSource,
      businessId: item.businessId,
    });

    if (results.length >= limit) break;
  }

  return results;
}

async function exactSearch(
  tenantId: string,
  field: string,
  value: string,
  entityType: SearchEntityType | null,
  limit: number
): Promise<SearchResult[]> {
  let skPrefix: string;

  if (entityType) {
    skPrefix = `EXACT#${field}#${value}#${entityType}`;
  } else {
    skPrefix = `EXACT#${field}#${value}`;
  }

  const params: QueryCommandInput = {
    TableName: SEARCH_TABLE,
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :prefix)',
    ExpressionAttributeValues: {
      ':pk': `TENANT#${tenantId}`,
      ':prefix': skPrefix,
    },
    Limit: limit,
  };

  const result = await docClient.send(new QueryCommand(params));
  const items = (result.Items || []) as SearchIndexItem[];

  return items.map((item) => ({
    entityType: item.entityType,
    entityId: item.entityId,
    displayName: item.displayName,
    matchField: item.fieldSource,
    businessId: item.businessId,
  }));
}

// ── Entity Transformers ─────────────────────────────────────────────────────

/**
 * Transform a product record into a SearchableEntity.
 */
export function productToSearchable(
  tenantId: string,
  product: Record<string, unknown>,
  businessId?: string
): SearchableEntity {
  return {
    tenantId,
    businessId,
    entityType: 'PRODUCT',
    entityId: String(product.id || product.productId || ''),
    displayName: String(product.name || ''),
    prefixFields: {
      name: String(product.name || ''),
    },
    exactFields: {
      barcode: product.barcode ? String(product.barcode) : '',
      sku: product.sku ? String(product.sku) : '',
    },
  };
}

/**
 * Transform a customer record into a SearchableEntity.
 */
export function customerToSearchable(
  tenantId: string,
  customer: Record<string, unknown>,
  businessId?: string
): SearchableEntity {
  return {
    tenantId,
    businessId,
    entityType: 'CUSTOMER',
    entityId: String(customer.id || customer.customerId || ''),
    displayName: String(customer.name || ''),
    prefixFields: {
      name: String(customer.name || ''),
    },
    exactFields: {
      mobile: customer.phone ? String(customer.phone) : '',
      gstin: customer.gstin ? String(customer.gstin) : '',
    },
  };
}

/**
 * Transform an invoice/bill record into a SearchableEntity.
 */
export function invoiceToSearchable(
  tenantId: string,
  invoice: Record<string, unknown>,
  businessId?: string
): SearchableEntity {
  return {
    tenantId,
    businessId,
    entityType: 'INVOICE',
    entityId: String(invoice.id || invoice.billId || ''),
    displayName: String(invoice.invoiceNumber || ''),
    prefixFields: {},
    exactFields: {
      invoiceNumber: invoice.invoiceNumber
        ? String(invoice.invoiceNumber)
        : '',
    },
  };
}

/**
 * Transform a supplier record into a SearchableEntity.
 */
export function supplierToSearchable(
  tenantId: string,
  supplier: Record<string, unknown>,
  businessId?: string
): SearchableEntity {
  return {
    tenantId,
    businessId,
    entityType: 'SUPPLIER',
    entityId: String(supplier.id || supplier.supplierId || ''),
    displayName: String(supplier.name || ''),
    prefixFields: {
      name: String(supplier.name || ''),
    },
    exactFields: {
      mobile: supplier.phone ? String(supplier.phone) : '',
      gstin: supplier.gstin ? String(supplier.gstin) : '',
    },
  };
}

// ── Response Formatter ──────────────────────────────────────────────────────

function formatGlobalResponse(
  results: SearchResult[],
  strategy: string,
  startTime: number
): SearchResponse {
  const grouped: SearchResponse['results'] = {
    products: [],
    customers: [],
    invoices: [],
    suppliers: [],
  };

  for (const r of results) {
    switch (r.entityType) {
      case 'PRODUCT':
        grouped.products.push(r);
        break;
      case 'CUSTOMER':
        grouped.customers.push(r);
        break;
      case 'INVOICE':
        grouped.invoices.push(r);
        break;
      case 'SUPPLIER':
        grouped.suppliers.push(r);
        break;
    }
  }

  return {
    results: grouped,
    pagination: { cursor: null, hasMore: false },
    meta: {
      strategy,
      latencyMs: Date.now() - startTime,
      totalResults: results.length,
    },
  };
}
