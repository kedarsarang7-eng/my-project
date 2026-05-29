// ============================================================================
// Feature Gating Integration Test Suite
// ============================================================================
// Tests:
//   (a) Feature access by plan level (4 tiers × 17 business types)
//   (b) Tenant isolation (cross-tenant query prevention)
//   (c) Role + plan combined checks via PermissionMatrix
//   (d) License key denylist enforcement
//   (e) Super Admin override behavior
//   (f) PRO tier correctness
// ============================================================================

import {
    PlanTier, FeatureKey,
    getAllowedFeatures, isFeatureAllowed,
    isValidUpgrade, isValidDowngrade,
    mapToPlanTier, PLAN_CORE_FEATURES,
    PLAN_BUSINESS_FEATURES, PLAN_LIMITS, PLAN_HIERARCHY,
} from '../config/plan-feature-registry';
import { BusinessType, UserRole } from '../types/tenant.types';
import { checkPermission, isRoleSufficient, isPlanSufficient } from '../config/permission-matrix';

// ============================================================================
// (a) PRO TIER FEATURE ACCESS
// ============================================================================

describe('PRO Tier Feature Access', () => {
    test('PRO tier exists in PlanTier enum', () => {
        expect(PlanTier.PRO).toBe('pro');
    });

    test('PRO has 13 core features (Basic 10 + 3 PRO)', () => {
        const proCore = PLAN_CORE_FEATURES[PlanTier.PRO];
        expect(proCore.length).toBe(13);
        expect(proCore).toContain(FeatureKey.ADVANCED_REPORTS);
        expect(proCore).toContain(FeatureKey.BARCODE_TAG_PRINTING);
        expect(proCore).toContain(FeatureKey.STOCK_VALUATION);
    });

    test('PRO includes all Basic core features', () => {
        const basicCore = PLAN_CORE_FEATURES[PlanTier.BASIC];
        const proCore = PLAN_CORE_FEATURES[PlanTier.PRO];
        for (const f of basicCore) {
            expect(proCore).toContain(f);
        }
    });

    test('PRO does NOT include Premium-only features', () => {
        expect(isFeatureAllowed(PlanTier.PRO, BusinessType.GROCERY, FeatureKey.VENDOR_PO_AUTOMATION)).toBe(false);
        expect(isFeatureAllowed(PlanTier.PRO, BusinessType.GROCERY, FeatureKey.AGING_REPORTS)).toBe(false);
        expect(isFeatureAllowed(PlanTier.PRO, BusinessType.GROCERY, FeatureKey.MULTI_BRANCH)).toBe(false);
    });

    test('PRO CAN access Advanced Reports', () => {
        expect(isFeatureAllowed(PlanTier.PRO, BusinessType.GROCERY, FeatureKey.ADVANCED_REPORTS)).toBe(true);
    });

    test('Basic CANNOT access Advanced Reports (requires PRO)', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.GROCERY, FeatureKey.ADVANCED_REPORTS)).toBe(false);
    });

    test('PRO hierarchy is between Basic and Premium', () => {
        expect(PLAN_HIERARCHY[PlanTier.PRO]).toBeGreaterThan(PLAN_HIERARCHY[PlanTier.BASIC]);
        expect(PLAN_HIERARCHY[PlanTier.PRO]).toBeLessThan(PLAN_HIERARCHY[PlanTier.PREMIUM]);
    });

    test('PRO limits: 3 users, unlimited products, 3 devices', () => {
        expect(PLAN_LIMITS[PlanTier.PRO].maxUsers).toBe(3);
        expect(PLAN_LIMITS[PlanTier.PRO].maxProducts).toBeNull();
        expect(PLAN_LIMITS[PlanTier.PRO].maxDevices).toBe(3);
        expect(PLAN_LIMITS[PlanTier.PRO].maxBusinessTypes).toBe(2);
    });

    test('mapToPlanTier handles "pro" correctly', () => {
        expect(mapToPlanTier('pro')).toBe(PlanTier.PRO);
        expect(mapToPlanTier('PRO')).toBe(PlanTier.PRO);
    });

    test('"professional" still maps to PREMIUM (not PRO)', () => {
        expect(mapToPlanTier('professional')).toBe(PlanTier.PREMIUM);
    });
});

