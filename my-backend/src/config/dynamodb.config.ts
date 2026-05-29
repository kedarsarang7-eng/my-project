// ============================================================================
// DynamoDB Configuration — Single Table Design
// ============================================================================
// Replaces PostgreSQL (RDS) with DynamoDB for serverless, zero-cost-at-idle.
// Uses Single Table Design: all entities share one table with GSIs.
//
// Billing Mode: PAY_PER_REQUEST (on-demand) — $0 at zero traffic.
// Free Tier: 25 WCU + 25 RCU + 25GB storage (always-free).
// ============================================================================
import { config } from './environment';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
    DynamoDBDocumentClient,
    GetCommand,
    PutCommand,
    QueryCommand,
    UpdateCommand,
    DeleteCommand,
    BatchWriteCommand,
    BatchGetCommand,
    TransactWriteCommand,
    ScanCommand,
} from '@aws-sdk/lib-dynamodb';
import type {
    GetCommandInput,
    PutCommandInput,
    QueryCommandInput,
    UpdateCommandInput,
    DeleteCommandInput,
    BatchWriteCommandInput,
    TransactWriteCommandInput,
    ScanCommandInput,
} from '@aws-sdk/lib-dynamodb';

// ── Singleton Client ───────────────────────────────────────────────────────
const client = new DynamoDBClient({
    region: config.aws.region,
});

const docClient = DynamoDBDocumentClient.from(client, {
    marshallOptions: {
        removeUndefinedValues: true,
        convertClassInstanceToMap: true,
    },
    unmarshallOptions: {
        wrapNumbers: false,
    },
});

// ── Table Name ─────────────────────────────────────────────────────────────
export const TABLE_NAME = config.dynamodb.tableName;

// ── Key Builders ───────────────────────────────────────────────────────────

