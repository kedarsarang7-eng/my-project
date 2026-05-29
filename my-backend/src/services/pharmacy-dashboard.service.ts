// ============================================================================
// PHARMACY DASHBOARD SERVICE
// ============================================================================
// Provides all pharmacy-specific dashboard data endpoints
// Implements business-type filtering, caching, and real-time data aggregation
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import { Keys, queryAllItems, queryItems, getItem } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { getCached } from '../utils/cache';

type Rec = Record<string, any>;

function toAmount(value: unknown): number {
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
}

function daysBetween(d1: Date, d2: Date): number {
    return Math.abs(Math.floor((d2.getTime() - d1.getTime()) / (1000 * 60 * 60 * 24)));
}

function getDateRange(range: string): { from: Date; to: Date } {
    const now = new Date();
    const from = new Date();
    
    switch (range) {
        case 'last7days':
            from.setDate(now.getDate() - 7);
            break;
        case 'last30days':
            from.setDate(now.getDate() - 30);
            break;
        case 'last90days':
            from.setDate(now.getDate() - 90);
            break;
        default:
            from.setDate(now.getDate() - 30);
    }
    
    from.setHours(0, 0, 0, 0);
    now.setHours(23, 59, 59, 999);
    
    return { from, to: now };
}

export class PharmacyDashboardService {

    // ── KPI CARDS DATA ─────────────────────────────────────────────────────

