// ============================================================================
// Sub_App_Sync_Layer — Barrel Export
// ============================================================================
//
// Single import point for the API Gateway routing layer (`serverless.yml`
// or its CDK equivalent) and for tests. The two HTTP entries currently
// exposed are:
//
//   GET  /notifications/replay?since=&app=        → replay
//   POST /notifications/{id}/ack                  → ack
//
// JWT-authenticated WebSocket / SSE entry (REQ 8.2, 8.3) is provided
// through the in-app channel adapter at
// `my-backend/src/notifications/channels/in-app.ts` (task 9.1) and is
// re-exported here when that lands so callers wire one module.
//
// Validates: REQ 8.2, 8.3, 8.4, 8.5, 8.5a, 8.7.
// ============================================================================

export { replay } from './replay.handler';
export { ack } from './ack.handler';
