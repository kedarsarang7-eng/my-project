// ============================================================================
// STORAGE HANDLER — S3 Presigned URL Generator
// ============================================================================
// Provides presigned URLs for direct client-to-S3 uploads/downloads.
// All keys are tenant-scoped to prevent cross-tenant data leaks.
//
// Endpoints:
//   POST   /storage/presign      → Generate presigned PUT URL for upload
//   GET    /storage/url/{key}    → Generate presigned GET URL for download
//   DELETE /storage/{key}        → Delete object from S3
//   GET    /storage/list         → List objects by prefix
// ============================================================================

import {
  success,
  error,
  verifyToken,
} from '../shared/utils.mjs';

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
} from '@aws-sdk/client-s3';

import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({});
const BUCKET = process.env.S3_BUCKET_NAME || process.env.AWS_S3_BUCKET_NAME;

// MAX_SIZES removed — replaced by MIME_ROUTE_MAP below which includes both
// folder routing and max sizes per mime type

// Allowed key prefixes (folder names) — ENFORCED, not advisory
const ALLOWED_PREFIXES = [
  'products', 'ocr', 'audio', 'expenses', 'backups',
  'invoices', 'avatars', 'prescriptions', 'menu', 'marketing',
];

// Auto-routing map: mime type → default folder + max size
// Used when the client sends a key WITHOUT a prefix folder
const MIME_ROUTE_MAP = {
  'image/jpeg':  { folder: 'products',  maxBytes: 10 * 1024 * 1024 },
  'image/png':   { folder: 'products',  maxBytes: 10 * 1024 * 1024 },
  'image/webp':  { folder: 'products',  maxBytes: 10 * 1024 * 1024 },
  'audio/webm':  { folder: 'audio',     maxBytes: 50 * 1024 * 1024 },
  'audio/mp4':   { folder: 'audio',     maxBytes: 50 * 1024 * 1024 },
  'audio/wav':   { folder: 'audio',     maxBytes: 50 * 1024 * 1024 },
  'application/pdf':            { folder: 'invoices', maxBytes: 20 * 1024 * 1024 },
  'application/octet-stream':   { folder: 'backups',  maxBytes: 100 * 1024 * 1024 },
};

// Context hint → folder override (client can pass `context` in presign body)
const CONTEXT_FOLDER_MAP = {
  'ocr':           'ocr',
  'scan':          'ocr',
  'bill_scan':     'ocr',
  'voice':         'audio',
  'stt':           'audio',
  'receipt':       'expenses',
  'expense':       'expenses',
  'backup':        'backups',
  'invoice':       'invoices',
  'pdf':           'invoices',
  'avatar':        'avatars',
  'profile':       'avatars',
  'prescription':  'prescriptions',
  'menu':          'menu',
  'food':          'menu',
  'campaign':      'marketing',
  'product':       'products',
};

/**
 * Validate and sanitize the S3 key.
 * Ensures tenant scoping and prevents path traversal.
 */
function validateKey(key, tenantId) {
  // Remove leading slashes
  const cleaned = key.replace(/^\/+/, '');

  // Prevent path traversal
  if (cleaned.includes('..') || cleaned.includes('//')) {
    throw new Error('Invalid key: path traversal detected');
  }

  // If key already starts with tenantId, use as-is
  if (cleaned.startsWith(`${tenantId}/`)) {
    return cleaned;
  }

  // Otherwise, prefix with tenantId for isolation
  return `${tenantId}/${cleaned}`;
}

/**
 * Extract the folder prefix from a tenant-scoped key.
 * Key format: {tenantId}/{folder}/{filename}
 * Returns the folder segment (e.g., 'products', 'ocr')
 */
function getKeyFolder(key) {
  const parts = key.split('/');
  // Expected: {tenantId}/{folder}/{filename...}
  return parts.length >= 3 ? parts[1] : null;
}

/**
 * Determine the correct folder for a file based on:
 * 1. Explicit folder in key  (highest priority)
 * 2. Context hint from client (e.g., 'ocr', 'backup')
 * 3. Mime type auto-routing   (fallback)
 */
