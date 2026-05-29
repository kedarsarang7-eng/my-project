import { config } from '../config/environment';
/**
 * Search Query Lambda Handler
 * 
 * Provides fast, multi-tenant search across all indexed entities.
 * Supports:
 * - Full-text search with fuzzy matching
 * - Filter by business type, date range, status
 * - Sort and pagination
 * - Suggestions/autocomplete
 * 
 * @author DukanX Engineering
 * @version 1.0.0
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { getOpenSearchClient, isOpenSearchConfigured } from '../search/opensearch-client';
import { getIndexName, SearchIndexName } from '../search/opensearch-mappings';

// Environment
const ENVIRONMENT = config.app.env || 'dev';
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;

// Valid entity types for search
const VALID_ENTITY_TYPES: SearchIndexName[] = [
  'bills',
  'customers',
  'products',
  'productBatches',
  'suppliers',
  'purchaseBills',
  'patients',
  'visits',
  'prescriptions',
  'kots',
  'menuItems',
  'ledgerEntries',
  'expenses',
  'bankTransactions',
  'deliveryChallans',
  'bookReturns',
  'preOrders',
  'serviceJobs',
  'eInvoices',
  'fuelTransactions',
];

/**
 * Main Lambda handler
 */
export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  console.log('[SearchQuery] Request received', {
    requestId: context.awsRequestId,
    path: event.path,
    httpMethod: event.httpMethod,
  });

  // Check OpenSearch configuration
  if (!isOpenSearchConfigured()) {
    return errorResponse(503, 'Search service not configured');
  }

  try {
    // Extract tenant context from JWT claims
    const tenantContext = await extractTenantContext(event);
    if (!tenantContext) {
      return errorResponse(401, 'Unauthorized - invalid tenant context');
    }

    // Route based on path and method
    const path = event.path || '';
    const method = event.httpMethod;

    if (method === 'GET' && path.match(/\/search\/suggest$/)) {
      return handleSuggestions(event, tenantContext);
    }

    if (method === 'GET' && path.match(/\/search\/([^/]+)$/)) {
      return handleSearch(event, tenantContext);
    }

    if (method === 'POST' && path.match(/\/search\/([^/]+)\/advanced$/)) {
      return handleAdvancedSearch(event, tenantContext);
    }

    return errorResponse(404, 'Not found');
  } catch (error) {
    console.error('[SearchQuery] Unhandled error:', error);
    return errorResponse(500, 'Internal server error');
  }
};

/**
 * Handle basic search request
 */
async function handleSearch(
  event: APIGatewayProxyEvent,
  tenantContext: TenantContext
): Promise<APIGatewayProxyResult> {
  const entityType = extractEntityType(event.path);
  if (!entityType || !VALID_ENTITY_TYPES.includes(entityType)) {
    return errorResponse(400, 'Invalid or unsupported entity type');
  }

  const params = parseQueryParams(event.queryStringParameters || {});
  const client = getOpenSearchClient();
  const indexName = getIndexName(entityType, ENVIRONMENT);

  try {
    // Build the search query
    const searchBody = buildSearchQuery(params, tenantContext);

    const response = await client.search({
      index: indexName,
      body: searchBody,
    });

    const hits = response.body.hits.hits;
    const total = response.body.hits.total as { value: number; relation: string };

    const results = hits.map((hit: { _id: string; _source: Record<string, unknown>; _score: number }) => ({
      id: hit._id,
      ...hit._source,
      _score: hit._score,
    }));

    return successResponse({
      entityType,
      query: params.q,
      total: total.value,
      page: params.page,
      pageSize: params.pageSize,
      results,
    });
  } catch (error) {
    console.error('[SearchQuery] Search error:', {
      entityType,
      index: indexName,
      error: error instanceof Error ? error.message : String(error),
    });
    return errorResponse(500, 'Search failed');
  }
}

/**
 * Handle advanced search with complex filters
 */
