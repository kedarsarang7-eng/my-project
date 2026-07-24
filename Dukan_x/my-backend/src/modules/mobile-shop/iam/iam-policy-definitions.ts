/**
 * IAM Policy Definitions — Workload Identity Permissions
 *
 * Typed constants documenting which DynamoDB actions each workload identity
 * is permitted. These constants serve as the source of truth for:
 * - serverless.yml IAM role statements
 * - CI validation of CloudFormation templates
 * - Application-level audit access enforcement
 *
 * Principle: each identity gets ONLY the actions it needs.
 * Flutter clients receive NO DynamoDB credentials whatsoever.
 *
 * Requirements: 6.39–6.41, 8.10, 8.14
 */

// ─── DynamoDB Action Constants ──────────────────────────────────────────────

/**
 * DynamoDB actions permitted for the main Lambda application role.
 *
 * This role handles all standard CRUD via API Gateway handlers.
 * Notably: NO Scan — all queries use bounded access patterns (AP-01–AP-15).
 */
export const APPLICATION_ROLE_ACTIONS = [
  'dynamodb:PutItem',
  'dynamodb:GetItem',
  'dynamodb:Query',
  'dynamodb:UpdateItem',
  'dynamodb:DeleteItem',
  'dynamodb:BatchWriteItem',
  'dynamodb:TransactWriteItems',
  'dynamodb:TransactGetItems',
] as const;

/**
 * Audit record restriction for the application role.
 *
 * The application role CANNOT update or delete items that are audit records
 * (entity type AUDIT or SK beginning with audit-related prefixes).
 *
 * Enforcement is layered:
 * 1. PRIMARY: Application-level guard in audit-access-guard.ts prevents
 *    Update/Delete operations from reaching DynamoDB for audit items.
 * 2. DEFENSE-IN-DEPTH: IAM condition (where feasible) or absence of
 *    mutation methods for audit entity types in the repository layer.
 *
 * Corrections to audit records are represented as NEW linked events
 * (with `correctsEventId`), never as updates to existing records.
 */
export const APPLICATION_ROLE_AUDIT_RESTRICTION = {
  description: 'Application role cannot update/delete audit records',
  restrictedEntityTypes: ['AUDIT'] as const,
  restrictedPKPrefix: 'AUDIT#',
  allowedAuditActions: ['dynamodb:PutItem', 'dynamodb:GetItem', 'dynamodb:Query'] as const,
  deniedAuditActions: ['dynamodb:UpdateItem', 'dynamodb:DeleteItem'] as const,
  enforcementLayers: [
    'application-code: audit-access-guard.ts assertNotAuditRecord / assertNotAuditOperation',
    'repository-design: no updateAudit / deleteAudit methods exposed',
    'iam-defense-in-depth: Deny policy with condition on leading key prefix (where feasible)',
  ] as const,
} as const;

/**
 * DynamoDB Streams actions for the stream consumer role.
 *
 * Stream consumers (EventBridge Pipes, reconciliation workers, WebSocket
 * fan-out) read change events. They never write to the main table directly —
 * any resulting writes use a separate invocation with appropriate role.
 */
export const STREAM_CONSUMER_ACTIONS = [
  'dynamodb:GetRecords',
  'dynamodb:GetShardIterator',
  'dynamodb:DescribeStream',
  'dynamodb:ListStreams',
] as const;

/**
 * DynamoDB actions for the migration/backfill role.
 *
 * This role has broader read access (including Scan for full-table migration)
 * and write access for version upgrades. It is a SEPARATE IAM role from the
 * application role and is used only during controlled migration operations.
 */
export const MIGRATION_ROLE_ACTIONS = [
  'dynamodb:PutItem',
  'dynamodb:GetItem',
  'dynamodb:Query',
  'dynamodb:Scan',
  'dynamodb:UpdateItem',
  'dynamodb:BatchGetItem',
  'dynamodb:BatchWriteItem',
  'dynamodb:TransactWriteItems',
  'dynamodb:DescribeTable',
] as const;

/**
 * DynamoDB actions for the backup/restore identity.
 *
 * Backup and restore operations use a dedicated identity with access to
 * table management, export, and restore operations. This identity is NOT
 * the application role and is granted only during approved operations.
 */
export const BACKUP_RESTORE_ACTIONS = [
  'dynamodb:CreateBackup',
  'dynamodb:DescribeBackup',
  'dynamodb:ListBackups',
  'dynamodb:RestoreTableFromBackup',
  'dynamodb:RestoreTableToPointInTime',
  'dynamodb:DescribeTable',
  'dynamodb:DescribeContinuousBackups',
  'dynamodb:ExportTableToPointInTime',
  'dynamodb:DescribeExport',
  'dynamodb:ListExports',
] as const;

/**
 * Flutter client DynamoDB actions: NONE.
 *
 * Flutter clients interact with MobileShop domain data ONLY through
 * authenticated Canonical_Backend APIs (API Gateway + Lambda).
 * No DynamoDB credentials, connection strings, table names, or SDK
 * configurations are distributed to the client application.
 *
 * Requirement 6.41: "authorize authoritative MobileShop_Domain access
 * through Canonical_Backend APIs without distributing Canonical_Datastore
 * credentials to Flutter clients"
 */
export const FLUTTER_CLIENT_ACTIONS: readonly string[] = [];

// ─── Role Metadata ──────────────────────────────────────────────────────────

/** Describes a workload identity and its permitted scope */
export interface WorkloadIdentity {
  readonly name: string;
  readonly description: string;
  readonly actions: readonly string[];
  readonly resourceScope: string;
  readonly separateRole: boolean;
}

/** Complete catalog of workload identities for the MobileShop module */
export const WORKLOAD_IDENTITIES: readonly WorkloadIdentity[] = [
  {
    name: 'MobileShopApplicationRole',
    description: 'Main Lambda handlers — CRUD via bounded access patterns, no Scan, no audit mutation',
    actions: APPLICATION_ROLE_ACTIONS,
    resourceScope: 'MobileShop table + indexes (stage-scoped ARN)',
    separateRole: false,
  },
  {
    name: 'MobileShopStreamConsumerRole',
    description: 'DynamoDB Streams readers — EventBridge Pipes, reconciliation triggers',
    actions: STREAM_CONSUMER_ACTIONS,
    resourceScope: 'MobileShop table stream ARN',
    separateRole: true,
  },
  {
    name: 'MobileShopMigrationRole',
    description: 'Migration/backfill workers — broader read (Scan) + conditional writes',
    actions: MIGRATION_ROLE_ACTIONS,
    resourceScope: 'MobileShop table + indexes (stage-scoped ARN)',
    separateRole: true,
  },
  {
    name: 'MobileShopBackupRestoreRole',
    description: 'Backup, export, and restore operations — dedicated operational identity',
    actions: BACKUP_RESTORE_ACTIONS,
    resourceScope: 'MobileShop table ARN + backup/export resources',
    separateRole: true,
  },
  {
    name: 'FlutterClient',
    description: 'Flutter mobile app — NO DynamoDB credentials, API-only access',
    actions: FLUTTER_CLIENT_ACTIONS,
    resourceScope: 'NONE — uses API Gateway endpoints only',
    separateRole: false,
  },
] as const;