export const Keys = {
    // Tenant
    tenantPK: (tenantId: string) => `TENANT#${tenantId}`,
    tenantProfileSK: () => 'PROFILE',
    tenantSettingsSK: () => 'SETTINGS',
    tenantLicenseSK: () => 'LICENSE',

    // User
    userSK: (userId: string) => `USER#${userId}`,
    emailGSI1PK: (email: string) => `EMAIL#${email.toLowerCase()}`,
    cognitoSubGSI2PK: (sub: string) => `COGNITOSUB#${sub}`,

    // Product / Inventory
    productSK: (productId: string) => `PRODUCT#${productId}`,
    skuGSI1SK: (sku: string) => `SKU#${sku}`,
    barcodeGSI3PK: (tenantId: string) => `TENANT#${tenantId}`,
    barcodeGSI3SK: (barcode: string) => `BARCODE#${barcode}`,

    // Invoice / Bill
    invoiceSK: (invoiceId: string) => `INVOICE#${invoiceId}`,
    invoiceNumGSI1SK: (num: string) => `INVNUM#${num}`,
    invoiceLineItemPK: (invoiceId: string) => `INVOICE#${invoiceId}`,
    lineItemSK: (lineItemId: string) => `LINEITEM#${lineItemId}`,

    // Customer
    customerSK: (customerId: string) => `CUSTOMER#${customerId}`,
    phoneGSI1SK: (phone: string) => `PHONE#${phone}`,

    // Payment
    paymentSK: (paymentId: string) => `PAYMENT#${paymentId}`,

    // Transaction
    transactionSK: (txnId: string) => `TXN#${txnId}`,

    // License
    licensePK: (licenseKey: string) => `LICENSE#${licenseKey}`,
    licenseMetaSK: () => 'META',
    licenseActivationSK: (timestamp: string) => `ACTIVATION#${timestamp}`,
    licenseEntityGSI1PK: () => 'ENTITY#LICENSE',

    // Business
    businessSK: (businessId: string) => `BUSINESS#${businessId}`,

    // Staff
    staffSK: (staffId: string) => `STAFF#${staffId}`,

    // Sync
    syncDeviceSK: (deviceId: string) => `SYNC#DEVICE#${deviceId}`,

    // Idempotency
    idempotencyPK: (key: string) => `IDEMPOTENCY#${key}`,
    idempotencyMetaSK: () => 'META',

    // Expense
    expenseSK: (expenseId: string) => `EXPENSE#${expenseId}`,

    // Vendor
    vendorSK: (vendorId: string) => `VENDOR#${vendorId}`,
    purchaseOrderSK: (poId: string) => `PO#${poId}`,
    grnSK: (grnId: string) => `GRN#${grnId}`,
    purchaseBillSK: (billId: string) => `PBILL#${billId}`,
    purchaseReturnSK: (returnId: string) => `PRET#${returnId}`,
    partySK: (partyId: string) => `PARTY#${partyId}`,
    partyLedgerSK: (entryId: string) => `PLEDGER#${entryId}`,
    creditTxnSK: (txnId: string) => `CREDITTXN#${txnId}`,
    stockMoveSK: (moveId: string) => `STOCKMOVE#${moveId}`,
    priceBookSK: (priceBookId: string) => `PRICEBOOK#${priceBookId}`,

    // Credit recovery follow-up visits (p21)
    recoveryVisitSK: (visitId: string) => `RECOVERYVISIT#${visitId}`,

    // HSN Master (global — not per-tenant, HSN codes are India-wide)
    hsnMasterPK: () => 'HSNMASTER',
    hsnMasterSK: (hsnCode: string) => `HSN#${hsnCode}`,

    // Serial / IMEI Tracking (Consumer Protection Act)
    serialTrackSK: (identifier: string) => `SERIAL#${identifier}`,

    // Generic entity listing via GSI
    entityGSI1PK: (entityType: string) => `ENTITY#${entityType}`,

    // Estimate / Quotation (Hardware shop)
    estimateSK: (estimateId: string) => `ESTIMATE#${estimateId}`,
    estimateNumGSI1SK: (num: string) => `ESTNUM#${num}`,
    estimateLineItemPK: (estimateId: string) => `ESTIMATE#${estimateId}`,
    estimateLineItemSK: (lineItemId: string) => `ESTLINE#${lineItemId}`,

    // Delivery Challan (Hardware shop — material movement)
    challanSK: (challanId: string) => `CHALLAN#${challanId}`,
    challanNumGSI1SK: (num: string) => `DCNUM#${num}`,

    // Held / Parked Bills (cashier safety — Sprint 1)
    // Held bills are a transient cart snapshot; NO stock impact, NO invoice number.
    // Stored under TENANT#<tid> so a single tenant query lists all held bills.
    heldBillSK: (heldBillId: string) => `HELDBILL#${heldBillId}`,
    heldBillEntityGSI1PK: () => 'ENTITY#HELDBILL',

    // Smart Inventory Import
    importJobSK: (jobId: string) => `IMPORTJOB#${jobId}`,
    importJobFingerprintSK: (fingerprint: string) => `IMPORTFINGERPRINT#${fingerprint}`,
    categoryCachePK: () => 'CATCACHE',
    categoryCacheSK: (hash: string) => `CATCACHE#${hash}`,

    // In-Store Self Scan & Checkout
    inStoreSessionPK: (sessionId: string) => `SESSION#${sessionId}`,
    inStoreSessionSK: (sessionId: string) => `SESSION#${sessionId}`,
    inStoreOrderSK: (orderId: string) => `INSTORE_ORDER#${orderId}`,
    sessionByCustomerGSI1PK: (customerId: string) => `CUSTOMER_SESSION#${customerId}`,
    sessionByStoreGSI2PK: (storeId: string) => `STORE_SESSION#${storeId}`,
    analyticsDateSK: (date: string) => `ANALYTICS#DAILY#${date}`,

    // Cash Closings (cashier safety — Sprint 1: day-end denomination close)
    // SK encodes the closing date so listing newest-first is a free SK scan.
    // closingDate format: YYYY-MM-DD.
    cashClosingSK: (closingDate: string, businessId?: string) =>
        businessId
            ? `CASHCLOSE#${closingDate}#${businessId}`
            : `CASHCLOSE#${closingDate}`,
    cashClosingEntityGSI1PK: () => 'ENTITY#CASHCLOSE',

    // Decoration & Catering
    dcEventSK: (eventId: string) => `DC_EVENT#${eventId}`,
    dcThemeSK: (themeId: string) => `DC_THEME#${themeId}`,
    dcMenuItemSK: (itemId: string) => `DC_MENU#${itemId}`,
    dcPackageSK: (pkgId: string) => `DC_PKG#${pkgId}`,
    dcStaffSK: (staffId: string) => `DC_STAFF#${staffId}`,
    dcVendorSK: (vendorId: string) => `DC_VENDOR#${vendorId}`,
    dcInventorySK: (itemId: string) => `DC_INV#${itemId}`,
    dcExpenseSK: (expId: string) => `DC_EXPENSE#${expId}`,
    dcInvoiceSK: (invId: string) => `DC_INVOICE#${invId}`,
    // GSI: list all DC events for a tenant sorted by date
    dcEventGSI1PK: (tenantId: string) => `DC_EVENTS#${tenantId}`,
    dcEventGSI1SK: (date: string, eventId: string) => `DATE#${date}#${eventId}`,

    // Auto Parts / Garage
    autoPartsJobCardSK: (jobCardId: string) => `AUTOPARTS_JOB_CARD#${jobCardId}`,
    autoPartsPartSK: (partId: string) => `AUTOPARTS_PART#${partId}`,
    autoPartsOemRefSK: (oemNumber: string, aftermarketNumber: string) => `OEM#${oemNumber}#${aftermarketNumber}`,
    autoPartsAftermarketRefSK: (aftermarketNumber: string, oemNumber: string) => `AFTERMARKET#${aftermarketNumber}#${oemNumber}`,

    // Jewellery
    jewelleryRateCardSK: (date: string) => `GOLDRATE#${date}`,
    jewelleryCustomOrderSK: (orderId: string) => `JEWELLERY_ORDER#${orderId}`,
    jewelleryExchangeSK: (exchangeId: string) => `JEWELLERY_EXCHANGE#${exchangeId}`,
    
    // Jewellery Extended Features (NEW)
    goldRateAlertSK: (id: string) => `ALERT#${id}`,
    makingChargesConfigSK: (id: string) => `MAKING_CONFIG#${id}`,
    repairJobSK: (id: string) => `REPAIR#${id}`,
    goldSchemeSK: (id: string) => `GOLD_SCHEME#${id}`,
    schemePaymentSK: (schemeId: string, paymentId: string) => `GOLD_SCHEME#${schemeId}#PAYMENT#${paymentId}`,
    schemeTemplateSK: (id: string) => `SCHEME_TEMPLATE#${id}`,

    // Academic Coaching
    acStudentSK: (studentId: string) => `AC_STUDENT#${studentId}`,
    acBatchSK: (batchId: string) => `AC_BATCH#${batchId}`,
    acCourseSK: (courseId: string) => `AC_COURSE#${courseId}`,
    acFeeRecordSK: (feeRecordId: string) => `AC_FEE#${feeRecordId}`,
    acAttendanceSK: (attendanceId: string) => `AC_ATTENDANCE#${attendanceId}`,
    acFacultySK: (facultyId: string) => `AC_FACULTY#${facultyId}`,
    acExamSK: (examId: string) => `AC_EXAM#${examId}`,
    acResultSK: (resultId: string) => `AC_RESULT#${resultId}`,
    acTimetableSlotSK: (slotId: string) => `AC_TIMETABLE#${slotId}`,
    acMaterialSK: (materialId: string) => `AC_MATERIAL#${materialId}`,
    acInvoiceSK: (invoiceId: string) => `AC_INVOICE#${invoiceId}`,
    acPaymentSK: (paymentId: string) => `AC_PAYMENT#${paymentId}`,
    acNotificationSK: (notificationId: string) => `AC_NOTIF#${notificationId}`,
    acDemoClassSK: (demoId: string) => `AC_DEMO#${demoId}`,
    acFacultyAttendanceSK: (facultyId: string, date: string) => `AC_FACULTY_ATTENDANCE#${facultyId}#${date}`,
    acIdCardSK: (idCardId: string) => `AC_ID_CARD#${idCardId}`,
    acExpenseSK: (expenseId: string) => `AC_EXPENSE#${expenseId}`,
    // GSIs for Academic Coaching
    acStudentByBatchGSI1PK: (tenantId: string, batchId: string) => `AC_BATCH_STUDENTS#${tenantId}#${batchId}`,
    acFeeByStudentGSI1PK: (tenantId: string, studentId: string) => `AC_STUDENT_FEES#${tenantId}#${studentId}`,
    acAttendanceByBatchGSI1PK: (tenantId: string, batchId: string) => `AC_BATCH_ATTENDANCE#${tenantId}#${batchId}`,
    acResultByExamGSI1PK: (tenantId: string, examId: string) => `AC_EXAM_RESULTS#${tenantId}#${examId}`,
    acTimetableByBatchGSI1PK: (tenantId: string, batchId: string) => `AC_BATCH_TIMETABLE#${tenantId}#${batchId}`,
    acTimetableByFacultyGSI2PK: (tenantId: string, facultyId: string) => `AC_FACULTY_TIMETABLE#${tenantId}#${facultyId}`,
    acDemoByStatusGSI1PK: (tenantId: string, status: string) => `AC_DEMO_STATUS#${tenantId}#${status}`,

    // Refunds
    refundPK: (refundId: string) => `REFUND#${refundId}`,
    refundSK: () => 'META',
    refundByBillGSI: (billId: string) => `BILL#${billId}`,
    refundByTimeGSI: () => `REFUND#${Date.now()}`,

    // Wholesale Transport — LR Number GSI for fast lorry-receipt lookup
    // GSI4PK = TENANT#{tenantId}, GSI4SK = LR#{lrNumber}
    lrNumberGSI4PK: (tenantId: string) => `TENANT#${tenantId}`,
    lrNumberGSI4SK: (lrNumber: string) => `LR#${lrNumber}`,
};

