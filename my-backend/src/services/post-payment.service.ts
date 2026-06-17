// ============================================================================
// Post-Payment Service — Orchestrates All Post-Payment Actions (DynamoDB)
// ============================================================================
// Migrated from PostgreSQL to DynamoDB single-table design.
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import * as whatsappService from './whatsapp.service';
import { Keys, getItem, queryItems, updateItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { recordRevision } from './revision-history.service';
import { config } from '../config/environment';

const s3Client = new S3Client(configureAwsClient({ region: config.aws.region }));
const S3_BUCKET = config.s3.bucketName;

interface PostPaymentInput {
    tenantId: string;
    invoiceId: string;
    paymentOrderId: string;
    amountCents: number;
    gatewayTransactionId?: string;
}

export async function executePostPaymentActions(input: PostPaymentInput): Promise<void> {
    const { tenantId, invoiceId, paymentOrderId, amountCents, gatewayTransactionId } = input;

    // Fetch invoice details
    let invoiceDetails: Record<string, any> | null = null;
    try {
        invoiceDetails = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId),
            Keys.invoiceSK(invoiceId),
        );
    } catch (err) {
        logger.error('Post-payment: failed to fetch invoice', { invoiceId, error: (err as Error).message });
        return;
    }
    if (!invoiceDetails) return;

    // ── Action 0: Update Staff Sale Transaction (if linked) ────────────
    try {
        const now = new Date().toISOString();
        const staffSales = await queryItems<Record<string, any>>(
            Keys.tenantPK(tenantId),
            'STAFFSALE#',
            {
                filterExpression: 'paymentOrderId = :poid AND paymentStatus = :pending',
                expressionAttributeValues: { ':poid': paymentOrderId, ':pending': 'pending' },
            },
        );

        for (const sale of staffSales.items) {
            const beforeSale = { ...sale };
            await updateItem(
                sale.PK, sale.SK,
                {
                    updateExpression: 'SET paymentStatus = :paid, updatedAt = :now',
                    expressionAttributeValues: { ':paid': 'paid', ':now': now },
                },
            );
            await recordRevision(
                tenantId,
                'staff_sales_details',
                String(sale.id || ''),
                'status_change',
                'system',
                beforeSale,
                { ...beforeSale, paymentStatus: 'paid', updatedAt: now },
                { source: 'post-payment.executePostPaymentActions', paymentOrderId },
            );
            logger.info('Staff sale payment confirmed', {
                staffSaleId: sale.id, staffId: sale.staffId, paymentOrderId,
            });
        }

        // Update the invoice itself
        const beforeInvoice = { ...invoiceDetails };
        await updateItem(
            Keys.tenantPK(tenantId),
            Keys.invoiceSK(invoiceId),
            {
                updateExpression: 'SET #s = :paid, paidCents = totalCents, balanceCents = :zero, updatedAt = :now',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':paid': 'paid', ':zero': 0, ':now': now },
            },
        );
        await recordRevision(
            tenantId,
            'transactions',
            invoiceId,
            'status_change',
            'system',
            beforeInvoice,
            {
                ...beforeInvoice,
                status: 'paid',
                paidCents: Number(beforeInvoice.totalCents || 0),
                balanceCents: 0,
                updatedAt: now,
            },
            { source: 'post-payment.executePostPaymentActions', paymentOrderId },
        );
    } catch (err) {
        logger.error('Post-payment: staff sale update failed', { paymentOrderId, error: (err as Error).message });
    }

    // ── Action 1: Generate & Upload Invoice PDF to S3 ───────────────────
    let invoicePdfUrl: string | undefined;
    try {
        invoicePdfUrl = await generateAndUploadInvoicePdf(tenantId, invoiceId, invoiceDetails);
    } catch (err) {
        logger.error('Post-payment: PDF generation failed', { invoiceId, error: (err as Error).message });
    }

    // ── Action 2: Send WhatsApp Notification ────────────────────────────
    if (invoiceDetails.customerPhone) {
        try {
            const amount = formatAmount(amountCents);
            await whatsappService.sendPaymentConfirmation({
                customerPhone: invoiceDetails.customerPhone,
                customerName: invoiceDetails.customerName || 'Customer',
                amount,
                transactionId: gatewayTransactionId || paymentOrderId,
                invoiceNumber: invoiceDetails.invoiceNumber,
                invoicePdfUrl,
            });
        } catch (err) {
            logger.error('Post-payment: WhatsApp notification failed', { invoiceId, error: (err as Error).message });
        }
    }

    logger.info('Post-payment actions completed', {
        tenantId, invoiceId, paymentOrderId, pdfUploaded: !!invoicePdfUrl,
    });
}

