// ============================================================================
// AUTHENTICATION & AUTHORIZATION UTILITIES
// ============================================================================

import { APIGatewayProxyEvent } from 'aws-lambda';

export type StaffRole = 'owner' | 'admin' | 'manager' | 'supervisor' | 'cashier' | 'pump_operator';

export interface CognitoClaims {
  sub: string;
  email?: string;
  phone_number?: string;
  name?: string;
  'custom:role'?: string;
  'custom:staff_id'?: string;
  'custom:petrol_pump_id'?: string;
  'custom:pump_station_id'?: string;
  'custom:tenant_id'?: string;
  'custom:business_type'?: string;
  'cognito:groups'?: string[];
  [key: string]: any;
}

export interface AuthContext {
  userId: string;
  email?: string;
  role: StaffRole;
  staffId?: string;
  petrolPumpId?: string;
  pumpStationId?: string;
  tenantId?: string;
  businessType?: string;
  groups: string[];
  isOwner: boolean;
  isAdmin: boolean;
  isManager: boolean;
}

/**
 * Extract Cognito claims from API Gateway event
 */
export function extractCognitoClaims(event: APIGatewayProxyEvent): CognitoClaims | null {
  const claims = event.requestContext?.authorizer?.claims;
  if (!claims || typeof claims !== 'object') {
    return null;
  }
  return claims as CognitoClaims;
}

/**
 * Extract and build auth context from API Gateway event
 */
export function extractAuthContext(event: APIGatewayProxyEvent): AuthContext | null {
  const claims = extractCognitoClaims(event);
  if (!claims) {
    return null;
  }

  const role = (claims['custom:role'] || '').toLowerCase() as StaffRole;
  const groups = claims['cognito:groups'] || [];

  return {
    userId: claims.sub,
    email: claims.email,
    role,
    staffId: claims['custom:staff_id'],
    petrolPumpId: claims['custom:petrol_pump_id'] || claims['custom:pump_station_id'] || claims['custom:tenant_id'],
    pumpStationId: claims['custom:pump_station_id'],
    tenantId: claims['custom:tenant_id'],
    businessType: claims['custom:business_type'],
    groups,
    isOwner: role === 'owner' || groups.includes('Owner'),
    isAdmin: role === 'admin' || role === 'owner' || groups.includes('Admin'),
    isManager: role === 'manager' || role === 'admin' || role === 'owner'
  };
}

/**
 * Extract user role from claims
 */
export function extractUserRole(event: APIGatewayProxyEvent): StaffRole | null {
  const claims = extractCognitoClaims(event);
  if (!claims) return null;
  return (claims['custom:role'] || '').toLowerCase() as StaffRole;
}

/**
 * Extract petrol pump ID from claims
 */
export function extractPetrolPumpId(event: APIGatewayProxyEvent): string | null {
  const claims = extractCognitoClaims(event);
  if (!claims) return null;
  return claims['custom:petrol_pump_id'] || 
         claims['custom:pump_station_id'] || 
         claims['custom:tenant_id'] || 
         null;
}

/**
 * Assert that user has one of the allowed roles
 * Throws error with 403 status if not authorized
 */
export function assertRole(
  event: APIGatewayProxyEvent, 
  allowedRoles: StaffRole[]
): AuthContext {
  const authContext = extractAuthContext(event);
  
  if (!authContext) {
    throw new AuthError('Unauthorized: Missing authentication', 401);
  }

  if (!allowedRoles.includes(authContext.role) && !authContext.isAdmin) {
    throw new AuthError(
      `Forbidden: Required role: ${allowedRoles.join(' or ')}`, 
      403
    );
  }

  return authContext;
}

/**
 * Assert that user is owner or admin
 */
export function assertOwnerOrAdmin(event: APIGatewayProxyEvent): AuthContext {
  const authContext = extractAuthContext(event);
  
  if (!authContext) {
    throw new AuthError('Unauthorized: Missing authentication', 401);
  }

  if (!authContext.isOwner && !authContext.isAdmin) {
    throw new AuthError('Forbidden: Owner or Admin role required', 403);
  }

  return authContext;
}

/**
 * Assert that user can access specific petrol pump
 */
export function assertPumpAccess(
  event: APIGatewayProxyEvent, 
  targetPumpId: string
): AuthContext {
  const authContext = extractAuthContext(event);
  
  if (!authContext) {
    throw new AuthError('Unauthorized: Missing authentication', 401);
  }

  // Owners/admins can access any pump
  if (authContext.isOwner || authContext.isAdmin) {
    return authContext;
  }

  // Others can only access their assigned pump
  if (authContext.petrolPumpId !== targetPumpId) {
    throw new AuthError('Forbidden: Cannot access staff from different station', 403);
  }

  return authContext;
}

export class AuthError extends Error {
  public statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = 'AuthError';
    this.statusCode = statusCode;
  }
}
