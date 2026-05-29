// ============================================================================
// Zod Validation Schemas — Input Validation for All API Endpoints
// ============================================================================
// These schemas are the SINGLE SOURCE OF TRUTH for API input validation.
// Every handler must validate its input through these schemas.
// ============================================================================

import { z } from 'zod';

// ── Auth Schemas ────────────────────────────────────────────────────────────

export const signupSchema = z.object({
    email: z.string().email().max(255).trim().toLowerCase(),
    password: z.string().min(8).max(128),
    fullName: z.string().max(100).trim().optional(),
    businessName: z.string().min(1).max(200).trim(),
    businessType: z.enum([
        'grocery', 'pharmacy', 'restaurant', 'clothing', 'electronics',
        'mobile_shop', 'computer_shop', 'hardware', 'service', 'wholesale',
        'petrol_pump', 'vegetables_broker', 'clinic', 'other',
    ]),
    phone: z.string().regex(/^\+?[\d\s\-]{7,20}$/).optional(),
    licenseKey: z.string().min(10).max(100),
});

export const loginSchema = z.object({
    email: z.string().email().max(255).trim().toLowerCase(),
    password: z.string().min(1).max(128),
});

export const refreshTokenSchema = z.object({
    refreshToken: z.string().min(1),
});

export const mfaVerifySchema = z.object({
    session: z.string().min(1),
    username: z.string().min(1),
    totpCode: z.string().length(6).regex(/^\d+$/),
});

export const mfaSetupConfirmSchema = z.object({
    session: z.string().min(1),
    username: z.string().min(1),
    totpCode: z.string().length(6).regex(/^\d+$/),
});

export const mfaSetupSchema = z.object({
    session: z.string().min(1),
});

export const forgotPasswordSchema = z.object({
    email: z.string().email().max(255).trim().toLowerCase(),
});

export const confirmResetPasswordSchema = z.object({
    email: z.string().email().max(255).trim().toLowerCase(),
    confirmationCode: z.string().min(1).max(20),
    newPassword: z.string().min(8).max(128)
        .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
        .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
        .regex(/[0-9]/, 'Password must contain at least one number')
        .regex(/[^a-zA-Z0-9]/, 'Password must contain at least one special character'),
});

export const changePasswordSchema = z.object({
    previousPassword: z.string().min(1).max(128),
    proposedPassword: z.string().min(8).max(128)
        .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
        .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
        .regex(/[0-9]/, 'Password must contain at least one number')
        .regex(/[^a-zA-Z0-9]/, 'Password must contain at least one special character'),
});

// ── Inventory Schemas ───────────────────────────────────────────────────────

export const createInventorySchema = z.object({
    name: z.string().min(1).max(200).trim(),
    displayName: z.string().max(200).trim().optional(),
    sku: z.string().max(50).optional(),
    barcode: z.string().max(50).optional(),
    productType: z.string().max(30).default('general'),
    category: z.string().max(100).optional(),
    subcategory: z.string().max(100).optional(),
    brand: z.string().max(100).optional(),
    hsnCode: z.string().max(10).optional(),
    unit: z.string().max(20).default('pcs'),
    salePriceCents: z.number().int().min(0).max(999_999_999_99),
    purchasePriceCents: z.number().int().min(0).optional(),
    mrpCents: z.number().int().min(0).optional(),
    wholesalePriceCents: z.number().int().min(0).optional(),
    cgstRateBp: z.number().int().min(0).max(10000).default(0),
    sgstRateBp: z.number().int().min(0).max(10000).default(0),
    igstRateBp: z.number().int().min(0).max(10000).default(0),
    cessRateBp: z.number().int().min(0).max(10000).default(0),
    currentStock: z.number().min(0).default(0),
    lowStockThreshold: z.number().min(0).default(5),
    reorderQty: z.number().min(0).optional(),
    attributes: z.record(z.string(), z.unknown()).default({}),
    isActive: z.boolean().default(true),
    isService: z.boolean().default(false),
    description: z.string().max(1000).optional(),
    // AUDIT FIX GST-3.1: Distinguish nil-rated vs exempt vs zero-rated for GSTR-1
    // - standard: Normal GST rate applies
    // - nil_rated: 0% by law (e.g., fresh vegetables HSN 0703, milk HSN 0401)
    // - exempt: Exempt under Section 11 (e.g., agricultural produce)
    // - zero_rated: Export/SEZ supply (0% but ITC available)
    taxCategory: z.enum(['standard', 'nil_rated', 'exempt', 'zero_rated']).default('standard'),
});

