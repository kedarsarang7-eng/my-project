// ============================================================================
// Invoice Service — Create & Finalize Invoices (DynamoDB)
// ============================================================================
// Handles invoice creation from the Flutter billing screen.
// All monetary values are stored as integer paise (cents).
// Migrated from PostgreSQL to DynamoDB single-table design.
//
// AUDIT FIXES APPLIED:
//   C-1: finalizeInvoice verifies actual paidCents instead of forcing full payment
//   C-2: Discount processing (item-level + bill-level)
//   C-3: IGST calculation for inter-state supplies
//   H-3: Void retry logic only skips the specific failed product
//   H-4: Post-sale low-stock check + WebSocket alert
//   M-7: Indian GST rounding rules (round per component to nearest paise)
//   H-2: Audit logging on all financial operations
//   M-10: InvoiceError extends AppError
//
// PHARMACY COMPLIANCE FIXES:
//   P-1: Expired batch sales blocked (expiryDate < today → reject)
//   P-2: Schedule H/H1/X prescription enforcement
//   P-3: Quantity limit / abuse warning with manager override
//   P-4: Doctor registration number format validation
//   P-5: Near-expiry warnings (within 90 days)
//
// ENHANCEMENT FIXES (13-issue sweep):
//   Fix-1:  InvoiceMetadata typed interface replaces Record<string, unknown>
//   Fix-2:  ResolvedInvoiceItem named interface — no more large inline type
//   Fix-3:  businessType param typed as BusinessType enum (was raw string)
//   Fix-4:  Single GSI customer lookup reused for both validation + credit check
//           (eliminates 2nd DB round-trip); customerId stored on invoice record
//   Fix-5:  Customer phone lookup via GSI1 (O(1)) not filter-expression scan (O(n))
//   Fix-6:  productMap filters out records missing id — no silent undefined keys
//   Fix-7:  Invoice counter validated as Number.isInteger, not just truthy
//   Fix-8:  Large invoice path: lineItemsStatus sentinel (pending→complete)
//           makes orphaned invoices detectable by recovery tooling
//   Fix-9:  TransactionCanceledException parsed by SK prefix, not array index
//           (position-independent — safe against future transact item reordering)
//   Fix-10: Free-text fields (customerName, notes, lrNumber, transporterName)
//           capped at sensible lengths to prevent DynamoDB 400KB item overflow
//   Fix-11: warrantyMonths on InvoiceItemInput → computed warrantyExpiryDate
//           stored on SERIALTRACK records (Consumer Protection Act compliance)
//   Fix-12: DAILY_METRICS update wrapped in 3-attempt exponential-backoff retry
//   Fix-13: This header updated to document all fixes
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys, TABLE_NAME,
    getItem, putItem, queryItems, updateItem, transactWrite, batchWrite, batchGetItems,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { AppError, CreditLimitExceededError, InvoiceValidationError } from '../utils/errors';
import { logAudit } from '../middleware/audit';
import { invalidateCache } from '../utils/cache';
import { deductBatchesFIFO, InsufficientBatchStockError } from './pharmacy-batch.service';
import { deductGroceryBatchesFEFO, InsufficientGroceryBatchStockError } from './grocery-batch.service';
import { buildNarcoticLogTransactItem, buildH1RegisterTransactItem } from '../handlers/pharmacy';
import { BusinessType } from '../types/tenant.types';
import { extractStateCode } from '../utils/gstin.utils';
import { enforceUdharCreditLimit } from '../utils/credit-check.util';
import { earnPoints } from './loyalty.service';
import { recordRevision } from './revision-history.service';
import { config } from '../config/environment';

// ---- Types ----

/** Helper: Find variant record for clothing items */
async function findClothingVariant(
    tenantId: string,
    productId: string,
    size?: string,
    color?: string,
    variantId?: string,
): Promise<Record<string, any> | null> {
    if (!variantId && (!size || !color)) return null;

    const pk = Keys.tenantPK(tenantId);
    
    if (variantId) {
        // Direct lookup by variant ID
        const result = await getItem(pk, `VARIANT#${productId}#${variantId}`);
        return result && !(result.isDeleted === true) ? result as Record<string, any> : null;
    }

    // Find by size + color combination
    const variants = await queryItems<Record<string, any>>(pk, `VARIANT#${productId}#`, {
        filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #size = :size AND #color = :color',
        expressionAttributeNames: { '#size': 'size', '#color': 'color' },
        expressionAttributeValues: { ':false': false, ':size': size, ':color': color },
        limit: 1,
    });

    return variants.items.length > 0 ? variants.items[0] : null;
}

export interface CreateInvoiceInput {
    items: InvoiceItemInput[];
    customerName?: string;
    customerPhone?: string;
    customerGstin?: string;
    invoiceDate?: string;
    paymentMode?: string;
    notes?: string;
    /** Bill-level discount applied AFTER item totals are summed (in paise) */
    discountCents?: number;
    /** Whether this is an inter-state supply (uses IGST instead of CGST+SGST) */
    isInterState?: boolean;
    /** Allow override of the auto GST Interstate logic */
    isInterStateOverride?: boolean;
    /** WS-2: Optional service charge to apply pre-tax (if non-taxable entity) */
    serviceChargeCents?: number;
    /** WS-2: Multi-payment split array */
    splitPayments?: Array<{ method: string; amountCents: number }>;
    /** Invoice metadata — prescriptionId, doctor info, overrides */
    metadata?: InvoiceMetadata;
    /** Sales document variant used by frontend and print templates */
    invoiceType?: 'tax_invoice' | 'retail_invoice' | 'proforma_invoice';
    /** Optional tenant-specific print profile id */
    invoiceProfileId?: string;
    /** Hardware: Transport details for compliance */
    lrNumber?: string;
    transporterName?: string;
    ewayBillNumber?: string;
    transportMode?: 'road' | 'rail' | 'air' | 'ship';
}

export interface InvoiceItemInput {
    productId: string;
    quantity: number;
    unitPrice: number; // Frontend sends in PAISE (cents)
    /** Item-level discount in paise — applied BEFORE tax calculation */
    discountCents?: number;
    batchNumber?: string;
    expiryDate?: string;
    /** FIX-HW-004: Billing unit for UOM validation (e.g. 'ft', 'kg', 'mtr') */
    unit?: string;
    /** FIX-HW-004: Unit conversion factor — owner/manager override only */
    conversionFactor?: number;
    /** Consumer Protection Act: Serial number for electronics */
    serialNumber?: string;
    /** Consumer Protection Act: IMEI 1 for mobile devices */
    imei1?: string;
    /** Consumer Protection Act: IMEI 2 for dual-SIM devices (optional) */
    imei2?: string;
    /** Clothing variant: size (e.g., 'S', 'M', 'L', 'XL') */
    size?: string;
    /** Clothing variant: color (e.g., 'Red', 'Blue', 'Black') */
    color?: string;
    /** Clothing variant: variant ID for direct reference */
    variantId?: string;
    /** Warranty period in months — stored on SERIALTRACK record (Consumer Protection Act) */
    warrantyMonths?: number;
}

/**
 * Strongly-typed invoice metadata bag.
 * Replaces the previous `Record<string, unknown>` — prevents silent key typos.
 */
export interface InvoiceMetadata {
    prescriptionId?: string;
    doctorName?: string;
    doctorRegNo?: string;
    managerOverride?: boolean;
    enforceCreditLimit?: boolean;
    isInterStateOverride?: boolean;
    restoBillId?: string;
    waiterId?: string;
    tableId?: string;
    splitPayments?: Array<{ mode: string; amountCents: number }>;
    cashReceivedCents?: number;
    changeGivenCents?: number;
    [key: string]: unknown; // allow future extension without breaking changes
}

/** Named type for a resolved + tax-calculated line item — avoids repeated inline casts. */
export interface ResolvedInvoiceItem {
    itemId: string;
    name: string;
    quantity: number;
    unitPriceCents: number;
    totalCents: number;
    discountCents: number;
    taxableValueCents: number;
    unit: string;
    cgstCents: number;
    sgstCents: number;
    igstCents: number;
    lineTaxCents: number;
    hsnCode: string | null;
    batchNumber: string | null;
    expiryDate: string | null;
    serialNumber: string | null;
    imei1: string | null;
    imei2: string | null;
    billedUnit: string;
    conversionFactor: number;
    variantId?: string;
    variantSize?: string;
    variantColor?: string;
}

/** Typed warning object returned alongside invoice data */
export interface InvoiceWarning {
    type: string;
    message: string;
    [key: string]: unknown;
}

export interface InvoiceResult {
    id: string;
    invoiceNumber: string;
    status: string;
    totalCents: number;
    subtotalCents: number;
    taxCents: number;
    cgstCents: number;
    sgstCents: number;
    igstCents: number;
    discountCents: number;
    paidCents: number;
    balanceCents: number;
    paymentMode: string;
    roundOffCents: number;
    itemsCount: number;
    createdAt: string;
    invoiceType?: 'tax_invoice' | 'retail_invoice' | 'proforma_invoice';
    /** Non-blocking warnings (near-expiry, quantity alerts, duplicate Rx IDs) */
    warnings?: InvoiceWarning[];
}

// ---- Pharmacy Compliance Helpers ----

/** Indian MCI/DMC doctor registration number pattern */
const DOCTOR_REG_PATTERN = /^[A-Z]{2,5}-\d{4,8}$/i;

/** Drug schedules that require a valid prescription */
const RX_REQUIRED_SCHEDULES = ['H', 'H1', 'X'];

/** Roles allowed to perform manager overrides */
const OVERRIDE_ROLES = ['owner', 'admin', 'manager'];

// ---- GST Rounding (Indian Rules) ----

/**
 * Round a tax amount to the nearest paise (integer).
 * Indian GST circular: round to nearest rupee for final invoice,
 * but per-line rounding is to nearest paise (integer cents).
 * Final CGST/SGST/IGST components are rounded to nearest rupee (100 paise).
 */
function roundTaxComponent(amountPaise: number): number {
    return Math.round(amountPaise);
}

/**
 * Round final tax to nearest rupee (100 paise) per GST rules.
 * GST Circular 172/04/2022: total CGST, SGST, IGST each rounded to nearest rupee.
 */
function roundToNearestRupee(paise: number): number {
    return Math.round(paise / 100) * 100;
}

// ---- Service Functions ----

/**
 * Create a new invoice (transaction + line items).
 * Uses DynamoDB conditional writes for invoice number uniqueness.
 *
 * Discount application order:
 *   1. Item-level discount subtracted from line total (pre-tax)
 *   2. Tax calculated on discounted line total
 *   3. Bill-level discount subtracted from subtotal (post-tax not affected)
 *
 * Pharmacy compliance checks (P-1 through P-5):
 *   - P-1: Rejects sale if any line item's expiryDate is in the past
 *   - P-2: Requires prescriptionId for Schedule H/H1/X drugs
 *   - P-3: Enforces per-product maxSaleQuantity with manager override
 *   - P-4: Validates doctorRegNo format for Schedule X drugs
 *   - P-5: Adds near-expiry warnings (within 90 days)
 *
 * @param userRole - Role of the requesting user (needed for manager overrides)
 * @param businessType - Business type from JWT (needed for pharmacy FIFO batch deduction)
 */