function resolveFolder(key, mimeType, context) {
  // Check if key already has a valid folder prefix
  const parts = key.split('/');
  if (parts.length >= 2) {
    const maybeFolder = parts[0]; // Before tenantId is prepended
    if (ALLOWED_PREFIXES.includes(maybeFolder)) {
      return maybeFolder;
    }
  }

  // Check context hint
  if (context) {
    const ctx = context.toLowerCase().trim();
    if (CONTEXT_FOLDER_MAP[ctx]) {
      return CONTEXT_FOLDER_MAP[ctx];
    }
  }

  // Fall back to mime type routing
  const route = MIME_ROUTE_MAP[mimeType];
  return route ? route.folder : null;
}

// ============================================================================
// POST /storage/presign — Generate presigned PUT URL
// ============================================================================
// Request body:
// {
//   "key": "product_abc.jpg",           // filename (folder auto-resolved)
//   "mimeType": "image/jpeg",           // required
//   "context": "ocr",                   // optional: hint for folder routing
//   "folder": "products",               // optional: explicit folder override
//   "operation": "putObject"             // optional: default putObject
// }
//
// Bucket structure enforced:
//   {tenantId}/{folder}/{key}
//
// Example resolved keys:
//   tenant_123/products/product_abc.jpg
//   tenant_123/ocr/scan_20260531.jpg
//   tenant_123/backups/2026-05-31_backup.enc
// ============================================================================
async function handlePresign(event, tenantId) {
  const body = JSON.parse(event.body || '{}');
  const key = body.key || body.fileName;
  const mimeType = body.mimeType || body.contentType;
  const { context, folder, operation } = body;

  if (!key || !mimeType) {
    return error('key and mimeType are required', 400);
  }

  // Validate mime type
  const route = MIME_ROUTE_MAP[mimeType];
  if (!route) {
    return error(`Unsupported mime type: ${mimeType}. Allowed: ${Object.keys(MIME_ROUTE_MAP).join(', ')}`, 400);
  }

  // Resolve folder — explicit > context > mime auto-route
  const targetFolder = folder || resolveFolder(key, mimeType, context);
  if (!targetFolder) {
    return error('Cannot determine storage folder. Provide folder or context parameter.', 400);
  }

  // Enforce allowed prefixes
  if (!ALLOWED_PREFIXES.includes(targetFolder)) {
    return error(
      `Invalid folder: "${targetFolder}". Allowed: ${ALLOWED_PREFIXES.join(', ')}`,
      400,
    );
  }

  // Build the full scoped key: {tenantId}/{folder}/{filename}
  // Strip any folder prefix already in the key to avoid duplication
  const filename = key.split('/').pop(); // Just the filename
  const scopedKey = `${tenantId}/${targetFolder}/${filename}`;

  // Validate final key
  if (scopedKey.includes('..') || scopedKey.includes('//')) {
    return error('Invalid key after resolution', 400);
  }

  const op = operation || 'putObject';

  if (op === 'putObject') {
    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: scopedKey,
      ContentType: mimeType,
      ContentLength: route.maxBytes, // Enforce max size
      ServerSideEncryption: 'AES256',
      Metadata: {
        'tenant-id': tenantId,
        'folder': targetFolder,
        'uploaded-at': new Date().toISOString(),
        'original-key': key,
      },
    });

    const presignedUrl = await getSignedUrl(s3, command, {
      expiresIn: 300, // 5 minutes
    });

    // Public URL for later retrieval (via presigned GET, not direct)
    const region = process.env.AWS_REGION || 'ap-south-1';

    return success({
      url: presignedUrl,
      key: scopedKey,
      folder: targetFolder,
      maxBytes: route.maxBytes,
      expiresIn: 300,
      // Structure info for debugging
      structure: `${BUCKET}/${tenantId}/${targetFolder}/${filename}`,
    });
  }

  return error(`Unsupported operation: ${op}`, 400);
}

