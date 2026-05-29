// ============================================================================
// Master Business Type Registry — Single Source of Truth
// ============================================================================
// This configuration defines all supported business types in the system.
// Both backend and frontend should reference this config to avoid hardcoding.
// ============================================================================

export interface BusinessTypeConfig {
    id: string;
    label: string;
    description: string;
    category: 'retail' | 'service' | 'healthcare' | 'hospitality' | 'industrial' | 'education';
    icon?: string;
    features: string[];
}

/**
 * Complete list of supported business types.
 * Add new types here and they'll be available throughout the system.
 */
export const BUSINESS_TYPES: BusinessTypeConfig[] = [
    {
        id: 'grocery',
        label: 'Grocery Store',
        description: 'General grocery and supermarket operations',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'expiry_tracking'],
    },
    {
        id: 'pharmacy',
        label: 'Pharmacy',
        description: 'Pharmacy and medical store management',
        category: 'healthcare',
        features: ['inventory', 'billing', 'gst', 'reports', 'batch_tracking', 'prescriptions', 'narcotic_register'],
    },
    {
        id: 'restaurant',
        label: 'Restaurant',
        description: 'Restaurant and food service operations',
        category: 'hospitality',
        features: ['inventory', 'billing', 'gst', 'reports', 'table_management', 'kitchen_display'],
    },
    {
        id: 'clothing',
        label: 'Clothing & Fashion',
        description: 'Clothing retail with variant management',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'variants', 'size_management'],
    },
    {
        id: 'electronics',
        label: 'Electronics Store',
        description: 'Electronics and mobile phone retail',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'serial_tracking', 'warranty'],
    },
    {
        id: 'mobile_shop',
        label: 'Mobile Shop',
        description: 'Mobile phone and accessories store',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'imei_tracking', 'repairs'],
    },
    {
        id: 'computer_shop',
        label: 'Computer Store',
        description: 'Computer hardware and software sales',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'service_desk', 'assemblies'],
    },
    {
        id: 'hardware',
        label: 'Hardware Store',
        description: 'Hardware and construction materials',
        category: 'industrial',
        features: ['inventory', 'billing', 'gst', 'reports', 'projects', 'procurement'],
    },
    {
        id: 'service',
        label: 'Service Center',
        description: 'General service and repair center',
        category: 'service',
        features: ['billing', 'gst', 'reports', 'appointments', 'work_orders'],
    },
    {
        id: 'wholesale',
        label: 'Wholesale Distribution',
        description: 'Wholesale and distribution business',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'distribution', 'credit_management'],
    },
    {
        id: 'petrol_pump',
        label: 'Petrol Pump',
        description: 'Fuel station and convenience store',
        category: 'industrial',
        features: ['billing', 'gst', 'reports', 'fuel_management', 'atg_integration', 'shifts'],
    },
    {
        id: 'vegetables_broker',
        label: 'Vegetables Broker',
        description: 'Vegetables and produce brokerage',
        category: 'retail',
        features: ['billing', 'gst', 'reports', 'commodity_trading'],
    },
    {
        id: 'clinic',
        label: 'Clinic',
        description: 'Medical clinic and healthcare facility',
        category: 'healthcare',
        features: ['appointments', 'billing', 'gst', 'reports', 'patient_records', 'medical_history'],
    },
    {
        id: 'book_store',
        label: 'Book Store',
        description: 'Books and stationery retail',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'isbn_tracking', 'institutional_orders'],
    },
    {
        id: 'jewellery',
        label: 'Jewellery Store',
        description: 'Jewellery and precious metals retail',
        category: 'retail',
        features: ['inventory', 'billing', 'gst', 'reports', 'karat_tracking', 'custom_orders'],
    },
    {
        id: 'other',
        label: 'Other Business',
        description: 'Custom business type not listed above',
        category: 'service',
        features: ['billing', 'gst', 'reports'],
    },
];

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Get business type config by ID
 */
export function getBusinessType(id: string): BusinessTypeConfig | undefined {
    return BUSINESS_TYPES.find(type => type.id === id);
}

/**
 * Get all business type IDs
 */
export function getBusinessTypeIds(): string[] {
    return BUSINESS_TYPES.map(type => type.id);
}

/**
 * Get business types by category
 */
export function getBusinessTypesByCategory(category: BusinessTypeConfig['category']): BusinessTypeConfig[] {
    return BUSINESS_TYPES.filter(type => type.category === category);
}

/**
 * Validate that a business type ID is supported
 */
export function isValidBusinessType(id: string): boolean {
    return getBusinessTypeIds().includes(id);
}

/**
 * Validate that all business types in an array are supported
 */
export function validateBusinessTypes(types: string[]): { isValid: boolean; invalidTypes: string[] } {
    const validIds = getBusinessTypeIds();
    const invalidTypes = types.filter(type => !validIds.includes(type));
    return {
        isValid: invalidTypes.length === 0,
        invalidTypes,
    };
}

/**
 * Get business type label by ID
 */
export function getBusinessTypeLabel(id: string): string {
    const type = getBusinessType(id);
    return type?.label || id;
}

// ============================================================================
// Type Guards and Enums
// ============================================================================

export type BusinessTypeId = typeof BUSINESS_TYPES[number]['id'];
export type BusinessCategory = BusinessTypeConfig['category'];

export const BUSINESS_CATEGORIES = ['retail', 'service', 'healthcare', 'hospitality', 'industrial', 'education'] as const;

/**
 * Type guard to check if a string is a valid business type ID
 */
export function isBusinessTypeId(value: string): value is BusinessTypeId {
    return isValidBusinessType(value);
}
