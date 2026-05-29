// ============================================================================
// Lambda Handler — Reports (Sales, GSTR-1, GSTR-3B, P&L, CSV Export) (DynamoDB)
// ============================================================================
// AUDIT FIXES APPLIED:
//   M-4: GSTR-3B report
//   M-5: Profit & Loss report
//   M-6: Category-wise and salesperson-wise breakdowns in sales report
//   L-9: CSV export endpoint
//   GSTR-1 HSN summary now includes tax component breakdowns
//   TIMEZONE FIX: Report date ranges normalized to tenant timezone (IST)
// ============================================================================
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, getItem, putItem, queryAllItems, updateItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import { getCached } from '../utils/cache';
import { normalizeDateRangeForQuery, getMonthStartInTimezone, getDateInTimezone, isValidDateFormat } from '../utils/timezone';
import { internalHandler } from '../middleware/internal-auth';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

type ExportFormat = 'csv' | 'json' | 'excel';
type ExportType = 'sales' | 'gstr1' | 'gstr3b';
type ShareChannel = 'email' | 'whatsapp';
const DEFAULT_REPORT_TIMEZONE = 'Asia/Kolkata';
dayjs.extend(utc);
dayjs.extend(timezone);

function isValidTimezone(timeZone: string): boolean {
    try {
        Intl.DateTimeFormat('en-US', { timeZone }).format(new Date());
        return true;
    } catch {
        return false;
    }
}

async function resolveTenantTimezone(tenantId: string): Promise<string> {
    try {
        const tenantProfile = await getItem<Record<string, any>>(
            Keys.tenantPK(tenantId),
            Keys.tenantProfileSK(),
        );
        const configured = String(
            tenantProfile?.settings?.timezone ||
            tenantProfile?.timezone ||
            '',
        ).trim();
        if (configured && isValidTimezone(configured)) {
            return configured;
        }
    } catch (err: any) {
        logger.warn('Failed to resolve tenant timezone. Falling back to default.', {
            tenantId,
            error: err?.message,
        });
    }
    return DEFAULT_REPORT_TIMEZONE;
}

function escapeCsvCell(value: unknown): string {
    const raw = String(value ?? '');
    return `"${raw.replace(/"/g, '""')}"`;
}

function toCsv(headers: string[], rows: Array<Array<unknown>>): string {
    const headerLine = headers.map(escapeCsvCell).join(',');
    const body = rows.map((row) => row.map(escapeCsvCell).join(',')).join('\n');
    return `${headerLine}\n${body}${rows.length > 0 ? '\n' : ''}`;
}

function toSpreadsheetMl(sheetName: string, headers: string[], rows: Array<Array<unknown>>): string {
    const esc = (v: unknown) => String(v ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');

    const headerXml = headers.map(h => `<Cell><Data ss:Type="String">${esc(h)}</Data></Cell>`).join('');
    const rowXml = rows.map((r) => {
        const cells = r.map((c) => {
            const isNum = typeof c === 'number' || (typeof c === 'string' && c !== '' && !Number.isNaN(Number(c)));
            const type = isNum ? 'Number' : 'String';
            return `<Cell><Data ss:Type="${type}">${esc(c)}</Data></Cell>`;
        }).join('');
        return `<Row>${cells}</Row>`;
    }).join('');

    return `<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <Worksheet ss:Name="${esc(sheetName)}">
  <Table>
   <Row>${headerXml}</Row>
   ${rowXml}
  </Table>
 </Worksheet>
</Workbook>`;
}

function buildGstr3bSummaryRows(invoiceItems: Record<string, any>[]) {
    const interStateInvoices = invoiceItems.filter(i => i.isInterState === true);
    const intraStateInvoices = invoiceItems.filter(i => i.isInterState !== true);

    const outwardTaxableValue = invoiceItems.reduce((s, i) => s + (Number(i.subtotalCents) || 0), 0);
    const interIgst = interStateInvoices.reduce((s, i) => s + (Number(i.igstCents) || 0), 0);
    const intraCgst = intraStateInvoices.reduce((s, i) => s + (Number(i.cgstCents) || 0), 0);
    const intraSgst = intraStateInvoices.reduce((s, i) => s + (Number(i.sgstCents) || 0), 0);

    return {
        invoiceCount: invoiceItems.length,
        section31: {
            outward_taxable: {
                total_taxable_value_cents: outwardTaxableValue,
                igst_cents: interIgst,
                cgst_cents: intraCgst,
                sgst_cents: intraSgst,
            },
            zero_rated: { total_taxable_value_cents: 0, igst_cents: 0 },
            nil_rated_exempted: { total_taxable_value_cents: 0 },
            non_gst: { total_taxable_value_cents: 0 },
        },
        outputTax: { igst_cents: interIgst, cgst_cents: intraCgst, sgst_cents: intraSgst },
        section4Itc: { igst_cents: 0, cgst_cents: 0, sgst_cents: 0 },
        netTaxPayable: { igst_cents: interIgst, cgst_cents: intraCgst, sgst_cents: intraSgst },
    };
}

function parseJsonBody(event: Record<string, any>): Record<string, any> {
    if (!event.body) return {};
    try {
        return JSON.parse(event.body);
    } catch {
        throw new Error('INVALID_JSON');
    }
}

export type BuildReportExportResult =
    | { ok: true; contentType: string; contentDisposition: string; body: string }
    | { ok: false; error: string };

/**
 * Build export file (same as GET /reports/export) for workers and API.
 */
export async function buildReportExportPayload(input: {
    tenantId: string;
    fromDate: string;
    toDate: string;
    exportType: ExportType;
    exportFormat: ExportFormat;
}): Promise<BuildReportExportResult> {
    const { tenantId, fromDate, toDate, exportType, exportFormat } = input;
    if (!['sales', 'gstr1', 'gstr3b'].includes(exportType)) {
        return { ok: false, error: 'Invalid type. Supported: sales, gstr1, gstr3b' };
    }
    if (!['csv', 'json', 'excel'].includes(exportFormat)) {
        return { ok: false, error: 'Invalid format. Supported: csv, json, excel' };
    }
    if (!isValidDateFormat(fromDate) || !isValidDateFormat(toDate)) {
        return { ok: false, error: 'Invalid date format. Use YYYY-MM-DD' };
    }

    const tenantTimezone = await resolveTenantTimezone(tenantId);
    const pk = Keys.tenantPK(tenantId);
    const boundaries = normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
    const fromISO = boundaries.fromUTC;
    const toISO = boundaries.toUTC;

    const invoiceItems = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
        filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR (#s <> :voided AND #s <> :draft))',
        expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false, ':voided': 'voided', ':draft': 'draft' },
        expressionAttributeNames: { '#s': 'status' },
        maxPages: 10,
    });

    let headers: string[] = [];
    let rows: Array<Array<unknown>> = [];
    let jsonPayload: Record<string, unknown> = {};

    if (exportType === 'sales') {
        headers = ['Invoice Number', 'Date', 'Customer', 'Subtotal (₹)', 'Tax (₹)', 'Discount (₹)', 'Total (₹)', 'Paid (₹)', 'Balance (₹)', 'Payment Mode', 'Status'];
        rows = invoiceItems.map((inv) => [
            inv.invoiceNumber || '',
            dayjs(inv.createdAt || '').tz(tenantTimezone).format('YYYY-MM-DD'),
            inv.customerName || 'Walk-in',
            ((Number(inv.subtotalCents) || 0) / 100).toFixed(2),
            ((Number(inv.taxCents) || 0) / 100).toFixed(2),
            ((Number(inv.discountCents) || 0) / 100).toFixed(2),
            ((Number(inv.totalCents) || 0) / 100).toFixed(2),
            ((Number(inv.paidCents) || 0) / 100).toFixed(2),
            ((Number(inv.balanceCents) || 0) / 100).toFixed(2),
            inv.paymentMode || 'cash',
            inv.status || '',
        ]);
        jsonPayload = {
            report: 'sales',
            period: { from: fromDate, to: toDate },
            count: rows.length,
            rows,
        };
    } else if (exportType === 'gstr1') {
        const filtered = invoiceItems.filter(i => i.status !== 'draft');
        headers = ['Invoice Number', 'Date', 'Customer', 'GSTIN', 'Subtotal (₹)', 'CGST (₹)', 'SGST (₹)', 'IGST (₹)', 'Total (₹)'];
        rows = filtered.map((inv) => [
            inv.invoiceNumber || '',
            dayjs(inv.createdAt || '').tz(tenantTimezone).format('YYYY-MM-DD'),
            inv.customerName || '',
            inv.metadata?.customerGstin || '',
            ((Number(inv.subtotalCents) || 0) / 100).toFixed(2),
            ((Number(inv.cgstCents) || 0) / 100).toFixed(2),
            ((Number(inv.sgstCents) || 0) / 100).toFixed(2),
            ((Number(inv.igstCents) || 0) / 100).toFixed(2),
            ((Number(inv.totalCents) || 0) / 100).toFixed(2),
        ]);
        jsonPayload = {
            report: 'gstr1',
            period: { from: fromDate, to: toDate },
            count: rows.length,
            rows,
        };
    } else {
        const filtered = invoiceItems.filter(i => i.status !== 'draft' && i.status !== 'voided');
        const g3b = buildGstr3bSummaryRows(filtered);
        headers = ['Section', 'Taxable Value (₹)', 'IGST (₹)', 'CGST (₹)', 'SGST (₹)'];
        rows = [
            ['3.1 Outward Taxable', (g3b.section31.outward_taxable.total_taxable_value_cents / 100).toFixed(2), (g3b.section31.outward_taxable.igst_cents / 100).toFixed(2), (g3b.section31.outward_taxable.cgst_cents / 100).toFixed(2), (g3b.section31.outward_taxable.sgst_cents / 100).toFixed(2)],
            ['4 ITC', '0.00', '0.00', '0.00', '0.00'],
            ['5 Net Tax Payable', '', (g3b.netTaxPayable.igst_cents / 100).toFixed(2), (g3b.netTaxPayable.cgst_cents / 100).toFixed(2), (g3b.netTaxPayable.sgst_cents / 100).toFixed(2)],
        ];
        jsonPayload = {
            report: 'gstr3b',
            period: { from: fromDate, to: toDate },
            invoiceCount: g3b.invoiceCount,
            section_3_1: g3b.section31,
            section_4_itc: g3b.section4Itc,
            output_tax: g3b.outputTax,
            net_tax_payable: g3b.netTaxPayable,
        };
    }

    if (exportFormat === 'json') {
        return {
            ok: true,
            contentType: 'application/json; charset=utf-8',
            contentDisposition: `attachment; filename="${exportType}_report_${fromDate}_to_${toDate}.json"`,
            body: JSON.stringify(jsonPayload),
        };
    }

    if (exportFormat === 'excel') {
        const xml = toSpreadsheetMl(exportType.toUpperCase(), headers, rows);
        return {
            ok: true,
            contentType: 'application/vnd.ms-excel; charset=utf-8',
            contentDisposition: `attachment; filename="${exportType}_report_${fromDate}_to_${toDate}.xls"`,
            body: xml,
        };
    }

    const csvContent = toCsv(headers, rows);
    return {
        ok: true,
        contentType: 'text/csv; charset=utf-8',
        contentDisposition: `attachment; filename="${exportType}_report_${fromDate}_to_${toDate}.csv"`,
        body: csvContent,
    };
}

