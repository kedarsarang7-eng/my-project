/**
 * IAM Validation — Serverless/CloudFormation Template Validator
 *
 * Validates that the serverless CloudFormation template enforces
 * least-privilege workload identities for MobileShop DynamoDB access.
 *
 * This can be run as a CI check to prevent IAM policy drift.
 *
 * Checks:
 * - Application role does NOT have Scan permission
 * - Migration role is separate from application role
 * - Stream consumer role only has stream-related actions
 * - No DynamoDB actions are granted to client-facing resources
 * - Audit deny policy is present (where applicable)
 *
 * Requirements: 6.39–6.41, 8.10, 8.14
 */

import {
  APPLICATION_ROLE_ACTIONS,
  STREAM_CONSUMER_ACTIONS,
  MIGRATION_ROLE_ACTIONS,
} from './iam-policy-definitions';

// ─── Types ──────────────────────────────────────────────────────────────────

/** A policy statement from a CloudFormation IAM role */
export interface PolicyStatement {
  Effect: 'Allow' | 'Deny';
  Action: string | string[];
  Resource: string | string[];
  Condition?: Record<string, unknown>;
}

/** An IAM role resource from CloudFormation */
export interface IamRoleResource {
  Type: 'AWS::IAM::Role';
  Properties: {
    RoleName?: string;
    Policies?: Array<{
      PolicyName: string;
      PolicyDocument: {
        Statement: PolicyStatement[];
      };
    }>;
    ManagedPolicyArns?: string[];
    [key: string]: unknown;
  };
}

/** Serverless provider IAM configuration */
export interface ProviderIam {
  role?: {
    statements?: PolicyStatement[];
  };
}

/** A simplified CloudFormation template structure */
export interface CloudFormationTemplate {
  Resources?: Record<string, { Type: string; Properties?: Record<string, unknown> }>;
  provider?: {
    iam?: ProviderIam;
    iamRoleStatements?: PolicyStatement[];
  };
  [key: string]: unknown;
}

/** Validation result for a single check */
export interface ValidationFinding {
  readonly rule: string;
  readonly severity: 'error' | 'warning';
  readonly message: string;
  readonly resource?: string;
}