// ── Helper Functions ───────────────────────────────────────────────────────

/**
 * Get a single item by PK + SK.
 */
export async function getItem<T = Record<string, unknown>>(
    pk: string,
    sk: string,
): Promise<T | null> {
    const result = await docClient.send(new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: pk, SK: sk },
    }));
    return (result.Item as T) || null;
}

/**
 * Put (create/overwrite) an item.
 */
export async function putItem(
    item: Record<string, unknown>,
    conditionExpression?: string,
): Promise<void> {
    const params: PutCommandInput = {
        TableName: TABLE_NAME,
        Item: item,
    };
    if (conditionExpression) {
        params.ConditionExpression = conditionExpression;
    }
    await docClient.send(new PutCommand(params));
}

/**
 * Query items by PK with optional SK prefix (begins_with).
 */
export async function queryItems<T = Record<string, unknown>>(
    pk: string,
    skPrefix?: string,
    opts?: {
        limit?: number;
        scanIndexForward?: boolean;
        exclusiveStartKey?: Record<string, unknown>;
        filterExpression?: string;
        expressionAttributeValues?: Record<string, unknown>;
        expressionAttributeNames?: Record<string, string>;
        indexName?: string;
    },
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
    const params: QueryCommandInput = {
        TableName: TABLE_NAME,
        KeyConditionExpression: skPrefix
            ? 'PK = :pk AND begins_with(SK, :skPrefix)'
            : 'PK = :pk',
        ExpressionAttributeValues: {
            ':pk': pk,
            ...(skPrefix ? { ':skPrefix': skPrefix } : {}),
            ...(opts?.expressionAttributeValues || {}),
        },
        ScanIndexForward: opts?.scanIndexForward ?? true,
        Limit: opts?.limit,
        ExclusiveStartKey: opts?.exclusiveStartKey,
    };

    if (opts?.filterExpression) {
        params.FilterExpression = opts.filterExpression;
    }
    if (opts?.expressionAttributeNames) {
        params.ExpressionAttributeNames = opts.expressionAttributeNames;
    }
    if (opts?.indexName) {
        params.IndexName = opts.indexName;
        // For GSI queries, use GSI keys
        if (opts.indexName === 'GSI1') {
            params.KeyConditionExpression = skPrefix
                ? 'GSI1PK = :pk AND begins_with(GSI1SK, :skPrefix)'
                : 'GSI1PK = :pk';
        } else if (opts.indexName === 'GSI2') {
            params.KeyConditionExpression = skPrefix
                ? 'GSI2PK = :pk AND begins_with(GSI2SK, :skPrefix)'
                : 'GSI2PK = :pk';
        } else if (opts.indexName === 'GSI3') {
            params.KeyConditionExpression = skPrefix
                ? 'GSI3PK = :pk AND begins_with(GSI3SK, :skPrefix)'
                : 'GSI3PK = :pk';
        }
    }

    const result = await docClient.send(new QueryCommand(params));
    return {
        items: (result.Items || []) as T[],
        lastKey: result.LastEvaluatedKey,
    };
}

