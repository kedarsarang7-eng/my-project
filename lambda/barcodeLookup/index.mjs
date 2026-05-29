// ============================================================================
// BARCODE LOOKUP LAMBDA
// ============================================================================
// Purpose: O(1) barcode → product lookup with strict tenant isolation
// Performance Target: <100ms p99 latency (DynamoDB GSI query)
//
// Security: 
// - Validates Cognito JWT
// - Extracts tenantId from custom:tenantId claim
// - Never allows cross-tenant barcode lookups
// - All responses scoped to requesting tenant only
//
// Input:  { barcode: string, businessId?: string }
// Output: { success: boolean, product?: Product, error?: ErrorDetail }
//
// Error Codes:
// - BARCODE_NOT_FOUND: Product doesn't exist in tenant's inventory
// - INVALID_BARCODE: Barcode format validation failed
// - TENANT_MISMATCH: Authorization error (403)
// - RATE_LIMITED: Too many requests (429)
// ============================================================================

import { success, error, verifyToken, getItem, queryItems } from '../shared/utils.mjs';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';

// Initialize DynamoDB client outside handler for connection reuse
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
  unmarshallOptions: { wrapNumbers: false },
});

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'DukanX';

// ============================================================================
// BARCODE VALIDATION
// ============================================================================

const BARCODE_PATTERNS = {
  // EAN-13: 13 digits, last is check digit
  EAN13: /^\d{13}$/,
  // EAN-8: 8 digits, last is check digit
  EAN8: /^\d{8}$/,
  // UPC-A: 12 digits
  UPCA: /^\d{12}$/,
  // Code-128: Alphanumeric, variable length (used internally)
  CODE128: /^[A-Za-z0-9\-_]{6,48}$/,
  // ISBN-13 (books): 13 digits starting with 978 or 979
  ISBN13: /^(978|979)\d{10}$/,
};

/**
 * Validate barcode format with check digit verification for EAN
 * @param {string} barcode - Raw barcode string
 * @returns {{ valid: boolean, format?: string, error?: string }}
 */
function validateBarcode(barcode) {
  if (!barcode || typeof barcode !== 'string') {
    return { valid: false, error: 'BARCODE_EMPTY' };
  }

  const trimmed = barcode.trim();
  
  if (trimmed.length === 0) {
    return { valid: false, error: 'BARCODE_EMPTY' };
  }

  if (trimmed.length > 48) {
    return { valid: false, error: 'BARCODE_TOO_LONG' };
  }

  // Check against patterns
  for (const [format, pattern] of Object.entries(BARCODE_PATTERNS)) {
    if (pattern.test(trimmed)) {
      // Verify EAN-13 check digit
      if (format === 'EAN13' && !verifyEan13CheckDigit(trimmed)) {
        return { valid: false, error: 'INVALID_CHECK_DIGIT', format: 'EAN13' };
      }
      
      // Verify EAN-8 check digit
      if (format === 'EAN8' && !verifyEan8CheckDigit(trimmed)) {
        return { valid: false, error: 'INVALID_CHECK_DIGIT', format: 'EAN8' };
      }

      return { valid: true, format };
    }
  }

  // If no specific format matched but it's alphanumeric, accept as generic
  if (/^[A-Za-z0-9\-_]+$/.test(trimmed)) {
    return { valid: true, format: 'GENERIC' };
  }

  return { valid: false, error: 'INVALID_FORMAT' };
}

/**
 * Verify EAN-13 check digit (Modulo 10)
 * @param {string} ean - 13-digit EAN
 * @returns {boolean}
 */
function verifyEan13CheckDigit(ean) {
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    const digit = parseInt(ean[i], 10);
    sum += (i % 2 === 0) ? digit : digit * 3;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit === parseInt(ean[12], 10);
}

/**
 * Verify EAN-8 check digit (Modulo 10)
 * @param {string} ean - 8-digit EAN
 * @returns {boolean}
 */
