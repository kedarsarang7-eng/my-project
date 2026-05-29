/**
 * OpenSearch Index Initialization Script
 * 
 * Creates all required indices with proper mappings after deployment.
 * Also provides backfill capability for existing DynamoDB data.
 * 
 * Usage:
 *   npx ts-node scripts/init-search-indices.ts [--stage dev] [--backfill]
 * 
 * @author DukanX Engineering
 */

import { Client } from '@opensearch-project/opensearch';
import { AwsSigv4Signer } from '@opensearch-project/opensearch/aws';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { DynamoDBClient, ScanCommand, paginateScan } from '@aws-sdk/client-dynamodb';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { searchIndexes, SearchIndexName } from '../src/search/opensearch-mappings';
import * as readline from 'readline';

// Configuration
const STAGE = process.argv.find(arg => arg.startsWith('--stage='))?.split('=')[1] || 'dev';
const SHOULD_BACKFILL = process.argv.includes('--backfill');
const DRY_RUN = process.argv.includes('--dry-run');
const BATCH_SIZE = 500;

// AWS Region
const AWS_REGION = process.env.AWS_REGION || 'ap-south-1';

/**
 * Create OpenSearch client
 */
function createClient(): Client {
  const endpoint = process.env.OPENSEARCH_ENDPOINT;
  
  if (!endpoint) {
    throw new Error('OPENSEARCH_ENDPOINT environment variable is required');
  }

  return new Client({
    ...AwsSigv4Signer({
      region: AWS_REGION,
      service: 'es',
      getCredentials: () => {
        const credentialsProvider = defaultProvider();
        return credentialsProvider();
      },
    }),
    node: endpoint,
  });
}

/**
 * Create DynamoDB client
 */
function createDynamoClient(): DynamoDBClient {
  return new DynamoDBClient({ region: AWS_REGION });
}

/**
 * Initialize all search indices
 */
async function initializeIndices(client: Client): Promise<void> {
  console.log(`\n🔄 Initializing search indices for stage: ${STAGE}\n`);

  const indexNames = Object.keys(searchIndexes) as SearchIndexName[];
  
  for (const indexKey of indexNames) {
    const indexConfig = searchIndexes[indexKey];
    const indexName = `${STAGE}-${indexConfig.index}`;

    try {
      // Check if index exists
      const exists = await client.indices.exists({ index: indexName });
      
      if (exists.body) {
        console.log(`  ⚠️  Index already exists: ${indexName}`);
        
        // Ask for confirmation to delete (if not dry run)
        if (!DRY_RUN) {
          const shouldRecreate = await confirm(`Recreate index ${indexName}? (y/N): `);
          if (shouldRecreate) {
            console.log(`  🗑️  Deleting index: ${indexName}`);
            await client.indices.delete({ index: indexName });
            console.log(`  ✅ Deleted: ${indexName}`);
          } else {
            console.log(`  ⏭️  Skipping: ${indexName}`);
            continue;
          }
        } else {
          console.log(`  ⏭️  [DRY RUN] Would skip: ${indexName}`);
          continue;
        }
      }

      if (DRY_RUN) {
        console.log(`  📝 [DRY RUN] Would create index: ${indexName}`);
        continue;
      }

      // Create index with mappings
      console.log(`  📝 Creating index: ${indexName}`);
      await client.indices.create({
        index: indexName,
        body: indexConfig.body,
      });
      
      console.log(`  ✅ Created: ${indexName}`);
    } catch (error) {
      console.error(`  ❌ Failed to create index ${indexName}:`, error);
    }
  }

  console.log('\n✅ Index initialization complete\n');
}

/**
 * Backfill data from DynamoDB to OpenSearch
 */
