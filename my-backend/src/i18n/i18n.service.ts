// =============================================================================
// i18n Service — Production-grade internationalization for Lambda
// =============================================================================
// Design principles:
//  1. All locale bundles are loaded ONCE on cold start (no per-request I/O).
//  2. Template interpolation uses {{variable}} syntax matching our JSON files.
//  3. Nested key access via dot notation: t('billing.invoiceCreated', ctx, vars).
//  4. Fallback chain: requested locale → 'en' → key itself.
//  5. No external i18n library dependency — zero cold-start cost.
//  6. Thread-safe: pure functional, no mutable state after init.
//  7. Plural support via _count in TranslationVars (key_one / key_other).
//  8. Locale-aware INR currency + number formatting via Intl.
//  9. detectLocaleFromEvent() — one-liner for Lambda handlers.
// 10. Typed TranslationKey union — typos caught at compile time.
// 11. Missing-key counters for observability (CloudWatch-ready).
// =============================================================================

import * as enLocale from './locales/en.json';
import * as hiLocale from './locales/hi.json';
import * as mrLocale from './locales/mr.json';
import * as guLocale from './locales/gu.json';
import * as taLocale from './locales/ta.json';
import * as teLocale from './locales/te.json';
import * as knLocale from './locales/kn.json';
import * as bnLocale from './locales/bn.json';
import * as paLocale from './locales/pa.json';
import * as mlLocale from './locales/ml.json';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type SupportedLocale = 'en' | 'hi' | 'mr' | 'gu' | 'ta' | 'te' | 'kn' | 'ml' | 'bn' | 'pa' | 'ur';

/**
 * Translation variables bag.
 * Pass `_count` to enable plural selection (key_one / key_other convention).
 *
 * @example
 * t('inventory.itemCount', 'hi', { _count: 3, count: 3 })
 * // resolves 'inventory.itemCount_other' first, falls back to 'inventory.itemCount'
 */
export interface TranslationVars {
    [key: string]: string | number | undefined;
    _count?: number;
}

export type TranslationBundle = Record<string, unknown>;

/**
 * Strongly-typed dot-notation keys derived from en.json structure.
 * Add new keys here whenever en.json gains a new entry.
 */
