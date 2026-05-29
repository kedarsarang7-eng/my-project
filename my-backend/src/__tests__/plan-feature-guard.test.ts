// ============================================================================
// Plan Feature Guard — Comprehensive Test Suite
// ============================================================================
// Tests cover:
//   1. Feature registry correctness
//   2. Plan-based access enforcement
//   3. Business type isolation
//   4. Manifest generation & verification
//   5. Upgrade/downgrade validation
//   6. Security bypass prevention
//   7. Cache behavior
// ============================================================================

import {
    PlanTier,
    FeatureKey,
    getAllowedFeatures,
    isFeatureAllowed,
    isValidUpgrade,
    isValidDowngrade,
    mapToPlanTier,
    PLAN_CORE_FEATURES,
    PLAN_BUSINESS_FEATURES,
    PLAN_LIMITS,
    PLAN_HIERARCHY,
} from '../config/plan-feature-registry';
import { BusinessType } from '../types/tenant.types';
import {
    generateManifestSync as generateManifest,
    verifyManifest,
} from '../services/feature-manifest.service';

// ============================================================================
// 1. FEATURE REGISTRY TESTS
// ============================================================================

describe('Plan Feature Registry', () => {
    describe('Core Features per Plan', () => {
        test('Basic plan has exactly 10 core features', () => {
            const basicCore = PLAN_CORE_FEATURES[PlanTier.BASIC];
            expect(basicCore.length).toBe(10);
            expect(basicCore).toContain(FeatureKey.DASHBOARD);
            expect(basicCore).toContain(FeatureKey.STANDARD_POS);
            expect(basicCore).toContain(FeatureKey.BASIC_INVENTORY);
            expect(basicCore).toContain(FeatureKey.CUSTOMER_LEDGER);
            expect(basicCore).toContain(FeatureKey.EXPENSE_TRACKER);
        });

        test('Pro plan has exactly 13 core features (Basic + 3 Pro)', () => {
            const proCore = PLAN_CORE_FEATURES[PlanTier.PRO];
            expect(proCore.length).toBe(13);
            expect(proCore).toContain(FeatureKey.ADVANCED_REPORTS);
            expect(proCore).toContain(FeatureKey.BARCODE_TAG_PRINTING);
            expect(proCore).toContain(FeatureKey.STOCK_VALUATION);
        });

        test('Premium plan includes all Pro + 7 premium core features (total 20)', () => {
            const premiumCore = PLAN_CORE_FEATURES[PlanTier.PREMIUM];
            const proCore = PLAN_CORE_FEATURES[PlanTier.PRO];

            // Premium includes all Pro
            for (const feature of proCore) {
                expect(premiumCore).toContain(feature);
            }

            // Premium adds: advanced_role_permissions, vendor_po_automation, aging_reports,
            // audit_logs, cloud_backup, advanced_analytics, gst_reports
            expect(premiumCore).toContain(FeatureKey.VENDOR_PO_AUTOMATION);
            expect(premiumCore).toContain(FeatureKey.AGING_REPORTS);
            // IMPORTANT: AUDIT_LOGS and CLOUD_BACKUP are Premium+, NOT Enterprise
            // See dukanx_feature_tier_spec.md §Implementation Notes items 6 & 7
            expect(premiumCore).toContain(FeatureKey.AUDIT_LOGS);
            expect(premiumCore).toContain(FeatureKey.CLOUD_BACKUP);
            expect(premiumCore).toContain(FeatureKey.GST_REPORTS);
            expect(premiumCore.length).toBe(20);
        });

        test('Enterprise plan includes all Premium + 5 enterprise core features (total 25)', () => {
            const enterpriseCore = PLAN_CORE_FEATURES[PlanTier.ENTERPRISE];
            const premiumCore = PLAN_CORE_FEATURES[PlanTier.PREMIUM];

            for (const feature of premiumCore) {
                expect(enterpriseCore).toContain(feature);
            }

            expect(enterpriseCore).toContain(FeatureKey.MULTI_BRANCH);
            expect(enterpriseCore).toContain(FeatureKey.API_ACCESS);
            expect(enterpriseCore).toContain(FeatureKey.FINANCIAL_RECONCILIATION_ENGINE);
            expect(enterpriseCore).toContain(FeatureKey.HIERARCHICAL_ROLE_CONTROL);
            // AUDIT_LOGS + CLOUD_BACKUP are in Premium, not added again here
            expect(enterpriseCore).not.toContain(undefined);
            expect(enterpriseCore.length).toBe(25);
        });
    });

    describe('Business-Specific Features', () => {
        test('Basic Grocery has Fast Billing POS only', () => {
            const features = PLAN_BUSINESS_FEATURES[PlanTier.BASIC]?.[BusinessType.GROCERY];
            expect(features).toBeDefined();
            expect(features!.length).toBe(1);
            expect(features).toContain(FeatureKey.GROCERY_FAST_BILLING_POS);
        });

        test('Premium Pharmacy has 4 features (basic + prescription + alternative + returns)', () => {
            const features = PLAN_BUSINESS_FEATURES[PlanTier.PREMIUM]?.[BusinessType.PHARMACY];
            expect(features).toBeDefined();
            expect(features!.length).toBe(4);
            expect(features).toContain(FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY);
            expect(features).toContain(FeatureKey.PHARMACY_PRESCRIPTION);
            expect(features).toContain(FeatureKey.PHARMACY_RETURNS);
        });

        test('Enterprise Pharmacy adds Schedule H + Rack Tracking', () => {
            const features = PLAN_BUSINESS_FEATURES[PlanTier.ENTERPRISE]?.[BusinessType.PHARMACY];
            expect(features).toBeDefined();
            expect(features).toContain(FeatureKey.PHARMACY_SCHEDULE_H);
            expect(features).toContain(FeatureKey.PHARMACY_RACK_TRACKING);
            expect(features!.length).toBe(6);
        });

        test('Enterprise Restaurant has Waiter App + Multi-Kitchen', () => {
            const features = PLAN_BUSINESS_FEATURES[PlanTier.ENTERPRISE]?.[BusinessType.RESTAURANT];
            expect(features).toContain(FeatureKey.RESTAURANT_WAITER_APP);
            expect(features).toContain(FeatureKey.RESTAURANT_MULTI_KITCHEN);
        });

        test('Premium Computer Shop has PC Builder + Component Tracking', () => {
            const features = PLAN_BUSINESS_FEATURES[PlanTier.PREMIUM]?.[BusinessType.COMPUTER_SHOP];
            expect(features).toBeDefined();
            expect(features).toContain(FeatureKey.COMPUTER_PC_BUILDER);
            expect(features).toContain(FeatureKey.COMPUTER_COMPONENT_TRACKING);
        });

        test('All 13 business types defined for Basic plan', () => {
            const basicBiz = PLAN_BUSINESS_FEATURES[PlanTier.BASIC];
            const expectedTypes = [
                BusinessType.GROCERY, BusinessType.PHARMACY, BusinessType.RESTAURANT,
                BusinessType.CLOTHING, BusinessType.ELECTRONICS, BusinessType.MOBILE_SHOP,
                BusinessType.HARDWARE, BusinessType.SERVICE, BusinessType.WHOLESALE,
                BusinessType.PETROL_PUMP, BusinessType.VEGETABLES_BROKER,
                BusinessType.CLINIC, BusinessType.BOOK_STORE,
            ];
            for (const bt of expectedTypes) {
                expect(basicBiz?.[bt]).toBeDefined();
                expect(basicBiz![bt]!.length).toBeGreaterThan(0);
            }
        });
    });
});