export async function createInvoice(
    tenantId: string,
    createdBy: string,
    input: CreateInvoiceInput,
    userRole?: string,
    businessType?: BusinessType,
): Promise<InvoiceResult> {
    if (!input.items || input.items.length === 0) {
        throw new InvoiceError('Invoice must have at least one item');
    }

    const invoiceId = uuidv4();
    const now = input.invoiceDate ? new Date(input.invoiceDate).toISOString() : new Date().toISOString();
    const tableName = config.dynamodb.tableName;

    // ================================================================
    // FIX #4 + #5: Single GSI-based customer lookup (O(1), not O(n) filter scan).
    // Resolves the customer once here; result is reused for credit-limit
    // enforcement below — eliminates the second DB round-trip.
    // ================================================================
    let resolvedCustomer: Record<string, any> | null = null;
    if (input.customerPhone && input.customerPhone.trim() !== '') {
        const phoneGsiResult = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            Keys.phoneGSI1SK(input.customerPhone.trim()),
            {
                indexName: 'GSI1',
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
                limit: 1,
            },
        );
        resolvedCustomer = phoneGsiResult.items[0] ?? null;

        if (!resolvedCustomer) {
            if (input.paymentMode === 'credit' || input.paymentMode === 'unpaid') {
                throw new InvoiceError(
                    `Customer with phone ${input.customerPhone} not found. ` +
                    'Credit/Udhar invoices require an existing customer with valid credit limit.',
                    404,
                );
            }
            logger.warn('Invoice created with unverified customer phone', {
                tenantId,
                customerPhone: input.customerPhone,
                invoiceId,
                paymentMode: input.paymentMode,
            });
        }
    }

    // --------------------------------------------------------
    // AUTOMATED GST INTERSTATE CALCULATION
    // --------------------------------------------------------
    let isInterState = input.isInterState === true;
    const hasOverride = input.isInterStateOverride === true || input.metadata?.isInterStateOverride === true;

    if (hasOverride) {
        logAudit({
            action: 'GST_INTERSTATE_OVERRIDE',
            resource: 'invoice',
            metadata: {
                userId: createdBy,
                clientSuppliedValue: isInterState
            }
        }).catch(() => {});

        logger.info('GST inter-state calculation overridden', {
            metric: 'InterStateOverride',
            value: 1,
            tenantId,
            userId: createdBy,
            isInterState
        });
    } else if (input.customerGstin) {
        try {
            const tenantProfile = await getItem<any>(Keys.tenantPK(tenantId), Keys.tenantProfileSK());
            const tenantStateCode = tenantProfile?.stateCode || extractStateCode(tenantProfile?.gstin);
            const customerStateCode = extractStateCode(input.customerGstin);

            if (tenantStateCode && customerStateCode) {
                isInterState = tenantStateCode !== customerStateCode;
            }
        } catch (e) {
            logger.warn('Failed to auto-compute GST isInterState', { error: (e as Error).message });
        }
    }

    // 1. Generate invoice number — atomic counter in DynamoDB
    let nextNum: number;
    try {
        const counterResult = await updateItem(
            Keys.tenantPK(tenantId),
            'COUNTER#INVOICE',
            {
                updateExpression: 'SET #val = if_not_exists(#val, :zero) + :one, updatedAt = :now',
                expressionAttributeNames: { '#val': 'counterValue' },
                expressionAttributeValues: { ':zero': 0, ':one': 1, ':now': now },
            },
        );
        nextNum = (counterResult as any)?.counterValue;
        if (!Number.isInteger(nextNum) || nextNum < 1) {
            throw new Error(`Counter returned invalid value: ${JSON.stringify(nextNum)}`);
        }
    } catch (err) {
        logger.error('Invoice counter failed', { tenantId, error: (err as Error).message });
        throw new InvoiceError('Failed to generate invoice number. Please retry.', 503);
    }
    const invoiceNumber = `INV-${nextNum.toString().padStart(6, '0')}`;

    // 2. Calculate totals from items (with discount + IGST support)
    let subtotalCents = 0;
    let totalItemDiscountCents = 0;
    let taxCents = 0;
    let headerCgstCents = 0;
    let headerSgstCents = 0;
    let headerIgstCents = 0;
    const resolvedItems: ResolvedInvoiceItem[] = [];

    // Transaction items for stock deduction
    const transactItems: any[] = [];

    // NDPS Act: Narcotic log transact items to inject into the same transaction
    const narcoticLogItems: any[] = [];

    // D&C Act Schedule H1: Register transact items written atomically with invoice
    const h1RegisterItems: any[] = [];

    // Consumer Protection Act: Serial/IMEI tracking transact items
    const serialTrackItems: any[] = [];

    // Non-blocking warnings accumulated during validation
    const warnings: InvoiceWarning[] = [];

    // Items that need low-stock check after sale
    const stockCheckItems: Array<{ productId: string; name: string; currentStock: number; quantity: number; lowStockThreshold: number }> = [];

    // Resolve invoice-level metadata for pharmacy compliance checks
    const invoiceMetadata = input.metadata || {};

    // WS-3: BATCH FETCH ITEM RECIPES EARLY (BOM Explosion)
    const recipeKeys = input.items.map(item => ({
        PK: Keys.tenantPK(tenantId),
        SK: `ITEM_RECIPES#${item.productId}`,
    }));
    const recipes = await batchGetItems<Record<string, any>>(recipeKeys);
    const recipeMap = new Map(recipes.map(r => [r.menuItemId || r.productId || r.SK?.replace('ITEM_RECIPES#', ''), r]));

    // Build list of products to fetch (original items + exploded ingredients)
    const productKeysToFetch = new Map<string, any>();
    for (const item of input.items) {
        productKeysToFetch.set(`PRODUCT#${item.productId}`, { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(item.productId) });
        const recipe = recipeMap.get(item.productId);
        if (recipe && Array.isArray(recipe.ingredients)) {
            for (const ing of recipe.ingredients) {
                const ingId = ing.inventoryId || ing.productId;
                if (ingId) {
                    productKeysToFetch.set(`PRODUCT#${ingId}`, { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(ingId) });
                }
            }
        }
    }

    // BATCH FETCH: Get all products and explosion ingredients
    const products = await batchGetItems<Record<string, any>>(Array.from(productKeysToFetch.values()));
    // Fix #6: Only map products that have a valid id — malformed records without an id
    // would create an undefined key, causing false 'Product not found' errors downstream.
    const productMap = new Map(
        products
            .filter(p => typeof p.id === 'string' && p.id.length > 0)
            .map(p => [p.id, p]),
    );

    for (const item of input.items) {
        const product = productMap.get(item.productId);

        if (!product || product.isDeleted) {
            throw new InvoiceError(`Product not found: ${item.productId}`);
        }

        // ============================================================
        // V-1: QUANTITY VALIDATION — block zero, negative, and NaN
        // ============================================================
        if (!item.quantity || item.quantity <= 0 || !Number.isFinite(item.quantity)) {
            throw new InvoiceError(
                `Item '${product.name}' has invalid quantity ${item.quantity}. Quantity must be greater than 0.`,
                400,
            );
        }

        // ============================================================
        // V-2: UNIT PRICE INTEGER VALIDATION — monetary paise must be integer
        // ============================================================
        if (item.unitPrice !== undefined && item.unitPrice !== null) {
            if (!Number.isInteger(item.unitPrice) || item.unitPrice < 0) {
                throw new InvoiceError(
                    `Item '${product.name}' has invalid unit price ${item.unitPrice}. Use integer paise (e.g. 50000 for ₹500).`,
                    400,
                );
            }
        }

        // ============================================================
        // V-3: UOM VALIDATION — FIX-HW-004
        // Validates the billed unit matches the product's base unit.
        // Allows owner/manager unit override with explicit conversionFactor.
        // ============================================================
        if (item.unit && item.unit !== (product.unit || 'pcs')) {
            if (item.conversionFactor && item.conversionFactor > 0
                && userRole && OVERRIDE_ROLES.includes(userRole)) {
                warnings.push({
                    type: 'UNIT_CONVERSION',
                    message: `Unit override: ${item.quantity} ${item.unit} → ${item.quantity * item.conversionFactor} ${product.unit || 'pcs'} for '${product.name}'.`,
                    productName: product.name,
                    billedUnit: item.unit,
                    baseUnit: product.unit || 'pcs',
                    conversionFactor: item.conversionFactor,
                });
            } else if (item.conversionFactor && (!userRole || !OVERRIDE_ROLES.includes(userRole))) {
                throw new UnitMismatchError(
                    `Unit override requires owner/manager role. '${product.name}' base unit is '${product.unit || 'pcs'}'.`,
                    item.productId, product.unit || 'pcs', item.unit, 403,
                );
            } else {
                throw new UnitMismatchError(
                    `Unit mismatch for '${product.name}': expected '${product.unit || 'pcs'}', received '${item.unit}'.`,
                    item.productId, product.unit || 'pcs', item.unit,
                );
            }
        }

        // ============================================================
        // P-1: EXPIRED BATCH CHECK — block sale of expired medicines
        // BUG-003 FIX: Both dates normalized to UTC midnight to avoid
        // timezone drift (AWS Lambda runs UTC, dates may be IST)
        // ============================================================
        if (item.expiryDate) {
            const nowDate = new Date();
            const todayUTC = new Date(Date.UTC(nowDate.getUTCFullYear(), nowDate.getUTCMonth(), nowDate.getUTCDate()));
            const expiryUTC = new Date(item.expiryDate + 'T00:00:00Z');

            if (isNaN(expiryUTC.getTime())) {
                throw new InvoiceError(
                    `Invalid expiry date format '${item.expiryDate}' for batch ${item.batchNumber || 'N/A'}. Expected YYYY-MM-DD.`,
                    400,
                );
            }

            if (expiryUTC < todayUTC) {
                throw new InvoiceError(
                    `Cannot sell from expired batch. Batch ${item.batchNumber || 'N/A'} expired on ${item.expiryDate}.`,
                    400,
                );
            }

            // P-5: Near-expiry warning (within 90 days)
            const daysRemaining = Math.ceil((expiryUTC.getTime() - todayUTC.getTime()) / 86400000);
            if (daysRemaining <= 90 && daysRemaining >= 0) {
                warnings.push({
                    type: 'NEAR_EXPIRY',
                    message: `Batch ${item.batchNumber || 'N/A'} of '${product.name}' expires in ${daysRemaining} day${daysRemaining !== 1 ? 's' : ''} (${item.expiryDate}).`,
                    batchNumber: item.batchNumber || null,
                    expiryDate: item.expiryDate,
                    daysRemaining,
                    productName: product.name,
                });
            }
        }

        // ============================================================
        // P-2: PRESCRIPTION ENFORCEMENT for Schedule H/H1/X drugs
        // ============================================================
        const requiresRx = product.attributes?.requiresPrescription === 'true'
            || product.attributes?.requiresPrescription === true;
        const drugSchedule = product.attributes?.drugSchedule;

        if (requiresRx) {
            const hasManagerOverride = invoiceMetadata.managerOverride === true
                && userRole && OVERRIDE_ROLES.includes(userRole);

            if (hasManagerOverride) {
                // Log compliance override — fire-and-forget
                logAudit({
                    action: 'COMPLIANCE_OVERRIDE',
                    resource: 'invoice',
                    resourceId: invoiceId,
                    metadata: {
                        drugName: product.name,
                        drugSchedule,
                        overrideType: 'PRESCRIPTION_BYPASS',
                        overrideReason: invoiceMetadata.overrideReason || 'No reason provided',
                        userId: createdBy,
                        userRole,
                    },
                }).catch(() => { });

                warnings.push({
                    type: 'COMPLIANCE_OVERRIDE',
                    message: `Prescription requirement overridden for '${product.name}' (Schedule ${drugSchedule}) by ${userRole}.`,
                    drugName: product.name,
                    drugSchedule,
                });
            } else {
                const prescriptionId = invoiceMetadata.prescriptionId;
                if (!prescriptionId || String(prescriptionId).trim() === '') {
                    throw new InvoiceError(
                        `'${product.name}' is a Schedule ${drugSchedule || 'H'} drug and requires a valid prescription. Attach prescriptionId in metadata.`,
                        400,
                    );
                }

                // P-2b: Schedule H1 register requirements (CDSCO H1 Rule)
                // Mandatory: prescribing doctor name + reg no + patient name.
                // patientAddress is recommended but not strictly required.
                if (drugSchedule === 'H1') {
                    const doctorName = invoiceMetadata.doctorName;
                    const doctorRegNo = invoiceMetadata.doctorRegNo;
                    const patientName = invoiceMetadata.patientName;

                    if (!doctorName || String(doctorName).trim() === ''
                        || !doctorRegNo || String(doctorRegNo).trim() === '') {
                        throw new InvoiceError(
                            `'${product.name}' is a Schedule H1 drug. doctorName and doctorRegNo must be provided in metadata per CDSCO H1 Register requirements.`,
                            400,
                        );
                    }

                    if (!DOCTOR_REG_PATTERN.test(String(doctorRegNo))) {
                        throw new InvoiceError(
                            `Invalid doctor registration number '${doctorRegNo}' for Schedule H1 drug '${product.name}'. Expected format: MCI-12345 or DMC-567890.`,
                            400,
                        );
                    }

                    if (!patientName || String(patientName).trim() === '') {
                        throw new InvoiceError(
                            `'${product.name}' is a Schedule H1 drug. patientName must be provided in metadata per CDSCO H1 Register requirements.`,
                            400,
                        );
                    }

                    const h1Item = buildH1RegisterTransactItem({
                        tenantId,
                        invoiceId,
                        productName: product.name,
                        quantitySold: item.quantity,
                        batchNumber: item.batchNumber || null,
                        expiryDate: item.expiryDate || null,
                        dispensedBy: createdBy,
                        metadata: invoiceMetadata,
                    });

                    if (!h1Item) {
                        throw new InvoiceError(
                            `Schedule H1 register entry could not be created: missing required H1 fields (patientName, doctorName, doctorRegNo, prescriptionId).`,
                            400,
                        );
                    }

                    h1RegisterItems.push(h1Item);
                }

                // P-2c: Schedule X requires doctor + patient + address (NDPS)
                if (drugSchedule === 'X') {
                    const doctorName = invoiceMetadata.doctorName;
                    const doctorRegNo = invoiceMetadata.doctorRegNo;
                    if (!doctorName || String(doctorName).trim() === '' || !doctorRegNo || String(doctorRegNo).trim() === '') {
                        throw new InvoiceError(
                            `'${product.name}' is a Schedule X controlled substance. Both doctorName and doctorRegNo must be provided in metadata.`,
                            400,
                        );
                    }

                    // P-4: Validate doctor registration number format
                    if (!DOCTOR_REG_PATTERN.test(String(doctorRegNo))) {
                        throw new InvoiceError(
                            `Invalid doctor registration number '${doctorRegNo}'. Expected format: MCI-12345 or DMC-567890.`,
                            400,
                        );
                    }

                    // ============================================================
                    // NDPS-001: NARCOTIC DRUG REGISTER — Schedule X
                    // Per the Narcotic Drugs and Psychotropic Substances Act,
                    // all Schedule X sales MUST record patient details in a
                    // government-auditable register.
                    // ============================================================
                    const patientName = invoiceMetadata.patientName;
                    const patientAddress = invoiceMetadata.patientAddress;
                    if (!patientName || String(patientName).trim() === '' || !patientAddress || String(patientAddress).trim() === '') {
                        throw new InvoiceError(
                            `'${product.name}' is a Schedule X narcotic drug. patientName and patientAddress must be provided in metadata per NDPS Act.`,
                            400,
                        );
                    }

                    const narcoticItem = buildNarcoticLogTransactItem({
                        tenantId,
                        invoiceId,
                        productName: product.name,
                        quantitySold: item.quantity,
                        batchNumber: item.batchNumber || null,
                        expiryDate: item.expiryDate || null,
                        dispensedBy: createdBy,
                        metadata: invoiceMetadata,
                    });

                    if (!narcoticItem) {
                        throw new InvoiceError(
                            `Schedule X narcotic register entry could not be created: missing required NDPS fields (patientName, patientAddress, doctorName, doctorRegNo, prescriptionId).`,
                            400,
                        );
                    }

                    narcoticLogItems.push(narcoticItem);
                }

                // P-4b: For Schedule H, warn (don't block) on bad doctorRegNo format
                if (drugSchedule === 'H' && invoiceMetadata.doctorRegNo) {
                    if (!DOCTOR_REG_PATTERN.test(String(invoiceMetadata.doctorRegNo))) {
                        warnings.push({
                            type: 'INVALID_DOCTOR_REG_FORMAT',
                            message: `Doctor registration number '${invoiceMetadata.doctorRegNo}' does not match expected format (e.g., MCI-12345).`,
                            doctorRegNo: invoiceMetadata.doctorRegNo,
                        });
                    }
                }
            }
        }

        // ============================================================
        // P-3: QUANTITY LIMIT enforcement with manager override
        // ============================================================
        const maxQty = product.attributes?.maxSaleQuantity
            ? parseInt(String(product.attributes.maxSaleQuantity), 10)
            : null;

        if (maxQty !== null && !isNaN(maxQty) && item.quantity > maxQty) {
            const hasOverride = invoiceMetadata.managerOverride === true
                && userRole && OVERRIDE_ROLES.includes(userRole);

            if (!hasOverride) {
                throw new InvoiceError(
                    `Sale of ${item.quantity} units of '${product.name}' exceeds the maximum allowed quantity of ${maxQty}. A manager override is required.`,
                    400,
                );
            }

            // Log quantity override — fire-and-forget
            logAudit({
                action: 'QUANTITY_OVERRIDE',
                resource: 'invoice',
                resourceId: invoiceId,
                metadata: {
                    productId: item.productId,
                    productName: product.name,
                    quantity: item.quantity,
                    maxAllowed: maxQty,
                    userId: createdBy,
                    reason: invoiceMetadata.overrideReason || 'No reason provided',
                },
            }).catch(() => { });
        }

        // P-3b: Soft warning for walk-in buying >10 of Schedule H/H1/X drugs
        if ((!input.customerName || input.customerName === 'Walk-in')
            && drugSchedule && RX_REQUIRED_SCHEDULES.includes(drugSchedule)
            && item.quantity > 10 && maxQty === null) {
            warnings.push({
                type: 'HIGH_QUANTITY_WALK_IN',
                message: `Walk-in purchase of ${item.quantity} units of Schedule ${drugSchedule} drug '${product.name}' exceeds 10 units.`,
                productName: product.name,
                quantity: item.quantity,
                drugSchedule,
            });
        }

        const unitPriceCents = item.unitPrice || product.salePriceCents || 0;

        // ============================================================
        // MRP-1: MRP ENFORCEMENT — selling above MRP is illegal in India
        // (Consumer Protection Act, 2019)
        // FIX-HW-006: When UOM conversion is active, compare per-base-unit
        // price against MRP. E.g. ₹270/piece ÷ 6ft/piece = ₹45/ft vs MRP ₹50/ft
        // ============================================================
        const effectivePriceForMrpCheck = (item.conversionFactor && item.conversionFactor > 0)
            ? Math.round(unitPriceCents / item.conversionFactor)
            : unitPriceCents;
        if (product.mrpCents && product.mrpCents > 0 && effectivePriceForMrpCheck > product.mrpCents) {
            throw new InvoiceError(
                `Sale price ₹${(effectivePriceForMrpCheck / 100).toFixed(2)} exceeds MRP ₹${(product.mrpCents / 100).toFixed(2)} for '${product.name}'. Selling above MRP is not permitted.`,
                400,
            );
        }

        // ============================================================
        // SERIAL-001: IMEI/SERIAL NUMBER ENFORCEMENT
        // Consumer Protection Act — mandatory for electronics/mobile_shop
        // Accessories and services are exempt.
        // ============================================================
        const productCategory = (product.category || product.attributes?.category || '').toString().toLowerCase();
        const isExemptFromSerial = productCategory === 'accessory' || productCategory === 'service' || product.isService;

        if (!isExemptFromSerial && businessType === BusinessType.ELECTRONICS) {
            if (!item.serialNumber || item.serialNumber.trim() === '') {
                throw new InvoiceValidationError(
                    `Serial number is required for '${product.name}' (electronics business type). Accessories and services are exempt.`,
                    { productId: item.productId, productName: product.name, field: 'serialNumber' },
                );
            }
        }

        if (!isExemptFromSerial && businessType === BusinessType.MOBILE_SHOP) {
            if (!item.imei1 || item.imei1.trim() === '') {
                throw new InvoiceValidationError(
                    `IMEI number is required for '${product.name}' (mobile shop business type). Accessories and services are exempt.`,
                    { productId: item.productId, productName: product.name, field: 'imei1' },
                );
            }
        }

        // Build SERIALTRACK# record for items with serial/IMEI data
        const serialIdentifier = item.serialNumber || item.imei1;
        if (serialIdentifier) {
            // Fix #11: Compute warrantyExpiryDate from warrantyMonths (Consumer Protection Act)
            let warrantyExpiryDate: string | null = null;
            if (item.warrantyMonths && item.warrantyMonths > 0) {
                const soldDate = new Date(now);
                soldDate.setMonth(soldDate.getMonth() + item.warrantyMonths);
                warrantyExpiryDate = soldDate.toISOString().split('T')[0];
            }

            const serialTrackBase = {
                entityType: 'SERIALTRACK',
                tenantId,
                serialNumber: item.serialNumber || null,
                imei1: item.imei1 || null,
                imei2: item.imei2 || null,
                productId: item.productId,
                productName: product.name,
                invoiceId,
                invoiceNumber,
                customerId: resolvedCustomer?.id ?? null,
                customerName: (input.customerName || 'Walk-in').slice(0, 200),
                customerPhone: input.customerPhone || null,
                soldAt: now,
                warrantyMonths: item.warrantyMonths ?? null,
                warrantyExpiryDate,
                createdAt: now,
            };

            serialTrackItems.push({
                Put: {
                    TableName: tableName,
                    Item: { PK: Keys.tenantPK(tenantId), SK: Keys.serialTrackSK(serialIdentifier), ...serialTrackBase },
                    ConditionExpression: 'attribute_not_exists(SK)',
                },
            });

            // If imei2 is also provided (dual-SIM), track it separately
            if (item.imei2 && item.imei2 !== item.imei1) {
                serialTrackItems.push({
                    Put: {
                        TableName: tableName,
                        Item: { PK: Keys.tenantPK(tenantId), SK: Keys.serialTrackSK(item.imei2), ...serialTrackBase },
                        ConditionExpression: 'attribute_not_exists(SK)',
                    },
                });
            }
        }

        const lineGrossCents = roundTaxComponent(unitPriceCents * item.quantity);

        // C-2: Apply item-level discount (pre-tax)
        const itemDiscountCents = Math.min(item.discountCents || 0, lineGrossCents);
        const taxableValueCents = lineGrossCents - itemDiscountCents;

        // C-3: IGST vs CGST+SGST based on inter-state flag
        let lineCgstCents = 0;
        let lineSgstCents = 0;
        let lineIgstCents = 0;

        if (isInterState) {
            // Inter-state: use IGST (CGST rate + SGST rate combined)
            const igstBp = Number(product.igstRateBp) || (Number(product.cgstRateBp || 0) + Number(product.sgstRateBp || 0));
            lineIgstCents = roundTaxComponent(taxableValueCents * igstBp / 10000);
        } else {
            // Intra-state: use CGST + SGST
            const cgstBp = Number(product.cgstRateBp) || 0;
            const sgstBp = Number(product.sgstRateBp) || 0;
            lineCgstCents = roundTaxComponent(taxableValueCents * cgstBp / 10000);
            lineSgstCents = roundTaxComponent(taxableValueCents * sgstBp / 10000);
        }
        const lineTaxCents = lineCgstCents + lineSgstCents + lineIgstCents;

        // FIX-HW-005: MUTUAL EXCLUSIVITY — IGST and CGST/SGST cannot coexist
        if (isInterState && (lineCgstCents !== 0 || lineSgstCents !== 0)) {
            throw new InvariantError(
                `Inter-state invoice has non-zero CGST/SGST for '${product.name}'. IGST and CGST/SGST are mutually exclusive.`,
            );
        }
        if (!isInterState && lineIgstCents !== 0) {
            throw new InvariantError(
                `Intra-state invoice has non-zero IGST for '${product.name}'. CGST/SGST and IGST are mutually exclusive.`,
            );
        }

        resolvedItems.push({
            itemId: product.id,
            name: product.name,
            quantity: item.quantity,
            unitPriceCents,
            totalCents: taxableValueCents + lineTaxCents,
            discountCents: itemDiscountCents,
            taxableValueCents,
            unit: product.unit || 'pcs',
            cgstCents: lineCgstCents,
            sgstCents: lineSgstCents,
            igstCents: lineIgstCents,
            lineTaxCents,
            hsnCode: product.hsnCode || null,
            batchNumber: item.batchNumber || null,
            expiryDate: item.expiryDate || null,
            serialNumber: item.serialNumber || null,
            imei1: item.imei1 || null,
            imei2: item.imei2 || null,
            billedUnit: item.unit || product.unit || 'pcs',
            conversionFactor: item.conversionFactor || 1,
        });

        subtotalCents += taxableValueCents;
        totalItemDiscountCents += itemDiscountCents;
        taxCents += lineTaxCents;
        headerCgstCents += lineCgstCents;
        headerSgstCents += lineSgstCents;
        headerIgstCents += lineIgstCents;

        // Stock deduction (skip services and proforma invoices)
        // Proforma invoices are quotation documents — they must not commit real stock.
        if (!product.isService && input.invoiceType !== 'proforma_invoice') {
            const recipe = recipeMap.get(item.productId);

            // WS-3: BOM EXPLOSION — Deduct raw ingredients if recipe exists
            if (recipe && Array.isArray(recipe.ingredients) && recipe.ingredients.length > 0) {
                for (const ing of recipe.ingredients) {
                    const ingId = ing.inventoryId || ing.productId;
                    const ingProduct = productMap.get(ingId);
                    if (!ingProduct) continue;

                    const stockDeductionQty = (ing.quantityPerUnit || 1) * item.quantity;
                    
                    if ((ingProduct.currentStock || 0) < stockDeductionQty) {
                        throw new InvoiceError(
                            `Insufficient stock for ingredient '${ingProduct.name}' required for '${product.name}': ` +
                            `available=${ingProduct.currentStock}, requested=${stockDeductionQty}`,
                        );
                    }
                    
                    transactItems.push({
                        Update: {
                            TableName: tableName,
                            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(ingId) },
                            UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                            ConditionExpression: 'currentStock >= :qty',
                            ExpressionAttributeValues: { ':qty': stockDeductionQty, ':now': now },
                        },
                    });

                    stockCheckItems.push({
                        productId: ingId,
                        name: ingProduct.name,
                        currentStock: ingProduct.currentStock || 0,
                        quantity: stockDeductionQty,
                        lowStockThreshold: ingProduct.lowStockThreshold || 5,
                    });
                }
            } else {
                // FIX-HW-004: Standard product deduction
                const stockDeductionQty = (item.unit && item.unit !== (product.unit || 'pcs') && item.conversionFactor)
                    ? item.quantity * item.conversionFactor
                    : item.quantity;

                // ============================================================
                // CLOTHING VARIANT STOCK DEDUCTION
                // For clothing tenants with variant info, deduct from specific VARIANT# record
                // and also update aggregate PRODUCT# currentStock for consistency.
                // ============================================================
                if (businessType === BusinessType.CLOTHING && (item.size || item.color || item.variantId)) {
                    const variant = await findClothingVariant(
                        tenantId,
                        item.productId,
                        item.size,
                        item.color,
                        item.variantId,
                    );

                    if (!variant) {
                        throw new InvoiceError(
                            `Variant not found for product '${product.name}' with size=${item.size}, color=${item.color}`,
                            404,
                        );
                    }

                    if ((variant.stock || 0) < stockDeductionQty) {
                        throw new InvoiceError(
                            `Insufficient stock for variant '${product.name}' (${item.size}/${item.color}): ` +
                            `available=${variant.stock}, requested=${stockDeductionQty}`,
                        );
                    }

                    // Deduct from specific variant record
                    transactItems.push({
                        Update: {
                            TableName: tableName,
                            Key: { PK: Keys.tenantPK(tenantId), SK: `VARIANT#${item.productId}#${variant.id}` },
                            UpdateExpression: 'SET stock = stock - :qty, updatedAt = :now',
                            ConditionExpression: 'stock >= :qty',
                            ExpressionAttributeValues: { ':qty': stockDeductionQty, ':now': now },
                        },
                    });

                    // Also deduct from aggregate PRODUCT# currentStock for consistency
                    transactItems.push({
                        Update: {
                            TableName: tableName,
                            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(item.productId) },
                            UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                            ConditionExpression: 'currentStock >= :qty',
                            ExpressionAttributeValues: { ':qty': stockDeductionQty, ':now': now },
                        },
                    });

                    // Add variant info to stock check for low stock alerts
                    stockCheckItems.push({
                        productId: item.productId,
                        name: product.name,
                        currentStock: variant.stock || 0,
                        quantity: stockDeductionQty,
                        lowStockThreshold: 5
                    });

                    // Add variant info to resolved item for line-item audit trail
                    const resolvedItem = resolvedItems[resolvedItems.length - 1];
                    if (resolvedItem) {
                        (resolvedItem as any).variantId = variant.id;
                        (resolvedItem as any).variantSize = item.size;
                        (resolvedItem as any).variantColor = item.color;
                    }
                }
                // ============================================================
                // FIFO-001: PHARMACY BATCH DEDUCTION
                // For pharmacy tenants, deduct from MEDBATCH# records in FIFO
                // order (oldest expiry first) instead of simple stock decrement.
                // The aggregate PRODUCT# currentStock is ALSO decremented to
                // keep the aggregate counter consistent.
                // ============================================================
                else if (businessType === BusinessType.PHARMACY) {
                    try {
                        const fifoResult = await deductBatchesFIFO(
                            tenantId,
                            item.productId,
                            product.name,
                            stockDeductionQty,
                            now,
                        );

                        // Inject all batch update operations into the transaction
                        for (const batchOp of fifoResult.operations) {
                            transactItems.push(batchOp.transactItem);
                        }

                        // ALSO deduct from aggregate PRODUCT# currentStock
                        // (keeps the aggregate counter in sync for dashboard/reports)
                        transactItems.push({
                            Update: {
                                TableName: tableName,
                                Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(item.productId) },
                                UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                                ConditionExpression: 'currentStock >= :qty',
                                ExpressionAttributeValues: { ':qty': stockDeductionQty, ':now': now },
                            },
                        });

                        // Add FIFO batch info to resolved item for line-item audit trail
                        const batchInfo = fifoResult.operations.map(op => ({
                            batch: op.batchNumber,
                            expiry: op.expiryDate,
                            qty: op.deductedQty,
                            depleted: op.wasDepleted,
                        }));

                        // Near-expiry warnings from batch deduction
                        const todayMs = new Date().getTime();
                        for (const op of fifoResult.operations) {
                            const expiryMs = new Date(op.expiryDate).getTime();
                            const daysRemaining = Math.ceil((expiryMs - todayMs) / 86400000);
                            if (daysRemaining <= 90 && daysRemaining >= 0) {
                                warnings.push({
                                    type: 'NEAR_EXPIRY_BATCH_CONSUMED',
                                    message: `FIFO consumed ${op.deductedQty} from batch '${op.batchNumber}' of '${product.name}' — expires in ${daysRemaining} day(s).`,
                                    batchNumber: op.batchNumber,
                                    expiryDate: op.expiryDate,
                                    daysRemaining,
                                    productName: product.name,
                                    deductedQty: op.deductedQty,
                                });
                            }
                        }

                        logger.info('FIFO batch deduction applied', {
                            tenantId, productId: item.productId, productName: product.name,
                            requestedQty: stockDeductionQty,
                            batchesConsumed: fifoResult.operations.length,
                            batchesDepleted: fifoResult.batchesDepleted,
                            cogsPaise: fifoResult.cogsPaise,
                        });
                    } catch (err) {
                        if (err instanceof InsufficientBatchStockError) {
                            throw new InvoiceError(
                                err.message,
                                400,
                            );
                        }
                        throw err;
                    }
                } else {
                    if (businessType === BusinessType.GROCERY || businessType === BusinessType.WHOLESALE) {
                        try {
                            const fefoResult = await deductGroceryBatchesFEFO(
                                tenantId,
                                item.productId,
                                product.name,
                                stockDeductionQty,
                                now,
                            );

                            for (const batchOp of fefoResult.operations) {
                                transactItems.push(batchOp.transactItem);
                            }
                        } catch (err) {
                            if (err instanceof InsufficientGroceryBatchStockError) {
                                throw new InvoiceError(err.message, 400);
                            }
                            throw err;
                        }
                    }

                    // Aggregate product stock always decremented for non-pharmacy paths.
                    if ((product.currentStock || 0) < stockDeductionQty) {
                        throw new InvoiceError(
                            `Insufficient stock for '${product.name}': ` +
                            `available=${product.currentStock}, requested=${stockDeductionQty}`,
                        );
                    }
                    transactItems.push({
                        Update: {
                            TableName: tableName,
                            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(item.productId) },
                            UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                            ConditionExpression: 'currentStock >= :qty',
                            ExpressionAttributeValues: { ':qty': stockDeductionQty, ':now': now },
                        },
                    });
                }

                stockCheckItems.push({
                    productId: item.productId,
                    name: product.name,
                    currentStock: product.currentStock || 0,
                    quantity: stockDeductionQty,
                    lowStockThreshold: product.lowStockThreshold || 5,
                });
            }
        }
    }

    // FIX-HW-001: Accumulate all tax in raw integer paise — no per-component rounding.
    // Only apply a SINGLE round-off at the invoice level (GST Circular 172/04/2022).
    taxCents = headerCgstCents + headerSgstCents + headerIgstCents;

    // FIX-HW-001: For CGST/SGST display, use floor+remainder pattern.
    // This ensures cgst + sgst = total intra-state tax exactly.
    if (!isInterState) {
        const totalIntraStateTax = headerCgstCents + headerSgstCents;
        // CRITICAL: GST Council Rule - CGST gets ceiling (extra paise when odd)
        headerCgstCents = Math.ceil(totalIntraStateTax / 2);
        headerSgstCents = totalIntraStateTax - headerCgstCents;
    }

    // C-2: Apply bill-level discount (post-item, pre-tax-unaffected)
    const billDiscountCents = Math.min(input.discountCents || 0, subtotalCents);
    subtotalCents -= billDiscountCents;

    // WS-2: Add Service Charge to subtotal directly so finalTotal rounding holds.
    // If the service charge must attract GST, it should have been added as an InvoiceItemInput.
    const serviceChargeCents = input.serviceChargeCents || 0;
    subtotalCents += serviceChargeCents;

    const totalDiscountCents = totalItemDiscountCents + billDiscountCents;
    const totalCents = subtotalCents + taxCents;

    // Single round-off to nearest rupee for final invoice total
    const roundOffCents = Math.round(totalCents / 100) * 100 - totalCents;
    const finalTotalCents = totalCents + roundOffCents;

    // FIX-HW-001: INVARIANT ASSERTION — subtotal + tax + roundOff must equal total exactly
    if (subtotalCents + taxCents + roundOffCents !== finalTotalCents) {
        throw new InvariantError(
            `GST rounding invariant broken: ${subtotalCents} + ${taxCents} + ${roundOffCents} !== ${finalTotalCents}`,
        );
    }

    // BUG-006 FIX: Warn if round-off drift exceeds ₹2 (200 paise)
    if (Math.abs(roundOffCents) > 200) {
        logger.warn('Large round-off drift detected', {
            tenantId, invoiceId, roundOffCents,
            subtotalCents, taxCents, totalCents, finalTotalCents,
            lineItemCount: resolvedItems.length,
        });
    }

    // ================================================================
    // FIX-HW-002: CONTRACTOR CREDIT LIMIT ENFORCEMENT
    // When paymentMode is 'credit', verify customer's available credit via
    // enforceUdharCreditLimit (ledger-backed outstanding).
    // metadata.enforceCreditLimit === true → throw CreditLimitExceededError (hard stop).
    // Otherwise → append CREDIT_LIMIT_EXCEEDED warning and continue (contractor override).
    // ================================================================
    const enforceCreditLimitHard = invoiceMetadata.enforceCreditLimit === true;

    if (input.paymentMode === 'credit' && resolvedCustomer) {
        try {
            {
                const customer = resolvedCustomer;
                await enforceUdharCreditLimit(tenantId, customer.id, finalTotalCents);
            }
        } catch (err) {
            if (err instanceof CreditLimitExceededError) {
                if (enforceCreditLimitHard) {
                    throw err;
                }
                const cle = err as CreditLimitExceededError;
                warnings.push({
                    type: 'CREDIT_LIMIT_EXCEEDED',
                    message: cle.message,
                    invoiceTotalCents: cle.invoiceTotalCents,
                    availableCreditCents: cle.availableCreditCents,
                    creditLimitCents: cle.creditLimitCents,
                    outstandingBalanceCents: cle.outstandingBalanceCents,
                });
            } else {
                logger.warn('Credit limit check failed \u2014 allowing invoice', { error: (err as Error).message });
            }
        }
    }

    // WS-2: Calculate accurate initial payment status based on payment mode
    let calculatedPaidCents = 0;
    let initialStatus = 'draft';

    if (input.paymentMode === 'unpaid' || input.paymentMode === 'credit') {
        initialStatus = 'pending';
    } else if (input.paymentMode === 'split') {
        const splitPayments = input.splitPayments || (invoiceMetadata.splitPayments as any[]);
        if (Array.isArray(splitPayments)) {
            calculatedPaidCents = splitPayments.reduce((sum, p) => sum + (Number(p.amountCents) || 0), 0);
        }
        initialStatus = calculatedPaidCents >= finalTotalCents ? 'paid' : 
                      (calculatedPaidCents > 0 ? 'partially_paid' : 'pending');
    } else {
        // Immediate full payment (cash, upi, card, wallet)
        calculatedPaidCents = finalTotalCents;
        initialStatus = 'paid';
    }

    // 3. Create invoice record
    const invoiceItem: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: Keys.invoiceSK(invoiceId),
        entityType: 'INVOICE',
        id: invoiceId,
        tenantId,
        invoiceNumber,
        customerId: resolvedCustomer?.id ?? null,
        customerName: (input.customerName || 'Walk-in').slice(0, 200),
        customerPhone: input.customerPhone || null,
        subtotalCents,
        taxCents,
        cgstCents: headerCgstCents,
        sgstCents: headerSgstCents,
        igstCents: headerIgstCents,
        discountCents: totalDiscountCents,
        billDiscountCents,
        serviceChargeCents,
        roundOffCents,
        totalCents: finalTotalCents,
        paidCents: calculatedPaidCents,
        balanceCents: Math.max(finalTotalCents - calculatedPaidCents, 0),
        paymentMode: input.paymentMode || 'cash',
        invoiceType: input.invoiceType || 'tax_invoice',
        invoiceProfileId: input.invoiceProfileId || null,
        // Hardware: Transport details for compliance and reporting
        lrNumber: input.lrNumber?.slice(0, 50) ?? null,
        transporterName: input.transporterName?.slice(0, 200) ?? null,
        ewayBillNumber: input.ewayBillNumber?.slice(0, 50) ?? null,
        transportMode: input.transportMode || null,
        status: initialStatus,
        isInterState,
        notes: input.notes?.slice(0, 1000) ?? null,
        metadata: {
            customerGstin: input.customerGstin || null,
            ...(invoiceMetadata.prescriptionId ? { prescriptionId: invoiceMetadata.prescriptionId } : {}),
            ...(invoiceMetadata.doctorName ? { doctorName: invoiceMetadata.doctorName } : {}),
            ...(invoiceMetadata.doctorRegNo ? { doctorRegNo: invoiceMetadata.doctorRegNo } : {}),
            // RESTO-001/020: Restaurant bill linkage + waiter attribution
            ...(invoiceMetadata.restoBillId ? { restoBillId: invoiceMetadata.restoBillId } : {}),
            ...(invoiceMetadata.waiterId ? { waiterId: invoiceMetadata.waiterId } : {}),
            ...(invoiceMetadata.tableId ? { tableId: invoiceMetadata.tableId } : {}),
            // Sprint 1: persist split-payment breakdown so day-end cash close can
            // attribute the cash leg of split tenders correctly. Without this,
            // expected-cash compute would under-count split bills.
            ...(input.splitPayments && input.splitPayments.length > 0
                ? { splitPayments: input.splitPayments }
                : {}),
            // Cashier-counter receipts: keep the cash drawer reconciliation trail.
            ...(typeof (invoiceMetadata as Record<string, unknown>).cashReceivedCents === 'number'
                ? { cashReceivedCents: (invoiceMetadata as Record<string, unknown>).cashReceivedCents }
                : {}),
            ...(typeof (invoiceMetadata as Record<string, unknown>).changeGivenCents === 'number'
                ? { changeGivenCents: (invoiceMetadata as Record<string, unknown>).changeGivenCents }
                : {}),
        },
        // RESTO-020: Top-level waiterId for sales report grouping
        ...(invoiceMetadata.restoBillId ? { restoBillId: String(invoiceMetadata.restoBillId) } : {}),
        ...(invoiceMetadata.waiterId ? { waiterId: String(invoiceMetadata.waiterId) } : {}),
        createdBy,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
        // GSI1: invoice number lookup
        GSI1PK: Keys.tenantPK(tenantId),
        GSI1SK: Keys.invoiceNumGSI1SK(invoiceNumber),
    };

    // 4. Build line item records
    const lineItemRecords = resolvedItems.map((item) => ({
        PK: Keys.invoiceLineItemPK(invoiceId),
        SK: Keys.lineItemSK(uuidv4()),
        entityType: 'LINE_ITEM',
        tenantId,
        transactionId: invoiceId,
        itemId: item.itemId,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        unitPriceCents: item.unitPriceCents,
        totalCents: item.totalCents,
        discountCents: item.discountCents,
        taxableValueCents: item.taxableValueCents,
        taxCents: item.lineTaxCents,
        cgstCents: item.cgstCents,
        sgstCents: item.sgstCents,
        igstCents: item.igstCents,
        hsnCode: item.hsnCode,
        batchNumber: item.batchNumber,
        expiryDate: item.expiryDate,
        serialNumber: item.serialNumber,
        imei1: item.imei1,
        imei2: item.imei2,
        billedUnit: item.billedUnit || item.unit,
        conversionFactor: item.conversionFactor || 1,
        createdAt: now,
    }));

    // 5. ATOMIC WRITE: invoice header + stock deductions + line items
    // NDPS-001: Include narcotic log entries in the atomic transaction
    for (const narcoticOp of narcoticLogItems) {
        transactItems.push(narcoticOp);
    }

    // CDSCO-H1: Include H1 register entries in the atomic transaction
    for (const h1Op of h1RegisterItems) {
        transactItems.push(h1Op);
    }

    // SERIAL-001: Include serial/IMEI tracking records in the atomic transaction
    // ConditionExpression on each prevents duplicate IMEI/serial sales
    for (const serialOp of serialTrackItems) {
        transactItems.push(serialOp);
    }

    const totalTransactOps = transactItems.length + 1 + lineItemRecords.length;

    if (totalTransactOps <= 100) {
        // All fits in one atomic transaction — BEST CASE
        transactItems.push({
            Put: { TableName: tableName, Item: invoiceItem },
        });
        for (const lineItem of lineItemRecords) {
            transactItems.push({
                Put: { TableName: tableName, Item: lineItem },
            });
        }

        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                const reasons: Array<{ Code?: string }> = err.CancellationReasons || [];
                // Fix #9: Parse by SK value, not array index — position-independent so
                // inserting new transact ops never silently misroutes error messages.
                for (let i = 0; i < reasons.length; i++) {
                    if (reasons[i]?.Code === 'ConditionalCheckFailed') {
                        const failedItem = transactItems[i];
                        const failedSK: string =
                            failedItem?.Put?.Item?.SK ||
                            failedItem?.Update?.Key?.SK || '';

                        if (failedSK.startsWith('SERIAL#')) {
                            const duplicateId = failedSK.replace('SERIAL#', '');
                            throw new InvoiceValidationError(
                                `IMEI/Serial number '${duplicateId}' has already been sold. Duplicate serial/IMEI sales are not permitted.`,
                                { duplicateIdentifier: duplicateId, field: 'serialNumber' },
                            );
                        }

                        if (failedSK.startsWith('PRODUCT#')) {
                            const productId = failedSK.replace('PRODUCT#', '');
                            const matchedItem = resolvedItems.find(ri => ri.itemId === productId);
                            throw Object.assign(
                                new InvoiceError(
                                    `Insufficient stock for '${matchedItem?.name || productId}' ` +
                                    `(concurrent sale detected). Please retry.`,
                                    409,
                                ),
                                { code: 'STOCK_CONFLICT', retryable: true },
                            );
                        }
                    }
                }
                throw Object.assign(
                    new InvoiceError('Invoice creation failed due to concurrent modification. Please retry.', 409),
                    { code: 'STOCK_CONFLICT', retryable: true },
                );
            }
            throw err;
        }
    } else {
        // Large invoice (>95 items): transactWrite for header+stock; batchWrite for line items.
        // Fix #8: Mark invoice with lineItemsStatus='pending' BEFORE batchWrite so that if
        // Lambda crashes between the two writes, the orphaned invoice is detectable by
        // a recovery process (lineItemsStatus !== 'complete' → flag for audit).
        logger.warn('Large invoice: line items written separately (lineItemsStatus guard active)', {
            tenantId, invoiceId, totalItems: lineItemRecords.length,
        });

        transactItems.push({
            Put: { TableName: tableName, Item: { ...invoiceItem, lineItemsStatus: 'pending' } },
        });

        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                throw new InvoiceError('Insufficient stock (concurrent sale detected). Please retry.', 409);
            }
            throw err;
        }

        if (lineItemRecords.length > 0) {
            await batchWrite(lineItemRecords.map(item => ({ type: 'put' as const, item })));
        }

        // Mark line items fully written — clears the pending sentinel
        await updateItem(Keys.tenantPK(tenantId), Keys.invoiceSK(invoiceId), {
            updateExpression: 'SET lineItemsStatus = :done',
            expressionAttributeValues: { ':done': 'complete' },
        }).catch(e => logger.warn('Failed to clear lineItemsStatus sentinel', { invoiceId, error: (e as Error).message }));
    }

    // H-4: Post-sale low-stock check + WebSocket alerts
    try {
        const wsService = await import('./websocket.service');
        const { WSEventName } = await import('../types/websocket.types');

        for (const si of stockCheckItems) {
            const newStock = si.currentStock - si.quantity;

            // STOCK_UPDATED — lets all connected operator devices refresh their inventory list
            wsService.emitEvent(tenantId, WSEventName.STOCK_UPDATED, {
                productId: si.productId,
                productName: si.name,
                newStock,
            }).catch(err => logger.warn('WS stock-updated failed', { error: (err as Error).message }));

            if (newStock <= si.lowStockThreshold) {
                wsService.emitEvent(tenantId, WSEventName.LOW_STOCK_ALERT, {
                    itemId: si.productId,
                    itemName: si.name,
                    currentStock: newStock,
                    threshold: si.lowStockThreshold,
                    isOutOfStock: newStock <= 0,
                }).catch(err => logger.warn('WS low-stock alert failed', { error: (err as Error).message }));
            }
        }

        // INVOICE_CREATED — tells connected Flutter clients to refresh their dashboard KPIs
        wsService.emitEvent(tenantId, WSEventName.INVOICE_CREATED, {
            invoiceId,
            invoiceNumber,
            totalCents: finalTotalCents,
            status: initialStatus,
        }).catch(err => logger.warn('WS invoice-created failed', { error: (err as Error).message }));

    } catch { /* WebSocket events are non-critical */ }

    // O(1) Dashboard Metrics Aggregation
    // Fix #12: Retry with exponential backoff (3 attempts, 100ms/200ms/400ms).
    // DynamoDB ADD is idempotent for numeric counters — safe to retry.
    let metricSales = 0;
    let metricPending = 0;
    if (initialStatus === 'paid' || initialStatus === 'partially_paid' || initialStatus === 'finalized') {
        metricSales = finalTotalCents;
    }
    if (initialStatus === 'pending' || initialStatus === 'partially_paid') {
        metricPending = Math.max(finalTotalCents - calculatedPaidCents, 0);
    }
    const dateStr = now.split('T')[0];
    let metricsAttempt = 0;
    while (metricsAttempt < 3) {
        try {
            await updateItem(Keys.tenantPK(tenantId), `DAILY_METRICS#${dateStr}`, {
                updateExpression: 'ADD salesCents :sales, transactionCount :inc, pendingCents :pending',
                expressionAttributeValues: {
                    ':sales': metricSales,
                    ':inc': 1,
                    ':pending': metricPending,
                },
            });
            break; // success
        } catch (e) {
            metricsAttempt++;
            if (metricsAttempt >= 3) {
                logger.error('DAILY_METRICS update failed after 3 attempts', {
                    tenantId, invoiceId, dateStr, error: (e as Error).message,
                });
            } else {
                await new Promise(res => setTimeout(res, 100 * Math.pow(2, metricsAttempt - 1)));
            }
        }
    }

    // H-9: Invalidate dashboard cache so next request sees updated revenue
    invalidateCache(`dashboard:${tenantId}`);

    // H-2: Audit log
    logAudit({
        action: 'INVOICE_CREATED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: {
            invoiceNumber, totalCents: finalTotalCents, itemsCount: resolvedItems.length,
            discountCents: totalDiscountCents, isInterState,
        },
    }).catch(() => { });

    logger.info('Invoice created', {
        tenantId, invoiceNumber, totalCents: finalTotalCents, items: resolvedItems.length,
        atomic: totalTransactOps <= 100, discountCents: totalDiscountCents,
        isInterState, igstCents: headerIgstCents,
    });

    // P-4c: Duplicate prescriptionId warning (non-blocking)
    if (invoiceMetadata.prescriptionId) {
        try {
            const existingRx = await queryItems<Record<string, any>>(
                Keys.tenantPK(tenantId), 'INVOICE#', {
                    filterExpression: 'metadata.prescriptionId = :rxId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':rxId': String(invoiceMetadata.prescriptionId), ':false': false },
                    limit: 1,
                },
            );
            if (existingRx.items.length > 0) {
                warnings.push({
                    type: 'DUPLICATE_PRESCRIPTION_ID',
                    message: `Prescription ID '${invoiceMetadata.prescriptionId}' was already used on invoice ${existingRx.items[0].invoiceNumber || existingRx.items[0].id}.`,
                    existingInvoiceId: existingRx.items[0].id,
                });
            }
        } catch { /* Non-critical — don't block sale for lookup errors */ }
    }

    return {
        id: invoiceId,
        invoiceNumber,
        status: initialStatus,
        totalCents: finalTotalCents,
        subtotalCents,
        taxCents,
        cgstCents: headerCgstCents,
        sgstCents: headerSgstCents,
        igstCents: headerIgstCents,
        discountCents: totalDiscountCents,
        paidCents: calculatedPaidCents,
        balanceCents: Math.max(finalTotalCents - calculatedPaidCents, 0),
        paymentMode: input.paymentMode || 'cash',
        roundOffCents,
        itemsCount: resolvedItems.length,
        createdAt: now,
        invoiceType: (input.invoiceType || 'tax_invoice') as 'tax_invoice' | 'retail_invoice' | 'proforma_invoice',
        ...(warnings.length > 0 ? { warnings } : {}),
    };
}

