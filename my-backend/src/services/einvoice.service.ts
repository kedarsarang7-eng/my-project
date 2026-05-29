import { config } from '../config/environment';
// ============================================================================
// E-Invoice Service — IRN Generation via NIC GST API
// ============================================================================
// AUDIT: GST-3.2 — E-Invoice integration for B2B invoices > ₹5 Cr turnover.
//
// Flow:
//   1. After invoice finalization, check if e-invoice is required
//   2. Generate JSON payload per NIC e-Invoice Schema v1.1
//   3. Sign with tenant's digital certificate
//   4. Submit to NIC e-Invoice Portal API
//   5. Store IRN + signed QR code + acknowledgement on the invoice record
//
// Environments:
//   Sandbox: einv-apisandbox.nic.in
//   Production: einvoice1.gst.gov.in
//
// DynamoDB Entity:
//   PK: TENANT#{tenantId}, SK: EINVOICE#{invoiceId}  — IRN record
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys, getItem, putItem, updateItem, queryItems,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { logAudit } from '../middleware/audit';
import { AppError } from '../utils/errors';

export class EInvoiceError extends AppError {
    constructor(message: string, statusCode = 400) {
        super(message, statusCode, 'EINVOICE_ERROR');
    }
}

const NIC_SANDBOX_URL = 'https://einv-apisandbox.nic.in';
const NIC_PROD_URL = 'https://einvoice1.gst.gov.in';

interface EInvoicePayload {
    Version: string;
    TranDtls: {
        TaxSch: string; // GST
        SupTyp: string; // B2B, SEZWP, SEZWOP, EXPWP, EXPWOP, DEXP
        RegRev: string; // Y/N (reverse charge)
        EcmGstin: string | null;
    };
    DocDtls: {
        Typ: string; // INV, CRN, DBN
        No: string;
        Dt: string; // DD/MM/YYYY
    };
    SellerDtls: {
        Gstin: string;
        LglNm: string;
        TrdNm?: string;
        Addr1: string;
        Addr2?: string;
        Loc: string;
        Pin: number;
        Stcd: string;
    };
    BuyerDtls: {
        Gstin: string;
        LglNm: string;
        TrdNm?: string;
        Pos: string; // Place of supply state code
        Addr1: string;
        Addr2?: string;
        Loc: string;
        Pin: number;
        Stcd: string;
    };
    ItemList: Array<{
        SlNo: string;
        PrdDesc: string;
        IsServc: string; // Y/N
        HsnCd: string;
        Qty: number;
        FreeQty?: number;
        Unit: string;
        UnitPrice: number;
        TotAmt: number;
        Discount: number;
        PreTaxVal?: number;
        AssAmt: number;
        GstRt: number;
        IgstAmt: number;
        CgstAmt: number;
        SgstAmt: number;
        CesRt?: number;
        CesAmt?: number;
        CesNonAdvlAmt?: number;
        StateCesRt?: number;
        StateCesAmt?: number;
        StateCesNonAdvlAmt?: number;
        OthChrg?: number;
        TotItemVal: number;
    }>;
    ValDtls: {
        AssVal: number;
        CgstVal: number;
        SgstVal: number;
        IgstVal: number;
        CesVal?: number;
        StCesVal?: number;
        Discount?: number;
        OthChrg?: number;
        RndOffAmt?: number;
        TotInvVal: number;
    };
}

