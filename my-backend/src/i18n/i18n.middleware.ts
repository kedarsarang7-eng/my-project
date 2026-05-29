// =============================================================================
// i18n Middleware — Locale detection for Lambda handlers
// =============================================================================
// Injects locale into handler context using AsyncLocalStorage.
// Supports:
//   - X-App-Locale header (explicit client preference, highest priority)
//   - Accept-Language header (browser/OS standard)
//   - Per-tenant default locale from TenantSettings
//   - Fallback: 'en'
//
// Usage in handler-wrapper:
//   const locale = getRequestLocale(event, tenantSettings);
//   runWithLocale(locale, () => handlerFn(event, context, auth));
//
// Usage in handlers:
//   const locale = getCurrentLocale(); // → 'hi' | 'mr' | 'en' | ...
// =============================================================================

import { AsyncLocalStorage } from 'async_hooks';
import { APIGatewayProxyEventV2 } from 'aws-lambda';
import { detectLocale, normalizeLocale, SupportedLocale } from './i18n.service';
import { TenantSettings } from '../types/tenant.types';

// ---------------------------------------------------------------------------
// AsyncLocalStorage context for locale propagation
// ---------------------------------------------------------------------------

const localeStorage = new AsyncLocalStorage<{ locale: SupportedLocale }>();

/**
 * Run a callback with the given locale bound to async context.
 * This allows any nested function call to read the locale via getCurrentLocale().
 */
export function runWithLocale<T>(locale: SupportedLocale, fn: () => T): T {
    return localeStorage.run({ locale }, fn);
}

/**
 * Get the current request's locale from async context.
 * Falls back to 'en' if called outside a runWithLocale() scope.
 */
export function getCurrentLocale(): SupportedLocale {
    return localeStorage.getStore()?.locale ?? 'en';
}

// ---------------------------------------------------------------------------
// Locale detection from API Gateway event
// ---------------------------------------------------------------------------

/**
 * Detect locale from Lambda event headers with tenant preference fallback.
 *
 * Priority:
 * 1. X-App-Locale header (Flutter app sends this after user selects language)
 * 2. Accept-Language header (OS/browser standard)
 * 3. Tenant default locale from TenantSettings
 * 4. 'en' fallback
 */
export function getRequestLocale(
    event: APIGatewayProxyEventV2,
    tenantSettings?: TenantSettings | null,
): SupportedLocale {
    const headers = event.headers ?? {};
    return detectLocale({
        xAppLocale: headers['x-app-locale'] ?? headers['X-App-Locale'],
        acceptLanguage: headers['accept-language'] ?? headers['Accept-Language'],
        userPreference: null,
        tenantDefault: tenantSettings?.locale ?? null,
    });
}

/**
 * Extract locale from headers only (when tenant settings are not available).
 */
export function getLocaleFromHeaders(
    headers: Record<string, string | undefined>,
): SupportedLocale {
    return detectLocale({
        xAppLocale: headers['x-app-locale'] ?? headers['X-App-Locale'],
        acceptLanguage: headers['accept-language'] ?? headers['Accept-Language'],
    });
}

// ---------------------------------------------------------------------------
// Locale context for notification/template rendering
// ---------------------------------------------------------------------------

export interface LocaleContext {
    locale: SupportedLocale;
    isRtl: boolean;
    timezone: string;
    currencySymbol: string;
    dateFormat: string;
}

const RTL_LOCALES = new Set(['ur', 'ar', 'fa']);
const LOCALE_TIMEZONES: Partial<Record<SupportedLocale, string>> = {
    en: 'Asia/Kolkata',
    hi: 'Asia/Kolkata',
    mr: 'Asia/Kolkata',
    gu: 'Asia/Kolkata',
    ta: 'Asia/Kolkata',
    te: 'Asia/Kolkata',
    kn: 'Asia/Kolkata',
    ml: 'Asia/Kolkata',
    bn: 'Asia/Kolkata',
    pa: 'Asia/Kolkata',
    ur: 'Asia/Karachi',
};

export function buildLocaleContext(
    locale: SupportedLocale,
    tenantTimezone?: string,
): LocaleContext {
    return {
        locale,
        isRtl: RTL_LOCALES.has(locale),
        timezone: tenantTimezone ?? LOCALE_TIMEZONES[locale] ?? 'Asia/Kolkata',
        currencySymbol: '₹', // INR for all supported business locales
        dateFormat: 'DD/MM/YYYY',
    };
}

// ---------------------------------------------------------------------------
// Date formatting helpers for backend use
// ---------------------------------------------------------------------------

/**
 * Format date for display in the given locale.
 * Backend uses IST by default for all Indian locales.
 */
export function formatDateForLocale(
    date: Date,
    locale: SupportedLocale,
    timezone = 'Asia/Kolkata',
): string {
    try {
        return new Intl.DateTimeFormat(localeToIntlTag(locale), {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            timeZone: timezone,
        }).format(date);
    } catch {
        return date.toLocaleDateString('en-IN');
    }
}

export function formatDateLongForLocale(
    date: Date,
    locale: SupportedLocale,
    timezone = 'Asia/Kolkata',
): string {
    try {
        return new Intl.DateTimeFormat(localeToIntlTag(locale), {
            day: 'numeric',
            month: 'long',
            year: 'numeric',
            timeZone: timezone,
        }).format(date);
    } catch {
        return date.toLocaleDateString('en-IN', { dateStyle: 'long' });
    }
}

/**
 * Format currency in Indian numbering system.
 * 1234567.5 → "₹12,34,567.50"
 */
export function formatCurrencyINR(amount: number): string {
    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    }).format(amount);
}

/**
 * Format number in Indian grouping: 1234567 → "12,34,567"
 */
export function formatNumberIndian(value: number): string {
    return new Intl.NumberFormat('en-IN').format(value);
}

// ---------------------------------------------------------------------------
// Locale → IETF BCP 47 tag mapping
// ---------------------------------------------------------------------------

const LOCALE_TO_INTL: Record<string, string> = {
    en: 'en-IN',
    hi: 'hi-IN',
    mr: 'mr-IN',
    gu: 'gu-IN',
    ta: 'ta-IN',
    te: 'te-IN',
    kn: 'kn-IN',
    ml: 'ml-IN',
    bn: 'bn-IN',
    pa: 'pa-IN',
    ur: 'ur-PK',
};

export function localeToIntlTag(locale: string): string {
    return LOCALE_TO_INTL[locale] ?? 'en-IN';
}
