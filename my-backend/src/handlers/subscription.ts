// ============================================================================
// Subscription API Handler — Client-Facing Endpoints
// ============================================================================
// GET  /subscription/current     — Get current subscription details
// GET  /subscription/plans       — List all available plans with pricing
// POST /subscription/upgrade     — Initiate plan upgrade
// POST /subscription/downgrade   — Initiate plan downgrade
// POST /subscription/retry       — Create payment retry link
// GET  /subscription/usage       — Get current usage stats
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { withSoftwareLock } from '../middleware/software-lock';
import { AuthContext, UserRole } from '../types/tenant.types';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
    getSubscriptionContext,
    initiateUpgrade,
    initiateDowngrade,
    createPaymentRetry,
    UpgradeRequest,
    DowngradeRequest,
    SubscriptionError,
} from '../services/subscription.service';
import { getTenantUsage } from '../services/limit-check.service';
import {
    PlanTier,
    PLAN_LIMITS,
    PLAN_CORE_FEATURES,
    PLAN_BUSINESS_FEATURES,
    getAllowedFeatures,
} from '../config/plan-feature-registry';
import {
    BillingCycle,
    RAZORPAY_PLAN_MAPPING,
    calculateYearlySavings,
    formatPriceInRupees,
    TRIAL_CONFIG,
} from '../config/razorpay-subscription.config';

// ── GET /subscription/current ───────────────────────────────────────────────

export const getCurrentSubscription = authorizedHandler(
    [UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CHARTERED_ACCOUNTANT, UserRole.SUPER_ADMIN],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        try {
            const tenantId = auth.tenantId || auth.businessId || '';
            if (!tenantId) {
                return response.error(400, 'MISSING_TENANT', 'Tenant ID not found in token');
            }

            const subscription = await getSubscriptionContext(tenantId);

            // Get usage stats
            const usage = await getTenantUsage(tenantId);

            // F011: Include allowedFeatures so Flutter hasFeature() checks actual feature keys,
            // not just whether the subscription is active.
            const businessType = auth.businessType || subscription.businessType;
            const allowedFeatures = getAllowedFeatures(subscription.currentPlan, businessType as any);

            // Format response
            const result = {
                plan: subscription.currentPlan,
                billingCycle: subscription.currentBillingCycle,
                status: subscription.subscriptionStatus,
                planStartDate: subscription.planStartDate.toISOString(),
                planEndDate: subscription.planEndDate?.toISOString() || null,
                trialEndDate: subscription.trialEndDate?.toISOString() || null,
                gracePeriodEndDate: subscription.gracePeriodEndDate?.toISOString() || null,
                nextBillingDate: subscription.nextBillingDate?.toISOString() || null,
                limits: PLAN_LIMITS[subscription.currentPlan],
                usage,
                isInTrial: subscription.subscriptionStatus === 'trial',
                daysUntilTrialExpiry: subscription.trialEndDate
                    ? Math.max(0, Math.ceil((subscription.trialEndDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)))
                    : null,
                allowedFeatures,
            };

            return response.success(result);
        } catch (error) {
            logger.error('Failed to get subscription', { error, auth: auth.sub });
            return response.error(500, 'INTERNAL_ERROR', 'Failed to retrieve subscription details');
        }
    },
);

// ── GET /subscription/plans ──────────────────────────────────────────────────

export const listPlans = authorizedHandler(
    [UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CHARTERED_ACCOUNTANT, UserRole.SUPER_ADMIN],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        try {
            const tenantId = auth.tenantId || auth.businessId || '';
            const currentPlan = (auth.planTier as PlanTier) || PlanTier.BASIC;
            const businessType = auth.businessType || 'grocery';

            // Build plan comparison list with all 6 billing cycles
            const plans = Object.values(PlanTier).map(tier => {
                const cycles = Object.values(BillingCycle).map(cycle => {
                    const m = RAZORPAY_PLAN_MAPPING[tier][cycle];
                    return {
                        cycle,
                        months: m.months,
                        priceInPaise: m.priceInPaise,
                        displayPrice: m.displayPrice,
                        effectiveMonthlyPaise: m.effectiveMonthlyPaise,
                        savingsVsMonthly: (RAZORPAY_PLAN_MAPPING[tier][BillingCycle.MONTHLY].priceInPaise * m.months) - m.priceInPaise,
                    };
                });
                const limits = PLAN_LIMITS[tier];

                return {
                    id: tier,
                    name: formatPlanName(tier),
                    description: getPlanDescription(tier),
                    current: tier === currentPlan,
                    cycles,
                    limits: {
                        maxUsers: limits.maxUsers,
                        maxProducts: limits.maxProducts,
                        maxBranches: limits.maxBranches,
                        maxDevices: limits.maxDevices,
                        maxBusinessTypes: limits.maxBusinessTypes,
                        maxInvoicesPerMonth: limits.maxInvoicesPerMonth,
                    },
                    features: getAllowedFeatures(tier, businessType as any),
                    canUpgrade: isUpgradeAllowed(currentPlan as PlanTier, tier),
                    canDowngrade: isDowngradeAllowed(currentPlan as PlanTier, tier),
                };
            });

            return response.success({
                plans,
                currentPlan,
                trialConfig: {
                    durationDays: TRIAL_CONFIG.durationDays,
                    trialPlan: TRIAL_CONFIG.trialPlan,
                },
            });
        } catch (error) {
            logger.error('Failed to list plans', { error, auth: auth.sub });
            return response.error(500, 'INTERNAL_ERROR', 'Failed to retrieve plans');
        }
    },
);