export const updateInventorySchema = createInventorySchema.partial();

// ── Sync Schemas ────────────────────────────────────────────────────────────

export const syncChangeSchema = z.object({
    table: z.string().min(1).max(100),
    action: z.enum(['insert', 'update', 'delete']),
    id: z.string().uuid(),
    data: z.record(z.string(), z.unknown()),
    localTimestamp: z.string(),
});

export const syncPushSchema = z.object({
    changes: z.array(syncChangeSchema).min(1).max(500),
    deviceId: z.string().max(100).optional(),
    lastSyncedAt: z.string().optional(),
});

export const syncPullSchema = z.object({
    lastSyncedAt: z.string().min(1),
    tables: z.array(z.string().max(100)).max(100).optional(),
});

// ── Payment Schemas ─────────────────────────────────────────────────────────

export const recordPaymentSchema = z.object({
    invoiceId: z.string().uuid(),
    amountCents: z.number().int().positive().max(999_999_999_99),
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']).optional(),
    notes: z.string().max(500).optional(),
});

// ── Invoice Schemas ─────────────────────────────────────────────────────────

export const createInvoiceSchema = z.object({
    customerId: z.string().uuid().optional(),
    customerName: z.string().max(100).optional(),
    customerPhone: z.string().max(20).optional(),
    customerGstin: z.string().max(15).optional(), // C-3: For IGST determination
    isInterState: z.boolean().optional(),       // C-3: Inter-state supply flag
    isInterStateOverride: z.boolean().optional(), // Allow override of auto GST logic
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
        unitPriceCents: z.number().int().min(0),
        discountCents: z.number().int().min(0).default(0), // C-2: Item-level discount
        freeQuantity: z.number().min(0).default(0),
        taxCents: z.number().int().min(0).default(0),
        batchNumber: z.string().max(50).optional(),
        expiryDate: z.string().optional(),
        attributes: z.record(z.string(), z.unknown()).default({}),
        // FIX-HW-004: UOM conversion factor for owner/manager unit overrides
        conversionFactor: z.number().positive().optional(),
        // IMEI/Serial tracking (Consumer Protection Act — electronics/mobile_shop)
        serialNumber: z.string().max(100).optional(),
        imei1: z.string().regex(/^\d{15}$/, 'IMEI must be 15 digits').optional(),
        imei2: z.string().regex(/^\d{15}$/, 'IMEI must be 15 digits').optional(),
    })).min(1),
    discountCents: z.number().int().min(0).default(0), // C-2: Bill-level discount
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']).default('cash'),
    invoiceType: z.enum(['tax_invoice', 'retail_invoice', 'proforma_invoice']).default('tax_invoice'),
    invoiceProfileId: z.string().max(100).optional(),
    splitPayments: z.array(z.object({
        method: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']),
        amountCents: z.number().int().positive(),
        reference: z.string().max(100).optional(),
    })).max(6).optional(),
    notes: z.string().max(1000).optional(),
    metadata: z.record(z.string(), z.unknown()).default({}),
    // Hardware: Transport details for compliance
    lrNumber: z.string().max(50).optional(),
    transporterName: z.string().max(100).optional(),
    ewayBillNumber: z.string().max(20).optional(),
    transportMode: z.enum(['road', 'rail', 'air', 'ship']).optional(),
});

export const voidInvoiceSchema = z.object({
    reason: z.string().min(1).max(500).trim(),
});