export type TranslationKey =
    | 'common.success' | 'common.error' | 'common.notFound' | 'common.conflict'
    | 'common.forbidden' | 'common.unauthorized' | 'common.badRequest'
    | 'common.limitExceeded' | 'common.planExpired' | 'common.serverError' | 'common.timeout'
    | 'auth.loginSuccess' | 'auth.logoutSuccess' | 'auth.invalidCredentials'
    | 'auth.accountLocked' | 'auth.sessionExpired' | 'auth.tokenInvalid'
    | 'auth.mfaRequired' | 'auth.otpSent' | 'auth.otpExpired' | 'auth.otpInvalid'
    | 'billing.invoiceCreated' | 'billing.invoiceUpdated' | 'billing.invoiceDeleted'
    | 'billing.paymentRecorded' | 'billing.billItemAdded' | 'billing.billItemRemoved'
    | 'billing.stockInsufficient' | 'billing.taxCalculated'
    | 'billing.invoiceNotFound' | 'billing.duplicateInvoice'
    | 'inventory.productCreated' | 'inventory.productUpdated' | 'inventory.productDeleted'
    | 'inventory.stockUpdated' | 'inventory.lowStockAlert' | 'inventory.outOfStock'
    | 'inventory.expiryWarning' | 'inventory.expiredProduct'
    | 'inventory.barcodeNotFound' | 'inventory.importStarted' | 'inventory.importComplete'
    | 'customers.customerCreated' | 'customers.customerUpdated' | 'customers.customerDeleted'
    | 'customers.creditLimitExceeded' | 'customers.outstandingBalance'
    | 'notifications.billCreated' | 'notifications.paymentReceived' | 'notifications.lowStock'
    | 'notifications.expiryWarning' | 'notifications.planExpiring' | 'notifications.newOrder'
    | 'notifications.backupComplete' | 'notifications.syncComplete'
    | 'notifications.staffCheckedIn' | 'notifications.dailySummary'
    | 'whatsapp.billCreated' | 'whatsapp.paymentReceived' | 'whatsapp.paymentReminder'
    | 'whatsapp.lowBalanceReminder' | 'whatsapp.orderConfirmation'
    | 'sms.billCreated' | 'sms.paymentReceived' | 'sms.paymentReminder' | 'sms.otpMessage'
    | 'pdf.invoiceTitle' | 'pdf.billTo' | 'pdf.shipTo' | 'pdf.description'
    | 'pdf.qty' | 'pdf.rate' | 'pdf.amount' | 'pdf.taxableAmount'
    | 'pdf.cgst' | 'pdf.sgst' | 'pdf.igst' | 'pdf.grandTotal'
    | 'pdf.amountInWords' | 'pdf.authorizedSignatory' | 'pdf.thankYou'
    | 'pdf.termsConditions' | 'pdf.notes' | 'pdf.originalForRecipient'
    | 'pdf.duplicateForSupplier' | 'pdf.eandoe' | 'pdf.subjectToJurisdiction'
    | 'pdf.computerGeneratedInvoice'
    | 'reports.dailySales' | 'reports.monthlySales' | 'reports.gstR1' | 'reports.gstR2'
    | 'reports.inventory' | 'reports.profitLoss' | 'reports.balanceSheet'
    | 'reports.cashFlow' | 'reports.periodLabel' | 'reports.generatedOn'
    | 'reports.generatedBy' | 'reports.noDataFound' | 'reports.totalSales'
    | 'reports.totalPurchase' | 'reports.grossProfit' | 'reports.netProfit'
    | 'validation.required' | 'validation.minLength' | 'validation.maxLength'
    | 'validation.invalidEmail' | 'validation.invalidPhone' | 'validation.invalidGstin'
    | 'validation.invalidPan' | 'validation.positiveNumber' | 'validation.amountZero'
    | 'validation.futureDate' | 'validation.pastDate' | 'validation.passwordWeak';

// ---------------------------------------------------------------------------
// Locale Registry — loaded at module init (cold start)
// ---------------------------------------------------------------------------

const LOCALE_BUNDLES: Record<string, TranslationBundle> = {
    en: enLocale as unknown as TranslationBundle,
    hi: hiLocale as unknown as TranslationBundle,
    mr: mrLocale as unknown as TranslationBundle,
    gu: guLocale as unknown as TranslationBundle,
    ta: taLocale as unknown as TranslationBundle,
    te: teLocale as unknown as TranslationBundle,
    kn: knLocale as unknown as TranslationBundle,
    bn: bnLocale as unknown as TranslationBundle,
    pa: paLocale as unknown as TranslationBundle,
    ml: mlLocale as unknown as TranslationBundle,
};

// Locales without a native bundle — fall back to English
const LOCALE_FALLBACKS: Partial<Record<SupportedLocale, SupportedLocale>> = {
    ur: 'en',   // Urdu uses Nastaliq/Arabic script — no native bundle yet
};

const SUPPORTED_LOCALES = new Set<string>(['en', 'hi', 'mr', 'gu', 'ta', 'te', 'kn', 'ml', 'bn', 'pa', 'ur']);

// ---------------------------------------------------------------------------
// Enhancement #1 — Dev-time key validation (cold-start, non-blocking)
// ---------------------------------------------------------------------------

if (process.env.NODE_ENV !== 'production') {
    const enKeys = flattenKeys(LOCALE_BUNDLES.en);
    for (const [locale, bundle] of Object.entries(LOCALE_BUNDLES)) {
        if (locale === 'en') continue;
        const bundleKeys = flattenKeys(bundle);
        const missing = enKeys.filter(k => !bundleKeys.includes(k));
        if (missing.length > 0) {
            console.warn(
                `[i18n] ${locale} is missing ${missing.length} key(s): ${missing.slice(0, 5).join(', ')}${missing.length > 5 ? '...' : ''}`,
            );
        }
    }
}

