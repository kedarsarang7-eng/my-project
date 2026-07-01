// ============================================================================
// Auth Service — Cognito User Management (PORTABLE — no Lambda deps)
// ============================================================================
// Handles signup (tenant creation + Cognito user), login, and token refresh.
// This service can be used from Lambda OR from an Express/Docker server.
// ============================================================================

import {
    CognitoIdentityProviderClient,
    SignUpCommand,
    InitiateAuthCommand,
    AdminUpdateUserAttributesCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { v4 as uuidv4 } from 'uuid';
import { cognitoConfig } from '../config/aws.config';
import { getPool } from '../config/db.config';
import { BusinessType, SubscriptionPlan, UserRole } from '../types/tenant.types';
import { logger } from '../utils/logger';

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
}

export interface AuthTokens {
    accessToken: string;
    idToken: string;
    refreshToken: string;
    expiresIn: number;
}

export class AuthService {

    /**
     * Register a new business owner:
     * 1. Create the Cognito user
     * 2. Create the tenant (business) record in PostgreSQL
     * 3. Create the user record linked to the tenant
     * 4. Update Cognito custom attributes with tenant_id, role, business_type
     */
    async signup(input: SignupInput): Promise<{ tenantId: string; userId: string }> {
        const db = getPool();
        const tenantId = uuidv4();
        const userId = uuidv4();

        // ── Step 1: Create Cognito user ───────────────────────────────────
        const signUpCommand = new SignUpCommand({
            ClientId: cognitoConfig.clientId,
            Username: input.email,
            Password: input.password,
            UserAttributes: [
                { Name: 'email', Value: input.email },
                { Name: 'custom:tenant_id', Value: tenantId },
                { Name: 'custom:role', Value: UserRole.OWNER },
                { Name: 'custom:business_type', Value: input.businessType },
            ],
        });

        const cognitoResult = await cognitoClient.send(signUpCommand);
        const cognitoSub = cognitoResult.UserSub!;

        // ── Step 2: Create tenant in PostgreSQL (transaction) ─────────────
        const client = await db.connect();
        try {
            await client.query('BEGIN');

            // Create tenant (business)
            await client.query(
                `INSERT INTO tenants (id, name, business_type, subscription_plan, settings)
         VALUES ($1, $2, $3, $4, $5)`,
                [
                    tenantId,
                    input.businessName,
                    input.businessType,
                    SubscriptionPlan.FREE,
                    JSON.stringify({
                        currency: 'INR',
                        timezone: 'Asia/Kolkata',
                        fiscalYearStart: 4,
                        enableGst: true,
                        enableMultiCurrency: false,
                    }),
                ]
            );

            // Create user linked to tenant
            await client.query(
                `INSERT INTO users (id, tenant_id, cognito_sub, email, full_name, phone, role)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                [
                    userId,
                    tenantId,
                    cognitoSub,
                    input.email,
                    input.fullName || null,
                    input.phone || null,
                    UserRole.OWNER,
                ]
            );

            await client.query('COMMIT');
        } catch (err) {
            await client.query('ROLLBACK');
            // TODO: Clean up the Cognito user if DB creation fails
            logger.error('Signup DB transaction failed', { error: (err as Error).message });
            throw err;
        } finally {
            client.release();
        }

        logger.info('Tenant registered successfully', {
            tenantId,
            userId,
            businessType: input.businessType,
        });

        return { tenantId, userId };
    }

    /**
     * Authenticate a user with email + password.
     * Returns Cognito JWT tokens (accessToken, idToken, refreshToken).
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
            AuthParameters: {
                REFRESH_TOKEN: refreshToken,
            },
        });

        const result = await cognitoClient.send(command);
        const authResult = result.AuthenticationResult!;

        return {
            accessToken: authResult.AccessToken!,
            idToken: authResult.IdToken!,
            expiresIn: authResult.ExpiresIn || 3600,
        };
    }
}