async function generateAndUploadInvoicePdf(tenantId: string, invoiceId: string, invoice: any): Promise<string | undefined> {
    if (!S3_BUCKET) { logger.warn('S3 bucket not configured'); return undefined; }

    // Fetch line items for this invoice
    let lineItems: Record<string, any>[] = [];
    try {
        const result = await queryItems<Record<string, any>>(
            Keys.invoiceLineItemPK(invoiceId), 'LINEITEM#', { limit: 500 },
        );
        lineItems = result.items;
    } catch (err) {
        logger.warn('Failed to fetch line items for PDF', { invoiceId, error: (err as Error).message });
    }

    // Fetch tenant/business details for header
    let businessDetails: Record<string, any> = {};
    try {
        const tenant = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId), 'META',
        );
        businessDetails = tenant || {};
    } catch { /* Use defaults if tenant details unavailable */ }

    const htmlContent = generateInvoiceHtml(invoice, lineItems, businessDetails);
    const pdfBuffer = Buffer.from(htmlContent, 'utf-8');
    const now = new Date();
    const s3Key = `tenants/${tenantId}/invoices/${now.getFullYear()}/${String(now.getMonth() + 1).padStart(2, '0')}/${invoiceId}.html`;

    await s3Client.send(new PutObjectCommand({
        Bucket: S3_BUCKET, Key: s3Key, Body: pdfBuffer, ContentType: 'text/html',
        Metadata: { tenantId, invoiceId, invoiceNumber: invoice.invoiceNumber || '' },
    }));

    const url = `https://${S3_BUCKET}.s3.${config.aws.region}.amazonaws.com/${s3Key}`;
    logger.info('Invoice uploaded to S3', { s3Key, tenantId, invoiceId });
    return url;
}

// ============================================================================
// FEATURE-D: GST-Compliant Invoice/Receipt HTML Template
// ============================================================================
// Mandatory fields per GST Rule 46 (Tax Invoice):
//   1. Business name, address, GSTIN
//   2. Invoice number (sequential), date
//   3. Customer name, address (if registered), GSTIN (for B2B)
//   4. HSN/SAC code for each item
//   5. Description, quantity, unit, rate
//   6. Taxable value per item
//   7. CGST/SGST (intra-state) or IGST (inter-state) rate + amount
//   8. Total tax amount
//   9. Total invoice value (in figures and words)
//  10. Place of supply (for inter-state)
//  11. Round-off amount
//  12. Signature / digital signature
// ============================================================================