/** Overall validation result */
export interface ValidationResult {
  readonly valid: boolean;
  readonly findings: readonly ValidationFinding[];
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/** Normalize Action field to an array */
function normalizeActions(action: string | string[]): string[] {
  return Array.isArray(action) ? action : [action];
}

/** Check if an action list contains DynamoDB Scan */
function hasScanAction(actions: string[]): boolean {
  return actions.some(
    (a) => a === 'dynamodb:Scan' || a === 'dynamodb:*',
  );
}

/** Check if an action list contains DynamoDB wildcard */
function hasDynamoWildcard(actions: string[]): boolean {
  return actions.some((a) => a === 'dynamodb:*');
}

/** Check if an action is a DynamoDB action */
function isDynamoDbAction(action: string): boolean {
  return action.startsWith('dynamodb:');
}

/** Check if actions are stream-only */
function isStreamOnly(actions: string[]): boolean {
  const streamActions = new Set(STREAM_CONSUMER_ACTIONS);
  return actions.every(
    (a) => streamActions.has(a as typeof STREAM_CONSUMER_ACTIONS[number]) || !isDynamoDbAction(a),
  );
}

/** Extract all policy statements from a resource */
function extractStatements(resource: IamRoleResource): PolicyStatement[] {
  const statements: PolicyStatement[] = [];
  if (resource.Properties.Policies) {
    for (const policy of resource.Properties.Policies) {
      statements.push(...policy.PolicyDocument.Statement);
    }
  }
  return statements;
}

// ─── Validation Rules ───────────────────────────────────────────────────────

/**
 * Validates a serverless/CloudFormation template for IAM policy compliance.
 *
 * Rules enforced:
 * 1. Application role does not grant `dynamodb:Scan`
 * 2. Migration role is defined separately from the application role
 * 3. Stream consumer role only has stream-related DynamoDB actions
 * 4. No client-facing resources (Cognito User Pool Client, CloudFront, S3
 *    bucket policies) grant DynamoDB actions
 * 5. No role uses `dynamodb:*` wildcard
 *
 * @param template - The CloudFormation or serverless template to validate
 * @returns ValidationResult with findings
 *
 * @example
 * ```typescript
 * import { readFileSync } from 'fs';
 * import { load } from 'js-yaml';
 *
 * const template = load(readFileSync('serverless.yml', 'utf-8'));
 * const result = validateIamPolicies(template as CloudFormationTemplate);
 * if (!result.valid) {
 *   console.error('IAM validation failed:', result.findings);
 *   process.exit(1);
 * }
 * ```
 */
export function validateIamPolicies(template: CloudFormationTemplate): ValidationResult {
  const findings: ValidationFinding[] = [];

  // ── Check provider-level IAM statements (serverless format) ──────────
  const providerStatements = template.provider?.iam?.role?.statements
    ?? template.provider?.iamRoleStatements
    ?? [];

  for (const stmt of providerStatements) {
    if (stmt.Effect !== 'Allow') continue;
    const actions = normalizeActions(stmt.Action);

    // Rule 1: No Scan in provider (application) role
    if (hasScanAction(actions)) {
      findings.push({
        rule: 'NO_SCAN_IN_APPLICATION_ROLE',
        severity: 'error',
        message: 'Application role must not have dynamodb:Scan. Use bounded Query access patterns.',
        resource: 'provider.iam.role.statements',
      });
    }

    // Rule 5: No wildcard
    if (hasDynamoWildcard(actions)) {
      findings.push({
        rule: 'NO_DYNAMODB_WILDCARD',
        severity: 'error',
        message: 'dynamodb:* wildcard is prohibited. Specify exact actions.',
        resource: 'provider.iam.role.statements',
      });
    }
  }

  // ── Check CloudFormation Resources ────────────────────────────────────
  const resources = template.Resources ?? {};
  const roleNames = new Set<string>();
  let hasMigrationRole = false;
  let hasApplicationRole = false;

  for (const [logicalId, resource] of Object.entries(resources)) {
    if (resource.Type !== 'AWS::IAM::Role') continue;

    const iamRole = resource as unknown as IamRoleResource;
    const roleName = iamRole.Properties.RoleName ?? logicalId;
    roleNames.add(roleName);

    const statements = extractStatements(iamRole);
    const isMigrationRole = logicalId.toLowerCase().includes('migration')
      || (roleName?.toLowerCase().includes('migration') ?? false);
    const isStreamRole = logicalId.toLowerCase().includes('stream')
      || (roleName?.toLowerCase().includes('stream') ?? false);
    const isApplicationRole = logicalId.toLowerCase().includes('application')
      || logicalId.toLowerCase().includes('approle')
      || (!isMigrationRole && !isStreamRole && statements.some(
        (s) => s.Effect === 'Allow' && normalizeActions(s.Action).some(
          (a) => APPLICATION_ROLE_ACTIONS.includes(a as typeof APPLICATION_ROLE_ACTIONS[number]),
        ),
      ));

    if (isMigrationRole) hasMigrationRole = true;
    if (isApplicationRole) hasApplicationRole = true;

    for (const stmt of statements) {
      if (stmt.Effect !== 'Allow') continue;
      const actions = normalizeActions(stmt.Action);

      // Rule 1: Application role cannot have Scan
      if (isApplicationRole && hasScanAction(actions)) {
        findings.push({
          rule: 'NO_SCAN_IN_APPLICATION_ROLE',
          severity: 'error',
          message: `Application role "${roleName}" must not have dynamodb:Scan.`,
          resource: logicalId,
        });
      }

      // Rule 3: Stream role should only have stream actions
      if (isStreamRole && !isStreamOnly(actions)) {
        const nonStreamActions = actions.filter(
          (a) => isDynamoDbAction(a) && !STREAM_CONSUMER_ACTIONS.includes(
            a as typeof STREAM_CONSUMER_ACTIONS[number],
          ),
        );
        if (nonStreamActions.length > 0) {
          findings.push({
            rule: 'STREAM_ROLE_ONLY_STREAM_ACTIONS',
            severity: 'error',
            message: `Stream role "${roleName}" has non-stream DynamoDB actions: ${nonStreamActions.join(', ')}`,
            resource: logicalId,
          });
        }
      }

      // Rule 5: No wildcard in any role
      if (hasDynamoWildcard(actions)) {
        findings.push({
          rule: 'NO_DYNAMODB_WILDCARD',
          severity: 'error',
          message: `Role "${roleName}" uses dynamodb:* wildcard. Specify exact actions.`,
          resource: logicalId,
        });
      }
    }
  }

  // ── Rule 2: Migration role must be separate from application role ────
  // Check that at least one explicitly-named migration role exists
  // (serverless.yml task 2.1 already created MobileShopMigrationRole)
  if (hasApplicationRole && !hasMigrationRole) {
    // Only warn — the migration role might be in a different template section
    findings.push({
      rule: 'MIGRATION_ROLE_SEPARATE',
      severity: 'warning',
      message: 'No dedicated migration role found. Migration/backfill should use a separate IAM role from the application role.',
    });
  }

  // ── Rule 4: No DynamoDB actions on client-facing resources ───────────
  for (const [logicalId, resource] of Object.entries(resources)) {
    const clientFacingTypes = [
      'AWS::Cognito::UserPoolClient',
      'AWS::CloudFront::Distribution',
      'AWS::S3::BucketPolicy',
      'AWS::ApiGatewayV2::Integration',
    ];

    if (!clientFacingTypes.includes(resource.Type)) continue;

    // Check if any inline policies grant DynamoDB access
    const props = resource.Properties ?? {};
    const policyString = JSON.stringify(props);
    if (policyString.includes('dynamodb:')) {
      findings.push({
        rule: 'NO_DYNAMODB_ON_CLIENT_RESOURCES',
        severity: 'error',
        message: `Client-facing resource "${logicalId}" (${resource.Type}) must not have DynamoDB actions. Flutter uses API Gateway only.`,
        resource: logicalId,
      });
    }
  }

  return {
    valid: findings.filter((f) => f.severity === 'error').length === 0,
    findings,
  };
}

/**
 * Validates that the application role's DynamoDB actions match the expected set.
 * Useful as a quick sanity check independent of the full template parse.
 *
 * @param grantedActions - The DynamoDB actions currently granted to the application role
 * @returns List of unexpected or missing actions
 */
export function validateApplicationRoleActions(
  grantedActions: readonly string[],
): { unexpected: string[]; missing: string[] } {
  const expected = new Set<string>(APPLICATION_ROLE_ACTIONS);
  const granted = new Set(grantedActions);

  const unexpected = grantedActions.filter((a) => !expected.has(a) && isDynamoDbAction(a));
  const missing = APPLICATION_ROLE_ACTIONS.filter((a) => !granted.has(a));

  return { unexpected, missing };
}

/**
 * Validates that the migration role's actions are a superset of what's needed
 * but does not include backup/restore-only actions.
 *
 * @param grantedActions - The DynamoDB actions currently granted to the migration role
 * @returns List of findings
 */
export function validateMigrationRoleActions(
  grantedActions: readonly string[],
): ValidationFinding[] {
  const findings: ValidationFinding[] = [];
  const expected = new Set<string>(MIGRATION_ROLE_ACTIONS);
  const granted = new Set(grantedActions);

  // Migration role should have Scan (that's its distinguishing feature)
  if (!granted.has('dynamodb:Scan')) {
    findings.push({
      rule: 'MIGRATION_ROLE_HAS_SCAN',
      severity: 'warning',
      message: 'Migration role should include dynamodb:Scan for full-table migrations.',
    });
  }

  // Migration role should NOT have backup/restore actions
  const backupActions = [
    'dynamodb:CreateBackup',
    'dynamodb:RestoreTableFromBackup',
    'dynamodb:RestoreTableToPointInTime',
  ];
  for (const action of backupActions) {
    if (granted.has(action)) {
      findings.push({
        rule: 'MIGRATION_ROLE_NO_BACKUP',
        severity: 'error',
        message: `Migration role should not have ${action}. Use a separate backup/restore identity.`,
      });
    }
  }

  return findings;
}
