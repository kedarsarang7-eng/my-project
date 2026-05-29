import { config } from '../config/environment';
/**
 * DynamoDB Stream to OpenSearch Indexer Lambda
 * 
 * Triggered by DynamoDB Streams for INSERT, MODIFY, REMOVE events.
 * Syncs data to OpenSearch for fast, scalable search across all entities.
 * 
 * Features:
 * - Multi-tenant isolation (tenantId filtering)
 * - Dead Letter Queue (DLQ) for failed operations
 * - CloudWatch logging for audit trail
 * - Batch processing for efficiency
 * 
 * @author DukanX Engineering
 * @version 1.0.0
 */

import { DynamoDBStreamEvent, DynamoDBRecord, Context, SQSEvent } from 'aws-lambda';
import { unmarshall } from '@aws-sdk/util-dynamodb';
import { AttributeValue } from '@aws-sdk/client-dynamodb';
import { getOpenSearchClient, isOpenSearchConfigured } from '../search/opensearch-client';
import { getIndexName, SearchIndexName } from '../search/opensearch-mappings';
import { Client } from '@opensearch-project/opensearch';
import { logger } from '../utils/logger';

// DLQ Configuration
const DLQ_URL = config.awsQueue.dlqUrl || '';
const ENVIRONMENT = config.app.env || 'dev';
const MAX_RETRIES = 3;

// Entity type mapping from DynamoDB table to OpenSearch index
const ENTITY_TYPE_MAP: Record<string, SearchIndexName> = {
  // Core billing
  'BILL': 'bills',
  'INVOICE': 'bills',
  'CREDIT_NOTE': 'bills',
  
  // Customers
  'CUSTOMER': 'customers',
  'CUSTOMER_PROFILE': 'customers',
  
  // Inventory
  'PRODUCT': 'products',
  'STOCK_ITEM': 'products',
  'INVENTORY_ITEM': 'products',
  
  // Pharmacy batches
  'PRODUCT_BATCH': 'productBatches',
  'BATCH': 'productBatches',
  'PHARMACY_BATCH': 'productBatches',
  
  // Suppliers
  'SUPPLIER': 'suppliers',
  'VENDOR': 'suppliers',
  
  // Purchase
  'PURCHASE_BILL': 'purchaseBills',
  'PURCHASE_ORDER': 'purchaseBills',
  
  // Clinic
  'PATIENT': 'patients',
  'VISIT': 'visits',
  'PRESCRIPTION': 'prescriptions',
  
  // Restaurant
  'KOT': 'kots',
  'KITCHEN_ORDER': 'kots',
  'MENU_ITEM': 'menuItems',
  'DISH': 'menuItems',
  
  // Accounting
  'LEDGER_ENTRY': 'ledgerEntries',
  'JOURNAL_ENTRY': 'ledgerEntries',
  'EXPENSE': 'expenses',
  'BANK_TRANSACTION': 'bankTransactions',
  
  // Delivery
  'DELIVERY_CHALLAN': 'deliveryChallans',
  'CHALLAN': 'deliveryChallans',
  
  // Book Store
  'BOOK_RETURN': 'bookReturns',
  
  // Pre-orders
  'PRE_ORDER': 'preOrders',
  
  // Service
  'SERVICE_JOB': 'serviceJobs',
  'REPAIR_JOB': 'serviceJobs',
  
  // E-Invoice
  'E_INVOICE': 'eInvoices',
  'GST_INVOICE': 'eInvoices',
  
  // Petrol Pump
  'FUEL_TRANSACTION': 'fuelTransactions',
  'FUEL_SALE': 'fuelTransactions',
};

// Interface for indexed documents
interface SearchDocument {
  tenantId: string;
  businessId?: string;
  businessType?: string;
  [key: string]: unknown;
}

/**
 * Main Lambda handler for DynamoDB Streams
 */