export type ApplyReportDispatchOutcomeResult =
    | { ok: true; data: Record<string, unknown> }
    | { ok: false; statusCode: number; message: string };

/**
 * Core lifecycle update for a dispatch job (+ audit event). Used by HTTP mark-attempt and scheduled worker.
 */
export async function applyReportDispatchOutcome(
    tenantId: string,
    dispatchId: string,
    input: {
        outcome: 'sent' | 'failed';
        increment?: number;
        errorMessage?: string;
        nextRetryAt?: string;
        requestSource: string;
    },
): Promise<ApplyReportDispatchOutcomeResult> {
    const outcome = input.outcome;
    const increment = Math.max(1, Math.min(5, Number(input.increment) || 1));
    const pk = Keys.tenantPK(tenantId);
    const sk = `REPORTDISPATCH#${dispatchId}`;
    const existing = await getItem<Record<string, any>>(pk, sk);
    if (!existing) {
        return { ok: false, statusCode: 404, message: 'Report dispatch' };
    }

    const currentStatus = String(existing.status || '').toLowerCase();
    if (['cancelled', 'sent'].includes(currentStatus)) {
        return { ok: false, statusCode: 400, message: `Dispatch cannot be updated from status=${existing.status}` };
    }

    const nowIso = new Date().toISOString();
    const currentAttempt = Math.max(0, Number(existing.attemptCount) || 0);
    const maxAttempts = Math.max(1, Number(existing.maxAttempts) || 3);
    const nextAttempt = currentAttempt + increment;

    let nextStatus = String(existing.status || 'queued').toLowerCase();
    let lastError: string | null = null;
    let nextRetryAt: string | null = null;
    let sentAt: string | null = null;

    if (outcome === 'sent') {
        nextStatus = 'sent';
        sentAt = nowIso;
    } else {
        const errMessage = String(input.errorMessage || 'DISPATCH_FAILED');
        lastError = errMessage;
        if (nextAttempt >= maxAttempts) {
            nextStatus = 'failed';
            nextRetryAt = null;
        } else {
            nextStatus = 'queued';
            const requestedRetry = String(input.nextRetryAt || '').trim();
            if (requestedRetry) {
                const retryMoment = dayjs(requestedRetry);
                nextRetryAt = retryMoment.isValid()
                    ? retryMoment.toISOString()
                    : dayjs().add(15, 'minute').toISOString();
            } else {
                nextRetryAt = dayjs().add(15, 'minute').toISOString();
            }
        }
    }

    const updated = await updateItem(pk, sk, {
        updateExpression: 'SET #status = :status, updatedAt = :updatedAt, attemptCount = :attemptCount, maxAttempts = :maxAttempts, lastError = :lastError, nextRetryAt = :nextRetryAt, sentAt = :sentAt, updatedBy = :updatedBy',
        expressionAttributeNames: { '#status': 'status' },
        expressionAttributeValues: {
            ':status': nextStatus,
            ':updatedAt': nowIso,
            ':attemptCount': nextAttempt,
            ':maxAttempts': maxAttempts,
            ':lastError': lastError,
            ':nextRetryAt': nextRetryAt,
            ':sentAt': sentAt,
            ':updatedBy': `internal:${input.requestSource || 'worker'}`,
        },
    });

    const eventId = `rde_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    await putItem({
        PK: pk,
        SK: `REPORTDISPATCHEVENT#${dispatchId}#${nowIso}#${eventId}`,
        GSI1PK: Keys.entityGSI1PK('REPORTDISPATCHEVENT'),
        GSI1SK: nowIso,
        entityType: 'REPORTDISPATCHEVENT',
        id: eventId,
        dispatchId,
        tenantId,
        source: input.requestSource || 'worker',
        outcome,
        statusAfter: updated?.status || nextStatus,
        attemptCount: updated?.attemptCount ?? nextAttempt,
        maxAttempts: updated?.maxAttempts ?? maxAttempts,
        lastError: updated?.lastError ?? lastError,
        nextRetryAt: updated?.nextRetryAt ?? nextRetryAt,
        createdAt: nowIso,
    } as Record<string, any>);

    return {
        ok: true,
        data: {
            dispatchId,
            outcome,
            status: updated?.status || nextStatus,
            attemptCount: updated?.attemptCount ?? nextAttempt,
            maxAttempts: updated?.maxAttempts ?? maxAttempts,
            lastError: updated?.lastError ?? lastError,
            nextRetryAt: updated?.nextRetryAt ?? nextRetryAt,
        },
    };
}