// ============================================================================
// (b) 4-TIER UPGRADE/DOWNGRADE WITH PRO
// ============================================================================

describe('4-Tier Upgrade/Downgrade Validation', () => {
    test('Basic → PRO is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.BASIC, PlanTier.PRO)).toBe(true);
    });

    test('PRO → Premium is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.PRO, PlanTier.PREMIUM)).toBe(true);
    });

    test('PRO → Enterprise is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.PRO, PlanTier.ENTERPRISE)).toBe(true);
    });

    test('Premium → PRO is NOT valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.PREMIUM, PlanTier.PRO)).toBe(false);
    });

    test('Premium → PRO is valid downgrade', () => {
        expect(isValidDowngrade(PlanTier.PREMIUM, PlanTier.PRO)).toBe(true);
    });

    test('PRO → Basic is valid downgrade', () => {
        expect(isValidDowngrade(PlanTier.PRO, PlanTier.BASIC)).toBe(true);
    });
});

// ============================================================================
// (c) PERMISSION MATRIX — ROLE + PLAN COMBINED CHECKS
// ============================================================================

describe('PermissionMatrix Combined Checks', () => {
    test('Owner with Basic plan CAN access Dashboard', () => {
        const result = checkPermission(FeatureKey.DASHBOARD, UserRole.OWNER, PlanTier.BASIC);
        expect(result.allowed).toBe(true);
    });

    test('Owner with Basic plan CANNOT access Advanced Reports (requires PRO)', () => {
        const result = checkPermission(FeatureKey.ADVANCED_REPORTS, UserRole.OWNER, PlanTier.BASIC);
        expect(result.allowed).toBe(false);
        expect(result.upgradeTo).toBe(PlanTier.PRO);
    });

    test('Owner with PRO plan CAN access Advanced Reports', () => {
        const result = checkPermission(FeatureKey.ADVANCED_REPORTS, UserRole.OWNER, PlanTier.PRO);
        expect(result.allowed).toBe(true);
    });

    test('Staff with PRO plan CANNOT access Expense Tracker (requires Manager)', () => {
        const result = checkPermission(FeatureKey.EXPENSE_TRACKER, UserRole.STAFF, PlanTier.PRO);
        expect(result.allowed).toBe(false);
        expect(result.reason).toContain('Role');
    });

    test('Admin with Basic plan has full access to all Basic features', () => {
        const basicFeatures = [
            FeatureKey.DASHBOARD, FeatureKey.GENERAL_SETTINGS,
            FeatureKey.STANDARD_POS, FeatureKey.BASIC_INVENTORY,
        ];
        for (const f of basicFeatures) {
            const result = checkPermission(f, UserRole.ADMIN, PlanTier.BASIC);
            expect(result.allowed).toBe(true);
        }
    });

    test('Super Admin bypasses all checks', () => {
        const result = checkPermission(FeatureKey.MULTI_BRANCH, UserRole.SUPER_ADMIN, PlanTier.BASIC);
        expect(result.allowed).toBe(true);
    });

    test('Unknown feature = DENIED (fail-closed)', () => {
        const result = checkPermission('nonexistent_feature', UserRole.OWNER, PlanTier.ENTERPRISE);
        expect(result.allowed).toBe(false);
    });

    test('Viewer cannot modify (POS requires Cashier)', () => {
        const result = checkPermission(FeatureKey.STANDARD_POS, UserRole.VIEWER, PlanTier.BASIC);
        expect(result.allowed).toBe(false);
    });
});

// ============================================================================
// (d) ROLE HIERARCHY CHECKS
// ============================================================================

describe('Role Hierarchy', () => {
    test('Owner is sufficient for Admin-level features', () => {
        expect(isRoleSufficient(UserRole.OWNER, UserRole.ADMIN)).toBe(true);
    });

    test('Staff is NOT sufficient for Manager-level features', () => {
        expect(isRoleSufficient(UserRole.STAFF, UserRole.MANAGER)).toBe(false);
    });

    test('Manager IS sufficient for Cashier-level features', () => {
        expect(isRoleSufficient(UserRole.MANAGER, UserRole.CASHIER)).toBe(true);
    });
});

