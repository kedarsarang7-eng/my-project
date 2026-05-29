// ============================================================================
// p28(c) RBAC — Role-Based Access Control helpers for Staff Attendance handlers
// ============================================================================
//
// All staff-attendance Lambda functions are protected at the API Gateway level
// by the CognitoAuthorizer JWT.  The authorizer validates the token signature
// and expiry, then forwards the JWT claims as
//   event.requestContext.authorizer.claims
//
// Claim shape (Cognito User Pools):
//   sub              — Cognito user UUID (used as userId for audit)
//   custom:staffId   — petrol-pump staff ID (matches PetrolStaffProfiles PK)
//   custom:role      — one of: pump_operator | cashier | manager | supervisor | admin
//   cognito:groups   — space-separated group string (Cognito adds this)
//
// Role hierarchy (ascending privilege):
//   pump_operator < cashier < supervisor < manager < admin
// ============================================================================

import type { APIGatewayProxyEvent } from 'aws-lambda';
import { ErrorCodes, type ErrorCode } from '../constants/errorCodes';

// ── Role constants ────────────────────────────────────────────────────────────
export const ROLES = {
  PUMP_OPERATOR: 'pump_operator',
  CASHIER: 'cashier',
  SUPERVISOR: 'supervisor',
  MANAGER: 'manager',
  ADMIN: 'admin',
} as const;

export type StaffRoleValue = (typeof ROLES)[keyof typeof ROLES];

const ROLE_LEVEL: Record<string, number> = {
  pump_operator: 10,
  cashier: 20,
  supervisor: 30,
  manager: 40,
  admin: 50,
};

// ── Claim extraction ──────────────────────────────────────────────────────────
export interface StaffClaims {
  sub: string;
  staffId: string;
  role: StaffRoleValue;
}

/**
 * Extracts and validates JWT claims forwarded by the Cognito authorizer.
 *
 * Returns `null` if claims are missing or malformed — callers should return
 * a 401 in that case (token passed API GW but claims are corrupted/stale).
 */
export function extractClaims(event: APIGatewayProxyEvent): StaffClaims | null {
  const claims = event.requestContext.authorizer?.claims;
  if (!claims) return null;

  const sub: string = claims['sub'] ?? '';
  const staffId: string = claims['custom:staffId'] ?? claims['staffId'] ?? '';
  const rawRole: string = (
    claims['custom:role'] ??
    claims['role'] ??
    ROLES.PUMP_OPERATOR
  ).toLowerCase();

  if (!sub) return null;

  const role = (ROLE_LEVEL[rawRole] !== undefined ? rawRole : ROLES.PUMP_OPERATOR) as StaffRoleValue;

  return { sub, staffId, role };
}

// ── Role checks ───────────────────────────────────────────────────────────────

/** True when the caller's role is at or above the minimum required level. */
export function hasMinimumRole(claims: StaffClaims, minimumRole: StaffRoleValue): boolean {
  return (ROLE_LEVEL[claims.role] ?? 0) >= (ROLE_LEVEL[minimumRole] ?? 0);
}

/** True when the caller is acting on their own staffId, or is manager+. */
export function isSelfOrManager(claims: StaffClaims, targetStaffId: string): boolean {
  return claims.staffId === targetStaffId || hasMinimumRole(claims, ROLES.MANAGER);
}

// ── Structured error response helper ─────────────────────────────────────────
export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
};

/**
 * Builds a consistent error response body:
 *   { error: string, errorCode: ErrorCode, [extra fields] }
 *
 * Clients MUST branch on `errorCode` — the `error` string is for display only.
 */
export function errorResponse(
  statusCode: number,
  message: string,
  code: ErrorCode,
  extra?: Record<string, unknown>,
) {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify({ error: message, errorCode: code, ...extra }),
  };
}

export function unauthorizedResponse(message = 'Unauthorized') {
  return errorResponse(401, message, ErrorCodes.UNAUTHORIZED);
}

export function forbiddenResponse(message = 'Forbidden: insufficient role') {
  return errorResponse(403, message, ErrorCodes.FORBIDDEN_ROLE);
}
