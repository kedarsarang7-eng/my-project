/**
 * Shared utility helpers for FuelPOS Lambda functions
 * DRY - Don't Repeat Yourself
 */

/**
 * Standard CORS headers for all responses
 */
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Tenant-Id,X-Request-Id',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  'Access-Control-Max-Age': '86400', // 24 hours
};

/**
 * Get IST (Indian Standard Time) date string
 * @param {Date} date - Optional date object, defaults to now
 * @returns {string} Date in YYYY-MM-DD format
 */
export function getISTDate(date = new Date()) {
  const istOffset = 5.5 * 60 * 60 * 1000; // IST is UTC+5:30
  const istTime = date.getTime() + (date.getTimezoneOffset() * 60 * 1000) + istOffset;
  const istDate = new Date(istTime);
  return istDate.toISOString().split('T')[0];
}

/**
 * Get yesterday's date in IST
 * @param {string} date - Date string in YYYY-MM-DD format
 * @returns {string} Yesterday's date in YYYY-MM-DD format
 */
export function getYesterdayDate(date) {
  const d = new Date(date);
  d.setDate(d.getDate() - 1);
  return getISTDate(d);
}

/**
 * Format time to IST
 * @param {string} isoTimestamp - ISO timestamp string
 * @returns {string} Time in HH:MM format (IST)
 */
export function formatISTTime(isoTimestamp) {
  if (!isoTimestamp) return '-';
  
  const date = new Date(isoTimestamp);
  return date.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: 'Asia/Kolkata',
  });
}

/**
 * Format amount in INR
 * @param {number} amount - Amount to format
 * @returns {string} Formatted INR string
 */
export function formatINR(amount) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2,
  }).format(amount || 0);
}

/**
 * Format number with commas (Indian format)
 * @param {number} num - Number to format
 * @returns {string} Formatted number
 */
export function formatNumber(num) {
  return new Intl.NumberFormat('en-IN').format(num || 0);
}

/**
 * Calculate percentage change
 * @param {number} current - Current value
 * @param {number} previous - Previous value
 * @returns {number} Percentage change
 */
export function calculateChangePercent(current, previous) {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100 * 10) / 10;
}

/**
 * Round to 2 decimal places
 * @param {number} num - Number to round
 * @returns {number} Rounded number
 */
export function round2(num) {
  return Math.round((num || 0) * 100) / 100;
}

/**
 * Round to 1 decimal place
 * @param {number} num - Number to round
 * @returns {number} Rounded number
 */
export function round1(num) {
  return Math.round((num || 0) * 10) / 10;
}

/**
 * Sleep/pause execution
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Generate request ID
 * @returns {string} UUID v4
 */
export function generateRequestId() {
  return crypto.randomUUID();
}

// Import crypto for generateRequestId
import { randomUUID } from 'crypto';

/**
 * Safely parse JSON
 * @param {string} json - JSON string
 * @param {*} defaultValue - Default value if parsing fails
 * @returns {*} Parsed object or default
 */
export function safeJsonParse(json, defaultValue = {}) {
  try {
    return JSON.parse(json);
  } catch {
    return defaultValue;
  }
}

/**
 * Validate UUID format
 * @param {string} uuid - String to validate
 * @returns {boolean} True if valid UUID
 */
export function isValidUUID(uuid) {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}

/**
 * Truncate string with ellipsis
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @returns {string} Truncated string
 */
export function truncate(str, maxLength = 50) {
  if (!str || str.length <= maxLength) return str;
  return str.substring(0, maxLength - 3) + '...';
}

/**
 * Remove null/undefined values from object
 * @param {Object} obj - Object to clean
 * @returns {Object} Cleaned object
 */
export function removeEmpty(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([_, v]) => v != null)
  );
}