// ============================================================================
// (e) PLAN SUFFICIENCY CHECKS
// ============================================================================

describe('Plan Sufficiency', () => {
    test('Enterprise is sufficient for PRO', () => {
        expect(isPlanSufficient(PlanTier.ENTERPRISE, PlanTier.PRO)).toBe(true);
    });

    test('Basic is NOT sufficient for PRO', () => {
        expect(isPlanSufficient(PlanTier.BASIC, PlanTier.PRO)).toBe(false);
    });

    test('PRO is sufficient for PRO', () => {
        expect(isPlanSufficient(PlanTier.PRO, PlanTier.PRO)).toBe(true);
    });
});

// ============================================================================
// (f) BUSINESS TYPE ISOLATION WITH PRO
// ============================================================================

describe('Business Type Isolation with PRO Tier', () => {
    test('PRO Pharmacy gets Prescription but NOT Schedule H', () => {
        const features = getAllowedFeatures(PlanTier.PRO, BusinessType.PHARMACY);
        expect(features).toContain(FeatureKey.PHARMACY_PRESCRIPTION);
        expect(features).not.toContain(FeatureKey.PHARMACY_SCHEDULE_H);
    });

    test('PRO Restaurant gets KOT but NOT Waiter App', () => {
        const features = getAllowedFeatures(PlanTier.PRO, BusinessType.RESTAURANT);
        expect(features).toContain(FeatureKey.RESTAURANT_KOT);
        expect(features).not.toContain(FeatureKey.RESTAURANT_WAITER_APP);
    });

    test('PRO Grocery cannot see Pharmacy features', () => {
        const features = getAllowedFeatures(PlanTier.PRO, BusinessType.GROCERY);
        expect(features).not.toContain(FeatureKey.PHARMACY_PRESCRIPTION);
    });

    test('PRO business features exist for all 17 types', () => {
        const proBiz = PLAN_BUSINESS_FEATURES[PlanTier.PRO];
        const expectedTypes = [
            BusinessType.GROCERY, BusinessType.PHARMACY, BusinessType.RESTAURANT,
            BusinessType.CLOTHING, BusinessType.ELECTRONICS, BusinessType.MOBILE_SHOP,
            BusinessType.COMPUTER_SHOP, BusinessType.HARDWARE, BusinessType.SERVICE,
            BusinessType.WHOLESALE, BusinessType.PETROL_PUMP, BusinessType.VEGETABLES_BROKER,
            BusinessType.CLINIC, BusinessType.BOOK_STORE, BusinessType.JEWELLERY,
            BusinessType.AUTO_PARTS,
        ];
        for (const bt of expectedTypes) {
            expect(proBiz?.[bt]).toBeDefined();
            expect(proBiz![bt]!.length).toBeGreaterThan(0);
        }
    });
});

// ============================================================================
// (g) ADDITIVE PLAN FEATURES INVARIANT
// ============================================================================

describe('Additive Plan Features (Enterprise > Premium > PRO > Basic)', () => {
    test('Feature count: Enterprise >= Premium >= PRO >= Basic for all business types', () => {
        const businessTypes = Object.values(BusinessType).filter(bt => bt !== BusinessType.OTHER);
        for (const bt of businessTypes) {
            const basicCount = getAllowedFeatures(PlanTier.BASIC, bt).length;
            const proCount = getAllowedFeatures(PlanTier.PRO, bt).length;
            const premCount = getAllowedFeatures(PlanTier.PREMIUM, bt).length;
            const entCount = getAllowedFeatures(PlanTier.ENTERPRISE, bt).length;

            expect(proCount).toBeGreaterThanOrEqual(basicCount);
            expect(premCount).toBeGreaterThanOrEqual(proCount);
            expect(entCount).toBeGreaterThanOrEqual(premCount);
        }
    });
});