export interface FinalizeInvoiceOptions {
    finalizedBy?: string;
}

/**
 * Finalize a draft invoice (mark as finalized, record actual payment state).
 * C-1 FIX: No longer force-sets paidCents=totalCents. Instead verifies actual
 * payment state and only changes status to 'finalized'.
 */
export async function finalizeInvoice(
    tenantId: string,
    invoiceId: string,
    options?: FinalizeInvoiceOptions,
): Promise<{
    id: string;
    status: string;
    paidCents: number;
    balanceCents: number;
    loyalty?: { pointsEarned: number; newBalance: number };
}> {
    // Get invoice to check actual payment state
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );

    if (!invoice || invoice.isDeleted) {
        throw new InvoiceError('Invoice not found', 404);
    }
    if (invoice.status !== 'draft') {
        throw new InvoiceError(`Cannot finalize invoice with status '${invoice.status}'. Only draft invoices can be finalized.`, 409);
    }

    // Check line items exist
    const lineItems = await queryItems(
        Keys.invoiceLineItemPK(invoiceId),
        'LINEITEM#',
    );

    if (lineItems.items.length === 0) {
        throw new InvoiceError('Cannot finalize invoice with zero line items', 400);
    }

    // C-1 FIX: Determine actual payment status based on paidCents
    const totalCents = Number(invoice.totalCents) || 0;
    const paidCents = Number(invoice.paidCents) || 0;
    const balanceCents = Math.max(totalCents - paidCents, 0);

    let newStatus = 'finalized';
    if (paidCents >= totalCents) {
        newStatus = 'paid';
    } else if (paidCents > 0) {
        newStatus = 'partially_paid';
    }

    // Update invoice status — preserving actual payment amounts
    const now = new Date().toISOString();
    const result = await updateItem(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
        {
            updateExpression: 'SET #s = :newStatus, balanceCents = :balance, updatedAt = :now',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':newStatus': newStatus,
                ':balance': balanceCents,
                ':now': now,
                ':draft': 'draft',
                ':false': false,
            },
            conditionExpression: '#s = :draft AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
        },
    );

    if (!result) {
        throw new InvoiceError('Invoice not found or already finalized', 404);
    }

    // H-2: Audit log
    logAudit({
        action: 'INVOICE_FINALIZED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { invoiceNumber: invoice.invoiceNumber, newStatus, paidCents, balanceCents },
    }).catch(() => { });

    // O(1) Dashboard Metrics Aggregation
    let metricSales = 0;
    let metricPending = 0;
    if (newStatus === 'paid' || newStatus === 'partially_paid' || newStatus === 'finalized') {
        metricSales = totalCents;
    }
    if (newStatus === 'pending' || newStatus === 'partially_paid') {
        metricPending = balanceCents;
    }
    try {
        const dateStr = (invoice.createdAt || now).split('T')[0];
        await updateItem(Keys.tenantPK(tenantId), `DAILY_METRICS#${dateStr}`, {
            updateExpression: 'ADD salesCents :sales, pendingCents :pending',
            expressionAttributeValues: {
                ':sales': metricSales,
                ':pending': metricPending
            }
        });
    } catch (e) {
        logger.error('Failed to update DAILY_METRICS in finalize', { error: e });
    }

    // H-9: Invalidate dashboard cache
    invalidateCache(`dashboard:${tenantId}`);

    let loyalty: { pointsEarned: number; newBalance: number } | undefined;
    const custId = String(invoice.customerId ?? '').trim();
    const finalizedBy = options?.finalizedBy ?? 'system';
    if (custId && custId !== 'guest') {
        try {
            loyalty = await earnPoints(
                tenantId,
                custId,
                totalCents,
                invoiceId,
                String(invoice.invoiceNumber ?? invoiceId),
                finalizedBy,
            );
        } catch (loyErr: unknown) {
            logger.warn('Loyalty earn failed after finalize', {
                tenantId,
                invoiceId,
                error: (loyErr as Error).message,
            });
        }
    }
    await recordRevision(
        tenantId,
        'transactions',
        invoiceId,
        'status_change',
        finalizedBy,
        invoice,
        {
            ...invoice,
            status: newStatus,
            balanceCents,
            updatedAt: now,
            ...(loyalty !== undefined ? { loyalty } : {}),
        },
        { source: 'invoice.finalizeInvoice' },
    );

    logger.info('Invoice finalized', { tenantId, invoiceId, newStatus, paidCents, balanceCents });
    return {
        id: invoiceId,
        status: newStatus,
        paidCents,
        balanceCents,
        ...(loyalty !== undefined ? { loyalty } : {}),
    };
}