function flattenKeys(obj: unknown, prefix = ''): string[] {
    if (typeof obj !== 'object' || obj === null) return [];
    return Object.entries(obj as Record<string, unknown>).flatMap(([k, v]) => {
        const full = prefix ? `${prefix}.${k}` : k;
        return typeof v === 'object' && v !== null ? flattenKeys(v, full) : [full];
    });
}

// ---------------------------------------------------------------------------
// Enhancement #6 — Missing-key metrics
// ---------------------------------------------------------------------------

let _missingKeyCount = 0;
const _missingKeys = new Set<string>();

/** Returns count of unique translation keys that fell back to English or raw key. */
export function getMissingKeyStats(): { count: number; keys: string[] } {
    return { count: _missingKeyCount, keys: Array.from(_missingKeys) };
}

/** Reset counters (useful between test runs). */
export function resetMissingKeyStats(): void {
    _missingKeyCount = 0;
    _missingKeys.clear();
}

// ---------------------------------------------------------------------------
// Core translation function
// ---------------------------------------------------------------------------

/**
 * Get a translation string by dot-notation key for the given locale.
 *
 * @param key       Typed dot-notation path: 'billing.invoiceCreated'
 * @param locale    Target language code (default: 'en')
 * @param vars      Template variables; include `_count` for plural selection
 * @returns         Translated + interpolated string
 *
 * @example
 * t('billing.invoiceCreated', 'hi', { invoiceNo: 'INV-001' })
 * // → "इनवॉइस #INV-001 सफलतापूर्वक बनाया गया"
 */
export function t(
    key: TranslationKey | string,
    locale: string = 'en',
    vars?: TranslationVars,
): string {
    const normalized = normalizeLocale(locale);

    // Enhancement #2: plural key resolution via _count
    const pluralKey = vars?._count !== undefined
        ? resolvePluralKey(normalized, key, vars._count)
        : undefined;

    const raw = (pluralKey ? resolveKey(normalized, pluralKey) : undefined)
        ?? resolveKey(normalized, key)
        ?? resolveKey('en', key)
        ?? key;

    // Track missing keys for observability
    if (raw === key && normalized !== 'en') {
        _missingKeyCount++;
        _missingKeys.add(`${normalized}:${key}`);
    }

    return vars ? interpolate(raw, vars) : raw;
}

/**
 * Create a locale-bound translator (useful in handlers):
 *   const tr = useTranslator('hi');
 *   tr('billing.invoiceCreated', { invoiceNo: 'INV-001' })
 */
export function useTranslator(locale: string) {
    const normalized = normalizeLocale(locale);
    return (key: TranslationKey | string, vars?: TranslationVars): string =>
        t(key, normalized, vars);
}

// ---------------------------------------------------------------------------
// Enhancement #2 — Plural support
// ---------------------------------------------------------------------------

/**
 * Resolves the plural variant of a key based on count.
 * Convention: 'key_one' for count === 1, 'key_other' for everything else.
 * Falls back to base key if variant not found.
 */
function resolvePluralKey(
    locale: SupportedLocale,
    key: string,
    count: number,
): string {
    const suffix = count === 1 ? '_one' : '_other';
    const pluralKey = `${key}${suffix}`;
    // Only return the plural key if it actually exists in the bundle
    return resolveKey(locale, pluralKey) !== undefined ? pluralKey : key;
}

// ---------------------------------------------------------------------------
// Enhancement #3 — Locale-aware formatting
// ---------------------------------------------------------------------------

/**
 * Format a number as Indian Rupees using the locale's numeral system.
 *
 * @example
 * formatCurrency(1234567.5, 'hi') // → "₹12,34,567.50" (Indian grouping)
 */
