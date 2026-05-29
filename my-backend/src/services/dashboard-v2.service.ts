// ============================================================================
// Dashboard V2 Service — Business-Type-Aware Dashboard Data
// ============================================================================
// All methods are tenant-scoped and business-type-filtered.
// Aggregates data server-side — never sends raw records.
// Returns { data: ..., isEmpty: true, message: "..." } when empty.
// ============================================================================

import { Keys, queryAllItems, queryItems, getItem } from '../config/dynamodb.config';
import { BusinessType } from '../types/tenant.types';
import { logger } from '../utils/logger';
import { getCached } from '../utils/cache';

type Rec = Record<string, any>;

function toAmount(value: unknown): number {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
}

function isActiveInvoice(inv: Rec): boolean {
    if (inv.isDeleted === true) return false;
    const status = String(inv.status || '').toLowerCase();
    return status !== 'voided' && status !== 'draft';
}

function toMonthKey(date: Date): string {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function getMonthLabel(key: string): string {
    const [y, m] = key.split('-');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[parseInt(m, 10) - 1] || m;
}

function daysBetween(d1: Date, d2: Date): number {
    return Math.abs(Math.floor((d2.getTime() - d1.getTime()) / (1000 * 60 * 60 * 24)));
}

async function fetchAllInvoices(tenantId: string): Promise<Rec[]> {
    const pk = Keys.tenantPK(tenantId);
    const all = await queryAllItems<Rec>(pk, 'INVOICE#', { maxPages: 50 });
    return all.filter(isActiveInvoice);
}

async function fetchInvoicesByBusinessType(tenantId: string, businessType: BusinessType): Promise<Rec[]> {
    const all = await fetchAllInvoices(tenantId);
    // Filter by businessType if the field exists on invoice records
    return all.filter(inv => {
        const bt = String(inv.businessType || '').toLowerCase();
        // If invoice has no businessType, include it (legacy data)
        if (!bt || bt === '') return true;
        return bt === businessType.toLowerCase();
    });
}

async function fetchInvoicesInDateRange(tenantId: string, businessType: BusinessType, fromIso: string, toIso: string): Promise<Rec[]> {
    const all = await fetchInvoicesByBusinessType(tenantId, businessType);
    return all.filter(inv => {
        const createdAt = inv.createdAt || inv.date || '';
        return createdAt >= fromIso && createdAt < toIso;
    });
}

export class DashboardV2Service {

    // ── Summary (Performance Cards) ─────────────────────────────────────
    async getDashboardSummary(tenantId: string, businessType: BusinessType, period: string): Promise<Rec> {
        return getCached(`dash-v2-summary:${tenantId}:${businessType}:${period}`, 30, async () => {
            const now = new Date();
            const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
            const monthEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));

            const allInvoices = await fetchInvoicesByBusinessType(tenantId, businessType);
            const mtdInvoices = allInvoices.filter(inv => {
                const d = inv.createdAt || inv.date || '';
                return d >= monthStart.toISOString() && d < monthEnd.toISOString();
            });

            // Previous month for comparison
            const prevMonthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
            const prevMonthEnd = monthStart;
            const prevInvoices = allInvoices.filter(inv => {
                const d = inv.createdAt || inv.date || '';
                return d >= prevMonthStart.toISOString() && d < prevMonthEnd.toISOString();
            });

            // Total Revenue (MTD) — sum of paid invoices
            const totalRevenueCents = mtdInvoices
                .filter(inv => String(inv.status || '').toLowerCase() === 'paid' || toAmount(inv.paidCents) > 0)
                .reduce((sum, inv) => sum + (toAmount(inv.paidCents) || toAmount(inv.totalCents)), 0);

            const prevRevenueCents = prevInvoices
                .filter(inv => String(inv.status || '').toLowerCase() === 'paid' || toAmount(inv.paidCents) > 0)
                .reduce((sum, inv) => sum + (toAmount(inv.paidCents) || toAmount(inv.totalCents)), 0);

            const revenueChangePercent = prevRevenueCents > 0
                ? ((totalRevenueCents - prevRevenueCents) / prevRevenueCents * 100)
                : 0;

            // Overdue Invoices
            const overdueInvoices = allInvoices.filter(inv => {
                const status = String(inv.status || '').toLowerCase();
                if (status === 'paid' || status === 'cancelled') return false;
                const dueDate = inv.dueDate || inv.due_date;
                if (!dueDate) return false;
                return new Date(dueDate) < now;
            });
            const overdueCount = overdueInvoices.length;
            const overdueAmountCents = overdueInvoices.reduce((s, inv) => s + Math.max(toAmount(inv.balanceCents) || (toAmount(inv.totalCents) - toAmount(inv.paidCents)), 0), 0);

            // Pending Payments
            const pendingInvoices = allInvoices.filter(inv => {
                const status = String(inv.status || '').toLowerCase();
                return status === 'pending' || status === 'partial' || status === 'unpaid';
            });
            const pendingCount = pendingInvoices.length;
            const pendingAmountCents = pendingInvoices.reduce((s, inv) => s + Math.max(toAmount(inv.balanceCents) || (toAmount(inv.totalCents) - toAmount(inv.paidCents)), 0), 0);

            // Average Collection Period (days)
            const paidInvoices = allInvoices.filter(inv => String(inv.status || '').toLowerCase() === 'paid');
            let avgCollectionDays = 0;
            if (paidInvoices.length > 0) {
                const totalDays = paidInvoices.reduce((sum, inv) => {
                    const created = new Date(inv.createdAt || inv.date || now.toISOString());
                    const paid = new Date(inv.paidAt || inv.updatedAt || now.toISOString());
                    return sum + daysBetween(created, paid);
                }, 0);
                avgCollectionDays = Math.round(totalDays / paidInvoices.length);
            }
            // Change vs last month
            const prevPaid = prevInvoices.filter(inv => String(inv.status || '').toLowerCase() === 'paid');
            let prevAvgDays = 0;
            if (prevPaid.length > 0) {
                const totalDays = prevPaid.reduce((sum, inv) => {
                    const created = new Date(inv.createdAt || inv.date || now.toISOString());
                    const paid = new Date(inv.paidAt || inv.updatedAt || now.toISOString());
                    return sum + daysBetween(created, paid);
                }, 0);
                prevAvgDays = Math.round(totalDays / prevPaid.length);
            }
            const collectionChangePercent = prevAvgDays > 0
                ? ((avgCollectionDays - prevAvgDays) / prevAvgDays * 100)
                : 0;

            // Badge logic
            const collectionRate = allInvoices.length > 0
                ? (paidInvoices.length / allInvoices.length * 100)
                : 100;
            const revenueBadge = collectionRate > 80 ? 'Healthy' : (collectionRate < 50 ? 'Critical' : 'Urgent');
            const overdueBadge = (overdueCount > 10 || (overdueAmountCents > totalRevenueCents * 0.2)) ? 'Urgent' : 'Normal';
            const pendingBadge = pendingCount > 10 ? 'Urgent' : 'Normal';

            const isEmpty = allInvoices.length === 0;

            return {
                totalRevenueCents,
                revenueChangePercent: Math.round(revenueChangePercent * 10) / 10,
                revenueBadge,
                overdueCount,
                overdueAmountCents,
                overdueBadge,
                pendingCount,
                pendingAmountCents,
                pendingBadge,
                avgCollectionDays,
                collectionChangePercent: Math.round(collectionChangePercent * 10) / 10,
                businessType,
                period,
                isEmpty,
                message: isEmpty ? `No data for ${businessType} business type` : null,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── Revenue Chart (Last N Months) ───────────────────────────────────
    async getRevenueChart(tenantId: string, businessType: BusinessType, months: number): Promise<Rec> {
        return getCached(`dash-v2-revenue:${tenantId}:${businessType}:${months}`, 60, async () => {
            const allInvoices = await fetchInvoicesByBusinessType(tenantId, businessType);
            const now = new Date();
            const points: Array<{ month: string; label: string; billedCents: number; collectedCents: number }> = [];

            for (let i = months - 1; i >= 0; i--) {
                const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
                const nextMonth = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1));
                const key = toMonthKey(d);
                const label = getMonthLabel(key);

                const monthInvoices = allInvoices.filter(inv => {
                    const cd = inv.createdAt || inv.date || '';
                    return cd >= d.toISOString() && cd < nextMonth.toISOString();
                });

                const billedCents = monthInvoices.reduce((s, inv) => s + toAmount(inv.totalCents), 0);
                const collectedCents = monthInvoices.reduce((s, inv) => s + toAmount(inv.paidCents), 0);

                points.push({ month: key, label, billedCents, collectedCents });
            }

            const isEmpty = allInvoices.length === 0;
            return {
                months,
                points,
                businessType,
                isEmpty,
                message: isEmpty ? `No revenue data for ${businessType}` : null,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── Invoice Status Distribution (Donut Chart) ───────────────────────
    async getInvoiceDistribution(tenantId: string, businessType: BusinessType): Promise<Rec> {
        return getCached(`dash-v2-dist:${tenantId}:${businessType}`, 60, async () => {
            const allInvoices = await fetchInvoicesByBusinessType(tenantId, businessType);

            let paid = 0, pending = 0, overdue = 0;
            const now = new Date();

            for (const inv of allInvoices) {
                const status = String(inv.status || '').toLowerCase();
                if (status === 'paid') {
                    paid++;
                } else {
                    const dueDate = inv.dueDate || inv.due_date;
                    if (dueDate && new Date(dueDate) < now) {
                        overdue++;
                    } else {
                        pending++;
                    }
                }
            }

            const total = allInvoices.length;
            const isEmpty = total === 0;

            return {
                totalInvoices: total,
                paid,
                pending,
                overdue,
                paidPercent: total > 0 ? Math.round(paid / total * 100) : 0,
                pendingPercent: total > 0 ? Math.round(pending / total * 100) : 0,
                overduePercent: total > 0 ? Math.round(overdue / total * 100) : 0,
                businessType,
                isEmpty,
                message: isEmpty ? `No invoices for ${businessType}` : null,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── Recent Invoices (Table) ─────────────────────────────────────────
    async getRecentInvoices(tenantId: string, businessType: BusinessType, range: string, filter: string): Promise<Rec> {
        const cacheKey = `dash-v2-recent:${tenantId}:${businessType}:${range}:${filter}`;
        return getCached(cacheKey, 15, async () => {
            const now = new Date();
            let daysBack = 10;
            if (range === '7days') daysBack = 7;
            else if (range === '30days') daysBack = 30;
            else if (range === '1day') daysBack = 1;

            if (filter === 'today') daysBack = 1;
            else if (filter === 'this_week') daysBack = 7;

            const from = new Date(now);
            from.setUTCDate(from.getUTCDate() - daysBack);
            from.setUTCHours(0, 0, 0, 0);

            const allInvoices = await fetchInvoicesByBusinessType(tenantId, businessType);
            const recent = allInvoices
                .filter(inv => {
                    const d = inv.createdAt || inv.date || '';
                    return d >= from.toISOString();
                })
                .sort((a, b) => {
                    const da = a.createdAt || a.date || '';
                    const db = b.createdAt || b.date || '';
                    return db.localeCompare(da);
                })
                .slice(0, 20)
                .map(inv => ({
                    invoiceNumber: inv.invoiceNumber || inv.billNumber || String(inv.SK || '').replace('INVOICE#', ''),
                    customerName: inv.customerName || inv.customer_name || 'Walk-in',
                    date: (inv.createdAt || inv.date || '').slice(0, 10),
                    dueDate: (inv.dueDate || inv.due_date || '').slice(0, 10),
                    amountCents: toAmount(inv.totalCents),
                    status: String(inv.status || 'pending').toLowerCase(),
                    invoiceId: inv.id || String(inv.SK || '').replace('INVOICE#', ''),
                }));

            const isEmpty = recent.length === 0;
            return {
                invoices: recent,
                range,
                filter,
                businessType,
                isEmpty,
                message: isEmpty ? `No recent transactions for ${businessType}` : null,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── Cash Flow Forecast ──────────────────────────────────────────────
    async getCashflowForecast(tenantId: string, businessType: BusinessType): Promise<Rec> {
        return getCached(`dash-v2-cashflow:${tenantId}:${businessType}`, 120, async () => {
            const allInvoices = await fetchInvoicesByBusinessType(tenantId, businessType);
            const now = new Date();

            // Calculate actual cash received in last 3 months
            const points: Array<{ month: string; label: string; cashReserveCents: number; forecastCents: number }> = [];
            let runningCash = 0;

            for (let i = 2; i >= 0; i--) {
                const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
                const nextMonth = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1));
                const key = toMonthKey(d);
                const label = getMonthLabel(key);

                const monthInvoices = allInvoices.filter(inv => {
                    const cd = inv.createdAt || inv.date || '';
                    return cd >= d.toISOString() && cd < nextMonth.toISOString();
                });

                const collected = monthInvoices.reduce((s, inv) => s + toAmount(inv.paidCents), 0);
                const billed = monthInvoices.reduce((s, inv) => s + toAmount(inv.totalCents), 0);
                runningCash += collected;

                // Simple forecast: billed amount for current + future months
                const isFuture = i === 0;
                points.push({
                    month: key,
                    label,
                    cashReserveCents: runningCash,
                    forecastCents: isFuture ? Math.round(billed * 1.102) : billed, // +10.2% growth projection
                });
            }

            // Forecast percentage
            const lastTwo = points.slice(-2);
            let forecastPercent = 0;
            if (lastTwo.length === 2 && lastTwo[0].forecastCents > 0) {
                forecastPercent = Math.round((lastTwo[1].forecastCents - lastTwo[0].forecastCents) / lastTwo[0].forecastCents * 1000) / 10;
            }

            const isEmpty = allInvoices.length === 0;
            return {
                points,
                forecastPercent,
                businessType,
                isEmpty,
                message: isEmpty ? `No cash flow data for ${businessType}` : null,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── Notifications Count ─────────────────────────────────────────────
    async getNotificationsCount(tenantId: string): Promise<Rec> {
        try {
            const pk = Keys.tenantPK(tenantId);
            const notifications = await queryItems<Rec>(pk, 'NOTIFICATION#', {
                filterExpression: 'isRead = :false',
                expressionAttributeValues: { ':false': false },
                limit: 100,
            });
            return {
                count: notifications.items.length,
                generatedAt: new Date().toISOString(),
            };
        } catch {
            return { count: 0, generatedAt: new Date().toISOString() };
        }
    }

    // ── License Validation ──────────────────────────────────────────────
    async validateLicense(tenantId: string, userId: string): Promise<Rec> {
        try {
            const pk = Keys.tenantPK(tenantId);
            const tenant = await getItem<Rec>(pk, 'TENANT_META');

            if (!tenant) {
                return {
                    valid: false,
                    status: 'not_found',
                    message: 'License not found',
                    allowedBusinessTypes: [],
                    activeBusinessType: null,
                };
            }

            // Get businesses under this tenant
            const businesses = await queryAllItems<Rec>(pk, 'BUSINESS#', { maxPages: 5 });
            const activeBusinessTypes = businesses
                .filter(b => b.isDeleted !== true && b.isActive !== false)
                .map(b => String(b.businessType || 'other').toLowerCase());

            const uniqueTypes = Array.from(new Set(activeBusinessTypes));
            const activeType = tenant.activeBusinessType || tenant.businessType || uniqueTypes[0] || 'other';

            const expiresAt = tenant.subscriptionValidUntil || tenant.expiresAt;
            const isExpired = expiresAt && new Date(expiresAt) < new Date();

            return {
                valid: !isExpired,
                status: isExpired ? 'expired' : (tenant.status || 'active'),
                plan: tenant.subscriptionPlan || tenant.plan || 'basic',
                allowedBusinessTypes: uniqueTypes.length > 0 ? uniqueTypes : [activeType],
                activeBusinessType: activeType,
                tenantId,
                userId,
                expiresAt: expiresAt || null,
                message: isExpired ? 'License expired' : null,
            };
        } catch (err) {
            logger.error('License validation failed', { tenantId, userId, error: (err as Error).message });
            return {
                valid: false,
                status: 'error',
                message: 'License validation failed',
                allowedBusinessTypes: [],
                activeBusinessType: null,
            };
        }
    }
}
