// ============================================================================
// Sync Service — Offline-First Push/Pull (DynamoDB)
// ============================================================================
// Handles bidirectional sync between Flutter desktop/mobile and the cloud.
// Push: Client sends local changes → server applies with LWW resolution.
// Pull: Client requests changes since last sync timestamp.
//
// Migrated from PostgreSQL to DynamoDB single-table design.
// Each syncable "table" maps to a DynamoDB SK prefix under TENANT#<id>.
// ============================================================================

import { v4 as uuidv4 } from 'uuid';
import {
    Keys,
    getItem, putItem, queryItems, updateItem, deleteItem,
} from '../config/dynamodb.config';
import { safeDynamoDbOperation } from '../utils/dynamodb-errors';
import { logger } from '../utils/logger';
import { recordRevision } from './revision-history.service';

// ---- Types ----

export interface PushRequest {
    changes: ChangeRecord[];
    deviceId?: string;
    lastSyncedAt?: string;
}

export interface ChangeRecord {
    table: string;
    action: 'insert' | 'update' | 'delete';
    id: string;
    data: Record<string, unknown>;
    localTimestamp: string;
}

export interface PushResponse {
    accepted: number;
    rejected: number;
    conflicts: ConflictRecord[];
    serverTimestamp: string;
}

export interface ConflictRecord {
    id: string;
    table: string;
    reason: string;
}

export interface PullRequest {
    lastSyncedAt: string;
    tables?: string[];
}

export interface PullResponse {
    changes: PulledChange[];
    serverTimestamp: string;
    hasMore: boolean;
}

export interface PulledChange {
    table: string;
    action: 'insert' | 'update' | 'delete';
    id: string;
    data: Record<string, unknown>;
    updatedAt: string;
}

// ============================================================================
// SYNCABLE TABLES → DynamoDB SK PREFIX MAPPING
// ============================================================================
// Maps client table names to DynamoDB SK prefixes.
// This replaces the PostgreSQL table whitelist.
// ============================================================================