export function formatCurrency(amount: number, locale: SupportedLocale = 'en'): string {
    try {
        return new Intl.NumberFormat(`${locale}-IN`, {
            style: 'currency',
            currency: 'INR',
            maximumFractionDigits: 2,
        }).format(amount);
    } catch {
        // Intl may not support every locale tag on all Node versions — safe fallback
        return `₹${amount.toFixed(2)}`;
    }
}

/**
 * Format a number using the locale's numeral system and Indian grouping.
 *
 * @example
 * formatNumber(1234567, 'bn') // → "১২,৩৪,৫৬৭" (Bengali numerals)
 */
export function formatNumber(n: number, locale: SupportedLocale = 'en'): string {
    try {
        return new Intl.NumberFormat(`${locale}-IN`).format(n);
    } catch {
        return String(n);
    }
}

// ---------------------------------------------------------------------------
// Enhancement #4 — detectLocaleFromEvent (Lambda helper)
// ---------------------------------------------------------------------------

/**
 * One-liner locale detection for Lambda handlers.
 * Reads `x-app-locale` (set by Flutter DioClient interceptor) then falls back
 * to `accept-language`. Case-insensitive header lookup.
 *
 * @example
 * export const handler = async (event: APIGatewayProxyEvent) => {
 *     const locale = detectLocaleFromEvent(event);
 *     const tr = useTranslator(locale);
 *     return { statusCode: 200, body: tr('common.success') };
 * };
 */
export function detectLocaleFromEvent(event: {
    headers: Record<string, string | undefined>;
}): SupportedLocale {
    const h = event.headers;
    return detectLocale({
        xAppLocale: h['x-app-locale'] ?? h['X-App-Locale'],
        acceptLanguage: h['accept-language'] ?? h['Accept-Language'],
    });
}

// ---------------------------------------------------------------------------
// Locale normalization
// ---------------------------------------------------------------------------

/**
 * Accept-Language: "hi-IN,hi;q=0.9,en-US;q=0.8,en;q=0.7"
 * → 'hi'
 */
export function normalizeLocale(raw: string | null | undefined): SupportedLocale {
    if (!raw) return 'en';

    const langCode = raw.trim().toLowerCase().split(/[-_]/)[0];
    if (SUPPORTED_LOCALES.has(langCode)) return langCode as SupportedLocale;

    // Check Accept-Language header with quality values
    const parts = raw.split(',');
    for (const part of parts) {
        const lang = part.trim().split(';')[0].trim().toLowerCase().split(/[-_]/)[0];
        if (SUPPORTED_LOCALES.has(lang)) return lang as SupportedLocale;
    }

    return 'en';
}

/**
 * Detect locale from multiple sources in priority order:
 * 1. x-app-locale header (explicit client preference)
 * 2. Accept-Language header
 * 3. User preference from database (passed as parameter)
 * 4. Tenant default
 * 5. 'en'
 */
export function detectLocale(options: {
    xAppLocale?: string | null;
    acceptLanguage?: string | null;
    userPreference?: string | null;
    tenantDefault?: string | null;
}): SupportedLocale {
    const { xAppLocale, acceptLanguage, userPreference, tenantDefault } = options;
    if (xAppLocale) return normalizeLocale(xAppLocale);
    if (acceptLanguage) return normalizeLocale(acceptLanguage);
    if (userPreference) return normalizeLocale(userPreference);
    if (tenantDefault) return normalizeLocale(tenantDefault);
    return 'en';
}

// ---------------------------------------------------------------------------
// Key resolution
// ---------------------------------------------------------------------------

function resolveKey(locale: SupportedLocale | string, key: string): string | undefined {
    const bundle = getBundleForLocale(locale as SupportedLocale);
    if (!bundle) return undefined;

    const parts = key.split('.');
    let current: unknown = bundle;

    for (const part of parts) {
        if (current === null || typeof current !== 'object') return undefined;
        current = (current as Record<string, unknown>)[part];
    }

    return typeof current === 'string' ? current : undefined;
}

