/**
 * Continuation Token Service
 *
 * Serializes DynamoDB LastEvaluatedKey into an opaque, integrity-protected,
 * tenant-bound continuation token. Validates signature, expiry, tenant,
 * access pattern, query shape, and data model version before returning
 * the exclusive start key for pagination.
 *
 * The API never exposes raw LastEvaluatedKey to clients.
 *
 * Requirements: 6.15–6.17, 11.10, 12.6
 */

import { createHmac, timingSafeEqual } from 'crypto';
import { PAGINATION_CONFIG } from '../config/pagination.config';
import { MODEL_VERSION_CONFIG } from '../config/model-version.config';
import type { AccessPatternId } from './access-patterns';

// ─── Types ───────────────────────────────────────────────────────────────────

/** Internal payload serialized into the continuation token */
export interface ContinuationTokenPayload {
  /** Token schema version (for forward-compatible changes) */
  version: number;
  /** Bound to the authenticated tenant */
  tenantId: string;
  /** Access pattern this token was issued for (AP-01 through AP-15) */
  accessPatternId: string;
  /** Deterministic hash of the query parameters at issuance */
  queryHash: string;
  /** Table or GSI index name (undefined = base table) */
  indexName?: string;
  /** DynamoDB LastEvaluatedKey to resume from */
  exclusiveStartKey: Record<string, unknown>;
  /** Data model version at time of issue */
  dataModelVersion: number;
  /** Epoch seconds when the token was created */
  issuedAt: number;
  /** Epoch seconds when the token expires */
  expiresAt: number;
}

/** Reason a continuation token was rejected */
export type TokenRejectionReason =
  | 'SIGNATURE_INVALID'
  | 'MALFORMED'
  | 'EXPIRED'
  | 'TENANT_MISMATCH'
  | 'ACCESS_PATTERN_MISMATCH'
  | 'QUERY_HASH_MISMATCH'
  | 'MODEL_VERSION_UNSUPPORTED';

/** Result of token validation */
export type TokenValidationResult =
  | { valid: true; exclusiveStartKey: Record<string, unknown> }
  | { valid: false; reason: TokenRejectionReason };

/** Context required for token validation (from the current request) */
export interface TokenValidationContext {
  /** Authenticated tenant ID from the current request */
  tenantId: string;
  /** Current epoch seconds (injectable for testing) */
  nowEpochSeconds?: number;
}

// ─── Constants ───────────────────────────────────────────────────────────────

/** Current token schema version */
const TOKEN_VERSION = 1;

/** Separator between payload and signature in the token */
const TOKEN_SEPARATOR = '.';

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Compute a deterministic hash of query parameters.
 *
 * Sorts keys, serializes to a canonical JSON string, and produces
 * a truncated SHA-256 hex digest. This ensures the same logical query
 * always produces the same hash regardless of parameter order.
 */
export function computeQueryHash(params: Record<string, unknown>): string {
  const sorted = Object.keys(params)
    .sort()
    .reduce<Record<string, unknown>>((acc, key) => {
      acc[key] = params[key];
      return acc;
    }, {});

  const canonical = JSON.stringify(sorted);
  return createHmac('sha256', 'query-hash-salt')
    .update(canonical)
    .digest('hex')
    .slice(0, 16); // 16 hex chars = 64 bits — sufficient for collision avoidance
}

/**
 * Create an opaque continuation token from a DynamoDB LastEvaluatedKey.
 *
 * The token is HMAC-SHA256 signed with the server secret and base64url encoded.
 * It binds: tenant, access pattern, query parameters, index, model version, and expiry.
 */
export function createContinuationToken(
  params: {
    tenantId: string;
    accessPatternId: AccessPatternId;
    queryHash: string;
    indexName?: string;
    exclusiveStartKey: Record<string, unknown>;
    dataModelVersion: number;
  },
  secret: string,
): string {
  const now = Math.floor(Date.now() / 1000);

  const payload: ContinuationTokenPayload = {
    version: TOKEN_VERSION,
    tenantId: params.tenantId,
    accessPatternId: params.accessPatternId,
    queryHash: params.queryHash,
    indexName: params.indexName,
    exclusiveStartKey: params.exclusiveStartKey,
    dataModelVersion: params.dataModelVersion,
    issuedAt: now,
    expiresAt: now + PAGINATION_CONFIG.tokenExpirySeconds,
  };

  const payloadJson = JSON.stringify(payload);
  const payloadB64 = toBase64Url(payloadJson);
  const signature = sign(payloadB64, secret);

  return `${payloadB64}${TOKEN_SEPARATOR}${signature}`;
}

