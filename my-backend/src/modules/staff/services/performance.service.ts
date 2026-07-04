// ============================================================================
// Staff Module — Performance Scoring Service (Task 10.2)
// ============================================================================
// Computes PerformanceScore as a DETERMINISTIC weighted sum. The result is
// fully inspectable: every contributing factor and its weight are returned
// alongside the final numeric score.
//
// PROPERTY 23 (design.md):
//   "For any set of contributing factors and weights, the PerformanceScore
//    equals the weighted sum of those factors, and the returned result exposes
//    each contributing factor and its weight for inspection."
//
// PROPERTY 26 (design.md):
//   "For any formula or scoring inputs, evaluating the same inputs repeatedly
//    yields identical results."
//
// This service is PURE — no side effects, no I/O, no randomness. Given the same
// inputs it always produces the same output (determinism by construction).
//
// Requirements: 7.1 (deterministic weighted formula, inspectable inputs/weights),
//               7.2 (contributing factors and weights available for inspection),
//               7.7 (same inputs → same result).
// ============================================================================

import { ValidationError } from '../../../utils/errors';

// ── Types ─────────────────────────────────────────────────────────────────────

/**
 * A single contributing factor to the performance score.
 * - `name`   — human-readable identifier (e.g. "punctuality", "sales_target")
 * - `value`  — the raw metric value for this factor
 * - `weight` — the factor's weight in the scoring formula (≥ 0)
 */
export interface PerformanceFactor {
    name: string;
    value: number;
    weight: number;
}

/**
 * The result of computing a performance score — exposes all contributing
 * factors and weights for full inspectability (Req 7.2).
 */
export interface PerformanceScoreResult {
    /** The final numeric performance score (weighted sum). */
    score: number;
    /** The contributing factors with their values and weights (inspectable). */
    factors: PerformanceFactor[];
    /** The sum of all weights (useful for normalisation checks). */
    totalWeight: number;
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Compute a deterministic, inspectable performance score.
 *
 * The score is defined as:
 *   score = Σ (factor_i.value × factor_i.weight)
 *
 * This is a pure function: same (factors, weights) → same result, always.
 * The returned object exposes every contributing factor and its weight for
 * full inspectability (Property 23, Req 7.2).
 *
 * @param factors - array of factor name→value pairs: `{ name, value }`
 * @param weights - map of factor name→weight: `{ [name]: weight }`
 * @returns PerformanceScoreResult with numeric score and full breakdown
 * @throws ValidationError if inputs are invalid (empty factors, missing weight, negative weight)
 */
export function computeScore(
    factors: ReadonlyArray<{ name: string; value: number }>,
    weights: Readonly<Record<string, number>>,
): PerformanceScoreResult {
    // ── Input validation ────────────────────────────────────────────────────
    if (!factors || factors.length === 0) {
        throw new ValidationError(
            'At least one factor is required to compute a performance score',
        );
    }

    const resultFactors: PerformanceFactor[] = [];
    let totalWeight = 0;
    let score = 0;

    for (const factor of factors) {
        if (!factor.name || typeof factor.name !== 'string') {
            throw new ValidationError(
                'Each factor must have a non-empty string name',
            );
        }
        if (typeof factor.value !== 'number' || !Number.isFinite(factor.value)) {
            throw new ValidationError(
                `Factor '${factor.name}' must have a finite numeric value`,
            );
        }

        const weight = weights[factor.name];
        if (weight === undefined || weight === null) {
            throw new ValidationError(
                `Missing weight for factor '${factor.name}'`,
            );
        }
        if (typeof weight !== 'number' || !Number.isFinite(weight)) {
            throw new ValidationError(
                `Weight for factor '${factor.name}' must be a finite number`,
            );
        }
        if (weight < 0) {
            throw new ValidationError(
                `Weight for factor '${factor.name}' must be non-negative`,
            );
        }

        const contribution = factor.value * weight;
        score += contribution;
        totalWeight += weight;

        resultFactors.push({
            name: factor.name,
            value: factor.value,
            weight,
        });
    }

    return {
        score,
        factors: resultFactors,
        totalWeight,
    };
}
