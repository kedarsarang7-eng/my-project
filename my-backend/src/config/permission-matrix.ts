// ============================================================================
// Permission Matrix — Single Source of Truth for Role + Plan Access
// ============================================================================
// Maps every feature to: { minRole, requiredPlan }
// Both checks must pass on every API call. Owner/Admin have full access
// to all features within their tenant's plan.
// ============================================================================

import { UserRole } from '../types/tenant.types';
import { PlanTier, FeatureKey } from '../config/plan-feature-registry';

export interface PermissionRule {
    minRole: UserRole;
    requiredPlan: PlanTier;
}

// Role hierarchy (higher index = more privileged)
const ROLE_HIERARCHY: Record<string, number> = {
    [UserRole.VIEWER]: 0,
    [UserRole.STAFF]: 1,
    [UserRole.PUMPBOY]: 1,
    [UserRole.CASHIER]: 2,
    [UserRole.ACCOUNTANT]: 3,
    [UserRole.CHARTERED_ACCOUNTANT]: 3,
    [UserRole.MANAGER]: 4,
    [UserRole.ADMIN]: 5,
    [UserRole.OWNER]: 6,
    [UserRole.SUPER_ADMIN]: 99,
};

const PLAN_HIERARCHY: Record<string, number> = {
    [PlanTier.BASIC]: 1,
    [PlanTier.PRO]: 2,
    [PlanTier.PREMIUM]: 3,
    [PlanTier.ENTERPRISE]: 4,
};

/**
 * Permission Matrix: { featureKey: { minRole, requiredPlan } }
 * Owner/Admin = full plan access. Staff/Cashier = restricted.
 */
export const PERMISSION_MATRIX: Record<string, PermissionRule> = {
    // ── Basic Core (all roles, basic plan) ──
    [FeatureKey.DASHBOARD]: { minRole: UserRole.VIEWER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.GENERAL_SETTINGS]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.BASIC },
    [FeatureKey.BASIC_USER_ROLES]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.BASIC },
    [FeatureKey.ACCOUNTING_KHATA]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.BASIC },
    [FeatureKey.BASIC_REPORTING]: { minRole: UserRole.VIEWER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.STANDARD_POS]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.BASIC_INVENTORY]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.CUSTOMER_LEDGER]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.EXPENSE_TRACKER]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.BASIC_REORDER_ALERTS]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },

    // ── PRO Core ──
    [FeatureKey.ADVANCED_REPORTS]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.PRO },
    [FeatureKey.BARCODE_TAG_PRINTING]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.STOCK_VALUATION]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.PRO },

    // ── Premium Core ──
    [FeatureKey.ADVANCED_ROLE_PERMISSIONS]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.VENDOR_PO_AUTOMATION]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.AGING_REPORTS]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.PREMIUM },

    // ── Premium Core (features available from Premium tier) ──
    // NOTE: Per spec §6 & §7, AUDIT_LOGS and CLOUD_BACKUP are Premium+, NOT Enterprise.
    // They are already included in PREMIUM_CORE_FEATURES in plan-feature-registry.ts.
    [FeatureKey.AUDIT_LOGS]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.ADVANCED_ANALYTICS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.CLOUD_BACKUP]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.PREMIUM },
    // F006: ADVANCED_ANALYTICS and GST_REPORTS were missing from this matrix — fail-closed
    // unknown-feature check would deny all users. Both are Premium+ per plan-feature-registry.ts.
    [FeatureKey.GST_REPORTS]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.PREMIUM },

    // ── Enterprise Core ──
    [FeatureKey.MULTI_BRANCH]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.CENTRALIZED_INVENTORY_SYNC]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.API_ACCESS]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.FINANCIAL_RECONCILIATION_ENGINE]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.HIERARCHICAL_ROLE_CONTROL]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },

    // ── Business-Specific (all default to STAFF min, plan varies) ──
    [FeatureKey.GROCERY_FAST_BILLING_POS]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.GROCERY_WEIGHING_SCALE]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.PRO },
    [FeatureKey.GROCERY_ADVANCED_BATCH]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },

    [FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.PHARMACY_PRESCRIPTION]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.PHARMACY_ALTERNATIVE_MEDICINE]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.PHARMACY_RETURNS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.PHARMACY_SCHEDULE_H]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.PHARMACY_RACK_TRACKING]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.RESTAURANT_BASIC_TABLE_MGMT]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.RESTAURANT_KOT]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.RESTAURANT_SPLIT_BILLING]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.RESTAURANT_BOM]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.RESTAURANT_WAITER_APP]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.RESTAURANT_MULTI_KITCHEN]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.CLOTHING_BASIC_MATRIX]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.CLOTHING_FULL_MATRIX]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.CLOTHING_SEASONAL_OFFERS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },

    [FeatureKey.ELECTRONICS_MANUAL_SERIAL]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.ELECTRONICS_WARRANTY]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.ELECTRONICS_REPAIR_TICKET]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.ELECTRONICS_EMI_INTEGRATION]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.ELECTRONICS_IMEI_API]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.MOBILE_IMEI_ENTRY]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.MOBILE_EXCHANGE]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.MOBILE_REPAIR]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.MOBILE_EMI_INTEGRATION]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.MOBILE_IMEI_API]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.COMPUTER_PC_BUILDER]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.COMPUTER_COMPONENT_TRACKING]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.COMPUTER_AMC]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.COMPUTER_SERVICE_DESK]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.HARDWARE_ESTIMATE_TO_INVOICE]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.HARDWARE_MULTI_UOM]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.HARDWARE_DELIVERY_CHALLAN]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.HARDWARE_CONTRACTOR_CREDIT]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.HARDWARE_GATE_PASS]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.SERVICE_BASIC_APPOINTMENT]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.SERVICE_TECHNICIAN_ASSIGNMENT]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PRO },
    [FeatureKey.SERVICE_SUBSCRIPTION_BILLING]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.SERVICE_SLA]: { minRole: UserRole.ADMIN, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.WHOLESALE_BASIC_BULK_ENTRY]: { minRole: UserRole.CASHIER, requiredPlan: PlanTier.BASIC },
    [FeatureKey.WHOLESALE_TIERED_PRICING]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PRO },
    [FeatureKey.WHOLESALE_LOGISTICS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.WHOLESALE_EWAY_BILL]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.WHOLESALE_ADVANCED_AR]: { minRole: UserRole.ACCOUNTANT, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.PETROL_BASIC_SHIFT_ENTRY]: { minRole: UserRole.PUMPBOY, requiredPlan: PlanTier.BASIC },
    [FeatureKey.PETROL_DIP_READING]: { minRole: UserRole.PUMPBOY, requiredPlan: PlanTier.PRO },
    [FeatureKey.PETROL_NOZZLE_SETTLEMENT]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.PETROL_DENSITY_LOSS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.VEGBROKER_BASIC_RATE_ENTRY]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.VEGBROKER_COMMISSION_AUTOMATION]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PRO },
    [FeatureKey.VEGBROKER_FARMER_SETTLEMENT]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.CLINIC_TOKEN_SCREEN]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.CLINIC_BASIC_EMR]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.CLINIC_E_PRESCRIPTION]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.CLINIC_FULL_EMR]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.CLINIC_AUTO_FOLLOWUP]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.BOOKSTORE_ISBN_MANUAL]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.BOOKSTORE_ISBN_AUTOFILL]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.BOOKSTORE_PUBLISHER_FILTERS]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.BOOKSTORE_INSTITUTIONAL_SALES]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.BOOKSTORE_CONSIGNMENT_SETTLEMENT]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.BOOKSTORE_USED_BOOK_ENGINE]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.BOOKSTORE_ACADEMIC_CRM]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.JEWELLERY_PURITY_TRACKING]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.JEWELLERY_MAKING_CHARGES]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.JEWELLERY_HALLMARK]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.JEWELLERY_OLD_GOLD_EXCHANGE]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.JEWELLERY_DAILY_RATE_CARD]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.JEWELLERY_CUSTOM_ORDERS]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },

    [FeatureKey.AUTOPARTS_VEHICLE_LOOKUP]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.BASIC },
    [FeatureKey.AUTOPARTS_OEM_CROSS_REF]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PRO },
    [FeatureKey.AUTOPARTS_FITMENT_GUIDE]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.PREMIUM },
    [FeatureKey.AUTOPARTS_RETURN_WARRANTY]: { minRole: UserRole.MANAGER, requiredPlan: PlanTier.ENTERPRISE },
    [FeatureKey.AUTOPARTS_JOB_CARD]: { minRole: UserRole.STAFF, requiredPlan: PlanTier.ENTERPRISE },
};