interface EWayBillPayload {
    supplyType: string;
    subSupplyType?: string;
    subSupplyDesc?: string;
    docType: string;
    docNo: string;
    docDate: string;
    fromGstin?: string;
    fromTrdName?: string;
    fromAddr1?: string;
    fromAddr2?: string;
    fromPlace: string;
    fromStateCode?: string;
    toPlace: string;
    toGstin?: string;
    toTrdName?: string;
    toAddr1?: string;
    toAddr2?: string;
    toStateCode?: string;
    distance: number;
    transDistance?: number;
    fromPincode?: string;
    toPincode?: string;
    totalValue?: number;
    cgstValue?: number;
    sgstValue?: number;
    igstValue?: number;
    cessValue?: number;
    totInvValue?: number;
    vehicleNo?: string;
    vehicleType?: string;
    transMode?: string;
    transporterId?: string;
    transporterName?: string;
    itemList?: Array<{
        productName: string;
        productDesc?: string;
        hsnCode: string;
        quantity: number;
        qtyUnit?: string;
        taxableAmount: number;
        cgstRate?: number;
        sgstRate?: number;
        igstRate?: number;
        cessRate?: number;
    }>;
}

/**
 * Check if a tenant requires e-invoicing.
 * Currently mandatory for businesses with turnover > ₹5 Cr.
 */
export async function isEInvoiceRequired(tenantId: string): Promise<boolean> {
    try {
        const settings = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId), 'SETTINGS#EINVOICE',
        );
        return settings?.isEnabled === true;
    } catch {
        return false;
    }
}

/**
 * Generate and submit e-invoice to NIC portal.
 * Called after invoice finalization for B2B invoices.
 */