/**
 * Fetch line items for multiple invoices with bounded concurrency.
 * Instead of N sequential queries (N+1 pattern), batches 10 at a time.
 */
async function batchFetchLineItems(
    invoiceIds: string[],
    batchSize = 10,
): Promise<Record<string, any>[]> {
    const allLineItems: Record<string, any>[] = [];
    for (let i = 0; i < invoiceIds.length; i += batchSize) {
        const batch = invoiceIds.slice(i, i + batchSize);
        const results = await Promise.all(
            batch.map(id => queryAllItems<Record<string, any>>(
                Keys.invoiceLineItemPK(id), 'LINEITEM#', { maxPages: 3 }
            ))
        );
        for (const items of results) {
            allLineItems.push(...items);
        }
    }
    return allLineItems;
}

/**
 * GET /reports/sales?from=2026-01-01&to=2026-01-31&groupBy=day
 * M-6: Now includes category-wise and salesperson-wise breakdowns
 * TIMEZONE FIX: Date ranges normalized to tenant timezone (default IST)
 */
export const salesReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        
        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        
        // TIMEZONE FIX: Use tenant timezone for date defaults
        const fromDate = params.from || getMonthStartInTimezone(tenantTimezone);
        const toDate = params.to || getDateInTimezone(tenantTimezone);
        const groupBy = params.groupBy || 'day';
        const compareWithPrevious = String(params.compareWithPrevious || '').toLowerCase() === 'true';
        const maxPages = Math.max(1, Math.min(25, Number(params.maxPages) || 10));
        const lineItemInvoiceCap = Math.max(1, Math.min(2000, Number(params.lineItemInvoiceCap) || 500));
        const pk = Keys.tenantPK(auth.tenantId);

        // Validate date format
        if (!isValidDateFormat(fromDate) || !isValidDateFormat(toDate)) {
            return response.badRequest('Invalid date format. Use YYYY-MM-DD');
        }

        const cacheKey = `report:sales:${auth.tenantId}:${fromDate}:${toDate}:${groupBy}:${compareWithPrevious}`;
        const data = await getCached(cacheKey, 300, async () => {
            // TIMEZONE FIX: Normalize date range from tenant timezone to UTC for DynamoDB query
            const boundaries = normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
            const fromISO = boundaries.fromUTC;
            const toISO = boundaries.toUTC;

            // Fetch ALL invoices in range (auto-paginated)
            const items = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR (#s <> :voided AND #s <> :draft))',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false, ':voided': 'voided', ':draft': 'draft' },
                expressionAttributeNames: { '#s': 'status' },
                maxPages, // Tunable page cap for large workloads
            });

            // Build timeseries
            const periodMap = new Map<string, { billCount: number; totalCents: number; paidCents: number; discountCents: number; taxCents: number }>();
            for (const inv of items) {
                const rawDate = inv.createdAt || inv.updatedAt || inv.invoiceDate || '';
                const local = dayjs(rawDate).tz(tenantTimezone);
                if (!local.isValid()) {
                    continue;
                }
                let period: string;
                if (groupBy === 'month') {
                    period = local.startOf('month').format('YYYY-MM-DD');
                } else if (groupBy === 'week') {
                    const mondayOffset = (local.day() + 6) % 7; // Monday-start week bucket
                    period = local.subtract(mondayOffset, 'day').format('YYYY-MM-DD');
                } else {
                    period = local.format('YYYY-MM-DD');
                }
                const existing = periodMap.get(period) || { billCount: 0, totalCents: 0, paidCents: 0, discountCents: 0, taxCents: 0 };
                existing.billCount++;
                existing.totalCents += Number(inv.totalCents) || 0;
                existing.paidCents += Number(inv.paidCents) || 0;
                existing.discountCents += Number(inv.discountCents) || 0;
                existing.taxCents += Number(inv.taxCents) || 0;
                periodMap.set(period, existing);
            }

            const timeseries = Array.from(periodMap.entries())
                .map(([period, data]) => ({ period, ...data }))
                .sort((a, b) => a.period.localeCompare(b.period));

            const summarizeInvoices = (invoiceRows: Record<string, any>[]) => ({
                total_bills: invoiceRows.length,
                total_revenue_cents: invoiceRows.reduce((s, i) => s + (Number(i.totalCents) || 0), 0),
                total_collected_cents: invoiceRows.reduce((s, i) => s + (Number(i.paidCents) || 0), 0),
                total_outstanding_cents: invoiceRows.reduce((s, i) => s + (Number(i.balanceCents) || 0), 0),
                total_discount_cents: invoiceRows.reduce((s, i) => s + (Number(i.discountCents) || 0), 0),
                total_tax_cents: invoiceRows.reduce((s, i) => s + (Number(i.taxCents) || 0), 0),
                total_cgst_cents: invoiceRows.reduce((s, i) => s + (Number(i.cgstCents) || 0), 0),
                total_sgst_cents: invoiceRows.reduce((s, i) => s + (Number(i.sgstCents) || 0), 0),
                total_igst_cents: invoiceRows.reduce((s, i) => s + (Number(i.igstCents) || 0), 0),
                avg_bill_cents: invoiceRows.length > 0
                    ? Math.round(invoiceRows.reduce((s, i) => s + (Number(i.totalCents) || 0), 0) / invoiceRows.length)
                    : 0,
            });
            const summary = summarizeInvoices(items);

            // Top products: batch-fetch line items with bounded concurrency
            const invoiceIds = items.map(inv => inv.id).filter(Boolean);
            const lineItemInvoiceIds = invoiceIds.slice(0, lineItemInvoiceCap);
            const allLineItems = await batchFetchLineItems(lineItemInvoiceIds);

            const productMap = new Map<string, { name: string; totalQty: number; totalRevenueCents: number; billCount: number }>();
            const invoiceProductSets = new Map<string, Set<string>>();

            // M-6: Category-wise breakdown
            const categoryMap = new Map<string, { categoryName: string; totalQty: number; totalRevenueCents: number; productCount: number }>();
            const categoryProducts = new Map<string, Set<string>>();

            for (const li of allLineItems) {
                const name = li.name || 'Unknown';
                const existing = productMap.get(name) || { name, totalQty: 0, totalRevenueCents: 0, billCount: 0 };
                existing.totalQty += Number(li.quantity) || 0;
                existing.totalRevenueCents += Number(li.totalCents) || 0;

                const txnId = li.transactionId || '';
                if (!invoiceProductSets.has(txnId)) invoiceProductSets.set(txnId, new Set());
                const seen = invoiceProductSets.get(txnId)!;
                if (!seen.has(name)) { existing.billCount++; seen.add(name); }

                productMap.set(name, existing);

                // Category aggregation
                const category = li.category || 'Uncategorized';
                const catData = categoryMap.get(category) || { categoryName: category, totalQty: 0, totalRevenueCents: 0, productCount: 0 };
                catData.totalQty += Number(li.quantity) || 0;
                catData.totalRevenueCents += Number(li.totalCents) || 0;
                if (!categoryProducts.has(category)) categoryProducts.set(category, new Set());
                categoryProducts.get(category)!.add(name);
                catData.productCount = categoryProducts.get(category)!.size;
                categoryMap.set(category, catData);
            }
            const topProducts = Array.from(productMap.values())
                .sort((a, b) => b.totalRevenueCents - a.totalRevenueCents)
                .slice(0, 10);

            // M-6: Category breakdown
            const categoryBreakdown = Array.from(categoryMap.values())
                .sort((a, b) => b.totalRevenueCents - a.totalRevenueCents);

            // M-6: Salesperson-wise breakdown
            const staffMap = new Map<string, { staffId: string; staffName: string; billCount: number; totalRevenueCents: number }>();
            for (const inv of items) {
                const staffId = inv.createdBy || 'unknown';
                const existing = staffMap.get(staffId) || { staffId, staffName: inv.staffName || staffId, billCount: 0, totalRevenueCents: 0 };
                existing.billCount++;
                existing.totalRevenueCents += Number(inv.totalCents) || 0;
                staffMap.set(staffId, existing);
            }
            const salespersonBreakdown = Array.from(staffMap.values())
                .sort((a, b) => b.totalRevenueCents - a.totalRevenueCents);

            // Payment mode breakdown
            const modeMap = new Map<string, { count: number; totalCents: number }>();
            for (const inv of items) {
                const mode = inv.paymentMode || 'cash';
                const existing = modeMap.get(mode) || { count: 0, totalCents: 0 };
                existing.count++;
                existing.totalCents += Number(inv.totalCents) || 0;
                modeMap.set(mode, existing);
            }
            const paymentModes = Array.from(modeMap.entries())
                .map(([mode, data]) => ({ mode, ...data }))
                .sort((a, b) => b.totalCents - a.totalCents);

            let previousPeriod: Record<string, any> | null = null;
            if (compareWithPrevious) {
                const fromLocal = dayjs(fromDate).tz(tenantTimezone).startOf('day');
                const toLocal = dayjs(toDate).tz(tenantTimezone).startOf('day');
                const rangeDays = Math.max(1, toLocal.diff(fromLocal, 'day') + 1);
                const prevToLocal = fromLocal.subtract(1, 'day');
                const prevFromLocal = prevToLocal.subtract(rangeDays - 1, 'day');

                const prevFromDate = prevFromLocal.format('YYYY-MM-DD');
                const prevToDate = prevToLocal.format('YYYY-MM-DD');
                const prevBoundaries = normalizeDateRangeForQuery(prevFromDate, prevToDate, tenantTimezone);
                const previousItems = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                    filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR (#s <> :voided AND #s <> :draft))',
                    expressionAttributeValues: { ':from': prevBoundaries.fromUTC, ':to': prevBoundaries.toUTC, ':false': false, ':voided': 'voided', ':draft': 'draft' },
                    expressionAttributeNames: { '#s': 'status' },
                    maxPages: 10,
                });
                const previousSummary = summarizeInvoices(previousItems);
                previousPeriod = {
                    period: {
                        from: prevFromDate,
                        to: prevToDate,
                        timezone: tenantTimezone,
                        fromUTC: prevBoundaries.fromUTC,
                        toUTC: prevBoundaries.toUTC,
                    },
                    summary: previousSummary,
                    delta: {
                        total_revenue_cents: summary.total_revenue_cents - previousSummary.total_revenue_cents,
                        total_bills: summary.total_bills - previousSummary.total_bills,
                        total_collected_cents: summary.total_collected_cents - previousSummary.total_collected_cents,
                    },
                };
            }

            return {
                period: { 
                    from: fromDate, 
                    to: toDate, 
                    groupBy,
                    timezone: tenantTimezone,
                    fromUTC: boundaries.fromUTC,
                    toUTC: boundaries.toUTC
                }, 
                summary, 
                timeseries, 
                topProducts, 
                paymentModes, 
                categoryBreakdown, 
                salespersonBreakdown,
                previous_period: previousPeriod,
                performance: {
                    max_pages_used: maxPages,
                    invoice_count_analyzed: items.length,
                    line_item_invoice_sample_size: lineItemInvoiceIds.length,
                    line_item_sample_capped: invoiceIds.length > lineItemInvoiceIds.length,
                    line_items_analyzed: allLineItems.length,
                },
            };
        });

        return response.success(data);
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * GET /reports/gstr1?from=2026-01-01&to=2026-03-31
 * FIXED: HSN summary now includes per-HSN CGST/SGST/IGST breakdown
 * TIMEZONE FIX: Date ranges normalized to tenant timezone (default IST)
 */
