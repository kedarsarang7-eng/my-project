// ============================================================================
// Lambda Handler — Authentication (Signup / Login / Refresh)
// ============================================================================
// Thin Lambda wrapper → delegates to AuthService (portable).
// Uses Zod validation for all inputs.
// NOTE: Auth handlers do NOT use authorizedHandler (they are PRE-auth).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { AuthService } from '../services/auth.service';
import { parseBody } from '../middleware/validation';
import { signupSchema, loginSchema, refreshTokenSchema, mfaVerifySchema, mfaSetupConfirmSchema, mfaSetupSchema, forgotPasswordSchema, confirmResetPasswordSchema, changePasswordSchema } from '../schemas';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import * as context from '../utils/context';

const authService = new AuthService();

// Security headers for all auth responses
const SECURITY_HEADERS = {
    'X-Content-Type-Options': 'nosniff',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Frame-Options': 'DENY',
    'Cache-Control': 'no-store',
};

function addHeaders(result: APIGatewayProxyResultV2, correlationId: string): APIGatewayProxyResultV2 {
    if (typeof result === 'object' && result !== null) {
        (result as any).headers = {
            ...(result as any).headers,
            ...SECURITY_HEADERS,
            'X-Correlation-Id': correlationId,
        };
    }
    return result;
}

/**
 * POST /auth/signup
 * Register a new business owner + create tenant record.
 */
export async function signup(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(signupSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { email, password, fullName, businessName, businessType, phone, licenseKey } = parsed.data;

            const result = await authService.signup({
                email,
                password,
                fullName,
                businessName,
                businessType,
                phone,
                licenseKey,
            });

            logger.info('New tenant registered', { email, businessType });

            return addHeaders(response.success(result, 201), correlationId);
        } catch (err: unknown) {
            logger.error('Signup failed', { error: (err as Error).message });

            if ((err as Error).message.includes('already exists')) {
                return addHeaders(
                    response.conflict('An account with this email already exists'),
                    correlationId
                );
            }

            return addHeaders(response.internalError(), correlationId);
        }
    });
}

/**
 * POST /auth/login
 * Authenticate user with Cognito, return tokens.
 */
export async function login(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(loginSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { email, password } = parsed.data;

            const tokens = await authService.login(email, password);

            if (tokens.challengeName) {
                logger.info('Login requires MFA challenge', { email, challengeName: tokens.challengeName });
                return addHeaders(response.success({
                    challengeName: tokens.challengeName,
                    session: tokens.session
                }, 202), correlationId);
            }

            logger.info('Login successful', { email });

            return addHeaders(response.success(tokens), correlationId);
        } catch (err: unknown) {
            logger.error('Login failed', { error: (err as Error).message });

            if ((err as Error).message.includes('Incorrect')) {
                return addHeaders(
                    response.unauthorized('Invalid email or password'),
                    correlationId
                );
            }
            if ((err as Error).message.includes('disabled') || (err as Error).message.includes('suspended')) {
                return addHeaders(
                    response.unauthorized('Your account has been suspended. Contact admin.'),
                    correlationId
                );
            }
            if ((err as Error).message.includes('No assigned role') || (err as Error).message.includes('not configured')) {
                return addHeaders(
                    response.unauthorized('Account not configured. Contact your administrator.'),
                    correlationId
                );
            }

            // AUDIT FIX #4: Never leak raw error messages to client
            return addHeaders(
                response.unauthorized('Login failed. Please try again.'),
                correlationId
            );
        }
    });
}

/**
 * GET /auth/me
 * Validate access token and return normalized auth payload.
 */
export async function me(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();
    return context.runWithContext({ correlationId }, async () => {
        try {
            const authHeader = event.headers?.authorization || event.headers?.Authorization || '';
            const accessToken = authHeader.replace(/^Bearer\s+/i, '').trim();
            if (!accessToken) {
                return addHeaders(response.unauthorized('Missing authorization token'), correlationId);
            }
            const payload = await authService.getMe(accessToken);
            return addHeaders(response.success(payload), correlationId);
        } catch (err: unknown) {
            return addHeaders(
                response.unauthorized('Your session has expired. Please sign in again.'),
                correlationId,
            );
        }
    });
}

/**
 * POST /auth/mfa/verify
 * Respond to the SOFTWARE_TOKEN_MFA challenge.
 */
export async function mfaVerify(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(mfaVerifySchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { username, session, totpCode } = parsed.data;

            const tokens = await authService.verifyMfa(username, session, totpCode);

            // If it returns another challenge, return that
            if (tokens.challengeName) {
                return addHeaders(response.success({
                    challengeName: tokens.challengeName,
                    session: tokens.session
                }, 202), correlationId);
            }

            logger.info('MFA Login successful', { username });

            return addHeaders(response.success(tokens), correlationId);
        } catch (err: unknown) {
            logger.error('MFA verify failed', { error: (err as Error).message });
            return addHeaders(response.unauthorized('Invalid MFA Code or Session Expired'), correlationId);
        }
    });
}

/**
 * POST /auth/mfa/setup
 * Initiates MFA setup for a user that got MFA_SETUP challenge.
 */
export async function mfaSetup(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            // AUDIT FIX #18: Use Zod schema for mfaSetup
            const parsed = parseBody(mfaSetupSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const setupResult = await authService.setupMfa(parsed.data.session);

            return addHeaders(response.success({
                secretCode: setupResult.secretCode,
                session: setupResult.session,
                message: "Please enter this key into your Authenticator App"
            }), correlationId);
        } catch (err: unknown) {
            logger.error('MFA setup initiation failed', { error: (err as Error).message });
            return addHeaders(response.unauthorized('Invalid challenge session'), correlationId);
        }
    });
}

