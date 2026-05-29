// ============================================================================
// Billing Service — Migrated from sls/backend
// ============================================================================
// Migrated from: sls/backend/src/services/billingService.ts
// Adapted for my-backend Lambda architecture

import {
    getItem, putItem, queryItems, queryAllItems, updateItem,
} from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

// ---- Types ----

export interface BillingEvent {
    id: string;
    license_key: string | null;
    license_id: string | null;
    event_type: string;
    from_plan: string | null;
    to_plan: string | null;
    amount_cents: number;
    currency: string;
    gst_rate: number;
    gst_amount_cents: number;
    total_amount_cents: number;
    payment_method: string | null;
    payment_reference: string | null;
    invoice_number: string | null;
    client_name: string | null;
    client_email: string | null;
    client_gstin: string | null;
    client_state_code: string | null;
    metadata: Record<string, any>;
    created_by: string | null;
    status: string;
    idempotency_key: string | null;
    created_at: string;
    updated_at: string;
    voided_at: string | null;
    voided_by: string | null;
    void_reason: string | null;
}

// ---- DynamoDB Key Helpers ----

const BillingKeys = {
    pk: () => 'BILLING',
    eventSK: (id: string) => `EVENT#${id}`,
    idempotencyPK: (key: string) => `IDEMPOTENCY#BILLING`,
    idempotencySK: (key: string) => `KEY#${key}`,
    invoiceSeqPK: () => 'BILLING_SEQ',
    invoiceSeqSK: () => 'COUNTER',
    loginHistoryPK: () => 'ADMIN_LOGIN_HISTORY',
    loginHistorySK: (ts: string) => `LOG#${ts}`,
    auditPK: () => 'ADMIN_AUDIT',
    auditSK: (ts: string) => `LOG#${ts}`,
};

// ---- Financial Rounding ----

export function bankersRound(value: number): number {
    if (!Number.isFinite(value)) return 0;
    const floored = Math.floor(value);
    const decimal = value - floored;
    if (Math.abs(decimal - 0.5) < 1e-10) {
        return floored % 2 === 0 ? floored : floored + 1;
    }
    return Math.round(value);
}

// ---- Invoice State Machine ----

const VALID_TRANSITIONS: Record<string, string[]> = {
    'draft': ['confirmed', 'void'],
    'confirmed': ['paid', 'void', 'refunded'],
    'paid': ['refunded', 'disputed'],
    'void': [],
    'refunded': [],
    'disputed': ['paid', 'refunded', 'void'],
};

export function isValidTransition(from: string, to: string): boolean {
    const allowed = VALID_TRANSITIONS[from];
    if (!allowed) return false;
    return allowed.includes(to);
}

// ---- Invoice Number Generation (Atomic via DynamoDB Counter) ----