// ── Held / Parked Bills (Sprint 1: cashier safety) ──────────────────────────
// A held bill is a cart snapshot the cashier saved to free the lane.
// NO stock deduction, NO invoice number, NO finance impact.
// On resume, client calls /invoices to actually create + finalize.
// NOTE: productId / customerId here are STRING (not uuid()) on purpose.
// A held bill is a transient cart snapshot, not a referential record. Cashiers
// often park carts that contain ad-hoc items typed by hand or rows imported
// from a barcode scan that hasn't yet been committed to the inventory table.
// ── Cash Closings (Sprint 1: day-end denomination close) ────────────────────
// One denomination breakdown line: how many of a given note/coin were counted.
// `valuePaise` is the face value in paise (₹500 → 50000) so the schema is
// currency-agnostic and ready for non-INR variants if we ever go cross-border.
export const cashDenominationSchema = z.object({
    valuePaise: z.number().int().positive(), // 200000 = ₹2000, 50000 = ₹500, etc.
    count: z.number().int().min(0),
});

export const recordCashClosingSchema = z.object({
    // ISO date — YYYY-MM-DD. Defaults to today on the server.
    closingDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    /** Cashier-counted drawer total, paise. */
    countedCashPaise: z.number().int().min(0),
    /** Optional denomination breakdown — required for audit trail when set. */
    denominations: z.array(cashDenominationSchema).max(20).optional(),
    /** Optional: cashier ack of variance even before owner approves. */
    cashierNote: z.string().max(500).optional(),
    /** Optional shift link (petrol pump / multi-shift retailers). */
    shiftId: z.string().uuid().optional(),
});

export const approveCashClosingSchema = z.object({
    /** Owner-supplied reason. Mandatory: variance > tolerance must justify itself. */
    reason: z.string().min(1).max(500).trim(),
});

export const holdBillSchema = z.object({
    label: z.string().min(1).max(80).trim(), // e.g. "Lane 2 — red shirt customer"
    customerId: z.string().min(1).max(100).optional(),
    customerName: z.string().max(100).optional(),
    customerPhone: z.string().max(20).optional(),
    items: z.array(z.object({
        productId: z.string().min(1).max(100),
        name: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
        unitPriceCents: z.number().int().min(0),
        discountCents: z.number().int().min(0).default(0),
        taxCents: z.number().int().min(0).default(0),
        batchNumber: z.string().max(50).optional(),
        expiryDate: z.string().optional(),
        attributes: z.record(z.string(), z.unknown()).default({}),
    })).min(1).max(200), // 200 lines = absurd already; keeps payload bounded
    discountCents: z.number().int().min(0).default(0),
    notes: z.string().max(1000).optional(),
    metadata: z.record(z.string(), z.unknown()).default({}),
});

// H-8: Return/refund schema
export const returnInvoiceSchema = z.object({
    items: z.array(z.object({
        itemId: z.string().uuid(),
        // M-5 FIX: Allow fractional returns (e.g. 2.5 ft of pipe, 0.75 kg putty)
        quantity: z.number().positive(),
        reason: z.string().max(500).optional(),
    })).min(1),
});

export const sendInvoiceSchema = z.object({
    method: z.enum(['whatsapp', 'sms', 'email']),
    to: z.string().min(1).max(200).trim(),
});

// ── Storage Schemas ─────────────────────────────────────────────────────────

export const signedUrlSchema = z.object({
    action: z.enum(['upload', 'download']),
    path: z.string().min(1).max(500),
    contentType: z.string().max(100).optional(),
    maxSizeMB: z.number().int().min(1).max(500).optional(), // Client-side size limit hint
    // MEDIUM FIX: Content length for upload validation
    contentLength: z.number().int().min(1).max(100 * 1024 * 1024).optional(),
}).refine(
    (data) => data.action !== 'upload' || !!data.contentType,
    { message: 'contentType is required for upload', path: ['contentType'] }
);

// ── Admin Schemas ───────────────────────────────────────────────────────────