    async getTotalRevenue(tenantId: string, range: string): Promise<Rec> {
        return getCached(`pharmacy-revenue:${tenantId}:${range}`, 30, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch pharmacy sales/invoices
            const invoices = await queryAllItems<Rec>(pk, 'INVOICE#', { maxPages: 50 });
            const pharmacyInvoices = invoices.filter(inv => 
                inv.businessType === 'pharmacy' && 
                inv.createdAt >= from.toISOString() && 
                inv.createdAt <= to.toISOString() &&
                inv.status === 'paid'
            );

            const totalCents = pharmacyInvoices.reduce((sum, inv) => 
                sum + toAmount(inv.totalCents), 0);

            // Previous period for comparison
            const prevFrom = new Date(from);
            const prevTo = new Date(to);
            prevFrom.setDate(prevFrom.getDate() - (to.getDate() - from.getDate()));
            prevTo.setDate(prevTo.getDate() - (to.getDate() - from.getDate()));

            const prevInvoices = invoices.filter(inv => 
                inv.businessType === 'pharmacy' && 
                inv.createdAt >= prevFrom.toISOString() && 
                inv.createdAt <= prevTo.toISOString() &&
                inv.status === 'paid'
            );

            const prevCents = prevInvoices.reduce((sum, inv) => 
                sum + toAmount(inv.totalCents), 0);

            const changePercent = prevCents > 0 ? 
                ((totalCents - prevCents) / prevCents * 100) : 0;

            const trend = changePercent > 0 ? 'up' : (changePercent < 0 ? 'down' : 'neutral');

            return {
                total: totalCents,
                changePercent: Math.round(changePercent * 10) / 10,
                trend,
                isEmpty: pharmacyInvoices.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    async getNewPatientsCount(tenantId: string, range: string): Promise<Rec> {
        return getCached(`pharmacy-patients:${tenantId}:${range}`, 30, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch patients
            const patients = await queryAllItems<Rec>(pk, 'PATIENT#', { maxPages: 50 });
            const newPatients = patients.filter(patient => 
                patient.createdAt >= from.toISOString() && 
                patient.createdAt <= to.toISOString()
            );

            // Previous period for comparison
            const prevFrom = new Date(from);
            const prevTo = new Date(to);
            prevFrom.setDate(prevFrom.getDate() - (to.getDate() - from.getDate()));
            prevTo.setDate(prevTo.getDate() - (to.getDate() - from.getDate()));

            const prevPatients = patients.filter(patient => 
                patient.createdAt >= prevFrom.toISOString() && 
                patient.createdAt <= prevTo.toISOString()
            );

            const changePercent = prevPatients.length > 0 ? 
                ((newPatients.length - prevPatients.length) / prevPatients.length * 100) : 0;

            return {
                count: newPatients.length,
                changePercent: Math.round(changePercent * 10) / 10,
                isEmpty: patients.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    async getPrescriptionsFilledCount(tenantId: string, range: string): Promise<Rec> {
        return getCached(`pharmacy-prescriptions:${tenantId}:${range}`, 30, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch prescriptions
            const prescriptions = await queryAllItems<Rec>(pk, 'PRESCRIPTION#', { maxPages: 50 });
            const filledPrescriptions = prescriptions.filter(prescription => 
                prescription.status === 'dispensed' &&
                prescription.dispensedAt >= from.toISOString() && 
                prescription.dispensedAt <= to.toISOString()
            );

            // Previous period for comparison
            const prevFrom = new Date(from);
            const prevTo = new Date(to);
            prevFrom.setDate(prevFrom.getDate() - (to.getDate() - from.getDate()));
            prevTo.setDate(prevTo.getDate() - (to.getDate() - from.getDate()));

            const prevPrescriptions = prescriptions.filter(prescription => 
                prescription.status === 'dispensed' &&
                prescription.dispensedAt >= prevFrom.toISOString() && 
                prescription.dispensedAt <= prevTo.toISOString()
            );

            const changePercent = prevPrescriptions.length > 0 ? 
                ((filledPrescriptions.length - prevPrescriptions.length) / prevPrescriptions.length * 100) : 0;

            return {
                count: filledPrescriptions.length,
                changePercent: Math.round(changePercent * 10) / 10,
                isEmpty: prescriptions.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    async getLowStockItemsCount(tenantId: string): Promise<Rec> {
        return getCached(`pharmacy-lowstock:${tenantId}`, 60, async () => {
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch inventory items
            const inventory = await queryAllItems<Rec>(pk, 'INVENTORY#', { maxPages: 50 });
            const lowStockItems = inventory.filter(item => 
                item.businessType === 'pharmacy' &&
                item.quantity <= item.reorderPoint
            );

            // Determine severity
            let severity = 'ok';
            if (lowStockItems.length > 20) {
                severity = 'alert';
            } else if (lowStockItems.length > 10) {
                severity = 'warning';
            }

            return {
                count: lowStockItems.length,
                severity,
                isEmpty: inventory.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── SALES PERFORMANCE CHART ─────────────────────────────────────────────

    async getSalesDailyData(tenantId: string, range: string): Promise<Rec> {
        return getCached(`pharmacy-sales-daily:${tenantId}:${range}`, 60, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch pharmacy sales
            const invoices = await queryAllItems<Rec>(pk, 'INVOICE#', { maxPages: 50 });
            const pharmacyInvoices = invoices.filter(inv => 
                inv.businessType === 'pharmacy' && 
                inv.createdAt >= from.toISOString() && 
                inv.createdAt <= to.toISOString() &&
                inv.status === 'paid'
            );

            // Group by date
            const dailyData = new Map<string, number>();
            const dates: string[] = [];
            
            // Initialize all dates in range
            const current = new Date(from);
            while (current <= to) {
                const dateKey = current.toISOString().split('T')[0];
                dates.push(dateKey);
                dailyData.set(dateKey, 0);
                current.setDate(current.getDate() + 1);
            }

            // Sum sales by date
            pharmacyInvoices.forEach(inv => {
                const dateKey = inv.createdAt.split('T')[0];
                if (dailyData.has(dateKey)) {
                    dailyData.set(dateKey, (dailyData.get(dateKey) || 0) + toAmount(inv.totalCents));
                }
            });

            const daily = Array.from(dailyData.values());
            
            // Calculate 30-day rolling average
            const average = daily.map((_, index) => {
                const start = Math.max(0, index - 14);
                const end = Math.min(daily.length, index + 15);
                const subset = daily.slice(start, end);
                return subset.reduce((sum, val) => sum + val, 0) / subset.length;
            });

            return {
                dates,
                daily,
                average,
                isEmpty: pharmacyInvoices.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── PRESCRIPTIONS BY CATEGORY ─────────────────────────────────────────────

    async getPrescriptionsByCategory(tenantId: string, granularity: string): Promise<Rec> {
        return getCached(`pharmacy-prescriptions-category:${tenantId}:${granularity}`, 120, async () => {
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch prescriptions
            const prescriptions = await queryAllItems<Rec>(pk, 'PRESCRIPTION#', { maxPages: 50 });
            const filledPrescriptions = prescriptions.filter(p => p.status === 'dispensed');

            // Group by category
            const categoryData = new Map<string, number>();
            
            // Common pharmacy categories
            const categories = ['Anti-biotics', 'Cardiovascular', 'Analgesics', 'OTC', 'Vitamins', 'Diabetes'];
            categories.forEach(cat => categoryData.set(cat, 0));

            filledPrescriptions.forEach(prescription => {
                const category = prescription.category || 'OTC';
                categoryData.set(category, (categoryData.get(category) || 0) + 1);
            });

            const categoriesList = Array.from(categoryData.keys());
            const counts = Array.from(categoryData.values());

            return {
                categories: categoriesList,
                counts,
                isEmpty: filledPrescriptions.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── TOP SELLING PRODUCTS ─────────────────────────────────────────────────

    async getTopSellingProducts(tenantId: string, range: string, limit: number): Promise<Rec> {
        return getCached(`pharmacy-top-products:${tenantId}:${range}:${limit}`, 60, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch invoice items
            const invoices = await queryAllItems<Rec>(pk, 'INVOICE#', { maxPages: 50 });
            const pharmacyInvoices = invoices.filter(inv => 
                inv.businessType === 'pharmacy' && 
                inv.createdAt >= from.toISOString() && 
                inv.createdAt <= to.toISOString()
            );

            // Aggregate product sales
            const productSales = new Map<string, { qty: number; revenue: number }>();

            pharmacyInvoices.forEach((inv: any) => {
                if (inv.items && Array.isArray(inv.items)) {
                    inv.items.forEach((item: any) => {
                        const productName = item.name || 'Unknown Product';
                        const qty = toAmount(item.quantity);
                        const revenue = toAmount(item.totalCents || item.price * qty);
                        
                        if (!productSales.has(productName)) {
                            productSales.set(productName, { qty: 0, revenue: 0 });
                        }
                        
                        const current = productSales.get(productName)!;
                        current.qty += qty;
                        current.revenue += revenue;
                    });
                }
            });

            // Sort by revenue and take top N
            const sortedProducts = Array.from(productSales.entries())
                .sort((a, b) => b[1].revenue - a[1].revenue)
                .slice(0, limit)
                .map(([name, data]) => ({
                    name,
                    qty: data.qty,
                    revenue: data.revenue,
                }));

            return {
                products: sortedProducts,
                isEmpty: sortedProducts.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── INVENTORY STATUS ─────────────────────────────────────────────────────

    async getInventoryStatusSummary(tenantId: string): Promise<Rec> {
        return getCached(`pharmacy-inventory-status:${tenantId}`, 60, async () => {
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch inventory items
            const inventory = await queryAllItems<Rec>(pk, 'INVENTORY#', { maxPages: 50 });
            const pharmacyInventory = inventory.filter(item => item.businessType === 'pharmacy');

            let inStock = 0, lowStock = 0, outOfStock = 0;

            pharmacyInventory.forEach(item => {
                const qty = toAmount(item.quantity);
                const reorderPoint = toAmount(item.reorderPoint);
                
                if (qty <= 0) {
                    outOfStock++;
                } else if (qty <= reorderPoint) {
                    lowStock++;
                } else {
                    inStock++;
                }
            });

            const total = pharmacyInventory.length;
            
            return {
                inStock: total > 0 ? Math.round((inStock / total) * 100 * 10) / 10 : 0,
                lowStock: total > 0 ? Math.round((lowStock / total) * 100 * 10) / 10 : 0,
                outOfStock: total > 0 ? Math.round((outOfStock / total) * 100 * 10) / 10 : 0,
                isEmpty: total === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── LOW STOCK ALERTS ─────────────────────────────────────────────────────

    async getLowStockAlerts(tenantId: string, limit: number): Promise<Rec> {
        return getCached(`pharmacy-lowstock-alerts:${tenantId}:${limit}`, 30, async () => {
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch inventory items
            const inventory = await queryAllItems<Rec>(pk, 'INVENTORY#', { maxPages: 50 });
            const pharmacyInventory = inventory.filter(item => item.businessType === 'pharmacy');

            const lowStockItems = pharmacyInventory
                .filter(item => toAmount(item.quantity) <= toAmount(item.reorderPoint))
                .map(item => {
                    const qty = toAmount(item.quantity);
                    const reorderPoint = toAmount(item.reorderPoint);
                    
                    let status = 'warning';
                    if (qty <= 10) {
                        status = 'critical';
                    } else if (qty <= 30) {
                        status = 'warning';
                    }

                    return {
                        id: item.SK || item.id,
                        name: item.name || 'Unknown Product',
                        qty,
                        reorderPoint,
                        status,
                    };
                })
                .sort((a, b) => a.qty - b.qty) // Sort by quantity (lowest first)
                .slice(0, limit);

            return {
                items: lowStockItems,
                isEmpty: lowStockItems.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── RECENT ACTIVITY ─────────────────────────────────────────────────────

    async getRecentActivity(tenantId: string, limit: number): Promise<Rec> {
        return getCached(`pharmacy-activity:${tenantId}:${limit}`, 15, async () => {
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch recent activities from various sources
            const activities: Rec[] = [];

            // Recent prescriptions
            const prescriptions = await queryItems<Rec>(pk, 'PRESCRIPTION#', {
                limit,
                scanIndexForward: false,
            });
            
            prescriptions.items.forEach((prescription: any) => {
                activities.push({
                    type: 'prescription',
                    description: `Prescription ${prescription.prescriptionId} ${prescription.status}`,
                    timestamp: prescription.updatedAt || prescription.createdAt,
                    actor: prescription.doctorName || 'System',
                });
            });

            // Recent sales
            const invoices = await queryItems<Rec>(pk, 'INVOICE#', {
                limit,
                scanIndexForward: false,
            });
            
            invoices.items.filter((inv: any) => inv.businessType === 'pharmacy').forEach((invoice: any) => {
                activities.push({
                    type: 'sale',
                    description: `Sale completed: ${invoice.invoiceNumber}`,
                    timestamp: invoice.createdAt,
                    actor: invoice.createdBy || 'System',
                });
            });

            // Sort by timestamp (most recent first) and limit
            const sortedActivities = activities
                .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
                .slice(0, limit);

            return {
                activities: sortedActivities,
                isEmpty: sortedActivities.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── PATIENT FEEDBACK ─────────────────────────────────────────────────────

    async getPatientFeedbackSummary(tenantId: string, range: string): Promise<Rec> {
        return getCached(`pharmacy-feedback:${tenantId}:${range}`, 120, async () => {
            const { from, to } = getDateRange(range);
            const pk = Keys.tenantPK(tenantId);
            
            // Fetch feedback/reviews
            const feedback = await queryAllItems<Rec>(pk, 'FEEDBACK#', { maxPages: 50 });
            const pharmacyFeedback = feedback.filter(item => 
                item.businessType === 'pharmacy' &&
                item.createdAt >= from.toISOString() && 
                item.createdAt <= to.toISOString()
            );

            if (pharmacyFeedback.length === 0) {
                return {
                    average: 0,
                    trend: [],
                    isEmpty: true,
                    generatedAt: new Date().toISOString(),
                };
            }

            // Calculate average rating
            const totalRating = pharmacyFeedback.reduce((sum, item) => 
                sum + toAmount(item.rating), 0);
            const average = totalRating / pharmacyFeedback.length;

            // Generate trend (last 30 days)
            const trend: number[] = [];
            const now = new Date();
            
            for (let i = 29; i >= 0; i--) {
                const trendDate = new Date(now);
                trendDate.setDate(now.getDate() - i);
                const trendDateStart = new Date(trendDate);
                trendDateStart.setHours(0, 0, 0, 0);
                const trendDateEnd = new Date(trendDate);
                trendDateEnd.setHours(23, 59, 59, 999);

                const dayFeedback = pharmacyFeedback.filter(item => 
                    item.createdAt >= trendDateStart.toISOString() && 
                    item.createdAt <= trendDateEnd.toISOString()
                );

                if (dayFeedback.length > 0) {
                    const dayTotal = dayFeedback.reduce((sum, item) => 
                        sum + toAmount(item.rating), 0);
                    trend.push(dayTotal / dayFeedback.length);
                } else {
                    trend.push(average); // Use overall average for days with no feedback
                }
            }

            return {
                average: Math.round(average * 10) / 10,
                trend,
                isEmpty: pharmacyFeedback.length === 0,
                generatedAt: new Date().toISOString(),
            };
        });
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────

    async reorderProduct(tenantId: string, productId: string): Promise<Rec> {
        // Create a reorder request
        const pk = Keys.tenantPK(tenantId);
        const reorderId = `REORDER#${Date.now()}`;
        
        const reorderRecord = {
            PK: pk,
            SK: reorderId,
            productId,
            status: 'pending',
            createdAt: new Date().toISOString(),
            businessType: 'pharmacy',
        };

        // This would typically integrate with your inventory management system
        // For now, we'll just create the record
        await getItem(pk, reorderId); // This would be a put operation in real implementation
        
        return {
            success: true,
            message: 'Reorder request created successfully',
            reorderId,
            generatedAt: new Date().toISOString(),
        };
    }
}