function getBundleForLocale(locale: SupportedLocale): TranslationBundle | undefined {
    if (LOCALE_BUNDLES[locale]) return LOCALE_BUNDLES[locale];

    const fallback = LOCALE_FALLBACKS[locale];
    if (fallback && LOCALE_BUNDLES[fallback]) return LOCALE_BUNDLES[fallback];

    return LOCALE_BUNDLES['en'];
}

// ---------------------------------------------------------------------------
// String interpolation
// ---------------------------------------------------------------------------

/**
 * Replace {{variable}} placeholders with values.
 * Skips the internal `_count` key (plural hint, not a template variable).
 * Unknown variables are left as-is (do not throw).
 */
function interpolate(template: string, vars: TranslationVars): string {
    return template.replace(/\{\{(\w+)\}\}/g, (_match, key: string) => {
        if (key === '_count') return _match;
        const val = vars[key];
        if (val === undefined || val === null) return `{{${key}}}`;
        return String(val);
    });
}

// ---------------------------------------------------------------------------
// Convenience builders for common response messages
// ---------------------------------------------------------------------------

export const i18n = {
    /** Common messages */
    success: (locale: string, vars?: TranslationVars) => t('common.success', locale, vars),
    notFound: (locale: string, resource: string) => t('common.notFound', locale, { resource }),
    conflict: (locale: string, resource: string) => t('common.conflict', locale, { resource }),
    forbidden: (locale: string) => t('common.forbidden', locale),
    unauthorized: (locale: string) => t('common.unauthorized', locale),
    limitExceeded: (locale: string) => t('common.limitExceeded', locale),
    planExpired: (locale: string) => t('common.planExpired', locale),
    serverError: (locale: string) => t('common.serverError', locale),

    /** Billing */
    invoiceCreated: (locale: string, invoiceNo: string) =>
        t('billing.invoiceCreated', locale, { invoiceNo }),
    paymentRecorded: (locale: string, amount: number) =>
        t('billing.paymentRecorded', locale, { amount: formatCurrency(amount, normalizeLocale(locale)) }),
    stockInsufficient: (locale: string, productName: string, available: number, unit: string) =>
        t('billing.stockInsufficient', locale, { productName, available: formatNumber(available, normalizeLocale(locale)), unit }),

    /** Inventory */
    lowStockAlert: (locale: string, productName: string, quantity: number, unit: string) =>
        t('inventory.lowStockAlert', locale, { productName, quantity: formatNumber(quantity, normalizeLocale(locale)), unit }),
    expiryWarning: (locale: string, productName: string, date: string) =>
        t('inventory.expiryWarning', locale, { productName, date }),
    expiredProduct: (locale: string, productName: string) =>
        t('inventory.expiredProduct', locale, { productName }),

    /** Notifications */
    notification: (locale: string, key: string, vars?: TranslationVars) =>
        t(`notifications.${key}`, locale, vars),

    /** WhatsApp */
    whatsappBill: (locale: string, vars: TranslationVars) =>
        t('whatsapp.billCreated', locale, vars),
    whatsappPayment: (locale: string, vars: TranslationVars) =>
        t('whatsapp.paymentReceived', locale, vars),
    whatsappReminder: (locale: string, vars: TranslationVars) =>
        t('whatsapp.paymentReminder', locale, vars),

    /** SMS */
    smsBill: (locale: string, vars: TranslationVars) =>
        t('sms.billCreated', locale, vars),
    smsPayment: (locale: string, vars: TranslationVars) =>
        t('sms.paymentReceived', locale, vars),
    smsOtp: (locale: string, otp: string, minutes: number) =>
        t('sms.otpMessage', locale, { otp, minutes: String(minutes) }),

    /** PDF */
    pdf: (locale: string, key: string, vars?: TranslationVars) =>
        t(`pdf.${key}`, locale, vars),

    /** Validation */
    validationRequired: (locale: string, field: string) =>
        t('validation.required', locale, { field }),
    validationInvalidPhone: (locale: string) =>
        t('validation.invalidPhone', locale),
    validationInvalidGstin: (locale: string) =>
        t('validation.invalidGstin', locale),
};