async function handleAdvancedSearch(
  event: APIGatewayProxyEvent,
  tenantContext: TenantContext
): Promise<APIGatewayProxyResult> {
  const entityType = extractEntityType(event.path);
  if (!entityType || !VALID_ENTITY_TYPES.includes(entityType)) {
    return errorResponse(400, 'Invalid or unsupported entity type');
  }

  if (!event.body) {
    return errorResponse(400, 'Request body required');
  }

  let searchRequest: AdvancedSearchRequest;
  try {
    searchRequest = JSON.parse(event.body);
  } catch {
    return errorResponse(400, 'Invalid JSON in request body');
  }

  const client = getOpenSearchClient();
  const indexName = getIndexName(entityType, ENVIRONMENT);

  try {
    const searchBody = buildAdvancedQuery(searchRequest, tenantContext);

    const response = await client.search({
      index: indexName,
      body: searchBody,
    });

    const hits = response.body.hits.hits;
    const total = response.body.hits.total as { value: number; relation: string };
    const aggregations = response.body.aggregations || {};

    const results = hits.map((hit: { _id: string; _source: Record<string, unknown>; _score: number }) => ({
      id: hit._id,
      ...hit._source,
      _score: hit._score,
    }));

    return successResponse({
      entityType,
      total: total.value,
      page: searchRequest.page || 1,
      pageSize: searchRequest.pageSize || DEFAULT_PAGE_SIZE,
      results,
      aggregations,
    });
  } catch (error) {
    console.error('[SearchQuery] Advanced search error:', {
      entityType,
      index: indexName,
      error: error instanceof Error ? error.message : String(error),
    });
    return errorResponse(500, 'Advanced search failed');
  }
}

/**
 * Handle autocomplete suggestions
 */
async function handleSuggestions(
  event: APIGatewayProxyEvent,
  tenantContext: TenantContext
): Promise<APIGatewayProxyResult> {
  const params = event.queryStringParameters || {};
  const query = params.q || '';
  const entityType = params.entity as SearchIndexName | undefined;

  if (!query || query.length < 2) {
    return successResponse({ suggestions: [] });
  }

  const client = getOpenSearchClient();

  // If entity type specified, search that index only
  const indices = entityType && VALID_ENTITY_TYPES.includes(entityType)
    ? [getIndexName(entityType, ENVIRONMENT)]
    : VALID_ENTITY_TYPES.map(et => getIndexName(et, ENVIRONMENT));

  try {
    const suggestBody = {
      size: 0,
      query: {
        bool: {
          must: [
            buildMultiMatchQuery(query),
            { term: { tenantId: tenantContext.tenantId } },
          ],
        },
      },
      suggest: {
        text: query,
        name_suggest: {
          completion: {
            field: 'name.edge',
            fuzzy: { fuzziness: 'AUTO' },
            size: 10,
          },
        },
      },
    };

    // If businessId filter applies
    if (tenantContext.businessId) {
      (suggestBody.query.bool.must as unknown[]).push(
        { term: { businessId: tenantContext.businessId } }
      );
    }

    const response = await client.search({
      index: indices.join(','),
      body: suggestBody,
    });

    // Extract suggestions from results
    const suggestions: Suggestion[] = [];
    const seen = new Set<string>();

    const hits = response.body.hits.hits;
    for (const hit of hits.slice(0, 10)) {
      const source = hit._source as Record<string, unknown>;
      const text = source.name || source.customerName || source.productName || 
                   source.patientName || source.supplierName;
      
      if (text && typeof text === 'string' && !seen.has(text)) {
        seen.add(text);
        suggestions.push({
          text,
          type: hit._index?.replace(`${ENVIRONMENT}-dukanx-`, ''),
          id: hit._id,
          highlight: generateHighlight(source, query),
        });
      }
    }

    return successResponse({ suggestions });
  } catch (error) {
    console.error('[SearchQuery] Suggestions error:', error);
    return errorResponse(500, 'Suggestions failed');
  }
}