export const handler = async (
  event: DynamoDBStreamEvent,
  context: Context
): Promise<{ batchItemFailures: { itemIdentifier: string }[] }> => {
  logger.info('Processing records', {
    recordCount: event.Records.length,
    requestId: context.awsRequestId,
    remainingTime: context.getRemainingTimeInMillis(),
    handler: 'searchIndexer',
  });

  // Check if OpenSearch is configured
  if (!isOpenSearchConfigured()) {
    logger.warn('OpenSearch not configured - skipping indexing', { handler: 'searchIndexer' });
    return { batchItemFailures: [] };
  }

  const client = getOpenSearchClient();
  const batchItemFailures: { itemIdentifier: string }[] = [];

  // Process records in batches for efficiency
  const indexOperations: Promise<void>[] = [];

  for (const record of event.Records) {
    try {
      const operation = processRecord(record, client);
      if (operation) {
        indexOperations.push(operation);
      }
    } catch (error) {
      logger.error('Error processing record', {
        eventID: record.eventID,
        error: error instanceof Error ? error.message : String(error),
        handler: 'searchIndexer',
      });
      
      // Add to batch failures for retry (unless it's a permanent error)
      if (isRetryableError(error)) {
        batchItemFailures.push({ itemIdentifier: record.eventID! });
      }
    }
  }

  // Wait for all indexing operations to complete
  try {
    await Promise.all(indexOperations);
  } catch (error) {
    logger.error('Batch processing error', { error: error instanceof Error ? error.message : String(error), handler: 'searchIndexer' });
  }

  // Log summary
  logger.info('Completed processing', {
    totalRecords: event.Records.length,
    failures: batchItemFailures.length,
    handler: 'searchIndexer',
  });

  return { batchItemFailures };
};

/**
 * Process a single DynamoDB record
 */
function processRecord(record: DynamoDBRecord, client: Client): Promise<void> | null {
  const eventName = record.eventName;
  const eventID = record.eventID;

  if (!eventName || !eventID) {
    logger.warn('Missing event name or ID', { handler: 'searchIndexer' });
    return null;
  }

  // Unmarshall DynamoDB image
  const newImage = record.dynamodb?.NewImage;
  const oldImage = record.dynamodb?.OldImage;

  if (eventName === 'REMOVE') {
    // Handle deletion
    const oldDoc = oldImage ? unmarshall(oldImage as Record<string, AttributeValue>) : null;
    if (!oldDoc) {
      logger.warn('REMOVE event missing old image', { eventID, handler: 'searchIndexer' });
      return null;
    }
    return deleteDocument(oldDoc, client, eventID);
  }

  // Handle INSERT and MODIFY
  if (!newImage) {
    logger.warn(`${eventName} event missing new image`, { eventID, handler: 'searchIndexer' });
    return null;
  }

  const document = unmarshall(newImage as Record<string, AttributeValue>);
  
  // Skip if document is marked as deleted (soft delete)
  if (document.deletedAt || document.isDeleted) {
    return deleteDocument(document, client, eventID);
  }

  return indexDocument(document, client, eventID, eventName);
}

/**
 * Index a document in OpenSearch
 */
async function indexDocument(
  document: Record<string, unknown>,
  client: Client,
  eventID: string,
  eventName: string
): Promise<void> {
  const entityType = detectEntityType(document);
  if (!entityType) {
    logger.warn('Could not detect entity type for document', {
      keys: Object.keys(document),
      eventID,
      handler: 'searchIndexer',
    });
    return;
  }

  const indexName = getIndexName(entityType, ENVIRONMENT);
  const docId = extractDocumentId(document, entityType);
  const searchDoc = transformToSearchDocument(document, entityType);

  if (!searchDoc.tenantId) {
    logger.warn('Document missing tenantId - skipping', { eventID, handler: 'searchIndexer' });
    return;
  }

  try {
    const response = await client.index({
      index: indexName,
      id: docId,
      body: searchDoc,
      refresh: false, // Let OpenSearch handle refresh
    });

    logger.info('Document indexed', {
      eventID,
      eventName,
      entityType,
      index: indexName,
      docId,
      result: response.body?.result,
      version: response.body?._version,
      handler: 'searchIndexer',
    });
  } catch (error) {
    logger.error('Failed to index document', {
      eventID,
      entityType,
      index: indexName,
      docId,
      error: error instanceof Error ? error.message : String(error),
      handler: 'searchIndexer',
    });
    throw error;
  }
}

