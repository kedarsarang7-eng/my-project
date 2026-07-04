// ============================================================================
// Staff Module — Statutory Rate Service (Task 9.1)
// ============================================================================
// Reads effective-dated PF/ESI/PT/TDS rates from StatutoryRate items stored in
// DynamoDB (SK: STATRATE#{kind}#{state|ALL}#{version}). The service resolves
// the applicable rate for a given date and employee state.
//
// CRITICAL INVARIANT (Req 6.3): No hardcoded statutory rate values anywhere.
// Every rate is sourced exclusively from the Statutory_Rate_Table (DynamoDB).
//
// PT is state-specific (uses the employee's state); PF/ESI/TDS use 'ALL'.
// When a required effective rate is missing, the service throws an AppError
// with code STATUTORY_RATE_UNAVAILABLE — the payroll run must abort.
//
// Resolution logic is kept pure (selectEffectiveRate) so it's independently
// testable for Property 20 (payroll deductions derive solely from the table).
//
// Requirements: 6.2, 6.3, 6.4
// ============================================================================

import { queryItems } from '../../../config/dynamodb.config';
import { gsi1PK } from '../../../dynamodb/keys';
import { AppError } from '../../../utils/errors';
import { logger } from '../../../utils/logger';
import {
    StatutoryRate,
    StatutoryKind,
    STATUTORY_KINDS,
    STATUTORY_STATE_ALL,
} from '../schemas/payroll.schema';
import { STATRATE_SK_PREFIX } from '../repositories/payroll.keys';

// ── Error codes ──────────────────────────────────────────────────────────────

export const STATUTORY_RATE_UNAVAILABLE = 'STATUTORY_RATE_UNAVAILABLE';

// ── Types ────────────────────────────────────────────────────────────────────

/**
 * Input context needed to resolve all statutory rates for a payroll computation.
 */
export interface StatutoryRateContext {
    tenantId: string;
    businessId: string;
    /** The payroll date for which effective rates are needed (ISO-8601). */
    effectiveDate: string;
    /** Employee's state code — used to select the PT rate (Req 6.4). */
    employeeState: string;
}

/**
 * Resolved statutory rates ready for payroll computation. Every field is
 * sourced from the Statutory_Rate_Table — never hardcoded (Req 6.3).
 *
 * Note: payroll.service.ts owns a `ResolvedStatutoryRates` interface that takes
 * raw `StatutoryRate` items. This interface maps to `ResolvedRate` (the service
 * output shape). Consumers call `toPayrollRates()` to bridge the two.
 */
export interface StatutoryRateResolution {
    pf: ResolvedRate;
    esi: ResolvedRate;
    pt: ResolvedRate;
    tds: ResolvedRate;
}

export interface ResolvedRate {
    kind: StatutoryKind;
    rate: number;
    params?: Record<string, unknown>;
    effectiveFrom: string;
    effectiveTo?: string;
    version: number;
    state: string;
}

// ── Pure rate selection logic (testable without DynamoDB) ─────────────────────

/**
 * Given a list of StatutoryRate records for a specific kind+state, select the
 * one that is effective on the given date. If multiple versions overlap, the
 * highest version number wins (latest published rate takes precedence).
 *
 * A rate is effective on `date` iff:
 *   effectiveFrom <= date AND (effectiveTo is undefined OR effectiveTo >= date)
 *
 * @returns The selected rate, or null if no applicable rate exists.
 */
export function selectEffectiveRate(
    rates: StatutoryRate[],
    date: string,
): StatutoryRate | null {
    const applicable = rates.filter((r) => {
        if (r.effectiveFrom > date) return false;
        if (r.effectiveTo && r.effectiveTo < date) return false;
        return true;
    });

    if (applicable.length === 0) return null;

    // Highest version wins among overlapping effective rates.
    applicable.sort((a, b) => b.version - a.version);
    return applicable[0];
}

// ── DynamoDB query layer ─────────────────────────────────────────────────────

/**
 * Fetch all StatutoryRate items for a given kind + state (or ALL) from the GSI1
 * index. GSI1PK = TENANT#{tenantId}#BIZ#{businessId}#STATRATE#{kind}#{state}.
 */
