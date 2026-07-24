/**
 * MobileShop DynamoDB Streams Consumer
 *
 * Processes batched DynamoDB stream records with:
 * - Versioned change decoding (dataModelVersion check)
 * - Partial-batch failure handling (individual failures don't fail the batch)
 * - Deduplication by event identity (eventId)
 * - Routing to reconciliation or notification consumers
 * - Returns batchItemFailures for EventBridge Pipes retry
 *
 * Requirements: 7.4, 7.10–7.15, 8.4
 */

import type { DynamoDBStreamEvent, DynamoDBRecord } from 'aws-lambda';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import { extractTenantId } from '../persistence/key-codec';
import { fanoutPullHints } from './websocket-fanout';
import type {
  StreamRecord,
  StreamAction,
  StreamConsumerResult,
  RecordProcessingResult,
  RecordRoute,
} from './stream-types';

// ─── Deduplication Cache ─────────────────────────────────────────────────────

/**
 * In-memory deduplication set for the current invocation.
 * DynamoDB Streams delivers at-least-once; we skip duplicates within a batch.
 * Cross-invocation deduplication relies on idempotent consumers.
 */
const processedEventIds = new Set<string>();

// ─── Main Handler ────────────────────────────────────────────────────────────

/**
 * Lambda handler for DynamoDB Streams via EventBridge Pipes.
 *
 * Uses partial-batch failure reporting: individual record failures
 * are collected and returned in `batchItemFailures` so that only
 * failed records are retried by the pipe.
 */
export async function handler(
  event: DynamoDBStreamEvent,
): Promise<StreamConsumerResult> {
  const results: RecordProcessingResult[] = [];

  // Clear deduplication cache per invocation
  processedEventIds.clear();

  for (const record of event.Records) {
    const result = await processRecord(record);
    results.push(result);
  }

  // Return only failed items for partial-batch retry
  const batchItemFailures = results
    .filter((r) => !r.success)
    .map((r) => ({ itemIdentifier: r.sequenceNumber }));

  return { batchItemFailures };
}

// ─── Record Processing ───────────────────────────────────────────────────────

async function processRecord(
  record: DynamoDBRecord,
): Promise<RecordProcessingResult> {
  const sequenceNumber = record.dynamodb?.SequenceNumber ?? 'unknown';

  try {
    // Decode the stream record
    const decoded = decodeStreamRecord(record);
    if (!decoded) {
      // Skip records we can't decode (e.g., unsupported version, missing keys)
      return { sequenceNumber, success: true };
    }

    // Deduplicate by event identity within this batch
    if (processedEventIds.has(decoded.eventId)) {
      return { sequenceNumber, success: true };
    }
    processedEventIds.add(decoded.eventId);

    // Route to appropriate consumer
    const route = classifyRecord(decoded);

    switch (route) {
      case 'reconciliation':
        await handleReconciliationRecord(decoded);
        break;
      case 'notification':
        await handleNotificationRecord(decoded);
        break;
      case 'skip':
        // No processing needed (e.g., idempotency TTL deletes)
        break;
    }

    return { sequenceNumber, success: true };
  } catch (error) {
    // Log the failure but continue processing remaining records
    const errorMessage =
      error instanceof Error ? error.message : 'Unknown error';

    console.log(
      JSON.stringify({
        eventType: 'STREAM_RECORD_FAILURE',
        timestamp: new Date().toISOString(),
        sequenceNumber,
        error: errorMessage,
      }),
    );

    return { sequenceNumber, success: false, error: errorMessage };
  }
}

// ─── Record Decoding ─────────────────────────────────────────────────────────

/**
 * Decodes a raw DynamoDB stream record into a typed StreamRecord.
 * Returns null for records that should be silently skipped.
 */
