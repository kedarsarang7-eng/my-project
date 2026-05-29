// ============================================================================
// MIGRATION SCRIPT: Add RID to existing DynamoDB records
// ============================================================================
// Run this to backfill requestId on existing data without downtime
// Usage: node migrate-existing-data-with-rid.js --table=Bills --batch-size=100

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

// Configuration
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '100');
const TABLES_TO_MIGRATE = [
  'Bills',
  'Customers', 
  'Products',
  'Staff',
];

/**
 * Generate legacy RID for migration
 */
function generateLegacyRid(tenantId, timestamp) {
  // Use timestamp from record as fallback
  const ts = timestamp || Date.now();
  return `${tenantId}-${ts}-legacy`;
}

/**
 * Migrate single table
 */
async function migrateTable(tableName) {
  console.log(`\n[Migration] Starting migration for table: ${tableName}`);
  
  let lastEvaluatedKey = null;
  let processedCount = 0;
  let updatedCount = 0;
  let errorCount = 0;
  
  do {
    // Scan with pagination
    const scanParams = {
      TableName: tableName,
      Limit: BATCH_SIZE,
      ...(lastEvaluatedKey && { ExclusiveStartKey: lastEvaluatedKey }),
    };
    
    const result = await docClient.send(new ScanCommand(scanParams));
    lastEvaluatedKey = result.LastEvaluatedKey;
    
    // Process batch
    for (const item of result.Items || []) {
      processedCount++;
      
      // Skip if already has requestId
      if (item.requestId) {
        console.log(`  [Skip] ${item.PK} already has requestId`);
        continue;
      }
      
      try {
        // Generate RID from existing data
        const tenantId = item.tenantId || item.GSI1PK?.replace('TENANT#', '') || 'unknown';
        const timestamp = item.createdAt || item.updatedAt || Date.now();
        const legacyRid = generateLegacyRid(tenantId, timestamp);
        
        // Update with RID
        await docClient.send(new UpdateCommand({
          TableName: tableName,
          Key: {
            PK: item.PK,
            SK: item.SK,
          },
          UpdateExpression: 'SET requestId = :rid, #updated = :now',
          ExpressionAttributeNames: {
            '#updated': 'updatedAt',
          },
          ExpressionAttributeValues: {
            ':rid': legacyRid,
            ':now': new Date().toISOString(),
          },
          ConditionExpression: 'attribute_not_exists(requestId)',  // Only if not exists
        }));
        
        updatedCount++;
        console.log(`  [Updated] ${item.PK} -> ${legacyRid}`);
        
      } catch (error) {
        if (error.name === 'ConditionalCheckFailedException') {
          console.log(`  [Skip] ${item.PK} was updated by another process`);
        } else {
          console.error(`  [Error] ${item.PK}: ${error.message}`);
          errorCount++;
        }
      }
      
      // Rate limiting - avoid throttling
      if (processedCount % 10 === 0) {
        await new Promise(r => setTimeout(r, 100));
      }
    }
    
    console.log(`[Progress] ${tableName}: ${processedCount} processed, ${updatedCount} updated, ${errorCount} errors`);
    
  } while (lastEvaluatedKey);
  
  console.log(`\n[Migration] Complete for ${tableName}:`);
  console.log(`  Total processed: ${processedCount}`);
  console.log(`  Updated: ${updatedCount}`);
  console.log(`  Errors: ${errorCount}`);
  
  return { processedCount, updatedCount, errorCount };
}

/**
 * Add GSI for requestId lookup
 */
async function addRequestIdGSI(tableName) {
  console.log(`\n[GSI] Adding RequestIdIndex to ${tableName}`);
  
  try {
    // Note: This requires table update which may take time
    // In production, use AWS Console or CLI to add GSI separately
    console.log(`  Please add GSI manually or via CloudFormation:`);
    console.log(`  IndexName: RequestIdIndex`);
    console.log(`  KeySchema: [{ AttributeName: 'GSI2PK', KeyType: 'HASH' }, { AttributeName: 'GSI2SK', KeyType: 'RANGE' }]`);
    console.log(`  Projection: { ProjectionType: 'ALL' }`);
    
  } catch (error) {
    console.error(`  Error: ${error.message}`);
  }
}

/**
 * Main migration
 */
async function main() {
  console.log('========================================');
  console.log('RID Migration Tool');
  console.log('========================================');
  console.log(`Batch size: ${BATCH_SIZE}`);
  console.log(`Tables: ${TABLES_TO_MIGRATE.join(', ')}`);
  console.log('');
  
  const startTime = Date.now();
  const results = [];
  
  for (const tableName of TABLES_TO_MIGRATE) {
    try {
      const result = await migrateTable(tableName);
      results.push({ tableName, ...result });
      
      // Suggest adding GSI
      await addRequestIdGSI(tableName);
      
    } catch (error) {
      console.error(`[Fatal Error] Table ${tableName}: ${error.message}`);
      results.push({ tableName, error: error.message });
    }
  }
  
  const duration = (Date.now() - startTime) / 1000;
  
  console.log('\n========================================');
  console.log('Migration Summary');
  console.log('========================================');
  console.log(`Duration: ${duration}s`);
  console.log('');
  
  for (const result of results) {
    if (result.error) {
      console.log(`${result.tableName}: FAILED - ${result.error}`);
    } else {
      console.log(`${result.tableName}: ${result.updatedCount} updated, ${result.errorCount} errors`);
    }
  }
  
  console.log('\nNext steps:');
  console.log('1. Add GSI "RequestIdIndex" to each table for trace lookup');
  console.log('2. Update application code to use new RID system');
  console.log('3. Enable strict RID validation after 100% rollout');
}

// Run if executed directly
if (require.main === module) {
  main().catch(error => {
    console.error('Migration failed:', error);
    process.exit(1);
  });
}

module.exports = { migrateTable, generateLegacyRid };