async function fetchRatesForKind(
    tenantId: string,
    businessId: string,
    kind: StatutoryKind,
    stateOrAll: string,
): Promise<StatutoryRate[]> {
    const gsi1PKValue = gsi1PK(tenantId, businessId, `STATRATE#${kind}#${stateOrAll}`);

    const result = await queryItems<StatutoryRate & Record<string, unknown>>(
        gsi1PKValue,
        undefined,
        {
            indexName: 'GSI1',
            scanIndexForward: false, // newest effectiveFrom first
        },
    );

    return result.items as StatutoryRate[];
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Resolve a single statutory rate for the given kind, state, and date.
 * Throws STATUTORY_RATE_UNAVAILABLE if no effective rate exists.
 */
export async function resolveRate(
    tenantId: string,
    businessId: string,
    kind: StatutoryKind,
    stateOrAll: string,
    effectiveDate: string,
): Promise<ResolvedRate> {
    const rates = await fetchRatesForKind(tenantId, businessId, kind, stateOrAll);
    const selected = selectEffectiveRate(rates, effectiveDate);

    if (!selected) {
        logger.error('Statutory rate unavailable', {
            kind,
            state: stateOrAll,
            effectiveDate,
            tenantId,
            businessId,
        });
        throw new AppError(
            STATUTORY_RATE_UNAVAILABLE,
            `Required statutory rate not found: ${kind} for state '${stateOrAll}' effective on ${effectiveDate}. Payroll run aborted.`,
        );
    }

    return {
        kind: selected.kind,
        rate: selected.rate,
        params: selected.params,
        effectiveFrom: selected.effectiveFrom,
        effectiveTo: selected.effectiveTo,
        version: selected.version,
        state: stateOrAll,
    };
}

/**
 * Resolve ALL required statutory rates for a payroll computation.
 *
 * - PF: fetched with state = 'ALL'
 * - ESI: fetched with state = 'ALL'
 * - PT: fetched with state = employeeState (Req 6.4)
 * - TDS: fetched with state = 'ALL'
 *
 * If ANY required rate is unavailable, throws STATUTORY_RATE_UNAVAILABLE
 * and the payroll run must abort.
 *
 * @param ctx - The statutory rate resolution context
 * @returns All resolved rates ready for payroll computation
 * @throws AppError with code STATUTORY_RATE_UNAVAILABLE
 */
export async function resolveAllRates(
    ctx: StatutoryRateContext,
): Promise<StatutoryRateResolution> {
    const { tenantId, businessId, effectiveDate, employeeState } = ctx;

    // Resolve all four rates. PT uses the employee's state; others use 'ALL'.
    // We resolve sequentially to fail-fast with a clear error on the first
    // missing rate rather than awaiting all and reporting a composite error.
    const pf = await resolveRate(tenantId, businessId, 'PF', STATUTORY_STATE_ALL, effectiveDate);
    const esi = await resolveRate(tenantId, businessId, 'ESI', STATUTORY_STATE_ALL, effectiveDate);
    const pt = await resolveRate(tenantId, businessId, 'PT', employeeState, effectiveDate);
    const tds = await resolveRate(tenantId, businessId, 'TDS', STATUTORY_STATE_ALL, effectiveDate);

    return { pf, esi, pt, tds };
}

/**
 * Resolve all rates with parallel fetching for performance.
 * All rates must be available; if any is missing, the first failure throws.
 */
export async function resolveAllRatesParallel(
    ctx: StatutoryRateContext,
): Promise<StatutoryRateResolution> {
    const { tenantId, businessId, effectiveDate, employeeState } = ctx;

    const [pf, esi, pt, tds] = await Promise.all([
        resolveRate(tenantId, businessId, 'PF', STATUTORY_STATE_ALL, effectiveDate),
        resolveRate(tenantId, businessId, 'ESI', STATUTORY_STATE_ALL, effectiveDate),
        resolveRate(tenantId, businessId, 'PT', employeeState, effectiveDate),
        resolveRate(tenantId, businessId, 'TDS', STATUTORY_STATE_ALL, effectiveDate),
    ]);

    return { pf, esi, pt, tds };
}

// Re-export constants for downstream consumers
export { STATUTORY_KINDS, STATUTORY_STATE_ALL };