async function backfillData(osClient: Client, ddbClient: DynamoDBClient): Promise<void> {
  console.log(`\n🔄 Starting backfill from DynamoDB to OpenSearch\n`);
  
  const tableName = `DukanX-${STAGE}`;
  
  // Entity type mapping (SK prefix to entity type)
  const entityPrefixMap: Record<string, SearchIndexName> = {
    'BILL': 'bills',
    'CUSTOMER': 'customers',
    'PRODUCT': 'products',
    'BATCH': 'productBatches',
    'SUPPLIER': 'suppliers',
    'PURCHASE': 'purchaseBills',
    'PATIENT': 'patients',
    'VISIT': 'visits',
    'PRESCRIPTION': 'prescriptions',
    'KOT': 'kots',
    'MENU': 'menuItems',
    'LEDGER': 'ledgerEntries',
    'EXPENSE': 'expenses',
    'BANK': 'bankTransactions',
    'CHALLAN': 'deliveryChallans',
    'BOOK_RETURN': 'bookReturns',
    'PREORDER': 'preOrders',
    'JOB': 'serviceJobs',
    'EINVOICE': 'eInvoices',
    'FUEL': 'fuelTransactions',
  };

  console.log(`📊 Scanning table: ${tableName}`);

  let totalProcessed = 0;
  let totalIndexed = 0;
  let totalErrors = 0;

  // Paginated scan
  const paginator = paginateScan(
    { client: ddbClient, pageSize: BATCH_SIZE },
    {
      TableName: tableName,
      ProjectionExpression: 'PK, SK, #data',
      ExpressionAttributeNames: { '#data': 'data' },
    }
  );

  const batch: { index: string; id: string; body: Record<string, unknown> }[] = [];

  for await (const page of paginator) {
    if (!page.Items) continue;

    for (const item of page.Items) {
      totalProcessed++;
      
      const unmarshalled = unmarshall(item);
      const pk = unmarshalled.PK as string;
      const sk = unmarshalled.SK as string;
      
      // Extract entity type from SK prefix
      const skPrefix = sk.split('#')[0];
      const entityType = entityPrefixMap[skPrefix];
      
      if (!entityType) {
        continue; // Skip non-searchable entities
      }

      // Skip soft-deleted items
      if (unmarshalled.deletedAt || unmarshalled.isDeleted) {
        continue;
      }

      const indexName = `${STAGE}-dukanx-${entityType}`;
      const docId = sk.replace(/^[A-Z_]+#/, '');

      // Transform document (simplified - production should use same logic as indexer)
      const doc = transformDocument(unmarshalled, entityType);
      
      if (!doc.tenantId) {
        console.warn(`  ⚠️  Skipping item without tenantId: ${pk}#${sk}`);
        continue;
      }

      batch.push({
        index: indexName,
        id: docId,
        body: doc,
      });

      // Bulk index when batch is full
      if (batch.length >= BATCH_SIZE) {
        const result = await bulkIndex(osClient, batch);
        totalIndexed += result.indexed;
        totalErrors += result.errors;
        batch.length = 0; // Clear batch
        
        process.stdout.write(`\r  📦 Processed: ${totalProcessed} | Indexed: ${totalIndexed} | Errors: ${totalErrors}`);
      }
    }
  }

  // Index remaining items
  if (batch.length > 0) {
    const result = await bulkIndex(osClient, batch);
    totalIndexed += result.indexed;
    totalErrors += result.errors;
  }

  console.log(`\n\n✅ Backfill complete:`);
  console.log(`   📊 Total processed: ${totalProcessed}`);
  console.log(`   ✅ Total indexed: ${totalIndexed}`);
  console.log(`   ❌ Total errors: ${totalErrors}\n`);
}

/**
 * Bulk index documents
 */
async function bulkIndex(
  client: Client,
  batch: { index: string; id: string; body: Record<string, unknown> }[]
): Promise<{ indexed: number; errors: number }> {
  if (DRY_RUN) {
    console.log(`\n  [DRY RUN] Would index ${batch.length} documents`);
    return { indexed: batch.length, errors: 0 };
  }

  const body = batch.flatMap(doc => [
    { index: { _index: doc.index, _id: doc.id } },
    doc.body,
  ]);

  try {
    const response = await client.bulk({ body });
    const items = response.body.items as Array<{ index?: { result: string; error?: unknown } }>;
    
    const indexed = items.filter(item => 
      item.index?.result === 'created' || item.index?.result === 'updated'
    ).length;
    
    const errors = items.filter(item => item.index?.error).length;

    return { indexed, errors };
  } catch (error) {
    console.error('  ❌ Bulk index failed:', error);
    return { indexed: 0, errors: batch.length };
  }
}

/**
 * Transform DynamoDB document to search document (simplified)
 */
function transformDocument(
  doc: Record<string, unknown>,
  entityType: SearchIndexName
): Record<string, unknown> {
  const base = {
    tenantId: extractTenantId(doc),
    businessId: doc.businessId || doc.shopId,
    businessType: doc.businessType,
  };

  switch (entityType) {
    case 'bills':
      return {
        ...base,
        billId: doc.id || doc.billId,
        invoiceNumber: doc.invoiceNumber,
        customerName: doc.customerName,
        customerPhone: doc.customerPhone,
        grandTotal: doc.grandTotal,
        status: doc.status,
        billDate: doc.billDate || doc.date,
        createdAt: doc.createdAt,
      };
    
    case 'customers':
      return {
        ...base,
        customerId: doc.id || doc.customerId,
        name: doc.name,
        phone: doc.phone,
        email: doc.email,
        gstin: doc.gstin,
        isActive: doc.isActive,
        createdAt: doc.createdAt,
      };
    
    case 'products':
      return {
        ...base,
        productId: doc.id || doc.productId,
        name: doc.name,
        sku: doc.sku,
        barcode: doc.barcode,
        category: doc.category,
        sellingPrice: doc.sellingPrice,
        stockQuantity: doc.stockQuantity,
        createdAt: doc.createdAt,
      };
    
    // Add more entity types as needed
    default:
      return { ...base, ...doc };
  }
}

function extractTenantId(doc: Record<string, unknown>): string {
  return doc.tenantId || doc.TenantId || doc.userId || doc.ownerId || 'unknown';
}

/**
 * Prompt for confirmation
 */
function confirm(question: string): Promise<boolean> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes');
    });
  });
}