async function _generateInvoiceNumber(eventType: string): Promise<string> {
    const prefix = eventType === 'refund' ? 'CR' : 'DX';
    const now = new Date();
    const yearMonth = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}`;

    // Atomic counter via DynamoDB UpdateItem
    const result = await updateItem(
        BillingKeys.invoiceSeqPK(),
        BillingKeys.invoiceSeqSK(),
        {
            updateExpression: 'SET #seq = if_not_exists(#seq, :zero) + :inc, entityType = :et',
            expressionAttributeValues: {
                ':zero': 0,
                ':inc': 1,
                ':et': 'invoice_counter',
            },
            expressionAttributeNames: {
                '#seq': 'sequence',
            },
        }
    );

    const sequence = (result?.sequence || 1).toString().padStart(6, '0');
    return `${prefix}${yearMonth}-${sequence}`;
}

// ---- Billing Event Operations ----

export async function createBillingEvent(params: {
    event_type: string;
    from_plan?: string | null;
    to_plan?: string | null;
    amount_cents: number;
    currency?: string;
    gst_rate?: number;
    payment_method?: string | null;
    payment_reference?: string | null;
    client_name?: string | null;
    client_email?: string | null;
    client_gstin?: string | null;
    client_state_code?: string | null;
    metadata?: Record<string, any>;
    created_by?: string | null;
    idempotency_key?: string | null;
    license_key?: string | null;
    license_id?: string | null;
}): Promise<BillingEvent> {
    const id = uuidv4();
    const now = new Date().toISOString();
    const currency = params.currency || 'INR';
    const gst_rate = params.gst_rate ?? 18; // Default 18% GST

    // Calculate GST
    const gst_amount_cents = bankersRound(params.amount_cents * (gst_rate / 100));
    const total_amount_cents = params.amount_cents + gst_amount_cents;

    // Generate invoice number
    const invoice_number = await _generateInvoiceNumber(params.event_type);

    const event: BillingEvent = {
        id,
        license_key: params.license_key || null,
        license_id: params.license_id || null,
        event_type: params.event_type,
        from_plan: params.from_plan || null,
        to_plan: params.to_plan || null,
        amount_cents: params.amount_cents,
        currency,
        gst_rate,
        gst_amount_cents,
        total_amount_cents,
        payment_method: params.payment_method || null,
        payment_reference: params.payment_reference || null,
        invoice_number,
        client_name: params.client_name || null,
        client_email: params.client_email || null,
        client_gstin: params.client_gstin || null,
        client_state_code: params.client_state_code || null,
        metadata: params.metadata || {},
        created_by: params.created_by || null,
        status: 'draft',
        idempotency_key: params.idempotency_key || null,
        created_at: now,
        updated_at: now,
        voided_at: null,
        voided_by: null,
        void_reason: null,
    };

    // Check idempotency
    if (params.idempotency_key) {
        const existing = await getItem<any>(
            BillingKeys.idempotencyPK(params.idempotency_key),
            BillingKeys.idempotencySK(params.idempotency_key)
        );
        if (existing) {
            logger.info('Idempotent billing event creation - returning existing', {
                idempotency_key: params.idempotency_key,
                existing_id: existing.billingEventId,
            });
            return existing.billingEvent as BillingEvent;
        }
    }

    // Store billing event
    await putItem({
        PK: BillingKeys.pk(),
        SK: BillingKeys.eventSK(id),
        ...event,
        entityType: 'billing_event',
    });

    // Store idempotency key if provided
    if (params.idempotency_key) {
        await putItem({
            PK: BillingKeys.idempotencyPK(params.idempotency_key),
            SK: BillingKeys.idempotencySK(params.idempotency_key),
            entityType: 'billing_idempotency',
            billingEventId: id,
            billingEvent: event,
            createdAt: now,
            TTL: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60), // 30 days
        });
    }

    logger.info('Billing event created', {
        id,
        event_type: params.event_type,
        amount_cents: params.amount_cents,
        invoice_number,
    });

    return event;
}

// ---- Status Transition ----

export async function transitionBillingStatus(params: {
    event_id: string;
    new_status: string;
    actor: string;
    reason?: string;
}): Promise<BillingEvent> {
    const existing = await getItem<BillingEvent & Record<string, unknown>>(
        BillingKeys.pk(),
        BillingKeys.eventSK(params.event_id),
    );

    if (!existing) {
        throw new Error(`Billing event ${params.event_id} not found`);
    }

    if (!isValidTransition(existing.status, params.new_status)) {
        throw new Error(
            `Invalid status transition: ${existing.status} → ${params.new_status}. ` +
            `Allowed: [${VALID_TRANSITIONS[existing.status]?.join(', ') || 'none'}]`
        );
    }

    const now = new Date().toISOString();
    let updateExpr = 'SET #status = :newStatus, updated_at = :now';
    const exprValues: Record<string, unknown> = {
        ':newStatus': params.new_status,
        ':now': now,
    };
    const exprNames: Record<string, string> = { '#status': 'status' };

    if (params.new_status === 'void') {
        updateExpr += ', voided_at = :voidedAt, voided_by = :actor, void_reason = :reason';
        exprValues[':voidedAt'] = now;
        exprValues[':actor'] = params.actor;
        exprValues[':reason'] = params.reason || null;
    }

    await updateItem(
        BillingKeys.pk(),
        BillingKeys.eventSK(params.event_id),
        {
            updateExpression: updateExpr,
            expressionAttributeValues: exprValues,
            expressionAttributeNames: exprNames,
        }
    );

    // Audit
    await putItem({
        PK: BillingKeys.auditPK(),
        SK: BillingKeys.auditSK(`${now}#${uuidv4()}`),
        entityType: 'audit_log',
        admin_sub: params.actor,
        action: 'transition_billing_status',
        target_type: 'billing_event',
        target_id: params.event_id,
        details: {
            from_status: existing.status,
            to_status: params.new_status,
            reason: params.reason || null,
            invoice_number: existing.invoice_number,
        },
        created_at: now,
    });

    logger.info('Billing event status transitioned', {
        id: params.event_id,
        from: existing.status,
        to: params.new_status,
        actor: params.actor,
    });

    return { ...existing, status: params.new_status } as BillingEvent;
}