/**
 * Validate a continuation token and extract the exclusive start key.
 *
 * Checks (in order):
 * 1. Structure (payload.signature format)
 * 2. HMAC signature integrity
 * 3. JSON parse
 * 4. Expiry
 * 5. Tenant match
 * 6. Access pattern match
 * 7. Query hash match
 * 8. Data model version support
 *
 * Returns the exclusiveStartKey on success or a typed rejection reason on failure.
 */
export function validateContinuationToken(
  token: string,
  ctx: TokenValidationContext,
  accessPatternId: AccessPatternId,
  queryHash: string,
  secret: string,
): TokenValidationResult {
  // 1. Split token into payload and signature
  const separatorIndex = token.lastIndexOf(TOKEN_SEPARATOR);
  if (separatorIndex === -1 || separatorIndex === 0 || separatorIndex === token.length - 1) {
    return { valid: false, reason: 'SIGNATURE_INVALID' };
  }

  const payloadB64 = token.slice(0, separatorIndex);
  const providedSignature = token.slice(separatorIndex + 1);

  // 2. Verify HMAC signature (timing-safe)
  const expectedSignature = sign(payloadB64, secret);
  if (!timingSafeCompare(providedSignature, expectedSignature)) {
    return { valid: false, reason: 'SIGNATURE_INVALID' };
  }

  // 3. Decode and parse payload
  let payload: ContinuationTokenPayload;
  try {
    const payloadJson = fromBase64Url(payloadB64);
    payload = JSON.parse(payloadJson) as ContinuationTokenPayload;
  } catch {
    return { valid: false, reason: 'MALFORMED' };
  }

  // Basic structure validation
  if (
    !payload ||
    typeof payload.version !== 'number' ||
    typeof payload.tenantId !== 'string' ||
    typeof payload.accessPatternId !== 'string' ||
    typeof payload.queryHash !== 'string' ||
    typeof payload.expiresAt !== 'number' ||
    typeof payload.issuedAt !== 'number' ||
    typeof payload.dataModelVersion !== 'number' ||
    !payload.exclusiveStartKey ||
    typeof payload.exclusiveStartKey !== 'object'
  ) {
    return { valid: false, reason: 'MALFORMED' };
  }

  // 4. Check expiry
  const now = ctx.nowEpochSeconds ?? Math.floor(Date.now() / 1000);
  if (now >= payload.expiresAt) {
    return { valid: false, reason: 'EXPIRED' };
  }

  // 5. Verify tenant binding
  if (payload.tenantId !== ctx.tenantId) {
    return { valid: false, reason: 'TENANT_MISMATCH' };
  }

  // 6. Verify access pattern binding
  if (payload.accessPatternId !== accessPatternId) {
    return { valid: false, reason: 'ACCESS_PATTERN_MISMATCH' };
  }

  // 7. Verify query hash binding
  if (payload.queryHash !== queryHash) {
    return { valid: false, reason: 'QUERY_HASH_MISMATCH' };
  }

  // 8. Verify data model version is still supported
  if (
    payload.dataModelVersion < MODEL_VERSION_CONFIG.minSupportedVersion ||
    payload.dataModelVersion > MODEL_VERSION_CONFIG.maxSupportedVersion
  ) {
    return { valid: false, reason: 'MODEL_VERSION_UNSUPPORTED' };
  }

  return { valid: true, exclusiveStartKey: payload.exclusiveStartKey };
}

/**
 * Read the token secret from environment.
 * Falls back to a development-only default (never use in production).
 */
export function getTokenSecret(): string {
  const secret = process.env.MOBILE_SHOP_TOKEN_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'MOBILE_SHOP_TOKEN_SECRET environment variable is required in production',
      );
    }
    // Development fallback — not secure, never deploy with this
    return 'dev-only-insecure-token-secret-do-not-use-in-prod';
  }
  return secret;
}

// ─── Internal Helpers ────────────────────────────────────────────────────────

/** Produce HMAC-SHA256 signature as base64url */
function sign(data: string, secret: string): string {
  return createHmac('sha256', secret)
    .update(data)
    .digest('base64url');
}

/** Timing-safe string comparison to prevent timing attacks */
function timingSafeCompare(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  return timingSafeEqual(bufA, bufB);
}

/** Encode string to base64url (no padding) */
function toBase64Url(str: string): string {
  return Buffer.from(str, 'utf8').toString('base64url');
}

/** Decode base64url to string */
function fromBase64Url(b64: string): string {
  return Buffer.from(b64, 'base64url').toString('utf8');
}
