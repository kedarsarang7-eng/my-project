// ============================================================================
// Retention Configuration — Input Validation
// ============================================================================
// Validates request bodies for the retention-config endpoint using zod.
// Bounds match `MIN_ARCHIVE_PERIOD_DAYS` and `MAX_ARCHIVE_PERIOD_DAYS` from
// `./types.ts`.
//
// Validates: REQ 13.4 (only authenticated, validated changes accepted).
// ============================================================================

import { z } from 'zod';
import {
    MAX_ARCHIVE_PERIOD_DAYS,
    MIN_ARCHIVE_PERIOD_DAYS,
} from './types';

/**
 * Body schema for `PUT /notifications/retention-config`.
 *
 * Strict on purpose: the integer must be whole, finite, and within the
 * allowed range. A trailing `.strict()` would reject unknown keys; we keep
 * the schema permissive there so future fields can be added without
 * breaking older clients, but we still parse only the field we care about.
 */
export const updateRetentionConfigSchema = z.object({
    archive_period_days: z
        .number()
        .int('archive_period_days must be an integer')
        .min(
            MIN_ARCHIVE_PERIOD_DAYS,
            `archive_period_days must be at least ${MIN_ARCHIVE_PERIOD_DAYS}`,
        )
        .max(
            MAX_ARCHIVE_PERIOD_DAYS,
            `archive_period_days must be at most ${MAX_ARCHIVE_PERIOD_DAYS}`,
        ),
});

export type UpdateRetentionConfigBody = z.infer<
    typeof updateRetentionConfigSchema
>;