export const gstr1Report = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        
        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        
        // TIMEZONE FIX: Use tenant timezone for date defaults
        const fromDate = params.from || getMonthStartInTimezone(tenantTimezone);
        const toDate = params.to || getDateInTimezone(tenantTimezone);
        const pk = Keys.tenantPK(auth.tenantId);

        // Validate date format
        if (!isValidDateFormat(fromDate) || !isValidDateFormat(toDate)) {
            return response.badRequest('Invalid date format. Use YYYY-MM-DD');
        }

        const cacheKey = `report:gstr1:${auth.tenantId}:${fromDate}:${toDate}`;
        const data = await getCached(cacheKey, 300, async () => {
            // TIMEZONE FIX: Normalize date range from tenant timezone to UTC for DynamoDB query
            const boundaries = normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
            const fromISO = boundaries.fromUTC;
            const toISO = boundaries.toUTC;

            // Auto-paginated invoice fetch
            const allInvoiceItems = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR #s <> :draft)',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false, ':draft': 'draft' },
                expressionAttributeNames: { '#s': 'status' },
                maxPages: 10,
            });

            const invoiceItems = allInvoiceItems.filter(i => i.status !== 'voided');

            // B2B: invoices with customer GSTIN
            const b2b = invoiceItems
                .filter(i => i.metadata?.customerGstin)
                .map(i => ({
                    invoiceNumber: i.invoiceNumber, customerName: i.customerName,
                    customerGstin: i.metadata?.customerGstin,
                    invoiceDate: i.createdAt, subtotalCents: i.subtotalCents,
                    cgstCents: i.cgstCents || 0, sgstCents: i.sgstCents || 0,
                    igstCents: i.igstCents || 0, totalCents: i.totalCents, status: i.status,
                }));

            // CDNR: Credit/Debit Notes explicitly mapped from voided or returned B2B invoices
            const cdnrInvoices = allInvoiceItems.filter(i => 
                (i.status === 'voided' || i.returnInvoiceId) && i.metadata?.customerGstin
            );
            
            const cdnr = cdnrInvoices.map(i => {
                const rtNum = i.returnInvoiceId || `CN-${i.invoiceNumber}`;
                const dt = i.updatedAt || i.createdAt;
                return {
                    ctin: i.metadata?.customerGstin,
                    nt: [{
                        ntNum: rtNum,
                        ntdt: dt,
                        ntty: 'C',
                        rsn: 'Sales Return',
                        val: (Number(i.totalCents) || 0) / 100,
                        itms: [{
                           txval: (Number(i.subtotalCents) || 0) / 100,
                           igst: (Number(i.igstCents) || 0) / 100,
                           cgst: (Number(i.cgstCents) || 0) / 100,
                           sgst: (Number(i.sgstCents) || 0) / 100
                        }]
                    }]
                };
            });

            // B2C summary
            const b2cItems = invoiceItems.filter(i => !i.metadata?.customerGstin);
            const b2cSummary = {
                invoice_count: b2cItems.length,
                taxable_value_cents: b2cItems.reduce((s, i) => s + (Number(i.subtotalCents) || 0), 0),
                cgst_cents: b2cItems.reduce((s, i) => s + (Number(i.cgstCents) || 0), 0),
                sgst_cents: b2cItems.reduce((s, i) => s + (Number(i.sgstCents) || 0), 0),
                igst_cents: b2cItems.reduce((s, i) => s + (Number(i.igstCents) || 0), 0),
                total_cents: b2cItems.reduce((s, i) => s + (Number(i.totalCents) || 0), 0),
            };

            // FIXED: HSN-wise summary with per-HSN tax component breakdown
            const invoiceIds = invoiceItems.map(inv => inv.id).filter(Boolean);
            const allLineItems = await batchFetchLineItems(invoiceIds);

            const hsnMap = new Map<string, {
                totalQty: number; taxableValueCents: number; totalValueCents: number;
                cgstCents: number; sgstCents: number; igstCents: number;
                invoiceCount: number; unit?: string; taxRate?: number; taxCategory?: string;
            }>();
            for (const li of allLineItems) {
                const hsn = li.hsnCode || 'N/A';
                const existing = hsnMap.get(hsn) || {
                    totalQty: 0, taxableValueCents: 0, totalValueCents: 0,
                    cgstCents: 0, sgstCents: 0, igstCents: 0, invoiceCount: 0,
                };
                existing.totalQty += Number(li.quantity) || 0;
                existing.taxableValueCents += Number(li.taxableValueCents) || 0;
                existing.totalValueCents += Number(li.totalCents) || 0;
                existing.cgstCents += Number(li.cgstCents) || 0;
                existing.sgstCents += Number(li.sgstCents) || 0;
                existing.igstCents += Number(li.igstCents) || 0;
                existing.invoiceCount++;
                // GST-3.3: Preserve unit, taxRate, and taxCategory for HSN summary enrichment
                if (li.unit) existing.unit = li.unit;
                if (li.taxRate !== undefined) existing.taxRate = Number(li.taxRate);
                if (li.taxCategory) existing.taxCategory = li.taxCategory;
                hsnMap.set(hsn, existing);
            }

            const hsnSummary = Array.from(hsnMap.entries())
                .map(([hsnCode, data]) => ({
                    hsn_code: hsnCode,
                    ...data,
                    // GST-3.3: Include tax_rate percentage for PDF rendering
                    tax_rate_percent: data.taxRate !== undefined ? data.taxRate : null,
                }))
                .sort((a, b) => b.totalValueCents - a.totalValueCents);

            // AUDIT FIX GST-3.1: Nil-rated and exempt supply segregation
            // GSTR-1 requires separate columns for nil-rated, exempt, and non-GST supplies.
            // Lookup taxCategory from line items to segregate supplies.
            let nilRatedValueCents = 0;
            let exemptValueCents = 0;
            let nonGstValueCents = 0;

            for (const li of allLineItems) {
                const taxCategory = li.taxCategory || 'standard';
                const liValue = Number(li.taxableValueCents) || Number(li.totalCents) || 0;

                if (taxCategory === 'nil_rated') {
                    nilRatedValueCents += liValue;
                } else if (taxCategory === 'exempt') {
                    exemptValueCents += liValue;
                } else if (taxCategory === 'zero_rated' && !li.isExport) {
                    nonGstValueCents += liValue;
                }
            }

            const nilAndExempt = {
                nil_rated_intra_state_cents: nilRatedValueCents,
                exempt_intra_state_cents: exemptValueCents,
                non_gst_supply_cents: nonGstValueCents,
                total_nil_exempt_cents: nilRatedValueCents + exemptValueCents + nonGstValueCents,
            };

            return {
                period: { from: fromDate, to: toDate },
                b2b, b2c_summary: b2cSummary, hsn_summary: hsnSummary, cdnr,
                nil_and_exempt: nilAndExempt,
            };
        });

        return response.success(data);
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * M-4: GET /reports/gstr3b?from=2026-01-01&to=2026-03-31
 * GSTR-3B summary — monthly return with tax liability and ITC.
 */