/**
 * Delete a document from OpenSearch
 */
async function deleteDocument(
  document: Record<string, unknown>,
  client: Client,
  eventID: string
): Promise<void> {
  const entityType = detectEntityType(document);
  if (!entityType) {
    logger.warn('Could not detect entity type for deletion', { eventID, handler: 'searchIndexer' });
    return;
  }

  const indexName = getIndexName(entityType, ENVIRONMENT);
  const docId = extractDocumentId(document, entityType);

  try {
    await client.delete({
      index: indexName,
      id: docId,
    });

    logger.info('Document deleted', {
      eventID,
      entityType,
      index: indexName,
      docId,
      handler: 'searchIndexer',
    });
  } catch (error: unknown) {
    // 404 is acceptable - document may not exist in index
    if (isNotFoundError(error)) {
      logger.info('Document not found for deletion (already removed)', {
        eventID,
        docId,
        handler: 'searchIndexer',
      });
      return;
    }

    logger.error('Failed to delete document', {
      eventID,
      entityType,
      error: error instanceof Error ? error.message : String(error),
      handler: 'searchIndexer',
    });
    throw error;
  }
}

/**
 * Detect entity type from document structure
 */
function detectEntityType(document: Record<string, unknown>): SearchIndexName | null {
  // Check explicit entity type field
  const entityType = document.entityType || document._type || document.type;
  if (entityType && typeof entityType === 'string') {
    const mapped = ENTITY_TYPE_MAP[entityType.toUpperCase()];
    if (mapped) return mapped;
  }

  // Check SK (sort key) pattern for single-table design
  const sk = document.SK || document.sk || document.sortKey;
  if (sk && typeof sk === 'string') {
    // Extract entity type from SK prefix (e.g., "BILL#123" -> "BILL")
    const skPrefix = sk.split('#')[0].toUpperCase();
    const mapped = ENTITY_TYPE_MAP[skPrefix];
    if (mapped) return mapped;
  }

  // Infer from field patterns
  if (document.invoiceNumber && document.grandTotal !== undefined) return 'bills';
  if (document.gstin && document.totalDues !== undefined) return 'customers';
  if (document.sku && document.sellingPrice !== undefined) return 'products';
  if (document.batchNumber && document.expiryDate) return 'productBatches';
  if (document.creditDays && document.totalOutstanding !== undefined) return 'suppliers';
  if (document.billNumber && document.supplierId) return 'purchaseBills';
  if (document.bloodGroup && document.allergies) return 'patients';
  if (document.chiefComplaint && document.diagnosis) return 'visits';
  if (document.medicines && document.advice !== undefined) return 'prescriptions';
  if (document.kotId && (document.tableNumber || document.itemNames)) return 'kots';
  if (document.isVeg !== undefined || document.spiceLevel) return 'menuItems';
  if (document.debit !== undefined && document.credit !== undefined) return 'ledgerEntries';
  if (document.expenseDate && document.vendorName) return 'expenses';
  if (document.transactionDate && document.accountId) return 'bankTransactions';
  if (document.challanNumber && document.eWayBillNumber !== undefined) return 'deliveryChallans';
  if (document.isbns && document.vendorId) return 'bookReturns';
  if (document.expectedDate && document.advanceAmount !== undefined) return 'preOrders';
  if (document.problemDescription && (document.vehicleNumber || document.imei)) return 'serviceJobs';
  if (document.irn && document.ackNo) return 'eInvoices';
  if (document.litres && document.fuelType) return 'fuelTransactions';

  return null;
}

/**
 * Extract document ID for OpenSearch
 */