export async function generateEInvoice(
    tenantId: string,
    invoiceId: string,
): Promise<{
    irn: string;
    ackNo: string;
    ackDt: string;
    signedQrCode: string;
    status: 'success' | 'pending';
}> {
    // Fetch invoice
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );
    if (!invoice) throw new EInvoiceError('Invoice not found', 404);

    // Only B2B invoices (with customer GSTIN) are eligible
    const customerGstin = invoice.metadata?.customerGstin || invoice.customerGstin;
    if (!customerGstin) {
        throw new EInvoiceError('E-invoice is only for B2B invoices with customer GSTIN');
    }

    // Check if IRN already exists
    const existing = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        `EINVOICE#${invoiceId}`,
    );
    if (existing?.irn) {
        return {
            irn: existing.irn,
            ackNo: existing.ackNo,
            ackDt: existing.ackDt,
            signedQrCode: existing.signedQrCode,
            status: 'success',
        };
    }

    // Fetch tenant profile for seller details
    const tenantProfile = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'PROFILE',
    );
    if (!tenantProfile?.gstin) {
        throw new EInvoiceError('Tenant GSTIN not configured');
    }

    // Fetch e-invoice settings (API credentials)
    const eInvSettings = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'SETTINGS#EINVOICE',
    );
    if (!eInvSettings?.clientId || !eInvSettings?.clientSecret) {
        throw new EInvoiceError('E-Invoice API credentials not configured');
    }

    // Fetch line items
    const lineItems = await queryItems<Record<string, any>>(
        `INVOICE#${invoiceId}`, 'LINEITEM#',
    );

    // Build NIC e-Invoice payload
    const isInterState = invoice.isInterState === true;
    const invoiceDate = new Date(invoice.createdAt);
    const formattedDate = `${String(invoiceDate.getDate()).padStart(2, '0')}/${String(invoiceDate.getMonth() + 1).padStart(2, '0')}/${invoiceDate.getFullYear()}`;

    const payload: EInvoicePayload = {
        Version: '1.1',
        TranDtls: {
            TaxSch: 'GST',
            SupTyp: 'B2B',
            RegRev: 'N',
            EcmGstin: null,
        },
        DocDtls: {
            Typ: 'INV',
            No: invoice.invoiceNumber,
            Dt: formattedDate,
        },
        SellerDtls: {
            Gstin: tenantProfile.gstin,
            LglNm: tenantProfile.legalName || tenantProfile.name || tenantProfile.shopName,
            TrdNm: tenantProfile.shopName || tenantProfile.name,
            Addr1: tenantProfile.address || '',
            Loc: tenantProfile.city || tenantProfile.location || '',
            Pin: Number(tenantProfile.pincode) || 0,
            Stcd: tenantProfile.gstin.substring(0, 2),
        },
        BuyerDtls: {
            Gstin: customerGstin,
            LglNm: invoice.customerName || '',
            Pos: customerGstin.substring(0, 2),
            Addr1: invoice.customerAddress || invoice.metadata?.customerAddress || '',
            Loc: invoice.metadata?.customerCity || '',
            Pin: Number(invoice.metadata?.customerPincode) || 0,
            Stcd: customerGstin.substring(0, 2),
        },
        ItemList: lineItems.items.map((li, idx) => {
            const unitPrice = (Number(li.unitPriceCents) || 0) / 100;
            const qty = Number(li.quantity) || 0;
            const totAmt = unitPrice * qty;
            const discount = (Number(li.discountCents) || 0) / 100;
            const assAmt = totAmt - discount;
            const cgst = (Number(li.cgstCents) || 0) / 100;
            const sgst = (Number(li.sgstCents) || 0) / 100;
            const igst = (Number(li.igstCents) || 0) / 100;
            const gstRate = isInterState
                ? Number(li.igstRateBp || 0) / 100
                : (Number(li.cgstRateBp || 0) + Number(li.sgstRateBp || 0)) / 100;

            return {
                SlNo: String(idx + 1),
                PrdDesc: li.name || '',
                IsServc: li.isService ? 'Y' : 'N',
                HsnCd: li.hsnCode || '0',
                Qty: qty,
                Unit: mapUnitToNIC(li.unit || 'pcs'),
                UnitPrice: unitPrice,
                TotAmt: totAmt,
                Discount: discount,
                AssAmt: assAmt,
                GstRt: gstRate,
                IgstAmt: igst,
                CgstAmt: cgst,
                SgstAmt: sgst,
                TotItemVal: assAmt + igst + cgst + sgst,
            };
        }),
        ValDtls: {
            AssVal: (Number(invoice.subtotalCents) || 0) / 100,
            CgstVal: (Number(invoice.cgstCents) || 0) / 100,
            SgstVal: (Number(invoice.sgstCents) || 0) / 100,
            IgstVal: (Number(invoice.igstCents) || 0) / 100,
            Discount: (Number(invoice.discountCents) || 0) / 100,
            RndOffAmt: (Number(invoice.roundOffCents) || 0) / 100,
            TotInvVal: (Number(invoice.totalCents) || 0) / 100,
        },
    };

    // Submit to NIC API
    const isProduction = eInvSettings.environment === 'production';
    const baseUrl = isProduction ? NIC_PROD_URL : NIC_SANDBOX_URL;

    let irnResult: {
        irn: string;
        ackNo: string;
        ackDt: string;
        signedQrCode: string;
    };

    try {
        // Step 1: Authenticate
        const authResponse = await fetch(`${baseUrl}/eivital/v1.04/auth`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
            },
            body: JSON.stringify({
                UserName: eInvSettings.username,
                Password: eInvSettings.password,
                Gstin: tenantProfile.gstin,
            }),
        });

        if (!authResponse.ok) {
            const errorBody = await authResponse.text();
            logger.error('E-Invoice auth failed', { tenantId, status: authResponse.status, body: errorBody });
            throw new EInvoiceError(`NIC authentication failed: ${authResponse.status}`);
        }

        const authData = await authResponse.json() as Record<string, any>;
        const authToken = authData.Data?.AuthToken || authData.AuthToken;

        if (!authToken) {
            throw new EInvoiceError('No auth token received from NIC');
        }

        // Step 2: Generate IRN
        const irnResponse = await fetch(`${baseUrl}/eicore/v1.03/Invoice`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
                'AuthToken': authToken,
            },
            body: JSON.stringify(payload),
        });

        if (!irnResponse.ok) {
            const errorBody = await irnResponse.text();
            logger.error('E-Invoice IRN generation failed', { tenantId, invoiceId, status: irnResponse.status, body: errorBody });
            throw new EInvoiceError(`IRN generation failed: HTTP ${irnResponse.status}`);
        }

        const irnData = await irnResponse.json() as Record<string, any>;

        if (!irnData.Data?.Irn) {
            throw new EInvoiceError(`IRN generation failed: ${irnData.ErrorDetails?.[0]?.ErrorMessage || 'Unknown error'}`);
        }

        irnResult = {
            irn: irnData.Data.Irn,
            ackNo: String(irnData.Data.AckNo || ''),
            ackDt: irnData.Data.AckDt || '',
            signedQrCode: irnData.Data.SignedQRCode || '',
        };
    } catch (err) {
        if (err instanceof EInvoiceError) throw err;
        logger.error('E-Invoice API call failed', {
            tenantId, invoiceId, error: (err as Error).message,
        });
        throw new EInvoiceError(`E-Invoice API error: ${(err as Error).message}`, 502);
    }

    // Store IRN record
    const now = new Date().toISOString();
    await putItem({
        PK: Keys.tenantPK(tenantId),
        SK: `EINVOICE#${invoiceId}`,
        entityType: 'EINVOICE',
        tenantId,
        invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        irn: irnResult.irn,
        ackNo: irnResult.ackNo,
        ackDt: irnResult.ackDt,
        signedQrCode: irnResult.signedQrCode,
        payload: JSON.stringify(payload),
        status: 'generated',
        createdAt: now,
    });

    // Update invoice record with IRN
    await updateItem(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
        {
            updateExpression: 'SET irn = :irn, irnAckNo = :ackNo, irnAckDt = :ackDt, updatedAt = :now',
            expressionAttributeValues: {
                ':irn': irnResult.irn,
                ':ackNo': irnResult.ackNo,
                ':ackDt': irnResult.ackDt,
                ':now': now,
            },
        },
    );

    logAudit({
        action: 'EINVOICE_GENERATED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { irn: irnResult.irn, ackNo: irnResult.ackNo },
    }).catch(() => {});

    logger.info('E-Invoice generated', { tenantId, invoiceId, irn: irnResult.irn });

    return { ...irnResult, status: 'success' };
}

