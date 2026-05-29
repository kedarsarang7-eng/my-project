// ============================================================================
// GSTIN Utility Methods
// ============================================================================

const INDIAN_STATE_CODES = new Set([
    '01', '02', '03', '04', '05', '06', '07', '08', '09', '10',
    '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
    '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
    '31', '32', '33', '34', '35', '36', '37', '38'
]);

/**
 * Extracts the 2-digit state code from a given GSTIN.
 * Returns null if the given GSTIN is invalid or lacks a valid state code.
 */
export function extractStateCode(gstin?: string | null): string | null {
    if (!gstin || typeof gstin !== 'string') {
        return null;
    }

    const trimmed = gstin.trim();
    if (trimmed.length < 2) {
        return null;
    }

    const stateCode = trimmed.substring(0, 2);
    if (isValidStateCode(stateCode)) {
        return stateCode;
    }

    return null;
}

/**
 * Checks if a given 2-digit code is a valid Indian GST state code.
 */
export function isValidStateCode(code: string): boolean {
    return INDIAN_STATE_CODES.has(code);
}