// ── POST /subscription/upgrade ─────────────────────────────────────────────

export const upgradeSubscription = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN],
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    withSoftwareLock(async (event: APIGatewayProxyEventV2, ..._args: any[]) => {
        const auth = _args[1] as AuthContext;
        try {
            const tenantId = auth.tenantId || auth.businessId || '';
            const userId = auth.sub || '';

            if (!tenantId) {
                return response.error(400, 'MISSING_TENANT', 'Tenant ID not found in token');
            }

            if (!event.body) {
                return response.error(400, 'MISSING_BODY', 'Request body is required');
            }

            const body = JSON.parse(event.body) as Record<string, unknown>;

            // Validate request
            if (!body.targetPlan || !Object.values(PlanTier).includes(body.targetPlan as PlanTier)) {
                return response.error(400, 'INVALID_PLAN', 'targetPlan must be one of: basic, pro, premium, enterprise');
            }

            if (!body.billingCycle || !Object.values(BillingCycle).includes(body.billingCycle as BillingCycle)) {
                return response.error(400, 'INVALID_CYCLE', 'billingCycle must be one of: monthly, quarterly, biannual, yearly, biennial, triennial');
            }

            const request: UpgradeRequest = {
                targetPlan: body.targetPlan as PlanTier,
                billingCycle: body.billingCycle as BillingCycle,
                immediateCharge: (body.immediateCharge as boolean) !== false,
            };

            const result = await initiateUpgrade(tenantId, userId, request);

            logger.info('Subscription upgrade initiated', {
                tenantId,
                userId,
                from: auth.planTier,
                to: request.targetPlan,
            });

            return response.success({
                success: true,
                message: `Successfully upgraded to ${formatPlanName(request.targetPlan)}`,
                newPlan: result.newPlan,
                billingCycle: result.billingCycle,
                proratedCharge: result.proratedCharge,
                proratedChargeDisplay: formatPriceInRupees(result.proratedCharge),
                nextBillingDate: result.nextBillingDate.toISOString(),
                invoiceUrl: result.invoiceUrl,
            });
        } catch (error) {
            if (error instanceof SubscriptionError) {
                return response.error(400, error.code, error.message, {
                    upgradeRequired: error.upgradeRequired,
                    currentPlan: error.currentPlan,
                    requiredPlan: error.requiredPlan,
                });
            }

            logger.error('Failed to upgrade subscription', { error, auth: auth.sub });
            return response.error(500, 'UPGRADE_FAILED', 'Failed to process upgrade. Please try again or contact support.');
        }
    }),
);

// ── POST /subscription/downgrade ─────────────────────────────────────────────

export const downgradeSubscription = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN],
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    withSoftwareLock(async (event: APIGatewayProxyEventV2, ..._args: any[]) => {
        const auth = _args[1] as AuthContext;
        try {
            const tenantId = auth.tenantId || auth.businessId || '';
            const userId = auth.sub || '';

            if (!tenantId) {
                return response.error(400, 'MISSING_TENANT', 'Tenant ID not found in token');
            }

            if (!event.body) {
                return response.error(400, 'MISSING_BODY', 'Request body is required');
            }

            const body = JSON.parse(event.body) as Record<string, unknown>;

            // Validate request
            if (!body.targetPlan || !Object.values(PlanTier).includes(body.targetPlan as PlanTier)) {
                return response.error(400, 'INVALID_PLAN', 'targetPlan must be one of: basic, pro, premium, enterprise');
            }

            if (!body.billingCycle || !Object.values(BillingCycle).includes(body.billingCycle as BillingCycle)) {
                return response.error(400, 'INVALID_CYCLE', 'billingCycle must be one of: monthly, quarterly, biannual, yearly, biennial, triennial');
            }

            const request: DowngradeRequest = {
                targetPlan: body.targetPlan as PlanTier,
                billingCycle: body.billingCycle as BillingCycle,
                effectiveDate: body.effectiveDate ? new Date(body.effectiveDate as string) : undefined,
            };

            const result = await initiateDowngrade(tenantId, userId, request);

            logger.info('Subscription downgrade scheduled', {
                tenantId,
                userId,
                from: auth.planTier,
                to: request.targetPlan,
                scheduledDate: result.scheduledDate,
            });

            return response.success({
                success: true,
                message: result.message,
                targetPlan: result.targetPlan,
                billingCycle: result.billingCycle,
                scheduledDate: result.scheduledDate.toISOString(),
            });
        } catch (error) {
            if (error instanceof SubscriptionError) {
                return response.error(400, error.code, error.message);
            }

            logger.error('Failed to downgrade subscription', { error, auth: auth.sub });
            return response.error(500, 'DOWNGRADE_FAILED', 'Failed to process downgrade. Please try again or contact support.');
        }
    }),
);

