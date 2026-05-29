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
    description?: string;    // L-3: Product description
    imageUrl?: string;       // L-3: Product image URL (S3 or external)

    // ── Pricing (BIGINT paise — stored as number in TS) ───────────────────
    salePriceCents: number;
    purchasePriceCents?: number;
    mrpCents?: number;
    wholesalePriceCents?: number;
    // L-2: Quantity-based pricing tiers
    pricingTiers?: PricingTier[];

    // ── Tax Rates (Basis Points: 18% = 1800) ──────────────────────────────
    cgstRateBp: number;
    sgstRateBp: number;
    igstRateBp: number;

    // ── Stock ─────────────────────────────────────────────────────────────
    currentStock: number;
    lowStockThreshold: number;
    reorderQty?: number;
    // L-5: Multi-location stock (basic)
    locationStock?: LocationStock[];

    // ── Variants ──────────────────────────────────────────────────────────
    // L-1: Groups multiple products as variants of a parent product
    variantGroupId?: string;

    // ── Business-Specific Attributes (JSONB) ──────────────────────────────
    attributes: Record<string, unknown>;

    isActive: boolean;
    isArchived?: boolean;   // L-4: Archived flag
    createdAt: Date;
    updatedAt: Date;
}

/**
 * L-2: Pricing tier for quantity-based bulk discounts.
 * Example: [{ minQty: 10, priceCents: 900 }, { minQty: 50, priceCents: 800 }]
 */
export interface PricingTier {
    minQty: number;
    priceCents: number;
    label?: string; // e.g. "Wholesale", "Bulk"
}

/**
 * L-5: Per-location stock tracking (basic multi-location support).
 */
export interface LocationStock {
    locationId: string;
    locationName: string;
    stock: number;
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
    groupId?: string;  // Groups variants together (maps to variantGroupId)
}

export interface FoodItemAttributes {
    isVeg: boolean;
    spiceLevel?: 'MILD' | 'MEDIUM' | 'HOT';
    preparationTime?: number; // minutes
    allergens?: string[];
    categoryId?: string;
}

export interface HardwareAttributes {
    rackLocation?: string;          // e.g. "A-3-2" (Aisle-Rack-Shelf)
    binNumber?: string;
    materialType?: 'plumbing' | 'electrical' | 'structural' | 'paint' | 'tools' | 'fasteners' | 'general';
    gradeSpecification?: string;    // e.g. "Fe 500D" for TMT bars, "CPVC SDR 11" for pipes
    lengthPerUnit?: number;         // per piece in base unit (e.g. 6 for "6ft GI pipe")
    weightPerUnit?: number;         // per piece in kg (e.g. 50 for "50kg cement bag")
    conversionFactor?: number;      // default UOM conversion (e.g. 12 for "12 pcs/box")
    conversionUnit?: string;        // target unit for conversion (e.g. "box", "bundle")
}

// ── Query Filters ───────────────────────────────────────────────────────

export interface InventoryFilters {
    tenantId: string;
    productType?: ProductType;
    category?: string;
    search?: string;
    lowStockOnly?: boolean;
    isActive?: boolean;
    isArchived?: boolean;  // L-4: Filter by archive status
    variantGroupId?: string; // L-1: Filter by variant group
    page: number;
    limit: number;
    /** DynamoDB cursor for server-side pagination (ExclusiveStartKey) */
    cursor?: Record<string, unknown>;
}

