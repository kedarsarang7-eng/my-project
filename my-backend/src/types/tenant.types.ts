// ============================================================================
// TypeScript Types — Tenant / Business Profile
// ============================================================================

/**
 * Canonical business types used by backend permission layer.
 * Keep aliases in normalizeBusinessType() for legacy/client variants.
 */
export enum BusinessType {
    GROCERY = 'grocery',
    PHARMACY = 'pharmacy',
    RESTAURANT = 'restaurant',
    CLOTHING = 'clothing',
    ELECTRONICS = 'electronics',
    MOBILE_SHOP = 'mobile_shop',
    COMPUTER_SHOP = 'computer_shop',
    HARDWARE = 'hardware',
    SERVICE = 'service',
    WHOLESALE = 'wholesale',
    PETROL_PUMP = 'petrol_pump',
    VEGETABLES_BROKER = 'vegetables_broker',
    CLINIC = 'clinic',
    BOOK_STORE = 'book_store',
    JEWELLERY = 'jewellery',
    AUTO_PARTS = 'auto_parts',
    DECORATION_CATERING = 'decoration_catering',
    SCHOOL_ERP = 'school_erp',
    OTHER = 'other',
}

const BUSINESS_TYPE_ALIASES: Record<string, BusinessType> = {
    grocery: BusinessType.GROCERY,
    pharmacy: BusinessType.PHARMACY,
    hardware: BusinessType.HARDWARE,
    petrol_pump: BusinessType.PETROL_PUMP,
    clinic: BusinessType.CLINIC,
    restaurant: BusinessType.RESTAURANT,
    computer_shop: BusinessType.COMPUTER_SHOP,
    mobile_shop: BusinessType.MOBILE_SHOP,
    book_store: BusinessType.BOOK_STORE,
    clothing_store: BusinessType.CLOTHING,
    clothing: BusinessType.CLOTHING,
    jewelry: BusinessType.JEWELLERY,
    jewellery: BusinessType.JEWELLERY,
    auto_parts: BusinessType.AUTO_PARTS,
    decoration_catering: BusinessType.DECORATION_CATERING,
    decoration: BusinessType.DECORATION_CATERING,
    catering: BusinessType.DECORATION_CATERING,
    school_erp: BusinessType.SCHOOL_ERP,
    academic_coaching: BusinessType.SCHOOL_ERP,
    coaching: BusinessType.SCHOOL_ERP,
    tuition: BusinessType.SCHOOL_ERP,
    classes: BusinessType.SCHOOL_ERP,
    schoolerp: BusinessType.SCHOOL_ERP,
    wholesale: BusinessType.WHOLESALE,
    vegetable_broker: BusinessType.VEGETABLES_BROKER,
    vegetables_broker: BusinessType.VEGETABLES_BROKER,
    service: BusinessType.SERVICE,
    electronics: BusinessType.ELECTRONICS,
    other: BusinessType.OTHER,
};

export function normalizeBusinessType(raw: string | null | undefined): BusinessType {
    const normalized = String(raw || '').trim().toLowerCase();
    return BUSINESS_TYPE_ALIASES[normalized] || BusinessType.OTHER;
}

export enum SubscriptionPlan {
    FREE = 'free',
    STARTER = 'starter',
    PROFESSIONAL = 'professional',
    ENTERPRISE = 'enterprise',
    // ── New Plan Tiers (aligned with plan-feature-registry) ──
    BASIC = 'basic',
    PRO = 'pro',
    PREMIUM = 'premium',
}

export enum UserRole {
    SUPER_ADMIN = 'super_admin',       // Platform-wide license management
    OWNER = 'owner',
    ADMIN = 'admin',
    MANAGER = 'manager',
    ACCOUNTANT = 'accountant',
    CASHIER = 'cashier',
    STAFF = 'staff',
    /** Petrol pump floor role — nozzles, dips, fills (JWT must emit this role) */
    PUMPBOY = 'pumpboy',
    VIEWER = 'viewer',                 // (Read only access)
    CHARTERED_ACCOUNTANT = 'ca',       // (Financial access)
    /**
     * Customer-app end-user (Part 4). A consumer who connects to a tenant's
     * shop via the companion app to view their own invoices/payments/dues.
     * Dedicated Cognito group separate from business-owner roles; customer-app
     * endpoints are restricted to this role so business staff can't impersonate
     * the customer-app surface (and vice-versa).
     */
    CUSTOMER = 'customer',
}

export interface Tenant {
    id: string;
    name: string;
    displayName?: string;
    businessType: BusinessType;
    subscriptionPlan: SubscriptionPlan;

    // GST (India)
    gstin?: string;
    pan?: string;
    stateCode?: string;

    // Contact
    phone?: string;
    email?: string;
    address?: Record<string, string>;

    // Settings (JSONB)
    settings: TenantSettings;

    logoUrl?: string;
    subscriptionValidUntil?: Date;

    // ── Plan & Subscription Management (NEW) ───────────────────────────────
    /** Monthly or yearly billing cycle */
    billingCycle?: 'monthly' | 'yearly';
    /** When the current plan started */
    planStartDate?: Date;
    /** Current plan status */
    planStatus?: 'active' | 'expired' | 'trial' | 'cancelled';
    /** When trial ends (if in trial status) */
    trialEndDate?: Date;
    /** Current month's invoice count for limit enforcement */
    currentMonthInvoiceCount?: number;
    /** Total product count for limit enforcement */
    currentProductCount?: number;
    /** Month-Year for invoice counter reset (MM-YYYY) */
    invoiceCountMonth?: string;

    createdAt: Date;
    updatedAt: Date;
}

export interface TenantSettings {
    currency: string;
    timezone: string;
    fiscalYearStart: number; // month (1-12)
    invoicePrefix?: string;
    enableGst: boolean;
    enableMultiCurrency: boolean;
    /** Default locale for this tenant (en | hi | mr | gu | ...) */
    locale?: string;
}

export interface TenantUser {
    id: string;
    tenantId: string;
    cognitoSub: string;
    email: string;
    fullName?: string;
    phone?: string;
    role: UserRole;
    permissions: string[];
    isActive: boolean;
    createdAt: Date;
}

/**
 * Decoded JWT payload from Cognito.
 * Injected into the request context by the auth middleware.
 */
export interface AuthContext {
    sub: string;           // Cognito user ID
    email: string;
    tenantId: string;      // custom:tenant_id
    businessId?: string;   // custom:business_id (alias for tenant_id)
    role: UserRole;        // custom:role
    userRole?: string;     // custom:user_role (admin|staff|manager|ca)
    businessType: BusinessType; // custom:business_type
    licenseStatus?: string; // custom:license_status
    planStatus?: string;   // custom:plan_status (active|expired|trial|cancelled)
    deviceId?: string;     // X-Device-Id header (Phase 3)
    planTier?: string;     // Resolved PlanTier from tenant record
    allowedFeatures?: string[]; // Cached feature keys from manifest
}