/**
 * Cancel an e-invoice IRN.
 * Allowed within 24 hours of generation per NIC rules.
 */
export async function cancelEInvoice(
    tenantId: string,
    invoiceId: string,
    cancelReason: '1' | '2' | '3' | '4', // 1=Duplicate, 2=DataEntry, 3=OrderCancel, 4=Others
    cancelRemarks: string,
): Promise<{ cancelled: boolean }> {
    const existing = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        `EINVOICE#${invoiceId}`,
    );

    if (!existing?.irn) {
        throw new EInvoiceError('No e-invoice found for this invoice', 404);
    }

    if (existing.status === 'cancelled') {
        throw new EInvoiceError('E-invoice already cancelled');
    }

    // Check 24-hour window
    const createdAt = new Date(existing.createdAt);
    const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    if (hoursSinceCreation > 24) {
        throw new EInvoiceError('E-invoice can only be cancelled within 24 hours of generation');
    }

    const eInvSettings = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), 'SETTINGS#EINVOICE',
    );
    const tenantProfile = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId), 'PROFILE',
    );

    if (!eInvSettings?.clientId || !tenantProfile?.gstin) {
        throw new EInvoiceError('E-Invoice credentials not configured');
    }

    const isProduction = eInvSettings.environment === 'production';
    const baseUrl = isProduction ? NIC_PROD_URL : NIC_SANDBOX_URL;

    try {
        // Authenticate
        const authResponse = await fetch(`${baseUrl}/eivital/v1.04/auth`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
            },
            body: JSON.stringify({
                UserName: eInvSettings.username,
                Password: eInvSettings.password,
                Gstin: tenantProfile.gstin,
            }),
        });

        const authData = await authResponse.json() as Record<string, any>;
        const authToken = authData.Data?.AuthToken || authData.AuthToken;

        // Cancel IRN
        const cancelResponse = await fetch(`${baseUrl}/eicore/v1.03/Invoice/Cancel`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
                'AuthToken': authToken,
            },
            body: JSON.stringify({
                Irn: existing.irn,
                CnlRsn: cancelReason,
                CnlRem: cancelRemarks,
            }),
        });

        if (!cancelResponse.ok) {
            const errorBody = await cancelResponse.text();
            throw new EInvoiceError(`IRN cancellation failed: ${errorBody}`);
        }
    } catch (err) {
        if (err instanceof EInvoiceError) throw err;
        throw new EInvoiceError(`E-Invoice cancel API error: ${(err as Error).message}`, 502);
    }

    const now = new Date().toISOString();
    await updateItem(
        Keys.tenantPK(tenantId),
        `EINVOICE#${invoiceId}`,
        {
            updateExpression: 'SET #s = :cancelled, cancelledAt = :now, cancelReason = :reason, cancelRemarks = :remarks',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':cancelled': 'cancelled',
                ':now': now,
                ':reason': cancelReason,
                ':remarks': cancelRemarks,
            },
        },
    );

    logAudit({
        action: 'EINVOICE_CANCELLED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { irn: existing.irn, reason: cancelReason },
    }).catch(() => {});

    logger.info('E-Invoice cancelled', { tenantId, invoiceId, irn: existing.irn });
    return { cancelled: true };
}