// ============================================================================
// QUERY BUILDERS
// ============================================================================

function buildSearchQuery(params: SearchParams, tenantContext: TenantContext): Record<string, unknown> {
  const must: unknown[] = [
    { term: { tenantId: tenantContext.tenantId } },
  ];

  // Business filter
  if (tenantContext.businessId) {
    must.push({ term: { businessId: tenantContext.businessId } });
  }

  // Business type filter
  if (params.businessType) {
    must.push({ term: { businessType: params.businessType } });
  }

  // Date range filter
  if (params.dateFrom || params.dateTo) {
    const dateRange: Record<string, string> = {};
    if (params.dateFrom) dateRange.gte = params.dateFrom;
    if (params.dateTo) dateRange.lte = params.dateTo;
    
    // Determine date field based on entity type
    const dateField = params.dateField || 'createdAt';
    must.push({ range: { [dateField]: dateRange } });
  }

  // Status filter
  if (params.status) {
    must.push({ terms: { status: params.status.split(',') } });
  }

  // Amount range
  if (params.minAmount !== undefined || params.maxAmount !== undefined) {
    const amountRange: Record<string, number> = {};
    if (params.minAmount !== undefined) amountRange.gte = params.minAmount;
    if (params.maxAmount !== undefined) amountRange.lte = params.maxAmount;
    must.push({ range: { grandTotal: amountRange } });
  }

  // Search query
  if (params.q) {
    must.push(buildMultiMatchQuery(params.q));
  }

  // Build final query
  const query: Record<string, unknown> = {
    bool: {
      must,
      must_not: [
        { exists: { field: 'deletedAt' } }, // Exclude soft-deleted
      ],
    },
  };

  return {
    from: (params.page - 1) * params.pageSize,
    size: params.pageSize,
    query,
    sort: buildSort(params.sortBy, params.sortOrder),
    highlight: {
      fields: {
        name: {},
        customerName: {},
        productName: {},
        patientName: {},
        supplierName: {},
        description: {},
      },
      pre_tags: ['<mark>'],
      post_tags: ['</mark>'],
    },
  };
}

function buildAdvancedSearch(
  request: AdvancedSearchRequest,
  tenantContext: TenantContext
): Record<string, unknown> {
  const must: unknown[] = [
    { term: { tenantId: tenantContext.tenantId } },
  ];

  if (tenantContext.businessId) {
    must.push({ term: { businessId: tenantContext.businessId } });
  }

  // Apply filters
  if (request.filters) {
    for (const [field, value] of Object.entries(request.filters)) {
      if (Array.isArray(value)) {
        must.push({ terms: { [field]: value } });
      } else if (typeof value === 'object' && value !== null) {
        // Range filter
        must.push({ range: { [field]: value } });
      } else {
        must.push({ term: { [field]: value } });
      }
    }
  }

  // Full-text search
  if (request.query) {
    must.push(buildMultiMatchQuery(request.query));
  }

  const query: Record<string, unknown> = {
    bool: {
      must,
      must_not: [
        { exists: { field: 'deletedAt' } },
      ],
    },
  };

  const body: Record<string, unknown> = {
    from: ((request.page || 1) - 1) * (request.pageSize || DEFAULT_PAGE_SIZE),
    size: request.pageSize || DEFAULT_PAGE_SIZE,
    query,
    sort: buildSort(request.sortBy, request.sortOrder),
  };

  // Add aggregations if requested
  if (request.aggregations) {
    body.aggs = buildAggregations(request.aggregations);
  }

  return body;
}

