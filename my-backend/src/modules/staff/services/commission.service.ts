// ============================================================================
// Staff Module — Commission Engine Service (Task 10.2)
// ============================================================================
// Evaluates commission rules across all supported kinds: category, brand,
// product, target, profit, and custom (AST-evaluated via formula-evaluator).
//
// PROPERTY 26 (design.md):
//   "For any formula or scoring inputs, evaluating the same inputs repeatedly
//    yields identical results."
//
// This service is PURE and DETERMINISTIC — same inputs always produce the same
// output. For `custom` rules the formula is parsed, validated, and evaluated via
// the sandboxed AST formula evaluator (AD-5, formula-evaluator.service.ts).
//
// Design reference: `commission.service.ts — evaluateCommission(rule, context);
// supports category/brand/product/target/profit/custom.`
//
// Requirements: 7.3 (commission rules by category/brand/product/target/profit/custom),
//               7.7 (same inputs → same result).
// ============================================================================

import { AppError, ValidationError } from '../../../utils/errors';
import {
    evaluate,
    FormulaContext,
    parse,
    validate,
} from './formula-evaluator.service';

// ── Types ─────────────────────────────────────────────────────────────────────

/** Supported commission rule kinds (Req 7.3). */
export type CommissionRuleKind =
    | 'category'
    | 'brand'
    | 'product'
    | 'target'
    | 'profit'
    | 'custom';

/**
 * Parameters for non-custom commission rules.
 * Each rule kind interprets these fields as appropriate:
 *
 * - `rate`          — percentage commission rate (0–100) applied to `baseAmount`
 * - `flatAmount`    — flat commission in paise (added to percentage if present)
 * - `minThreshold`  — minimum amount required before commission applies
 * - `maxCap`        — maximum commission cap in paise
 * - `tieredRates`   — optional graduated tiers (for target/profit rules)
 */
export interface CommissionParams {
    rate?: number;
    flatAmount?: number;
    minThreshold?: number;
    maxCap?: number;
    tieredRates?: CommissionTier[];
}

/** A graduated commission tier (for target/profit rules). */
export interface CommissionTier {
    /** Lower bound (inclusive) for this tier. */
    from: number;
    /** Upper bound (exclusive) for this tier; undefined = uncapped. */
    to?: number;
    /** The commission rate (0–100) for amounts within this tier. */
    rate: number;
}

/**
 * A commission rule definition (matches the DynamoDB CommissionRule entity).
 */
export interface CommissionRule {
    id: string;
    businessId: string;
    kind: CommissionRuleKind;
    /** Parameters for standard (non-custom) rules. */
    params?: CommissionParams;
    /** Formula string for `custom` rules (AST-evaluated). */
    formula?: string;
}

/**
 * Context supplied to the commission engine for evaluation.
 * Contains the numeric values needed to compute the commission.
 */
export interface CommissionContext {
    /** The base amount to apply the commission rate against (e.g. sale total in paise). */
    baseAmount: number;
    /** Additional numeric variables available for formula evaluation. */
    [key: string]: number;
}

/**
 * The result of evaluating a commission rule — fully inspectable.
 */
export interface CommissionResult {
    /** Computed commission amount (in paise for money values). */
    amount: number;
    /** The rule kind that was evaluated. */
    kind: CommissionRuleKind;
    /** The rule id. */
    ruleId: string;
    /** Breakdown of how the commission was computed. */
    breakdown: CommissionBreakdown;
}