/**
 * Query ALL items across multiple pages (auto-pagination).
 * Use this when you need the complete result set (e.g., reports, dashboard aggregations).
 * DynamoDB returns max 1MB per page — this function follows all pages.
 *
 * CAUTION: For very large datasets, use queryItems with manual pagination instead.
 * Safety limit: max 10 pages (~10MB) to prevent runaway queries.
 */
export async function queryAllItems<T = Record<string, unknown>>(
    pk: string,
    skPrefix?: string,
    opts?: {
        filterExpression?: string;
        expressionAttributeValues?: Record<string, unknown>;
        expressionAttributeNames?: Record<string, string>;
        indexName?: string;
        scanIndexForward?: boolean;
        maxPages?: number;
    },
): Promise<T[]> {
    const allItems: T[] = [];
    let lastKey: Record<string, unknown> | undefined;
    const maxPages = opts?.maxPages ?? 10;
    let page = 0;

    do {
        const result = await queryItems<T>(pk, skPrefix, {
            ...opts,
            exclusiveStartKey: lastKey,
        });
        allItems.push(...result.items);
        lastKey = result.lastKey;
        page++;
    } while (lastKey && page < maxPages);

    return allItems;
}

/**
 * Update an item with an UpdateExpression.
 */
export async function updateItem(
    pk: string,
    sk: string,
    params: {
        updateExpression: string;
        expressionAttributeValues?: Record<string, unknown>;
        expressionAttributeNames?: Record<string, string>;
        conditionExpression?: string;
    },
): Promise<Record<string, unknown> | null> {
    const input: UpdateCommandInput = {
        TableName: TABLE_NAME,
        Key: { PK: pk, SK: sk },
        UpdateExpression: params.updateExpression,
        ExpressionAttributeValues: params.expressionAttributeValues,
        ExpressionAttributeNames: params.expressionAttributeNames,
        ConditionExpression: params.conditionExpression,
        ReturnValues: 'ALL_NEW',
    };
    const result = await docClient.send(new UpdateCommand(input));
    return result.Attributes || null;
}