function buildMultiMatchQuery(query: string): Record<string, unknown> {
  return {
    multi_match: {
      query,
      fields: [
        'name^3',
        'name.ngram^2',
        'customerName^3',
        'productName^3',
        'patientName^3',
        'supplierName^3',
        'invoiceNumber^2',
        'billNumber^2',
        'phone^2',
        'email^2',
        'sku',
        'barcode',
        'gstin',
        'vehicleNumber',
        'description',
        'itemNames',
        'medicines',
        'diagnosis',
        'chiefComplaint',
        'address',
        'irn',
      ],
      type: 'best_fields',
      fuzziness: 'AUTO',
      prefix_length: 1,
      operator: 'or',
    },
  };
}

function buildAdvancedQuery(
  request: AdvancedSearchRequest,
  tenantContext: TenantContext
): Record<string, unknown> {
  const must: unknown[] = [
    { term: { tenantId: tenantContext.tenantId } },
  ];

  if (tenantContext.businessId) {
    must.push({ term: { businessId: tenantContext.businessId } });
  }

  // Apply dynamic filters
  if (request.filters) {
    for (const [field, filter] of Object.entries(request.filters)) {
      if (filter.eq !== undefined) {
        must.push({ term: { [field]: filter.eq } });
      }
      if (filter.in !== undefined && Array.isArray(filter.in)) {
        must.push({ terms: { [field]: filter.in } });
      }
      if (filter.range !== undefined) {
        must.push({ range: { [field]: filter.range } });
      }
      if (filter.match !== undefined) {
        must.push({ match: { [field]: filter.match } });
      }
      if (filter.exists !== undefined) {
        if (filter.exists) {
          must.push({ exists: { field } });
        } else {
          must.push({ bool: { must_not: { exists: { field } } } });
        }
      }
    }
  }

  // Full-text query
  if (request.query) {
    must.push(buildMultiMatchQuery(request.query));
  }

  const query: Record<string, unknown> = {
    bool: {
      must,
      must_not: [
        { exists: { field: 'deletedAt' } },
      ],
    },
  };

  const body: Record<string, unknown> = {
    from: ((request.page || 1) - 1) * (request.pageSize || DEFAULT_PAGE_SIZE),
    size: request.pageSize || DEFAULT_PAGE_SIZE,
    query,
    sort: buildSort(request.sortBy, request.sortOrder),
    highlight: {
      fields: {
        name: {},
        customerName: {},
        productName: {},
        description: {},
      },
      pre_tags: ['<mark>'],
      post_tags: ['</mark>'],
    },
  };

  // Add aggregations
  if (request.aggregations) {
    body.aggs = request.aggregations;
  }

  // Add source filtering
  if (request.fields) {
    body._source = request.fields;
  }

  return body;
}

function buildSort(sortBy?: string, sortOrder: 'asc' | 'desc' = 'desc'): unknown[] {
  const sorts: unknown[] = [];

  if (sortBy) {
    sorts.push({ [sortBy]: { order: sortOrder } });
  } else {
    // Default sort by relevance (_score) then date
    sorts.push({ _score: { order: 'desc' } });
  }

  // Always add createdAt as tiebreaker
  sorts.push({ createdAt: { order: 'desc' } });

  return sorts;
}

function buildAggregations(aggConfig: Record<string, unknown>): Record<string, unknown> {
  const aggs: Record<string, unknown> = {};

  for (const [name, config] of Object.entries(aggConfig)) {
    if (typeof config === 'string') {
      // Simple field aggregation
      aggs[name] = {
        terms: { field: config, size: 50 },
      };
    } else if (typeof config === 'object' && config !== null) {
      aggs[name] = config;
    }
  }

  return aggs;
}

// ============================================================================
// HELPERS
// ============================================================================

interface TenantContext {
  tenantId: string;
  businessId?: string;
  userId: string;
  role: string;
}

interface SearchParams {
  q: string;
  page: number;
  pageSize: number;
  sortBy?: string;
  sortOrder: 'asc' | 'desc';
  businessType?: string;
  status?: string;
  dateFrom?: string;
  dateTo?: string;
  dateField?: string;
  minAmount?: number;
  maxAmount?: number;
}

