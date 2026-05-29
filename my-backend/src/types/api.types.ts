// ============================================================================
// TypeScript Types — API Request / Response Contracts
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { AuthContext } from './tenant.types';

/**
 * Extended API Gateway event that includes the decoded auth context.
 * Populated by the Cognito auth middleware.
 */
export interface AuthenticatedEvent extends APIGatewayProxyEventV2 {
    auth: AuthContext;
}

/**
 * Standard API response shape.
 * All endpoints return this structure for consistency.
 *
 * Success: { status: 'success', code: 200, message: '...', data: {...} }
 * Error:   { status: 'error',   code: 400, message: '...', error: '...' }
 */
export interface ApiResponse<T = unknown> {
    status: 'success' | 'error';
    code: number;
    message: string;
    success: boolean;
    data?: T;
    error?: {
        code: string;
        message: string;
        details?: unknown;
    } | string;
    meta?: {
        page?: number;
        limit?: number;
        total?: number;
        nextCursor?: string | null;
        hasMore?: boolean;
        timestamp?: string;
    };
}

/**
 * Pagination parameters extracted from query strings.
 */
export interface PaginationParams {
    page: number;
    limit: number;
    sortBy?: string;
    sortOrder?: 'ASC' | 'DESC';
}

/**
 * Lambda handler type alias for convenience.
 */
export type LambdaHandler = (
    event: APIGatewayProxyEventV2,
    context: Context
) => Promise<APIGatewayProxyResultV2>;
