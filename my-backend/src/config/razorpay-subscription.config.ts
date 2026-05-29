import { config } from '../config/environment';
// ============================================================================
// Razorpay Subscription Configuration
// ============================================================================
// Maps DukanX PlanTiers to Razorpay Plan IDs for all billing cycles.
// These plan IDs must be created in Razorpay Dashboard first.
//
// Pricing (confirmed):
//   Basic:      ₹249/mo | ₹699/3mo | ₹1,299/6mo | ₹2,399/12mo | ₹4,299/2yr | ₹5,999/3yr
//   Pro:        ₹499/mo | ₹1,399/3mo | ₹2,699/6mo | ₹4,999/12mo | ₹8,999/2yr | ₹12,999/3yr
//   Premium:    ₹999/mo | ₹2,799/3mo | ₹5,299/6mo | ₹9,999/12mo | ₹17,999/2yr | ₹24,999/3yr
//   Enterprise: ₹1,999/mo | ₹5,499/3mo | ₹10,499/6mo | ₹19,999/12mo | ₹35,999/2yr | ₹49,999/3yr
//   Offline Lifetime: Basic ₹4,999 | Pro ₹9,999 | Premium ₹19,999 | Enterprise ₹39,999
// ============================================================================

import { PlanTier } from './plan-feature-registry';

export enum BillingCycle {
    MONTHLY = 'monthly',       // 1 month
    QUARTERLY = 'quarterly',   // 3 months
    BIANNUAL = 'biannual',     // 6 months
    YEARLY = 'yearly',         // 12 months
    BIENNIAL = 'biennial',     // 2 years
    TRIENNIAL = 'triennial',   // 3 years
}

/** Number of calendar months each cycle covers — used for proration and expiry. */
export const BILLING_CYCLE_MONTHS: Record<BillingCycle, number> = {
    [BillingCycle.MONTHLY]: 1,
    [BillingCycle.QUARTERLY]: 3,
    [BillingCycle.BIANNUAL]: 6,
    [BillingCycle.YEARLY]: 12,
    [BillingCycle.BIENNIAL]: 24,
    [BillingCycle.TRIENNIAL]: 36,
};

export interface RazorpayPlanMapping {
    planId: PlanTier;
    billingCycle: BillingCycle;
    razorpayPlanId: string;
    priceInPaise: number;   // Total price for the cycle period (not per-month)
    displayPrice: string;
    months: number;         // How many months this cycle covers
    effectiveMonthlyPaise: number; // priceInPaise / months — for comparison UI
}

