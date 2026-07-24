/**
 * MobileShop IAM — Barrel Export
 *
 * Workload identity policy definitions, application-level audit
 * immutability enforcement, and CloudFormation template validation.
 *
 * Requirements: 6.39–6.41, 8.10, 8.14
 */

// IAM Policy Definitions
export {
  APPLICATION_ROLE_ACTIONS,
  APPLICATION_ROLE_AUDIT_RESTRICTION,
  STREAM_CONSUMER_ACTIONS,
  MIGRATION_ROLE_ACTIONS,
  BACKUP_RESTORE_ACTIONS,
  FLUTTER_CLIENT_ACTIONS,
  WORKLOAD_IDENTITIES,
  type WorkloadIdentity,
} from './iam-policy-definitions';

// Audit Access Guard
export {
  assertNotAuditRecord,
  assertNotAuditOperation,
  isAuditKey,
  isAuditEntityType,
  AuditImmutabilityViolationError,
} from './audit-access-guard';

// IAM Validation (CI check)
export {
  validateIamPolicies,
  validateApplicationRoleActions,
  validateMigrationRoleActions,
  type PolicyStatement,
  type IamRoleResource,
  type CloudFormationTemplate,
  type ValidationFinding,
  type ValidationResult,
} from './iam-validation';
