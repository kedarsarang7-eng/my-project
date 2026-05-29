// ============================================================================
// Vehicle Number Normalization — PP-009 FIX
// ============================================================================
// Normalizes Indian vehicle registration numbers to a canonical form
// for consistent matching and deduplication.
//
// Examples:
//   "MH-12-AB-1234"  → "MH12AB1234"
//   "mh 12 ab 1234"  → "MH12AB1234"
//   "MH.12.AB.1234"  → "MH12AB1234"
//   "  mh12ab1234  "  → "MH12AB1234"
// ============================================================================

/**
 * Normalize an Indian vehicle registration number to a canonical uppercase
 * form with no separators.
 */
export function normalizeVehicleNumber(raw: string): string {
    if (!raw) return '';
    return raw
        .toUpperCase()
        .replace(/[\s\-\.\/]/g, '')  // Remove spaces, dashes, dots, slashes
        .replace(/[^A-Z0-9]/g, '')   // Remove any remaining special chars
        .trim();
}

/**
 * Format a normalized vehicle number for display (e.g. "MH12AB1234" → "MH-12-AB-1234").
 * Best-effort — works for standard Indian RTO format.
 */
export function formatVehicleNumber(normalized: string): string {
    // Standard format: SS-DD-AA-DDDD (state code, district, series, number)
    const match = normalized.match(/^([A-Z]{2})(\d{1,2})([A-Z]{1,3})(\d{1,4})$/);
    if (match) {
        return `${match[1]}-${match[2]}-${match[3]}-${match[4]}`;
    }
    return normalized; // Return as-is if doesn't match standard pattern
}
