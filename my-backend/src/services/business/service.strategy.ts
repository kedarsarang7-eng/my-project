// ============================================================================
// Service / Repair Center Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class ServiceStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [jobSummary, overdueJobs, partsUsed, recentJobs] = await Promise.all([
            this.getJobSummary(tenantId),
            this.getOverdueJobs(tenantId),
            this.getPartsUsage(tenantId),
            this.getRecentJobs(tenantId),
        ]);

        sections.unshift({
            id: 'service_job_summary',
            title: 'Repair Job Summary',
            type: 'metric',
            data: jobSummary,
        });

        sections.unshift({
            id: 'service_overdue_jobs',
            title: 'Overdue Jobs',
            type: 'alert',
            data: overdueJobs,
        });

        sections.push({
            id: 'service_recent_jobs',
            title: 'Recent Repair Jobs',
            type: 'table',
            data: recentJobs,
        });

        sections.push({
            id: 'service_parts_usage',
            title: 'Parts Usage',
            type: 'table',
            data: partsUsed,
        });

        return sections;
    }

    private async getJobSummary(tenantId: string) {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString();
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERVICEJOB#', {
            filterExpression: 'createdAt >= :since AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':since': thirtyDaysAgo, ':false': false },
        });

        let open = 0;
        let inProgress = 0;
        let delivered = 0;

        for (const job of result.items) {
            const status = String(job.status || '').toLowerCase();
            if (status === 'delivered') {
                delivered++;
            } else if (['assigned', 'in_progress', 'in-progress', 'repairing', 'pending'].includes(status)) {
                inProgress++;
            } else {
                open++;
            }
        }

        return {
            totalJobs: result.items.length,
            openJobs: open,
            inProgressJobs: inProgress,
            deliveredJobs: delivered,
        };
    }

    private async getOverdueJobs(tenantId: string) {
        const now = new Date().toISOString();
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERVICEJOB#', {
            filterExpression: 'estimatedDeliveryDate < :now AND NOT #s IN (:delivered, :cancelled) AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeNames: { '#s': 'status' },
            expressionAttributeValues: {
                ':now': now,
                ':delivered': 'delivered',
                ':cancelled': 'cancelled',
                ':false': false,
            },
            limit: 15,
        });

        return result.items
            .sort((a, b) => (a.estimatedDeliveryDate || '').localeCompare(b.estimatedDeliveryDate || ''))
            .slice(0, 10)
            .map(job => ({
                id: job.id,
                customer_name: job.customerName || job.customerId || 'Unknown',
                device: [job.deviceMake, job.deviceModel].filter(Boolean).join(' '),
                status: job.status,
                estimated_delivery_date: job.estimatedDeliveryDate,
                estimated_cost_cents: Number(job.estimatedCostCents || 0),
            }));
    }

    private async getPartsUsage(tenantId: string) {
        const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000).toISOString();
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERVICEJOBPART#', {
            filterExpression: 'createdAt >= :since',
            expressionAttributeValues: { ':since': ninetyDaysAgo },
        });

        const byItem: Record<string, { name: string; qty: number; total: number }> = {};
        for (const part of result.items) {
            const key = part.inventoryId || part.name || part.id;
            if (!byItem[key]) {
                byItem[key] = { name: part.name || key, qty: 0, total: 0 };
            }
            byItem[key].qty += Number(part.quantity || 0);
            byItem[key].total += Number(part.totalPriceCents || 0);
        }

        return Object.values(byItem)
            .sort((a, b) => b.total - a.total)
            .slice(0, 10)
            .map(item => ({
                name: item.name,
                quantity_used: item.qty,
                total_spend_cents: item.total,
            }));
    }

    private async getRecentJobs(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SERVICEJOB#', {
            filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':false': false },
            limit: 25,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(job => ({
                id: job.id,
                customer_name: job.customerName || job.customerId || 'Unknown',
                device_make: job.deviceMake,
                device_model: job.deviceModel,
                status: job.status,
                estimated_cost_cents: Number(job.estimatedCostCents || 0),
                created_at: job.createdAt,
            }));
    }
}