/**
 * POST /auth/mfa/confirm-setup
 * Confirms the MFA setup code.
 */
export async function mfaSetupConfirm(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(mfaSetupConfirmSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { session, totpCode } = parsed.data;

            const tokens = await authService.verifyMfaSetup(session, totpCode);

            return addHeaders(response.success(tokens, 200), correlationId);
        } catch (err: unknown) {
            logger.error('MFA setup confirm failed', { error: (err as Error).message });
            return addHeaders(response.unauthorized('Invalid MFA code'), correlationId);
        }
    });
}

/**
 * POST /auth/refresh
 * Refresh an expired access token using the refresh token.
 */
export async function refresh(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(refreshTokenSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const tokens = await authService.refreshTokens(parsed.data.refreshToken);

            return addHeaders(response.success(tokens), correlationId);
        } catch (err: unknown) {
            logger.error('Token refresh failed', { error: (err as Error).message });
            return addHeaders(
                response.unauthorized('Failed to refresh token'),
                correlationId
            );
        }
    });
}

// =============================================================================
// SECURITY FIX S-1: Logout — Revoke all refresh tokens via globalSignOut
// =============================================================================

/**
 * POST /auth/logout
 * Invalidates all sessions. Requires a valid access token in Authorization header.
 */
export async function logout(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const authHeader = event.headers?.authorization || event.headers?.Authorization || '';
            const accessToken = authHeader.replace(/^Bearer\s+/i, '').trim();

            if (!accessToken) {
                return addHeaders(
                    response.error(400, 'MISSING_TOKEN', 'Access token required in Authorization header'),
                    correlationId,
                );
            }

            await authService.logout(accessToken);

            return addHeaders(response.success({ message: 'Logged out — all sessions revoked' }), correlationId);
        } catch (err: unknown) {
            logger.error('Logout failed', { error: (err as Error).message });
            // Even if globalSignOut fails, return success to client (don't block UI)
            return addHeaders(
                response.success({ message: 'Logout processed' }),
                correlationId,
            );
        }
    });
}

/**
 * POST /auth/change-password
 * Changes password and revokes all existing sessions.
 * Requires valid access token + current/new password.
 */
export async function changePassword(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const authHeader = event.headers?.authorization || event.headers?.Authorization || '';
            const accessToken = authHeader.replace(/^Bearer\s+/i, '').trim();

            if (!accessToken) {
                return addHeaders(
                    response.error(400, 'MISSING_TOKEN', 'Access token required in Authorization header'),
                    correlationId,
                );
            }

            // AUDIT FIX #17: Use Zod schema for changePassword with full policy validation
            const parsed = parseBody(changePasswordSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { previousPassword, proposedPassword } = parsed.data;

            await authService.changePassword(accessToken, previousPassword, proposedPassword);

            return addHeaders(
                response.success({ message: 'Password changed — all sessions revoked. Please login again.' }),
                correlationId,
            );
        } catch (err: unknown) {
            const msg = (err as Error).message;
            logger.error('Change password failed', { error: msg });

            if (msg.includes('Incorrect') || msg.includes('NotAuthorizedException')) {
                return addHeaders(response.unauthorized('Current password is incorrect'), correlationId);
            }
            if (msg.includes('InvalidPasswordException') || msg.includes('policy')) {
                return addHeaders(
                    response.badRequest('New password does not meet requirements (min 8 chars, uppercase, lowercase, number, symbol)'),
                    correlationId,
                );
            }

            return addHeaders(response.internalError(), correlationId);
        }
    });
}

// =============================================================================
// AUDIT FIX #2: Forgot Password — Initiate password reset via Cognito
// =============================================================================

/**
 * POST /auth/forgot-password
 * Sends a verification code to the user's email for password reset.
 */
export async function forgotPassword(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(forgotPasswordSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { email } = parsed.data;

            await authService.forgotPassword(email);

            // Always return success to prevent email enumeration
            return addHeaders(
                response.success({ message: 'If an account exists with this email, a password reset code has been sent.' }),
                correlationId,
            );
        } catch (err: unknown) {
            logger.error('Forgot password failed', { error: (err as Error).message });
            // Return success even on error to prevent email enumeration attacks
            return addHeaders(
                response.success({ message: 'If an account exists with this email, a password reset code has been sent.' }),
                correlationId,
            );
        }
    });
}

/**
 * POST /auth/confirm-reset-password
 * Confirms password reset with verification code + new password.
 */
export async function confirmResetPassword(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    const correlationId = event.requestContext?.requestId || randomUUID();

    return context.runWithContext({ correlationId }, async () => {
        try {
            const parsed = parseBody(confirmResetPasswordSchema, event);
            if (!parsed.success) return addHeaders(parsed.error, correlationId);

            const { email, confirmationCode, newPassword } = parsed.data;

            await authService.confirmResetPassword(email, confirmationCode, newPassword);

            return addHeaders(
                response.success({ message: 'Password has been reset successfully. Please login with your new password.' }),
                correlationId,
            );
        } catch (err: unknown) {
            const msg = (err as Error).message;
            logger.error('Confirm reset password failed', { error: msg });

            if (msg.includes('CodeMismatchException') || msg.includes('code')) {
                return addHeaders(response.badRequest('Invalid or expired verification code'), correlationId);
            }
            if (msg.includes('InvalidPasswordException') || msg.includes('policy')) {
                return addHeaders(
                    response.badRequest('New password does not meet requirements (min 8 chars, uppercase, lowercase, number, symbol)'),
                    correlationId,
                );
            }
            if (msg.includes('ExpiredCodeException') || msg.includes('expired')) {
                return addHeaders(response.badRequest('Verification code has expired. Please request a new one.'), correlationId);
            }

            return addHeaders(response.internalError(), correlationId);
        }
    });
}
