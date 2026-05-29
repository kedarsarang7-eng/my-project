// ============================================================================
// Clinic Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class ClinicStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [todayAppointments, followUps, labOrders, recentSoapNotes] = await Promise.all([
            this.getTodayAppointments(tenantId),
            this.getPendingFollowUps(tenantId),
            this.getOpenLabOrders(tenantId),
            this.getRecentSoapNotes(tenantId),
        ]);

        sections.unshift({
            id: 'clinic_today_flow',
            title: 'Today’s Clinic Flow',
            type: 'metric',
            data: {
                appointments: todayAppointments.total,
                waiting: todayAppointments.waiting,
                completed: todayAppointments.completed,
                followUpsDue: followUps.length,
                openLabOrders: labOrders.length,
            },
        });

        sections.unshift({
            id: 'clinic_followups',
            title: 'Upcoming Follow-Ups',
            type: 'alert',
            data: followUps,
        });

        sections.push({
            id: 'clinic_lab_orders',
            title: 'Open Lab Orders',
            type: 'table',
            data: labOrders,
        });

        sections.push({
            id: 'clinic_recent_soap',
            title: 'Recent SOAP Notes',
            type: 'list',
            data: recentSoapNotes,
        });

        return sections;
    }

    private async getTodayAppointments(tenantId: string) {
        const today = new Date().toISOString().substring(0, 10);
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'APPOINTMENT#', {
            filterExpression: 'appointmentDate = :today AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':today': today, ':false': false },
        });

        const total = result.items.length;
        const waiting = result.items.filter(a => a.status === 'waiting').length;
        const completed = result.items.filter(a => a.status === 'completed').length;

        return { total, waiting, completed };
    }

    private async getPendingFollowUps(tenantId: string) {
        const today = new Date().toISOString().substring(0, 10);
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'FOLLOWUP#', {
            filterExpression: 'followUpDate >= :today AND status = :status',
            expressionAttributeValues: { ':today': `${today}T00:00:00.000Z`, ':status': 'scheduled' },
        });

        return result.items
            .sort((a, b) => (a.followUpDate || '').localeCompare(b.followUpDate || ''))
            .slice(0, 10)
            .map(f => ({
                id: f.id,
                patient_id: f.patientId,
                follow_up_date: f.followUpDate,
                reason: f.reason,
                notes: f.notes,
            }));
    }

    private async getOpenLabOrders(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'LABORDER#', {
            filterExpression: 'status <> :completed AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':completed': 'completed', ':false': false },
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(o => ({
                id: o.id,
                patient_id: o.patientId,
                priority: o.priority,
                status: o.status,
                tests: (o.tests || []).map((t: any) => t.testName).join(', '),
                created_at: o.createdAt,
            }));
    }

    private async getRecentSoapNotes(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'SOAPNOTE#', {
            limit: 20,
        });

        return result.items
            .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
            .slice(0, 10)
            .map(s => ({
                id: s.id,
                patient_id: s.patientId,
                assessment: s.assessment,
                plan: s.plan,
                created_at: s.createdAt,
            }));
    }
}