const TABLE_TO_SK_PREFIX: Record<string, string> = {
    // Core
    inventory: 'PRODUCT#',
    transactions: 'INVOICE#',
    transaction_items: 'LINEITEM#',
    customers: 'CUSTOMER#',
    payments: 'PAYMENT#',
    expenses: 'EXPENSE#',
    vendors: 'VENDOR#',
    purchase_orders: 'PURCHASE#',
    purchase_items: 'PURCHASEITEM#',
    delivery_challans: 'CHALLAN#',
    stock_movements: 'STOCKMOVE#',
    product_batches: 'BATCH#',

    // Financial
    bank_accounts: 'BANKACCOUNT#',
    bank_transactions: 'BANKTXN#',
    journal_entries: 'JOURNAL#',
    ledger_accounts: 'LEDGERACC#',
    accounting_periods: 'ACCPERIOD#',
    day_book: 'DAYBOOK#',
    invoice_counters: 'INVCOUNTER#',

    // Customer / Linking
    customer_profiles: 'CUSTPROFILE#',
    customer_ledger: 'CUSTLEDGER#',
    udhar_people: 'UDHARPERSON#',
    udhar_transactions: 'UDHARTXN#',
    recovery_visits: 'RECOVERYVISIT#',

    // GST
    gst_settings: 'GSTSETTING#',
    gst_invoice_details: 'GSTINVDET#',
    e_invoices: 'EINVOICE#',
    e_way_bills: 'EWAYBILL#',

    // Staff / HR
    staff_members: 'STAFF#',
    staff_attendance: 'ATTENDANCE#',
    salary_records: 'SALARY#',
    loans_advances: 'LOANADVANCE#',
    payslips: 'PAYSLIP#',
    incentives: 'INCENTIVE#',
    daily_work_reports: 'DWR#',

    // Reminder / Period
    reminder_settings: 'REMINDER#',
    period_locks: 'PERIODLOCK#',

    // Marketing
    marketing_campaigns: 'CAMPAIGN#',
    message_templates: 'MSGTEMPLATE#',

    // Security
    security_settings: 'SECSETTING#',
    cash_closings: 'CASHCLOSE#',
    user_sessions: 'SESSION#',
    audit_revisions: 'REVISION#',

    // Petrol Pump — match handler write prefixes
    shifts: 'SHIFT#',
    dispensers: 'DISPENSER#',
    nozzles: 'NOZZLE#',
    fuel_tanks: 'FUELTANK#',
    staff_nozzle_assignments: 'STAFFNOZZLEASSIGN#',
    staff_sales_details: 'STAFFSALE#',
    staff_cash_settlements: 'CASHSETTLEMENT#',
    cash_deposits: 'CASHDEPOSIT#',
    lube_stock: 'LUBESTOCK#',
    density_records: 'DENSITY#',
    nozzle_readings: 'NOZZLEREADING#',
    tank_dips: 'TANKDIP#',
    tank_atg_readings: 'TANKATG#',
    tank_calibration_charts: 'CALIBCHART#',
    tanker_deliveries: 'TANKERDELIVERY#',
    fuel_price_logs: 'FUELPRICELOG#',
    loss_entries: 'LOSSENTRY#',
    five_litre_tests: 'FIVELITRE#',
    ppm_checks: 'PPMCHECK#',
    membership_cards: 'MEMBERCARD#',

    // Restaurant / Hotel
    food_categories: 'FOODCAT#',
    food_menu_items: 'FOODITEM#',
    food_item_variations: 'FOODVAR#',
    food_addons: 'FOODADDON#',
    food_item_addon_links: 'FOODADDONLINK#',
    restaurant_tables: 'RESTTABLE#',
    restaurant_floors: 'RESTFLOOR#',
    food_orders: 'FOODORDER#',
    food_order_items: 'FOODORDERITEM#',
    restaurant_bills: 'RESTBILL#',
    restaurant_kots: 'RESTKOT#',
    restaurant_inventory_items: 'RESTINV#',
    item_recipes: 'RECIPE#',
    restaurant_loyalty_transactions: 'RESTLOYALTY#',
    restaurant_bill_splits: 'RESTSPLIT#',

    // Mobile / Computer / Electronics
    imei_serials: 'IMEI#',
    service_jobs: 'SVCJOB#',
    service_job_parts: 'SVCJOBPART#',
    service_job_status_history: 'SVCJOBSTATUS#',
    product_variants: 'VARIANT#',
    exchanges: 'EXCHANGE#',

    // Clinic / Doctor
    patients: 'PATIENT#',
    visits: 'VISIT#',
    prescriptions: 'PRESCRIPTION#',
    doctor_profiles: 'DOCTOR#',
    patient_doctor_links: 'PATDOC#',
    appointments: 'APPOINTMENT#',
    prescription_items: 'PRESCRIPTIONITEM#',
    medical_records: 'MEDRECORD#',
    follow_ups: 'FOLLOWUP#',
    soap_notes: 'SOAPNOTE#',
    lab_orders: 'LABORDER#',
    lab_results: 'LABRESULT#',
    lab_reports: 'LABREPORT#',
    medical_templates: 'MEDTPL#',

    // Vegetable Broker
    farmers: 'FARMER#',
    commission_ledger: 'COMMLEDGER#',

    // Manufacturing
    bill_of_materials: 'BOM#',
    production_entries: 'PRODENTRY#',

    // Subscriptions
    subscriptions: 'SUBSCRIPTION#',

    // Misc
    return_inwards: 'RETURNIN#',
    proformas: 'PROFORMA#',
    bookings: 'BOOKING#',
    receipts: 'RECEIPT#',
    dispatches: 'DISPATCH#',
    user_shortcuts: 'USERSHORTCUT#',
    book_returns: 'BOOKRETURN#',

    // Sync metadata
    sync_devices: 'SYNC#DEVICE#',
};

// Auto-derived from TABLE_TO_SK_PREFIX so every mapped table is syncable.
const SYNCABLE_TABLES = new Set<string>(Object.keys(TABLE_TO_SK_PREFIX));

// Default tables included when client pulls without specifying tables.
const DEFAULT_PULL_TABLES: string[] = Object.keys(TABLE_TO_SK_PREFIX).filter(
    (t) => t !== 'sync_devices'
);

// Tables with immutable records — locked once finalized.
const IMMUTABLE_STATUS_TABLES: Record<string, { field: string; statuses: Set<string> }> = {
    transactions: { field: 'status', statuses: new Set(['finalized', 'paid', 'voided']) },
    payments: { field: 'status', statuses: new Set(['posted', 'reconciled']) },
    e_invoices: { field: 'status', statuses: new Set(['issued', 'cancelled']) },
    e_way_bills: { field: 'status', statuses: new Set(['active', 'cancelled', 'expired']) },
    cash_closings: { field: 'status', statuses: new Set(['closed', 'approved']) },
    salary_records: { field: 'status', statuses: new Set(['paid', 'finalized']) },
    payslips: { field: 'status', statuses: new Set(['issued', 'paid']) },
    period_locks: { field: 'status', statuses: new Set(['locked']) },
    journal_entries: { field: 'status', statuses: new Set(['posted', 'finalized']) },
    shifts: { field: 'shiftStatus', statuses: new Set(['closed', 'reconciled']) },
};