function decodeStreamRecord(record: DynamoDBRecord): StreamRecord | null {
  const image = record.dynamodb?.NewImage ?? record.dynamodb?.OldImage;
  if (!image) return null;

  // Check dataModelVersion compatibility
  const dataModelVersion = image.dataModelVersion?.N
    ? parseInt(image.dataModelVersion.N, 10)
    : undefined;

  if (dataModelVersion === undefined) {
    // Records without version are legacy — skip silently
    return null;
  }

  if (
    dataModelVersion < MODEL_VERSION_CONFIG.minSupportedVersion ||
    dataModelVersion > MODEL_VERSION_CONFIG.maxSupportedVersion
  ) {
    console.log(
      JSON.stringify({
        eventType: 'STREAM_VERSION_SKIP',
        timestamp: new Date().toISOString(),
        dataModelVersion,
        minSupported: MODEL_VERSION_CONFIG.minSupportedVersion,
        maxSupported: MODEL_VERSION_CONFIG.maxSupportedVersion,
        sequenceNumber: record.dynamodb?.SequenceNumber,
      }),
    );
    return null;
  }

  // Extract tenant ID from PK
  const pk = image.PK?.S;
  if (!pk) return null;

  let tenantId: string;
  try {
    tenantId = extractTenantId(pk);
  } catch {
    // Malformed key — skip silently
    return null;
  }

  // Extract entity metadata
  const entityType = image.entityType?.S ?? 'UNKNOWN';
  const entityId = image.entityId?.S ?? '';
  const version = image.version?.N ? parseInt(image.version.N, 10) : 0;
  const eventId = image.eventId?.S ?? record.dynamodb?.SequenceNumber ?? '';

  // Determine action from the event name and record content
  const action = resolveAction(record, image);

  // Detect reconciliation/control records
  const isReconciliation = detectReconciliation(pk, entityType);

  return {
    eventId,
    tenantId,
    entityType,
    entityId,
    version,
    dataModelVersion,
    action,
    isReconciliation,
    eventName: (record.eventName as 'INSERT' | 'MODIFY' | 'REMOVE') ?? 'MODIFY',
    approximateCreationDateTime:
      record.dynamodb?.ApproximateCreationDateTime ?? Date.now() / 1000,
    sequenceNumber: record.dynamodb?.SequenceNumber ?? '',
  };
}

// ─── Action Resolution ───────────────────────────────────────────────────────

function resolveAction(
  record: DynamoDBRecord,
  image: Record<string, any>,
): StreamAction {
  const eventName = record.eventName;

  if (eventName === 'REMOVE') return 'DELETE';
  if (eventName === 'INSERT') {
    // Check if it's a claim
    const sk = image.SK?.S ?? '';
    if (sk.startsWith('IMEI#') || sk.startsWith('RESERVATION#')) {
      return 'CLAIM_CREATE';
    }
    return 'CREATE';
  }

  // MODIFY — check for lifecycle or reconciliation transitions
  const newImage = record.dynamodb?.NewImage;
  const oldImage = record.dynamodb?.OldImage;

  if (newImage && oldImage) {
    // Lifecycle transition: status/state changed
    const newState = newImage.lifecycleState?.S ?? newImage.status?.S;
    const oldState = oldImage.lifecycleState?.S ?? oldImage.status?.S;
    if (newState && oldState && newState !== oldState) {
      // Reconciliation record status change
      const entityType = newImage.entityType?.S ?? '';
      if (entityType === 'RECONCILIATION') {
        const newStatus = newImage.status?.S;
        return newStatus === 'COMPLETED'
          ? 'RECONCILIATION_COMPLETE'
          : 'RECONCILIATION_STEP';
      }
      return 'LIFECYCLE_TRANSITION';
    }
  }

  return 'UPDATE';
}

// ─── Record Classification ───────────────────────────────────────────────────

function detectReconciliation(pk: string, entityType: string): boolean {
  return pk.includes('#RECON#') || entityType === 'RECONCILIATION';
}

function classifyRecord(record: StreamRecord): RecordRoute {
  // Reconciliation/control records → reconciliation consumer
  if (record.isReconciliation) return 'reconciliation';

  // TTL removals of idempotency records → skip
  if (record.eventName === 'REMOVE' && record.entityType === 'IDEMPOTENCY') {
    return 'skip';
  }

  // Domain changes → notification (WebSocket hints)
  return 'notification';
}

// ─── Consumer Handlers ───────────────────────────────────────────────────────

/**
 * Handles reconciliation/control record changes.
 * Routes to bounded reconciliation workers via EventBridge.
 * Currently logs structured events for downstream processing.
 */
async function handleReconciliationRecord(record: StreamRecord): Promise<void> {
  console.log(
    JSON.stringify({
      eventType: 'STREAM_RECONCILIATION_TRIGGER',
      timestamp: new Date().toISOString(),
      tenantId: record.tenantId,
      entityId: record.entityId,
      action: record.action,
      version: record.version,
      sequenceNumber: record.sequenceNumber,
    }),
  );

  // Reconciliation workers are triggered via EventBridge Pipe filter.
  // The pipe configuration (serverless.yml task 2.1) routes reconciliation
  // records to the reconciliation worker Lambda. This handler serves as
  // the primary stream consumer entry point for all records.
}

/**
 * Handles domain change notifications.
 * Fans out minimal pull hints to connected WebSocket clients for the tenant.
 */
async function handleNotificationRecord(record: StreamRecord): Promise<void> {
  await fanoutPullHints(record);
}
