// ============================================================================
// Lambda Handler — Authentication (Signup / Login / Refresh)
// ============================================================================
// Thin Lambda wrapper → delegates to AuthService (portable).
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { AuthService } from '../services/auth.service';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

const authService = new AuthService();

/**
 * POST /auth/signup
 * Register a new business owner + create tenant record.
 */
export async function signup(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    try {
        const body = JSON.parse(event.body || '{}');

        const { email, password, fullName, businessName, businessType, phone } = body;

        if (!email || !password || !businessName || !businessType) {
            return response.badRequest('Missing required fields: email, password, businessName, businessType');
        }

        const result = await authService.signup({
            email,
            password,
            fullName,
            businessName,
            businessType,
            phone,
        });

        logger.info('New tenant registered', { email, businessType });

        return response.success(result, 201);
    } catch (err: unknown) {
        logger.error('Signup failed', { error: (err as Error).message });

        if ((err as Error).message.includes('already exists')) {
            return response.conflict('An account with this email already exists');
        }

        return response.internalError((err as Error).message);
    }
}

/**
 * POST /auth/login
 * Authenticate user with Cognito, return tokens.
 */
export async function login(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    try {
        const body = JSON.parse(event.body || '{}');
        const { email, password } = body;

        if (!email || !password) {
            return response.badRequest('Missing required fields: email, password');
        }

        const tokens = await authService.login(email, password);

        logger.info('Login successful', { email });

        return response.success(tokens);
    } catch (err: unknown) {
        logger.error('Login failed', { error: (err as Error).message });

        if ((err as Error).message.includes('Incorrect')) {
            return response.unauthorized('Invalid email or password');
        }

        return response.unauthorized((err as Error).message);
    }
}

/**
 * POST /auth/refresh
 * Refresh an expired access token using the refresh token.
 */
export async function refresh(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
    try {
        const body = JSON.parse(event.body || '{}');
        const { refreshToken } = body;

        if (!refreshToken) {
            return response.badRequest('Missing refreshToken');
        }

        const tokens = await authService.refreshTokens(refreshToken);

        return response.success(tokens);
    } catch (err: unknown) {
        logger.error('Token refresh failed', { error: (err as Error).message });
        return response.unauthorized('Failed to refresh token');
    }
}
