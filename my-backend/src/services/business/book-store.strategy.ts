// ============================================================================
// Book Store Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class BookStoreStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [lowStockBooks, pendingReturns, institutionalOrders, openConsignments] = await Promise.all([
            this.getLowStockBooks(tenantId),
            this.getPendingReturns(tenantId),
            this.getInstitutionalOrders(tenantId),
            this.getOpenConsignments(tenantId),
        ]);

        sections.unshift({
            id: 'bookstore_book_flow',
            title: 'Book Store Snapshot',
            type: 'metric',
            data: {
                lowStockBooks: lowStockBooks.length,
                pendingReturns: pendingReturns.length,
                institutionalOrders: institutionalOrders.length,
                openConsignments: openConsignments.length,
            },
        });

        sections.unshift({
            id: 'bookstore_low_stock',
            title: 'Low Stock Books',
            type: 'alert',
            data: lowStockBooks,
        });

        sections.push({
            id: 'bookstore_returns',
            title: 'Pending Publisher Returns',
            type: 'table',
            data: pendingReturns,
        });

        sections.push({
            id: 'bookstore_institutional_orders',
            title: 'Institutional Orders',
            type: 'table',
            data: institutionalOrders,
        });

        sections.push({
            id: 'bookstore_consignments',
            title: 'Open Consignments',
            type: 'table',
            data: openConsignments,
        });

        return sections;
    }

    private async getLowStockBooks(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND (attribute_not_exists(isActive) OR isActive = :true)',
            expressionAttributeValues: { ':false': false, ':true': true },
        });

        return result.items
            .filter(p => (Number(p.currentStock) || 0) <= (Number(p.lowStockThreshold) || 0))
            .sort((a, b) => (Number(a.currentStock) || 0) - (Number(b.currentStock) || 0))
            .slice(0, 10)
            .map(p => ({
                id: p.id,
                name: p.name,
                isbn: p.isbn,
                author: p.author,
                current_stock: p.currentStock,
                threshold: p.lowStockThreshold,
            }));
    }

    private async getPendingReturns(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'BOOKRETURN#', {
            filterExpression: 'status = :draft OR status = :pending',
            expressionAttributeValues: { ':draft': 'draft', ':pending': 'pending' },
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(r => ({
                id: r.id,
                vendor_name: r.vendorName,
                return_date: r.returnDate,
                total_amount: r.totalAmount,
                status: r.status,
            }));
    }

    private async getInstitutionalOrders(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'INSTORDER#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(o => ({
                id: o.id,
                institution_name: o.institutionName,
                due_date: o.dueDate,
                total_amount: o.totalAmount,
                status: o.status,
            }));
    }

    private async getOpenConsignments(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CONSIGNMENT#', {
            filterExpression: 'status = :open OR status = :partial',
            expressionAttributeValues: { ':open': 'open', ':partial': 'partial' },
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(c => ({
                id: c.id,
                vendor_name: c.vendorName,
                received_date: c.receivedDate,
                total_amount: c.totalAmount,
                status: c.status,
            }));
    }
}