export const gstr3bReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        const fromDate = params.from || getMonthStartInTimezone(tenantTimezone);
        const toDate = params.to || getDateInTimezone(tenantTimezone);
        const pk = Keys.tenantPK(auth.tenantId);

        const cacheKey = `report:gstr3b:${auth.tenantId}:${fromDate}:${toDate}`;
        const data = await getCached(cacheKey, 300, async () => {
            const boundaries = normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
            const fromISO = boundaries.fromUTC;
            const toISO = boundaries.toUTC;

            const invoiceItems = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR (#s <> :voided AND #s <> :draft))',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false, ':voided': 'voided', ':draft': 'draft' },
                expressionAttributeNames: { '#s': 'status' },
                maxPages: 10,
            });

            // 3.1 — Outward supplies, segmented by line tax category
            const interStateInvoices = invoiceItems.filter(i => i.isInterState === true);
            const invoiceIds = invoiceItems.map(inv => inv.id).filter(Boolean);
            const allLineItems = await batchFetchLineItems(invoiceIds);

            const section31Agg = {
                outwardTaxableValueCents: 0,
                outwardIgstCents: 0,
                outwardCgstCents: 0,
                outwardSgstCents: 0,
                zeroRatedValueCents: 0,
                zeroRatedIgstCents: 0,
                nilExemptValueCents: 0,
                nonGstValueCents: 0,
            };

            for (const li of allLineItems) {
                const taxCategory = String(li.taxCategory || 'standard');
                const taxableValue = Number(li.taxableValueCents) || Number(li.totalCents) || 0;
                const igstCents = Number(li.igstCents) || 0;
                const cgstCents = Number(li.cgstCents) || 0;
                const sgstCents = Number(li.sgstCents) || 0;
                const isExport = Boolean(li.isExport);

                if (taxCategory === 'non_gst') {
                    section31Agg.nonGstValueCents += taxableValue;
                    continue;
                }
                if (taxCategory === 'nil_rated' || taxCategory === 'exempt') {
                    section31Agg.nilExemptValueCents += taxableValue;
                    continue;
                }
                if (taxCategory === 'zero_rated' || isExport) {
                    section31Agg.zeroRatedValueCents += taxableValue;
                    section31Agg.zeroRatedIgstCents += igstCents;
                    continue;
                }

                section31Agg.outwardTaxableValueCents += taxableValue;
                section31Agg.outwardIgstCents += igstCents;
                section31Agg.outwardCgstCents += cgstCents;
                section31Agg.outwardSgstCents += sgstCents;
            }

            // Fallback: if line-items are unavailable, keep header totals.
            if (allLineItems.length === 0) {
                const intraStateInvoices = invoiceItems.filter(i => i.isInterState !== true);
                section31Agg.outwardTaxableValueCents = invoiceItems.reduce((s, i) => s + (Number(i.subtotalCents) || 0), 0);
                section31Agg.outwardIgstCents = interStateInvoices.reduce((s, i) => s + (Number(i.igstCents) || 0), 0);
                section31Agg.outwardCgstCents = intraStateInvoices.reduce((s, i) => s + (Number(i.cgstCents) || 0), 0);
                section31Agg.outwardSgstCents = intraStateInvoices.reduce((s, i) => s + (Number(i.sgstCents) || 0), 0);
            }

            const section31 = {
                outward_taxable: {
                    total_taxable_value_cents: section31Agg.outwardTaxableValueCents,
                    igst_cents: section31Agg.outwardIgstCents,
                    cgst_cents: section31Agg.outwardCgstCents,
                    sgst_cents: section31Agg.outwardSgstCents,
                },
                zero_rated: {
                    total_taxable_value_cents: section31Agg.zeroRatedValueCents,
                    igst_cents: section31Agg.zeroRatedIgstCents,
                },
                nil_rated_exempted: {
                    total_taxable_value_cents: section31Agg.nilExemptValueCents,
                },
                non_gst: {
                    total_taxable_value_cents: section31Agg.nonGstValueCents,
                },
            };

            // Credit-note netting for output liability (issued returns/refunds).
            const creditNotes = await queryAllItems<Record<string, any>>(pk, 'CREDITNOTE#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false },
                maxPages: 10,
            });
            const creditTaxAdjustments = {
                taxable_value_cents: 0,
                igst_cents: 0,
                cgst_cents: 0,
                sgst_cents: 0,
                credit_note_count: creditNotes.length,
            };
            if (creditNotes.length > 0) {
                const originalInvoiceIds = [...new Set(
                    creditNotes
                        .map((cn) => String(cn.originalInvoiceId || ''))
                        .filter(Boolean),
                )];
                const originalLineItems = await batchFetchLineItems(originalInvoiceIds);
                const lineTaxBasis = new Map<string, { qty: number; cgst: number; sgst: number; igst: number }>();
                for (const li of originalLineItems) {
                    const invoiceId = String(li.transactionId || '');
                    const itemId = String(li.itemId || '');
                    if (!invoiceId || !itemId) continue;
                    const k = `${invoiceId}:${itemId}`;
                    const existing = lineTaxBasis.get(k) || { qty: 0, cgst: 0, sgst: 0, igst: 0 };
                    existing.qty += Number(li.quantity) || 0;
                    existing.cgst += Number(li.cgstCents) || 0;
                    existing.sgst += Number(li.sgstCents) || 0;
                    existing.igst += Number(li.igstCents) || 0;
                    lineTaxBasis.set(k, existing);
                }

                const creditLineBatches = await Promise.all(
                    creditNotes.map((cn) =>
                        queryAllItems<Record<string, any>>(`CREDITNOTE#${cn.id}`, 'LINEITEM#', { maxPages: 3 }),
                    ),
                );
                const creditLineItems = creditLineBatches.flat();
                for (const cli of creditLineItems) {
                    const originalInvoiceId = String(cli.originalInvoiceId || '');
                    const itemId = String(cli.itemId || '');
                    const qty = Number(cli.quantity) || 0;
                    const taxRefund = Number(cli.taxRefundCents) || 0;
                    const creditAmount = Number(cli.creditAmountCents) || 0;
                    creditTaxAdjustments.taxable_value_cents += Math.max(0, creditAmount - taxRefund);

                    const basis = lineTaxBasis.get(`${originalInvoiceId}:${itemId}`);
                    if (basis && basis.qty > 0 && qty > 0) {
                        const qtyRatio = qty / basis.qty;
                        const igst = Math.round(basis.igst * qtyRatio);
                        const cgst = Math.round(basis.cgst * qtyRatio);
                        const sgst = Math.round(basis.sgst * qtyRatio);
                        creditTaxAdjustments.igst_cents += Math.max(0, igst);
                        creditTaxAdjustments.cgst_cents += Math.max(0, cgst);
                        creditTaxAdjustments.sgst_cents += Math.max(0, sgst);
                    } else if (taxRefund > 0) {
                        // Fallback when source line split unavailable: keep totals conservative, reduce IGST first.
                        creditTaxAdjustments.igst_cents += taxRefund;
                    }
                }
            }
            section31.outward_taxable.total_taxable_value_cents = Math.max(
                0,
                section31.outward_taxable.total_taxable_value_cents - creditTaxAdjustments.taxable_value_cents,
            );
            section31.outward_taxable.igst_cents = Math.max(
                0,
                section31.outward_taxable.igst_cents - creditTaxAdjustments.igst_cents,
            );
            section31.outward_taxable.cgst_cents = Math.max(
                0,
                section31.outward_taxable.cgst_cents - creditTaxAdjustments.cgst_cents,
            );
            section31.outward_taxable.sgst_cents = Math.max(
                0,
                section31.outward_taxable.sgst_cents - creditTaxAdjustments.sgst_cents,
            );

            // 3.2 — Inter-state supplies (B2C > 2.5 lakh)
            const interStateB2C = interStateInvoices
                .filter(i => !i.metadata?.customerGstin && (Number(i.totalCents) || 0) > 250000)
                .reduce((acc, i) => {
                    acc.total_value_cents += Number(i.totalCents) || 0;
                    acc.igst_cents += Number(i.igstCents) || 0;
                    return acc;
                }, { total_value_cents: 0, igst_cents: 0 });

            // 4 — Eligible ITC (Input Tax Credit) — from purchase invoices
            const purchaseBills = await queryAllItems<Record<string, any>>(pk, 'PBILL#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false },
                maxPages: 10,
            });
            const grossItc = {
                igst_cents: 0,
                cgst_cents: 0,
                sgst_cents: 0,
                ineligible_igst_cents: 0,
                ineligible_cgst_cents: 0,
                ineligible_sgst_cents: 0,
            };
            for (const bill of purchaseBills) {
                const items = Array.isArray(bill.items) ? bill.items : [];
                for (const item of items) {
                    const igst = Number(item.igstCents) || 0;
                    const cgst = Number(item.cgstCents) || 0;
                    const sgst = Number(item.sgstCents) || 0;
                    if (item.itcEligible === false) {
                        grossItc.ineligible_igst_cents += igst;
                        grossItc.ineligible_cgst_cents += cgst;
                        grossItc.ineligible_sgst_cents += sgst;
                        continue;
                    }
                    grossItc.igst_cents += igst;
                    grossItc.cgst_cents += cgst;
                    grossItc.sgst_cents += sgst;
                }
            }
            const section4_itc = {
                igst_cents: grossItc.igst_cents,
                cgst_cents: grossItc.cgst_cents,
                sgst_cents: grossItc.sgst_cents,
                ineligible_itc: {
                    igst_cents: grossItc.ineligible_igst_cents,
                    cgst_cents: grossItc.ineligible_cgst_cents,
                    sgst_cents: grossItc.ineligible_sgst_cents,
                },
                purchase_bill_count: purchaseBills.length,
            };

            // 5 — Tax payable = Output - Input
            const totalOutputTax = {
                igst_cents: section31.outward_taxable.igst_cents,
                cgst_cents: section31.outward_taxable.cgst_cents,
                sgst_cents: section31.outward_taxable.sgst_cents,
            };

            const netTaxPayable = {
                igst_cents: totalOutputTax.igst_cents - section4_itc.igst_cents,
                cgst_cents: totalOutputTax.cgst_cents - section4_itc.cgst_cents,
                sgst_cents: totalOutputTax.sgst_cents - section4_itc.sgst_cents,
            };

            return {
                period: { from: fromDate, to: toDate, timezone: tenantTimezone, fromUTC: fromISO, toUTC: toISO },
                section_3_1: section31,
                section_3_2_interstate_b2c: interStateB2C,
                credit_note_adjustments: creditTaxAdjustments,
                section_4_itc: section4_itc,
                output_tax: totalOutputTax,
                net_tax_payable: netTaxPayable,
                invoice_count: invoiceItems.length,
            };
        });

        return response.success(data);
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * M-5: GET /reports/pnl?from=2026-01-01&to=2026-03-31
 * Profit & Loss report — compares revenue against purchase costs.
 */