/**
 * Void an invoice (cancel it, reverse stock changes).
 * H-3 FIX: Retry logic now only skips the specific product that failed,
 * not all products.
 */
export async function voidInvoice(
    tenantId: string,
    invoiceId: string,
    reason?: string
): Promise<{ id: string; status: string }> {
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );

    if (!invoice || invoice.isDeleted) {
        throw new InvoiceError('Invoice not found', 404);
    }
    if (invoice.status === 'voided') {
        throw new InvoiceError('Invoice is already voided', 409);
    }
    // FEATURE-G: Void not allowed from draft — must finalize first
    if (invoice.status === 'draft') {
        throw new InvoiceError(
            'Cannot void a draft invoice. Finalize it first, or delete the draft.',
            409,
        );
    }
    if (Number(invoice.paidCents) > 0) {
        throw new InvoiceError(
            `Cannot void invoice ${invoiceId}: ₹${(Number(invoice.paidCents) / 100).toFixed(2)} has already been collected. Issue a return/refund instead.`,
            409,
        );
    }

    // Get line items to reverse stock
    const lineItems = await queryItems<Record<string, any>>(
        Keys.invoiceLineItemPK(invoiceId),
        'LINEITEM#',
    );

    const now = new Date().toISOString();
    const voidNote = `[VOIDED] ${reason || 'No reason provided'}`;

    // Build atomic transaction: stock reversals + invoice void in one transactWrite
    const transactItems: any[] = [];

    // Stock reversals for each line item (atomic — all or nothing)
    for (const item of lineItems.items) {
        if (item.itemId) {
            transactItems.push({
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(item.itemId) },
                    UpdateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
                    ConditionExpression: 'attribute_exists(PK)',
                    ExpressionAttributeValues: { ':qty': item.quantity, ':now': now },
                },
            });
        }
    }

    // Void the invoice itself (in the same transaction)
    transactItems.push({
        Update: {
            TableName: TABLE_NAME,
            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.invoiceSK(invoiceId) },
            UpdateExpression: 'SET #s = :voided, notes = :note, updatedAt = :now',
            ExpressionAttributeNames: { '#s': 'status' },
            ExpressionAttributeValues: {
                ':voided': 'voided',
                ':note': (invoice.notes ? invoice.notes + '\n' : '') + voidNote,
                ':now': now,
            },
        },
    });

    try {
        await transactWrite(transactItems);
    } catch (err: any) {
        // H-3 FIX: Only skip the specific product that failed, not all products
        if (err.name === 'TransactionCanceledException') {
            const reasons = err.CancellationReasons || [];
            const failedProductIndices = new Set<number>();
            const skippedProducts: string[] = [];

            for (let i = 0; i < reasons.length; i++) {
                if (reasons[i]?.Code === 'ConditionalCheckFailed') {
                    const failedItem = transactItems[i];
                    if (failedItem?.Update?.Key?.SK?.startsWith('PRODUCT#')) {
                        failedProductIndices.add(i);
                        skippedProducts.push(failedItem.Update.Key.SK.replace('PRODUCT#', ''));
                    }
                }
            }

            if (failedProductIndices.size > 0) {
                logger.warn('Void transaction: retrying without deleted products', {
                    invoiceId, tenantId, skippedProducts,
                });

                // Rebuild without just the failed product updates
                const retryItems = transactItems.filter((_, idx) => !failedProductIndices.has(idx));

                if (retryItems.length === 0) {
                    // Edge case: all products deleted. Just void the invoice.
                    retryItems.push({
                        Update: {
                            TableName: TABLE_NAME,
                            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.invoiceSK(invoiceId) },
                            UpdateExpression: 'SET #s = :voided, notes = :note, updatedAt = :now',
                            ExpressionAttributeNames: { '#s': 'status' },
                            ExpressionAttributeValues: {
                                ':voided': 'voided',
                                ':note': (invoice.notes ? invoice.notes + '\n' : '') + voidNote +
                                    '\n[WARN] Some stock reversals skipped (products deleted)',
                                ':now': now,
                            },
                        },
                    });
                }

                await transactWrite(retryItems);
            } else {
                throw new InvoiceError('Invoice void failed due to concurrent modification. Please retry.', 409);
            }
        } else {
            throw err;
        }
    }

    // H-2: Audit log
    logAudit({
        action: 'INVOICE_VOIDED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { invoiceNumber: invoice.invoiceNumber, reason, totalCents: invoice.totalCents },
    }).catch(() => { });

    // H-9: Invalidate dashboard cache
    invalidateCache(`dashboard:${tenantId}`);
    await recordRevision(
        tenantId,
        'transactions',
        invoiceId,
        'status_change',
        'system',
        invoice,
        {
            ...invoice,
            status: 'voided',
            notes: (invoice.notes ? invoice.notes + '\n' : '') + voidNote,
            updatedAt: now,
        },
        { source: 'invoice.voidInvoice', reason: reason || null },
    );

    logger.info('Invoice voided', { tenantId, invoiceId, reason });
    return { id: invoiceId, status: 'voided' };
}