// ── Razorpay Plan IDs (REPLACE with actual IDs from Razorpay Dashboard) ─────
export const RAZORPAY_PLAN_MAPPING: Record<PlanTier, Record<BillingCycle, RazorpayPlanMapping>> = {
    // ── BASIC ────────────────────────────────────────────────────────────────
    [PlanTier.BASIC]: {
        [BillingCycle.MONTHLY]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.MONTHLY, months: 1,
            razorpayPlanId: config.payment.plans.basicMonthly || 'plan_basic_monthly_dummy',
            priceInPaise: 24900,         // ₹249
            displayPrice: '₹249/month',
            effectiveMonthlyPaise: 24900,
        },
        [BillingCycle.QUARTERLY]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.QUARTERLY, months: 3,
            razorpayPlanId: config.payment.plans.basicQuarterly || 'plan_basic_quarterly_dummy',
            priceInPaise: 69900,         // ₹699 (save ₹48)
            displayPrice: '₹699/3 months (Save ₹48)',
            effectiveMonthlyPaise: 23300,
        },
        [BillingCycle.BIANNUAL]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.BIANNUAL, months: 6,
            razorpayPlanId: config.payment.plans.basicBiannual || 'plan_basic_biannual_dummy',
            priceInPaise: 129900,        // ₹1,299 (save ₹195)
            displayPrice: '₹1,299/6 months (Save ₹195)',
            effectiveMonthlyPaise: 21650,
        },
        [BillingCycle.YEARLY]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.YEARLY, months: 12,
            razorpayPlanId: config.payment.plans.basicYearly || 'plan_basic_yearly_dummy',
            priceInPaise: 239900,        // ₹2,399 (save ₹589)
            displayPrice: '₹2,399/year (Save ₹589)',
            effectiveMonthlyPaise: 19992,
        },
        [BillingCycle.BIENNIAL]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.BIENNIAL, months: 24,
            razorpayPlanId: config.payment.plans.basicBiennial || 'plan_basic_biennial_dummy',
            priceInPaise: 429900,        // ₹4,299
            displayPrice: '₹4,299/2 years',
            effectiveMonthlyPaise: 17913,
        },
        [BillingCycle.TRIENNIAL]: {
            planId: PlanTier.BASIC, billingCycle: BillingCycle.TRIENNIAL, months: 36,
            razorpayPlanId: config.payment.plans.basicTriennial || 'plan_basic_triennial_dummy',
            priceInPaise: 599900,        // ₹5,999
            displayPrice: '₹5,999/3 years',
            effectiveMonthlyPaise: 16664,
        },
    },
    // ── PRO ──────────────────────────────────────────────────────────────────
    [PlanTier.PRO]: {
        [BillingCycle.MONTHLY]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.MONTHLY, months: 1,
            razorpayPlanId: config.payment.plans.proMonthly || 'plan_pro_monthly_dummy',
            priceInPaise: 49900,         // ₹499
            displayPrice: '₹499/month',
            effectiveMonthlyPaise: 49900,
        },
        [BillingCycle.QUARTERLY]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.QUARTERLY, months: 3,
            razorpayPlanId: config.payment.plans.proQuarterly || 'plan_pro_quarterly_dummy',
            priceInPaise: 139900,        // ₹1,399
            displayPrice: '₹1,399/3 months',
            effectiveMonthlyPaise: 46633,
        },
        [BillingCycle.BIANNUAL]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.BIANNUAL, months: 6,
            razorpayPlanId: config.payment.plans.proBiannual || 'plan_pro_biannual_dummy',
            priceInPaise: 269900,        // ₹2,699
            displayPrice: '₹2,699/6 months',
            effectiveMonthlyPaise: 44983,
        },
        [BillingCycle.YEARLY]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.YEARLY, months: 12,
            razorpayPlanId: config.payment.plans.proYearly || 'plan_pro_yearly_dummy',
            priceInPaise: 499900,        // ₹4,999
            displayPrice: '₹4,999/year',
            effectiveMonthlyPaise: 41658,
        },
        [BillingCycle.BIENNIAL]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.BIENNIAL, months: 24,
            razorpayPlanId: config.payment.plans.proBiennial || 'plan_pro_biennial_dummy',
            priceInPaise: 899900,        // ₹8,999
            displayPrice: '₹8,999/2 years',
            effectiveMonthlyPaise: 37496,
        },
        [BillingCycle.TRIENNIAL]: {
            planId: PlanTier.PRO, billingCycle: BillingCycle.TRIENNIAL, months: 36,
            razorpayPlanId: config.payment.plans.proTriennial || 'plan_pro_triennial_dummy',
            priceInPaise: 1299900,       // ₹12,999
            displayPrice: '₹12,999/3 years',
            effectiveMonthlyPaise: 36108,
        },
    },
    // ── PREMIUM ───────────────────────────────────────────────────────────────
    [PlanTier.PREMIUM]: {
        [BillingCycle.MONTHLY]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.MONTHLY, months: 1,
            razorpayPlanId: config.payment.plans.premiumMonthly || 'plan_premium_monthly_dummy',
            priceInPaise: 99900,         // ₹999
            displayPrice: '₹999/month',
            effectiveMonthlyPaise: 99900,
        },
        [BillingCycle.QUARTERLY]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.QUARTERLY, months: 3,
            razorpayPlanId: config.payment.plans.premiumQuarterly || 'plan_premium_quarterly_dummy',
            priceInPaise: 279900,        // ₹2,799
            displayPrice: '₹2,799/3 months',
            effectiveMonthlyPaise: 93300,
        },
        [BillingCycle.BIANNUAL]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.BIANNUAL, months: 6,
            razorpayPlanId: config.payment.plans.premiumBiannual || 'plan_premium_biannual_dummy',
            priceInPaise: 529900,        // ₹5,299
            displayPrice: '₹5,299/6 months',
            effectiveMonthlyPaise: 88317,
        },
        [BillingCycle.YEARLY]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.YEARLY, months: 12,
            razorpayPlanId: config.payment.plans.premiumYearly || 'plan_premium_yearly_dummy',
            priceInPaise: 999900,        // ₹9,999
            displayPrice: '₹9,999/year',
            effectiveMonthlyPaise: 83325,
        },
        [BillingCycle.BIENNIAL]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.BIENNIAL, months: 24,
            razorpayPlanId: config.payment.plans.premiumBiennial || 'plan_premium_biennial_dummy',
            priceInPaise: 1799900,       // ₹17,999
            displayPrice: '₹17,999/2 years',
            effectiveMonthlyPaise: 74996,
        },
        [BillingCycle.TRIENNIAL]: {
            planId: PlanTier.PREMIUM, billingCycle: BillingCycle.TRIENNIAL, months: 36,
            razorpayPlanId: config.payment.plans.premiumTriennial || 'plan_premium_triennial_dummy',
            priceInPaise: 2499900,       // ₹24,999
            displayPrice: '₹24,999/3 years',
            effectiveMonthlyPaise: 69442,
        },
    },
    // ── ENTERPRISE ────────────────────────────────────────────────────────────
    [PlanTier.ENTERPRISE]: {
        [BillingCycle.MONTHLY]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.MONTHLY, months: 1,
            razorpayPlanId: config.payment.plans.enterpriseMonthly || 'plan_enterprise_monthly_dummy',
            priceInPaise: 199900,        // ₹1,999
            displayPrice: '₹1,999/month',
            effectiveMonthlyPaise: 199900,
        },
        [BillingCycle.QUARTERLY]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.QUARTERLY, months: 3,
            razorpayPlanId: config.payment.plans.enterpriseQuarterly || 'plan_enterprise_quarterly_dummy',
            priceInPaise: 549900,        // ₹5,499
            displayPrice: '₹5,499/3 months',
            effectiveMonthlyPaise: 183300,
        },
        [BillingCycle.BIANNUAL]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.BIANNUAL, months: 6,
            razorpayPlanId: config.payment.plans.enterpriseBiannual || 'plan_enterprise_biannual_dummy',
            priceInPaise: 1049900,       // ₹10,499
            displayPrice: '₹10,499/6 months',
            effectiveMonthlyPaise: 174983,
        },
        [BillingCycle.YEARLY]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.YEARLY, months: 12,
            razorpayPlanId: config.payment.plans.enterpriseYearly || 'plan_enterprise_yearly_dummy',
            priceInPaise: 1999900,       // ₹19,999
            displayPrice: '₹19,999/year',
            effectiveMonthlyPaise: 166658,
        },
        [BillingCycle.BIENNIAL]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.BIENNIAL, months: 24,
            razorpayPlanId: config.payment.plans.enterpriseBiennial || 'plan_enterprise_biennial_dummy',
            priceInPaise: 3599900,       // ₹35,999
            displayPrice: '₹35,999/2 years',
            effectiveMonthlyPaise: 149996,
        },
        [BillingCycle.TRIENNIAL]: {
            planId: PlanTier.ENTERPRISE, billingCycle: BillingCycle.TRIENNIAL, months: 36,
            razorpayPlanId: config.payment.plans.enterpriseTriennial || 'plan_enterprise_triennial_dummy',
            priceInPaise: 4999900,       // ₹49,999
            displayPrice: '₹49,999/3 years',
            effectiveMonthlyPaise: 138886,
        },
    },
};