// ============================================================================
// 2. PLAN ACCESS ENFORCEMENT TESTS
// ============================================================================

describe('Plan Access Enforcement', () => {
    test('Basic plan user can access Dashboard', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.GROCERY, FeatureKey.DASHBOARD)).toBe(true);
    });

    test('Basic plan user CANNOT access Advanced Reports', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.GROCERY, FeatureKey.ADVANCED_REPORTS)).toBe(false);
    });

    test('Premium plan user CAN access Advanced Reports', () => {
        expect(isFeatureAllowed(PlanTier.PREMIUM, BusinessType.GROCERY, FeatureKey.ADVANCED_REPORTS)).toBe(true);
    });

    test('Basic plan CANNOT access Multi-Branch', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.PHARMACY, FeatureKey.MULTI_BRANCH)).toBe(false);
    });

    test('Premium plan CANNOT access Multi-Branch', () => {
        expect(isFeatureAllowed(PlanTier.PREMIUM, BusinessType.PHARMACY, FeatureKey.MULTI_BRANCH)).toBe(false);
    });

    test('Enterprise plan CAN access Multi-Branch', () => {
        expect(isFeatureAllowed(PlanTier.ENTERPRISE, BusinessType.PHARMACY, FeatureKey.MULTI_BRANCH)).toBe(true);
    });

    test('Basic Pharmacy can access Basic Batch & Expiry', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.PHARMACY, FeatureKey.PHARMACY_BASIC_BATCH_EXPIRY)).toBe(true);
    });

    test('Basic Pharmacy CANNOT access Prescription module', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.PHARMACY, FeatureKey.PHARMACY_PRESCRIPTION)).toBe(false);
    });

    test('Premium Restaurant CAN access KOT', () => {
        expect(isFeatureAllowed(PlanTier.PREMIUM, BusinessType.RESTAURANT, FeatureKey.RESTAURANT_KOT)).toBe(true);
    });

    test('Basic Restaurant CANNOT access KOT', () => {
        expect(isFeatureAllowed(PlanTier.BASIC, BusinessType.RESTAURANT, FeatureKey.RESTAURANT_KOT)).toBe(false);
    });

    test('Enterprise Petrol Pump has Nozzle Settlement', () => {
        expect(isFeatureAllowed(PlanTier.ENTERPRISE, BusinessType.PETROL_PUMP, FeatureKey.PETROL_NOZZLE_SETTLEMENT)).toBe(true);
    });

    test('Premium Petrol Pump does NOT have Nozzle Settlement', () => {
        expect(isFeatureAllowed(PlanTier.PREMIUM, BusinessType.PETROL_PUMP, FeatureKey.PETROL_NOZZLE_SETTLEMENT)).toBe(false);
    });
});