export const killSwitchSchema = z.object({
    action: z.enum(['disable', 'enable']),
    reason: z.string().max(500).optional(),
});

// ── Report Schemas ──────────────────────────────────────────────────────────

export const dateRangeSchema = z.object({
    from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    groupBy: z.enum(['day', 'week', 'month']).default('day'),
});

// ── Customer Schemas (C5 Fix) ───────────────────────────────────────────────

export const createCustomerSchema = z.object({
    name: z.string().min(1).max(200).trim(),
    phone: z.string().max(15).optional(),
    email: z.string().email().max(200).optional(),
    gstin: z.string().max(15).optional(),
    address: z.string().max(500).optional(),
    city: z.string().max(100).optional(),
    state: z.string().max(100).optional(),
    pincode: z.string().max(10).optional(),
    creditLimitCents: z.number().int().min(0).default(0),
    // BUG-CREDIT-LIMIT-DAYS/BILLS FIX: rolling window credit limits.
    // creditMaxAgeDays   — bill cannot remain unpaid longer than N days
    // creditMaxOpenBills — at most N open udhar bills at once
    creditMaxAgeDays: z.number().int().min(1).max(365).optional(),
    creditMaxOpenBills: z.number().int().min(1).max(1000).optional(),
    // Customer tier — used by discount/loyalty engines (FLEET = corporate)
    tier: z.enum(['regular', 'silver', 'gold', 'platinum', 'fleet']).default('regular').optional(),
    customerType: z.enum(['individual', 'fleet', 'corporate', 'walk_in', 'government']).default('individual').optional(),
    discountPercent: z.number().min(0).max(100).optional(),
    notes: z.string().max(500).optional(),
});

export const updateCustomerSchema = createCustomerSchema.partial();

// ── Invoice Update Schema (H1 — Draft Edit) ───────────────────────────────

export const updateInvoiceSchema = z.object({
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().optional(),
        quantity: z.number().positive(),
        unitPriceCents: z.number().int().min(0),
        discountCents: z.number().int().min(0).default(0),
    })).min(1),
    customerName: z.string().max(200).optional(),
    customerPhone: z.string().max(15).optional(),
    customerGstin: z.string().max(15).optional(),
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']).optional(),
    invoiceType: z.enum(['tax_invoice', 'retail_invoice', 'proforma_invoice']).optional(),
    invoiceProfileId: z.string().max(100).optional(),
    notes: z.string().max(2000).optional(),
    discountCents: z.number().int().min(0).optional(),
    isInterState: z.boolean().optional(),
});


// ── Linking Schemas ─────────────────────────────────────────────────────────

export const generateLinkTokenSchema = z.object({
    expiresInMinutes: z.number().int().min(1).max(1440).default(30),
});

export const linkSchema = z.object({
    token: z.string().min(1).max(200),
});

// ── Notification Schemas ────────────────────────────────────────────────────

export const registerDeviceSchema = z.object({
    fcmToken: z.string().min(1).max(500),
    platform: z.enum(['android', 'ios', 'windows', 'macos', 'linux']).optional(),
    deviceName: z.string().max(100).optional(),
});

// ── AI/Insights Schemas ─────────────────────────────────────────────────────

export const aiInsightSchema = z.object({
    query: z.string().min(1).max(1000),
    context: z.record(z.string(), z.unknown()).optional(),
});

// ── Barcode/Stock Schemas ───────────────────────────────────────────────────

export const lookupBarcodeSchema = z.object({
    barcode: z.string().min(1).max(50).regex(
        /^[a-zA-Z0-9\-]+$/,
        'Barcode must contain only alphanumeric characters and hyphens'
    ),
});

/**
 * Add stock: creates a new product OR replenishes an existing one.
 * If `productId` is provided, adds stock to existing product.
 * If absent, creates a new product with the provided fields.
 */