// ── Grace Period Configuration ───────────────────────────────────────────────

export interface GracePeriodConfig {
    /** Days before full software lock after payment failure */
    partialLockDays: number;
    /** Days before data is marked for deletion (warning only) */
    warningDays: number;
}

export const GRACE_PERIOD_CONFIG: GracePeriodConfig = {
    partialLockDays: 7,
    warningDays: 30,
};

// ── Proration Configuration ─────────────────────────────────────────────────

export interface ProrationConfig {
    /** Whether to charge prorated amount immediately on upgrade */
    chargeImmediately: boolean;
    /** Whether to apply credits from previous plan on upgrade */
    applyCredits: boolean;
    /** Whether to refund on downgrade (typically no - credits apply to next billing) */
    refundOnDowngrade: boolean;
}

export const PRORATION_CONFIG: ProrationConfig = {
    chargeImmediately: true,
    applyCredits: true,
    refundOnDowngrade: false,
};

// ── Trial Configuration ────────────────────────────────────────────────────

export interface TrialConfig {
    /** Days for free trial */
    durationDays: number;
    /** Plan tier during trial */
    trialPlan: PlanTier;
    /** Notification schedule: days before expiry */
    notificationSchedule: number[];
}

export const TRIAL_CONFIG: TrialConfig = {
    durationDays: 15,
    trialPlan: PlanTier.PREMIUM,
    notificationSchedule: [7, 3, 1], // Notify at 7, 3, and 1 days before expiry
};

// ── Helper Functions ───────────────────────────────────────────────────────

export function getRazorpayPlanId(
    planId: PlanTier,
    billingCycle: BillingCycle,
): string {
    const mapping = RAZORPAY_PLAN_MAPPING[planId]?.[billingCycle];
    if (!mapping) {
        throw new Error(`No Razorpay plan mapping found for ${planId} ${billingCycle}`);
    }
    return mapping.razorpayPlanId;
}

export function getPlanPriceInPaise(
    planId: PlanTier,
    billingCycle: BillingCycle,
): number {
    const mapping = RAZORPAY_PLAN_MAPPING[planId]?.[billingCycle];
    if (!mapping) {
        throw new Error(`No price mapping found for ${planId} ${billingCycle}`);
    }
    return mapping.priceInPaise;
}

export function getPlanDisplayPrice(
    planId: PlanTier,
    billingCycle: BillingCycle,
): string {
    const mapping = RAZORPAY_PLAN_MAPPING[planId]?.[billingCycle];
    if (!mapping) {
        throw new Error(`No display price found for ${planId} ${billingCycle}`);
    }
    return mapping.displayPrice;
}

/** Savings vs paying monthly for the same period. Returns paise. */
export function calculateYearlySavings(planId: PlanTier): number {
    return getSavingsVsMonthly(planId, BillingCycle.YEARLY);
}

/** Generic savings for any cycle vs paying monthly for the same period. Returns paise. */
export function getSavingsVsMonthly(planId: PlanTier, cycle: BillingCycle): number {
    const monthly = RAZORPAY_PLAN_MAPPING[planId][BillingCycle.MONTHLY].priceInPaise;
    const target = RAZORPAY_PLAN_MAPPING[planId][cycle];
    return (monthly * target.months) - target.priceInPaise;
}

export function formatPriceInRupees(paise: number): string {
    const rupees = paise / 100;
    return `₹${rupees.toLocaleString('en-IN')}`;
}
