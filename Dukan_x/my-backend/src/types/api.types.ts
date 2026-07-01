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
 */
export interface ApiResponse<T = unknown> {
    success: boolean;
    data?: T;
    error?: {
        code: string;
        message: string;
        details?: unknown;
    };
    meta?: {
        page?: number;
        limit?: number;
        total?: number;
        timestamp: string;
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