/** Breakdown detail for inspectability. */
export interface CommissionBreakdown {
    /** The base amount used for calculation. */
    baseAmount: number;
    /** Applied rate (0–100) or null for flat/custom. */
    appliedRate: number | null;
    /** Flat amount added (if any). */
    flatAmount: number;
    /** Whether a cap was applied. */
    capped: boolean;
    /** Whether the threshold was met. */
    thresholdMet: boolean;
    /** For custom rules: the formula used. */
    formula?: string;
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Evaluate a commission rule against a context.
 *
 * This function is PURE and DETERMINISTIC: identical inputs always yield
 * identical results (Property 26). Custom rules are evaluated via the sandboxed
 * AST formula evaluator (no eval/new Function).
 *
 * @param rule    - The commission rule to evaluate
 * @param context - Numeric context (must include `baseAmount`)
 * @returns CommissionResult with computed amount and inspectable breakdown
 * @throws ValidationError on invalid rule/context
 * @throws AppError with FORMULA_REJECTED for invalid custom formulas
 */
export function evaluateCommission(
    rule: CommissionRule,
    context: CommissionContext,
): CommissionResult {
    // ── Input validation ────────────────────────────────────────────────────
    if (!rule || !rule.kind) {
        throw new ValidationError('Commission rule must have a valid kind');
    }
    if (!context || typeof context.baseAmount !== 'number' || !Number.isFinite(context.baseAmount)) {
        throw new ValidationError('Commission context must include a finite baseAmount');
    }

    switch (rule.kind) {
        case 'category':
        case 'brand':
        case 'product':
            return evaluateSimpleRate(rule, context);
        case 'target':
            return evaluateTarget(rule, context);
        case 'profit':
            return evaluateProfit(rule, context);
        case 'custom':
            return evaluateCustom(rule, context);
        default:
            throw new ValidationError(
                `Unsupported commission rule kind: '${(rule as CommissionRule).kind}'`,
            );
    }
}

// ── Internal evaluators ──────────────────────────────────────────────────────

/**
 * Simple percentage + flat commission (category, brand, product).
 * commission = (baseAmount × rate/100) + flatAmount, capped if maxCap is set.
 */
function evaluateSimpleRate(rule: CommissionRule, context: CommissionContext): CommissionResult {
    const params = rule.params ?? {};
    const rate = params.rate ?? 0;
    const flat = params.flatAmount ?? 0;
    const minThreshold = params.minThreshold ?? 0;

    const thresholdMet = context.baseAmount >= minThreshold;
    let amount = 0;

    if (thresholdMet) {
        amount = (context.baseAmount * rate) / 100 + flat;
    }

    const capped = params.maxCap !== undefined && amount > params.maxCap;
    if (capped) {
        amount = params.maxCap!;
    }

    return {
        amount,
        kind: rule.kind,
        ruleId: rule.id,
        breakdown: {
            baseAmount: context.baseAmount,
            appliedRate: rate,
            flatAmount: flat,
            capped,
            thresholdMet,
        },
    };
}

/**
 * Target-based commission: uses tiered rates or falls back to simple rate.
 * Evaluates the base amount against graduated tiers; commission is sum of each
 * tier's (portion × rate/100).
 */
function evaluateTarget(rule: CommissionRule, context: CommissionContext): CommissionResult {
    const params = rule.params ?? {};
    const minThreshold = params.minThreshold ?? 0;
    const thresholdMet = context.baseAmount >= minThreshold;

    if (!thresholdMet) {
        return {
            amount: 0,
            kind: rule.kind,
            ruleId: rule.id,
            breakdown: {
                baseAmount: context.baseAmount,
                appliedRate: null,
                flatAmount: 0,
                capped: false,
                thresholdMet: false,
            },
        };
    }

    let amount = 0;
    let effectiveRate: number | null = null;

    if (params.tieredRates && params.tieredRates.length > 0) {
        amount = computeTieredCommission(context.baseAmount, params.tieredRates);
    } else {
        const rate = params.rate ?? 0;
        effectiveRate = rate;
        amount = (context.baseAmount * rate) / 100;
    }

    amount += params.flatAmount ?? 0;

    const capped = params.maxCap !== undefined && amount > params.maxCap;
    if (capped) {
        amount = params.maxCap!;
    }

    return {
        amount,
        kind: rule.kind,
        ruleId: rule.id,
        breakdown: {
            baseAmount: context.baseAmount,
            appliedRate: effectiveRate,
            flatAmount: params.flatAmount ?? 0,
            capped,
            thresholdMet: true,
        },
    };
}

/**
 * Profit-based commission: identical structure to target but semantically
 * operates on profit margin rather than sales amount. Same tiered logic applies.
 */
function evaluateProfit(rule: CommissionRule, context: CommissionContext): CommissionResult {
    // Profit rules use the same mechanics as target rules; the difference is
    // semantic (baseAmount represents profit, not sales). We reuse the same
    // computation to maintain DRY and determinism.
    const result = evaluateTarget(rule, context);
    return { ...result, kind: 'profit' };
}

/**
 * Custom formula-based commission (AD-5 — sandboxed AST evaluation).
 * The formula is parsed, validated, and evaluated via formula-evaluator.service.
 */
function evaluateCustom(rule: CommissionRule, context: CommissionContext): CommissionResult {
    if (!rule.formula || typeof rule.formula !== 'string' || rule.formula.trim().length === 0) {
        throw new ValidationError(
            'Custom commission rule must have a non-empty formula',
        );
    }

    // Build the formula context from the commission context (all numeric values).
    const formulaCtx: FormulaContext = {};
    for (const [key, value] of Object.entries(context)) {
        if (typeof value === 'number' && Number.isFinite(value)) {
            formulaCtx[key] = value;
        }
    }

    // Parse → validate → evaluate (deterministic pipeline).
    const ast = parse(rule.formula);
    const validation = validate(ast);
    if (!validation.ok) {
        throw new AppError(
            'FORMULA_REJECTED',
            `Custom commission formula rejected: ${validation.error}`,
        );
    }

    const amount = evaluate(ast, formulaCtx);

    const params = rule.params ?? {};
    let finalAmount = amount;
    const capped = params.maxCap !== undefined && finalAmount > params.maxCap;
    if (capped) {
        finalAmount = params.maxCap!;
    }

    return {
        amount: finalAmount,
        kind: 'custom',
        ruleId: rule.id,
        breakdown: {
            baseAmount: context.baseAmount,
            appliedRate: null,
            flatAmount: 0,
            capped,
            thresholdMet: true,
            formula: rule.formula,
        },
    };
}

// ── Tiered computation helper ─────────────────────────────────────────────────

/**
 * Compute commission from graduated tiers.
 * Each tier applies its rate to the portion of `amount` within [tier.from, tier.to).
 * Tiers are evaluated in order; overlapping tiers sum their contributions.
 */
function computeTieredCommission(amount: number, tiers: CommissionTier[]): number {
    let commission = 0;

    for (const tier of tiers) {
        const from = tier.from;
        const to = tier.to ?? Infinity;

        if (amount <= from) continue;

        const taxable = Math.min(amount, to) - from;
        commission += (taxable * tier.rate) / 100;
    }

    return commission;
}