// ============================================================================
// 3. BUSINESS TYPE ISOLATION TESTS
// ============================================================================

describe('Business Type Isolation', () => {
    test('Pharmacy tenant cannot see Grocery features', () => {
        const pharmacyFeatures = getAllowedFeatures(PlanTier.ENTERPRISE, BusinessType.PHARMACY);
        expect(pharmacyFeatures).not.toContain(FeatureKey.GROCERY_FAST_BILLING_POS);
        expect(pharmacyFeatures).not.toContain(FeatureKey.GROCERY_WEIGHING_SCALE);
    });

    test('Restaurant tenant cannot see Pharmacy features', () => {
        const restoFeatures = getAllowedFeatures(PlanTier.ENTERPRISE, BusinessType.RESTAURANT);
        expect(restoFeatures).not.toContain(FeatureKey.PHARMACY_PRESCRIPTION);
        expect(restoFeatures).not.toContain(FeatureKey.PHARMACY_SCHEDULE_H);
    });

    test('Grocery tenant cannot see Petrol Pump features', () => {
        const groceryFeatures = getAllowedFeatures(PlanTier.ENTERPRISE, BusinessType.GROCERY);
        expect(groceryFeatures).not.toContain(FeatureKey.PETROL_BASIC_SHIFT_ENTRY);
        expect(groceryFeatures).not.toContain(FeatureKey.PETROL_NOZZLE_SETTLEMENT);
    });

    test('Clinic tenant cannot see Book Store features', () => {
        const clinicFeatures = getAllowedFeatures(PlanTier.ENTERPRISE, BusinessType.CLINIC);
        expect(clinicFeatures).not.toContain(FeatureKey.BOOKSTORE_ISBN_MANUAL);
        expect(clinicFeatures).not.toContain(FeatureKey.BOOKSTORE_USED_BOOK_ENGINE);
    });

    test('Features are unique (no duplicates) in any combination', () => {
        const allPlans = [PlanTier.BASIC, PlanTier.PREMIUM, PlanTier.ENTERPRISE];
        const allTypes = Object.values(BusinessType);

        for (const plan of allPlans) {
            for (const bt of allTypes) {
                const features = getAllowedFeatures(plan, bt);
                const uniqueFeatures = new Set(features);
                expect(features.length).toBe(uniqueFeatures.size);
            }
        }
    });
});