// ============================================================================
// GET /storage/url/{key} — Generate presigned GET URL
// ============================================================================
async function handleGetUrl(event, tenantId) {
  // Extract key from path — handles URL-encoded keys
  const rawKey = event.pathParameters?.key || '';
  const key = decodeURIComponent(rawKey);

  if (!key) {
    return error('key is required in path', 400);
  }

  const scopedKey = validateKey(key, tenantId);
  const expiresIn = parseInt(event.queryStringParameters?.expiresIn || '900', 10);

  // Verify object exists
  try {
    await s3.send(new HeadObjectCommand({
      Bucket: BUCKET,
      Key: scopedKey,
    }));
  } catch (e) {
    if (e.name === 'NotFound' || e.$metadata?.httpStatusCode === 404) {
      return error('Object not found', 404);
    }
    throw e;
  }

  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: scopedKey,
  });

  const presignedUrl = await getSignedUrl(s3, command, {
    expiresIn: Math.min(expiresIn, 3600), // Max 1 hour
  });

  return success({
    url: presignedUrl,
    key: scopedKey,
    expiresIn: Math.min(expiresIn, 3600),
  });
}

// ============================================================================
// DELETE /storage/{key} — Delete object from S3
// ============================================================================
async function handleDelete(event, tenantId) {
  const rawKey = event.pathParameters?.key || '';
  const key = decodeURIComponent(rawKey);

  if (!key) {
    return error('key is required in path', 400);
  }

  const scopedKey = validateKey(key, tenantId);

  await s3.send(new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: scopedKey,
  }));

  return success({ message: 'Deleted', key: scopedKey });
}

// ============================================================================
// GET /storage/list — List objects by prefix
// ============================================================================
async function handleList(event, tenantId) {
  const prefix = event.queryStringParameters?.prefix || '';
  const maxKeys = parseInt(event.queryStringParameters?.maxKeys || '100', 10);
  const continuationToken = event.queryStringParameters?.continuationToken;

  // Always scope to tenant
  const scopedPrefix = prefix
    ? validateKey(prefix, tenantId)
    : `${tenantId}/`;

  const params = {
    Bucket: BUCKET,
    Prefix: scopedPrefix,
    MaxKeys: Math.min(maxKeys, 1000),
  };

  if (continuationToken) {
    params.ContinuationToken = continuationToken;
  }

  const result = await s3.send(new ListObjectsV2Command(params));

  const items = (result.Contents || []).map(obj => ({
    key: obj.Key,
    sizeBytes: obj.Size,
    lastModified: obj.LastModified?.toISOString(),
    contentType: null, // Would need HeadObject for each — expensive
  }));

  return success({
    items,
    count: items.length,
    isTruncated: result.IsTruncated || false,
    nextContinuationToken: result.NextContinuationToken || null,
  });
}

// ============================================================================
// ROUTER
// ============================================================================
export async function handler(event) {
  try {
    // Validate bucket config
    if (!BUCKET) {
      return error('S3_BUCKET_NAME not configured', 500);
    }

    // Auth
    const authHeader = event.headers?.authorization || event.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    // SECURITY FIX (Finding #1): tenantId MUST come from verified JWT only.
    // NEVER fall back to client-supplied x-tenant-id header — that allows
    // any attacker to impersonate any tenant by setting a header.
    const tenantId = decoded.tenantId;

    if (!tenantId) {
      console.error('[SECURITY] JWT token missing tenantId claim', { sub: decoded.sub });
      return error('Token missing tenant context — access denied', 403);
    }

    const method = event.requestContext?.http?.method || event.httpMethod;
    const path = event.requestContext?.http?.path || event.path || '';

    // Route
    if (method === 'POST' && path.endsWith('/presign')) {
      return await handlePresign(event, tenantId);
    }

    if (method === 'GET' && path.includes('/storage/url/')) {
      return await handleGetUrl(event, tenantId);
    }

    if (method === 'DELETE' && path.includes('/storage/')) {
      return await handleDelete(event, tenantId);
    }

    if (method === 'GET' && path.endsWith('/storage/list')) {
      return await handleList(event, tenantId);
    }

    return error(`Unknown route: ${method} ${path}`, 404);
  } catch (err) {
    console.error('[StorageHandler] Error:', err);
    return error(err.message || 'Internal server error', 500);
  }
}
