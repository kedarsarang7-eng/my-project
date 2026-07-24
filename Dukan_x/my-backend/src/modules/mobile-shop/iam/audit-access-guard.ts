/**
 * Audit Access Guard — Application-Level Immutability Enforcement
 *
 * Prevents application workload code from updating or deleting audit records.
 * This is the PRIMARY enforcement layer; IAM deny policies are defense-in-depth.
 *
 * Usage: repository methods call these assertions before executing any
 * UpdateItem or DeleteItem against items that might be audit records.
 * If the assertion throws, the mutation is blocked before reaching DynamoDB.
 *
 * Corrections to audit records are represented as NEW linked events
 * (with `correctsEventId` pointing to the original), never as mutations.
 *
 * Requirements: 8.14, 6.39–6.41
 */

// ─── Constants ──────────────────────────────────────────────────────────────

/** Entity types that are immutable audit records */
const AUDIT_ENTITY_TYPES = new Set([
  'AUDIT',
  'AUDIT_EVENT',
  'IMMUTABLE_AUDIT_EVENT',
]);

/** Sort key prefix that identifies audit items in the DynamoDB key structure */
const AUDIT_SK_PREFIX = 'AUDIT#';

/** PK bucket segment that identifies audit partitions */
const AUDIT_PK_SEGMENT = 'AUDIT#';

/** Operations that are prohibited on audit records */
type MutationOperation = 'UpdateItem' | 'DeleteItem' | 'Update' | 'Delete';

// ─── Error ──────────────────────────────────────────────────────────────────

/**
 * Thrown when application code attempts to update or delete an audit record.
 * This is a security fault — it should never happen in normal operation.
 */
export class AuditImmutabilityViolationError extends Error {
  public readonly code = 'AUDIT_IMMUTABILITY_VIOLATION' as const;

  constructor(
    public readonly operation: string,
    public readonly entityType?: string,
    public readonly itemKey?: string,
  ) {
    super(
      `Audit immutability violation: cannot ${operation} audit records. ` +
      `Corrections must be new linked events. ` +
      `[entityType=${entityType ?? 'unknown'}, key=${itemKey ?? 'unknown'}]`
    );
    this.name = 'AuditImmutabilityViolationError';
  }
}

// ─── Guard Functions ────────────────────────────────────────────────────────

/**
 * Asserts that an item is NOT an audit record before allowing mutation.
 *
 * Checks:
 * - entityType field against known audit entity types
 * - SK prefix against the AUDIT# pattern
 * - PK containing AUDIT# segment
 *
 * @param item - The DynamoDB item (or partial item with keys/entityType)
 * @throws AuditImmutabilityViolationError if the item is an audit record
 *
 * @example
 * ```typescript
 * // In a repository update method:
 * assertNotAuditRecord(existingItem);
 * // Safe to proceed with UpdateItem
 * ```
 */
export function assertNotAuditRecord(item: {
  entityType?: string;
  SK?: string;
  PK?: string;
}): void {
  // Check entity type
  if (item.entityType && AUDIT_ENTITY_TYPES.has(item.entityType)) {
    throw new AuditImmutabilityViolationError(
      'mutate',
      item.entityType,
      item.SK ?? item.PK,
    );
  }

  // Check sort key prefix
  if (item.SK && item.SK.startsWith(AUDIT_SK_PREFIX)) {
    throw new AuditImmutabilityViolationError(
      'mutate',
      item.entityType ?? 'unknown',
      item.SK,
    );
  }

  // Check partition key for audit bucket segment
  if (item.PK && item.PK.includes(AUDIT_PK_SEGMENT)) {
    throw new AuditImmutabilityViolationError(
      'mutate',
      item.entityType ?? 'unknown',
      item.PK,
    );
  }
}

/**
 * Asserts that a given operation is not targeting audit items.
 *
 * Use this when you know the operation type and entity type but may not
 * have the full item loaded. This is a fast-path check before constructing
 * the DynamoDB request.
 *
 * @param operation - The DynamoDB operation being attempted
 * @param entityType - The entity type being targeted
 * @throws AuditImmutabilityViolationError if attempting Update/Delete on audit
 *
 * @example
 * ```typescript
 * // Before building an UpdateItem request:
 * assertNotAuditOperation('UpdateItem', record.entityType);
 * ```
 */
export function assertNotAuditOperation(
  operation: MutationOperation,
  entityType: string,
): void {
  const isMutating = operation === 'UpdateItem'
    || operation === 'DeleteItem'
    || operation === 'Update'
    || operation === 'Delete';

  if (isMutating && AUDIT_ENTITY_TYPES.has(entityType)) {
    throw new AuditImmutabilityViolationError(operation, entityType);
  }
}

/**
 * Checks whether an item key targets an audit record.
 * Returns true if the key pattern indicates an audit item.
 *
 * Use this for conditional logic where throwing is not appropriate.
 *
 * @param pk - The partition key
 * @param sk - The sort key (optional)
 * @returns true if the key identifies an audit record
 */
export function isAuditKey(pk: string, sk?: string): boolean {
  if (pk.includes(AUDIT_PK_SEGMENT)) return true;
  if (sk && sk.startsWith(AUDIT_SK_PREFIX)) return true;
  return false;
}

/**
 * Checks whether an entity type is an immutable audit type.
 *
 * @param entityType - The entity type string to check
 * @returns true if the entity type is an audit record type
 */
export function isAuditEntityType(entityType: string): boolean {
  return AUDIT_ENTITY_TYPES.has(entityType);
}