/**
 * Check if a role meets the minimum required role.
 */
export function isRoleSufficient(userRole: string, minRole: string): boolean {
    const userLevel = ROLE_HIERARCHY[userRole] ?? -1;
    const requiredLevel = ROLE_HIERARCHY[minRole] ?? 999;
    return userLevel >= requiredLevel;
}

/**
 * Check if a plan meets the minimum required plan.
 */
export function isPlanSufficient(userPlan: string, requiredPlan: string): boolean {
    const userLevel = PLAN_HIERARCHY[userPlan] ?? 0;
    const requiredLevel = PLAN_HIERARCHY[requiredPlan] ?? 999;
    return userLevel >= requiredLevel;
}

/**
 * Combined permission check: both role AND plan must be sufficient.
 * Owner/Admin automatically pass role checks for all features in their plan.
 */
export function checkPermission(
    feature: string,
    userRole: string,
    userPlan: string,
): { allowed: boolean; reason?: string; upgradeTo?: string } {
    // Super Admin bypasses everything
    if (userRole === UserRole.SUPER_ADMIN) {
        return { allowed: true };
    }

    const rule = PERMISSION_MATRIX[feature];
    if (!rule) {
        // Unknown feature = DENY (fail-closed)
        return { allowed: false, reason: `Unknown feature: ${feature}` };
    }

    // Check plan first
    if (!isPlanSufficient(userPlan, rule.requiredPlan)) {
        return {
            allowed: false,
            reason: `Upgrade to ${rule.requiredPlan} to access "${feature}".`,
            upgradeTo: rule.requiredPlan,
        };
    }

    // Owner/Admin have full access within their plan
    if (userRole === UserRole.OWNER || userRole === UserRole.ADMIN) {
        return { allowed: true };
    }

    // Check role
    if (!isRoleSufficient(userRole, rule.minRole)) {
        return {
            allowed: false,
            reason: `Role "${userRole}" cannot access "${feature}". Minimum: ${rule.minRole}.`,
        };
    }

    return { allowed: true };
}