/**
 * Get the DynamoDB SK prefix for a table name.
 * Falls back to uppercased table name with # suffix for unknown tables.
 */
function getSKPrefix(table: string): string {
    return TABLE_TO_SK_PREFIX[table] || `${table.toUpperCase().replace(/_/g, '')}#`;
}

// ---- Service Functions ----

/**
 * Process push from client — apply local changes to server.
 * Uses DynamoDB putItem/updateItem with condition expressions for LWW.
 */
export async function pushChanges(
    tenantId: string,
    request: PushRequest
): Promise<PushResponse> {
    let accepted = 0;
    let rejected = 0;
    const conflicts: ConflictRecord[] = [];
    const now = new Date().toISOString();

    // ── FINANCIAL SECURITY: Validate offline invoice totals ──
    const transactionChanges = request.changes.filter(c => c.table === 'transactions' && (c.action === 'insert' || c.action === 'update'));
    const transactionItemChanges = request.changes.filter(c => c.table === 'transaction_items' && (c.action === 'insert' || c.action === 'update'));

    for (const txnChange of transactionChanges) {
        const items = transactionItemChanges.filter(c => c.data.transaction_id === txnChange.id);

        if (items.length > 0) {
            let expectedSubtotal = 0;
            let expectedTax = 0;

            for (const item of items) {
                const product = await getItem<Record<string, any>>(
                    Keys.tenantPK(tenantId),
                    Keys.productSK(item.data.item_id as string),
                );

                if (product) {
                    const qty = Number(item.data.quantity) || 0;
                    const unitPrice = Number(item.data.unit_price_cents) || product.salePriceCents || 0;
                    const lineTotal = Math.round(unitPrice * qty);
                    const cgstCents = Math.round(lineTotal * (Number(product.cgstRateBp) || 0) / 10000);
                    const sgstCents = Math.round(lineTotal * (Number(product.sgstRateBp) || 0) / 10000);
                    expectedSubtotal += lineTotal;
                    expectedTax += cgstCents + sgstCents;
                }
            }

            const expectedTotal = expectedSubtotal + expectedTax;
            const clientTotal = Number(txnChange.data.total_cents) || 0;

            if (Math.abs(clientTotal - expectedTotal) > 2) {
                logger.warn('SECURITY VIOLATION: Sync rejected forged offline totals', {
                    tenantId, txnId: txnChange.id, clientTotal, expectedTotal,
                });
                conflicts.push({
                    id: txnChange.id,
                    table: 'transactions',
                    reason: `SECURITY: Forged totals detected. Expected ~${expectedTotal}, got ${clientTotal}`,
                });
                rejected++;
                request.changes = request.changes.filter(c => c.id !== txnChange.id && c.data.transaction_id !== txnChange.id);
            }
        }
    }

    // Process each change
    for (const change of request.changes) {
        if (!SYNCABLE_TABLES.has(change.table)) {
            conflicts.push({ id: change.id, table: change.table, reason: 'Table not syncable' });
            rejected++;
            continue;
        }

        try {
            const result = await processChange(tenantId, change, request.deviceId, now);
            if (result.conflict) {
                conflicts.push(result.conflict);
                rejected++;
            } else {
                accepted++;
            }
        } catch (err) {
            logger.warn('Sync push error', {
                id: change.id, table: change.table, error: (err as Error).message,
            });
            conflicts.push({ id: change.id, table: change.table, reason: (err as Error).message });
            rejected++;
        }
    }

    logger.info('Sync push completed', { tenantId, accepted, rejected, conflictCount: conflicts.length });

    return { accepted, rejected, conflicts, serverTimestamp: now };
}

/**
 * Process a single change record.
 */
