// ============================================================================
// TypeScript Types — Inventory (Polymorphic)
// ============================================================================

import { BusinessType } from './tenant.types';

/**
 * Polymorphic inventory item.
 * The base fields are shared; business-specific fields live in `attributes` JSONB.
 */
export interface InventoryItem {
    id: string;
    tenantId: string;
    productType: ProductType;

    // ── Common Fields ─────────────────────────────────────────────────────
    name: string;
    displayName?: string;
    sku?: string;
    barcode?: string;
    category?: string;
    subcategory?: string;
    brand?: string;
    hsnCode?: string;  // India GST
    unit: string;

    // ── Pricing (BIGINT paise — stored as number in TS) ───────────────────
    salePriceCents: number;
    purchasePriceCents?: number;
    mrpCents?: number;
    wholesalePriceCents?: number;

    // ── Tax Rates (Basis Points: 18% = 1800) ──────────────────────────────
    cgstRateBp: number;
    sgstRateBp: number;
    igstRateBp: number;

    // ── Stock ─────────────────────────────────────────────────────────────
    currentStock: number;
    lowStockThreshold: number;
    reorderQty?: number;

    // ── Business-Specific Attributes (JSONB) ──────────────────────────────
    attributes: Record<string, unknown>;

    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
}

/**
 * ProductType determines which set of attributes are relevant.
 */
export enum ProductType {
    GENERAL = 'general',
    FUEL = 'fuel',               // Petrol Pump
    MEDICINE = 'medicine',       // Pharmacy
    FOOD_ITEM = 'food_item',     // Restaurant
    CLOTHING_ITEM = 'clothing',  // Clothing (size/color variants)
    ELECTRONIC = 'electronic',   // Electronics
    HARDWARE = 'hardware_item',  // Hardware
    SERVICE = 'service',         // Service business
    VEGETABLE = 'vegetable',     // Mandi / Broker
    MEDICAL = 'medical_supply',  // Clinic
}

// ── Business-Specific Attribute Interfaces ────────────────────────────

export interface FuelAttributes {
    fuelType: 'PETROL' | 'DIESEL' | 'CNG' | 'LPG';
    tankId: string;
    densityAt15C?: number;
    currentRate: number;   // paise per litre
}

export interface MedicineAttributes {
    batchNumber: string;
    manufacturingDate: string;
    expiryDate: string;
    drugSchedule?: string;   // H, H1, X, etc.
    requiresPrescription: boolean;
    manufacturer?: string;
    composition?: string;
    rackLocation?: string;
}

export interface ClothingAttributes {
    size: string;
    color: string;
    material?: string;
    groupId?: string;  // Groups variants together
}

export interface FoodItemAttributes {
    isVeg: boolean;
    spiceLevel?: 'MILD' | 'MEDIUM' | 'HOT';
    preparationTime?: number; // minutes
    allergens?: string[];
    categoryId?: string;
}

// ── Query Filters ───────────────────────────────────────────────────────

export interface InventoryFilters {
    tenantId: string;
    productType?: ProductType;
    category?: string;
    search?: string;
    lowStockOnly?: boolean;
    isActive?: boolean;
    page: number;
    limit: number;
}
