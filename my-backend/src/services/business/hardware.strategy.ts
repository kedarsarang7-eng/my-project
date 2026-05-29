// ============================================================================
// Hardware Shop Strategy — Delivery Challans & Inventory Flow (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class HardwareStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [challanSummary, pendingChallans, recentChallans] = await Promise.all([
            this.getChallanSummary(tenantId),
            this.getPendingChallans(tenantId),
            this.getRecentChallans(tenantId),
        ]);

        sections.unshift({
            id: 'hardware_challan_summary',
            title: 'Delivery Challan Summary',
            type: 'metric',
            data: challanSummary,
        });

        sections.unshift({
            id: 'hardware_pending_challans',
            title: 'Pending Deliveries',
            type: 'alert',
            data: pendingChallans,
        });

        sections.push({
            id: 'hardware_recent_challans',
            title: 'Recent Challans',
            type: 'table',
            data: recentChallans,
        });

        return sections;
    }

    private async getChallanSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CHALLAN#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        let dispatched = 0;
        let delivered = 0;
        let draft = 0;

        for (const challan of result.items) {
            const status = String(challan.status || '').toLowerCase();
            if (status === 'delivered') delivered++;
            else if (status === 'dispatched') dispatched++;
            else draft++;
        }

        return {
            totalChallans: result.items.length,
            dispatchedChallans: dispatched,
            deliveredChallans: delivered,
            draftChallans: draft,
        };
    }

    private async getPendingChallans(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CHALLAN#', {
            filterExpression: '#s <> :delivered AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':delivered': 'delivered', ':false': false },
            limit: 20,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(challan => ({
                id: challan.id,
                challan_number: challan.challanNumber,
                customer_name: challan.customerName,
                delivery_address: challan.deliveryAddress,
                status: challan.status,
                items_count: Number(challan.itemsCount || 0),
                created_at: challan.createdAt,
            }));
    }

    private async getRecentChallans(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'CHALLAN#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit: 25,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(challan => ({
                id: challan.id,
                challan_number: challan.challanNumber,
                customer_name: challan.customerName,
                status: challan.status,
                items_count: Number(challan.itemsCount || 0),
                vehicle_number: challan.vehicleNumber,
                created_at: challan.createdAt,
            }));
    }
}