// ============================================
// Geo-Fencing Middleware
// ============================================
// Checks if the client's country (derived from IP) is allowed
// by the license's allowed_countries restriction.
//
// NOTE: In production, use MaxMind GeoIP2 or a geo-IP API.
// This implementation uses a simple header-based approach
// that works behind Cloudflare/nginx (CF-IPCountry header)
// or accepts country_code in the request body for testing.

import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

/**
 * Extract country code from the request.
 * Priority:
 *   1. Cloudflare CF-IPCountry header
 *   2. X-Country-Code header (from nginx GeoIP module)
 *   3. Request body country_code (for testing/development)
 *   4. null (unknown — allow by default)
 */
export function getCountryCode(req: Request): string | null {
    const cfCountry = req.headers['cf-ipcountry'] as string;
    if (cfCountry && cfCountry !== 'XX') return cfCountry.toUpperCase();

    const xCountry = req.headers['x-country-code'] as string;
    if (xCountry) return xCountry.toUpperCase();

    // For testing: accept country_code in body
    if (req.body?.country_code) return (req.body.country_code as string).toUpperCase();

    return null;
}

/**
 * Check if a country code is allowed by the license restrictions.
 * An empty allowed_countries array means ALL countries are allowed.
 */
export function isCountryAllowed(
    countryCode: string | null,
    allowedCountries: string[]
): boolean {
    // No restrictions set → allow all
    if (!allowedCountries || allowedCountries.length === 0) return true;

    // Can't determine country → block (fail-secure)
    if (!countryCode) {
        logger.warn('Geo-fence: cannot determine country, blocking request');
        return false;
    }

    return allowedCountries.includes(countryCode);
}

/**
 * Middleware factory for geo-fencing.
 * Used in the validation controller after license lookup.
 * This is NOT a route-level middleware — it's called programmatically
 * because the allowed countries depend on the specific license being validated.
 */
export function checkGeoFence(
    countryCode: string | null,
    allowedCountries: string[]
): { allowed: boolean; country: string | null } {
    const allowed = isCountryAllowed(countryCode, allowedCountries);

    if (!allowed) {
        logger.info('Geo-fence blocked', { country: countryCode, allowed: allowedCountries });
    }

    return { allowed, country: countryCode };
}