/**
 * HIGH FIX: Update item with optimistic locking (version-based concurrency control).
 * Automatically increments version and checks expectedVersion to prevent concurrent modification.
 *
 * @param expectedVersion - The version number the client expects (from their last read)
 * @throws ConditionalCheckFailedException if version mismatch (concurrent modification)
 *
 * Usage in handlers:
 *   await updateItemWithVersion(tenantId, itemId, updateData, clientVersion, 'entityVersion');
 */
export async function updateItemWithVersion(
    pk: string,
    sk: string,
    params: {
        updateExpression: string;
        expressionAttributeValues?: Record<string, unknown>;
        expressionAttributeNames?: Record<string, string>;
    },
    expectedVersion: number,
    versionFieldName = 'version',
): Promise<Record<string, unknown> | null> {
    const input: UpdateCommandInput = {
        TableName: TABLE_NAME,
        Key: { PK: pk, SK: sk },
        // Increment version and apply other updates
        UpdateExpression: `SET #version = if_not_exists(#version, :zero) + :one, ${params.updateExpression}`,
        ExpressionAttributeNames: {
            '#version': versionFieldName,
            ...(params.expressionAttributeNames || {}),
        },
        ExpressionAttributeValues: {
            ':one': 1,
            ':zero': 0,
            ':expectedVersion': expectedVersion,
            ...(params.expressionAttributeValues || {}),
        },
        // Optimistic locking: only update if version matches expected
        ConditionExpression: `attribute_not_exists(#version) OR #version = :expectedVersion`,
        ReturnValues: 'ALL_NEW',
    };

    try {
        const result = await docClient.send(new UpdateCommand(input));
        return result.Attributes || null;
    } catch (err: any) {
        if (err.name === 'ConditionalCheckFailedException') {
            // Convert to a clear error for the handler to catch
            const error = new Error(
                `Concurrent modification detected. Expected ${versionFieldName}=${expectedVersion} but item was modified by another request. Please refresh and retry.`
            );
            error.name = 'OptimisticLockError';
            (error as any).statusCode = 409;
            (error as any).code = 'CONCURRENT_MODIFICATION';
            throw error;
        }
        throw err;
    }
}

/**
 * Delete an item by PK + SK.
 */
export async function deleteItem(pk: string, sk: string): Promise<void> {
    await docClient.send(new DeleteCommand({
        TableName: TABLE_NAME,
        Key: { PK: pk, SK: sk },
    }));
}

/**
 * Batch write up to 25 items (DynamoDB limit).
 * Retries UnprocessedItems with exponential backoff to prevent silent data loss.
 */
