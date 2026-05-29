// ============================================================================
// Lambda — Jewellery compliance reports (Hallmark BIS register, Old Gold register)
// ============================================================================
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { z } from 'zod';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { parseQuery } from '../middleware/validation';
import { BusinessType, UserRole } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import { Keys, queryAllItems } from '../config/dynamodb.config';
import * as response from '../utils/response';

// F007: Both jewellery compliance reports require Premium (JEWELLERY_HALLMARK /
// JEWELLERY_OLD_GOLD_EXCHANGE are Premium+ per permission-matrix.ts)
const JEWELLERY_HALLMARK_OPTS = {
    requiredBusinessType: BusinessType.JEWELLERY,
    requiredFeature: FeatureKey.JEWELLERY_HALLMARK,
};

const JEWELLERY_OLD_GOLD_OPTS = {
    requiredBusinessType: BusinessType.JEWELLERY,
    requiredFeature: FeatureKey.JEWELLERY_OLD_GOLD_EXCHANGE,
};

const dateRangeSchema = z.object({
    from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

/**
 * GET /jewellery/reports/hallmark-register?from=&to=
 * BIS Hallmark compliance register — mandatory per BIS (Hallmarking) Order 2023.
 * Lists all hallmarked products sold with HUID, purity, weight, article type.
 */
export const hallmarkRegisterReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.ACCOUNTANT],
    async (event: APIGatewayProxyEventV2, _context, auth) => {
        const parsed = parseQuery(dateRangeSchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 90 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = `${from}T00:00:00.000Z`;
        const toIso = `${to}T23:59:59.999Z`;
        const pk = Keys.tenantPK(auth.tenantId);

        // Fetch products with hallmark data
        const products = await queryAllItems<Record<string, unknown>>(pk, 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        // Fetch invoices in range
        const invoices = await queryAllItems<Record<string, unknown>>(pk, 'INVOICE#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND attribute_exists(createdAt)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        // Build product lookup
        const prodMap = new Map<string, Record<string, unknown>>();
        for (const p of products) {
            if (p.id) prodMap.set(String(p.id), p);
        }

        // Collect hallmarked items from invoices in date range
        const rows: Record<string, unknown>[] = [];
        for (const inv of invoices) {
            const ts = String(inv.createdAt || '');
            if (!ts || ts < fromIso || ts > toIso) continue;
            const st = String(inv.status || '');
            if (st === 'voided' || st === 'draft') continue;

            const lineItems = inv.lineItems as Record<string, unknown>[] | undefined;
            if (!Array.isArray(lineItems)) continue;

            for (const li of lineItems) {
                const productId = String(li.productId || '');
                const product = prodMap.get(productId);
                const huid = String(li.huid || product?.huid || '');
                const purity = String(li.purity || product?.purity || '');
                const articleType = String(li.articleType || product?.articleType || product?.category || '');
                const weight = Number(li.weightGrams || li.weight || product?.weightGrams || 0);

                if (!huid && !purity) continue; // not hallmark-relevant

                rows.push({
                    invoiceNumber: inv.invoiceNumber || inv.id,
                    invoiceDate: ts.substring(0, 10),
                    customerName: inv.customerName || 'Walk-in',
                    productName: li.name || product?.name || '-',
                    huid: huid || 'N/A',
                    purity: purity || 'N/A',
                    weightGrams: weight,
                    articleType: articleType || 'N/A',
                    amountCents: Number(li.totalCents || li.subtotalCents || 0),
                    makingChargeCents: Number(li.makingChargeCents || 0),
                });
            }
        }

        rows.sort((a, b) => String(b.invoiceDate || '').localeCompare(String(a.invoiceDate || '')));

        return response.success({
            period: { from, to },
            totalItems: rows.length,
            totalWeightGrams: rows.reduce((s, r) => s + (Number(r.weightGrams) || 0), 0),
            items: rows,
        });
    },
    JEWELLERY_HALLMARK_OPTS,
);

/**
 * GET /jewellery/reports/old-gold-register?from=&to=
 * Old Gold / Exchange purchase register — PML Act compliance for amounts > ₹50K.
 * Lists old gold purchases with customer KYC, weight, purity, rate, amount.
 */
export const oldGoldRegisterReport = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
    async (event: APIGatewayProxyEventV2, _context, auth) => {
        const parsed = parseQuery(dateRangeSchema, event);
        if (!parsed.success) return parsed.error;

        const from = parsed.data.from || new Date(Date.now() - 90 * 86400000).toISOString().substring(0, 10);
        const to = parsed.data.to || new Date().toISOString().substring(0, 10);
        if (from > to) return response.badRequest('from must be <= to');

        const fromIso = `${from}T00:00:00.000Z`;
        const toIso = `${to}T23:59:59.999Z`;
        const pk = Keys.tenantPK(auth.tenantId);

        // Query purchase bills tagged as old gold
        const purchaseBills = await queryAllItems<Record<string, unknown>>(pk, 'PBILL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            maxPages: 40,
        });

        const rows: Record<string, unknown>[] = [];
        for (const pb of purchaseBills) {
            const ts = String(pb.createdAt || pb.purchaseDate || '');
            if (!ts || ts < fromIso || ts > toIso) continue;

            const cat = String(pb.category || pb.purchaseType || '').toLowerCase();
            const isOldGold = cat.includes('old_gold') || cat.includes('old gold') || cat.includes('exchange')
                || pb.isOldGoldPurchase === true;
            if (!isOldGold) continue;

            rows.push({
                purchaseId: pb.id || pb.SK,
                purchaseDate: ts.substring(0, 10),
                supplierName: pb.supplierName || pb.vendorName || pb.customerName || 'Unknown',
                metalType: pb.metalType || 'Gold',
                weightGrams: Number(pb.weightGrams || pb.weight || 0),
                purity: pb.purity || 'N/A',
                ratePerGramCents: Number(pb.ratePerGramCents || 0),
                totalAmountCents: Number(pb.totalCents || pb.amountCents || 0),
                kycReference: pb.kycReference || pb.panNumber || 'N/A',
                customerAddress: pb.customerAddress || pb.supplierAddress || null,
                notes: pb.notes || null,
            });
        }

        rows.sort((a, b) => String(b.purchaseDate || '').localeCompare(String(a.purchaseDate || '')));

        const totalAmountCents = rows.reduce((s, r) => s + (Number(r.totalAmountCents) || 0), 0);
        const pmlThresholdCents = 5000000; // ₹50,000 in paisa
        const pmlFlaggedCount = rows.filter(r => (Number(r.totalAmountCents) || 0) >= pmlThresholdCents).length;

        return response.success({
            period: { from, to },
            totalPurchases: rows.length,
            totalAmountCents,
            totalWeightGrams: rows.reduce((s, r) => s + (Number(r.weightGrams) || 0), 0),
            pmlFlaggedCount,
            pmlNote: `${pmlFlaggedCount} transactions >= ₹50,000 — PML Act KYC mandatory`,
            items: rows,
        });
    },
    JEWELLERY_OLD_GOLD_OPTS,
);
