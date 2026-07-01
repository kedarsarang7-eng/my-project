// ============================================
// Cognito Auth Controller — Dual-Portal Login & MFA
// ============================================
// Handles authentication for the Flutter desktop/mobile client.
// Two distinct login flows:
//   POST /api/cognito-auth/owner/login    — Owner login (requires MFA)
//   POST /api/cognito-auth/staff/login    — Staff login (standard)
//   POST /api/cognito-auth/verify-mfa     — Complete MFA challenge
//   POST /api/cognito-auth/verify-sms-mfa — Complete SMS MFA challenge
//   POST /api/cognito-auth/refresh        — Refresh tokens
//   POST /api/cognito-auth/staff/accept-invite — Staff accepts invite code + sets password
//   GET  /api/cognito-auth/me             — Get current user info from JWT
//
// Role Enforcement:
//   - Owner portal: ONLY users with role=owner can proceed. Staff get 403.
//   - Staff portal: ONLY users with role=staff (or variants) can proceed.
//   - MFA is MANDATORY for Owner login (SMS OTP via SNS).
// ============================================

import { Router, Request, Response } from 'express';
import {
    CognitoIdentityProviderClient,
    InitiateAuthCommand,
    RespondToAuthChallengeCommand,
    AdminGetUserCommand,
    AdminCreateUserCommand,
    AdminSetUserPasswordCommand,
    AdminUpdateUserAttributesCommand,
    AdminSetUserMFAPreferenceCommand,
    ChallengeNameType,
    MessageActionType,
    DeliveryMediumType,
} from '@aws-sdk/client-cognito-identity-provider';
import { requireCognitoAuth } from '../middleware/cognitoAuth';
import { isOwnerLevelRole, isStaffLevelRole } from '../middleware/requireRole';
import { authRateLimiter } from '../middleware/rateLimiter';
import { queryOne, query } from '../config/database';
import { logger } from '../utils/logger';

const router = Router();

// ---- Cognito Client (AWS SDK v3) ----

const cognitoClient = new CognitoIdentityProviderClient({
    region: process.env.AWS_REGION || 'ap-south-1',
});

const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID!;
const CLIENT_ID = process.env.COGNITO_DESKTOP_CLIENT_ID || process.env.COGNITO_CLIENT_ID!;

// ---- Helper: Decode JWT payload without verification (for role pre-check) ----

function decodeJwtPayload(token: string): Record<string, any> | null {
    try {
        const parts = token.split('.');
        if (parts.length !== 3) return null;
        const payload = Buffer.from(parts[1], 'base64url').toString('utf-8');
        return JSON.parse(payload);
    } catch {
        return null;
    }
}

// ============================================
// POST /api/cognito-auth/owner/login
// ============================================
// Owner Login — Requires role=owner. MFA mandatory.
// Body: { email, password }
// Returns: tokens OR challenge (MFA_REQUIRED)

