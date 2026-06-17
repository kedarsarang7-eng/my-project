#!/usr/bin/env npx ts-node
// ============================================================================
// SearchIndex Backfill Script
// ============================================================================
// One-time migration: scans existing data from the main DynamoDB table and
// indexes it into the SearchIndex table.
//
// Usage:
//   npx ts-node scripts/backfill-search-index.ts [--dry-run] [--entity PRODUCT|CUSTOMER|INVOICE|SUPPLIER]
//
// Prerequisites:
//   - SEARCH_INDEX_TABLE env var set (or uses default 'DukanX-SearchIndex')
//   - AWS credentials configured (local profile or IAM role)
//   - Main data table accessible
//
// @author DukanX Engineering
// ============================================================================

import { DynamoDBClient, ScanCommand } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import type { AttributeValue } from '@aws-sdk/client-dynamodb';
import {
  indexRecord,
  productToSearchable,
  customerToSearchable,
  invoiceToSearchable,
  supplierToSearchable,
  SearchEntityType,
} from '../src/search/dynamo-search-index';

// ── Config ──────────────────────────────────────────────────────────────────

const DATA_TABLE = process.env.DYNAMODB_TABLE || process.env.DATA_TABLE || '';
const REGION = process.env.AWS_REGION || 'ap-south-1';
const DRY_RUN = process.argv.includes('--dry-run');
const ENTITY_FILTER = (() => {
  const idx = process.argv.indexOf('--entity');
  return idx !== -1 ? process.argv[idx + 1]?.toUpperCase() : null;
})();

// Throttle: max concurrent indexing operations
const CONCURRENCY = 10;
const SCAN_LIMIT = 100; // Items per scan page

// ── DynamoDB Client ─────────────────────────────────────────────────────────

const client = new DynamoDBClient({ region: REGION });

// ── Entity Detection (same logic as search-indexer-v2.ts) ───────────────────

const SK_TO_ENTITY: Record<string, SearchEntityType> = {
  PRODUCT: 'PRODUCT',
  CUSTOMER: 'CUSTOMER',
  INVOICE: 'INVOICE',
  BILL: 'INVOICE',
  VENDOR: 'SUPPLIER',
  SUPPLIER: 'SUPPLIER',
  PARTY: 'SUPPLIER',
};

function detectEntityType(doc: Record<string, unknown>): SearchEntityType | null {
  const sk = (doc.SK || doc.sk || '') as string;
  if (sk) {
    const prefix = sk.split('#')[0].toUpperCase();
    const mapped = SK_TO_ENTITY[prefix];
    if (mapped) return mapped;
  }

  if (doc.sku !== undefined && doc.sellingPrice !== undefined) return 'PRODUCT';
  if (doc.phone && doc.totalDues !== undefined) return 'CUSTOMER';
  if (doc.invoiceNumber && doc.grandTotal !== undefined) return 'INVOICE';
  if (doc.creditDays !== undefined && doc.totalOutstanding !== undefined) return 'SUPPLIER';

  return null;
}

function extractTenantId(doc: Record<string, unknown>): string | null {
  const tid = doc.tenantId || doc.TenantId || doc.tenant_id;
  if (tid && typeof tid === 'string') return tid;

  const pk = doc.PK || doc.pk;
  if (pk && typeof pk === 'string') {
    const match = (pk as string).match(/^TENANT#([^#]+)/);
    if (match) return match[1];
  }
  return null;
}

// ── Backfill Logic ──────────────────────────────────────────────────────────

interface BackfillStats {
  scanned: number;
  indexed: number;
  skipped: number;
  errors: number;
  byType: Record<string, number>;
}

async function backfill(): Promise<void> {
  if (!DATA_TABLE) {
    console.error('❌ ERROR: Set DYNAMODB_TABLE or DATA_TABLE env var');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════════════════');
  console.log('  DukanX SearchIndex Backfill');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`  Source Table  : ${DATA_TABLE}`);
  console.log(`  Target Table  : ${process.env.SEARCH_INDEX_TABLE || 'DukanX-SearchIndex'}`);
  console.log(`  Region        : ${REGION}`);
  console.log(`  Dry Run       : ${DRY_RUN ? 'YES (no writes)' : 'NO (live writes)'}`);
  console.log(`  Entity Filter : ${ENTITY_FILTER || 'ALL'}`);
  console.log(`  Concurrency   : ${CONCURRENCY}`);
  console.log('═══════════════════════════════════════════════════════\n');

  const stats: BackfillStats = {
    scanned: 0,
    indexed: 0,
    skipped: 0,
    errors: 0,
    byType: {},
  };

  let lastKey: Record<string, AttributeValue> | undefined;
  let pageCount = 0;

  do {
    const result = await client.send(
      new ScanCommand({
        TableName: DATA_TABLE,
        Limit: SCAN_LIMIT,
        ExclusiveStartKey: lastKey,
      })
    );

    lastKey = result.LastEvaluatedKey;
    pageCount++;
    const items = result.Items || [];

    // Process items in batches of CONCURRENCY
    const promises: Promise<void>[] = [];

    for (const rawItem of items) {
      stats.scanned++;

      const doc = unmarshall(rawItem);

      // Skip deleted
      if (doc.deletedAt || doc.isDeleted) {
        stats.skipped++;
        continue;
      }

      const entityType = detectEntityType(doc);
      if (!entityType) {
        stats.skipped++;
        continue;
      }

      // Apply entity filter if specified
      if (ENTITY_FILTER && entityType !== ENTITY_FILTER) {
        stats.skipped++;
        continue;
      }

      const tenantId = extractTenantId(doc);
      if (!tenantId) {
        stats.skipped++;
        continue;
      }

      const businessId = doc.businessId as string | undefined;

      // Build searchable entity
      let entity;
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
          stats.skipped++;
          continue;
      }

      if (!entity.entityId) {
        stats.skipped++;
        continue;
      }

      stats.byType[entityType] = (stats.byType[entityType] || 0) + 1;

      if (DRY_RUN) {
        stats.indexed++;
        continue;
      }

      // Throttle: wait when we hit concurrency limit
      if (promises.length >= CONCURRENCY) {
        await Promise.allSettled(promises);
        promises.length = 0;
      }

      promises.push(
        indexRecord(entity)
          .then(() => {
            stats.indexed++;
          })
          .catch((err) => {
            stats.errors++;
            console.error(`  ⚠ Error indexing ${entityType}/${entity.entityId}: ${err.message}`);
          })
      );
    }

    // Wait for remaining promises in this page
    await Promise.allSettled(promises);

    // Progress
    if (pageCount % 10 === 0) {
      console.log(
        `  📄 Page ${pageCount} | Scanned: ${stats.scanned} | Indexed: ${stats.indexed} | Errors: ${stats.errors}`
      );
    }
  } while (lastKey);

  // Final report
  console.log('\n═══════════════════════════════════════════════════════');
  console.log('  Backfill Complete');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`  Total Scanned  : ${stats.scanned}`);
  console.log(`  Total Indexed  : ${stats.indexed}`);
  console.log(`  Total Skipped  : ${stats.skipped}`);
  console.log(`  Total Errors   : ${stats.errors}`);
  console.log('  By Entity Type :');
  for (const [type, count] of Object.entries(stats.byType)) {
    console.log(`    ${type}: ${count}`);
  }
  console.log('═══════════════════════════════════════════════════════\n');

  if (stats.errors > 0) {
    console.warn('⚠ Some records failed to index. Review errors above and re-run.');
    process.exit(1);
  }
}

// ── Run ─────────────────────────────────────────────────────────────────────

backfill().catch((err) => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
