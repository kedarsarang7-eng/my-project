// ============================================================================
// Search Query Handler — DynamoDB-Native Search
// ============================================================================
// Replaces the OpenSearch-based search-query.ts with DynamoDB SearchIndex.
// Same API contract, zero infrastructure cost.
//
// Endpoints:
//   GET /search?q={query}             → Global search across all entity types
//   GET /search/{entityType}?q={query} → Type-scoped search
//
// @author DukanX Engineering
// @version 2.0.0
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import {
  globalSearch,
  search,
  SearchEntityType,
} from '../search/dynamo-search-index';
import { logger } from '../utils/logger';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const MIN_QUERY_LENGTH = 2;

// Valid entity types for type-scoped search
const ENTITY_TYPE_MAP: Record<string, SearchEntityType> = {
  products: 'PRODUCT',
  customers: 'CUSTOMER',
  invoices: 'INVOICE',
  suppliers: 'SUPPLIER',
};

/**
 * Main Lambda handler for search queries.
 */
export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  const start = Date.now();

  try {
    // Extract tenant context from JWT
    const tenantId = extractTenantId(event);
    if (!tenantId) {
      return errorResponse(401, 'Unauthorized — missing tenant context');
    }

    const path = event.path || '';
    const params = event.queryStringParameters || {};
    const query = (params.q || '').trim();

    if (!query || query.length < MIN_QUERY_LENGTH) {
      return errorResponse(400, `Query must be at least ${MIN_QUERY_LENGTH} characters`);
    }

    // Truncate excessively long queries
    const safeQuery = query.substring(0, 100);
    const limit = Math.min(
      parseInt(params.limit || String(DEFAULT_LIMIT), 10) || DEFAULT_LIMIT,
      MAX_LIMIT
    );

    // Route: /search/{entityType} → type-scoped search
    const entityTypeMatch = path.match(/\/search\/([a-z]+)$/i);
    if (entityTypeMatch) {
      const entityKey = entityTypeMatch[1].toLowerCase();
      const entityType = ENTITY_TYPE_MAP[entityKey];

      if (!entityType) {
        return errorResponse(
          400,
          `Invalid entity type. Valid: ${Object.keys(ENTITY_TYPE_MAP).join(', ')}`
        );
      }

      const result = await search(safeQuery, tenantId, {
        entityType,
        limit,
        cursor: params.cursor || undefined,
      });

      return successResponse({
        entityType: entityKey,
        query: safeQuery,
        total: result.results.length,
        results: result.results,
        pagination: {
          cursor: result.cursor,
          hasMore: result.hasMore,
        },
        latencyMs: Date.now() - start,
      });
    }

    // Route: /search → global search
    const result = await globalSearch(safeQuery, tenantId, limit);

    return successResponse({
      ...result,
      query: safeQuery,
    });
  } catch (error) {
    logger.error('Search handler error', {
      error: error instanceof Error ? error.message : String(error),
      requestId: context.awsRequestId,
    });
    return errorResponse(500, 'Search failed');
  }
};

// ── Helpers ─────────────────────────────────────────────────────────────────

function extractTenantId(event: APIGatewayProxyEvent): string | null {
  try {
    const authorizer = event.requestContext?.authorizer;
    if (!authorizer) return null;

    const claims = authorizer.claims || authorizer;
    const tenantId = claims['custom:tenantId'] || claims.tenantId;
    return tenantId ? String(tenantId) : null;
  } catch {
    return null;
  }
}

function successResponse(body: unknown): APIGatewayProxyResult {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
    },
    body: JSON.stringify(body),
  };
}

function errorResponse(statusCode: number, message: string): APIGatewayProxyResult {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      error: true,
      message,
      timestamp: new Date().toISOString(),
    }),
  };
}
