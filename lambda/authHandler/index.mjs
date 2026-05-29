// ============================================================================
// DEPRECATED (2026-05-17, F-01a) — DO NOT REDEPLOY
// ----------------------------------------------------------------------------
// This handler previously served POST /auth/refresh and POST /auth/logout
// via template.yaml's AuthHandler block. Both routes are now owned by
// my-backend (my-backend/src/handlers/auth.ts -> refresh, logout)
// per the backend ownership decision in docs/ARCHITECTURE.md §4.3.
//
// The my-backend versions are security-hardened (S-1 fix, audit + correlation
// id, hardened error handling). This file is retained only for git history.
//
// If you need to re-enable Lambda-side auth for any reason, first revisit
// docs/ARCHITECTURE.md §4.3 and update the ownership map BEFORE re-wiring.
//
// RUNTIME GUARD: both exported handlers will return HTTP 410 Gone if they
// are ever accidentally invoked, preventing silent auth-bypass.
// ============================================================================

const DEPRECATED_RESPONSE = {
  statusCode: 410,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    error: 'DEPRECATED_HANDLER',
    message:
      'This auth handler has been decommissioned. ' +
      'Auth routes are now served by my-backend. ' +
      'See docs/ARCHITECTURE.md §4.3.',
  }),
};

// eslint-disable-next-line no-unused-vars
import { CognitoIdentityProviderClient, InitiateAuthCommand, GlobalSignOutCommand, AdminGetUserCommand } from '@aws-sdk/client-cognito-identity-provider';
import { success, error, verifyToken, logAuditEvent } from '../shared/utils.mjs';

const cognitoClient = new CognitoIdentityProviderClient({});

// POST /auth/refresh
export async function refreshToken(_event) {
  return DEPRECATED_RESPONSE;
  // --- original code preserved below for git history only ---
  try { // eslint-disable-line no-unreachable
    const { refreshToken } = JSON.parse(event.body || '{}');

    if (!refreshToken) {
      return error('Refresh token is required', 400);
    }

    const command = new InitiateAuthCommand({
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        REFRESH_TOKEN: refreshToken,
      },
    });

    const response = await cognitoClient.send(command);

    const tokens = {
      accessToken: response.AuthenticationResult.AccessToken,
      idToken: response.AuthenticationResult.IdToken,
    };

    // Decode ID token to get tenant info for audit
    const decoded = await verifyToken(tokens.accessToken);

    await logAuditEvent(
      decoded.tenantId,
      decoded.sub,
      'TOKEN_REFRESH',
      'auth',
      undefined,
      undefined,
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({ tokens });
  } catch (err) {
    console.error('Refresh token error:', err);
    return error('Invalid refresh token', 401);
  }
}

// POST /auth/logout
export async function logout(_event) {
  return DEPRECATED_RESPONSE;
  // --- original code preserved below for git history only ---
  try { // eslint-disable-line no-unreachable
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    const command = new GlobalSignOutCommand({
      AccessToken: token,
    });

    await cognitoClient.send(command);

    await logAuditEvent(
      decoded.tenantId,
      decoded.sub,
      'LOGOUT',
      'auth',
      undefined,
      undefined,
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({ message: 'Logged out successfully' });
  } catch (err) {
    console.error('Logout error:', err);
    return error('Logout failed', 500);
  }
}

// Cognito Pre-token Generation Trigger
export async function preTokenTrigger(event) {
  try {
    const { userAttributes } = event.request;

    // Inject custom claims into ID token
    event.response = {
      claimsOverrideDetails: {
        claimsToAddOrOverride: {
          'custom:tenantId': userAttributes['custom:tenantId'] || '',
          'custom:role': userAttributes['custom:role'] || 'staff',
          'custom:business_type': userAttributes['custom:business_type'] || 'other',
          'custom:plan': userAttributes['custom:plan'] || 'basic',
        },
      },
    };

    return event;
  } catch (err) {
    console.error('Pre-token trigger error:', err);
    return event;
  }
}

export async function handler(event) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;

  switch (route) {
    case 'POST /auth/refresh':
      return refreshToken(event);
    case 'POST /auth/logout':
      return logout(event);
    default:
      return error(`Unsupported auth route: ${route}`, 404);
  }
}