export async function batchWrite(
    items: Array<{
        type: 'put' | 'delete';
        item?: Record<string, unknown>;
        key?: { PK: string; SK: string };
    }>,
): Promise<void> {
    const requests = items.map(op => {
        if (op.type === 'put' && op.item) {
            return { PutRequest: { Item: op.item } };
        } else if (op.type === 'delete' && op.key) {
            return { DeleteRequest: { Key: op.key } };
        }
        throw new Error('Invalid batch operation');
    });

    // DynamoDB batch limit is 25
    for (let i = 0; i < requests.length; i += 25) {
        let batch = requests.slice(i, i + 25);
        let retries = 0;
        const MAX_RETRIES = 5;

        while (batch.length > 0 && retries < MAX_RETRIES) {
            const result = await docClient.send(new BatchWriteCommand({
                RequestItems: {
                    [TABLE_NAME]: batch,
                },
            }));

            const unprocessed = result.UnprocessedItems?.[TABLE_NAME];
            if (!unprocessed || unprocessed.length === 0) break;

            // Exponential backoff: 100ms, 200ms, 400ms, 800ms, 1600ms
            retries++;
            const delay = Math.min(100 * Math.pow(2, retries - 1), 2000);
            await new Promise(r => setTimeout(r, delay));
            batch = unprocessed as typeof batch;
        }

        if (batch.length > 0 && retries >= MAX_RETRIES) {
            throw new Error(
                `batchWrite failed after ${MAX_RETRIES} retries: ${batch.length} items unprocessed`
            );
        }
    }
}

/**
 * Batch get up to 100 items by PK+SK pairs.
 * DynamoDB BatchGetItem limit is 100 keys per call.
 * Used to eliminate N+1 query patterns (e.g., fetching all products for an invoice).
 */
export async function batchGetItems<T = Record<string, unknown>>(
    keys: Array<{ PK: string; SK: string }>,
): Promise<T[]> {
    const results: T[] = [];

    // DynamoDB batch get limit is 100
    for (let i = 0; i < keys.length; i += 100) {
        const batch = keys.slice(i, i + 100);
        let unprocessedKeys = batch.map(k => ({ PK: k.PK, SK: k.SK }));
        let retries = 0;
        const MAX_RETRIES = 3;

        while (unprocessedKeys.length > 0 && retries < MAX_RETRIES) {
            const result = await docClient.send(new BatchGetCommand({
                RequestItems: {
                    [TABLE_NAME]: {
                        Keys: unprocessedKeys,
                    },
                },
            }));

            const items = result.Responses?.[TABLE_NAME] || [];
            results.push(...(items as T[]));

            const remaining = result.UnprocessedKeys?.[TABLE_NAME]?.Keys;
            if (!remaining || remaining.length === 0) break;

            retries++;
            const delay = Math.min(100 * Math.pow(2, retries - 1), 1000);
            await new Promise(r => setTimeout(r, delay));
            unprocessedKeys = remaining as typeof unprocessedKeys;
        }
    }

    return results;
}

/**
 * Transactional write (up to 100 items).
 * Used for atomic operations like invoice creation + stock deduction.
 */
export async function transactWrite(
    transactItems: TransactWriteCommandInput['TransactItems'],
): Promise<void> {
    await docClient.send(new TransactWriteCommand({
        TransactItems: transactItems,
    }));
}

/**
 * Scan the table — ADMIN ONLY, never for production user-facing queries.
 * Scans are expensive (read every item) and should only be used for
 * admin operations like listing all licenses or data migration.
 * @internal — Do not import directly. Use queryItems/queryAllItems instead.
 */
export async function scanTable<T = Record<string, unknown>>(
    filterExpression?: string,
    expressionAttributeValues?: Record<string, unknown>,
    expressionAttributeNames?: Record<string, string>,
    limit?: number,
): Promise<T[]> {
    console.warn('[WARN] scanTable called — this is expensive. Use queryItems/queryAllItems for production queries.');
    const params: ScanCommandInput = {
        TableName: TABLE_NAME,
        FilterExpression: filterExpression,
        ExpressionAttributeValues: expressionAttributeValues,
        ExpressionAttributeNames: expressionAttributeNames,
        Limit: limit || 500, // Safety cap to prevent runaway scans
    };
    const result = await docClient.send(new ScanCommand(params));
    return (result.Items || []) as T[];
}

// ── Exported Client (for advanced use) ─────────────────────────────────────
export { docClient, client as dynamoClient };
