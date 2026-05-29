// =============================================================================
// Multilingual DynamoDB Schema — Language-neutral data design
// =============================================================================
// Key design principles:
//
// 1. BUSINESS DATA is stored language-neutral (enum keys, not English strings).
//    - Unit: 'kg' not 'Kilogram'
//    - Category: 'grocery_staples' not 'Staples'
//    - Payment mode: 'upi' not 'UPI Payment'
//
// 2. PRODUCT NAMES / DESCRIPTIONS use a MultiLangText structure.
//    - { en: 'Rice', hi: 'चावल', mr: 'तांदूळ' }
//    - Read-path: resolve active locale → fallback en → key
//
// 3. INTERNAL CODES stay in English (HSN, GST, SAC — statutory requirement).
//
// 4. SEARCH uses the lang-neutral key + English transliteration index.
//
// 5. TRANSLATION TABLE for dynamic system labels
//    PK=TRANSLATION#<namespace> SK=<key>#<locale>
// =============================================================================

import { SupportedLocale } from './i18n.service';

// ---------------------------------------------------------------------------
// MultiLangText — the core multilingual data type
// ---------------------------------------------------------------------------

/**
 * Multilingual text field stored in DynamoDB.
 * At minimum 'en' must be present (used as fallback).
 */
export type MultiLangText = {
    en: string;
    hi?: string;
    mr?: string;
    gu?: string;
    ta?: string;
    te?: string;
    kn?: string;
    ml?: string;
    bn?: string;
    pa?: string;
    ur?: string;
};

/**
 * Resolve a MultiLangText to a string for the given locale.
 * Falls back: requested locale → 'en'.
 */
export function resolveText(
    text: MultiLangText | string | undefined,
    locale: string,
): string {
    if (!text) return '';
    if (typeof text === 'string') return text;
    return text[locale as SupportedLocale] ?? text.en ?? '';
}

/**
 * Create a MultiLangText from a single-language input.
 * Used when only English is provided at product creation time.
 */
export function fromEnglish(english: string): MultiLangText {
    return { en: english };
}

/**
 * Merge translation updates into an existing MultiLangText.
 */
export function mergeTranslation(
    existing: MultiLangText,
    updates: Partial<MultiLangText>,
): MultiLangText {
    return { ...existing, ...updates };
}

// ---------------------------------------------------------------------------
// Language-neutral enum keys — stored in DB instead of display strings
// ---------------------------------------------------------------------------

/**
 * Payment modes stored as language-neutral keys.
 * Display resolved via ARB: l10n.cash, l10n.upi etc.
 */
export const PaymentModeKeys = ['cash', 'upi', 'card', 'net_banking', 'cheque', 'credit', 'emi'] as const;
export type PaymentModeKey = typeof PaymentModeKeys[number];

/**
 * Unit keys — stored as standard codes, displayed via lookup table.
 */
export const UnitKeys = [
    'pcs', 'kg', 'g', 'l', 'ml', 'dozen', 'box',
    'packet', 'bottle', 'strip', 'pair', 'set',
    'meter', 'cm', 'sqft', 'sqm', 'liter',
] as const;
export type UnitKey = typeof UnitKeys[number];

/** Unit display names — language-neutral codes only, display via ARB */
export const UNIT_DISPLAY: Record<UnitKey, MultiLangText> = {
    pcs:    { en: 'Pcs',    hi: 'नग',      mr: 'नग' },
    kg:     { en: 'Kg',     hi: 'किलो',    mr: 'किलो' },
    g:      { en: 'g',      hi: 'ग्राम',   mr: 'ग्रॅम' },
    l:      { en: 'L',      hi: 'लीटर',    mr: 'लिटर' },
    ml:     { en: 'ml',     hi: 'मिलीलीटर', mr: 'मिलीलिटर' },
    dozen:  { en: 'Dozen',  hi: 'दर्जन',   mr: 'डझन' },
    box:    { en: 'Box',    hi: 'डिब्बा',  mr: 'बॉक्स' },
    packet: { en: 'Pkt',    hi: 'पैकेट',   mr: 'पाकीट' },
    bottle: { en: 'Btl',    hi: 'बोतल',    mr: 'बाटली' },
    strip:  { en: 'Strip',  hi: 'स्ट्रिप', mr: 'स्ट्रिप' },
    pair:   { en: 'Pair',   hi: 'जोड़ी',   mr: 'जोडी' },
    set:    { en: 'Set',    hi: 'सेट',     mr: 'सेट' },
    meter:  { en: 'Mtr',    hi: 'मीटर',    mr: 'मीटर' },
    cm:     { en: 'cm',     hi: 'सेमी',    mr: 'सेमी' },
    sqft:   { en: 'Sq.ft',  hi: 'वर्ग फुट', mr: 'चौरस फूट' },
    sqm:    { en: 'Sq.m',   hi: 'वर्ग मीटर', mr: 'चौरस मीटर' },
    liter:  { en: 'L',      hi: 'लीटर',    mr: 'लिटर' },
};

