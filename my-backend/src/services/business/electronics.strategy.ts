// ============================================================================
// Electronics / Mobile Shop Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class ElectronicsStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [serialSummary, recentSerials, warrantySummary, imeiSummary] = await Promise.all([
            this.getSerialSummary(tenantId),
            this.getRecentSerials(tenantId),
            this.getWarrantySummary(tenantId),
            this.getImeiSummary(tenantId),
        ]);

        sections.unshift({
            id: 'electronics_serial_summary',
            title: 'Serial Tracking Summary',
            type: 'metric',
            data: serialSummary,
        });

        sections.unshift({
            id: 'electronics_warranty_alerts',
            title: 'Warranty Alerts',
            type: 'alert',
            data: warrantySummary,
        });

        sections.unshift({
            id: 'electronics_imei_summary',
            title: 'IMEI Coverage',
            type: 'metric',
            data: imeiSummary,
        });

        sections.push({
            id: 'electronics_recent_serials',
            title: 'Recent Serial / IMEI Sales',
            type: 'table',
            data: recentSerials,
        });

        return sections;
    }

    private async getSerialSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        const productIds = new Set<string>();
        const invoices = new Set<string>();

        for (const row of result.items) {
            if (row.productId) productIds.add(String(row.productId));
            if (row.invoiceId) invoices.add(String(row.invoiceId));
        }

        return {
            tracked_serials: result.items.length,
            unique_products: productIds.size,
            unique_invoices: invoices.size,
        };
    }

    private async getRecentSerials(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit: 50,
        });

        return result.items
            .sort((a, b) => (b.soldAt || b.createdAt || '').localeCompare(a.soldAt || a.createdAt || ''))
            .slice(0, 10)
            .map(serial => ({
                serial_or_imei: serial.serialNumber || serial.imei1 || serial.SK?.replace('SERIAL#', '') || '',
                product_name: serial.productName,
                customer_name: serial.customerName,
                invoice_number: serial.invoiceNumber,
                sold_at: serial.soldAt || serial.createdAt,
            }));
    }

    private async getWarrantySummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND attribute_exists(warrantyExpiryDate)',
            expressionAttributeValues: { ':false': false },
            limit: 100,
        });

        const now = Date.now();
        const expiringSoon = result.items.filter(row => {
            const exp = row.warrantyExpiryDate ? Date.parse(row.warrantyExpiryDate) : NaN;
            return !Number.isNaN(exp) && exp >= now && exp <= now + 30 * 86400000;
        });

        const expired = result.items.filter(row => {
            const exp = row.warrantyExpiryDate ? Date.parse(row.warrantyExpiryDate) : NaN;
            return !Number.isNaN(exp) && exp < now;
        });

        return {
            tracked_warranties: result.items.length,
            expiring_in_30_days: expiringSoon.length,
            expired_warranties: expired.length,
        };
    }

    private async getImeiSummary(tenantId: string) {
        const mobile = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND attribute_exists(imei1)',
            expressionAttributeValues: { ':false': false },
        });

        const electronics = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND attribute_exists(serialNumber)',
            expressionAttributeValues: { ':false': false },
        });

        return {
            imei_sales: mobile.items.length,
            serial_sales: electronics.items.length,
        };
    }
}