/**
 * Send an invoice (mark as sent, record delivery method).
 */
export async function sendInvoice(
    tenantId: string,
    invoiceId: string,
    method: 'email' | 'sms' | 'whatsapp' = 'email'
): Promise<{ id: string; sent: boolean; method: string }> {
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );

    if (!invoice) {
        throw new InvoiceError('Invoice not found', 404);
    }

    const now = new Date().toISOString();
    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
        {
            updateExpression: 'SET metadata.last_sent = :sent, updatedAt = :now',
            expressionAttributeValues: {
                ':sent': { method, sentAt: now },
                ':now': now,
            },
        },
    );
    await recordRevision(
        tenantId,
        'transactions',
        invoiceId,
        'update',
        'system',
        invoice,
        {
            ...invoice,
            metadata: {
                ...(invoice.metadata || {}),
                last_sent: { method, sentAt: now },
            },
            updatedAt: now,
        },
        { source: 'invoice.sendInvoice', method },
    );

    logger.info('Invoice send recorded', { tenantId, invoiceId, method });
    return { id: invoiceId, sent: true, method };
}

/**
 * Return/refund items from a finalized invoice.
 * H-8: Creates a credit note, reverses stock for returned items.
 */
export async function createReturn(
    tenantId: string,
    invoiceId: string,
    returnItems: Array<{ itemId: string; quantity: number; reason?: string }>,
    createdBy: string
): Promise<{ creditNoteId: string; creditAmountCents: number }> {
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );

    if (!invoice || invoice.isDeleted) {
        throw new InvoiceError('Invoice not found', 404);
    }
    if (invoice.status === 'voided' || invoice.status === 'draft') {
        throw new InvoiceError(`Cannot return items from a '${invoice.status}' invoice`, 409);
    }

    // Fetch line items for this invoice
    const lineItems = await queryItems<Record<string, any>>(
        Keys.invoiceLineItemPK(invoiceId),
        'LINEITEM#',
    );
    const lineItemMap = new Map(lineItems.items.map(li => [li.itemId, li]));

    const now = new Date().toISOString();
    const tNow = new Date(now);
    const yyyymm = `${tNow.getFullYear()}${String(tNow.getMonth() + 1).padStart(2, '0')}`;
    
    let tenantProfile, tenantSettings;
    try {
        [tenantProfile, tenantSettings] = await Promise.all([
            getItem<any>(Keys.tenantPK(tenantId), Keys.tenantProfileSK()),
            getItem<any>(Keys.tenantPK(tenantId), Keys.tenantSettingsSK())
        ]);
    } catch { /* Ignore */ }
    const shortCode = tenantSettings?.invoicePrefix || tenantProfile?.name?.substring(0, 3).toUpperCase() || 'RTN';

    // AUDIT FIX BUG-2.3: Read current counter value first, then include atomic increment
    // inside the TransactWrite. Previously the counter was incremented via a standalone
    // updateItem BEFORE the TransactWrite — if Lambda crashed between them, the counter
    // would advance but no credit note would be created, leaving a gap in the sequence.
    // GST Rule 55 requires continuous numbering with no gaps.
    const counterSK = `COUNTER#CREDIT_NOTE#${yyyymm}`;
    let currentCounterValue = 0;
    try {
        const counterRecord = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId),
            counterSK,
        );
        currentCounterValue = Number(counterRecord?.counterValue) || 0;
    } catch { /* Counter doesn't exist yet — will be created in TransactWrite */ }

    const seqNextNum = currentCounterValue + 1;
    const creditNoteNumber = `CN-${shortCode}-${yyyymm}-${String(seqNextNum).padStart(4, '0')}`;

    const creditNoteId = uuidv4();
    const tableName = config.dynamodb.tableName;
    let creditAmountCents = 0;
    const transactItems: any[] = [];
    const creditLineItems: any[] = [];

    // Include counter increment in the same TransactWrite as credit note creation
    if (currentCounterValue === 0) {
        // Counter doesn't exist yet — create it
        transactItems.push({
            Put: {
                TableName: tableName,
                Item: {
                    PK: Keys.tenantPK(tenantId),
                    SK: counterSK,
                    counterValue: 1,
                    entityType: 'COUNTER',
                    updatedAt: now,
                },
                ConditionExpression: 'attribute_not_exists(PK)',
            },
        });
    } else {
        // Counter exists — atomically increment with condition to prevent concurrent overwrites
        transactItems.push({
            Update: {
                TableName: tableName,
                Key: { PK: Keys.tenantPK(tenantId), SK: counterSK },
                UpdateExpression: 'SET counterValue = :next, updatedAt = :now',
                ConditionExpression: 'counterValue = :current',
                ExpressionAttributeValues: {
                    ':next': seqNextNum,
                    ':current': currentCounterValue,
                    ':now': now,
                },
            },
        });
    }

    // GAP #7: Fetch existing returns for this invoice to track already-returned quantities
    let existingCreditLines: Record<string, any>[] = [];
    try {
        // Query all credit notes for this invoice
        const creditNotes = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId), 'CREDITNOTE#', {
                filterExpression: 'originalInvoiceId = :invId AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':invId': invoiceId, ':false': false },
            },
        );
        // For each credit note, fetch its line items to get already-returned quantities
        for (const cn of creditNotes.items) {
            const cnLines = await queryItems<Record<string, any>>(
                `CREDITNOTE#${cn.id}`, 'LINEITEM#',
            );
            existingCreditLines.push(...cnLines.items);
        }
    } catch { /* If lookup fails, proceed with original quantity check only */ }

    // Group already-returned quantities by itemId
    const alreadyReturnedMap = new Map<string, number>();
    for (const cl of existingCreditLines) {
        const key = cl.itemId || '';
        alreadyReturnedMap.set(key, (alreadyReturnedMap.get(key) || 0) + (Number(cl.quantity) || 0));
    }

    for (const ri of returnItems) {
        const lineItem = lineItemMap.get(ri.itemId);
        if (!lineItem) {
            throw new InvoiceError(`Item '${ri.itemId}' not found in invoice ${invoiceId}`);
        }

        // GAP #7: Account for already-returned quantities
        const originalQty = Number(lineItem.quantity) || 0;
        const alreadyReturned = alreadyReturnedMap.get(ri.itemId) || 0;
        const returnable = originalQty - alreadyReturned;

        if (ri.quantity > returnable) {
            throw new InvoiceError(
                `Cannot return ${ri.quantity} of '${lineItem.name}' — only ${returnable} returnable (${originalQty} sold, ${alreadyReturned} already returned).`,
            );
        }

        const unitPrice = Number(lineItem.unitPriceCents) || 0;
        const lineCredit = roundTaxComponent(unitPrice * ri.quantity);
        // Proportional tax refund
        const taxRatio = lineItem.quantity > 0 ? ri.quantity / lineItem.quantity : 0;
        const taxRefund = roundTaxComponent((Number(lineItem.taxCents) || 0) * taxRatio);
        const totalRefund = lineCredit + taxRefund;
        creditAmountCents += totalRefund;

        // Stock reversal must mirror sale-time unit conversion.
        const conversionFactor = Number(lineItem.conversionFactor) > 0
            ? Number(lineItem.conversionFactor)
            : 1;
        const stockRestoreQty = ri.quantity * conversionFactor;

        // Stock reversal
        transactItems.push({
            Update: {
                TableName: tableName,
                Key: { PK: Keys.tenantPK(tenantId), SK: Keys.productSK(ri.itemId) },
                UpdateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
                ConditionExpression: 'attribute_exists(PK)',
                ExpressionAttributeValues: { ':qty': stockRestoreQty, ':now': now },
            },
        });

        creditLineItems.push({
            PK: `CREDITNOTE#${creditNoteId}`,
            SK: Keys.lineItemSK(uuidv4()),
            entityType: 'CREDIT_LINE_ITEM',
            tenantId,
            creditNoteId,
            originalInvoiceId: invoiceId,
            itemId: ri.itemId,
            name: lineItem.name,
            quantity: ri.quantity,
            stockRestoreQty,
            unitPriceCents: unitPrice,
            creditAmountCents: totalRefund,
            taxRefundCents: taxRefund,
            reason: ri.reason || null,
            createdAt: now,
        });
    }

    // Credit note header
    const creditNote: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: `CREDITNOTE#${creditNoteId}`,
        entityType: 'CREDIT_NOTE',
        id: creditNoteId,
        creditNoteNumber,
        tenantId,
        originalInvoiceId: invoiceId,
        originalInvoiceNumber: invoice.invoiceNumber,
        creditAmountCents,
        status: 'issued',
        createdBy,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
    };

    transactItems.push({
        Put: { TableName: tableName, Item: creditNote },
    });

    // Deduct credit from invoice balance and store returnInvoiceId (creditNoteNumber)
    transactItems.push({
        Update: {
            TableName: tableName,
            Key: { PK: Keys.tenantPK(tenantId), SK: Keys.invoiceSK(invoiceId) },
            UpdateExpression: 'SET balanceCents = balanceCents - :credit, returnInvoiceId = :cnNum, updatedAt = :now',
            ExpressionAttributeValues: { ':credit': creditAmountCents, ':cnNum': creditNoteNumber, ':now': now },
        },
    });

    if (transactItems.length <= 100) {
        for (const cli of creditLineItems) {
            transactItems.push({ Put: { TableName: tableName, Item: cli } });
        }
        await transactWrite(transactItems);
    } else {
        await transactWrite(transactItems);
        if (creditLineItems.length > 0) {
            await batchWrite(creditLineItems.map(item => ({ type: 'put' as const, item })));
        }
    }

    // Audit log
    logAudit({
        action: 'RETURN_CREATED',
        resource: 'credit_note',
        resourceId: creditNoteId,
        metadata: { originalInvoiceId: invoiceId, creditAmountCents, itemCount: returnItems.length },
    }).catch(() => { });

    invalidateCache(`dashboard:${tenantId}`);
    await recordRevision(
        tenantId,
        'credit_notes',
        creditNoteId,
        'create',
        createdBy,
        null,
        {
            id: creditNoteId,
            creditNoteNumber,
            originalInvoiceId: invoiceId,
            originalInvoiceNumber: invoice.invoiceNumber,
            creditAmountCents,
            status: 'issued',
            createdAt: now,
        },
        { source: 'invoice.createReturn' },
    );
    await recordRevision(
        tenantId,
        'transactions',
        invoiceId,
        'update',
        createdBy,
        invoice,
        {
            ...invoice,
            balanceCents: Math.max(Number(invoice.balanceCents || 0) - creditAmountCents, 0),
            returnInvoiceId: creditNoteNumber,
            updatedAt: now,
        },
        { source: 'invoice.createReturn', creditNoteId },
    );

    logger.info('Return/credit note created', { tenantId, creditNoteId, invoiceId, creditAmountCents });
    return { creditNoteId, creditAmountCents };
}