// ── POST /subscription/retry ───────────────────────────────────────────────

export const retryPayment = authorizedHandler(
    [UserRole.ADMIN, UserRole.SUPER_ADMIN],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        try {
            const tenantId = auth.tenantId || auth.businessId || '';
            const userId = auth.sub || '';

            if (!tenantId) {
                return response.error(400, 'MISSING_TENANT', 'Tenant ID not found in token');
            }

            const result = await createPaymentRetry(tenantId, userId);

            return response.success({
                success: true,
                paymentLink: result.paymentLink,
                nextAttemptDate: result.nextAttemptDate?.toISOString(),
                message: result.message,
            });
        } catch (error) {
            if (error instanceof SubscriptionError) {
                return response.error(400, error.code, error.message);
            }

            logger.error('Failed to create payment retry', { error, auth: auth.sub });
            return response.error(500, 'RETRY_FAILED', 'Failed to create payment retry link');
        }
    },
);

// ── GET /subscription/usage ───────────────────────────────────────────────────

export const getUsage = authorizedHandler(
    [UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF, UserRole.CHARTERED_ACCOUNTANT, UserRole.SUPER_ADMIN],
    async (_event: APIGatewayProxyEventV2, _ctx: Context, auth: AuthContext) => {
        try {
            const tenantId = auth.tenantId || auth.businessId || '';

            if (!tenantId) {
                return response.error(400, 'MISSING_TENANT', 'Tenant ID not found in token');
            }

            const usage = await getTenantUsage(tenantId);
            const limits = PLAN_LIMITS[(auth.planTier as PlanTier) || PlanTier.BASIC];

            // Calculate percentages
            const usagePercentages = {
                users: limits.maxUsers ? (usage.currentUsers / limits.maxUsers) * 100 : 0,
                products: limits.maxProducts ? (usage.currentProducts / limits.maxProducts) * 100 : 0,
                invoices: limits.maxInvoicesPerMonth ? (usage.currentMonthInvoices / limits.maxInvoicesPerMonth) * 100 : 0,
                branches: limits.maxBranches ? (usage.currentBranches / limits.maxBranches) * 100 : 0,
            };

            return response.success({
                usage,
                limits,
                percentages: usagePercentages,
                isOverLimit: {
                    users: usagePercentages.users >= 100,
                    products: usagePercentages.products >= 100,
                    invoices: usagePercentages.invoices >= 100,
                },
                billingPeriod: {
                    start: usage.billingPeriodStart,
                    end: usage.billingPeriodEnd,
                },
            });
        } catch (error) {
            logger.error('Failed to get usage', { error, auth: auth.sub });
            return response.error(500, 'INTERNAL_ERROR', 'Failed to retrieve usage stats');
        }
    },
);

// ── Helper Functions ───────────────────────────────────────────────────────

function formatPlanName(tier: PlanTier): string {
    const names: Record<PlanTier, string> = {
        [PlanTier.BASIC]: 'Basic',
        [PlanTier.PRO]: 'Pro',
        [PlanTier.PREMIUM]: 'Premium',
        [PlanTier.ENTERPRISE]: 'Enterprise',
    };
    return names[tier];
}

function getPlanDescription(tier: PlanTier): string {
    const descriptions: Record<PlanTier, string> = {
        [PlanTier.BASIC]: 'Perfect for single-user businesses just getting started',
        [PlanTier.PRO]: 'Ideal for growing businesses with up to 3 users',
        [PlanTier.PREMIUM]: 'Advanced features for established businesses with up to 5 users',
        [PlanTier.ENTERPRISE]: 'Unlimited users and all features for large organizations',
    };
    return descriptions[tier];
}

function isUpgradeAllowed(currentPlan: PlanTier, targetPlan: PlanTier): boolean {
    const hierarchy: Record<PlanTier, number> = {
        [PlanTier.BASIC]: 1,
        [PlanTier.PRO]: 2,
        [PlanTier.PREMIUM]: 3,
        [PlanTier.ENTERPRISE]: 4,
    };
    return hierarchy[targetPlan] > hierarchy[currentPlan];
}

function isDowngradeAllowed(currentPlan: PlanTier, targetPlan: PlanTier): boolean {
    const hierarchy: Record<PlanTier, number> = {
        [PlanTier.BASIC]: 1,
        [PlanTier.PRO]: 2,
        [PlanTier.PREMIUM]: 3,
        [PlanTier.ENTERPRISE]: 4,
    };
    return hierarchy[targetPlan] < hierarchy[currentPlan];
}
