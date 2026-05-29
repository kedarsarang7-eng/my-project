// ============================================================================
// Auth Service — Cognito User Management (DynamoDB)
// ============================================================================
// Handles signup (tenant creation + Cognito user), login, and token refresh.
// Migrated from PostgreSQL to DynamoDB single-table design.
//
// SECURITY: Implements compensating transaction — if DynamoDB insert fails,
// the Cognito user is deleted to prevent orphaned accounts.
// ============================================================================

import {
    CognitoIdentityProviderClient,
    SignUpCommand,
    InitiateAuthCommand,
    RespondToAuthChallengeCommand,
    AssociateSoftwareTokenCommand,
    VerifySoftwareTokenCommand,
    AdminDeleteUserCommand,
    AdminUpdateUserAttributesCommand,
    GlobalSignOutCommand,
    ChangePasswordCommand,
    RevokeTokenCommand,
    GetUserCommand,
    AdminListGroupsForUserCommand,
    ForgotPasswordCommand,
    ConfirmForgotPasswordCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { v4 as uuidv4 } from 'uuid';
import { cognitoConfig } from '../config/aws.config';
import {
    Keys,
    getItem, putItem, updateItem, transactWrite,
} from '../config/dynamodb.config';
import { BusinessType, SubscriptionPlan, UserRole } from '../types/tenant.types';
import { logger } from '../utils/logger';
import { config } from '../config/environment';

const cognitoClient = new CognitoIdentityProviderClient({
    region: cognitoConfig.region,
});

export interface SignupInput {
    email: string;
    password: string;
    fullName?: string;
    businessName: string;
    businessType: string;
    phone?: string;
    licenseKey: string;
}

export interface AuthTokens {
    accessToken?: string;
    idToken?: string;
    refreshToken?: string;
    expiresIn?: number;
    challengeName?: string;
    session?: string;
    token?: string;
    user?: {
        id: string;
        name: string;
        email: string;
        role: string;
    };
    permissions?: string[];
    // ENHANCED: Multi-business license support
    license?: {
        tenantId: string;
        businessType: string;
        allowedBusinessTypes: string[];
        plan: string;
        status: string;
        expiresAt?: string;
        maxUsers?: number;
        maxDevices?: number;
        features: string[];
    } | null;
}

const PERMISSIONS_BY_ROLE: Record<string, string[]> = {
    Staff: ['view_invoices', 'create_invoices', 'view_clients'],
    CA: ['view_invoices', 'create_invoices', 'view_reports', 'export_reports', 'view_clients'],
    Manager: ['view_invoices', 'create_invoices', 'view_reports', 'export_reports', 'view_clients', 'manage_staff', 'view_analytics'],
    Admin: ['ALL_PERMISSIONS'],
};

const GROUP_TO_ROLE: Record<string, string> = {
    Admin: 'Admin',
    SuperAdmin: 'Admin',
    BusinessOwner: 'Admin',
    Staff: 'Staff',
    Manager: 'Manager',
    CA: 'CA',
    CharteredAccountant: 'CA',
    Viewer: 'Staff',
    Customer: 'Staff',
};

export function normalizeRole(rawRole: string): string {
    return GROUP_TO_ROLE[rawRole] || rawRole;
}

export function permissionsForRole(role: string): string[] {
    return PERMISSIONS_BY_ROLE[role] || [];
}

export class AuthService {

    /**
     * Register a new business owner:
     * 1. Create the Cognito user
     * 2. Create the tenant + user records in DynamoDB (transactional)
     * 3. If DynamoDB fails → DELETE the Cognito user (compensating transaction)
     */
    async signup(input: SignupInput): Promise<{ tenantId: string; userId: string }> {
        const tenantId = uuidv4();
        const userId = uuidv4();
        const now = new Date().toISOString();

        // ── Step 1: Create Cognito user ───────────────────────────────────
        const signUpCommand = new SignUpCommand({
            ClientId: cognitoConfig.clientId,
            Username: input.email,
            Password: input.password,
            UserAttributes: [
                { Name: 'email', Value: input.email },
                { Name: 'custom:tenant_id', Value: tenantId },
                { Name: 'custom:business_id', Value: tenantId },
                { Name: 'custom:role', Value: UserRole.OWNER },
                { Name: 'custom:user_role', Value: 'admin' },
                { Name: 'custom:business_type', Value: input.businessType },
                { Name: 'custom:plan', Value: 'premium' },
                { Name: 'custom:plan_status', Value: 'trial' },
            ],
        });

        const cognitoResult = await cognitoClient.send(signUpCommand);
        const cognitoSub = cognitoResult.UserSub!;

        // ── Step 2: Create tenant + user in DynamoDB (transactional) ──────
        try {
            const transactItems: any[] = [
                // Create tenant profile (with 15-day Premium trial)
                {
                    Put: {
                        TableName: config.dynamodb.tableName,
                        Item: {
                            PK: Keys.tenantPK(tenantId),
                            SK: Keys.tenantProfileSK(),
                            entityType: 'TENANT',
                            id: tenantId,
                            tenantId,
                            name: input.businessName,
                            businessType: input.businessType,
                            // ── 15-Day Premium Trial (NEW) ─────────────────────────
                            subscriptionPlan: SubscriptionPlan.PREMIUM,
                            planStatus: 'trial',
                            billingCycle: 'monthly',
                            planStartDate: now,
                            trialEndDate: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
                            subscriptionValidUntil: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
                            // ── Usage Counters ────────────────────────────────────
                            currentMonthInvoiceCount: 0,
                            currentProductCount: 0,
                            invoiceCountMonth: new Date().toISOString().slice(0, 7).replace('-', '-'),
                            // ── Status ────────────────────────────────────────────
                            licenseStatus: 'trial',
                            isActive: true,
                            settings: {
                                currency: 'INR',
                                timezone: 'Asia/Kolkata',
                                fiscalYearStart: 4,
                                enableGst: true,
                                enableMultiCurrency: false,
                            },
                            createdAt: now,
                            updatedAt: now,
                        },
                        ConditionExpression: 'attribute_not_exists(PK)',
                    },
                },
                // Create user record
                {
                    Put: {
                        TableName: config.dynamodb.tableName,
                        Item: {
                            PK: Keys.tenantPK(tenantId),
                            SK: Keys.userSK(userId),
                            entityType: 'USER',
                            id: userId,
                            tenantId,
                            cognitoSub,
                            email: input.email,
                            fullName: input.fullName || null,
                            phone: input.phone || null,
                            role: UserRole.OWNER,
                            isActive: true,
                            createdAt: now,
                            updatedAt: now,
                            // GSI1: email lookup
                            GSI1PK: Keys.emailGSI1PK(input.email),
                            GSI1SK: 'USER',
                            // GSI2: cognito sub lookup
                            GSI2PK: Keys.cognitoSubGSI2PK(cognitoSub),
                            GSI2SK: 'USER',
                        },
                        ConditionExpression: 'attribute_not_exists(PK)',
                    },
                },
            ];

            await transactWrite(transactItems);

            // ── Step 3: Bind Tenant to License (if provided) ──────────────
            if (input.licenseKey && input.licenseKey.trim()) {
                const license = await getItem<Record<string, any>>(
                    Keys.licensePK(input.licenseKey),
                    Keys.licenseMetaSK(),
                );

                if (license && license.status === 'ACTIVE') {
                    await updateItem(
                        Keys.licensePK(input.licenseKey),
                        Keys.licenseMetaSK(),
                        {
                            updateExpression: 'SET tenantId = :tid, #s = :activated, updatedAt = :now',
                            expressionAttributeNames: { '#s': 'status' },
                            expressionAttributeValues: {
                                ':tid': tenantId,
                                ':activated': 'ACTIVATED',
                                ':now': now,
                            },
                        },
                    );
                    logger.info('License bound to new tenant during signup', {
                        tenantId, licenseKey: input.licenseKey.substring(0, 8) + '...',
                    });
                } else if (license) {
                    logger.warn('License key provided at signup is not ACTIVE', {
                        status: license.status, tenantId,
                    });
                } else {
                    logger.info('No standalone license found for key, skipping binding', { tenantId });
                }
            }

        } catch (err) {
            // ── Compensating Transaction: Delete orphaned Cognito user ─────
            logger.error('Signup DynamoDB transaction failed — deleting Cognito user', {
                error: (err as Error).message,
                cognitoSub,
                email: input.email,
            });

            try {
                await cognitoClient.send(new AdminDeleteUserCommand({
                    UserPoolId: cognitoConfig.userPoolId,
                    Username: input.email,
                }));
                logger.info('Cognito user cleaned up after DB failure', { email: input.email });
            } catch (cleanupErr) {
                logger.error('CRITICAL: Failed to clean up Cognito user after DB failure', {
                    email: input.email,
                    cognitoSub,
                    cleanupError: (cleanupErr as Error).message,
                    originalError: (err as Error).message,
                });
            }

            throw err;
        }

        logger.info('Tenant registered successfully', {
            tenantId, userId, businessType: input.businessType,
        });

        return { tenantId, userId };
    }

    /**
     * Authenticate a user with email + password.
     */
    async login(email: string, password: string): Promise<AuthTokens> {
        const command = new InitiateAuthCommand({
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: cognitoConfig.clientId,
            AuthParameters: {
                USERNAME: email,
                PASSWORD: password,
            },
        });

        const result = await cognitoClient.send(command);

        if (result.ChallengeName) {
            return {
                challengeName: result.ChallengeName,
                session: result.Session,
            };
        }

        const authResult = result.AuthenticationResult!;
        const accessToken = authResult.AccessToken!;
        const idToken = authResult.IdToken!;
        const { user, permissions, tenantId } = await this.resolveUserAndPermissions(email, accessToken);

        // ENHANCED: Fetch license data for multi-business support
        const license = await this.getLicenseData(tenantId);

        return {
            accessToken,
            idToken,
            refreshToken: authResult.RefreshToken,
            expiresIn: authResult.ExpiresIn || 3600,
            token: accessToken,
            user,
            permissions,
            license,
        };
    }

    private async resolveUserAndPermissions(email: string, accessToken: string): Promise<{
        user: { id: string; name: string; email: string; role: string };
        permissions: string[];
        tenantId: string;
    }> {
        const userInfo = await cognitoClient.send(
            new GetUserCommand({ AccessToken: accessToken }),
        );
        const attrs = Object.fromEntries(
            (userInfo.UserAttributes || []).map((a) => [a.Name || '', a.Value || '']),
        );
        const groups = await cognitoClient.send(
            new AdminListGroupsForUserCommand({
                UserPoolId: cognitoConfig.userPoolId,
                Username: email,
                Limit: 10,
            }),
        );
        const roleFromGroupRaw = (groups.Groups || [])[0]?.GroupName || '';
        const roleFromAttrRaw = attrs['custom:role'] || '';
        const roleFromGroup = normalizeRole(roleFromGroupRaw);
        const roleFromAttr = normalizeRole(roleFromAttrRaw);
        const resolvedRole = roleFromGroup || roleFromAttr;
        const permissions = permissionsForRole(resolvedRole);

        if (!resolvedRole) {
            throw new Error('Account not configured. No assigned role/group.');
        }

        const tenantId = attrs['custom:tenant_id'] || '';
        if (!tenantId) {
            throw new Error('Account not configured. No tenant ID found.');
        }

        return {
            user: {
                id: userInfo.Username || attrs.sub || email,
                name: attrs.name || attrs.given_name || email.split('@')[0],
                email: attrs.email || email,
                role: resolvedRole,
            },
            permissions,
            tenantId,
        };
    }

    async getMe(accessToken: string): Promise<AuthTokens> {
        const userInfo = await cognitoClient.send(
            new GetUserCommand({ AccessToken: accessToken }),
        );
        const attrs = Object.fromEntries(
            (userInfo.UserAttributes || []).map((a) => [a.Name || '', a.Value || '']),
        );
        const username = attrs.email || userInfo.Username || '';
        const { user, permissions, tenantId } = await this.resolveUserAndPermissions(username, accessToken);
        
        // ENHANCED: Fetch license data for multi-business support
        const license = await this.getLicenseData(tenantId);
        
        return {
            token: accessToken,
            user,
            permissions,
            license,
        };
    }

    /**
     * ENHANCED: Fetch license data for a tenant to include in login response.
     * Supports multi-business licenses by returning allowedBusinessTypes array.
     */
    private async getLicenseData(tenantId: string): Promise<AuthTokens['license'] | null> {
        try {
            // Get tenant license record
            const licenseRecord = await getItem<Record<string, any>>(
                Keys.tenantPK(tenantId),
                Keys.tenantLicenseSK()
            );

            if (!licenseRecord) {
                logger.warn('No license record found for tenant', { tenantId });
                return null;
            }

            // Extract license information
            const licenseData: AuthTokens['license'] = {
                tenantId,
                businessType: licenseRecord.businessType || 'unknown',
                allowedBusinessTypes: licenseRecord.allowedBusinessTypes || [licenseRecord.businessType || 'unknown'],
                plan: licenseRecord.plan || 'unknown',
                status: licenseRecord.status || 'UNKNOWN',
                expiresAt: licenseRecord.expiryDate || null,
                maxUsers: licenseRecord.maxUsers || 10,
                maxDevices: licenseRecord.maxDevices || 1,
                features: licenseRecord.features || [],
            };

            logger.debug('License data fetched for login', {
                tenantId,
                businessType: licenseData.businessType,
                allowedBusinessTypes: licenseData.allowedBusinessTypes,
                plan: licenseData.plan,
            });

            return licenseData;
        } catch (error) {
            logger.error('Failed to fetch license data for login', {
                tenantId,
                error: (error as Error).message,
            });
            // Return null instead of throwing to avoid blocking login
            return null;
        }
    }

    /**
     * Setup MFA for a new user.
     */
    async setupMfa(session: string): Promise<{ secretCode: string; session: string }> {
        const command = new AssociateSoftwareTokenCommand({ Session: session });
        const result = await cognitoClient.send(command);
        return { secretCode: result.SecretCode!, session: result.Session! };
    }

    /**
     * Verify first-time MFA setup code.
     */
    async verifyMfaSetup(session: string, totpCode: string): Promise<AuthTokens> {
        const command = new VerifySoftwareTokenCommand({ Session: session, UserCode: totpCode });
        const result = await cognitoClient.send(command);
        if (result.Status === 'SUCCESS') {
            return { session: result.Session, challengeName: 'MFA_SETUP_COMPLETE' };
        }
        throw new Error('MFA Setup Failed');
    }

    /**
     * Respond to an MFA Challenge during login.
     */
    async verifyMfa(username: string, session: string, totpCode: string): Promise<AuthTokens> {
        const command = new RespondToAuthChallengeCommand({
            ChallengeName: 'SOFTWARE_TOKEN_MFA',
            ClientId: cognitoConfig.clientId,
            ChallengeResponses: {
                USERNAME: username,
                SOFTWARE_TOKEN_MFA_CODE: totpCode,
            },
            Session: session,
        });

        const result = await cognitoClient.send(command);
        if (result.ChallengeName) {
            return { challengeName: result.ChallengeName, session: result.Session };
        }

        const authResult = result.AuthenticationResult!;
        return {
            accessToken: authResult.AccessToken!,
            idToken: authResult.IdToken!,
            refreshToken: authResult.RefreshToken!,
            expiresIn: authResult.ExpiresIn || 3600,
        };
    }

    /**
     * Refresh expired access tokens using the refresh token.
     */
    async refreshTokens(refreshToken: string): Promise<Omit<AuthTokens, 'refreshToken'>> {
        const command = new InitiateAuthCommand({
            AuthFlow: 'REFRESH_TOKEN_AUTH',
            ClientId: cognitoConfig.clientId,
            AuthParameters: { REFRESH_TOKEN: refreshToken },
        });

        const result = await cognitoClient.send(command);
        const authResult = result.AuthenticationResult!;
        return {
            accessToken: authResult.AccessToken!,
            idToken: authResult.IdToken!,
            expiresIn: authResult.ExpiresIn || 3600,
        };
    }

    /**
     * Auto-provision a user who logged in via Google/Phone Auth directly.
     */
    async autoProvision(sub: string, email: string, name?: string): Promise<{ tenantId: string; role: string; businessId: string }> {
        // Check if user already exists via GSI2 (cognito sub lookup)
        const existingResult = await import('../config/dynamodb.config').then(m =>
            m.queryItems<Record<string, any>>(
                Keys.cognitoSubGSI2PK(sub),
                'USER',
                { indexName: 'GSI2' },
            )
        );

        if (existingResult.items.length > 0) {
            const user = existingResult.items[0];
            // Get their first business
            const bizResult = await import('../config/dynamodb.config').then(m =>
                m.queryItems<Record<string, any>>(
                    Keys.tenantPK(user.tenantId),
                    'BUSINESS#',
                    { limit: 1 },
                )
            );
            return {
                tenantId: user.tenantId,
                role: user.role,
                businessId: bizResult.items[0]?.id,
            };
        }

        // User does not exist — First Login flow
        const tenantId = uuidv4();
        const businessId = uuidv4();
        const userId = uuidv4();
        const role = UserRole.OWNER;
        const businessType = 'other';
        const now = new Date().toISOString();

        const transactItems: any[] = [
            // Create tenant
            {
                Put: {
                    TableName: config.dynamodb.tableName,
                    Item: {
                        PK: Keys.tenantPK(tenantId),
                        SK: Keys.tenantProfileSK(),
                        entityType: 'TENANT',
                        id: tenantId,
                        tenantId,
                        name: name || 'My Business',
                        businessType,
                        subscriptionPlan: SubscriptionPlan.FREE,
                        isActive: true,
                        settings: {
                            currency: 'INR',
                            timezone: 'Asia/Kolkata',
                            fiscalYearStart: 4,
                            enableGst: false,
                            enableMultiCurrency: false,
                        },
                        createdAt: now,
                        updatedAt: now,
                    },
                },
            },
            // Create business profile
            {
                Put: {
                    TableName: config.dynamodb.tableName,
                    Item: {
                        PK: Keys.tenantPK(tenantId),
                        SK: Keys.businessSK(businessId),
                        entityType: 'BUSINESS',
                        id: businessId,
                        tenantId,
                        name: name || 'My Business',
                        businessType,
                        createdAt: now,
                        updatedAt: now,
                    },
                },
            },
            // Create user
            {
                Put: {
                    TableName: config.dynamodb.tableName,
                    Item: {
                        PK: Keys.tenantPK(tenantId),
                        SK: Keys.userSK(userId),
                        entityType: 'USER',
                        id: userId,
                        tenantId,
                        cognitoSub: sub,
                        email: email || `${sub}@generated.local`,
                        fullName: name || null,
                        role,
                        isActive: true,
                        createdAt: now,
                        updatedAt: now,
                        GSI1PK: Keys.emailGSI1PK(email || `${sub}@generated.local`),
                        GSI1SK: 'USER',
                        GSI2PK: Keys.cognitoSubGSI2PK(sub),
                        GSI2SK: 'USER',
                    },
                },
            },
        ];

        await transactWrite(transactItems);

        logger.info('Auto-provisioned new tenant from first login', { sub, tenantId, businessId });

        // Update Cognito Attributes in background
        try {
            const username = email && email.includes('@') ? email : sub;
            await cognitoClient.send(new AdminUpdateUserAttributesCommand({
                UserPoolId: cognitoConfig.userPoolId,
                Username: username,
                UserAttributes: [
                    { Name: 'custom:tenant_id', Value: tenantId },
                    { Name: 'custom:role', Value: role },
                ],
            }));
        } catch (cognitoErr) {
            logger.warn('Failed to update cognito attributes after auto-provision', {
                sub, error: (cognitoErr as Error).message,
            });
        }

        return { tenantId, role, businessId };
    }

    // =========================================================================
    // SECURITY FIX S-1: Logout — Revoke ALL refresh tokens (global sign-out)
    // =========================================================================
    /**
     * POST /auth/logout
     * Invalidates all refresh tokens for the user via Cognito globalSignOut.
     * After this, existing refresh tokens can no longer generate new access tokens.
     */
    async logout(accessToken: string): Promise<void> {
        // 1. Global sign-out — invalidates ALL sessions for this user
        await cognitoClient.send(new GlobalSignOutCommand({
            AccessToken: accessToken,
        }));

        logger.info('User logged out — all refresh tokens revoked');
    }

    // =========================================================================
    // SECURITY FIX S-1: Change Password — Revoke tokens after password change
    // =========================================================================
    /**
     * POST /auth/change-password
     * Changes the user's password and immediately revokes all existing sessions.
     * This prevents continued access using tokens issued with the old password.
     */
    // =========================================================================
    // AUDIT FIX #2: Forgot Password — Initiate Cognito password reset
    // =========================================================================
    async forgotPassword(email: string): Promise<void> {
        await cognitoClient.send(new ForgotPasswordCommand({
            ClientId: cognitoConfig.clientId,
            Username: email,
        }));
        logger.info('Password reset initiated', { email });
    }

    // =========================================================================
    // AUDIT FIX #2: Confirm Reset Password — Verify code + set new password
    // =========================================================================
    async confirmResetPassword(email: string, confirmationCode: string, newPassword: string): Promise<void> {
        await cognitoClient.send(new ConfirmForgotPasswordCommand({
            ClientId: cognitoConfig.clientId,
            Username: email,
            ConfirmationCode: confirmationCode,
            Password: newPassword,
        }));
        logger.info('Password reset confirmed', { email });
    }

    async changePassword(accessToken: string, previousPassword: string, proposedPassword: string): Promise<void> {
        // 1. Change password via Cognito
        await cognitoClient.send(new ChangePasswordCommand({
            AccessToken: accessToken,
            PreviousPassword: previousPassword,
            ProposedPassword: proposedPassword,
        }));

        // 2. Immediately revoke all sessions — forces re-login with new password
        try {
            await cognitoClient.send(new GlobalSignOutCommand({
                AccessToken: accessToken,
            }));
        } catch (signOutErr) {
            // The access token may have been invalidated by the password change itself
            // on some Cognito configurations — this is acceptable
            logger.warn('GlobalSignOut after password change failed (may be expected)', {
                error: (signOutErr as Error).message,
            });
        }

        logger.info('Password changed — all sessions revoked');
    }
}