function extractDocumentId(document: Record<string, unknown>, entityType: SearchIndexName): string {
  // Try various ID fields
  const id = document.id || document.Id || document.ID ||
             document.billId || document.customerId || document.productId ||
             document.patientId || document.visitId || document.prescriptionId ||
             document.kotId || document.jobId || document.expenseId ||
             document.challanId || document.returnId || document.preOrderId ||
             document.transactionId || document.entryId || document.eInvoiceId ||
             document.supplierId || document.batchId || document.menuItemId ||
             document.PK || document.pk;

  if (id && typeof id === 'string') {
    // If PK contains composite key, extract just the ID part
    if (id.includes('#')) {
      return id.split('#').pop() || id;
    }
    return id;
  }

  // Fallback: generate from SK if available
  const sk = document.SK || document.sk;
  if (sk && typeof sk === 'string') {
    return sk.replace(/^[A-Z_]+#/, '');
  }

  // Last resort: generate deterministic ID
  return `generated-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Transform DynamoDB document to search-optimized document
 */
function transformToSearchDocument(
  document: Record<string, unknown>,
  entityType: SearchIndexName
): SearchDocument {
  const base: SearchDocument = {
    tenantId: extractTenantId(document),
    businessId: extractBusinessId(document),
    businessType: extractBusinessType(document),
  };

  // Entity-specific transformations
  switch (entityType) {
    case 'bills':
      return transformBill(document, base);
    case 'customers':
      return transformCustomer(document, base);
    case 'products':
      return transformProduct(document, base);
    case 'productBatches':
      return transformProductBatch(document, base);
    case 'suppliers':
      return transformSupplier(document, base);
    case 'purchaseBills':
      return transformPurchaseBill(document, base);
    case 'patients':
      return transformPatient(document, base);
    case 'visits':
      return transformVisit(document, base);
    case 'prescriptions':
      return transformPrescription(document, base);
    case 'kots':
      return transformKOT(document, base);
    case 'menuItems':
      return transformMenuItem(document, base);
    case 'ledgerEntries':
      return transformLedgerEntry(document, base);
    case 'expenses':
      return transformExpense(document, base);
    case 'bankTransactions':
      return transformBankTransaction(document, base);
    case 'deliveryChallans':
      return transformDeliveryChallan(document, base);
    case 'bookReturns':
      return transformBookReturn(document, base);
    case 'preOrders':
      return transformPreOrder(document, base);
    case 'serviceJobs':
      return transformServiceJob(document, base);
    case 'eInvoices':
      return transformEInvoice(document, base);
    case 'fuelTransactions':
      return transformFuelTransaction(document, base);
    default:
      return { ...base, ...document };
  }
}

// ============================================================================
// ENTITY TRANSFORMERS
// ============================================================================

function transformBill(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const items = (doc.items as Array<Record<string, unknown>>) || [];
  
  return {
    ...base,
    billId: doc.id || doc.billId,
    invoiceNumber: doc.invoiceNumber,
    customerId: doc.customerId,
    customerName: doc.customerName,
    customerPhone: doc.customerPhone,
    customerGstin: doc.customerGstin,
    subtotal: doc.subtotal,
    taxAmount: doc.taxAmount,
    discountAmount: doc.discountAmount,
    grandTotal: doc.grandTotal,
    paidAmount: doc.paidAmount,
    status: doc.status,
    paymentMode: doc.paymentMode,
    billDate: doc.billDate || doc.date,
    dueDate: doc.dueDate,
    tableNumber: doc.tableNumber,
    vehicleNumber: doc.vehicleNumber,
    prescriptionId: doc.prescriptionId,
    shiftId: doc.shiftId,
    kotId: doc.kotId,
    itemNames: items.map(i => i.productName || i.itemName || i.name).filter(Boolean).join(' '),
    itemSkus: items.map(i => i.sku || i.productId).filter(Boolean),
    isEInvoice: !!doc.irn,
    irn: doc.irn,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
    deletedAt: doc.deletedAt,
  };
}

function transformCustomer(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    customerId: doc.id || doc.customerId,
    name: doc.name,
    phone: doc.phone,
    email: doc.email,
    address: doc.address,
    gstin: doc.gstin,
    stateCode: doc.stateCode,
    totalDues: doc.totalDues,
    totalBilled: doc.totalBilled,
    totalPaid: doc.totalPaid,
    creditLimit: doc.creditLimit,
    isActive: doc.isActive,
    isBlacklisted: doc.isBlacklisted,
    isBlocked: doc.isBlocked,
    vehicleNumber: doc.vehicleNumber,
    loyaltyPoints: doc.loyaltyPoints,
    linkStatus: doc.linkStatus,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
    lastTransactionDate: doc.lastTransactionDate,
  };
}

function transformProduct(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const metadata = (doc.metadata as Record<string, unknown>) || {};
  
  return {
    ...base,
    productId: doc.id || doc.productId,
    name: doc.name,
    sku: doc.sku,
    barcode: doc.barcode,
    altBarcodes: doc.altBarcodes,
    category: doc.category,
    subCategory: doc.subCategory,
    brand: doc.brand || metadata.brand,
    type: doc.type,
    sellingPrice: doc.sellingPrice,
    costPrice: doc.costPrice,
    mrp: doc.mrp,
    hsnCode: doc.hsnCode,
    gstRate: doc.gstRate,
    stockQuantity: doc.stockQuantity || doc.quantity,
    lowStockThreshold: doc.lowStockThreshold,
    unit: doc.unit,
    baseUnit: doc.baseUnit,
    size: doc.size || metadata.size,
    color: doc.color || metadata.color,
    groupId: doc.groupId,
    drugSchedule: doc.drugSchedule,
    isbn: doc.isbn,
    author: doc.author,
    publisher: doc.publisher,
    purity: doc.purity,
    metalWeight: doc.metalWeight,
    makingCharges: doc.makingCharges,
    hallmark: doc.hallmark,
    imei: doc.imei || metadata.imei,
    serialNumber: doc.serialNumber || metadata.serialNumber,
    warrantyMonths: doc.warrantyMonths,
    isActive: doc.isActive,
    isLowStock: (doc.stockQuantity as number || 0) <= (doc.lowStockThreshold as number || 10),
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformProductBatch(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const expiryDate = doc.expiryDate ? new Date(doc.expiryDate as string) : null;
  const now = new Date();
  const isExpired = expiryDate ? expiryDate < now : false;
  const isNearExpiry = expiryDate ? 
    (expiryDate.getTime() - now.getTime()) < (30 * 24 * 60 * 60 * 1000) : false;

  return {
    ...base,
    batchId: doc.id || doc.batchId,
    productId: doc.productId,
    productName: doc.productName,
    batchNumber: doc.batchNumber,
    manufactureDate: doc.manufactureDate,
    expiryDate: doc.expiryDate,
    quantity: doc.quantity,
    availableQuantity: doc.availableQuantity,
    unit: doc.unit,
    purchasePrice: doc.purchasePrice,
    sellingPrice: doc.sellingPrice,
    drugSchedule: doc.drugSchedule,
    isExpired,
    isNearExpiry,
    isActive: doc.isActive,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformSupplier(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    supplierId: doc.id || doc.supplierId,
    name: doc.name,
    phone: doc.phone,
    email: doc.email,
    address: doc.address,
    gstin: doc.gstin,
    pan: doc.pan,
    bankName: doc.bankName,
    accountNumber: doc.accountNumber,
    ifscCode: doc.ifscCode,
    upiId: doc.upiId,
    totalPurchased: doc.totalPurchased,
    totalPaid: doc.totalPaid,
    totalOutstanding: doc.totalOutstanding,
    creditDays: doc.creditDays,
    creditLimit: doc.creditLimit,
    isActive: doc.isActive,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformPurchaseBill(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const items = (doc.items as Array<Record<string, unknown>>) || [];
  
  return {
    ...base,
    purchaseBillId: doc.id || doc.purchaseBillId,
    billNumber: doc.billNumber,
    supplierId: doc.supplierId,
    supplierName: doc.supplierName,
    supplierPhone: doc.supplierPhone,
    supplierGstin: doc.supplierGstin,
    subtotal: doc.subtotal,
    totalTax: doc.totalTax,
    grandTotal: doc.grandTotal,
    paidAmount: doc.paidAmount,
    pendingAmount: (doc.grandTotal as number || 0) - (doc.paidAmount as number || 0),
    status: doc.status,
    paymentMode: doc.paymentMode,
    date: doc.date || doc.purchaseDate,
    dueDate: doc.dueDate,
    itemNames: items.map(i => i.itemName || i.name).filter(Boolean).join(' '),
    itemIds: items.map(i => i.itemId).filter(Boolean),
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformPatient(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    patientId: doc.id || doc.patientId,
    customerId: doc.customerId,
    name: doc.name,
    phone: doc.phone,
    age: doc.age,
    gender: doc.gender,
    bloodGroup: doc.bloodGroup,
    allergies: Array.isArray(doc.allergies) ? doc.allergies.join(' ') : doc.allergies,
    chronicConditions: Array.isArray(doc.chronicConditions) ? doc.chronicConditions.join(' ') : doc.chronicConditions,
    emergencyContactName: doc.emergencyContactName,
    emergencyContactPhone: doc.emergencyContactPhone,
    lastVisitId: doc.lastVisitId,
    lastVisitDate: doc.lastVisitDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformVisit(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    visitId: doc.id || doc.visitId,
    patientId: doc.patientId,
    patientName: doc.patientName,
    doctorId: doc.doctorId,
    doctorName: doc.doctorName,
    chiefComplaint: doc.chiefComplaint,
    diagnosis: doc.diagnosis,
    symptoms: Array.isArray(doc.symptoms) ? doc.symptoms.join(' ') : doc.symptoms,
    notes: doc.notes,
    bp: doc.bp,
    temperature: doc.temperature,
    weight: doc.weight,
    pulse: doc.pulse,
    spO2: doc.spO2,
    prescriptionId: doc.prescriptionId,
    billId: doc.billId,
    status: doc.status,
    visitDate: doc.visitDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformPrescription(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const medicines = (doc.medicines as Array<Record<string, unknown>>) || [];
  
  return {
    ...base,
    prescriptionId: doc.id || doc.prescriptionId,
    visitId: doc.visitId,
    patientId: doc.patientId,
    patientName: doc.patientName,
    doctorId: doc.doctorId,
    doctorName: doc.doctorName,
    medicines: medicines.map(m => m.name || m.medicineName).filter(Boolean).join(' '),
    medicineNames: medicines.map(m => m.name || m.medicineName).filter(Boolean),
    advice: doc.advice,
    nextVisitDate: doc.nextVisitDate,
    date: doc.date,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformKOT(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const items = (doc.items as Array<Record<string, unknown>>) || [];
  
  return {
    ...base,
    kotId: doc.id || doc.kotId,
    billId: doc.billId,
    tableNumber: doc.tableNumber,
    section: doc.section,
    itemNames: items.map(i => i.name || i.itemName).filter(Boolean).join(' '),
    itemCount: items.length,
    totalAmount: doc.totalAmount,
    status: doc.status,
    priority: doc.priority,
    waiterId: doc.waiterId,
    waiterName: doc.waiterName,
    orderTime: doc.orderTime,
    preparationTime: doc.preparationTime,
    completionTime: doc.completionTime,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformMenuItem(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    menuItemId: doc.id || doc.menuItemId,
    name: doc.name,
    description: doc.description,
    category: doc.category,
    subCategory: doc.subCategory,
    cuisine: doc.cuisine,
    price: doc.price,
    discountedPrice: doc.discountedPrice,
    isVeg: doc.isVeg,
    isVegan: doc.isVegan,
    isGlutenFree: doc.isGlutenFree,
    spiceLevel: doc.spiceLevel,
    isAvailable: doc.isAvailable,
    isActive: doc.isActive,
    ingredients: Array.isArray(doc.ingredients) ? doc.ingredients.join(' ') : doc.ingredients,
    allergens: doc.allergens,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformLedgerEntry(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    entryId: doc.id || doc.entryId,
    ledgerId: doc.ledgerId,
    ledgerName: doc.ledgerName,
    ledgerType: doc.ledgerType,
    ledgerGroup: doc.ledgerGroup,
    referenceId: doc.referenceId,
    referenceType: doc.referenceType,
    description: doc.description,
    debit: doc.debit,
    credit: doc.credit,
    amount: doc.amount,
    runningBalance: doc.runningBalance,
    partyId: doc.partyId,
    partyName: doc.partyName,
    transactionDate: doc.transactionDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformExpense(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    expenseId: doc.id || doc.expenseId,
    category: doc.category,
    description: doc.description,
    vendorName: doc.vendorName,
    vendorId: doc.vendorId,
    amount: doc.amount,
    paymentMode: doc.paymentMode,
    referenceNumber: doc.referenceNumber,
    hasReceipt: !!(doc.receiptImagePath || doc.receiptUrl),
    receiptUrl: doc.receiptUrl,
    expenseDate: doc.expenseDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformBankTransaction(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    transactionId: doc.id || doc.transactionId,
    accountId: doc.accountId,
    accountName: doc.accountName,
    type: doc.type,
    category: doc.category,
    description: doc.description,
    amount: doc.amount,
    referenceId: doc.referenceId,
    referenceType: doc.referenceType,
    balance: doc.balance,
    transactionDate: doc.transactionDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformDeliveryChallan(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const items = (doc.items as Array<Record<string, unknown>>) || 
                  (doc.itemsJson ? JSON.parse(doc.itemsJson as string) : []);
  
  return {
    ...base,
    challanId: doc.id || doc.challanId,
    challanNumber: doc.challanNumber,
    customerId: doc.customerId,
    customerName: doc.customerName,
    subtotal: doc.subtotal,
    taxAmount: doc.taxAmount,
    grandTotal: doc.grandTotal,
    transportMode: doc.transportMode,
    vehicleNumber: doc.vehicleNumber,
    eWayBillNumber: doc.eWayBillNumber,
    status: doc.status,
    convertedBillId: doc.convertedBillId,
    challanDate: doc.challanDate,
    dueDate: doc.dueDate,
    itemNames: items.map((i: Record<string, unknown>) => i.name || i.itemName || i.productName).filter(Boolean).join(' '),
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformBookReturn(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  const items = (doc.items as Array<Record<string, unknown>>) || 
                  (doc.itemsJson ? JSON.parse(doc.itemsJson as string) : []);
  
  return {
    ...base,
    returnId: doc.id || doc.returnId,
    vendorId: doc.vendorId,
    vendorName: doc.vendorName,
    isbns: items.map((i: Record<string, unknown>) => i.isbn).filter(Boolean),
    titles: items.map((i: Record<string, unknown>) => i.title || i.name).filter(Boolean).join(' '),
    itemCount: items.length,
    totalAmount: doc.totalAmount,
    status: doc.status,
    returnDate: doc.returnDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformPreOrder(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    preOrderId: doc.id || doc.preOrderId,
    customerId: doc.customerId,
    customerName: doc.customerName,
    customerPhone: doc.customerPhone,
    productId: doc.productId,
    productName: doc.productName,
    quantity: doc.quantity,
    advanceAmount: doc.advanceAmount,
    totalAmount: doc.totalAmount,
    status: doc.status,
    priority: doc.priority,
    expectedDate: doc.expectedDate,
    notes: doc.notes,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformServiceJob(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    jobId: doc.id || doc.jobId,
    jobNumber: doc.jobNumber,
    customerId: doc.customerId,
    customerName: doc.customerName,
    customerPhone: doc.customerPhone,
    vehicleNumber: doc.vehicleNumber,
    vehicleModel: doc.vehicleModel,
    imei: doc.imei,
    serialNumber: doc.serialNumber,
    problemDescription: doc.problemDescription,
    diagnosedIssue: doc.diagnosedIssue,
    status: doc.status,
    priority: doc.priority,
    estimatedCost: doc.estimatedCost,
    partsCost: doc.partsCost,
    laborCharge: doc.laborCharge,
    totalAmount: doc.totalAmount,
    assignedTo: doc.assignedTo,
    technicianName: doc.technicianName,
    receivedDate: doc.receivedDate,
    promisedDate: doc.promisedDate,
    completedDate: doc.completedDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformEInvoice(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    eInvoiceId: doc.id || doc.eInvoiceId,
    irn: doc.irn,
    ackNo: doc.ackNo,
    billId: doc.billId,
    invoiceNumber: doc.invoiceNumber,
    customerGstin: doc.customerGstin,
    customerName: doc.customerName,
    taxableAmount: doc.taxableAmount,
    cgst: doc.cgst,
    sgst: doc.sgst,
    igst: doc.igst,
    totalAmount: doc.totalAmount,
    status: doc.status,
    gstPortalStatus: doc.gstPortalStatus,
    invoiceDate: doc.invoiceDate,
    ackDate: doc.ackDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

function transformFuelTransaction(doc: Record<string, unknown>, base: SearchDocument): SearchDocument {
  return {
    ...base,
    transactionId: doc.id || doc.transactionId,
    billId: doc.billId,
    shiftId: doc.shiftId,
    dispenserId: doc.dispenserId,
    dispenserName: doc.dispenserName,
    nozzleId: doc.nozzleId,
    nozzleName: doc.nozzleName,
    fuelType: doc.fuelType,
    fuelTypeId: doc.fuelTypeId,
    litres: doc.litres,
    pricePerLitre: doc.pricePerLitre,
    amount: doc.amount,
    discount: doc.discount,
    totalAmount: doc.totalAmount,
    vehicleNumber: doc.vehicleNumber,
    driverName: doc.driverName,
    paymentMode: doc.paymentMode,
    pumpReadingStart: doc.pumpReadingStart,
    pumpReadingEnd: doc.pumpReadingEnd,
    attendantId: doc.attendantId,
    attendantName: doc.attendantName,
    transactionDate: doc.transactionDate,
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
  };
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function extractTenantId(doc: Record<string, unknown>): string {
  // Try various tenant ID fields
  const tenantId = doc.tenantId || doc.TenantId || doc.tenant_id ||
                   doc.ownerId || doc.userId || doc.businessOwnerId ||
                   doc.PK?.toString().split('#')[1]; // Extract from PK like "TENANT#123"
  
  if (tenantId && typeof tenantId === 'string') {
    return tenantId;
  }
  
  return 'unknown';
}

function extractBusinessId(doc: Record<string, unknown>): string | undefined {
  const businessId = doc.businessId || doc.shopId || doc.storeId || doc.branchId;
  return businessId as string | undefined;
}

function extractBusinessType(doc: Record<string, unknown>): string | undefined {
  const businessType = doc.businessType || doc.type || doc.storeType;
  return businessType as string | undefined;
}

function isRetryableError(error: unknown): boolean {
  if (error instanceof Error) {
    // Network errors, timeouts are retryable
    const retryablePatterns = [
      'ECONNRESET',
      'ETIMEDOUT',
      'ENOTFOUND',
      'Connection refused',
      'timeout',
      'Rate exceeded',
    ];
    return retryablePatterns.some(pattern => 
      error.message.includes(pattern)
    );
  }
  return false;
}

function isNotFoundError(error: unknown): boolean {
  if (error instanceof Error) {
    return error.message.includes('404') || 
           error.message.includes('not_found') ||
           error.message.includes('Not Found');
  }
  return false;
}
