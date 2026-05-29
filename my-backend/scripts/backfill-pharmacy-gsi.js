/* eslint-disable no-console */
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  ScanCommand,
  UpdateCommand,
} = require('@aws-sdk/lib-dynamodb');

const REGION = process.env.AWS_REGION || 'ap-south-1';
const TABLE_NAME = process.env.DYNAMODB_TABLE;
const DRY_RUN = process.argv.includes('--dry-run');
const LIMIT_ARG = process.argv.find((arg) => arg.startsWith('--limit='));
const LIMIT = LIMIT_ARG ? Number(LIMIT_ARG.split('=')[1]) : undefined;

if (!TABLE_NAME) {
  console.error('Missing DYNAMODB_TABLE env var.');
  process.exit(1);
}

const client = new DynamoDBClient({ region: REGION });
const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
});

const ENTITY_TO_GSI = {
  RX_CLAIM: 'RX_CLAIM',
  RX_PRIOR_AUTH: 'RX_PRIOR_AUTH',
  DRUG_MASTER_MAPPING: 'DRUG_MASTER_MAPPING',
  FORMULARY: 'FORMULARY',
};

function toIso(value) {
  if (!value) return new Date(0).toISOString();
  const parsed = new Date(String(value));
  if (Number.isNaN(parsed.getTime())) return new Date(0).toISOString();
  return parsed.toISOString();
}

function entityId(item) {
  if (item.id) return String(item.id);
  if (typeof item.SK === 'string' && item.SK.includes('#')) {
    return item.SK.split('#').slice(1).join('#');
  }
  return 'unknown';
}

function expectedGsi(item) {
  const type = ENTITY_TO_GSI[item.entityType];
  if (!type || !item.tenantId) return null;
  const id = entityId(item);
  const ts = toIso(item.updatedAt || item.submittedAt || item.createdAt);
  return {
    GSI1PK: `TENANT#${item.tenantId}#ENTITY#${type}`,
    GSI1SK: `${ts}#${id}`,
  };
}

async function scanCandidates() {
  const candidates = [];
  let startKey;
  let scanned = 0;

  do {
    const res = await docClient.send(new ScanCommand({
      TableName: TABLE_NAME,
      ProjectionExpression: 'PK, SK, tenantId, entityType, id, createdAt, updatedAt, submittedAt, GSI1PK, GSI1SK',
      ExclusiveStartKey: startKey,
    }));

    for (const item of (res.Items || [])) {
      if (!ENTITY_TO_GSI[item.entityType]) continue;
      const expected = expectedGsi(item);
      if (!expected) continue;
      if (item.GSI1PK === expected.GSI1PK && item.GSI1SK === expected.GSI1SK) continue;
      candidates.push({ item, expected });
      if (LIMIT && candidates.length >= LIMIT) return candidates;
    }

    startKey = res.LastEvaluatedKey;
    scanned += (res.Items || []).length;
    if (scanned % 1000 === 0) {
      console.log(`Scanned ${scanned} rows...`);
    }
  } while (startKey);

  return candidates;
}

async function run() {
  console.log(`Backfill pharmacy GSI start. table=${TABLE_NAME} region=${REGION} dryRun=${DRY_RUN}`);
  const candidates = await scanCandidates();
  console.log(`Candidates needing update: ${candidates.length}`);

  if (DRY_RUN) {
    for (const row of candidates.slice(0, 20)) {
      console.log(`- ${row.item.PK} ${row.item.SK} => ${row.expected.GSI1PK} | ${row.expected.GSI1SK}`);
    }
    if (candidates.length > 20) {
      console.log(`... ${candidates.length - 20} more`);
    }
    console.log('Dry-run complete. No writes made.');
    return;
  }

  let updated = 0;
  for (const row of candidates) {
    await docClient.send(new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { PK: row.item.PK, SK: row.item.SK },
      UpdateExpression: 'SET GSI1PK = :gsi1pk, GSI1SK = :gsi1sk',
      ExpressionAttributeValues: {
        ':gsi1pk': row.expected.GSI1PK,
        ':gsi1sk': row.expected.GSI1SK,
      },
    }));
    updated++;
    if (updated % 100 === 0) {
      console.log(`Updated ${updated}/${candidates.length}...`);
    }
  }

  console.log(`Backfill complete. Updated ${updated} rows.`);
}

run().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