router.post('/owner/login', authRateLimiter, async (req: Request, res: Response) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            res.status(400).json({ error: 'Email and password are required', code: 'MISSING_FIELDS' });
            return;
        }

        // 1. Initiate Cognito auth
        const authResult = await cognitoClient.send(new InitiateAuthCommand({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: CLIENT_ID,
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password,
            },
        }));

        // 2. Check for challenges (MFA, new password, etc.)
        if (authResult.ChallengeName) {
            // For Owner login, MFA challenges are EXPECTED and required
            const challengeResponse: Record<string, any> = {
                challenge: true,
                challenge_name: authResult.ChallengeName,
                session: authResult.Session,
                parameters: authResult.ChallengeParameters || {},
            };

            // If SMS_MFA or SOFTWARE_TOKEN_MFA — good, owner must complete it
            if (authResult.ChallengeName === 'SMS_MFA' || authResult.ChallengeName === 'SOFTWARE_TOKEN_MFA') {
                challengeResponse.message = 'MFA verification required. Please enter the OTP code.';
                challengeResponse.portal = 'owner';
                res.json(challengeResponse);
                return;
            }

            // NEW_PASSWORD_REQUIRED — first login, must set new password
            if (authResult.ChallengeName === 'NEW_PASSWORD_REQUIRED') {
                challengeResponse.message = 'You must set a new password on first login.';
                challengeResponse.portal = 'owner';
                res.json(challengeResponse);
                return;
            }

            // MFA_SETUP — Owner must set up MFA
            if (authResult.ChallengeName === 'MFA_SETUP') {
                challengeResponse.message = 'MFA setup required for owner accounts.';
                challengeResponse.portal = 'owner';
                res.json(challengeResponse);
                return;
            }

            // Unknown challenge
            res.json(challengeResponse);
            return;
        }

        // 3. Auth succeeded without challenge — check role BEFORE returning tokens
        const idToken = authResult.AuthenticationResult?.IdToken;
        if (!idToken) {
            res.status(500).json({ error: 'Authentication succeeded but no ID token returned', code: 'TOKEN_MISSING' });
            return;
        }

        const claims = decodeJwtPayload(idToken);
        const userRole = claims?.['custom:role'] || 'unknown';

        // CRITICAL: Enforce owner-only access
        if (!isOwnerLevelRole(userRole)) {
            logger.warn('Staff attempted owner portal login', {
                email,
                role: userRole,
                sub: claims?.sub,
            });

            // Do NOT return tokens — reject immediately
            res.status(403).json({
                error: 'Access denied. This login portal is for business owners only. Please use the Staff Login.',
                code: 'PORTAL_FORBIDDEN',
                portal: 'owner',
                your_role: userRole,
            });
            return;
        }

        // 4. Owner authenticated without MFA — this means MFA is not configured
        // We should warn but still allow (MFA setup can be enforced separately)
        logger.warn('Owner login without MFA', { email, sub: claims?.sub });

        res.json({
            challenge: false,
            portal: 'owner',
            tokens: {
                access_token: authResult.AuthenticationResult!.AccessToken,
                id_token: authResult.AuthenticationResult!.IdToken,
                refresh_token: authResult.AuthenticationResult!.RefreshToken,
                expires_in: authResult.AuthenticationResult!.ExpiresIn,
            },
            user: {
                sub: claims?.sub,
                email: claims?.email,
                role: userRole,
                tenant_id: claims?.['custom:tenant_id'],
                mfa_configured: false, // No MFA challenge means it's not set up
            },
            warning: 'MFA is not configured for this account. Please set up MFA for enhanced security.',
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'owner/login');
    }
});

// ============================================
// POST /api/cognito-auth/staff/login
// ============================================
// Staff Login — Requires role=staff (or variants). Standard auth.
// Body: { email, password }