export const addStockSchema = z.object({
    // If provided → replenish existing product. If absent → create new.
    productId: z.string().uuid().optional(),
    // Fields for new product creation
    name: z.string().min(1).max(200).trim().optional(),
    barcode: z.string().max(50).optional(),
    sku: z.string().max(50).optional(),
    category: z.string().max(100).optional(),
    brand: z.string().max(100).optional(),
    unit: z.string().max(20).default('pcs'),
    salePriceCents: z.number().int().min(0).optional(),
    purchasePriceCents: z.number().int().min(0).optional(),
    mrpCents: z.number().int().min(0).optional(),
    hsnCode: z.string().max(10).optional(),
    productType: z.string().max(30).default('general'),
    // Stock fields
    quantity: z.number().min(0).default(0),
    currentStock: z.number().min(0).optional(),
    batchNumber: z.string().max(50).optional(),
    expiryDate: z.string().optional(),
    notes: z.string().max(500).optional(),
}).refine(
    (data) => data.productId || data.name,
    { message: 'Either productId (replenish) or name (create new) is required' }
);

// ── Stock Adjustment Schema (BUG-004 FIX) ───────────────────────────────────

export const stockAdjustmentSchema = z.object({
    adjustmentQty: z.number()
        .refine(v => v !== 0, { message: 'Adjustment quantity must be non-zero' })
        .refine(v => Number.isFinite(v), { message: 'Adjustment quantity must be a finite number' }),
    reason: z.enum(['wastage', 'damage', 'theft', 'correction', 'expiry']),
    notes: z.string().max(500).optional(),
});

// ── Hardware Phase1+2 Procurement/Credit Schemas ────────────────────────────
export const createPurchaseOrderSchema = z.object({
    supplierId: z.string().uuid(),
    expectedDeliveryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    notes: z.string().max(1000).optional(),
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
        rateCents: z.number().int().min(0),
    })).min(1),
});

export const updatePurchaseOrderStatusSchema = z.object({
    status: z.enum(['draft', 'sent', 'partial', 'received', 'closed']),
    notes: z.string().max(500).optional(),
});

export const createGrnSchema = z.object({
    poId: z.string().uuid().optional(),
    supplierId: z.string().uuid(),
    invoiceNo: z.string().max(100).optional(),
    items: z.array(z.object({
        productId: z.string().uuid(),
        quantityReceived: z.number().positive(),
        quantityRejected: z.number().min(0).default(0),
        batchNumber: z.string().max(50).optional(),
        expiryDate: z.string().optional(),
        notes: z.string().max(500).optional(),
    })).min(1),
});

export const createPurchaseBillSchema = z.object({
    supplierId: z.string().uuid(),
    grnId: z.string().uuid().optional(),
    supplierInvoiceNumber: z.string().max(100),
    supplierInvoiceDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    gstin: z.string().max(15).optional(),
    items: z.array(z.object({
        productId: z.string().uuid(),
        quantity: z.number().positive(),
        taxableValueCents: z.number().int().min(0),
        cgstCents: z.number().int().min(0).default(0),
        sgstCents: z.number().int().min(0).default(0),
        igstCents: z.number().int().min(0).default(0),
        itcEligible: z.boolean().default(true),
    })).min(1),
});

export const createPartySchema = z.object({
    name: z.string().min(1).max(200).trim(),
    type: z.enum(['customer', 'supplier', 'contractor']).default('customer'),
    gstin: z.string().max(15).optional(),
    phone: z.string().max(20).optional(),
    address: z.string().max(500).optional(),
    creditLimitCents: z.number().int().min(0).default(0),
    creditDays: z.number().int().min(0).max(365).default(30),
    priceCategory: z.enum(['retail', 'contractor', 'wholesale', 'special']).default('retail'),
});

export const partyLedgerPostSchema = z.object({
    transactionType: z.enum(['sale', 'payment', 'adjustment', 'receipt']),
    debitCents: z.number().int().min(0).default(0),
    creditCents: z.number().int().min(0).default(0),
    referenceId: z.string().max(100).optional(),
    narration: z.string().max(500).optional(),
    allocationInvoiceId: z.string().uuid().optional(),
});