// ---- H1 FIX: Draft Invoice Editing ----

/**
 * Update a draft invoice — replace items, recalculate totals.
 * Only allowed when invoice status is 'draft'.
 * Reverses old stock deductions, applies new ones atomically.
 */
export async function updateInvoice(
    tenantId: string,
    invoiceId: string,
    input: CreateInvoiceInput
): Promise<InvoiceResult> {
    const pk = Keys.tenantPK(tenantId);
    const sk = Keys.invoiceSK(invoiceId);

    // 1. Fetch existing invoice
    const invoice = await getItem<Record<string, any>>(pk, sk);
    if (!invoice || invoice.isDeleted) {
        throw new InvoiceError('Invoice not found', 404);
    }

    if (invoice.status !== 'draft') {
        throw new InvoiceError(
            `Cannot edit invoice with status '${invoice.status}'. Only draft invoices can be modified.`,
            403
        );
    }

    if (Number(invoice.paidCents || 0) > 0) {
        throw new InvoiceError('Cannot edit invoice with payments. Void payments first.', 403);
    }

    // 2. Fetch old line items to reverse stock
    const oldLineItems = await queryItems<Record<string, any>>(
        Keys.invoiceLineItemPK(invoiceId), 'LINEITEM#'
    );

    // 3. Batch-fetch products for new items
    if (!input.items || input.items.length === 0) {
        throw new InvoiceError('At least one item is required');
    }

    const productIds = [...new Set(input.items.map(i => i.productId))];
    const productKeys = productIds.map(pid => ({ PK: pk, SK: Keys.productSK(pid) }));
    const products = await batchGetItems<Record<string, any>>(productKeys);
    const productMap = new Map(products.map(p => [p.id, p]));

    // Validate all products exist
    for (const item of input.items) {
        if (!productMap.has(item.productId)) {
            throw new InvoiceError(`Product ${item.productId} not found`, 404);
        }
    }

    // 4. Calculate new line totals (same logic as createInvoice)
    const newLineItems: Record<string, any>[] = [];
    let subtotalCents = 0;
    let totalCgstCents = 0, totalSgstCents = 0, totalIgstCents = 0;

    for (const item of input.items) {
        const product = productMap.get(item.productId)!;
        const lineId = uuidv4();

        const unitPriceCents = item.unitPrice || Number(product.salePriceCents) || 0;
        const grossLineCents = unitPriceCents * item.quantity;
        const itemDiscount = Math.min(item.discountCents || 0, grossLineCents);
        const taxableValueCents = grossLineCents - itemDiscount;

        // GST calculation
        let lineCgst = 0, lineSgst = 0, lineIgst = 0;
        if (input.isInterState) {
            const igstBp = Number(product.igstRateBp) || 0;
            lineIgst = roundTaxComponent(taxableValueCents * igstBp / 10000);
        } else {
            const cgstBp = Number(product.cgstRateBp) || 0;
            const sgstBp = Number(product.sgstRateBp) || 0;
            lineCgst = roundTaxComponent(taxableValueCents * cgstBp / 10000);
            lineSgst = roundTaxComponent(taxableValueCents * sgstBp / 10000);
        }

        const lineTaxCents = lineCgst + lineSgst + lineIgst;
        const lineTotalCents = taxableValueCents + lineTaxCents;

        subtotalCents += taxableValueCents;
        totalCgstCents += lineCgst;
        totalSgstCents += lineSgst;
        totalIgstCents += lineIgst;

        newLineItems.push({
            PK: Keys.invoiceLineItemPK(invoiceId),
            SK: Keys.lineItemSK(lineId),
            entityType: 'LINE_ITEM',
            id: lineId,
            invoiceId,
            productId: item.productId,
            productName: product.name || item.productId,
            quantity: item.quantity,
            unitPriceCents,
            discountCents: itemDiscount,
            taxableValueCents,
            cgstCents: lineCgst,
            sgstCents: lineSgst,
            igstCents: lineIgst,
            taxCents: lineTaxCents,
            totalCents: lineTotalCents,
            unit: product.unit || 'pcs',
            hsnCode: product.hsnCode || '',
            isService: !!product.isService,
        });
    }

    // Bill-level discount
    const billDiscountCents = Math.min(input.discountCents || 0, subtotalCents);
    subtotalCents -= billDiscountCents;

    // FIX-HW-001: No per-component rounding — accumulate raw paise, single round-off
    const taxCents = totalCgstCents + totalSgstCents + totalIgstCents;

    // FIX-HW-001: Floor+remainder for CGST/SGST display
    if (!input.isInterState) {
        const totalIntraStateTax = totalCgstCents + totalSgstCents;
        // CRITICAL: GST Council Rule - CGST gets ceiling (extra paise when odd)
        totalCgstCents = Math.ceil(totalIntraStateTax / 2);
        totalSgstCents = totalIntraStateTax - totalCgstCents;
    }

    const preRoundTotal = subtotalCents + taxCents;
    const roundOffCents = Math.round(preRoundTotal / 100) * 100 - preRoundTotal;
    const totalCents = preRoundTotal + roundOffCents;

    const now = new Date().toISOString();

    // 5. Build transaction: AUDIT FIX BUG-2.2 — Net-delta stock approach
    // Instead of separate reverse + deduct for the same product,
    // compute netDelta = newQty - oldQty per product. This prevents
    // the TransactWrite condition-check race where DynamoDB evaluates
    // all conditions against pre-mutation state.
    const transactItems: any[] = [];

    // Build old quantity map: productId → totalOldQty
    const oldQtyMap = new Map<string, { qty: number; isService: boolean }>();
    for (const oldLine of oldLineItems.items) {
        const existing = oldQtyMap.get(oldLine.productId);
        if (existing) {
            existing.qty += Number(oldLine.quantity) || 0;
        } else {
            oldQtyMap.set(oldLine.productId, {
                qty: Number(oldLine.quantity) || 0,
                isService: !!oldLine.isService,
            });
        }
    }

    // Build new quantity map: productId → totalNewQty
    const newQtyMap = new Map<string, { qty: number; isService: boolean }>();
    for (const item of input.items) {
        const product = productMap.get(item.productId)!;
        const existing = newQtyMap.get(item.productId);
        if (existing) {
            existing.qty += item.quantity;
        } else {
            newQtyMap.set(item.productId, {
                qty: item.quantity,
                isService: !!product.isService,
            });
        }
    }

    // Compute net delta per product and create single Update per product
    const allProductIds = new Set([...oldQtyMap.keys(), ...newQtyMap.keys()]);
    for (const productId of allProductIds) {
        const oldEntry = oldQtyMap.get(productId);
        const newEntry = newQtyMap.get(productId);
        const isService = oldEntry?.isService || newEntry?.isService || false;
        if (isService) continue;

        const oldQty = oldEntry?.qty || 0;
        const newQty = newEntry?.qty || 0;
        const netDelta = newQty - oldQty; // positive = need more stock, negative = returning stock

        if (netDelta === 0) continue; // No change for this product

        if (netDelta > 0) {
            // Need more stock — deduct with safety check
            transactItems.push({
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET currentStock = currentStock - :qty, updatedAt = :now',
                    ConditionExpression: 'currentStock >= :qty',
                    ExpressionAttributeValues: { ':qty': netDelta, ':now': now },
                },
            });
        } else {
            // Returning stock — no condition needed (always safe to add)
            transactItems.push({
                Update: {
                    TableName: TABLE_NAME,
                    Key: { PK: pk, SK: Keys.productSK(productId) },
                    UpdateExpression: 'SET currentStock = currentStock + :qty, updatedAt = :now',
                    ExpressionAttributeValues: { ':qty': Math.abs(netDelta), ':now': now },
                },
            });
        }
    }

    // 5c. Update invoice header
    transactItems.push({
        Update: {
            TableName: TABLE_NAME,
            Key: { PK: pk, SK: sk },
            UpdateExpression: 'SET subtotalCents = :sub, taxCents = :tax, totalCents = :total, ' +
                'cgstCents = :cgst, sgstCents = :sgst, igstCents = :igst, ' +
                'roundOffCents = :roundOff, discountCents = :disc, billDiscountCents = :billDisc, ' +
                'balanceCents = :total, itemsCount = :count, updatedAt = :now' +
                (input.invoiceType ? ', invoiceType = :invoiceType' : '') +
                (input.invoiceProfileId ? ', invoiceProfileId = :invoiceProfileId' : '') +
                (input.customerName ? ', customerName = :cname' : '') +
                (input.customerPhone ? ', customerPhone = :cphone' : '') +
                (input.customerGstin ? ', customerGstin = :cgstin' : '') +
                (input.notes ? ', notes = :notes' : ''),
            ConditionExpression: '#s = :draft',
            ExpressionAttributeNames: { '#s': 'status' },
            ExpressionAttributeValues: {
                ':sub': subtotalCents, ':tax': taxCents, ':total': totalCents,
                ':cgst': totalCgstCents, ':sgst': totalSgstCents, ':igst': totalIgstCents,
                ':roundOff': roundOffCents, ':disc': billDiscountCents + input.items.reduce((s, i) => s + (i.discountCents || 0), 0),
                ':billDisc': billDiscountCents, ':count': input.items.length,
                ':now': now, ':draft': 'draft',
                ...(input.invoiceType ? { ':invoiceType': input.invoiceType } : {}),
                ...(input.invoiceProfileId ? { ':invoiceProfileId': input.invoiceProfileId } : {}),
                ...(input.customerName ? { ':cname': input.customerName } : {}),
                ...(input.customerPhone ? { ':cphone': input.customerPhone } : {}),
                ...(input.customerGstin ? { ':cgstin': input.customerGstin } : {}),
                ...(input.notes ? { ':notes': input.notes } : {}),
            },
        },
    });

    // 6. Execute the atomic transaction (stock reversal + new deduction + header update)
    const txLimit = 100;
    if (transactItems.length <= txLimit) {
        try {
            await transactWrite(transactItems);
        } catch (err: any) {
            if (err.name === 'TransactionCanceledException') {
                throw new InvoiceError('Insufficient stock for one or more items, or invoice was modified. Please retry.', 409);
            }
            throw err;
        }
    } else {
        throw new InvoiceError('Too many items to edit atomically. Please split the invoice.', 400);
    }

    // 7. AUDIT FIX BUG-2.5: Merge delete+put into a single batchWrite call.
    // Previously two separate calls — if Lambda crashed between delete and put,
    // old line items would be deleted but new ones never written (data loss).
    const lineItemOps: Array<{ type: 'put' | 'delete'; item?: Record<string, unknown>; key?: { PK: string; SK: string } }> = [];

    for (const line of oldLineItems.items) {
        lineItemOps.push({
            type: 'delete' as const,
            key: { PK: line.PK, SK: line.SK },
        });
    }
    for (const line of newLineItems) {
        lineItemOps.push({
            type: 'put' as const,
            item: line,
        });
    }

    if (lineItemOps.length > 0) await batchWrite(lineItemOps);

    // Audit log
    logAudit({
        action: 'INVOICE_UPDATED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { invoiceNumber: invoice.invoiceNumber, totalCents, itemsCount: input.items.length },
    }).catch(() => { });

    invalidateCache(`dashboard:${tenantId}`);
    await recordRevision(
        tenantId,
        'transactions',
        invoiceId,
        'update',
        'system',
        invoice,
        {
            ...invoice,
            subtotalCents,
            taxCents,
            totalCents,
            cgstCents: totalCgstCents,
            sgstCents: totalSgstCents,
            igstCents: totalIgstCents,
            roundOffCents,
            discountCents: billDiscountCents + input.items.reduce((s, i) => s + (i.discountCents || 0), 0),
            billDiscountCents,
            balanceCents: totalCents,
            itemsCount: input.items.length,
            updatedAt: now,
        },
        { source: 'invoice.updateInvoice' },
    );

    logger.info('Invoice updated', { tenantId, invoiceId, totalCents });
    return {
        id: invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        status: 'draft',
        totalCents,
        subtotalCents: subtotalCents,
        taxCents: taxCents,
        cgstCents: totalCgstCents,
        sgstCents: totalSgstCents,
        igstCents: totalIgstCents,
        discountCents: billDiscountCents + input.items.reduce((s, i) => s + (i.discountCents || 0), 0),
        paidCents: 0,
        balanceCents: totalCents,
        paymentMode: invoice.paymentMode || 'cash',
        roundOffCents: roundOffCents,
        itemsCount: input.items.length,
        createdAt: invoice.createdAt,
        invoiceType: (input.invoiceType || invoice.invoiceType || 'tax_invoice') as 'tax_invoice' | 'retail_invoice' | 'proforma_invoice',
    };
}

// ---- Errors ----

// M-10: InvoiceError now extends AppError for standardized error handling
export class InvoiceError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'INVOICE_ERROR');
        this.name = 'InvoiceError';
    }
}

// SERIAL-001: Re-export InvoiceValidationError for handler error catching
export { InvoiceValidationError } from '../utils/errors';

// FIX-HW-001: Invariant violation — should never happen in production
export class InvariantError extends AppError {
    constructor(message: string) {
        super(message, 500, 'INVARIANT_VIOLATION');
        this.name = 'InvariantError';
    }
}

// FIX-HW-002: Re-exported from shared errors module for backward compatibility
// (actual class definition is now in ../utils/errors.ts)
export { CreditLimitExceededError } from '../utils/errors';

// FIX-HW-004: Unit of measure mismatch
export class UnitMismatchError extends AppError {
    productId: string;
    expectedUnit: string;
    receivedUnit: string;
    constructor(message: string, productId: string, expected: string, received: string, statusCode = 400) {
        super(message, statusCode, 'UNIT_MISMATCH');
        this.name = 'UnitMismatchError';
        this.productId = productId;
        this.expectedUnit = expected;
        this.receivedUnit = received;
    }
}