// ---------------------------------------------------------------------------
// DynamoDB item shapes — multilingual fields use MultiLangText
// ---------------------------------------------------------------------------

/**
 * Product item in DynamoDB — multilingual name + description.
 * Stored under PK=TENANT#{id} SK=PRODUCT#{productId}
 */
export interface MultilingualProductItem {
    PK: string;                         // TENANT#{tenantId}
    SK: string;                         // PRODUCT#{productId}
    GSI1PK: string;                     // CATEGORY#{categoryKey}
    GSI1SK: string;                     // STOCK#{paddedStock}
    type: 'PRODUCT';

    // Language-neutral identifiers (never English labels)
    productId: string;
    sku?: string;
    barcode?: string;
    hsnCode?: string;
    unit: UnitKey;                      // 'kg' not 'Kilogram'
    categoryKey: string;                // 'grocery_staples' not 'Staples'

    // Multilingual display fields
    name: MultiLangText;                // { en: 'Rice', hi: 'चावल', mr: 'तांदूळ' }
    description?: MultiLangText;
    searchKeywords?: string[];          // All-language search terms merged

    // Financials — always in paise (integer, no float precision errors)
    ratePaisa: number;                  // selling price in paise
    mrpPaisa?: number;
    costPaisa?: number;

    // GST — statutory code, stays in English
    gstRate: number;
    isGstInclusive: boolean;

    // Inventory
    currentStock: number;
    lowStockThreshold: number;
    expiryDate?: string;                // ISO 8601

    tenantId: string;
    createdAt: string;
    updatedAt: string;
}

/**
 * Category item — multilingual name.
 * PK=TENANT#{id} SK=CATEGORY#{categoryKey}
 */
export interface MultilingualCategoryItem {
    PK: string;
    SK: string;
    type: 'CATEGORY';
    categoryKey: string;                // language-neutral: 'grocery_staples'
    name: MultiLangText;                // { en: 'Staples', hi: 'अनाज', mr: 'धान्य' }
    parentKey?: string;
    sortOrder: number;
    tenantId: string;
}

/**
 * Translation table item for dynamic labels (custom business categories etc.).
 * PK=TRANSLATION#{namespace} SK={key}#{locale}
 */
export interface TranslationTableItem {
    PK: string;                         // TRANSLATION#{namespace}  e.g. TRANSLATION#categories
    SK: string;                         // {key}#{locale}           e.g. my_custom_cat#hi
    namespace: string;
    key: string;
    locale: string;
    value: string;
    tenantId?: string;                  // null = global, tenantId = tenant-specific override
    updatedAt: string;
    updatedBy?: string;
}

// ---------------------------------------------------------------------------
// DynamoDB key builders for multilingual entities
// ---------------------------------------------------------------------------

export const MultilingualKeys = {
    productPK: (tenantId: string) => `TENANT#${tenantId}`,
    productSK: (productId: string) => `PRODUCT#${productId}`,
    categoryPK: (tenantId: string) => `TENANT#${tenantId}`,
    categorySK: (categoryKey: string) => `CATEGORY#${categoryKey}`,
    translationPK: (namespace: string) => `TRANSLATION#${namespace}`,
    translationSK: (key: string, locale: string) => `${key}#${locale}`,
};

// ---------------------------------------------------------------------------
// Search keyword builder — generates multi-lang search terms
// ---------------------------------------------------------------------------

/**
 * Build a unified search keyword array from MultiLangText.
 * Merges all language variants + transliteration tokens.
 * Stored on the product for GSI-based search.
 */
export function buildSearchKeywords(name: MultiLangText, extra: string[] = []): string[] {
    const keywords = new Set<string>();

    // Add all language variants (lowercase)
    for (const [_lang, text] of Object.entries(name)) {
        if (text) {
            keywords.add(text.toLowerCase());
            // Add individual words for partial match
            text.toLowerCase().split(/\s+/).forEach((w) => w.length > 1 && keywords.add(w));
        }
    }

    // Add extra terms (SKU, barcode, HSN)
    extra.forEach((e) => e && keywords.add(e.toLowerCase()));

    return Array.from(keywords);
}

// ---------------------------------------------------------------------------
// Invoice multilingual fields
// ---------------------------------------------------------------------------

/**
 * Invoice line item with multilingual product reference.
 * We store the language-neutral productId, not a copied product name.
 * Display resolves via product lookup at read time.
 */
export interface MultilingualInvoiceItem {
    productId: string;
    productName: MultiLangText;     // Snapshot at time of sale (product may be edited later)
    hsnCode?: string;
    unit: UnitKey;
    quantity: number;
    ratePaisa: number;
    discountPct: number;
    gstRate: number;
    cgstPaisa: number;
    sgstPaisa: number;
    igstPaisa: number;
    totalPaisa: number;
}