// ── Estimate / Quotation Schemas (Hardware Shop) ────────────────────────────

export const createEstimateSchema = z.object({
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unitPriceCents: z.number().int().min(0),
        unit: z.string().max(20).default('pcs'),
        hsnCode: z.string().max(10).optional(),
        cgstRateBp: z.number().int().min(0).max(10000).optional(),
        sgstRateBp: z.number().int().min(0).max(10000).optional(),
        igstRateBp: z.number().int().min(0).max(10000).optional(),
        notes: z.string().max(500).optional(),
    })).min(1),
    customerName: z.string().max(200).optional(),
    customerPhone: z.string().max(20).optional(),
    customerGstin: z.string().max(15).optional(),
    validityDays: z.number().int().min(1).max(365).default(15),
    isInterState: z.boolean().optional(),
    notes: z.string().max(1000).optional(),
    metadata: z.record(z.string(), z.unknown()).default({}),
});

export const convertEstimateSchema = z.object({
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'cheque', 'credit', 'wallet']).optional(),
}).optional().default({});

export const voidEstimateSchema = z.object({
    reason: z.string().min(1).max(500).trim(),
});

// ── Delivery Challan Schemas (Hardware Shop) ────────────────────────────────

export const createChallanSchema = z.object({
    sourceInvoiceId: z.string().uuid().optional(),
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().min(1).max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
    })).min(1),
    customerName: z.string().max(200),
    deliveryAddress: z.string().min(1).max(500),
    vehicleNumber: z.string().max(20).optional(),
    driverName: z.string().max(100).optional(),
    driverPhone: z.string().max(20).optional(),
    ewayBillNumber: z.string().max(20).optional(),
    notes: z.string().max(1000).optional(),
});

// ============================================================================
// SECURITY FIX S-7: Zod schemas for previously unvalidated handlers
// ============================================================================

// ── AI Feedback Schema ──────────────────────────────────────────────────────
export const aiFeedbackSchema = z.object({
    memoryId: z.string().max(200).optional(),
    predictionContext: z.string().min(1).max(5000),
    feedbackScore: z.number().min(-1).max(1),
    agentName: z.string().max(100).optional(),
});

// ── Book Return Schema ──────────────────────────────────────────────────────
export const createBookReturnSchema = z.object({
    vendorId: z.string().min(1).max(200),
    vendorName: z.string().max(200).optional(),
    returnDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    items: z.array(z.object({
        productId: z.string().uuid().optional(),
        name: z.string().max(200).optional(),
        isbn: z.string().max(20).optional(),
        qty: z.number().int().positive().max(99999),
        price: z.number().int().min(0).max(999_999_999_99),
    })).min(1).max(500),
    notes: z.string().max(1000).optional(),
});

export const createInstitutionalOrderSchema = z.object({
    institutionName: z.string().min(1).max(200),
    contactPerson: z.string().max(200).optional(),
    contactPhone: z.string().max(20).optional(),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    items: z.array(z.object({
        productId: z.string().uuid().optional(),
        name: z.string().max(200),
        isbn: z.string().max(20).optional(),
        qty: z.number().int().positive().max(99999),
        price: z.number().int().min(0).max(999_999_999_99),
    })).min(1).max(1000),
    notes: z.string().max(2000).optional(),
});

export const createConsignmentSchema = z.object({
    vendorId: z.string().min(1).max(200),
    vendorName: z.string().max(200).optional(),
    receivedDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    items: z.array(z.object({
        productId: z.string().uuid().optional(),
        name: z.string().max(200),
        isbn: z.string().max(20).optional(),
        qty: z.number().int().positive().max(99999),
        price: z.number().int().min(0).max(999_999_999_99),
    })).min(1).max(1000),
    notes: z.string().max(2000).optional(),
});