export const profitLossReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        const fromDate = params.from || getMonthStartInTimezone(tenantTimezone);
        const toDate = params.to || getDateInTimezone(tenantTimezone);
        const pk = Keys.tenantPK(auth.tenantId);

        const cacheKey = `report:pnl:${auth.tenantId}:${fromDate}:${toDate}`;
        const data = await getCached(cacheKey, 300, async () => {
            const boundaries = normalizeDateRangeForQuery(fromDate, toDate, tenantTimezone);
            const fromISO = boundaries.fromUTC;
            const toISO = boundaries.toUTC;

            const invoiceItems = await queryAllItems<Record<string, any>>(pk, 'INVOICE#', {
                filterExpression: 'createdAt >= :from AND createdAt < :to AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(#s) OR (#s <> :voided AND #s <> :draft))',
                expressionAttributeValues: { ':from': fromISO, ':to': toISO, ':false': false, ':voided': 'voided', ':draft': 'draft' },
                expressionAttributeNames: { '#s': 'status' },
                maxPages: 10,
            });

            // Revenue from sales
            const totalRevenueCents = invoiceItems.reduce((s, i) => s + (Number(i.subtotalCents) || Number(i.totalCents) || 0), 0);
            const totalTaxCollectedCents = invoiceItems.reduce((s, i) => s + (Number(i.taxCents) || 0), 0);
            const totalDiscountCents = invoiceItems.reduce((s, i) => s + (Number(i.discountCents) || 0), 0);

            // Cost of Goods Sold (COGS): batch-fetch line items and use purchasePriceCents
            const invoiceIds = invoiceItems.map(inv => inv.id).filter(Boolean);
            const allLineItems = await batchFetchLineItems(invoiceIds);

            // Fetch products to get purchasePriceCents
            const productIds = [...new Set(allLineItems.map(li => li.itemId).filter(Boolean))];
            let cogsCents = 0;
            const productCosts = new Map<string, number>();

            if (productIds.length > 0) {
                // Batch fetch products for their purchase price
                const products = await queryAllItems<Record<string, any>>(pk, 'PRODUCT#', {
                    filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                    expressionAttributeValues: { ':false': false },
                    maxPages: 3,
                });
                for (const p of products) {
                    productCosts.set(p.id, Number(p.purchasePriceCents) || 0);
                }
            }

            for (const li of allLineItems) {
                const purchasePrice = productCosts.get(li.itemId) || 0;
                cogsCents += purchasePrice * (Number(li.quantity) || 0);
            }

            const grossProfitCents = totalRevenueCents - cogsCents;
            const grossMarginPercent = totalRevenueCents > 0 ? Math.round((grossProfitCents / totalRevenueCents) * 10000) / 100 : 0;

            // SECURITY FIX S-12: Restrict COGS to Owner/Admin only.
            // External ACCOUNTANT sees revenue + tax but NOT internal cost structure.
            const showCogs = true; // Will be filtered by role in return below

            return {
                period: { from: fromDate, to: toDate, timezone: tenantTimezone, fromUTC: fromISO, toUTC: toISO },
                revenue: {
                    total_revenue_cents: totalRevenueCents,
                    total_discount_cents: totalDiscountCents,
                    // subtotalCents already stores post-discount value at invoice level.
                    net_revenue_cents: totalRevenueCents,
                    tax_collected_cents: totalTaxCollectedCents,
                },
                costs: {
                    cogs_cents: cogsCents,
                    cogs_note: productCosts.size === 0
                        ? 'No purchase prices set on products — COGS is zero. Set purchasePriceCents on your products for accurate P&L.'
                        : undefined,
                },
                profit: {
                    gross_profit_cents: grossProfitCents,
                    gross_margin_percent: grossMarginPercent,
                },
                invoice_count: invoiceItems.length,
                line_items_analyzed: allLineItems.length,
            };
        });

        // S-12: Strip cost data for ACCOUNTANT role (may be external CA)
        if (auth.role === UserRole.ACCOUNTANT) {
            const filtered = { ...data };
            filtered.costs = { cogs_cents: undefined as any, cogs_note: 'Cost data restricted to Owner/Admin' };
            filtered.profit = { gross_profit_cents: undefined as any, gross_margin_percent: undefined as any };
            return response.success(filtered);
        }

        return response.success(data);
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * L-9: GET /reports/export?from=2026-01-01&to=2026-01-31&type=sales
 * CSV export of sales data
 */