// ---- List & Analytics ----

export async function listBillingEvents(params: {
    page?: number;
    limit?: number;
    event_type?: string;
    license_key?: string;
    status?: string;
    from_date?: string;
    to_date?: string;
}): Promise<{ data: BillingEvent[]; total: number }> {
    const { limit = 50 } = params;

    // Query all billing events, apply client-side filtering
    const allEvents = await queryAllItems<BillingEvent>(
        BillingKeys.pk(),
        'EVENT#',
        { maxPages: 5 }
    );

    let filtered = allEvents;
    if (params.event_type) filtered = filtered.filter(e => e.event_type === params.event_type);
    if (params.license_key) filtered = filtered.filter(e => e.license_key === params.license_key);
    if (params.status) filtered = filtered.filter(e => e.status === params.status);
    if (params.from_date) filtered = filtered.filter(e => e.created_at >= params.from_date!);
    if (params.to_date) filtered = filtered.filter(e => e.created_at <= params.to_date!);

    const page = params.page || 1;
    const offset = (page - 1) * limit;
    const paginated = filtered.slice(offset, offset + limit);

    return { data: paginated, total: filtered.length };
}

export async function getRevenueAnalytics(params?: {
    from_date?: string;
    to_date?: string;
}): Promise<{
    total_revenue_cents: number;
    total_gst_cents: number;
    total_events: number;
    by_type: Array<{ event_type: string; count: number; total_cents: number }>;
    by_plan: Array<{ plan: string; count: number; total_cents: number }>;
    monthly_trend: Array<{ month: string; total_cents: number; count: number }>;
}> {
    let events = await queryAllItems<BillingEvent>(
        BillingKeys.pk(),
        'EVENT#',
        { maxPages: 10 }
    );

    if (params?.from_date) events = events.filter(e => e.created_at >= params.from_date!);
    if (params?.to_date) events = events.filter(e => e.created_at <= params.to_date!);

    const total_revenue_cents = events.reduce((sum, e) => sum + (e.amount_cents || 0), 0);
    const total_gst_cents = events.reduce((sum, e) => sum + (e.gst_amount_cents || 0), 0);

    // Group by type
    const typeMap = new Map<string, { count: number; total_cents: number }>();
    const planMap = new Map<string, { count: number; total_cents: number }>();
    const monthMap = new Map<string, { total_cents: number; count: number }>();

    for (const e of events) {
        // By type
        const typeEntry = typeMap.get(e.event_type) || { count: 0, total_cents: 0 };
        typeEntry.count++;
        typeEntry.total_cents += e.total_amount_cents || 0;
        typeMap.set(e.event_type, typeEntry);

        // By plan
        const plan = e.to_plan || e.from_plan || 'unknown';
        const planEntry = planMap.get(plan) || { count: 0, total_cents: 0 };
        planEntry.count++;
        planEntry.total_cents += e.total_amount_cents || 0;
        planMap.set(plan, planEntry);

        // By month
        const month = e.created_at?.substring(0, 7) || 'unknown';
        const monthEntry = monthMap.get(month) || { total_cents: 0, count: 0 };
        monthEntry.count++;
        monthEntry.total_cents += e.total_amount_cents || 0;
        monthMap.set(month, monthEntry);
    }

    return {
        total_revenue_cents,
        total_gst_cents,
        total_events: events.length,
        by_type: Array.from(typeMap.entries()).map(([event_type, v]) => ({ event_type, ...v }))
            .sort((a, b) => b.total_cents - a.total_cents),
        by_plan: Array.from(planMap.entries()).map(([plan, v]) => ({ plan, ...v }))
            .sort((a, b) => b.total_cents - a.total_cents),
        monthly_trend: Array.from(monthMap.entries()).map(([month, v]) => ({ month, ...v }))
            .sort((a, b) => b.month.localeCompare(a.month)).slice(0, 12),
    };
}

