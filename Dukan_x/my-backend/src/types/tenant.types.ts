// ============================================================================
// TypeScript Types — Tenant / Business Profile
// ============================================================================

/**
 * All 14 supported business types.
 * Mirrors the Flutter `BusinessType` enum exactly.
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
    OTHER = 'other',
}

export enum SubscriptionPlan {
    FREE = 'free',
    STARTER = 'starter',
    PROFESSIONAL = 'professional',
    ENTERPRISE = 'enterprise',
}

export enum UserRole {
    OWNER = 'owner',
    ADMIN = 'admin',
    MANAGER = 'manager',
    ACCOUNTANT = 'accountant',
    CASHIER = 'cashier',
    STAFF = 'staff',
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
    role: UserRole;        // custom:role
    businessType: BusinessType; // custom:business_type
}