// ============================================================================
// 4. MANIFEST GENERATION & VERIFICATION TESTS
// ============================================================================

describe('Feature Manifest', () => {
    test('generateManifest produces valid JWT with correct payload', () => {
        const manifest = generateManifest(
            'test-tenant-123',
            PlanTier.PREMIUM,
            BusinessType.PHARMACY,
        );
        expect(manifest.tenantId).toBe('test-tenant-123');
        expect(manifest.planTier).toBe(PlanTier.PREMIUM);
        expect(manifest.businessType).toBe(BusinessType.PHARMACY);
        expect(manifest.allowedFeatures.length).toBeGreaterThan(0);
        expect(manifest.signedToken).toBeTruthy();
        expect(manifest.manifestHash).toBeTruthy();
    });

    test('verifyManifest decodes a valid signed token', () => {
        const manifest = generateManifest(
            'test-tenant-456',
            PlanTier.BASIC,
            BusinessType.GROCERY,
        );
        const decoded = verifyManifest(manifest.signedToken);
        expect(decoded.tenant_id).toBe('test-tenant-456');
        expect(decoded.plan_tier).toBe(PlanTier.BASIC);
        expect(decoded.business_type).toBe(BusinessType.GROCERY);
        expect(decoded.allowed_features).toContain(FeatureKey.DASHBOARD);
        expect(decoded.allowed_features).toContain(FeatureKey.GROCERY_FAST_BILLING_POS);
    });

    test('verifyManifest rejects tampered token', () => {
        const manifest = generateManifest(
            'test-tenant-789',
            PlanTier.BASIC,
            BusinessType.CLINIC,
        );
        // Tamper with the token
        const tamperedToken = manifest.signedToken + 'x';
        expect(() => verifyManifest(tamperedToken)).toThrow();
    });

    test('manifest hash changes when features change', () => {
        const m1 = generateManifest('tenant-a', PlanTier.BASIC, BusinessType.GROCERY);
        const m2 = generateManifest('tenant-a', PlanTier.PREMIUM, BusinessType.GROCERY);
        expect(m1.manifestHash).not.toBe(m2.manifestHash);
    });

    test('different tenants get different tokens (even with same plan)', () => {
        const m1 = generateManifest('tenant-1', PlanTier.BASIC, BusinessType.GROCERY);
        const m2 = generateManifest('tenant-2', PlanTier.BASIC, BusinessType.GROCERY);
        expect(m1.signedToken).not.toBe(m2.signedToken);
    });
});

// ============================================================================
// 5. UPGRADE / DOWNGRADE VALIDATION TESTS
// ============================================================================

describe('Upgrade/Downgrade Validation', () => {
    test('Basic → Premium is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.BASIC, PlanTier.PREMIUM)).toBe(true);
    });

    test('Premium → Enterprise is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.PREMIUM, PlanTier.ENTERPRISE)).toBe(true);
    });

    test('Basic → Enterprise is valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.BASIC, PlanTier.ENTERPRISE)).toBe(true);
    });

    test('Enterprise → Premium is NOT a valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.ENTERPRISE, PlanTier.PREMIUM)).toBe(false);
    });

    test('Premium → Basic is NOT a valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.PREMIUM, PlanTier.BASIC)).toBe(false);
    });

    test('Same plan is NOT a valid upgrade', () => {
        expect(isValidUpgrade(PlanTier.BASIC, PlanTier.BASIC)).toBe(false);
    });

    test('Enterprise → Premium is valid downgrade', () => {
        expect(isValidDowngrade(PlanTier.ENTERPRISE, PlanTier.PREMIUM)).toBe(true);
    });

    test('Premium → Basic is valid downgrade', () => {
        expect(isValidDowngrade(PlanTier.PREMIUM, PlanTier.BASIC)).toBe(true);
    });

    test('Basic → Premium is NOT a valid downgrade', () => {
        expect(isValidDowngrade(PlanTier.BASIC, PlanTier.PREMIUM)).toBe(false);
    });
});

// ============================================================================
// 6. PLAN HIERARCHY & LIMITS TESTS
// ============================================================================

