// ============================================================================
// RID GENERATOR - Request ID utilities for Lambda
// ============================================================================

import { randomUUID } from 'crypto';

/**
 * Generate RID in format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
 */
export function generateRID(tenantId) {
  const timestamp = Date.now();
  const uuidShort = randomUUID().substring(0, 6);
  return `${tenantId}-${timestamp}-${uuidShort}`;
}

/**
 * Generate Session RID for WebSocket connections
 */
export function generateSessionRID(tenantId) {
  const timestamp = Date.now();
  const uuidShort = randomUUID().substring(0, 6);
  return `${tenantId}-${timestamp}-session${uuidShort}`;
}

/**
 * Validate RID format
 */
export function isValidRID(rid) {
  const parts = rid.split('-');
  if (parts.length !== 3) return false;
  
  const [tenantId, timestamp, uuidShort] = parts;
  
  // Validate tenantId (non-empty)
  if (!tenantId || tenantId.length === 0) return false;
  
  // Validate timestamp (13 digits, valid number)
  if (!/^\d{13}$/.test(timestamp)) return false;
  const ts = parseInt(timestamp, 10);
  if (isNaN(ts) || ts < 1600000000000 || ts > 2000000000000) return false;
  
  // Validate uuid short (6 alphanumeric chars)
  if (!/^[a-z0-9]{6}$/.test(uuidShort)) return false;
  
  return true;
}

/**
 * Extract tenantId from RID
 */
export function extractTenantIdFromRID(rid) {
  const parts = rid.split('-');
  return parts.length >= 1 ? parts[0] : null;
}

/**
 * Get short reference (last 6 chars) for user display
 */
export function getShortReference(rid) {
  return rid.split('-').pop() || 'unknown';
}