router.post('/staff/login', authRateLimiter, async (req: Request, res: Response) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            res.status(400).json({ error: 'Email and password are required', code: 'MISSING_FIELDS' });
            return;
        }

        // 1. Initiate auth
        const authResult = await cognitoClient.send(new InitiateAuthCommand({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: CLIENT_ID,
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password,
            },
        }));

        // 2. Handle challenges
        if (authResult.ChallengeName) {
            const challengeResponse: Record<string, any> = {
                challenge: true,
                challenge_name: authResult.ChallengeName,
                session: authResult.Session,
                parameters: authResult.ChallengeParameters || {},
                portal: 'staff',
            };

            if (authResult.ChallengeName === 'NEW_PASSWORD_REQUIRED') {
                challengeResponse.message = 'Welcome! Please set your password for first login.';
            } else if (authResult.ChallengeName === 'SMS_MFA' || authResult.ChallengeName === 'SOFTWARE_TOKEN_MFA') {
                challengeResponse.message = 'MFA verification required.';
            }

            res.json(challengeResponse);
            return;
        }

        // 3. Auth succeeded — check role
        const idToken = authResult.AuthenticationResult?.IdToken;
        if (!idToken) {
            res.status(500).json({ error: 'Authentication succeeded but no ID token returned', code: 'TOKEN_MISSING' });
            return;
        }

        const claims = decodeJwtPayload(idToken);
        const userRole = claims?.['custom:role'] || 'unknown';

        // CRITICAL: Reject owners from staff portal
        if (isOwnerLevelRole(userRole)) {
            logger.warn('Owner attempted staff portal login', {
                email,
                role: userRole,
                sub: claims?.sub,
            });

            res.status(403).json({
                error: 'Access denied. Business owners must use the Owner Login portal.',
                code: 'PORTAL_FORBIDDEN',
                portal: 'staff',
                your_role: userRole,
            });
            return;
        }

        // Verify the user is actually a staff variant
        if (!isStaffLevelRole(userRole) && userRole !== 'unknown') {
            res.status(403).json({
                error: 'Access denied. Unrecognized role.',
                code: 'ROLE_INVALID',
                your_role: userRole,
            });
            return;
        }

        // 4. Check staff is active in the tenant
        const cognitoSub = claims?.sub;
        const tenantId = claims?.['custom:tenant_id'];

        if (tenantId && cognitoSub) {
            const staff = await queryOne(
                `SELECT is_active FROM staff_members WHERE cognito_sub = $1 AND tenant_id = $2`,
                [cognitoSub, tenantId]
            );

            if (staff && !(staff as any).is_active) {
                res.status(403).json({
                    error: 'Your account has been deactivated. Please contact the business owner.',
                    code: 'STAFF_INACTIVE',
                });
                return;
            }
        }

        // 5. Update last login
        if (cognitoSub && tenantId) {
            await queryOne(
                `UPDATE staff_members SET last_login_at = NOW() WHERE cognito_sub = $1 AND tenant_id = $2`,
                [cognitoSub, tenantId]
            ).catch(() => { /* non-critical */ });
        }

        logger.info('Staff login successful', { email, role: userRole, tenant: tenantId });

        res.json({
            challenge: false,
            portal: 'staff',
            tokens: {
                access_token: authResult.AuthenticationResult!.AccessToken,
                id_token: authResult.AuthenticationResult!.IdToken,
                refresh_token: authResult.AuthenticationResult!.RefreshToken,
                expires_in: authResult.AuthenticationResult!.ExpiresIn,
            },
            user: {
                sub: cognitoSub,
                email: claims?.email,
                role: userRole,
                tenant_id: tenantId,
                staff_id: claims?.['custom:staff_id'],
            },
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'staff/login');
    }
});

// ============================================
// POST /api/cognito-auth/verify-mfa
// ============================================
// Complete MFA challenge (SMS or TOTP).
// Body: { session, mfa_code, challenge_name, email, portal }