/**
 * Check index health and document counts
 */
async function checkIndices(client: Client): Promise<void> {
  console.log('\n🔍 Checking index health:\n');

  const indexNames = Object.values(searchIndexes).map(
    config => `${STAGE}-${config.index}`
  );

  try {
    const health = await client.cluster.health();
    console.log(`  Cluster status: ${health.body.status}`);
    console.log(`  Nodes: ${health.body.number_of_nodes}`);
    console.log(`  Active shards: ${health.body.active_shards}\n`);

    // Get stats for each index
    for (const indexName of indexNames) {
      try {
        const stats = await client.indices.stats({ index: indexName });
        const docCount = stats.body.indices[indexName]?.total?.docs?.count || 0;
        const storeSize = stats.body.indices[indexName]?.total?.store?.size_in_bytes || 0;
        
        console.log(`  📁 ${indexName}:`);
        console.log(`     Documents: ${docCount}`);
        console.log(`     Size: ${formatBytes(storeSize)}`);
      } catch {
        console.log(`  ⚠️  ${indexName}: Not found`);
      }
    }
    
    console.log('');
  } catch (error) {
    console.error('  ❌ Failed to check index health:', error);
  }
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Main execution
 */
async function main(): Promise<void> {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('  DukanX Search Index Initialization');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`  Stage: ${STAGE}`);
  console.log(`  Backfill: ${SHOULD_BACKFILL ? 'YES' : 'NO'}`);
  console.log(`  Dry Run: ${DRY_RUN ? 'YES' : 'NO'}`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  if (!process.env.OPENSEARCH_ENDPOINT) {
    console.error('❌ OPENSEARCH_ENDPOINT environment variable is required');
    console.log('\nSet it with:');
    console.log('  export OPENSEARCH_ENDPOINT=https://your-domain.ap-south-1.es.amazonaws.com\n');
    process.exit(1);
  }

  const osClient = createClient();
  const ddbClient = createDynamoClient();

  try {
    // Initialize indices
    await initializeIndices(osClient);

    // Backfill if requested
    if (SHOULD_BACKFILL) {
      if (DRY_RUN) {
        console.log('\n📝 [DRY RUN] Would backfill data from DynamoDB\n');
      } else {
        const confirmed = await confirm('Backfill existing data from DynamoDB? This may take a while. (y/N): ');
        if (confirmed) {
          await backfillData(osClient, ddbClient);
        } else {
          console.log('\n⏭️  Skipping backfill\n');
        }
      }
    }

    // Check index status
    await checkIndices(osClient);

    console.log('✅ All done!\n');
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { initializeIndices, backfillData, checkIndices };