interface FilterConfig {
  eq?: unknown;
  in?: unknown[];
  range?: { gte?: number | string; lte?: number | string; gt?: number | string; lt?: number | string };
  match?: string;
  exists?: boolean;
}

interface AdvancedSearchRequest {
  query?: string;
  filters?: Record<string, FilterConfig>;
  page?: number;
  pageSize?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  aggregations?: Record<string, unknown>;
  fields?: string[];
}

interface Suggestion {
  text: string;
  type: string;
  id: string;
  highlight?: string;
}

async function extractTenantContext(event: APIGatewayProxyEvent): Promise<TenantContext | null> {
  try {
    // Extract from JWT claims (Cognito authorizer)
    const requestContext = event.requestContext;
    const authorizer = requestContext?.authorizer;
    
    if (!authorizer) {
      console.warn('[SearchQuery] No authorizer context');
      return null;
    }

    const claims = authorizer.claims || authorizer;
    const tenantId = claims['custom:tenantId'] || claims.tenantId;
    const userId = claims.sub || claims.userId;
    const role = claims['custom:role'] || claims.role || 'user';

    if (!tenantId || !userId) {
      console.warn('[SearchQuery] Missing tenantId or userId in claims');
      return null;
    }

    // Extract businessId from headers (Flutter app sends this)
    const businessId = event.headers['x-business-id'] || 
                       event.headers['X-Business-Id'] ||
                       claims['custom:businessId'];

    return {
      tenantId: String(tenantId),
      businessId: businessId ? String(businessId) : undefined,
      userId: String(userId),
      role: String(role),
    };
  } catch (error) {
    console.error('[SearchQuery] Error extracting tenant context:', error);
    return null;
  }
}

function parseQueryParams(params: Record<string, string | undefined>): SearchParams {
  const page = parseInt(params.page || '1', 10);
  const pageSize = Math.min(
    parseInt(params.pageSize || String(DEFAULT_PAGE_SIZE), 10),
    MAX_PAGE_SIZE
  );

  return {
    q: params.q || '',
    page: isNaN(page) || page < 1 ? 1 : page,
    pageSize: isNaN(pageSize) || pageSize < 1 ? DEFAULT_PAGE_SIZE : pageSize,
    sortBy: params.sortBy,
    sortOrder: (params.sortOrder as 'asc' | 'desc') || 'desc',
    businessType: params.businessType,
    status: params.status,
    dateFrom: params.dateFrom,
    dateTo: params.dateTo,
    dateField: params.dateField,
    minAmount: params.minAmount ? parseFloat(params.minAmount) : undefined,
    maxAmount: params.maxAmount ? parseFloat(params.maxAmount) : undefined,
  };
}

function extractEntityType(path: string | undefined): SearchIndexName | null {
  if (!path) return null;
  
  const match = path.match(/\/search\/([^/]+)/);
  if (!match) return null;
  
  const entityType = match[1] as SearchIndexName;
  return VALID_ENTITY_TYPES.includes(entityType) ? entityType : null;
}

function generateHighlight(source: Record<string, unknown>, query: string): string | undefined {
  // Generate a short context snippet with the matching term
  const fieldsToCheck = ['name', 'customerName', 'productName', 'description'];
  
  for (const field of fieldsToCheck) {
    const value = source[field];
    if (value && typeof value === 'string') {
      const lowerValue = value.toLowerCase();
      const lowerQuery = query.toLowerCase();
      
      const index = lowerValue.indexOf(lowerQuery);
      if (index !== -1) {
        // Extract context around the match
        const start = Math.max(0, index - 20);
        const end = Math.min(value.length, index + query.length + 20);
        let snippet = value.substring(start, end);
        
        if (start > 0) snippet = '...' + snippet;
        if (end < value.length) snippet = snippet + '...';
        
        return snippet;
      }
    }
  }
  
  return undefined;
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
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      error: true,
      message,
      timestamp: new Date().toISOString(),
    }),
  };
}
