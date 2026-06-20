// ============================================================
// Dukan Marketplace - Authentication & Authorization
// JWT validation with strict business/customer isolation
// ============================================================

import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify/cognito-verifier';
import { Errors } from './errors';
import { BusinessTokenClaims, CustomerTokenClaims, TokenClaims } from './types';

// Initialize the Cognito JWT Verifier
const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID || 'ap-south-1_mockpool',
  tokenUse: 'access',
  clientId: null, // Allow any client ID
});

// ---------- TOKEN EXTRACTION ----------

export function extractToken(event: APIGatewayProxyEventV2): string {
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  
  if (!authHeader) {
    throw Errors.unauthorized('Authorization header missing');
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') {
    throw Errors.unauthorized('Invalid authorization header format. Expected: Bearer <token>');
  }

  return parts[1];
}

// ---------- TOKEN VALIDATION (Cognito JWKS verified) ----------

export async function validateBusinessToken(event: APIGatewayProxyEventV2): Promise<BusinessTokenClaims> {
  const token = extractToken(event);
  
  try {
    let payload: any;
    if (process.env.NODE_ENV === 'test' || !process.env.COGNITO_USER_POOL_ID || process.env.COGNITO_USER_POOL_ID.startsWith('mock')) {
      // Decode only in testing/mock environments
      payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    } else {
      // Production: verify signature using JWKS
      payload = await verifier.verify(token);
    }
    
    // Validate required fields
    if (!payload.sub || !payload.businessId) {
      throw Errors.unauthorized('Invalid token: missing required claims');
    }

    // Check expiration
    if (payload.exp && payload.exp * 1000 < Date.now()) {
      throw Errors.tokenExpired();
    }

    return {
      sub: payload.sub,
      businessId: payload.businessId,
      email: payload.email || '',
      'cognito:groups': payload['cognito:groups'] || [],
      userType: 'business',
    };
  } catch (err) {
    if (err instanceof Error && err.name === 'AppError') throw err;
    throw Errors.unauthorized(err instanceof Error ? err.message : 'Invalid token format');
  }
}

export async function validateCustomerToken(event: APIGatewayProxyEventV2): Promise<CustomerTokenClaims> {
  const token = extractToken(event);
  
  try {
    let payload: any;
    if (process.env.NODE_ENV === 'test' || !process.env.COGNITO_USER_POOL_ID || process.env.COGNITO_USER_POOL_ID.startsWith('mock')) {
      // Decode only in testing/mock environments
      payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
    } else {
      // Production: verify signature using JWKS
      payload = await verifier.verify(token);
    }
    
    if (!payload.sub) {
      throw Errors.unauthorized('Invalid token: missing required claims');
    }

    if (payload.exp && payload.exp * 1000 < Date.now()) {
      throw Errors.tokenExpired();
    }

    return {
      sub: payload.sub,
      phone: payload.phone_number || payload.phone || '',
      email: payload.email,
      userType: 'customer',
    };
  } catch (err) {
    if (err instanceof Error && err.name === 'AppError') throw err;
    throw Errors.unauthorized(err instanceof Error ? err.message : 'Invalid token format');
  }
}

// ---------- BUSINESS AUTHORIZATION ----------

export async function authorizeBusiness(
  event: APIGatewayProxyEventV2,
  pathBusinessIdParam: string = 'businessId'
): Promise<BusinessTokenClaims> {
  const claims = await validateBusinessToken(event);
  const pathBusinessId = event.pathParameters?.[pathBusinessIdParam];

  // CRITICAL: Validate businessId from token matches path parameter
  if (pathBusinessId && claims.businessId !== pathBusinessId) {
    throw Errors.businessMismatch(claims.businessId, pathBusinessId);
  }

  return claims;
}

// ---------- CUSTOMER AUTHORIZATION ----------

export async function authorizeCustomer(event: APIGatewayProxyEventV2): Promise<CustomerTokenClaims> {
  return await validateCustomerToken(event);
}

// ---------- CROSS-AUTHORIZATION (Customer accessing Business resources) ----------

export interface CustomerBusinessAuth {
  customerClaims: CustomerTokenClaims;
  businessId: string;
}

export async function authorizeCustomerForBusiness(
  event: APIGatewayProxyEventV2,
  pathBusinessIdParam: string = 'businessId'
): Promise<CustomerBusinessAuth> {
  const customerClaims = await validateCustomerToken(event);
  const businessId = event.pathParameters?.[pathBusinessIdParam];

  if (!businessId) {
    throw Errors.validation('Business ID is required');
  }

  return { customerClaims, businessId };
}

// ---------- ROLE CHECKING ----------

export function requireRole(claims: BusinessTokenClaims, allowedRoles: string[]): void {
  const userRoles = claims['cognito:groups'] || [];
  const hasRole = allowedRoles.some(role => userRoles.includes(role));
  
  if (!hasRole) {
    throw Errors.forbidden(`Required role: ${allowedRoles.join(' or ')}`);
  }
}

// ---------- ALLOWED CATEGORIES CHECK ----------

export const ALLOWED_MARKETPLACE_CATEGORIES = [
  'grocery',
  'hardware',
  'pharmacy',
  'restaurant',
  'mobile_shop',
  'computer_shop',
];

export function validateBusinessCategory(category: string): void {
  if (!ALLOWED_MARKETPLACE_CATEGORIES.includes(category)) {
    throw Errors.forbidden(
      `Business category '${category}' is not eligible for marketplace. ` +
      `Allowed categories: ${ALLOWED_MARKETPLACE_CATEGORIES.join(', ')}`
    );
  }
}