function generateInvoiceHtml(
    invoice: any,
    lineItems: Record<string, any>[],
    business: Record<string, any>,
): string {
    const isInterState = !!invoice.isInterState;
    const invoiceDate = invoice.createdAt
        ? new Date(invoice.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
        : new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    const invoiceTime = invoice.createdAt
        ? new Date(invoice.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
        : '';

    // Business info with fallbacks
    const bizName = business.name || business.businessName || 'Your Business';
    const bizAddress = business.address || business.shopAddress || '';
    const bizGstin = business.gstin || business.GSTIN || '';
    const bizPhone = business.phone || '';
    const bizState = business.state || '';

    // Customer info
    const custName = invoice.customerName || 'Walk-in Customer';
    const custPhone = invoice.customerPhone || '';
    const custGstin = invoice.metadata?.customerGstin || '';

    // Prescription info (pharmacy)
    const prescriptionId = invoice.metadata?.prescriptionId || '';
    const doctorName = invoice.metadata?.doctorName || '';
    const doctorRegNo = invoice.metadata?.doctorRegNo || '';

    // ── Line Items HTML ──
    const sortedItems = [...lineItems].sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    let lineItemsHtml = '';
    let slNo = 0;
    for (const item of sortedItems) {
        slNo++;
        const qty = item.quantity || 0;
        const unit = item.unit || 'pcs';
        const rate = formatAmount(item.unitPriceCents || 0);
        const hsn = item.hsnCode || '—';
        const taxableValue = formatAmount(item.taxableValueCents || item.totalCents - (item.taxCents || 0));
        const discount = item.discountCents ? formatAmount(item.discountCents) : '—';
        const batch = item.batchNumber || '';
        const expiry = item.expiryDate || '';

        let taxColumns = '';
        if (isInterState) {
            const igstRate = ((item.igstCents || 0) / Math.max(item.taxableValueCents || 1, 1) * 100).toFixed(1);
            taxColumns = `
                <td class="right">${igstRate}%</td>
                <td class="right">${formatAmount(item.igstCents || 0)}</td>`;
        } else {
            const cgstRate = ((item.cgstCents || 0) / Math.max(item.taxableValueCents || 1, 1) * 100).toFixed(1);
            const sgstRate = cgstRate;
            taxColumns = `
                <td class="right">${cgstRate}%</td>
                <td class="right">${formatAmount(item.cgstCents || 0)}</td>
                <td class="right">${sgstRate}%</td>
                <td class="right">${formatAmount(item.sgstCents || 0)}</td>`;
        }

        lineItemsHtml += `
            <tr>
                <td class="center">${slNo}</td>
                <td>${escapeHtml(item.name || '')}${batch ? `<br><small class="batch">Batch: ${escapeHtml(batch)}${expiry ? ` | Exp: ${expiry}` : ''}</small>` : ''}</td>
                <td class="center">${hsn}</td>
                <td class="right">${qty} ${unit}</td>
                <td class="right">${rate}</td>
                <td class="right">${discount}</td>
                <td class="right">${taxableValue}</td>
                ${taxColumns}
                <td class="right bold">${formatAmount(item.totalCents || 0)}</td>
            </tr>`;
    }

    // ── HSN-wise Tax Summary (mandatory for GST) ──
    const hsnMap = new Map<string, { hsn: string; taxableValue: number; cgst: number; sgst: number; igst: number; totalTax: number }>();
    for (const item of lineItems) {
        const hsn = item.hsnCode || 'N/A';
        const existing = hsnMap.get(hsn) || { hsn, taxableValue: 0, cgst: 0, sgst: 0, igst: 0, totalTax: 0 };
        existing.taxableValue += (item.taxableValueCents || 0);
        existing.cgst += (item.cgstCents || 0);
        existing.sgst += (item.sgstCents || 0);
        existing.igst += (item.igstCents || 0);
        existing.totalTax += (item.taxCents || 0);
        hsnMap.set(hsn, existing);
    }

    let hsnSummaryHtml = '';
    for (const [, hsnData] of hsnMap) {
        if (isInterState) {
            hsnSummaryHtml += `
                <tr>
                    <td>${hsnData.hsn}</td>
                    <td class="right">${formatAmount(hsnData.taxableValue)}</td>
                    <td class="right">${formatAmount(hsnData.igst)}</td>
                    <td class="right">${formatAmount(hsnData.totalTax)}</td>
                </tr>`;
        } else {
            hsnSummaryHtml += `
                <tr>
                    <td>${hsnData.hsn}</td>
                    <td class="right">${formatAmount(hsnData.taxableValue)}</td>
                    <td class="right">${formatAmount(hsnData.cgst)}</td>
                    <td class="right">${formatAmount(hsnData.sgst)}</td>
                    <td class="right">${formatAmount(hsnData.totalTax)}</td>
                </tr>`;
        }
    }

    // Tax summary header columns
    const hsnHeaders = isInterState
        ? '<th>HSN/SAC</th><th class="right">Taxable Value</th><th class="right">IGST</th><th class="right">Total Tax</th>'
        : '<th>HSN/SAC</th><th class="right">Taxable Value</th><th class="right">CGST</th><th class="right">SGST</th><th class="right">Total Tax</th>';

    // Line item table header columns
    const itemTaxHeaders = isInterState
        ? '<th class="right">IGST %</th><th class="right">IGST</th>'
        : '<th class="right">CGST %</th><th class="right">CGST</th><th class="right">SGST %</th><th class="right">SGST</th>';

    const itemTaxColspan = isInterState ? 10 : 11;

    // ── Amount in Words ──
    const totalRupees = Math.round(Number(invoice.totalCents || 0) / 100);
    const amountInWords = numberToWords(totalRupees);

    // ── Prescription Section (pharmacy only) ──
    const prescriptionHtml = prescriptionId ? `
        <div class="prescription-section">
            <h3>Prescription Details</h3>
            <table class="info-table">
                <tr><td class="label">Prescription ID:</td><td>${escapeHtml(prescriptionId)}</td></tr>
                ${doctorName ? `<tr><td class="label">Doctor:</td><td>${escapeHtml(doctorName)}</td></tr>` : ''}
                ${doctorRegNo ? `<tr><td class="label">Reg. No:</td><td>${escapeHtml(doctorRegNo)}</td></tr>` : ''}
            </table>
        </div>` : '';

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tax Invoice ${escapeHtml(invoice.invoiceNumber || '')}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', -apple-system, Arial, sans-serif;
            font-size: 12px;
            color: #1a1a2e;
            background: #fff;
            line-height: 1.5;
            max-width: 800px;
            margin: 0 auto;
            padding: 16px;
        }
        .invoice-container {
            border: 2px solid #16213e;
            padding: 0;
        }
        /* Header */
        .header {
            background: linear-gradient(135deg, #16213e 0%, #0f3460 100%);
            color: #fff;
            padding: 20px 24px;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
        }
        .header .biz-name {
            font-size: 22px;
            font-weight: 700;
            letter-spacing: 0.5px;
        }
        .header .biz-details {
            font-size: 11px;
            opacity: 0.9;
            margin-top: 4px;
        }
        .header .invoice-badge {
            text-align: right;
        }
        .header .invoice-badge .type {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 2px;
            opacity: 0.8;
        }
        .header .invoice-badge .number {
            font-size: 18px;
            font-weight: 700;
            margin-top: 4px;
        }
        .gstin-bar {
            background: #e94560;
            color: #fff;
            padding: 6px 24px;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 1px;
        }
        /* Info row */
        .info-row {
            display: flex;
            padding: 16px 24px;
            gap: 24px;
            border-bottom: 1px solid #e0e0e0;
        }
        .info-row .col { flex: 1; }
        .info-table { width: 100%; }
        .info-table td { padding: 2px 0; vertical-align: top; }
        .info-table .label {
            font-weight: 600;
            color: #555;
            width: 100px;
            font-size: 10px;
            text-transform: uppercase;
        }
        /* Items table */
        .items-section { padding: 0 24px 16px; }
        .items-section h3 {
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #0f3460;
            margin: 16px 0 8px;
            border-bottom: 2px solid #0f3460;
            padding-bottom: 4px;
        }
        table.items {
            width: 100%;
            border-collapse: collapse;
            font-size: 11px;
        }
        table.items th {
            background: #f4f6f9;
            color: #16213e;
            font-weight: 600;
            padding: 8px 6px;
            text-align: left;
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            border-bottom: 2px solid #16213e;
        }
        table.items td {
            padding: 7px 6px;
            border-bottom: 1px solid #eee;
            vertical-align: top;
        }
        table.items tr:hover { background: #fafbfd; }
        .right { text-align: right; }
        .center { text-align: center; }
        .bold { font-weight: 700; }
        .batch { color: #888; font-size: 9px; }
        /* Totals */
        .totals-section {
            padding: 0 24px 16px;
            display: flex;
            justify-content: flex-end;
        }
        .totals-table {
            width: 320px;
            font-size: 12px;
        }
        .totals-table td { padding: 5px 8px; }
        .totals-table .label { text-align: right; color: #555; font-weight: 500; }
        .totals-table .value { text-align: right; font-weight: 600; }
        .totals-table .grand-total {
            background: #16213e;
            color: #fff;
            font-size: 14px;
            font-weight: 700;
        }
        .totals-table .round-off { color: #888; font-size: 10px; }
        /* Words */
        .amount-words {
            padding: 8px 24px;
            background: #f9f9fb;
            border-top: 1px solid #e0e0e0;
            border-bottom: 1px solid #e0e0e0;
            font-size: 11px;
        }
        .amount-words strong { color: #16213e; }
        /* HSN Summary */
        .hsn-section { padding: 16px 24px; }
        .hsn-section h3 {
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #0f3460;
            margin-bottom: 6px;
        }
        table.hsn {
            width: 100%;
            border-collapse: collapse;
            font-size: 10px;
        }
        table.hsn th {
            background: #f4f6f9;
            padding: 6px;
            text-align: left;
            font-weight: 600;
            border-bottom: 1px solid #ccc;
        }
        table.hsn td { padding: 5px 6px; border-bottom: 1px solid #eee; }
        /* Prescription */
        .prescription-section {
            padding: 12px 24px;
            background: #fff8e1;
            border-top: 1px solid #ffe082;
        }
        .prescription-section h3 {
            font-size: 10px;
            text-transform: uppercase;
            color: #e65100;
            margin-bottom: 6px;
        }
        /* Footer */
        .footer {
            padding: 16px 24px;
            border-top: 1px solid #e0e0e0;
            display: flex;
            justify-content: space-between;
            font-size: 10px;
            color: #888;
        }
        .footer .terms { max-width: 50%; }
        .footer .terms p { margin-bottom: 2px; }
        .footer .signature {
            text-align: right;
            min-width: 200px;
        }
        .footer .signature .line {
            border-top: 1px solid #333;
            margin-top: 40px;
            padding-top: 4px;
            font-weight: 600;
            color: #333;
        }
        .payment-badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 3px;
            font-size: 10px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .status-paid { background: #c8e6c9; color: #2e7d32; }
        .status-draft { background: #fff9c4; color: #f57f17; }
        .status-finalized { background: #bbdefb; color: #1565c0; }
        .status-voided { background: #ffcdd2; color: #c62828; }
        .status-partial { background: #ffe0b2; color: #e65100; }
        @media print {
            body { padding: 0; }
            .invoice-container { border: none; }
        }
    </style>
</head>
<body>
<div class="invoice-container">
    <!-- Business Header -->
    <div class="header">
        <div>
            <div class="biz-name">${escapeHtml(bizName)}</div>
            <div class="biz-details">
                ${bizAddress ? escapeHtml(bizAddress) + '<br>' : ''}
                ${bizPhone ? 'Tel: ' + escapeHtml(bizPhone) : ''}
                ${bizState ? ' | State: ' + escapeHtml(bizState) : ''}
            </div>
        </div>
        <div class="invoice-badge">
            <div class="type">Tax Invoice</div>
            <div class="number">${escapeHtml(invoice.invoiceNumber || '')}</div>
        </div>
    </div>
    ${bizGstin ? `<div class="gstin-bar">GSTIN: ${escapeHtml(bizGstin)}</div>` : ''}

    <!-- Customer & Invoice Info -->
    <div class="info-row">
        <div class="col">
            <table class="info-table">
                <tr><td class="label">Bill To:</td><td><strong>${escapeHtml(custName)}</strong></td></tr>
                ${custPhone ? `<tr><td class="label">Phone:</td><td>${escapeHtml(custPhone)}</td></tr>` : ''}
                ${custGstin ? `<tr><td class="label">GSTIN:</td><td>${escapeHtml(custGstin)}</td></tr>` : ''}
            </table>
        </div>
        <div class="col">
            <table class="info-table">
                <tr><td class="label">Date:</td><td>${invoiceDate}${invoiceTime ? ' ' + invoiceTime : ''}</td></tr>
                <tr><td class="label">Payment:</td><td>${escapeHtml((invoice.paymentMode || 'cash').toUpperCase())}</td></tr>
                <tr>
                    <td class="label">Status:</td>
                    <td><span class="payment-badge status-${invoice.status || 'draft'}">${(invoice.status || 'draft').toUpperCase()}</span></td>
                </tr>
                ${isInterState ? '<tr><td class="label">Supply:</td><td>Inter-State (IGST)</td></tr>' : ''}
            </table>
        </div>
    </div>

    <!-- Line Items -->
    <div class="items-section">
        <h3>Items</h3>
        <table class="items">
            <thead>
                <tr>
                    <th class="center">#</th>
                    <th>Description</th>
                    <th class="center">HSN</th>
                    <th class="right">Qty</th>
                    <th class="right">Rate</th>
                    <th class="right">Disc.</th>
                    <th class="right">Taxable</th>
                    ${itemTaxHeaders}
                    <th class="right">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${lineItemsHtml || `<tr><td colspan="${itemTaxColspan}" class="center" style="padding:20px;color:#999;">No line items available</td></tr>`}
            </tbody>
        </table>
    </div>

    <!-- Totals -->
    <div class="totals-section">
        <table class="totals-table">
            <tr>
                <td class="label">Subtotal:</td>
                <td class="value">${formatAmount(invoice.subtotalCents || 0)}</td>
            </tr>
            ${invoice.discountCents ? `<tr>
                <td class="label">Discount:</td>
                <td class="value" style="color:#e94560;">-${formatAmount(invoice.discountCents)}</td>
            </tr>` : ''}
            ${isInterState ? `<tr>
                <td class="label">IGST:</td>
                <td class="value">${formatAmount(invoice.igstCents || invoice.taxCents || 0)}</td>
            </tr>` : `<tr>
                <td class="label">CGST:</td>
                <td class="value">${formatAmount(invoice.cgstCents || 0)}</td>
            </tr>
            <tr>
                <td class="label">SGST:</td>
                <td class="value">${formatAmount(invoice.sgstCents || 0)}</td>
            </tr>`}
            ${invoice.roundOffCents ? `<tr>
                <td class="label round-off">Round Off:</td>
                <td class="value round-off">${invoice.roundOffCents > 0 ? '+' : ''}${formatAmount(invoice.roundOffCents)}</td>
            </tr>` : ''}
            <tr>
                <td class="grand-total label" style="text-align:right;">Grand Total:</td>
                <td class="grand-total value">${formatAmount(invoice.totalCents || 0)}</td>
            </tr>
            ${(invoice.paidCents || 0) > 0 && (invoice.paidCents || 0) < (invoice.totalCents || 0) ? `
            <tr>
                <td class="label">Paid:</td>
                <td class="value">${formatAmount(invoice.paidCents)}</td>
            </tr>
            <tr>
                <td class="label" style="color:#e94560;font-weight:700;">Balance Due:</td>
                <td class="value" style="color:#e94560;font-weight:700;">${formatAmount(invoice.balanceCents || 0)}</td>
            </tr>` : ''}
        </table>
    </div>

    <!-- Amount in Words -->
    <div class="amount-words">
        <strong>Amount in Words:</strong> ${amountInWords} Rupees Only
    </div>

    <!-- HSN Summary (mandatory for GST invoices) -->
    ${lineItems.length > 0 ? `
    <div class="hsn-section">
        <h3>HSN/SAC Summary</h3>
        <table class="hsn">
            <thead><tr>${hsnHeaders}</tr></thead>
            <tbody>${hsnSummaryHtml}</tbody>
        </table>
    </div>` : ''}

    <!-- Prescription Details (pharmacy) -->
    ${prescriptionHtml}

    <!-- Footer -->
    <div class="footer">
        <div class="terms">
            <p><strong>Terms & Conditions:</strong></p>
            <p>1. Goods once sold will not be taken back.</p>
            <p>2. Subject to local jurisdiction.</p>
            <p>3. E. & O.E.</p>
            ${invoice.notes ? `<p style="margin-top:6px;"><strong>Notes:</strong> ${escapeHtml(invoice.notes)}</p>` : ''}
        </div>
        <div class="signature">
            <div class="line">Authorized Signatory</div>
            <div style="margin-top:2px;font-size:9px;color:#aaa;">This is a computer-generated invoice.</div>
        </div>
    </div>
</div>
</body>
</html>`;
}

/**
 * Simple Indian number-to-words conversion for amounts up to ₹99,99,99,999.
 */
function numberToWords(n: number): string {
    if (n === 0) return 'Zero';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
        'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    function twoDigits(num: number): string {
        if (num < 20) return ones[num];
        return tens[Math.floor(num / 10)] + (num % 10 ? ' ' + ones[num % 10] : '');
    }

    const parts: string[] = [];
    if (n >= 10000000) { parts.push(twoDigits(Math.floor(n / 10000000)) + ' Crore'); n %= 10000000; }
    if (n >= 100000) { parts.push(twoDigits(Math.floor(n / 100000)) + ' Lakh'); n %= 100000; }
    if (n >= 1000) { parts.push(twoDigits(Math.floor(n / 1000)) + ' Thousand'); n %= 1000; }
    if (n >= 100) { parts.push(ones[Math.floor(n / 100)] + ' Hundred'); n %= 100; }
    if (n > 0) { parts.push(twoDigits(n)); }
    return parts.join(' ');
}

/** HTML-escape to prevent XSS in rendered invoices */
function escapeHtml(str: string): string {
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function formatAmount(paise: number): string {
    const rupees = paise / 100;
    return `₹${rupees.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;
}