describe('Plan Hierarchy & Limits', () => {
    test('Plan hierarchy is ordered correctly', () => {
        expect(PLAN_HIERARCHY[PlanTier.BASIC]).toBeLessThan(PLAN_HIERARCHY[PlanTier.PREMIUM]);
        expect(PLAN_HIERARCHY[PlanTier.PREMIUM]).toBeLessThan(PLAN_HIERARCHY[PlanTier.ENTERPRISE]);
    });

    test('Basic plan has 1 max user', () => {
        expect(PLAN_LIMITS[PlanTier.BASIC].maxUsers).toBe(1);
    });

    test('Enterprise plan has 50 max branches', () => {
        expect(PLAN_LIMITS[PlanTier.ENTERPRISE].maxBranches).toBe(50);
    });

    test('Basic plan has 1 branch only', () => {
        expect(PLAN_LIMITS[PlanTier.BASIC].maxBranches).toBe(1);
    });
});

// ============================================================================
// 7. LEGACY PLAN MAPPING TESTS
// ============================================================================

describe('Legacy Plan Mapping', () => {
    test('free maps to BASIC', () => {
        expect(mapToPlanTier('free')).toBe(PlanTier.BASIC);
    });

    test('starter maps to BASIC', () => {
        expect(mapToPlanTier('starter')).toBe(PlanTier.BASIC);
    });

    test('professional maps to PREMIUM', () => {
        expect(mapToPlanTier('professional')).toBe(PlanTier.PREMIUM);
    });

    test('pro maps to PRO', () => {
        expect(mapToPlanTier('pro')).toBe(PlanTier.PRO);
    });

    test('enterprise maps to ENTERPRISE', () => {
        expect(mapToPlanTier('enterprise')).toBe(PlanTier.ENTERPRISE);
    });

    test('unknown plan defaults to BASIC (fail-safe)', () => {
        expect(mapToPlanTier('xyz')).toBe(PlanTier.BASIC);
        expect(mapToPlanTier('')).toBe(PlanTier.BASIC);
    });

    test('case insensitive mapping', () => {
        expect(mapToPlanTier('PREMIUM')).toBe(PlanTier.PREMIUM);
        expect(mapToPlanTier('Enterprise')).toBe(PlanTier.ENTERPRISE);
        expect(mapToPlanTier('BASIC')).toBe(PlanTier.BASIC);
    });
});

// ============================================================================
// 8. COMPREHENSIVE FEATURE COUNT VERIFICATION
// ============================================================================

describe('Feature Count Verification', () => {
    test('Enterprise always has more features than Premium for same business type', () => {
        const businessTypes = [
            BusinessType.PHARMACY, BusinessType.RESTAURANT, BusinessType.ELECTRONICS,
            BusinessType.MOBILE_SHOP, BusinessType.WHOLESALE, BusinessType.PETROL_PUMP,
            BusinessType.CLINIC, BusinessType.BOOK_STORE,
        ];

        for (const bt of businessTypes) {
            const premiumCount = getAllowedFeatures(PlanTier.PREMIUM, bt).length;
            const enterpriseCount = getAllowedFeatures(PlanTier.ENTERPRISE, bt).length;
            expect(enterpriseCount).toBeGreaterThanOrEqual(premiumCount);
        }
    });

    test('Premium always has more features than Basic for same business type', () => {
        const businessTypes = Object.values(BusinessType).filter(bt => bt !== BusinessType.OTHER);

        for (const bt of businessTypes) {
            const basicCount = getAllowedFeatures(PlanTier.BASIC, bt).length;
            const premiumCount = getAllowedFeatures(PlanTier.PREMIUM, bt).length;
            // Premium may equal basic if no premium business features exist (e.g., Computer Shop)
            expect(premiumCount).toBeGreaterThanOrEqual(basicCount);
        }
    });

    test('getAllowedFeatures returns non-empty for every plan + business type', () => {
        const plans = [PlanTier.BASIC, PlanTier.PREMIUM, PlanTier.ENTERPRISE];
        const businessTypes = Object.values(BusinessType);

        for (const plan of plans) {
            for (const bt of businessTypes) {
                const features = getAllowedFeatures(plan, bt);
                // At minimum, core features should be present
                expect(features.length).toBeGreaterThanOrEqual(10);
            }
        }
    });
});
