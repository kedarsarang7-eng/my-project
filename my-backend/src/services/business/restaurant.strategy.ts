// ============================================================================
// Restaurant Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { BaseStrategy } from './base.strategy';
import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { logger } from '../../utils/logger';

export class RestaurantStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        // 1. Table Occupancy
        try {
            const tables = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'RESTOTABLE#', {
                filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
                expressionAttributeValues: { ':false': false },
            });
            const occupied = tables.items.filter(t => t.status === 'occupied').length;
            const total = tables.items.length;
            sections.push({ id: 'resto-table-occupancy', title: 'Table Occupancy', type: 'metric', data: { occupiedCount: occupied, totalCount: total, occupancyPercent: total > 0 ? Math.round((occupied / total) * 100) : 0 } });
        } catch (err) {
            logger.warn('RestaurantStrategy: table occupancy failed', { error: (err as Error).message });
            sections.push({ id: 'resto-table-occupancy', title: 'Table Occupancy', type: 'metric', data: { occupiedCount: 0, totalCount: 0, occupancyPercent: 0 } });
        }

        // 2. Avg Ticket Size
        try {
            const today = new Date().toISOString().substring(0, 10);
            const bills = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'RESTOBILL#', {
                filterExpression: 'begins_with(createdAt, :today) AND #s <> :voided',
                expressionAttributeNames: { '#s': 'status' },
                expressionAttributeValues: { ':today': today, ':voided': 'voided' },
            });
            const totalCents = bills.items.reduce((sum, b) => sum + Number(b.totalAmountCents || 0), 0);
            const avg = bills.items.length > 0 ? Math.round(totalCents / bills.items.length) : 0;
            sections.push({ id: 'resto-avg-ticket', title: 'Avg Ticket Size (Today)', type: 'metric', data: { avgTicketCents: avg, billCount: bills.items.length } });
        } catch (err) {
            logger.warn('RestaurantStrategy: avg ticket failed', { error: (err as Error).message });
            sections.push({ id: 'resto-avg-ticket', title: 'Avg Ticket Size (Today)', type: 'metric', data: { avgTicketCents: 0, billCount: 0 } });
        }

        // 3. Active KOTs
        try {
            const today = new Date().toISOString().substring(0, 10);
            const kots = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'KOT#', {
                filterExpression: 'begins_with(createdAt, :today)',
                expressionAttributeValues: { ':today': today },
            });
            const pending = kots.items.filter(k => k.kotStatus === 'preparing').length;
            const inProgress = 0; // Handled per-item individually now
            sections.push({ id: 'resto-kot-status', title: 'Active KOTs', type: 'metric', data: { pendingKots: pending, inProgressKots: inProgress, activeKots: pending + inProgress } });
        } catch (err) {
            logger.warn('RestaurantStrategy: KOT query failed', { error: (err as Error).message });
            sections.push({ id: 'resto-kot-status', title: 'Active KOTs', type: 'metric', data: { pendingKots: 0, inProgressKots: 0, activeKots: 0 } });
        }

        return sections;
    }
}