async function processChange(
    tenantId: string,
    change: ChangeRecord,
    deviceId?: string,
    now?: string,
): Promise<{ conflict?: ConflictRecord }> {
    const timestamp = now || new Date().toISOString();
    const skPrefix = getSKPrefix(change.table);
    const sk = `${skPrefix}${change.id}`;
    const before = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), sk);

    if (change.action === 'delete') {
        // Soft delete
        try {
            await safeDynamoDbOperation(
                'sync_soft_delete',
                () => updateItem(
                    Keys.tenantPK(tenantId),
                    sk,
                    {
                        updateExpression: 'SET isDeleted = :true, updatedAt = :now, deviceId = :dev',
                        expressionAttributeValues: {
                            ':true': true,
                            ':now': timestamp,
                            ':dev': deviceId || null,
                        },
                    },
                ),
                { tenantId, sk, table: change.table }
            );
        } catch (err) {
            // Item may not exist — that's fine for delete
            logger.warn('Sync: Soft delete failed', { tenantId, sk, error: (err as Error).message });
        }
        await recordRevision(
            tenantId,
            change.table,
            change.id,
            'delete',
            deviceId || 'sync-device',
            before || null,
            { ...(before || {}), isDeleted: true, updatedAt: timestamp },
            { source: 'sync.push' },
        );
        return {};
    }

    // Insert or Update
    // Check immutability
    const immutableConfig = IMMUTABLE_STATUS_TABLES[change.table];
    if (immutableConfig && change.action === 'update') {
        const existing = await getItem<Record<string, any>>(Keys.tenantPK(tenantId), sk);
        if (existing && immutableConfig.statuses.has(existing[immutableConfig.field])) {
            return {
                conflict: {
                    id: change.id,
                    table: change.table,
                    reason: `Record is ${existing[immutableConfig.field]} and cannot be modified`,
                },
            };
        }
    }

    // Check LWW (Last Writer Wins)
    const existing = before;
    if (existing) {
        const serverUpdatedAt = existing.updatedAt ? new Date(existing.updatedAt) : new Date(0);
        const localUpdatedAt = change.localTimestamp ? new Date(change.localTimestamp) : new Date();

        if (serverUpdatedAt > localUpdatedAt) {
            return {
                conflict: {
                    id: change.id,
                    table: change.table,
                    reason: 'Server has newer version (LWW)',
                },
            };
        }
    }

    // Build the item
    const item: Record<string, any> = {
        PK: Keys.tenantPK(tenantId),
        SK: sk,
        entityType: change.table.toUpperCase().replace(/_/g, ''),
        id: change.id,
        tenantId,
        ...change.data,
        updatedAt: timestamp,
        deviceId: deviceId || null,
    };

    // Remove non-database fields
    delete item.is_synced;
    delete item.tenant_id; // We use tenantId (camelCase)

    if (change.action === 'insert') {
        item.createdAt = item.createdAt || timestamp;
        item.isDeleted = false;
    }

    await safeDynamoDbOperation(
        'sync_put_item',
        () => putItem(item),
        { tenantId, table: change.table, id: change.id }
    );
    await recordRevision(
        tenantId,
        change.table,
        change.id,
        change.action === 'insert' ? 'create' : 'update',
        deviceId || 'sync-device',
        before || null,
        item,
        { source: 'sync.push' },
    );
    return {};
}

/**
 * Pull changes from server since last sync timestamp.
 */
export async function pullChanges(
    tenantId: string,
    request: PullRequest
): Promise<PullResponse> {
    const since = request.lastSyncedAt || '1970-01-01T00:00:00Z';
    const requestedTables = request.tables?.filter(t => SYNCABLE_TABLES.has(t));
    const tables = requestedTables && requestedTables.length > 0
        ? requestedTables
        : DEFAULT_PULL_TABLES;
    const limit = 500;

    const changes: PulledChange[] = [];

    for (const table of tables) {
        if (changes.length >= limit) break;

        try {
            const skPrefix = getSKPrefix(table);
            const result = await queryItems<Record<string, any>>(
                Keys.tenantPK(tenantId),
                skPrefix,
                {
                    filterExpression: 'updatedAt > :since',
                    expressionAttributeValues: { ':since': since },
                    limit: limit - changes.length,
                },
            );

            for (const row of result.items) {
                const { PK, SK, entityType, ...data } = row;
                changes.push({
                    table,
                    action: row.isDeleted ? 'delete' : (row.createdAt === row.updatedAt ? 'insert' : 'update'),
                    id: row.id,
                    data,
                    updatedAt: row.updatedAt || new Date().toISOString(),
                });
            }
        } catch (err) {
            logger.warn(`Sync pull: table ${table} not available`, {
                error: (err as Error).message,
            });
        }
    }

    logger.info('Sync pull completed', {
        tenantId, changesCount: changes.length, hasMore: changes.length >= limit,
    });

    return {
        changes,
        serverTimestamp: new Date().toISOString(),
        hasMore: changes.length >= limit,
    };
}
