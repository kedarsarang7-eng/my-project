// ============================================================================
// UNS Event_Bus — Barrel Export
// ============================================================================
// Single entry point for every Event_Bus consumer in `my-backend/`. Other
// modules SHOULD import from `notifications/event-bus` (this index) rather
// than reach into individual files, so the canonical surface stays stable
// even as internals are refactored.
//
// Example:
//   import { publishEvent, OutboxPublisher } from '../notifications/event-bus';
// ============================================================================

// Types
export type {
    BusMessageAttributes,
    Category,
    Channel,
    DeliveryMode,
    EventContract,
    OutboxEntry,
    Priority,
    PublishAck,
    PublishFailure,
    Recipient,
    RecipientRole,
    SourceApp,
    ValidationIssue,
} from './types';

// Errors
export {
    EventBusConfigError,
    EventBusError,
    EventBusUnavailableError,
    EventContractValidationError,
    ProducerRateLimitExceededError,
    RetryBudgetExhaustedError,
} from './errors';

// Schema validator
export {
    tryValidateEventContract,
    validateEventContract,
} from './schema-validator';

// Payload redaction validator (REQ 12.8)
export {
    tryValidatePayloadRedaction,
    validatePayloadRedaction,
} from './redaction-validator';

// Delivery modes
export {
    getDeliveryMode,
    shouldUseFifoDedup,
} from './delivery-modes';

// Rate limiter (per-Producer publish throttle, REQ 12.4)
export {
    getSharedRateLimiter,
    ProducerRateLimiter,
    readRateLimiterConfig,
    UNKNOWN_PRODUCER_ID,
    _setSharedRateLimiterForTests,
    type RateLimitDecision,
    type RateLimiterConfig,
} from './rate-limiter';

// Publisher
export {
    isPublisherReady,
    publishBatch,
    publishEvent,
} from './publisher';

// Emit helper (for migration of legacy producers — task 14.9)
export {
    buildEventContract,
    emitUnsEvent,
    type EmitUnsEventInput,
} from './emit-helper';

// Consumer
export {
    backoffSeconds,
    createConsumer,
    DEFAULT_MAX_RETRIES,
    getDlqUrl,
    type Consumer,
    type ConsumerOptions,
    type EventHandler,
    type HandlerContext,
} from './consumer';

// Outbox
export {
    DynamoOutboxStorage,
    InMemoryOutboxStorage,
    OutboxPublisher,
    type OutboxPublisherOptions,
    type OutboxStorage,
} from './outbox';