// ---- Admin Login Tracking ----

export async function logAdminLogin(params: {
    admin_sub?: string;
    email: string;
    success: boolean;
    failure_reason?: string;
    ip_address?: string;
    user_agent?: string;
    geo_country?: string;
    mfa_used?: boolean;
}): Promise<void> {
    try {
        const now = new Date().toISOString();
        await putItem({
            PK: BillingKeys.loginHistoryPK(),
            SK: BillingKeys.loginHistorySK(`${now}#${uuidv4()}`),
            entityType: 'admin_login',
            admin_sub: params.admin_sub || null,
            email: params.email,
            success: params.success,
            failure_reason: params.failure_reason || null,
            ip_address: params.ip_address || null,
            user_agent: params.user_agent || null,
            geo_country: params.geo_country || null,
            mfa_used: params.mfa_used || false,
            created_at: now,
        });
    } catch (error: any) {
        logger.error('Failed to log admin login', { error: error.message });
    }
}

export async function getLoginHistory(params: {
    page?: number;
    limit?: number;
    email?: string;
    success?: boolean;
}): Promise<{ data: any[]; total: number }> {
    const { page = 1, limit = 50 } = params;

    const items = await queryAllItems<any>(
        BillingKeys.loginHistoryPK(),
        'LOG#',
        { maxPages: 3 }
    );

    let filtered = items;
    if (params.email) filtered = filtered.filter((i: any) => i.email === params.email);
    if (params.success !== undefined) filtered = filtered.filter((i: any) => i.success === params.success);

    const offset = (page - 1) * limit;
    return { data: filtered.slice(offset, offset + limit), total: filtered.length };
}

export async function checkLoginLockout(email: string): Promise<{
    locked: boolean;
    remaining_seconds: number;
    failed_count: number;
}> {
    const LOCKOUT_THRESHOLD = 5;
    const LOCKOUT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes

    try {
        const cutoff = new Date(Date.now() - LOCKOUT_WINDOW_MS).toISOString();

        const items = await queryAllItems<any>(
            BillingKeys.loginHistoryPK(),
            'LOG#',
            {
                maxPages: 2,
            }
        );

        // Filter client-side since we need complex filtering
        const filtered = items.filter((i: any) => 
            i.email === email && i.created_at >= cutoff
        );

        const failures = filtered.filter((i: any) => !i.success);
        const failedCount = failures.length;

        if (failedCount >= LOCKOUT_THRESHOLD) {
            const latestFailure = new Date(failures[0]?.created_at || Date.now());
            const lastSuccess = filtered.find((i: any) => i.success);
            const lastSuccessTime = lastSuccess ? new Date(lastSuccess.created_at) : new Date(0);

            if (lastSuccessTime < latestFailure) {
                const lockoutEnd = new Date(latestFailure.getTime() + LOCKOUT_WINDOW_MS);
                const remainingMs = lockoutEnd.getTime() - Date.now();

                if (remainingMs > 0) {
                    return {
                        locked: true,
                        remaining_seconds: Math.ceil(remainingMs / 1000),
                        failed_count: failedCount,
                    };
                }
            }
        }

        return { locked: false, remaining_seconds: 0, failed_count: failedCount };
    } catch (error: any) {
        logger.error('Login lockout check failed', { error: error.message });
        return { locked: false, remaining_seconds: 0, failed_count: 0 };
    }
}