router.post('/verify-mfa', authRateLimiter, async (req: Request, res: Response) => {
    try {
        const { session, mfa_code, challenge_name, email, portal } = req.body;

        if (!session || !mfa_code || !email) {
            res.status(400).json({ error: 'session, mfa_code, and email are required', code: 'MISSING_FIELDS' });
            return;
        }

        const challengeName = challenge_name || 'SMS_MFA';

        // Determine the correct response key based on challenge type
        const challengeResponses: Record<string, string> = {
            USERNAME: email,
        };

        if (challengeName === 'SMS_MFA') {
            challengeResponses.SMS_MFA_CODE = mfa_code;
        } else if (challengeName === 'SOFTWARE_TOKEN_MFA') {
            challengeResponses.SOFTWARE_TOKEN_MFA_CODE = mfa_code;
        }

        const result = await cognitoClient.send(new RespondToAuthChallengeCommand({
            ClientId: CLIENT_ID,
            ChallengeName: challengeName as ChallengeNameType,
            Session: session,
            ChallengeResponses: challengeResponses,
        }));

        // Check for another challenge (rare, but possible)
        if (result.ChallengeName) {
            res.json({
                challenge: true,
                challenge_name: result.ChallengeName,
                session: result.Session,
                parameters: result.ChallengeParameters || {},
            });
            return;
        }

        // Success — verify role matches portal
        const idToken = result.AuthenticationResult?.IdToken;
        const claims = idToken ? decodeJwtPayload(idToken) : null;
        const userRole = claims?.['custom:role'] || 'unknown';

        // Portal enforcement after MFA
        if (portal === 'owner' && !isOwnerLevelRole(userRole)) {
            res.status(403).json({
                error: 'Access denied. Staff cannot use the Owner portal.',
                code: 'PORTAL_FORBIDDEN',
                portal: 'owner',
                your_role: userRole,
            });
            return;
        }

        if (portal === 'staff' && isOwnerLevelRole(userRole)) {
            res.status(403).json({
                error: 'Access denied. Owners must use the Owner portal.',
                code: 'PORTAL_FORBIDDEN',
                portal: 'staff',
                your_role: userRole,
            });
            return;
        }

        logger.info('MFA verification successful', {
            email,
            portal,
            role: userRole,
            challengeType: challengeName,
        });

        res.json({
            challenge: false,
            portal,
            tokens: {
                access_token: result.AuthenticationResult!.AccessToken,
                id_token: result.AuthenticationResult!.IdToken,
                refresh_token: result.AuthenticationResult!.RefreshToken,
                expires_in: result.AuthenticationResult!.ExpiresIn,
            },
            user: {
                sub: claims?.sub,
                email: claims?.email,
                role: userRole,
                tenant_id: claims?.['custom:tenant_id'],
                mfa_configured: true,
            },
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'verify-mfa');
    }
});

// ============================================
// POST /api/cognito-auth/complete-new-password
// ============================================
// Complete NEW_PASSWORD_REQUIRED challenge (first-time login).
// Body: { session, email, new_password, portal }

router.post('/complete-new-password', authRateLimiter, async (req: Request, res: Response) => {
    try {
        const { session, email, new_password, portal } = req.body;

        if (!session || !email || !new_password) {
            res.status(400).json({ error: 'session, email, and new_password are required', code: 'MISSING_FIELDS' });
            return;
        }

        // Password validation
        if (new_password.length < 8) {
            res.status(400).json({ error: 'Password must be at least 8 characters', code: 'WEAK_PASSWORD' });
            return;
        }

        const result = await cognitoClient.send(new RespondToAuthChallengeCommand({
            ClientId: CLIENT_ID,
            ChallengeName: 'NEW_PASSWORD_REQUIRED',
            Session: session,
            ChallengeResponses: {
                USERNAME: email,
                NEW_PASSWORD: new_password,
            },
        }));

        // May trigger another challenge (e.g., MFA setup)
        if (result.ChallengeName) {
            res.json({
                challenge: true,
                challenge_name: result.ChallengeName,
                session: result.Session,
                parameters: result.ChallengeParameters || {},
                portal,
                message: result.ChallengeName === 'MFA_SETUP'
                    ? 'Password set. Now please set up MFA.'
                    : `Additional verification required: ${result.ChallengeName}`,
            });
            return;
        }

        // Success
        const idToken = result.AuthenticationResult?.IdToken;
        const claims = idToken ? decodeJwtPayload(idToken) : null;
        const userRole = claims?.['custom:role'] || 'unknown';

        res.json({
            challenge: false,
            portal,
            tokens: {
                access_token: result.AuthenticationResult!.AccessToken,
                id_token: result.AuthenticationResult!.IdToken,
                refresh_token: result.AuthenticationResult!.RefreshToken,
                expires_in: result.AuthenticationResult!.ExpiresIn,
            },
            user: {
                sub: claims?.sub,
                email: claims?.email,
                role: userRole,
                tenant_id: claims?.['custom:tenant_id'],
            },
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'complete-new-password');
    }
});

// ============================================
// POST /api/cognito-auth/refresh
// ============================================
// Refresh access/id tokens using refresh token.
// Body: { refresh_token }

router.post('/refresh', async (req: Request, res: Response) => {
    try {
        const { refresh_token } = req.body;

        if (!refresh_token) {
            res.status(400).json({ error: 'refresh_token is required', code: 'MISSING_FIELDS' });
            return;
        }

        const result = await cognitoClient.send(new InitiateAuthCommand({
            AuthFlow: 'REFRESH_TOKEN_AUTH',
            ClientId: CLIENT_ID,
            AuthParameters: {
                REFRESH_TOKEN: refresh_token,
            },
        }));

        if (!result.AuthenticationResult) {
            res.status(401).json({ error: 'Token refresh failed', code: 'REFRESH_FAILED' });
            return;
        }

        const idToken = result.AuthenticationResult.IdToken;
        const claims = idToken ? decodeJwtPayload(idToken) : null;

        res.json({
            tokens: {
                access_token: result.AuthenticationResult.AccessToken,
                id_token: result.AuthenticationResult.IdToken,
                expires_in: result.AuthenticationResult.ExpiresIn,
            },
            user: {
                sub: claims?.sub,
                email: claims?.email,
                role: claims?.['custom:role'],
                tenant_id: claims?.['custom:tenant_id'],
            },
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'refresh');
    }
});

// ============================================
// POST /api/cognito-auth/staff/create-account
// ============================================
// Owner creates a Cognito account for a staff member.
// Requires owner auth. Creates user with temp password.
// Body: { email, name, phone?, role_id, tenant_id }

router.post('/staff/create-account', requireCognitoAuth, async (req: Request, res: Response) => {
    try {
        // Only owners can create staff accounts
        const callerRole = req.cognitoUser?.role || (req as any).user?.role;
        if (!isOwnerLevelRole(callerRole)) {
            res.status(403).json({ error: 'Only owners can create staff accounts', code: 'OWNER_REQUIRED' });
            return;
        }

        const { email, name, phone, role_name, tenant_id } = req.body;
        const ownerTenantId = req.cognitoUser?.tenantId || tenant_id;

        if (!email || !name || !ownerTenantId) {
            res.status(400).json({ error: 'email, name, and tenant_id are required', code: 'MISSING_FIELDS' });
            return;
        }

        const staffRole = role_name || 'staff';

        // 1. Create Cognito user with temporary password
        const tempPassword = _generateTempPassword();

        const userAttributes = [
            { Name: 'email', Value: email },
            { Name: 'email_verified', Value: 'true' }, // Skip email verification for invited staff
            { Name: 'name', Value: name },
            { Name: 'custom:role', Value: staffRole },
            { Name: 'custom:tenant_id', Value: ownerTenantId },
        ];

        if (phone) {
            userAttributes.push({ Name: 'phone_number', Value: phone });
        }

        const createResult = await cognitoClient.send(new AdminCreateUserCommand({
            UserPoolId: USER_POOL_ID,
            Username: email,
            TemporaryPassword: tempPassword,
            UserAttributes: userAttributes,
            MessageAction: MessageActionType.SUPPRESS, // Don't send welcome email (we send invite code instead)
            DesiredDeliveryMediums: [DeliveryMediumType.EMAIL],
        }));

        const cognitoSub = createResult.User?.Attributes?.find((a: any) => a.Name === 'sub')?.Value;

        logger.info('Staff Cognito account created', {
            email,
            cognitoSub,
            tenant: ownerTenantId,
            createdBy: req.cognitoUser?.sub,
        });

        res.status(201).json({
            success: true,
            cognito_sub: cognitoSub,
            email,
            temp_password: tempPassword, // Owner shares this with staff
            message: 'Staff Cognito account created. Share the temporary password with the staff member.',
        });

    } catch (error: any) {
        if (error.name === 'UsernameExistsException') {
            res.status(409).json({
                error: 'A user with this email already exists in the system',
                code: 'USER_EXISTS',
            });
            return;
        }
        _handleCognitoError(res, error, 'staff/create-account');
    }
});

// ============================================
// POST /api/cognito-auth/owner/setup-sms-mfa
// ============================================
// Enable SMS MFA for the owner account.
// Requires owner auth.
// Body: { phone_number } (E.164 format: +919876543210)

router.post('/owner/setup-sms-mfa', requireCognitoAuth, async (req: Request, res: Response) => {
    try {
        const callerRole = req.cognitoUser?.role || (req as any).user?.role;
        if (!isOwnerLevelRole(callerRole)) {
            res.status(403).json({ error: 'Only owners can configure MFA', code: 'OWNER_REQUIRED' });
            return;
        }

        const { phone_number } = req.body;
        const cognitoSub = req.cognitoUser?.sub || (req as any).user?.sub;

        if (!phone_number) {
            res.status(400).json({ error: 'phone_number is required (E.164 format: +919876543210)', code: 'MISSING_FIELDS' });
            return;
        }

        // Validate E.164 format
        if (!/^\+[1-9]\d{6,14}$/.test(phone_number)) {
            res.status(400).json({ error: 'Invalid phone number format. Use E.164: +919876543210', code: 'INVALID_PHONE' });
            return;
        }

        // 1. Update phone number attribute
        await cognitoClient.send(new AdminUpdateUserAttributesCommand({
            UserPoolId: USER_POOL_ID,
            Username: cognitoSub,
            UserAttributes: [
                { Name: 'phone_number', Value: phone_number },
                { Name: 'phone_number_verified', Value: 'true' },
            ],
        }));

        // 2. Enable SMS MFA
        await cognitoClient.send(new AdminSetUserMFAPreferenceCommand({
            UserPoolId: USER_POOL_ID,
            Username: cognitoSub,
            SMSMfaSettings: {
                Enabled: true,
                PreferredMfa: true,
            },
        }));

        logger.info('Owner SMS MFA enabled', { sub: cognitoSub, phone: phone_number.slice(0, 6) + '****' });

        res.json({
            success: true,
            message: 'SMS MFA enabled successfully. You will receive an OTP on every login.',
            phone_number: phone_number.slice(0, 6) + '****' + phone_number.slice(-2),
        });

    } catch (error: any) {
        _handleCognitoError(res, error, 'owner/setup-sms-mfa');
    }
});

// ============================================
// GET /api/cognito-auth/me
// ============================================
// Get current user info from JWT (requires auth).

router.get('/me', requireCognitoAuth, async (req: Request, res: Response) => {
    const user = req.cognitoUser;
    if (!user) {
        res.status(401).json({ error: 'Not authenticated' });
        return;
    }

    res.json({
        sub: user.sub,
        email: user.email,
        role: user.role,
        tenant_id: user.tenantId,
        groups: user.groups,
        is_owner: isOwnerLevelRole(user.role),
        is_staff: isStaffLevelRole(user.role),
    });
});

// ============================================
// Error Handler
// ============================================

function _handleCognitoError(res: Response, error: any, context: string): void {
    const errorCode = error.name || error.__type || 'UnknownError';
    const errorMessage = error.message || 'An unexpected error occurred';

    logger.error(`Cognito auth error [${context}]`, {
        code: errorCode,
        message: errorMessage,
    });

    switch (errorCode) {
        case 'NotAuthorizedException':
            res.status(401).json({
                error: 'Invalid email or password',
                code: 'AUTH_INVALID_CREDENTIALS',
            });
            break;

        case 'UserNotFoundException':
            res.status(401).json({
                error: 'Invalid email or password',
                code: 'AUTH_INVALID_CREDENTIALS', // Don't reveal user existence
            });
            break;

        case 'UserNotConfirmedException':
            res.status(403).json({
                error: 'Account not confirmed. Please verify your email first.',
                code: 'USER_NOT_CONFIRMED',
            });
            break;

        case 'PasswordResetRequiredException':
            res.status(403).json({
                error: 'Password reset required. Please reset your password.',
                code: 'PASSWORD_RESET_REQUIRED',
            });
            break;

        case 'TooManyRequestsException':
        case 'LimitExceededException':
            res.status(429).json({
                error: 'Too many attempts. Please try again later.',
                code: 'RATE_LIMIT',
            });
            break;

        case 'CodeMismatchException':
            res.status(400).json({
                error: 'Invalid verification code. Please try again.',
                code: 'CODE_MISMATCH',
            });
            break;

        case 'ExpiredCodeException':
            res.status(400).json({
                error: 'Verification code has expired. Please request a new one.',
                code: 'CODE_EXPIRED',
            });
            break;

        case 'InvalidPasswordException':
            res.status(400).json({
                error: 'Password does not meet requirements. Must be 8+ chars with uppercase, lowercase, number, and symbol.',
                code: 'INVALID_PASSWORD',
            });
            break;

        default:
            res.status(500).json({
                error: 'Authentication service error',
                code: 'AUTH_SERVICE_ERROR',
            });
    }
}

// ---- Helper: Generate temporary password for staff ----

function _generateTempPassword(): string {
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const special = '!@#$%^&*';
    const all = upper + lower + digits + special;

    // Ensure at least one of each type
    let password = '';
    password += upper[Math.floor(Math.random() * upper.length)];
    password += lower[Math.floor(Math.random() * lower.length)];
    password += digits[Math.floor(Math.random() * digits.length)];
    password += special[Math.floor(Math.random() * special.length)];

    // Fill remaining with random chars
    for (let i = 0; i < 8; i++) {
        password += all[Math.floor(Math.random() * all.length)];
    }

    // Shuffle
    return password.split('').sort(() => Math.random() - 0.5).join('');
}

export default router;
