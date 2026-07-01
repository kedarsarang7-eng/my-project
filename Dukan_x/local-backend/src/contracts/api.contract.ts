// ============================================================================
// API Response Contract — mirrors my-backend/src/types/api.types.ts
// ============================================================================
// The Local_Backend MUST expose the SAME contracts the AWS backend exposes
// (Requirement 3.2). This file re-declares the AWS `ApiResponse` envelope
// shape verbatim so the Flutter repository layer cannot tell the two backends
// apart. It is a transport-agnostic shape, intentionally duplicated here
// rather than imported, because the packaged backend ships independently of
// the AWS Lambda bundle.
// ============================================================================

/**
 * Standard API response shape — identical to the AWS backend envelope.
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
    error?:
        | {
              code: string;
              message: string;
              details?: unknown;
          }
        | string;
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
 * Pagination parameters extracted from query strings — mirrors the AWS shape.
 */
export interface PaginationParams {
    page: number;
    limit: number;
    sortBy?: string;
    sortOrder?: 'ASC' | 'DESC';
}
