/**
 * MobileShop TenantContext — Interface and Factory
 *
 * Resolves tenant identity, business type, subject, permissions, and
 * correlation ID from verified JWT claims and membership lookup.
 *
 * Critical rules:
 * - Resolved from server-verified claims ONLY
 * - Client-supplied ownership fields are IGNORED
 * - Business type is normalized to canonical `mobile_shop`
 * - Fail closed: incomplete context = access denied
 *
 * Requirements: 6.4–6.6, 6.19, 8.3–8.10, 12.3
 */

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { AuthContext, UserRole } from '../../../types/tenant.types';
import {
  normalizeMobileShopBusinessType,
  CANONICAL_BUSINESS_TYPE,
} from '../schemas/common.schema';
import {
  migratePermissions,
  type LegacyRole,
} from '../permissions/compatibility-matrix';
import { expandPermissions } from '../permissions/mobile-shop-permissions';
import { extractCorrelationId } from './correlation';

// ─── TenantContext Interface ─────────────────────────────────────────────────

/**
 * Immutable tenant context resolved from verified authentication.
 * Attached to the request and propagated to all domain handlers.
 * Never constructed from client-supplied fields.
 */
export interface TenantContext {
  /** Authenticated tenant ID from verified JWT claims */
  readonly tenantId: string;
  /** Business (tenant) ID — same as tenantId for current architecture */
  readonly businessId: string;
  /** Authenticated subject (user) ID from JWT sub claim */
  readonly subjectId: string;
  /** Canonical business type, always `mobile_shop` */
  readonly businessType: typeof CANONICAL_BUSINESS_TYPE;
  /** Expanded effective permissions (manage implies view) */
  readonly permissions: ReadonlySet<string>;
  /** Correlation ID for request tracing */
  readonly correlationId: string;
}

// ─── Context Resolution Error ────────────────────────────────────────────────

/**
 * Error thrown when TenantContext cannot be resolved.
 * Results in a non-disclosing 403 before any domain/datastore access.
 */
export class TenantContextError extends Error {
  constructor(
    message: string,
    public readonly code: string,
  ) {
    super(message);
    this.name = 'TenantContextError';
  }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

/**
 * Resolves TenantContext from a verified AuthContext and the request event.
 *
 * Steps:
 * 1. Validate that all required claims are present
 * 2. Normalize business_type to canonical `mobile_shop`
 * 3. Reject if business type is not mobile_shop (non-disclosing)
 * 4. Resolve permissions via compatibility matrix migration
 * 5. Expand permissions (manage implies view)
 * 6. Extract or generate correlation ID
 *
 * @param auth - Verified AuthContext from cognito-auth middleware
 * @param event - Raw API Gateway event (for correlation header)
 * @returns Resolved TenantContext
 * @throws TenantContextError if resolution fails
 */
export function resolveTenantContext(
  auth: AuthContext,
  event: APIGatewayProxyEventV2,
): TenantContext {
  // Fail closed: tenant ID is required
  if (!auth.tenantId) {
    throw new TenantContextError(
      'Missing tenant identity',
      'TENANT_CONTEXT_MISSING_TENANT',
    );
  }

  // Fail closed: subject ID is required
  if (!auth.sub) {
    throw new TenantContextError(
      'Missing subject identity',
      'TENANT_CONTEXT_MISSING_SUBJECT',
    );
  }

  // Normalize business type — reject if not a mobile shop alias
  const rawBusinessType = auth.businessType as string;
  const normalizedType = normalizeMobileShopBusinessType(rawBusinessType || '');

  if (!normalizedType) {
    throw new TenantContextError(
      'Business type not authorized for mobile shop operations',
      'TENANT_CONTEXT_INVALID_BUSINESS_TYPE',
    );
  }

  // Resolve permissions through compatibility matrix migration
  // Uses the legacy role to determine the base permissions, then expands
  const migrationResult = migratePermissions({
    currentPermissions: [],
    role: auth.role as LegacyRole,
    capabilities: [], // Capabilities are resolved from tenant membership if available
  });

  // Expand permissions (manage implies view)
  const effectivePermissions = expandPermissions(new Set(migrationResult.permissions));

  // Extract or generate correlation ID
  const correlationId = extractCorrelationId(event);

  return {
    tenantId: auth.tenantId,
    businessId: auth.tenantId, // Same for current architecture
    subjectId: auth.sub,
    businessType: CANONICAL_BUSINESS_TYPE,
    permissions: effectivePermissions,
    correlationId,
  };
}