export async function generateEWayBill(
    tenantId: string,
    invoiceId: string,
    input: {
        fromPlace: string;
        toPlace: string;
        distanceKm: number;
        fromPincode?: string;
        toPincode?: string;
        vehicleNumber?: string;
        transporterId?: string;
        transporterName?: string;
    },
): Promise<{
    ewbNo: string;
    ewbDate: string;
    validUntil?: string;
    status: 'success';
}> {
    const invoice = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        Keys.invoiceSK(invoiceId),
    );
    if (!invoice) throw new EInvoiceError('Invoice not found', 404);

    const tenantProfile = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'PROFILE',
    );
    if (!tenantProfile?.gstin) {
        throw new EInvoiceError('Tenant GSTIN not configured');
    }

    const eInvSettings = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'SETTINGS#EINVOICE',
    );
    if (!eInvSettings?.clientId || !eInvSettings?.clientSecret) {
        throw new EInvoiceError('E-Invoice API credentials not configured');
    }

    const isProduction = eInvSettings.environment === 'production';
    const baseUrl = isProduction ? NIC_PROD_URL : NIC_SANDBOX_URL;
    const ewayPath = resolveEWayBillPath(eInvSettings?.ewayBillPath as string | undefined);
    const lineItems = await queryItems<Record<string, any>>(
        `INVOICE#${invoiceId}`,
        'LINEITEM#',
    ).catch(() => ({ items: [] as Record<string, any>[] }));

    const invoiceDate = new Date(invoice.createdAt || Date.now());
    const formattedDate = `${String(invoiceDate.getDate()).padStart(2, '0')}/${String(invoiceDate.getMonth() + 1).padStart(2, '0')}/${invoiceDate.getFullYear()}`;
    const buyerGstin = (invoice.metadata?.customerGstin || invoice.customerGstin || '').toString();
    const buyerStateCode = buyerGstin.length >= 2
        ? buyerGstin.substring(0, 2)
        : (invoice.metadata?.customerStateCode || tenantProfile.gstin.substring(0, 2)).toString();
    const itemList = (lineItems.items || []).map(li => ({
        productName: String(li.name || li.productName || 'Item'),
        productDesc: li.description ? String(li.description) : undefined,
        hsnCode: String(li.hsnCode || '0'),
        quantity: Number(li.quantity) || 0,
        qtyUnit: mapUnitToNIC(String(li.unit || 'pcs')),
        taxableAmount: Math.max(0, (Number(li.taxableValueCents ?? li.subtotalCents ?? 0) / 100)),
        cgstRate: Number(li.cgstRateBp || 0) / 100,
        sgstRate: Number(li.sgstRateBp || 0) / 100,
        igstRate: Number(li.igstRateBp || 0) / 100,
        cessRate: Number(li.cessRateBp || 0) / 100,
    }));

    const payload: EWayBillPayload = {
        supplyType: 'O',
        subSupplyType: '1',
        docType: 'INV',
        docNo: invoice.invoiceNumber || invoiceId,
        docDate: formattedDate,
        fromGstin: tenantProfile.gstin,
        fromTrdName: tenantProfile.shopName || tenantProfile.name || tenantProfile.legalName,
        fromAddr1: tenantProfile.address || '',
        fromAddr2: tenantProfile.address2 || undefined,
        fromPlace: input.fromPlace,
        fromStateCode: tenantProfile.gstin.substring(0, 2),
        toGstin: buyerGstin || 'URP',
        toTrdName: invoice.customerName || invoice.metadata?.customerName || 'Customer',
        toAddr1: invoice.customerAddress || invoice.metadata?.customerAddress || '',
        toAddr2: invoice.metadata?.customerAddress2 || undefined,
        toPlace: input.toPlace,
        toStateCode: buyerStateCode,
        distance: input.distanceKm,
        transDistance: input.distanceKm,
        fromPincode: input.fromPincode,
        toPincode: input.toPincode,
        totalValue: (Number(invoice.subtotalCents) || 0) / 100,
        cgstValue: (Number(invoice.cgstCents) || 0) / 100,
        sgstValue: (Number(invoice.sgstCents) || 0) / 100,
        igstValue: (Number(invoice.igstCents) || 0) / 100,
        cessValue: (Number(invoice.cessCents) || 0) / 100,
        totInvValue: (Number(invoice.totalCents) || 0) / 100,
        vehicleNo: input.vehicleNumber,
        vehicleType: input.vehicleNumber ? 'R' : undefined,
        transMode: input.vehicleNumber ? '1' : undefined,
        transporterId: input.transporterId,
        transporterName: input.transporterName,
        itemList,
    };

    let ewbResult: { ewbNo: string; ewbDate: string; validUntil?: string };
    try {
        const authResponse = await fetch(`${baseUrl}/eivital/v1.04/auth`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
            },
            body: JSON.stringify({
                UserName: eInvSettings.username,
                Password: eInvSettings.password,
                Gstin: tenantProfile.gstin,
            }),
        });
        if (!authResponse.ok) {
            const errorBody = await authResponse.text();
            throw new EInvoiceError(`NIC authentication failed: ${authResponse.status} ${errorBody}`);
        }
        const authData = await authResponse.json() as Record<string, any>;
        const authToken = authData.Data?.AuthToken || authData.AuthToken;
        if (!authToken) throw new EInvoiceError('No auth token received from NIC');

        const ewbResponse = await fetch(`${baseUrl}${ewayPath}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'client_id': eInvSettings.clientId,
                'client_secret': eInvSettings.clientSecret,
                'gstin': tenantProfile.gstin,
                'AuthToken': authToken,
            },
            body: JSON.stringify(payload),
        });
        if (!ewbResponse.ok) {
            const errorBody = await ewbResponse.text();
            throw new EInvoiceError(`E-Way Bill generation failed: HTTP ${ewbResponse.status} ${errorBody}`);
        }
        const ewbData = await ewbResponse.json() as Record<string, any>;
        const data = (ewbData.Data && typeof ewbData.Data === 'object') ? ewbData.Data as Record<string, any> : ewbData;
        const ewbNo = String(data.EwbNo || data.ewayBillNo || data.ewbNo || '').trim();
        if (!ewbNo) {
            throw new EInvoiceError(`E-Way Bill generation failed: ${data.ErrorMessage || 'Missing EWB number'}`);
        }
        ewbResult = {
            ewbNo,
            ewbDate: String(data.EwbDt || data.ewayBillDate || new Date().toISOString()),
            validUntil: data.ValidUpto || data.validUpto || data.validUntil,
        };
    } catch (err) {
        if (err instanceof EInvoiceError) throw err;
        logger.error('E-Way Bill API call failed', {
            tenantId, invoiceId, error: (err as Error).message,
        });
        throw new EInvoiceError(`E-Way Bill API error: ${(err as Error).message}`, 502);
    }

    logAudit({
        action: 'EWAY_BILL_GENERATED',
        resource: 'invoice',
        resourceId: invoiceId,
        metadata: { ewbNo: ewbResult.ewbNo },
    }).catch(() => { });

    return {
        ...ewbResult,
        status: 'success',
    };
}

function resolveEWayBillPath(pathOverride?: string): string {
    const raw = (pathOverride || config.einvoice.nicEwayBillPath || '/ewaybill').trim();
    if (!raw) return '/ewaybill';
    return raw.startsWith('/') ? raw : `/${raw}`;
}

export async function getEInvoiceSettings(tenantId: string): Promise<{
    isEnabled: boolean;
    environment: 'sandbox' | 'production';
    username?: string;
    hasClientId: boolean;
    hasClientSecret: boolean;
    ewayBillPath?: string;
}> {
    const settings = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'SETTINGS#EINVOICE',
    );

    return {
        isEnabled: settings?.isEnabled === true,
        environment: settings?.environment === 'production' ? 'production' : 'sandbox',
        username: settings?.username || undefined,
        hasClientId: Boolean(settings?.clientId),
        hasClientSecret: Boolean(settings?.clientSecret),
        ewayBillPath: settings?.ewayBillPath || undefined,
    };
}

export async function upsertEInvoiceSettings(
    tenantId: string,
    input: {
        isEnabled: boolean;
        environment: 'sandbox' | 'production';
        clientId?: string;
        clientSecret?: string;
        username?: string;
        password?: string;
        ewayBillPath?: string;
    },
): Promise<{ updated: boolean }> {
    const now = new Date().toISOString();
    const existing = await getItem<Record<string, any>>(
        Keys.tenantPK(tenantId),
        'SETTINGS#EINVOICE',
    );

    await putItem({
        PK: Keys.tenantPK(tenantId),
        SK: 'SETTINGS#EINVOICE',
        entityType: 'EINVOICE_SETTINGS',
        tenantId,
        isEnabled: input.isEnabled,
        environment: input.environment,
        clientId: input.clientId || existing?.clientId || null,
        clientSecret: input.clientSecret || existing?.clientSecret || null,
        username: input.username || existing?.username || null,
        password: input.password || existing?.password || null,
        ewayBillPath: input.ewayBillPath || existing?.ewayBillPath || null,
        createdAt: existing?.createdAt || now,
        updatedAt: now,
    });

    return { updated: true };
}

/**
 * Map DukanX unit codes to NIC unit codes.
 * Per e-Invoice schema v1.1 Unit code list.
 */
function mapUnitToNIC(unit: string): string {
    const unitMap: Record<string, string> = {
        'pcs': 'NOS', 'nos': 'NOS', 'pieces': 'NOS',
        'kg': 'KGS', 'kgs': 'KGS',
        'g': 'GMS', 'gms': 'GMS', 'gram': 'GMS',
        'l': 'LTR', 'ltr': 'LTR', 'litre': 'LTR', 'liter': 'LTR',
        'ml': 'MLT', 'mlt': 'MLT',
        'm': 'MTR', 'mtr': 'MTR', 'meter': 'MTR',
        'box': 'BOX', 'dozen': 'DOZ', 'doz': 'DOZ',
        'pack': 'PAC', 'pair': 'PRS', 'set': 'SET',
        'bag': 'BAG', 'roll': 'ROL', 'sheet': 'SHT',
        'ton': 'TON', 'quintal': 'QTL',
    };
    return unitMap[unit.toLowerCase()] || 'OTH';
}
