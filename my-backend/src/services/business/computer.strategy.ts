// ============================================================================
// Computer Shop Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class ComputerStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [jobCardSummary, openJobCards, componentSerials, recentRma] = await Promise.all([
            this.getJobCardSummary(tenantId),
            this.getOpenJobCards(tenantId),
            this.getComponentSerialSummary(tenantId),
            this.getRecentRma(tenantId),
        ]);

        sections.unshift({
            id: 'computer_job_summary',
            title: 'Repair Job Summary',
            type: 'metric',
            data: jobCardSummary,
        });

        sections.unshift({
            id: 'computer_open_job_cards',
            title: 'Open Job Cards',
            type: 'alert',
            data: openJobCards,
        });

        sections.unshift({
            id: 'computer_component_serials',
            title: 'Component Serial Tracking',
            type: 'metric',
            data: componentSerials,
        });

        sections.push({
            id: 'computer_recent_rma',
            title: 'Recent RMAs',
            type: 'table',
            data: recentRma,
        });

        return sections;
    }

    private async getJobCardSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'COMPJOBCARD#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        const byStatus: Record<string, number> = {};
        for (const row of result.items) {
            const status = String(row.status || 'UNKNOWN');
            byStatus[status] = (byStatus[status] || 0) + 1;
        }

        return {
            total_job_cards: result.items.length,
            intakes: byStatus.INTAKE || 0,
            diagnosis: byStatus.DIAGNOSIS || 0,
            awaiting_parts: byStatus.AWAITING_PARTS || 0,
            repairing: byStatus.REPAIRING || 0,
            qc: byStatus.QC || 0,
            delivered: byStatus.DELIVERED || 0,
        };
    }

    private async getOpenJobCards(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'COMPJOBCARD#', {
            filterExpression: '#s <> :delivered AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: { ':delivered': 'DELIVERED', ':false': false },
            limit: 20,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(card => ({
                id: card.id,
                device_brand: card.deviceBrand,
                device_model: card.deviceModel,
                serial_number: card.serialNumber,
                status: card.status,
                reported_issue: card.reportedIssue,
                created_at: card.createdAt,
            }));
    }

    private async getComponentSerialSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'COMPSERIAL#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
        });

        const invoiceIds = new Set<string>();
        const productIds = new Set<string>();

        for (const row of result.items) {
            if (row.invoiceId) invoiceIds.add(String(row.invoiceId));
            if (row.productId) productIds.add(String(row.productId));
        }

        return {
            tracked_components: result.items.length,
            unique_components: productIds.size,
            invoices_with_serials: invoiceIds.size,
        };
    }

    private async getRecentRma(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'RMA#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit: 30,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(rma => ({
                id: rma.id,
                brand: rma.brand,
                status: rma.status,
                oem_rma_number: rma.oemRmaNumber || null,
                reason: rma.reason,
                created_at: rma.createdAt,
            }));
    }
}