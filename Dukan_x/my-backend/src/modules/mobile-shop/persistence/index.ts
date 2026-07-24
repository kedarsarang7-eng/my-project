/**
 * MobileShop Persistence — Barrel Export
 *
 * Tenant-bound DynamoDB key codec, named access-pattern queries (AP-01–AP-15),
 * base repository with tenant verification, and concrete MobileShop repository.
 *
 * Requirements: 6.6, 6.14, 6.19, 6.25, 6.28–6.30, 8.9, 9.12
 */

// Key Codec
export {
  encodePK,
  encodeMetaSK,
  encodeChildSK,
  encodeSK,
  encodeGSI1PK,
  encodeGSI1SK,
  encodeGSI2PK,
  encodeGSI2SK,
  decodePK,
  decodeSK,
  extractTenantId,
  verifyTenantInKey,
  verifyItemTenant,
  buildEntityAggregatePK,
  buildClaimPK,
  buildUnitLifecycleGSI1PK,
  buildInvoicePK,
  buildCustomerHistoryGSI2PK,
  buildServiceJobGSI1PK,
  buildWarrantyGSI1PK,
  buildStatusGSI1PK,
  buildChangeFeedPK,
  buildAuditTimelineGSI2PK,
  buildReconciliationGSI1PK,
  buildProjectionPK,
  buildIdempotencyPK,
  buildCatalogGSI2PK,
  KeyCodecError,
  type BaseKey,
  type GSI1Key,
  type GSI2Key,
  type ItemKeys,
  type DecodedPK,
  type DecodedSK,
} from './key-codec';

// Access Patterns
export {
  INDEX_NAMES,
  UnsupportedQueryError,
  queryEntityAggregate,
  getImeiClaim,
  queryUnitsByLifecycle,
  queryInvoiceAssociations,
  queryCustomerDeviceHistory,
  queryServiceJobsByStatus,
  queryWarrantiesByStatus,
  queryByEntityTypeAndStatus,
  getReservationClaim,
  queryChangeFeed,
  queryAuditTimeline,
  queryReconciliationWork,
  queryKpiProjection,
  getIdempotencyOutcome,
  queryCatalogByPrefix,
  type AccessPatternId,
  type ConsistencyMode,
  type QueryInput,
  type GetInput,
  type PaginationParams,
} from './access-patterns';

// Repository Base
export {
  RepositoryBase,
  type DynamoItem,
  type PaginatedResult,
  type GetResult,
  type TenantMismatchFault,
  type RepositoryLogger,
  type RepositoryBaseConfig,
} from './repository-base';

// Concrete Repository
export {
  MobileShopRepository,
  type StatusQueryEntityType,
} from './mobile-shop.repository';

// Idempotency
export {
  createIdempotencyRecord,
  checkIdempotency,
  updateIdempotencyStatus,
  type IdempotencyStatus,
  type IdempotencyCheckResult,
  type IdempotencyErrorCode,
  type IdempotencyRecord,
} from './idempotency';

// Uniqueness Claims
export {
  createImeiClaim,
  createReservationClaim,
  releaseImeiClaim,
  releaseReservationClaim,
  type ClaimErrorCode,
  type ImeiClaimRecord,
  type ReservationClaimRecord,
} from './uniqueness-claims';

// Transaction Item Builders
export {
  buildClaimTransactItem,
  buildIdempotencyTransactItem,
  buildReleaseClaimTransactItem,
  type ClaimType,
  type TransactPutItem,
  type TransactDeleteItem,
} from './transaction-items';

// Audit & Change Event Persistence
export {
  buildAuditEventItem,
  buildChangeEventItem,
  buildAuditTransactItem,
  buildChangeTransactItem,
  type BuildAuditEventItemParams,
  type BuildChangeEventItemParams,
  type AuditEventItem,
  type ChangeEventItem,
} from './audit-events';

// Continuation Token Service
export {
  createContinuationToken,
  validateContinuationToken,
  computeQueryHash,
  getTokenSecret,
  type ContinuationTokenPayload,
  type TokenRejectionReason,
  type TokenValidationResult,
  type TokenValidationContext,
} from './continuation-token';