function verifyEan8CheckDigit(ean) {
  let sum = 0;
  for (let i = 0; i < 7; i++) {
    const digit = parseInt(ean[i], 10);
    sum += (i % 2 === 0) ? digit * 3 : digit;
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit === parseInt(ean[7], 10);
}

// ============================================================================
// DYNAMODB QUERIES
// ============================================================================

/**
 * Query product by barcode using GSI3 (BarcodeIndex)
 * Tenant-scoped: PK = TENANT#{tenantId}#BARCODE#{barcode}
 * 
 * @param {string} tenantId - Tenant ID from JWT
 * @param {string} barcode - Sanitized barcode
 * @param {string} [businessId] - Optional business scoping
 * @returns {Promise<object|null>} Product or null
 */
async function getProductByBarcode(tenantId, barcode, businessId = null) {
  const pk = `TENANT#${tenantId}`;
  const sk = `BARCODE#${barcode}`;

  // Query GSI3 for barcode lookup
  const params = {
    TableName: TABLE_NAME,
    IndexName: 'GSI3',
    KeyConditionExpression: 'GSI3PK = :gsi3pk AND GSI3SK = :gsi3sk',
    ExpressionAttributeValues: {
      ':gsi3pk': pk,
      ':gsi3sk': sk,
      ':false': false,
    },
    FilterExpression: 'attribute_not_exists(isDeleted) OR isDeleted = :false',
    Limit: 1,
  };

  // If businessId provided, add business scoping filter
  if (businessId) {
    params.ExpressionAttributeValues[':businessId'] = businessId;
    params.FilterExpression = '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(businessId) OR businessId = :businessId)';
  }

  const result = await docClient.send(new QueryCommand(params));
  
  if (!result.Items || result.Items.length === 0) {
    return null;
  }

  const item = result.Items[0];
  
  // Map DynamoDB item to clean product object
  return mapProductFromDynamoDB(item);
}

/**
 * Map DynamoDB item to product response
 * @param {object} item - DynamoDB item
 * @returns {object} Clean product object
 */
function mapProductFromDynamoDB(item) {
  return {
    id: item.id,
    tenantId: item.tenantId,
    businessId: item.businessId || null,
    productType: item.productType || 'general',
    name: item.name,
    displayName: item.displayName || null,
    sku: item.sku || null,
    barcode: item.barcode || null,
    altBarcodes: item.altBarcodes || [],
    category: item.category || null,
    subcategory: item.subcategory || null,
    brand: item.brand || null,
    hsnCode: item.hsnCode || null,
    unit: item.unit || 'pcs',
    // Prices in cents for precision
    salePriceCents: item.salePriceCents || 0,
    purchasePriceCents: item.purchasePriceCents || null,
    mrpCents: item.mrpCents || null,
    wholesalePriceCents: item.wholesalePriceCents || null,
    // Tax rates in basis points (e.g., 1800 = 18%)
    cgstRateBp: item.cgstRateBp || 0,
    sgstRateBp: item.sgstRateBp || 0,
    igstRateBp: item.igstRateBp || 0,
    // Stock
    currentStock: item.currentStock || 0,
    lowStockThreshold: item.lowStockThreshold || 5,
    reorderQty: item.reorderQty || null,
    // Attributes (business-type specific)
    attributes: item.attributes || {},
    // Status
    isActive: item.isActive !== false,
    isArchived: item.isArchived || false,
    // Media
    imageUrl: item.imageUrl || null,
    // Pharmacy-specific fields
    batchNumber: item.batchNumber || null,
    expiryDate: item.expiryDate || null,
    drugSchedule: item.drugSchedule || null,
    // Electronics-specific
    imei: item.imei || null,
    serialNumber: item.serialNumber || null,
    warrantyMonths: item.warrantyMonths || null,
    // Clothing-specific
    size: item.size || null,
    color: item.color || null,
    // Jewelry-specific
    purity: item.purity || null,
    metalWeight: item.metalWeight || null,
    makingCharges: item.makingCharges || null,
    hallmark: item.hallmark || null,
    // Book-specific
    isbn: item.isbn || null,
    author: item.author || null,
    publisher: item.publisher || null,
    // Metadata
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

export async function handler(event) {
  const startTime = Date.now();
  const requestId = event.requestContext?.requestId || crypto.randomUUID();

  try {
    // ------------------------------------------------------------------------
    // AUTHENTICATION
    // ------------------------------------------------------------------------
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401, requestId);
    }

    const token = authHeader.substring(7);
    let decoded;
    
    try {
      decoded = await verifyToken(token);
    } catch (err) {
      return error('Invalid or expired token', 401, requestId);
    }

    const tenantId = decoded.tenantId;
    const userId = decoded.sub;
    
    if (!tenantId) {
      return error('Tenant ID not found in token', 403, requestId);
    }

    // ------------------------------------------------------------------------
    // REQUEST PARSING
    // ------------------------------------------------------------------------
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (err) {
      return error('Invalid JSON in request body', 400, requestId);
    }

    const { barcode, businessId, includeInactive = false } = body;

    if (!barcode) {
      return error('barcode is required', 400, requestId);
    }

    // ------------------------------------------------------------------------
    // BARCODE VALIDATION
    // ------------------------------------------------------------------------
    const validation = validateBarcode(barcode);
    
    if (!validation.valid) {
      return success({
        success: false,
        error: {
          code: 'INVALID_BARCODE',
          message: `Barcode validation failed: ${validation.error}`,
          details: { barcode, format: validation.format },
        },
      }, 400);
    }

    const sanitizedBarcode = barcode.trim();

    // ------------------------------------------------------------------------
    // PRODUCT LOOKUP (O(1) via GSI3)
    // ------------------------------------------------------------------------
    const product = await getProductByBarcode(tenantId, sanitizedBarcode, businessId);

    if (!product) {
      // Log for analytics (non-blocking)
      console.log(JSON.stringify({
        level: 'INFO',
        requestId,
        tenantId,
        action: 'BARCODE_NOT_FOUND',
        barcode: sanitizedBarcode,
        latencyMs: Date.now() - startTime,
      }));

      return success({
        success: false,
        error: {
          code: 'BARCODE_NOT_FOUND',
          message: `No product found for barcode: ${sanitizedBarcode}`,
          details: { barcode: sanitizedBarcode, tenantId },
        },
      }, 404);
    }

    // Check if product is active (unless explicitly including inactive)
    if (!includeInactive && !product.isActive) {
      return success({
        success: false,
        error: {
          code: 'PRODUCT_INACTIVE',
          message: `Product '${product.name}' is currently inactive`,
          details: { barcode: sanitizedBarcode, productId: product.id },
        },
      }, 409);
    }

    // Check for low stock warning
    const isLowStock = product.currentStock <= product.lowStockThreshold;

    // Check for expiry warning (pharmacy)
    let expiryWarning = null;
    if (product.expiryDate) {
      const expiry = new Date(product.expiryDate);
      const today = new Date();
      const daysUntilExpiry = Math.floor((expiry - today) / (1000 * 60 * 60 * 24));
      
      if (daysUntilExpiry < 0) {
        expiryWarning = { level: 'CRITICAL', message: 'Product expired', days: daysUntilExpiry };
      } else if (daysUntilExpiry <= 30) {
        expiryWarning = { level: 'WARNING', message: 'Expiring soon', days: daysUntilExpiry };
      }
    }

    // BUG-028: BLOCK expired pharmacy products at backend
    // Safety issue: Prevent expired medicines from being sold via API bypass
    const isPharmacyProduct = product.drugSchedule || product.batchNumber;
    if (isPharmacyProduct && expiryWarning?.level === 'CRITICAL') {
      // Audit log the blocked attempt (compliance requirement)
      console.log(JSON.stringify({
        level: 'WARN',
        requestId,
        tenantId,
        userId,
        action: 'EXPIRED_PHARMACY_PRODUCT_BLOCKED',
        barcode: sanitizedBarcode,
        productId: product.id,
        productName: product.name,
        expiryDate: product.expiryDate,
        reason: 'Attempted to look up expired pharmacy product',
      }));

      return success({
        success: false,
        error: {
          code: 'PRODUCT_EXPIRED',
          message: `MEDICINE EXPIRED: '${product.name}' expired on ${product.expiryDate}. Sale of expired medicines is prohibited by law.`,
          details: { 
            barcode: sanitizedBarcode, 
            productId: product.id,
            productName: product.name,
            expiryDate: product.expiryDate,
            expiredDays: Math.abs(expiryWarning.days),
            drugSchedule: product.drugSchedule,
            batchNumber: product.batchNumber,
          },
        },
      }, 403); // 403 Forbidden - regulatory compliance
    }

    // ------------------------------------------------------------------------
    // AUDIT LOGGING (async, non-blocking)
    // ------------------------------------------------------------------------
    // Log successful lookup for analytics
    console.log(JSON.stringify({
      level: 'INFO',
      requestId,
      tenantId,
      userId,
      action: 'BARCODE_LOOKUP_SUCCESS',
      barcode: sanitizedBarcode,
      productId: product.id,
      latencyMs: Date.now() - startTime,
    }));

    // ------------------------------------------------------------------------
    // SUCCESS RESPONSE
    // ------------------------------------------------------------------------
    return success({
      success: true,
      product,
      metadata: {
        barcodeFormat: validation.format,
        isLowStock,
        expiryWarning,
        latencyMs: Date.now() - startTime,
      },
    });

  } catch (err) {
    console.error(JSON.stringify({
      level: 'ERROR',
      requestId,
      error: err.message,
      stack: err.stack,
      latencyMs: Date.now() - startTime,
    }));

    return error(
      'Internal server error',
      500,
      requestId
    );
  }
}

// ============================================================================
// BULK LOOKUP (for offline sync)
// POST /barcode/bulk-lookup
// ============================================================================

export async function bulkLookupHandler(event) {
  const requestId = event.requestContext?.requestId || crypto.randomUUID();

  try {
    // Authenticate
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401, requestId);
    }

    const decoded = await verifyToken(authHeader.substring(7));
    const tenantId = decoded.tenantId;

    if (!tenantId) {
      return error('Tenant ID not found in token', 403, requestId);
    }

    // Parse request
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (err) {
      return error('Invalid JSON', 400, requestId);
    }

    const { barcodes, businessId } = body;

    if (!Array.isArray(barcodes) || barcodes.length === 0) {
      return error('barcodes array is required', 400, requestId);
    }

    if (barcodes.length > 100) {
      return error('Maximum 100 barcodes per request', 400, requestId);
    }

    // Validate all barcodes
    const validatedBarcodes = barcodes
      .map(b => ({ raw: b, validation: validateBarcode(b) }))
      .filter(b => b.validation.valid);

    // Parallel lookup (limited concurrency)
    const CONCURRENCY = 10;
    const results = [];
    
    for (let i = 0; i < validatedBarcodes.length; i += CONCURRENCY) {
      const batch = validatedBarcodes.slice(i, i + CONCURRENCY);
      const batchResults = await Promise.all(
        batch.map(async ({ raw, validation }) => {
          const product = await getProductByBarcode(tenantId, raw.trim(), businessId);
          return {
            barcode: raw,
            barcodeFormat: validation.format,
            found: !!product,
            product,
          };
        })
      );
      results.push(...batchResults);
    }

    return success({
      success: true,
      results,
      summary: {
        total: barcodes.length,
        valid: validatedBarcodes.length,
        found: results.filter(r => r.found).length,
        notFound: results.filter(r => !r.found).length,
      },
    });

  } catch (err) {
    console.error(JSON.stringify({
      level: 'ERROR',
      requestId,
      error: err.message,
      stack: err.stack,
    }));

    return error('Internal server error', 500, requestId);
  }
}
