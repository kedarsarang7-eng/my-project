// ============================================================================
// HSN → GST Rate Validation Service
// ============================================================================
// Validates submitted CGST/SGST rates against the authoritative HSNMASTER
// table in DynamoDB. Prevents GST compliance violations by catching rate
// mismatches at inventory create/update and invoice creation time.
//
// KEY DESIGN:
//   - HSNMASTER is a global partition (not per-tenant) since HSN codes are
//     uniform across India under the GST regime.
//   - Hierarchical fallback: 8-digit → 6-digit → 4-digit prefix lookup.
//     GST rates are often defined at the chapter/heading level (4-digit).
//   - Unknown HSN codes are ALLOWED but logged via CloudWatch metric
//     'UnknownHSN' for compliance monitoring.
//   - Exempted HSN codes (0% GST) reject any non-zero rate submission.
// ============================================================================

import { Keys, getItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { config } from '../config/environment';

const cloudwatchClient = new CloudWatchClient({ region: config.aws.region });

// ── Types ──────────────────────────────────────────────────────────────────

export interface HsnMasterRecord {
    PK: string;
    SK: string;
    entityType: string;
    hsnCode: string;
    description: string;
    cgstRateBp: number;
    sgstRateBp: number;
    igstRateBp: number;
    exempted: boolean;
    effectiveFrom: string;  // ISO date
    createdAt: string;
    updatedAt: string;
}

export interface HsnValidationResult {
    valid: boolean;
    hsnCode: string;
    found: boolean;
    exempted?: boolean;
    expected?: {
        cgstRateBp: number;
        sgstRateBp: number;
        igstRateBp: number;
        description: string;
    };
    submitted?: {
        cgstRateBp: number;
        sgstRateBp: number;
    };
    message?: string;
}

// ── CloudWatch Metric ──────────────────────────────────────────────────────

async function emitUnknownHsnMetric(hsnCode: string): Promise<void> {
    try {
        await cloudwatchClient.send(new PutMetricDataCommand({
            Namespace: 'DukanX/Compliance',
            MetricData: [{
                MetricName: 'UnknownHSN',
                Value: 1,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'HsnCode', Value: hsnCode },
                ],
            }],
        }));
    } catch (err) {
        logger.warn('Failed to emit UnknownHSN metric', {
            hsnCode,
            error: (err as Error).message,
        });
    }
}

// ── Hierarchical HSN Lookup ────────────────────────────────────────────────

/**
 * Look up an HSN code in the master table with hierarchical fallback.
 * Tries exact match first, then progressively shorter prefixes:
 *   8-digit → 6-digit → 4-digit
 *
 * This is necessary because the GST schedule defines rates at different
 * granularity levels (e.g., Chapter 49 = all books at 0%).
 */
async function lookupHsnMaster(hsnCode: string): Promise<HsnMasterRecord | null> {
    // Normalize: strip spaces, ensure string
    const code = String(hsnCode).trim();
    if (!code) return null;

    // Try exact match first
    const exact = await getItem<HsnMasterRecord>(
        Keys.hsnMasterPK(),
        Keys.hsnMasterSK(code),
    );
    if (exact) return exact;

    // Hierarchical fallback: try progressively shorter prefixes
    const prefixLengths = [6, 4];
    for (const len of prefixLengths) {
        if (code.length > len) {
            const prefix = code.substring(0, len);
            const result = await getItem<HsnMasterRecord>(
                Keys.hsnMasterPK(),
                Keys.hsnMasterSK(prefix),
            );
            if (result) {
                logger.info('HSN hierarchical fallback matched', {
                    originalCode: code,
                    matchedCode: prefix,
                    description: result.description,
                });
                return result;
            }
        }
    }

    return null;
}

// ── Main Validation Function ───────────────────────────────────────────────

/**
 * Validate submitted CGST/SGST rates against the HSN master table.
 *
 * Behavior:
 *   1. If HSN found + rates match → { valid: true }
 *   2. If HSN found + rates mismatch → { valid: false, expected, submitted }
 *   3. If HSN found + exempted + non-zero rates → { valid: false }
 *   4. If HSN NOT found → { valid: true, found: false } + CloudWatch metric
 *
 * @param hsnCode - The HSN code to validate (4/6/8 digit)
 * @param cgstRateBp - Submitted CGST rate in basis points
 * @param sgstRateBp - Submitted SGST rate in basis points
 */
export async function validateHsnGstRate(
    hsnCode: string,
    cgstRateBp: number,
    sgstRateBp: number,
): Promise<HsnValidationResult> {
    const code = String(hsnCode).trim();

    // Skip validation if no HSN code provided
    if (!code) {
        return { valid: true, hsnCode: '', found: false, message: 'No HSN code provided, skipping validation' };
    }

    // Look up in master table (with hierarchical fallback)
    const master = await lookupHsnMaster(code);

    if (!master) {
        // Unknown HSN — allow but log warning
        logger.warn('HSN code not found in master table', {
            hsnCode: code,
            submittedCgstRateBp: cgstRateBp,
            submittedSgstRateBp: sgstRateBp,
        });

        // Emit CloudWatch metric for compliance monitoring (fire-and-forget)
        emitUnknownHsnMetric(code).catch(() => { });

        return {
            valid: true,
            hsnCode: code,
            found: false,
            submitted: { cgstRateBp, sgstRateBp },
            message: `HSN code '${code}' not found in master table. Allowed with warning.`,
        };
    }

    // ── Exempted HSN check ─────────────────────────────────────────────
    if (master.exempted) {
        if (cgstRateBp !== 0 || sgstRateBp !== 0) {
            return {
                valid: false,
                hsnCode: code,
                found: true,
                exempted: true,
                expected: {
                    cgstRateBp: 0,
                    sgstRateBp: 0,
                    igstRateBp: 0,
                    description: master.description,
                },
                submitted: { cgstRateBp, sgstRateBp },
                message: `HSN ${code} ('${master.description}') is GST-exempt. Submitted rates must be 0.`,
            };
        }

        return {
            valid: true,
            hsnCode: code,
            found: true,
            exempted: true,
            expected: {
                cgstRateBp: 0,
                sgstRateBp: 0,
                igstRateBp: 0,
                description: master.description,
            },
        };
    }

    // ── Rate comparison ────────────────────────────────────────────────
    const expectedCgst = Number(master.cgstRateBp) || 0;
    const expectedSgst = Number(master.sgstRateBp) || 0;

    if (cgstRateBp !== expectedCgst || sgstRateBp !== expectedSgst) {
        return {
            valid: false,
            hsnCode: code,
            found: true,
            expected: {
                cgstRateBp: expectedCgst,
                sgstRateBp: expectedSgst,
                igstRateBp: Number(master.igstRateBp) || 0,
                description: master.description,
            },
            submitted: { cgstRateBp, sgstRateBp },
            message: `GST rate mismatch for HSN ${code} ('${master.description}'): expected CGST ${expectedCgst}bp + SGST ${expectedSgst}bp, received CGST ${cgstRateBp}bp + SGST ${sgstRateBp}bp.`,
        };
    }

    // ── Rates match ────────────────────────────────────────────────────
    return {
        valid: true,
        hsnCode: code,
        found: true,
        expected: {
            cgstRateBp: expectedCgst,
            sgstRateBp: expectedSgst,
            igstRateBp: Number(master.igstRateBp) || 0,
            description: master.description,
        },
    };
}