export const exportReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        const fromDate = params.from || getMonthStartInTimezone(tenantTimezone);
        const toDate = params.to || getDateInTimezone(tenantTimezone);
        const exportType = (params.type || 'sales') as ExportType;
        const exportFormat = (params.format || 'csv') as ExportFormat;

        const built = await buildReportExportPayload({
            tenantId: auth.tenantId,
            fromDate,
            toDate,
            exportType,
            exportFormat,
        });
        if (!built.ok) {
            return response.badRequest(built.error);
        }

        return {
            statusCode: 200,
            headers: {
                'Content-Type': built.contentType,
                'Content-Disposition': built.contentDisposition,
                'X-Content-Type-Options': 'nosniff',
            },
            body: built.body,
        };
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * P2 foundation: POST /reports/share
 * Queues/schedules report dispatch jobs for email/WhatsApp channels.
 */
export const shareReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        let body: Record<string, any>;
        try {
            body = parseJsonBody(event as Record<string, any>);
        } catch (err: any) {
            if (err?.message === 'INVALID_JSON') {
                return response.badRequest('Invalid JSON payload');
            }
            throw err;
        }

        const tenantTimezone = await resolveTenantTimezone(auth.tenantId);
        const reportType = String(body.reportType || 'sales').toLowerCase() as ExportType;
        const format = String(body.format || 'csv').toLowerCase() as ExportFormat;
        const fromDate = String(body.from || getMonthStartInTimezone(tenantTimezone));
        const toDate = String(body.to || getDateInTimezone(tenantTimezone));
        const mode = String(body.mode || 'now').toLowerCase();
        const scheduleAt = body.scheduleAt ? String(body.scheduleAt) : '';
        const timezone = String(body.timezone || tenantTimezone);
        const channels = Array.isArray(body.channels) ? body.channels.map((x: any) => String(x || '').toLowerCase()) : [];
        const recipients = Array.isArray(body.recipients) ? body.recipients.map((x: any) => String(x || '').trim()).filter(Boolean) : [];
        const perfInput = (body.performanceOptions && typeof body.performanceOptions === 'object')
            ? body.performanceOptions as Record<string, any>
            : null;

        if (!['sales', 'gstr1', 'gstr3b'].includes(reportType)) {
            return response.badRequest('Invalid reportType. Supported: sales, gstr1, gstr3b');
        }
        if (!['csv', 'json', 'excel'].includes(format)) {
            return response.badRequest('Invalid format. Supported: csv, json, excel');
        }
        if (!isValidDateFormat(fromDate) || !isValidDateFormat(toDate)) {
            return response.badRequest('Invalid date format. Use YYYY-MM-DD');
        }
        if (!['now', 'scheduled'].includes(mode)) {
            return response.badRequest('Invalid mode. Supported: now, scheduled');
        }

        const validChannels: ShareChannel[] = ['email', 'whatsapp'];
        const normalizedChannels = [...new Set(channels)].filter((c): c is ShareChannel => validChannels.includes(c as ShareChannel));
        if (normalizedChannels.length === 0) {
            return response.badRequest('At least one channel is required: email or whatsapp');
        }
        if (recipients.length === 0) {
            return response.badRequest('At least one recipient is required');
        }
        let performanceOptions: Record<string, number> | null = null;
        if (perfInput) {
            const maxPages = Math.max(1, Math.min(25, Number(perfInput.maxPages) || 10));
            const lineItemInvoiceCap = Math.max(1, Math.min(2000, Number(perfInput.lineItemInvoiceCap) || 500));
            performanceOptions = {
                maxPages,
                lineItemInvoiceCap,
            };
        }

        let scheduledFor: string | null = null;
        if (mode === 'scheduled') {
            if (!scheduleAt) {
                return response.badRequest('scheduleAt is required when mode=scheduled');
            }
            const scheduleMoment = dayjs(scheduleAt);
            if (!scheduleMoment.isValid()) {
                return response.badRequest('Invalid scheduleAt datetime');
            }
            if (scheduleMoment.isBefore(dayjs())) {
                return response.badRequest('scheduleAt must be in the future');
            }
            if (!isValidTimezone(timezone)) {
                return response.badRequest('Invalid timezone');
            }
            scheduledFor = scheduleMoment.toISOString();
        }

        const dispatchId = `rptdisp_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
        const nowIso = new Date().toISOString();
        await putItem({
            PK: Keys.tenantPK(auth.tenantId),
            SK: `REPORTDISPATCH#${dispatchId}`,
            GSI1PK: Keys.entityGSI1PK('REPORTDISPATCH'),
            GSI1SK: nowIso,
            entityType: 'REPORTDISPATCH',
            id: dispatchId,
            tenantId: auth.tenantId,
            createdBy: auth.sub,
            createdAt: nowIso,
            updatedAt: nowIso,
            status: mode === 'scheduled' ? 'scheduled' : 'queued',
            mode,
            reportType,
            format,
            period: { from: fromDate, to: toDate },
            timezone: mode === 'scheduled' ? timezone : tenantTimezone,
            scheduleAt: scheduledFor,
            channels: normalizedChannels,
            recipients,
            performanceOptions,
            attemptCount: 0,
            maxAttempts: 3,
            lastError: null,
            nextRetryAt: null,
            jobSource: 'report-share-center',
        } as Record<string, any>);

        return response.success({
            dispatchId,
            status: mode === 'scheduled' ? 'scheduled' : 'queued',
            reportType,
            format,
            channels: normalizedChannels,
            recipientsCount: recipients.length,
            period: { from: fromDate, to: toDate },
            scheduleAt: scheduledFor,
            performanceOptions,
            attemptCount: 0,
            maxAttempts: 3,
            lastError: null,
            nextRetryAt: null,
            note: 'Dispatch queued. EventBridge worker runs report-dispatch-worker; set REPORT_DISPATCH_SNS_TOPIC_ARN and/or REPORT_DISPATCH_WHATSAPP_WEBHOOK_URL for real delivery. Dry-run logs if unset.',
        }, 202);
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * P2 foundation: GET /reports/share-dispatches?status=&limit=
 * Lists latest report dispatch jobs for share center history.
 */
