// ============================================
// TypeScript Interfaces — SLS Data Models
// ============================================

// ---- Enums ----

export type LicenseStatus = 'active' | 'suspended' | 'banned' | 'expired' | 'revoked';
export type LicenseType = 'trial' | 'standard' | 'lifetime';
export type LicenseTier = 'basic' | 'pro' | 'enterprise';
export type AdminRole = 'superadmin' | 'admin';
export type OfflineStatus = 'pending' | 'signed' | 'revoked';
export type LogAction = 'validate' | 'activate' | 'heartbeat' | 'offline_activate';

// ---- Feature Flags ----

export interface FeatureFlags {
    [key: string]: boolean | number | string;
}

// ---- Database Models ----

export interface Admin {
    id: string;
    email: string;
    password_hash: string;
    display_name: string;
    role: AdminRole;
    is_active: boolean;
    last_login_at: Date | null;
    created_at: Date;
    updated_at: Date;
}

export interface Reseller {
    id: string;
    email: string;
    password_hash: string;
    company_name: string;
    display_name: string;
    total_credits: number;
    used_credits: number;
    allowed_tiers: LicenseTier[];
    max_trial_days: number;
    is_active: boolean;
    created_by: string | null;
    last_login_at: Date | null;
    created_at: Date;
    updated_at: Date;
}

export interface License {
    id: string;
    license_key: string;
    key_hash: string;
    status: LicenseStatus;
    license_type: LicenseType;
    tier: LicenseTier;
    feature_flags: FeatureFlags;
    max_devices: number;
    allowed_countries: string[];
    starts_at: Date;
    expires_at: Date | null;
    trial_days: number | null;
    issued_to_email: string | null;
    issued_to_name: string | null;
    issued_by: string | null;
    reseller_id: string | null;
    notes: string | null;
    metadata: Record<string, unknown>;
    is_deleted: boolean;
    deleted_at: Date | null;
    created_at: Date;
    updated_at: Date;
}

export interface HwidBinding {
    id: string;
    license_id: string;
    hwid_hash: string;
    motherboard_id: string | null;
    disk_serial: string | null;
    mac_address: string | null;
    device_name: string | null;
    os_info: string | null;
    is_active: boolean;
    bound_at: Date;
    last_seen_at: Date;
}

export interface ActiveSession {
    id: string;
    license_id: string;
    hwid_binding_id: string | null;
    session_token: string;
    ip_address: string | null;
    country_code: string | null;
    last_heartbeat: Date;
    expires_at: Date;
    created_at: Date;
}

export interface AccessLog {
    id: string;
    license_id: string | null;
    action: LogAction;
    ip_address: string | null;
    country_code: string | null;
    user_agent: string | null;
    hwid_hash: string | null;
    success: boolean;
    failure_reason: string | null;
    response_data: Record<string, unknown>;
    created_at: Date;
}

export interface OfflineActivation {
    id: string;
    license_id: string;
    request_nonce: string;
    request_hwid: string;
    request_data: Record<string, unknown>;
    signed_payload: string | null;
    signature: string | null;
    status: OfflineStatus;
    signed_by: string | null;
    signed_at: Date | null;
    expires_at: Date | null;
    created_at: Date;
}

// ---- API Request/Response DTOs ----

export interface LoginRequest {
    email: string;
    password: string;
}

export interface LoginResponse {
    access_token: string;
    refresh_token: string;
    user: {
        id: string;
        email: string;
        display_name: string;
        role: string;
    };
}

export interface CreateLicenseRequest {
    license_type: LicenseType;
    tier: LicenseTier;
    feature_flags?: FeatureFlags;
    max_devices?: number;
    allowed_countries?: string[];
    expires_at?: string;
    trial_days?: number;
    issued_to_email?: string;
    issued_to_name?: string;
    notes?: string;
}

export interface ValidateRequest {
    license_key: string;
    hwid: string;
    device_name?: string;
    os_info?: string;
}

export interface ValidateResponse {
    valid: boolean;
    license_type: LicenseType;
    tier: LicenseTier;
    feature_flags: FeatureFlags;
    expires_at: string | null;
    session_token: string;
    message?: string;
}

export interface ValidationFailure {
    valid: false;
    error: string;
    code: string;   // machine-readable error code
}

export interface CreateResellerRequest {
    email: string;
    password: string;
    company_name: string;
    display_name: string;
    total_credits: number;
    allowed_tiers: LicenseTier[];
    max_trial_days?: number;
}

export interface ResellerGenerateRequest {
    license_type: LicenseType;
    tier: LicenseTier;
    feature_flags?: FeatureFlags;
    max_devices?: number;
    expires_at?: string;
    trial_days?: number;
    issued_to_email?: string;
    issued_to_name?: string;
}

export interface OfflineSignRequest {
    license_key: string;
    hwid: string;
    nonce: string;
    device_name?: string;
}

export interface DashboardAnalytics {
    total_licenses: number;
    active_licenses: number;
    expired_licenses: number;
    suspended_licenses: number;
    active_sessions_now: number;
    keys_expiring_7_days: number;
    validations_today: number;
    total_resellers: number;
    tier_distribution: { tier: string; count: number }[];
    recent_activity: AccessLog[];
}

// ---- JWT Payload ----

export interface JwtPayload {
    sub: string;    // user id
    email: string;
    role: string;   // admin | superadmin | reseller
    type: 'access' | 'refresh';
    iat?: number;
    exp?: number;
}

// ---- Pagination ----

export interface PaginationQuery {
    page?: number;
    limit?: number;
    sort_by?: string;
    sort_order?: 'asc' | 'desc';
    search?: string;
    status?: LicenseStatus;
    tier?: LicenseTier;
    license_type?: LicenseType;
}

export interface PaginatedResponse<T> {
    data: T[];
    pagination: {
        page: number;
        limit: number;
        total: number;
        total_pages: number;
    };
}

// ---- Customer App Types ----

export interface CustomerShopInfo {
    id: string;
    name: string;
    display_name: string | null;
    business_type: string;
    phone: string | null;
    logo_url: string | null;
    theme_color: string | null;
}

export interface CustomerDashboardResponse {
    shop: CustomerShopInfo;
    total_billed_cents: number;
    total_paid_cents: number;
    outstanding_cents: number;
    total_orders: number;
    recent_orders: CustomerOrderSummary[];
}

export interface CustomerOrderSummary {
    id: string;
    invoice_number: string;
    status: string;
    total_cents: number;
    paid_cents: number;
    balance_cents: number;
    payment_mode: string | null;
    created_at: string;
    items_count: number;
}

export interface CustomerOrderDetail extends CustomerOrderSummary {
    subtotal_cents: number;
    discount_cents: number;
    tax_cents: number;
    notes: string | null;
    items: CustomerOrderItem[];
}

export interface CustomerOrderItem {
    id: string;
    name: string;
    quantity: number;
    unit: string;
    unit_price_cents: number;
    discount_cents: number;
    tax_cents: number;
    total_cents: number;
}

export interface CustomerProductItem {
    id: string;
    name: string;
    display_name: string | null;
    category: string | null;
    brand: string | null;
    unit: string;
    sale_price_cents: number;
    mrp_cents: number | null;
    current_stock: number;
    is_service: boolean;
    description: string | null;
}