export const createConsignmentSettlementSchema = z.object({
    soldQty: z.number().int().min(0).default(0),
    returnedQty: z.number().int().min(0).default(0),
    settlementAmount: z.number().int().min(0).max(999_999_999_99).default(0),
    notes: z.string().max(2000).optional(),
    settlementDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

// ── Challan Delivery Schema ─────────────────────────────────────────────────
export const challanDeliveredSchema = z.object({
    receivedBy: z.string().min(1).max(200).trim(),
    notes: z.string().max(500).optional(),
});

// ── Grocery Batch Schemas ───────────────────────────────────────────────────
export const createGroceryBatchSchema = z.object({
    productId: z.string().uuid(),
    batchNumber: z.string().min(1).max(50).trim(),
    expiryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    quantityReceived: z.number().positive(),
    costPriceCents: z.number().int().min(0).optional(),
    supplierName: z.string().max(200).optional(),
    invoiceRef: z.string().max(100).optional(),
});

// ── Hardware Project Schemas ────────────────────────────────────────────────
export const createHardwareProjectSchema = z.object({
    projectName: z.string().min(1).max(200).trim(),
    contractorName: z.string().max(200).optional(),
    customerId: z.string().uuid().optional(),
    siteAddress: z.string().max(500).optional(),
    notes: z.string().max(1000).optional(),
});

export const createHardwareIndentSchema = z.object({
    projectId: z.string().uuid(),
    requestedBy: z.string().max(200),
    priority: z.enum(['low', 'normal', 'high']).default('normal'),
    items: z.array(z.object({
        productId: z.string().uuid(),
        name: z.string().max(200),
        quantity: z.number().positive(),
        unit: z.string().max(20).default('pcs'),
    })).min(1),
    notes: z.string().max(1000).optional(),
});

// ── Stock Analyze Image Schema ──────────────────────────────────────────────
export const analyzeImageSchema = z.object({
    image: z.string().min(1).max(10_000_000),  // Base64 encoded, max ~7.5MB image
});

// ── Clothing / Variants Schema ──────────────────────────────────────────────
export const bulkVariantUpdateSchema = z.object({
    productId: z.string().uuid(),
    variants: z.array(z.object({
        size: z.string().max(50).optional(),
        color: z.string().max(50).optional(),
        sku: z.string().max(100).optional(),
        barcode: z.string().max(50).optional(),
        priceCents: z.number().int().min(0),
        stock: z.number().int().min(0).default(0),
    })).min(1).max(500),
});

export const assignBarcodeToVariantSchema = z.object({
    productId: z.string().uuid(),
    variantId: z.string().uuid(),
    barcode: z.string().max(50),
});

// ── Tailoring Notes Schema ───────────────────────────────────────────────────
export const createTailoringNoteSchema = z.object({
    invoiceId: z.string().uuid(),
    customerId: z.string().uuid().optional(),
    measurements: z.object({
        chest: z.number().positive().optional(),
        waist: z.number().positive().optional(),
        hips: z.number().positive().optional(),
        length: z.number().positive().optional(),
        sleeve: z.number().positive().optional(),
        shoulder: z.number().positive().optional(),
        neck: z.number().positive().optional(),
        inseam: z.number().positive().optional(),
        customNotes: z.string().max(500).optional(),
    }),
    deliveryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    priority: z.enum(['normal', 'urgent', 'express']).default('normal'),
    notes: z.string().max(1000).optional(),
});

export const updateTailoringStatusSchema = z.object({
    status: z.enum(['measurement_taken', 'cutting', 'stitching', 'finishing', 'ready_for_delivery', 'delivered']),
    notes: z.string().max(500).optional(),
    estimatedCompletion: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export const updateTailoringMeasurementsSchema = z.object({
    measurements: z.object({
        chest: z.number().positive().optional(),
        waist: z.number().positive().optional(),
        hips: z.number().positive().optional(),
        length: z.number().positive().optional(),
        sleeve: z.number().positive().optional(),
        shoulder: z.number().positive().optional(),
        neck: z.number().positive().optional(),
        inseam: z.number().positive().optional(),
        customNotes: z.string().max(500).optional(),
    }),
});