export const listReportDispatches = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const params = event.queryStringParameters || {};
        const statusFilter = String(params.status || '').trim().toLowerCase();
        const limit = Math.min(100, Math.max(1, Number(params.limit) || 20));
        const pk = Keys.tenantPK(auth.tenantId);

        const rows = await queryAllItems<Record<string, any>>(pk, 'REPORTDISPATCH#', {
            scanIndexForward: false,
            maxPages: 3,
        });
        const filtered = statusFilter
            ? rows.filter((r) => String(r.status || '').toLowerCase() === statusFilter)
            : rows;
        const items = filtered.slice(0, limit).map((r) => ({
            id: r.id,
            status: r.status,
            mode: r.mode,
            reportType: r.reportType,
            format: r.format,
            channels: Array.isArray(r.channels) ? r.channels : [],
            recipientsCount: Array.isArray(r.recipients) ? r.recipients.length : 0,
            period: r.period || {},
            scheduleAt: r.scheduleAt || null,
            performanceOptions: r.performanceOptions || null,
            attemptCount: Number(r.attemptCount) || 0,
            maxAttempts: Number(r.maxAttempts) || 3,
            lastError: r.lastError || null,
            nextRetryAt: r.nextRetryAt || null,
            createdAt: r.createdAt || null,
            updatedAt: r.updatedAt || null,
        }));

        return response.success({
            count: items.length,
            items,
        });
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * P2 foundation: GET /reports/share-dispatches/{id}/events?limit=
 * Returns forensic attempt event history for one dispatch job.
 */
export const listReportDispatchEvents = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const dispatchId = String((event as any).pathParameters?.id || '').trim();
        if (!dispatchId) {
            return response.badRequest('dispatchId is required');
        }
        const params = event.queryStringParameters || {};
        const limit = Math.min(100, Math.max(1, Number(params.limit) || 20));
        const pk = Keys.tenantPK(auth.tenantId);

        const rows = await queryAllItems<Record<string, any>>(
            pk,
            `REPORTDISPATCHEVENT#${dispatchId}#`,
            { scanIndexForward: false, maxPages: 3 },
        );
        const items = rows.slice(0, limit).map((r) => ({
            id: r.id,
            dispatchId: r.dispatchId || dispatchId,
            outcome: r.outcome || null,
            statusAfter: r.statusAfter || null,
            attemptCount: Number(r.attemptCount) || 0,
            maxAttempts: Number(r.maxAttempts) || 3,
            lastError: r.lastError || null,
            nextRetryAt: r.nextRetryAt || null,
            source: r.source || null,
            createdAt: r.createdAt || null,
        }));

        return response.success({
            dispatchId,
            count: items.length,
            items,
        });
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * P2 foundation: POST /reports/share-dispatches/{id}/cancel
 * Cancels queued/scheduled dispatch.
 */
export const cancelReportDispatch = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event, _context, auth) => {
        const pathId = String((event as any).pathParameters?.id || '').trim();
        const body = parseJsonBody(event as Record<string, any>);
        const bodyId = String(body.dispatchId || '').trim();
        const dispatchId = pathId || bodyId;
        if (!dispatchId) {
            return response.badRequest('dispatchId is required');
        }
        const pk = Keys.tenantPK(auth.tenantId);
        const sk = `REPORTDISPATCH#${dispatchId}`;
        const existing = await getItem<Record<string, any>>(pk, sk);
        if (!existing) {
            return response.notFound('Report dispatch');
        }

        const currentStatus = String(existing.status || '').toLowerCase();
        if (currentStatus === 'cancelled') {
            return response.success({
                dispatchId,
                status: 'cancelled',
                alreadyCancelled: true,
            });
        }
        if (!['queued', 'scheduled'].includes(currentStatus)) {
            return response.badRequest(`Dispatch cannot be cancelled from status=${existing.status}`);
        }

        const updated = await updateItem(pk, sk, {
            updateExpression: 'SET #status = :cancelled, updatedAt = :updatedAt, cancelledAt = :cancelledAt, cancelledBy = :cancelledBy, nextRetryAt = :nextRetryAt',
            expressionAttributeNames: { '#status': 'status' },
            expressionAttributeValues: {
                ':cancelled': 'cancelled',
                ':updatedAt': new Date().toISOString(),
                ':cancelledAt': new Date().toISOString(),
                ':cancelledBy': auth.sub,
                ':nextRetryAt': null,
            },
        });

        return response.success({
            dispatchId,
            status: updated?.status || 'cancelled',
        });
    },
    { requiredFeature: FeatureKey.ADVANCED_REPORTS },
);

/**
 * P2 foundation: POST /reports/share-dispatches/{id}/mark-attempt
 * Worker updates attempt lifecycle (sent/failed/retry scheduling).
 */
export const markReportDispatchAttempt = internalHandler(
    async (event, _context, auth) => {
        const pathId = String((event as any).pathParameters?.id || '').trim();
        let body: Record<string, any>;
        try {
            body = parseJsonBody(event as Record<string, any>);
        } catch (err: any) {
            if (err?.message === 'INVALID_JSON') {
                return response.badRequest('Invalid JSON payload');
            }
            throw err;
        }

        const bodyId = String(body.dispatchId || '').trim();
        const dispatchId = pathId || bodyId;
        if (!dispatchId) {
            return response.badRequest('dispatchId is required');
        }
        const outcome = String(body.outcome || '').toLowerCase();
        if (!['sent', 'failed'].includes(outcome)) {
            return response.badRequest('Invalid outcome. Supported: sent, failed');
        }

        const increment = Math.max(1, Math.min(5, Number(body.increment) || 1));
        const errMsg = String(body.errorMessage || body.lastError || '').trim();
        const core = await applyReportDispatchOutcome(auth.tenantId, dispatchId, {
            outcome: outcome as 'sent' | 'failed',
            increment,
            errorMessage: outcome === 'failed' ? (errMsg || 'DISPATCH_FAILED') : undefined,
            nextRetryAt: body.nextRetryAt ? String(body.nextRetryAt) : undefined,
            requestSource: auth.requestSource || 'worker',
        });
        if (!core.ok) {
            if (core.statusCode === 404) return response.notFound(core.message);
            return response.badRequest(core.message);
        }
        return response.success(core.data);
    }
);
