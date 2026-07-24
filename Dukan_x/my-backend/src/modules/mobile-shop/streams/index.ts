/**
 * MobileShop Streams — Barrel Export
 *
 * DynamoDB Streams consumer with partial-batch failure handling,
 * versioned change decoding, deduplication, and WebSocket fan-out.
 *
 * Requirements: 7.4, 7.10–7.15, 8.4
 */

// Stream Consumer (Lambda handler)
export { handler as streamConsumerHandler } from './stream-consumer';

// WebSocket Fan-out
export { fanoutPullHints } from './websocket-fanout';

// Types
export type {
  StreamRecord,
  StreamAction,
  PullHint,
  BatchItemFailure,
  StreamConsumerResult,
  RecordProcessingResult,
  RecordRoute,
  WebSocketConnection,
  WebSocketSendResult,
} from './stream-types';
