// ============================================================================
// DUKANX ENTERPRISE DATABASE SCHEMA
// ============================================================================
// Drift (SQLite) Database for Offline-First Architecture
//
// Design Principles:
// - Local database is the SINGLE SOURCE OF TRUTH
// - Firestore is a replica/backup
// - All operations must succeed offline
// - Zero data loss tolerance
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:drift/drift.dart';

// ============================================================================
// SYSTEM COLUMNS (offline-license-activation, schemaVersion v39)
// ============================================================================
//
// Universal "System_Columns" required by the offline Local_Store contract
// (Requirement 8.1). Existing tables already define id, created_at, updated_at,
// deleted_at and a version column. This mixin adds ONLY the columns that were
// previously missing — tenant_id, sync_status, server_id and local_version — to
// the cloud-entity tables via the additive migration ladder.
//
// They are intentionally NULLABLE so the migration is purely additive: existing
// rows keep all their values, no backfill is required, and the generated Drift
// data classes keep these as optional constructor parameters (so existing
// direct-construction call sites continue to compile unchanged).
mixin TableSystemColumns on Table {
  /// Owning tenant identifier (multi-tenant isolation). Backfilled by the
  /// service layer; nullable for legacy rows created before v39.
  TextColumn get tenantId => text().nullable()();

  /// Per-row synchronization marker, e.g. `pending` | `synced`.
  TextColumn get syncStatus => text().nullable()();

  /// Server-assigned identifier, populated once the row is synced.
  TextColumn get serverId => text().nullable()();

  /// Monotonic local revision, incremented on each offline write.
  IntColumn get localVersion => integer().nullable()();
}

// ============================================================================
// CORE TABLES
// ============================================================================

/// Sync Queue - The heart of offline-first architecture
/// Tracks all pending operations that need to sync to Firestore
@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  // Unique operation ID (deterministic for idempotency)
  TextColumn get operationId => text()();

  // Type of operation: CREATE, UPDATE, DELETE
  TextColumn get operationType => text()();

  // Target collection in Firestore (e.g., 'bills', 'customers')
  TextColumn get targetCollection => text()();

  // Document ID in the collection
  TextColumn get documentId => text()();

  // JSON payload to sync
  TextColumn get payload => text()();

  // NEW: Integrity Check (SHA-256 of payload only)
  TextColumn get payloadHash => text().withDefault(const Constant(''))();

  // Current state: PENDING, IN_PROGRESS, SYNCED, FAILED, RETRY, DEAD_LETTER
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  // Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  // Last error message if failed
  TextColumn get lastError => text().nullable()();

  // Timestamp when operation was created
  DateTimeColumn get createdAt => dateTime()();

  // Timestamp when operation was last attempted
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  // Timestamp when operation was successfully synced
  DateTimeColumn get syncedAt => dateTime().nullable()();

  // Priority (lower = higher priority)
  IntColumn get priority => integer().withDefault(const Constant(5))();

  // Parent operation ID (for multi-step operations)
  TextColumn get parentOperationId => text().nullable()();

  // NEW: Strict Ordering Group
  // Items with same dependencyGroup must be processed strictly sequentially
  TextColumn get dependencyGroup => text().nullable()();

  // Step number in multi-step operations
  IntColumn get stepNumber => integer().withDefault(const Constant(1))();

  // Total steps in multi-step operations
  IntColumn get totalSteps => integer().withDefault(const Constant(1))();

  // User ID (Legacy, mapped to ownerId concept)
  TextColumn get userId => text()();

  // NEW: Owner Isolation (Explicit)
  // Prevents cross-tenant data leaks even if userId is ambiguous
  TextColumn get ownerId => text().withDefault(const Constant('UNKNOWN'))();

  // Device ID (for multi-device conflict resolution)
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Bills - Core billing data
@TableIndex(name: 'idx_bills_user_id', columns: {#userId})
@TableIndex(name: 'idx_bills_bill_date', columns: {#billDate})
@TableIndex(name: 'idx_bills_customer_id', columns: {#customerId})
@TableIndex(name: 'idx_bills_user_date', columns: {#userId, #billDate})
@TableIndex(name: 'idx_bills_user_invoice', columns: {#userId, #invoiceNumber})
@DataClassName('BillEntity')
class Bills extends Table with TableSystemColumns {
  // Unique bill ID (UUID)
  TextColumn get id => text()();

  // User/Business owner ID
  TextColumn get userId => text()();

  // Business ID (Shop ID) - For data isolation
  TextColumn get businessId => text().nullable()();

  // Invoice number (human-readable)
  TextColumn get invoiceNumber => text()();

  // Customer ID
  TextColumn get customerId => text().nullable()();

  // Customer Profile ID (Shop-Scoped - for linked customers)
  // CRITICAL: Use this for bills to linked customers, not customerId
  // This enables shop-level data isolation for multi-tenant customer linking
  TextColumn get customerProfileId => text().nullable()();

  // Customer name (denormalized for offline access)
  TextColumn get customerName => text().nullable()();

  // Bill date
  DateTimeColumn get billDate => dateTime()();

  // Due date
  DateTimeColumn get dueDate => dateTime().nullable()();

  // Subtotal (before tax)
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();

  // Tax amount
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();

  // Discount amount
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();

  // Grand total
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();

  // Amount paid
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();

  // Status: DRAFT, PENDING, PARTIAL, PAID, OVERDUE, CANCELLED
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();

  // Payment mode: CASH, UPI, CARD, BANK_TRANSFER, CREDIT
  TextColumn get paymentMode => text().nullable()();

  // Notes
  TextColumn get notes => text().nullable()();

  // Items JSON (serialized bill items)
  TextColumn get itemsJson => text()();

  // Source: MANUAL, SCAN, VOICE
  TextColumn get source => text().withDefault(const Constant('MANUAL'))();

  // Scan/Voice related data
  TextColumn get sourceImagePath => text().nullable()();
  TextColumn get sourceAudioPath => text().nullable()();
  TextColumn get ocrRawText => text().nullable()();

  // Split Payment Support
  RealColumn get cashPaid => real().withDefault(const Constant(0.0))();
  RealColumn get onlinePaid => real().withDefault(const Constant(0.0))();

  // Business Type & Extra Charges
  TextColumn get businessType =>
      text().withDefault(const Constant('grocery'))();
  RealColumn get serviceCharge => real().withDefault(const Constant(0.0))();

  // Per-Bill Profit Tracking (COGS-based)
  // Stored at sale time for accurate historical profit
  RealColumn get costOfGoodsSold => real().withDefault(const Constant(0.0))();
  RealColumn get grossProfit => real().withDefault(const Constant(0.0))();

  // Print Tracking (Freezing Logic)
  IntColumn get printCount => integer().withDefault(const Constant(0))();

  // Sync status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  // Delivery Challan Link
  TextColumn get deliveryChallanId => text().nullable()();

  // Petrol Pump: Link to active shift for reconciliation
  // FRAUD PREVENTION: Every fuel sale must belong to exactly one shift
  // Enables nozzle reading vs billed litres verification
  TextColumn get shiftId => text().nullable()();

  // Medical: Link to Doctor Prescription
  TextColumn get prescriptionId => text().nullable()();

  // Restaurant
  TextColumn get tableNumber => text().nullable()();
  TextColumn get waiterId => text().nullable()();
  TextColumn get kotId => text().nullable()();

  // Petrol Pump / Service Center
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get driverName => text().nullable()();
  TextColumn get attendantId =>
      text().nullable()(); // NEW: Staff who served this bill
  TextColumn get fuelType => text().nullable()(); // Petrol, Diesel, CNG
  RealColumn get pumpReadingStart => real().nullable()();
  RealColumn get pumpReadingEnd => real().nullable()();

  // Mandi / Broker
  TextColumn get brokerId => text().nullable()();
  RealColumn get marketCess => real().withDefault(const Constant(0.0))();
  RealColumn get commissionAmount => real().withDefault(const Constant(0.0))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  // Version for conflict resolution (optimistic locking)
  IntColumn get version => integer().withDefault(const Constant(1))();

  // Server timestamp from Firestore (for conflict detection)
  DateTimeColumn get serverTimestamp => dateTime().nullable()();

  // Device ID that last modified this record (for conflict resolution)
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bill Items - Line items for each bill
@DataClassName('BillItemEntity')
class BillItems extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get billId =>
      text().references(Bills, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get unitPrice => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  // GST fields
  TextColumn get hsnCode => text().nullable()();
  RealColumn get cgstRate => real().withDefault(const Constant(0))();
  RealColumn get cgstAmount => real().withDefault(const Constant(0))();
  RealColumn get sgstRate => real().withDefault(const Constant(0))();
  RealColumn get sgstAmount => real().withDefault(const Constant(0))();
  RealColumn get igstRate => real().withDefault(const Constant(0))();
  RealColumn get igstAmount => real().withDefault(const Constant(0))();

  // Cloth Store Fields
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();

  // Medical Compliance
  TextColumn get drugSchedule => text().nullable()(); // H, H1, X etc.

  // Batch Info (Pharmacy/FMCG)
  TextColumn get batchId => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();

  // Electronics / Mobile Shop
  TextColumn get imei => text().nullable()();
  TextColumn get serialNumber => text().nullable()();

  // Warranty Info
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();

  // Service / Repair
  TextColumn get problemDescription => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customers
@TableIndex(name: 'idx_customers_user_id', columns: {#userId})
@TableIndex(name: 'idx_customers_phone', columns: {#phone})
@DataClassName('CustomerEntity')
class Customers extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get gstin => text().nullable()();
  RealColumn get totalBilled => real().withDefault(const Constant(0.0))();
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();
  RealColumn get totalDues => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  // Device ID that last modified this record
  TextColumn get deviceId => text().nullable()();
  // GST/Credit fields
  TextColumn get stateCode => text().nullable()(); // 2-digit state code
  IntColumn get creditPeriodDays => integer().withDefault(const Constant(0))();
  RealColumn get creditLimit => real().withDefault(const Constant(0))();
  BoolColumn get optInSmsReminders =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get optInWhatsAppReminders =>
      boolean().withDefault(const Constant(true))();

  // ============================================
  // Customer Master Tab Enhancement Fields
  // ============================================
  // Customer type: cash, credit, regular, wholesale
  TextColumn get customerType =>
      text().withDefault(const Constant('regular'))();
  // Opening balance for legacy customers
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  // Price level: retail, wholesale, custom
  TextColumn get priceLevel => text().nullable()();
  // GST preference: inclusive, exclusive, exempt
  TextColumn get gstPreference =>
      text().withDefault(const Constant('exclusive'))();
  // Block status for disputed customers
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();
  TextColumn get blockReason => text().nullable()();
  // Last transaction date for aging calculations
  DateTimeColumn get lastTransactionDate => dateTime().nullable()();

  // ============================================
  // Customer Linking Fields
  // ============================================
  // Token for secure linking
  TextColumn get linkToken => text().nullable()();
  // Expiry for the link
  DateTimeColumn get linkExpiresAt => dateTime().nullable()();
  // Status: UNLINKED, PENDING, LINKED
  TextColumn get linkStatus => text().withDefault(const Constant('UNLINKED'))();
  // Loyalty system
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  // Enforce unique phone per vendor (userId) to prevent duplicates
  @override
  List<Set<Column>>? get uniqueKeys => [
    {phone, userId},
  ];
}

/// Products/Inventory
@TableIndex(name: 'idx_products_user_id', columns: {#userId})
@TableIndex(name: 'idx_products_barcode', columns: {#barcode})
@TableIndex(name: 'idx_products_sku', columns: {#sku})
@DataClassName('ProductEntity')
class Products extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get sellingPrice => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get lowStockThreshold =>
      real().withDefault(const Constant(10.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  // Device ID that last modified this record
  TextColumn get deviceId => text().nullable()();
  // GST fields
  TextColumn get hsnCode => text().nullable()();
  RealColumn get cgstRate => real().withDefault(const Constant(0))();
  RealColumn get sgstRate => real().withDefault(const Constant(0))();
  RealColumn get igstRate => real().withDefault(const Constant(0))();

  // Cloth Store Fields
  TextColumn get size => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get brand => text().nullable()();
  // Alternate Barcodes (comma separated list)
  TextColumn get altBarcodes => text().nullable()();

  // Garment Variant Linking
  TextColumn get groupId => text().nullable()(); // Links variants together
  TextColumn get variantAttributes =>
      text().nullable()(); // JSON string e.g. {"Size": "M", "Color": "Red"}

  // Medical Compliance
  TextColumn get drugSchedule => text().nullable()(); // H, H1, X etc.

  // Book Store fields
  TextColumn get isbn => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get publisher => text().nullable()();

  // Wholesale MOQ & multi-unit (Phase 4 — Schema_Gate approved)
  // Nullable: existing products get null (no MOQ configured = no enforcement).
  IntColumn get moq => integer().nullable()();
  IntColumn get unitConversionFactor => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Payments
@TableIndex(name: 'idx_payments_user_id', columns: {#userId})
@TableIndex(name: 'idx_payments_bill_id', columns: {#billId})
@TableIndex(name: 'idx_payments_customer_id', columns: {#customerId})
@DataClassName('PaymentEntity')
class Payments extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get billId => text()();
  TextColumn get customerId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get paymentMode => text()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paymentDate => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Payment Transactions - Audit trail for Dynamic QR payments
@DataClassName('PaymentTransactionEntity')
class PaymentTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get vendorId => text()(); // The vendor who should receive money

  // UPI Transaction Details
  TextColumn get transactionRef => text()(); // Unique TR generated for QR
  RealColumn get amount => real()();
  TextColumn get status => text().withDefault(
    const Constant('PENDING'),
  )(); // PENDING, SUCCESS, FAILED
  TextColumn get paymentMode => text().withDefault(const Constant('UPI_QR'))();

  // Security & Fraud Defense (Layer 1, 2, 5, 7)
  TextColumn get nonce => text().nullable()(); // UUIDv7 for anti-replay
  TextColumn get signature => text().nullable()(); // HMAC_SHA256 signature
  DateTimeColumn get expiresAt => dateTime().nullable()(); // Time-bound expiry
  TextColumn get transactionFingerprint =>
      text().nullable()(); // Hash of critical fields
  TextColumn get payerUpi =>
      text().nullable()(); // Captured from callback/input

  // Verification
  TextColumn get scannedByParams =>
      text().nullable()(); // Full raw text if needed
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Delivery Challans - For goods movement without tax invoice
@DataClassName('DeliveryChallanEntity')
class DeliveryChallans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get challanNumber => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()(); // Denormalized link
  DateTimeColumn get challanDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  // Amounts
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();

  // Status: DRAFT, SENT, CONVERTED, CANCELLED
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();

  // Transport Details
  TextColumn get transportMode => text().nullable()();
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get eWayBillNumber => text().nullable()();
  TextColumn get shippingAddress => text().nullable()();
  TextColumn get lrNumber => text().nullable()();
  TextColumn get transporterName => text().nullable()();

  // Items JSON
  TextColumn get itemsJson => text()();

  // Converted Invoice Link
  TextColumn get convertedBillId => text().nullable()();

  // Sync status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Expenses
@DataClassName('ExpenseEntity')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get paymentMode => text().nullable()();
  TextColumn get vendorName => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  DateTimeColumn get expenseDate => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// File Upload Queue - For images, audio, etc.
@DataClassName('FileUploadEntry')
class FileUploads extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get localPath => text()();
  TextColumn get remotePath => text().nullable()(); // Firebase Storage path
  TextColumn get remoteUrl => text().nullable()(); // Download URL after upload
  TextColumn get mimeType => text()();
  IntColumn get fileSizeBytes => integer()();
  TextColumn get associatedCollection => text().nullable()(); // e.g., 'bills'
  TextColumn get associatedDocumentId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get uploadedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// OCR Processing Queue
@DataClassName('OcrTaskEntity')
class OcrTasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get imageLocalPath => text()();
  TextColumn get imageRemoteUrl => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  // PENDING -> IMAGE_UPLOADING -> IMAGE_UPLOADED -> OCR_PROCESSING -> OCR_COMPLETE -> PARSED -> BILL_CREATED -> DONE
  TextColumn get currentStep => text().withDefault(const Constant('PENDING'))();
  TextColumn get rawOcrText => text().nullable()();
  TextColumn get parsedDataJson => text().nullable()();
  TextColumn get resultBillId => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Voice Processing Queue
@DataClassName('VoiceTaskEntity')
class VoiceTasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get audioLocalPath => text()();
  TextColumn get audioRemoteUrl => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  // PENDING -> AUDIO_UPLOADING -> AUDIO_UPLOADED -> STT_PROCESSING -> STT_COMPLETE -> NLP_PARSING -> PARSED -> BILL_CREATED -> DONE
  TextColumn get currentStep => text().withDefault(const Constant('PENDING'))();
  TextColumn get transcribedText => text().nullable()();
  TextColumn get parsedDataJson => text().nullable()();
  TextColumn get resultBillId => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Schema Version Tracking
@DataClassName('SchemaVersionEntity')
class SchemaVersions extends Table {
  IntColumn get version => integer()();
  TextColumn get description => text()();
  DateTimeColumn get appliedAt => dateTime()();
  BoolColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {version};
}

/// Data Integrity Checksums
@DataClassName('ChecksumEntity')
class Checksums extends Table {
  TextColumn get targetTableName => text()();
  TextColumn get userId => text()();
  IntColumn get recordCount => integer()();
  TextColumn get checksum => text()(); // MD5 or SHA256 of key data
  DateTimeColumn get calculatedAt => dateTime()();
  TextColumn get serverChecksum => text().nullable()();
  DateTimeColumn get serverChecksumAt => dateTime().nullable()();
  BoolColumn get isMatching => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {targetTableName, userId};
}

/// Audit Log - Track all changes for debugging and recovery
@DataClassName('AuditLogEntity')
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get targetTableName => text()();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE
  TextColumn get oldValueJson => text().nullable()();
  TextColumn get newValueJson => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get appVersion => text().nullable()();

  // Tamper-Evident Security (Hash Chain)
  // previousHash = Hash of previous log's (currentHash + signature)
  TextColumn get previousHash => text().nullable()();
  // currentHash = SHA256(previousHash + canonicalJson(this_record))
  TextColumn get currentHash => text().nullable()();
}

/// Conflict Log - Track sync conflicts for audit and recovery
@DataClassName('ConflictLogEntry')
class ConflictLog extends Table {
  // Unique conflict ID
  TextColumn get id => text()();

  // Target entity info
  TextColumn get collection => text()();
  TextColumn get documentId => text()();
  TextColumn get userId => text()();

  // Device info
  TextColumn get localDeviceId => text()();
  TextColumn get serverDeviceId => text().nullable()();

  // Version info
  IntColumn get localVersion => integer()();
  IntColumn get serverVersion => integer()();

  // Resolution strategy used
  // Values: SERVER_WINS, LOCAL_WINS, MERGED, MANUAL
  TextColumn get resolution => text()();

  // Data snapshots (for recovery)
  TextColumn get localDataJson => text()();
  TextColumn get serverDataJson => text()();

  // Merged result (if applicable)
  TextColumn get mergedDataJson => text().nullable()();

  // Timestamps
  DateTimeColumn get conflictDetectedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  // Status
  BoolColumn get isResolved => boolean().withDefault(const Constant(true))();
  TextColumn get resolutionNotes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dead Letter Queue - Failed operations that need manual intervention
@DataClassName('DeadLetterEntity')
class DeadLetterQueue extends Table {
  TextColumn get id => text()();
  TextColumn get originalOperationId => text()();
  TextColumn get userId => text()();
  TextColumn get operationType => text()();
  TextColumn get targetCollection => text()();
  TextColumn get documentId => text()();
  TextColumn get payload => text()();
  TextColumn get failureReason => text()();
  IntColumn get totalAttempts => integer()();
  DateTimeColumn get firstAttemptAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime()();
  DateTimeColumn get movedToDeadLetterAt => dateTime()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  TextColumn get resolutionNotes => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bank Accounts - Store cash, bank, or digital wallet accounts
@DataClassName('BankAccountEntity')
class BankAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get accountName =>
      text()(); // e.g., 'SBI Main', 'Cash in Hand', 'PhonePe'
  TextColumn get bankName => text().nullable()();
  TextColumn get accountNumber => text().nullable()();
  TextColumn get ifsc => text().nullable()();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bank Transactions - Ledger for bank accounts
@DataClassName('BankTransactionEntity')
class BankTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get accountId => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // CREDIT, DEBIT
  TextColumn get category =>
      text()(); // SALE, PURCHASE, EXPENSE, TRANSFER, INITIAL
  TextColumn get referenceId => text().nullable()(); // billId, expenseId, etc.
  TextColumn get description => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vendors - Single source of truth for supplier data
@DataClassName('VendorEntity')
class Vendors extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get gstin => text().nullable()();

  // Dynamic QR Support
  TextColumn get upiId => text().nullable()(); // e.g. merchant@upi
  TextColumn get upiName => text().nullable()(); // e.g. Merchant Store Name

  RealColumn get totalPurchased => real().withDefault(const Constant(0.0))();
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();
  RealColumn get totalOutstanding => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Purchase Orders - Track inward stock
@TableIndex(name: 'idx_po_user_id', columns: {#userId})
@TableIndex(name: 'idx_po_vendor_id', columns: {#vendorId})
@TableIndex(name: 'idx_po_date', columns: {#purchaseDate})
@TableIndex(name: 'idx_po_invoice', columns: {#invoiceNumber})
@DataClassName('PurchaseOrderEntity')
class PurchaseOrders extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get vendorId => text().nullable()();
  TextColumn get vendorName => text().nullable()();
  TextColumn get invoiceNumber => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime()();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(
    const Constant('COMPLETED'),
  )(); // PENDING, COMPLETED, CANCELLED
  TextColumn get paymentMode => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PETROL PUMP MODULE TABLES (OFFLINE-FIRST)
// ============================================================================

/// Shifts - Critical for session-based sales tracking
@DataClassName('ShiftEntity')
class Shifts extends Table {
  TextColumn get shiftId => text()();
  TextColumn get ownerId => text()();
  TextColumn get shiftName => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();

  // Status: OPEN, CLOSED
  TextColumn get status => text().withDefault(const Constant('OPEN'))();

  // Staff Assignment (JSON List of IDs)
  TextColumn get assignedEmployeeIds => text()();

  // Reconciliation Data
  RealColumn get totalSaleAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalLitresSold => real().withDefault(const Constant(0.0))();
  RealColumn get cashCollected => real().withDefault(const Constant(0.0))();
  RealColumn get cashDeclared => real().withDefault(const Constant(0.0))();
  RealColumn get cashVariance => real().withDefault(const Constant(0.0))();

  TextColumn get closedBy => text().nullable()();
  TextColumn get notes => text().nullable()();

  // Full Reconciliation Snapshot (JSON)
  TextColumn get reconciliationJson => text().nullable()();

  BoolColumn get wasForced => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {shiftId};
}

/// Dispensers - Physical pump units
@DataClassName('DispenserEntity')
class Dispensers extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()(); // e.g. "Dispenser 1"
  TextColumn get make => text().nullable()(); // e.g. "Gilbarco"
  TextColumn get model => text().nullable()();
  TextColumn get linkedTankId =>
      text().nullable()(); // Default tank for this dispenser

  // Calibration Tracking (Government Compliance)
  DateTimeColumn get lastCalibrationDate => dateTime().nullable()();
  DateTimeColumn get nextCalibrationDate => dateTime().nullable()();
  IntColumn get calibrationIntervalDays =>
      integer().withDefault(const Constant(180))(); // Default 6 months
  TextColumn get calibrationCertificateNumber => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Nozzles - Individual fueling points
@DataClassName('NozzleEntity')
class Nozzles extends Table {
  TextColumn get nozzleId => text()();
  TextColumn get ownerId => text()();
  TextColumn get dispenserId => text()();
  TextColumn get name => text()(); // e.g. "Nozzle 1 (Petrol)"

  // Product Link
  TextColumn get fuelTypeId => text()(); // Links to Products/FuelType
  TextColumn get fuelTypeName => text()();

  // Readings
  RealColumn get openingReading => real().withDefault(const Constant(0.0))();
  RealColumn get closingReading => real().withDefault(const Constant(0.0))();

  // Current Shift Link
  TextColumn get linkedShiftId => text().nullable()();

  // Tank Link (Specific to this nozzle if different from dispenser)
  TextColumn get linkedTankId => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {nozzleId};
}

/// Tanks - Fuel storage
@DataClassName('TankEntity')
class Tanks extends Table {
  TextColumn get tankId => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()(); // e.g. "Tank 1 (MS)"
  TextColumn get fuelTypeId => text()();

  RealColumn get capacity => real()();
  RealColumn get currentStock => real()();
  RealColumn get deadStock => real().withDefault(const Constant(0.0))();

  // Density parameters for dip calculation
  RealColumn get density => real().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tankId};
}

// ============================================================================
// ACCOUNTING & LEDGER (CORE FINANCIALS)
// ============================================================================

/*
/// Ledger - The General Ledger for Double Entry Accounting
@DataClassName('LedgerEntity')
class Ledger extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  // Account Information
  TextColumn get accountName => text()(); // e.g. "Cash", "Sales", "HDFC Bank"
  TextColumn get accountGroup =>
      text()(); // ASSETS, LIABILITIES, EQUITY, REVENUE, EXPENSES
  TextColumn get parentAccountId => text().nullable()(); // Sub-accounts support

  // Balances
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance =>
      real().withDefault(const Constant(0.0))(); // Denormalized for speed
  TextColumn get balanceType =>
      text().withDefault(const Constant('DR'))(); // DR or CR

  BoolColumn get isSystemAccount => boolean().withDefault(
      const Constant(false))(); // Cannot delete system (Cash, Sales)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Journal Entries - Individual transactions affecting the ledger
@DataClassName('JournalEntryEntity')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get transactionDate => text()(); // ISO Date string (YYYY-MM-DD)
  TextColumn get description => text()();
  TextColumn get referenceId =>
      text().nullable()(); // billId, shiftId, expenseId
  TextColumn get referenceType => text().nullable()(); // BILL, SHIFT, EXPENSE

  // Entry Details (JSON List: [{accountId, dr, cr}])
  TextColumn get entryItemsJson => text()();

  RealColumn get totalAmount => real()();

  BoolColumn get isPosted => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
*/

/// Purchase Items - Line items for purchases
@TableIndex(name: 'idx_pi_purchase_id', columns: {#purchaseId})
@TableIndex(name: 'idx_pi_product_id', columns: {#productId})
@DataClassName('PurchaseItemEntity')
class PurchaseItems extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get purchaseId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get costPrice => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();

  // Pharmacy / Batch Info
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stock Movements - Immutable ledger of all inventory changes
/// "The Golden Rule Table"
@DataClassName('StockMovementEntity')
class StockMovements extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get productId => text()();

  // IN (Purchase, Return, etc.) or OUT (Sale, Damage, etc.)
  TextColumn get type => text()(); // 'IN', 'OUT'

  // Reason for movement
  TextColumn get reason => text()();

  // The quantity changed (Always positive)
  RealColumn get quantity => real()();

  // Snapshot of stock BEFORE this movement (for audit)
  RealColumn get stockBefore => real().withDefault(const Constant(0.0))();

  // Snapshot of stock AFTER this movement (for audit)
  RealColumn get stockAfter => real().withDefault(const Constant(0.0))();

  // Reference ID (Bill ID, Purchase ID, etc.)
  TextColumn get referenceId => text().nullable()();

  // User given description/remarks
  TextColumn get description => text().nullable()();

  // Batch/Warehouse info
  // PHARMACY COMPLIANCE: Valid batchId required for Pharmacy stock moves
  TextColumn get batchId => text().nullable()();
  TextColumn get batchNumber =>
      text().nullable()(); // Denormalized for easy read
  TextColumn get warehouseId => text().nullable()();

  // Audit info
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy =>
      text().nullable()(); // 'ADMIN', 'VENDOR', 'SYSTEM'

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Product Batches - The Heart of Pharmacy Compliance
/// Tracks specific lots of products with expiry dates.
/// Mandatory for Pharmacy business type.
@TableIndex(name: 'idx_batch_product', columns: {#productId})
@TableIndex(name: 'idx_batch_expiry', columns: {#expiryDate})
@TableIndex(name: 'idx_batch_number', columns: {#batchNumber})
@DataClassName('ProductBatchEntity')
class ProductBatches extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text()();
  TextColumn get userId => text()(); // Owner ID
  TextColumn get batchNumber => text()();

  // Mandatory for Pharmacy, Optional for others
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get manufacturingDate => dateTime().nullable()();

  // Batch-specific pricing (optional overrides)
  RealColumn get mrp => real().withDefault(const Constant(0.0))();
  RealColumn get purchaseRate => real().withDefault(const Constant(0.0))();
  RealColumn get sellingRate => real().withDefault(const Constant(0.0))();

  // Stock Accounting
  RealColumn get openingQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get stockQuantity =>
      real().withDefault(const Constant(0.0))(); // Available

  // Status: ACTIVE, EXPIRED, BLOCKED
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  // Sync & Audit
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {productId, batchNumber}, // Unique batch number per product
  ];
}

/// Lock Override Logs - Verifiable Audit Trail for Admin Actions
/// Records every time a restriction (Period Lock, Price Lock) is bypassed.
@DataClassName('LockOverrideLogEntity')
class LockOverrideLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // Owner ID
  TextColumn get entityType => text()(); // BILL, STOCK, LEDGER
  TextColumn get entityId => text()();
  TextColumn get reason => text()();

  // Audit Payload
  TextColumn get originalValuesJson => text()(); // Snapshot before change
  TextColumn get modifiedValuesJson => text()(); // Snapshot after change

  TextColumn get approvedByUserId =>
      text()(); // Who authorized this (Supervisor)
  DateTimeColumn get approvedAt => dateTime()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// CUSTOMER DASHBOARD & RECONSTRUCTED TABLES
// ============================================================================

/// Customer-Vendor Connections
@DataClassName('CustomerConnectionEntity')
class CustomerConnections extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get vendorId => text()();
  TextColumn get vendorName => text()();
  TextColumn get vendorPhone => text().nullable()();
  TextColumn get vendorBusinessName => text().nullable()();
  TextColumn get vendorAddress => text().nullable()();
  TextColumn get customerRefId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  RealColumn get totalBilled => real().withDefault(const Constant(0.0))();
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();
  RealColumn get outstandingBalance =>
      real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastInvoiceDate => dateTime().nullable()();
  DateTimeColumn get lastPaymentDate => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer Item Requests (Pre-Orders)
/// Offline-first architecture: Created locally -> Synced to Firebase
@DataClassName('CustomerItemRequestEntity')
class CustomerItemRequests extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get vendorId => text()();
  TextColumn get status => text().withDefault(
    const Constant('pending'),
  )(); // pending, approved, rejected, billed
  TextColumn get itemsJson =>
      text()(); // List of products with qty, status, notes
  TextColumn get note => text().nullable()();

  // Sync Status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// CUSTOMER-SHOP QR LINKING SYSTEM (Multi-Tenant Isolation)
// ============================================================================

/// CustomerProfiles - Shop-Scoped Customer Profiles (CRITICAL for multi-tenant isolation)
/// Each customer gets a unique profile per shop they link to.
/// Bills MUST reference customerProfileId, NOT customerId directly.
@TableIndex(name: 'idx_cp_shop_id', columns: {#shopId})
@TableIndex(name: 'idx_cp_customer_id', columns: {#customerId})
@TableIndex(name: 'idx_cp_qr_hash', columns: {#qrHash})
@DataClassName('CustomerProfileEntity')
class CustomerProfiles extends Table {
  /// Unique profile ID (UUID)
  TextColumn get id => text()();

  /// Shop/Vendor tenant boundary (owner UID)
  TextColumn get shopId => text()();

  /// Global customer identity (customer's authUid)
  TextColumn get customerId => text()();

  /// Unique QR identifier hash for this profile (SHA256 of shopId + customerId + salt)
  TextColumn get qrHash => text()();

  /// Shop-specific display name (optional override)
  TextColumn get displayName => text().nullable()();

  /// Customer's phone (denormalized for shop's use)
  TextColumn get phone => text().nullable()();

  /// Customer's email (denormalized for shop's use)
  TextColumn get email => text().nullable()();

  /// Profile status: ACTIVE, BLOCKED, REVOKED
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  /// Reason for blocking (if blocked)
  TextColumn get blockReason => text().nullable()();

  /// Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Sync status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {shopId, customerId}, // One profile per customer per shop
    {qrHash}, // QR hash must be globally unique
  ];
}

/// ShopLinks - Customer ↔ Shop Associations
/// Tracks which shops a customer has linked to.
/// Used by customer app to display "My Linked Shops" dashboard.
@TableIndex(name: 'idx_sl_customer_id', columns: {#customerId})
@TableIndex(name: 'idx_sl_shop_id', columns: {#shopId})
@DataClassName('ShopLinkEntity')
class ShopLinks extends Table {
  /// Unique link ID (UUID)
  TextColumn get id => text()();

  /// Global customer authUid
  TextColumn get customerId => text()();

  /// Shop/Vendor ID (owner UID)
  TextColumn get shopId => text()();

  /// Link to shop-scoped profile
  TextColumn get customerProfileId => text()();

  /// Shop name (denormalized for customer dashboard)
  TextColumn get shopName => text()();

  /// Business type for UI adaptation (grocery, petrol_pump, medical, etc.)
  TextColumn get businessType => text().nullable()();

  /// Shop phone (denormalized)
  TextColumn get shopPhone => text().nullable()();

  /// Link status: ACTIVE, PENDING, BLOCKED, UNLINKED
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  /// Total amount billed to customer at this shop
  RealColumn get totalBilled => real().withDefault(const Constant(0.0))();

  /// Total amount paid by customer at this shop
  RealColumn get totalPaid => real().withDefault(const Constant(0.0))();

  /// Outstanding balance at this shop
  RealColumn get outstandingBalance =>
      real().withDefault(const Constant(0.0))();

  /// Timestamps
  DateTimeColumn get linkedAt => dateTime()();
  DateTimeColumn get unlinkedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Sync status
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {customerId, shopId}, // One link per customer per shop
  ];
}

/// Customer Ledger
@DataClassName('CustomerLedgerEntity')
class CustomerLedger extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get vendorId => text()();
  TextColumn get entryType => text()(); // DEBIT, CREDIT
  RealColumn get amount => real()();
  RealColumn get runningBalance => real()();
  TextColumn get referenceType => text().nullable()(); // INVOICE, PAYMENT
  TextColumn get referenceId => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get entryDate => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer Notifications
@DataClassName('CustomerNotificationEntity')
class CustomerNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get vendorId => text().nullable()();
  TextColumn get notificationType => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get dataJson => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get actionType => text().nullable()();
  TextColumn get actionId => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// -------------------------------------------------------------
// RESTORED / RECONSTRUCTED MISSING TABLES (Approximate Schemas)
// -------------------------------------------------------------

@DataClassName('UdharPersonEntity')
class UdharPeople extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UdharTransactionEntity')
class UdharTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get personId => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // GAVE, GOT
  TextColumn get reason => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ShopEntity')
class Shops extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shopName => text().nullable()(); // Alias for display name
  TextColumn get ownerId => text()();
  TextColumn get ownerName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get invoiceTerms => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get signaturePath => text().nullable()();
  BoolColumn get showTaxOnInvoice =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isGstRegistered =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowNegativeStock =>
      boolean().withDefault(const Constant(false))();
  IntColumn get invoiceLanguage => integer().withDefault(const Constant(0))();

  TextColumn get businessType => text().nullable()();
  TextColumn get appLanguage => text().nullable()();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReceiptEntity')
class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get billId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get paymentMode => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isAdvancePayment =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReturnInwardEntity')
class ReturnInwards extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get billId => text().nullable()();
  TextColumn get billNumber => text().nullable()();
  TextColumn get creditNoteNumber => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get totalReturnAmount => real().withDefault(const Constant(0.0))();
  TextColumn get reason => text().nullable()();
  TextColumn get itemsJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProformaEntity')
class Proformas extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get proformaNumber => text().nullable()();
  TextColumn get itemsJson => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get validUntil => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  TextColumn get terms => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BookingEntity')
class Bookings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get bookingNumber => text().nullable()();
  TextColumn get itemsJson => text().nullable()();
  RealColumn get amount => real()();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get advanceAmount => real().withDefault(const Constant(0.0))();
  RealColumn get balanceAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get deliveryDate => dateTime().nullable()();
  TextColumn get deliveryAddress => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get convertedBillId =>
      text().nullable()(); // NEW: Links to Bill when converted
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DispatchEntity')
class Dispatches extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get billId => text().nullable()();
  TextColumn get billNumber => text().nullable()();
  TextColumn get dispatchNumber => text().nullable()();
  TextColumn get itemsJson => text().nullable()();
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get driverName => text().nullable()();
  TextColumn get driverPhone => text().nullable()();
  TextColumn get deliveryAddress => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserEntity')
class Users extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('OWNER'))();
  BoolColumn get hasSeenLoginOnboarding =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get loginOnboardingSeenAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// GST Tables
@DataClassName('GstSettingsEntity')
class GstSettings extends Table {
  TextColumn get id => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get stateCode => text().nullable()();
  TextColumn get legalName => text().nullable()();
  TextColumn get tradeName => text().nullable()();
  TextColumn get filingFrequency => text().nullable()();
  BoolColumn get isComposite => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompositionScheme =>
      boolean().withDefault(const Constant(false))();
  RealColumn get compositionRate => real().withDefault(const Constant(1.0))();
  BoolColumn get isEInvoiceEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get registrationDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GstInvoiceDetailEntity')
class GstInvoiceDetails extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get invoiceType => text().nullable()();
  TextColumn get supplyType => text().nullable()();
  TextColumn get placeOfSupply => text().nullable()();
  RealColumn get taxableAmount => real()();
  RealColumn get taxableValue => real().withDefault(const Constant(0.0))();
  RealColumn get cgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get cgstAmount => real().withDefault(const Constant(0.0))();
  RealColumn get sgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get sgstAmount => real().withDefault(const Constant(0.0))();
  RealColumn get igstRate => real().withDefault(const Constant(0.0))();
  RealColumn get igstAmount => real().withDefault(const Constant(0.0))();
  RealColumn get cessAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalGst => real()();
  TextColumn get hsnSummaryJson => text().nullable()();
  BoolColumn get isReverseCharge =>
      boolean().withDefault(const Constant(false))();
  TextColumn get eInvoiceIrn => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HsnMasterEntity')
class HsnMaster extends Table {
  TextColumn get code => text()();
  TextColumn get hsnCode => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get rate => real()();
  RealColumn get cgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get sgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get igstRate => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {code};
}

// Accounting Tables
@DataClassName('JournalEntryEntity')
class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  // Business/shop scope (nullable for pre-v41 rows; backfilled by the service
  // layer). When set, accounting reports filter by it so a user owning
  // multiple businesses does not see cross-business aggregates.
  TextColumn get businessId => text().nullable()();
  TextColumn get voucherNumber => text().nullable()();
  TextColumn get voucherType => text().nullable()();
  DateTimeColumn get entryDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get narration => text().nullable()();
  TextColumn get sourceType => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get entriesJson => text().nullable()();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  RealColumn get totalDebit => real().withDefault(const Constant(0.0))();
  RealColumn get totalCredit => real().withDefault(const Constant(0.0))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountingPeriodEntity')
class AccountingPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  // Business/shop scope (nullable for pre-v41 rows; backfilled by the service
  // layer). See [JournalEntries.businessId].
  TextColumn get businessId => text().nullable()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lockedAt => dateTime().nullable()();
  TextColumn get lockedByUserId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LedgerAccountEntity')
class LedgerAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  // Business/shop scope (nullable for pre-v41 rows; backfilled by the service
  // layer). See [JournalEntries.businessId].
  TextColumn get businessId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get accountGroup => text().nullable()();
  TextColumn get accountType => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get openingIsDebit =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get parentId => text().nullable()();
  TextColumn get linkedEntityType => text().nullable()();
  TextColumn get linkedEntityId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Reminder Tables
@DataClassName('ReminderSettingsEntity')
class ReminderSettings extends Table {
  TextColumn get id => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReminderLogEntity')
class ReminderLogs extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get sentAt => dateTime()();
  TextColumn get type => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PeriodLockEntity')
class PeriodLocks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get lockDate => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EInvoiceEntity')
class EInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get billId => text()();
  TextColumn get irn => text().nullable()();
  TextColumn get ackNumber => text().nullable()();
  DateTimeColumn get ackDate => dateTime().nullable()();
  TextColumn get qrCode => text().nullable()();
  TextColumn get signedInvoice => text().nullable()();
  TextColumn get signedQrCode => text().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get cancelReason => text().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EWayBillEntity')
class EWayBills extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get billId => text()();
  TextColumn get ewbNumber => text().nullable()();
  DateTimeColumn get ewbDate => dateTime().nullable()();
  DateTimeColumn get validUntil => dateTime().nullable()();
  TextColumn get fromPlace => text().nullable()();
  TextColumn get toPlace => text().nullable()();
  RealColumn get distanceKm => real().withDefault(const Constant(0.0))();
  TextColumn get fromPincode => text().nullable()();
  TextColumn get toPincode => text().nullable()();
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get transporterId => text().nullable()();
  TextColumn get transporterName => text().nullable()();
  TextColumn get status => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MarketingCampaignEntity')
class MarketingCampaigns extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // SMS, WHATSAPP
  TextColumn get targetSegment => text().nullable()();
  TextColumn get message => text().nullable()();
  TextColumn get templateId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get customFilterJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  IntColumn get totalRecipients => integer().withDefault(const Constant(0))();
  IntColumn get sentCount => integer().withDefault(const Constant(0))();
  IntColumn get failedCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CampaignLogEntity')
class CampaignLogs extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text()();
  TextColumn get customerId => text()();
  TextColumn get channel => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get messageSent => text().nullable()();
  TextColumn get status => text()(); // SENT, FAILED
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  DateTimeColumn get sentAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageTemplateEntity')
class MessageTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get type => text()();
  TextColumn get category => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get language => text().nullable()();
  BoolColumn get isSystemTemplate =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StaffMemberEntity')
class StaffMembers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get role => text()();
  TextColumn get pumpId =>
      text().nullable()(); // NEW: Link to specific pump station
  RealColumn get salary => real().withDefault(const Constant(0.0))();
  RealColumn get baseSalary => real().withDefault(const Constant(0.0))();
  TextColumn get salaryType => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get leftAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StaffAttendanceEntity')
class StaffAttendance extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get staffId => text()(); // References StaffMembers
  DateTimeColumn get date => dateTime()(); // YYYY-MM-DD normalized
  TextColumn get status => text()(); // PRESENT, ABSENT, HALF_DAY, LEAVE
  TextColumn get method => text().withDefault(
    const Constant('MANUAL'),
  )(); // NEW: MANUAL, PIN, BIOMETRIC
  DateTimeColumn get checkIn => dateTime().nullable()();
  DateTimeColumn get checkOut => dateTime().nullable()();
  DateTimeColumn get checkInTime => dateTime().nullable()();
  DateTimeColumn get checkOutTime => dateTime().nullable()();
  RealColumn get hoursWorked => real().withDefault(const Constant(0.0))();
  TextColumn get leaveType => text().nullable()();
  TextColumn get markedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  // Ensure one record per staff per day
  @override
  List<Set<Column>>? get uniqueKeys => [
    {staffId, date},
  ];
}

/// Salary Records - Monthly payroll records
@DataClassName('SalaryRecordEntity')
class SalaryRecords extends Table {
  TextColumn get id => text()();
  TextColumn get staffId => text()(); // References StaffMembers
  TextColumn get userId => text()(); // Owner's user ID

  // Pay period
  IntColumn get month => integer()(); // 1-12
  IntColumn get year => integer()();

  // Attendance summary
  IntColumn get totalDays => integer()();
  IntColumn get presentDays => integer()();
  IntColumn get absentDays => integer()();
  IntColumn get halfDays => integer().withDefault(const Constant(0))();
  IntColumn get leaveDays => integer().withDefault(const Constant(0))();
  RealColumn get totalHoursWorked => real().withDefault(const Constant(0.0))();
  RealColumn get overtimeHours => real().withDefault(const Constant(0.0))();

  // Earnings
  RealColumn get baseSalary => real()();
  RealColumn get overtimePay => real().withDefault(const Constant(0.0))();
  RealColumn get bonuses => real().withDefault(const Constant(0.0))();
  RealColumn get incentives => real().withDefault(const Constant(0.0))();
  RealColumn get allowances => real().withDefault(const Constant(0.0))();
  RealColumn get grossSalary => real()();

  // Deductions
  RealColumn get advances => real().withDefault(const Constant(0.0))();
  RealColumn get loans => real().withDefault(const Constant(0.0))();
  RealColumn get latePenalty => real().withDefault(const Constant(0.0))();
  RealColumn get otherDeductions => real().withDefault(const Constant(0.0))();
  RealColumn get totalDeductions => real().withDefault(const Constant(0.0))();

  // Final amount
  RealColumn get netSalary => real()();

  // Payment details
  TextColumn get status =>
      text().withDefault(const Constant('PENDING'))(); // PENDING, PAID, PARTIAL
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get paymentMode => text().nullable()(); // CASH, BANK, UPI
  TextColumn get paymentReference => text().nullable()();

  // Notes
  TextColumn get notes => text().nullable()();
  TextColumn get calculationDetailsJson =>
      text().nullable()(); // Detailed breakdown

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // One salary record per staff per month
  @override
  List<Set<Column>>? get uniqueKeys => [
    {staffId, month, year},
  ];
}

/// Staff Nozzle Assignment - Operations
/// Tracks which staff operated which nozzle and when.
@DataClassName('StaffNozzleAssignmentEntity')
class StaffNozzleAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get shiftId => text()(); // Link to Shifts
  TextColumn get staffId => text()(); // Link to StaffMembers
  TextColumn get nozzleId => text()(); // Link to Nozzles

  DateTimeColumn get assignedAt => dateTime()();
  DateTimeColumn get revokedAt =>
      dateTime().nullable()(); // If reassigned mid-shift

  // Audit
  TextColumn get assignedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Staff Sales Summary - Settlement
/// Granular sales tracking per staff member per fuel type per shift
@DataClassName('StaffSalesSummaryEntity')
class StaffSalesDetails extends Table {
  TextColumn get id => text()();
  TextColumn get shiftId => text()();
  TextColumn get staffId => text()();
  TextColumn get fuelTypeId => text()();
  TextColumn get fuelTypeName => text().nullable()(); // Cached

  RealColumn get totalLitres => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();

  DateTimeColumn get calculatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {shiftId, staffId, fuelTypeId},
  ];
}

/// Staff Cash Settlement - Accountability
/// Tracks cash handed over by each staff member
@DataClassName('StaffCashSettlementEntity')
class StaffCashSettlements extends Table {
  TextColumn get id => text()();
  TextColumn get shiftId => text()();
  TextColumn get staffId => text()();

  RealColumn get expectedCash => real().withDefault(const Constant(0.0))();
  RealColumn get actualCash => real().withDefault(const Constant(0.0))();
  RealColumn get difference => real().withDefault(const Constant(0.0))();

  // Breakdown of digital payments collected by this staff (if any)
  TextColumn get digitalCollectionsJson => text().nullable()();

  TextColumn get status => text().withDefault(
    const Constant('PENDING'),
  )(); // PENDING, VERIFIED, DISPUTED
  TextColumn get verifiedBy => text().nullable()();
  DateTimeColumn get settledAt => dateTime()();

  // Notes
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {shiftId, staffId},
  ];
}

/// AI Customer Recommendation Signals
/// Tracks behavioral data for ranking customers
@DataClassName('CustomerBehaviorEntity')
class CustomerBehaviors extends Table {
  // Links to Customers.id
  TextColumn get customerId => text()();
  TextColumn get userId => text()();

  // Recency Signal
  DateTimeColumn get lastVisit => dateTime()();

  // Frequency Signal
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  IntColumn get overallPeriodDays => integer().withDefault(const Constant(0))();

  // Time Affinity Signals (Morning: 6-12, Afternoon: 12-17, Evening: 17-22)
  IntColumn get morningVisits => integer().withDefault(const Constant(0))();
  IntColumn get afternoonVisits => integer().withDefault(const Constant(0))();
  IntColumn get eveningVisits => integer().withDefault(const Constant(0))();

  // Monetary Signal
  RealColumn get totalSpend => real().withDefault(const Constant(0.0))();
  RealColumn get avgBillAmount => real().withDefault(const Constant(0.0))();

  // Cached Rank Score (for instant sorting)
  RealColumn get lastScore => real().withDefault(const Constant(0.0))();
  DateTimeColumn get scoreUpdatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {customerId};
}

/// Credit Network (Udhar Circle)
@DataClassName('CreditProfileEntity')
class CreditProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Privacy-preserved identity (SHA-256 of normalized phone)
  TextColumn get customerPhoneHash => text().unique()();

  // Trust Score (0.0 - 100.0)
  RealColumn get trustScore => real().withDefault(const Constant(100.0))();

  // Risk indicators
  IntColumn get totalDefaults => integer().withDefault(const Constant(0))();

  // Cache validity
  DateTimeColumn get lastUpdated => dateTime()();
}

// ============================================================================
// RESTAURANT / HOTEL TABLES
// ============================================================================
// These tables are ONLY used when businessType == RESTAURANT || HOTEL
// ============================================================================

/// Food Categories - Menu organization
@DataClassName('FoodCategoryEntity')
class FoodCategories extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get name => text()(); // Starters, Main Course, Desserts, Beverages
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Food Menu Items - Restaurant/Hotel menu items
@DataClassName('FoodMenuItemEntity')
class FoodMenuItems extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isPopular => boolean().withDefault(const Constant(false))();
  IntColumn get preparationTimeMinutes =>
      integer().nullable()(); // Estimated prep time
  IntColumn get popularityCount =>
      integer().withDefault(const Constant(0))(); // Order count
  BoolColumn get isVegetarian => boolean().withDefault(const Constant(false))();
  BoolColumn get isVegan => boolean().withDefault(const Constant(false))();
  BoolColumn get isSpicy => boolean().withDefault(const Constant(false))();
  TextColumn get allergensJson =>
      text().nullable()(); // JSON array of allergens
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Restaurant Tables - Physical tables in the restaurant
@DataClassName('RestaurantTableEntity')
class RestaurantTables extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get tableNumber => text()(); // "1", "2", "A1", etc.
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(const Constant('AVAILABLE'))();
  // Status: AVAILABLE, OCCUPIED, RESERVED, CLEANING
  TextColumn get section =>
      text().nullable()(); // Indoor, Outdoor, Private, etc.
  TextColumn get qrCodeId => text().nullable()(); // Link to RestaurantQrCodes
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {vendorId, tableNumber},
  ];
}

/// Restaurant QR Codes - QR codes for restaurant/tables
@DataClassName('RestaurantQrCodeEntity')
class RestaurantQrCodes extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get tableId =>
      text().nullable()(); // NULL for general restaurant QR
  TextColumn get qrType => text()(); // RESTAURANT, TABLE
  TextColumn get qrData => text()(); // Encoded JSON data
  TextColumn get qrImagePath =>
      text().nullable()(); // Local path to generated QR image
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Food Orders - Customer food orders
@DataClassName('FoodOrderEntity')
class FoodOrders extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get customerId => text()();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get tableId => text().nullable()(); // NULL for takeaway
  TextColumn get tableNumber => text().nullable()();
  TextColumn get orderType => text()(); // DINE_IN, TAKEAWAY
  TextColumn get orderStatus => text().withDefault(const Constant('PENDING'))();
  // Status: PENDING, ACCEPTED, COOKING, READY, SERVED, COMPLETED, CANCELLED
  TextColumn get itemsJson => text()(); // JSON array of order items
  IntColumn get itemCount => integer()();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  RealColumn get serviceCharge => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get grandTotal => real()();
  TextColumn get specialInstructions => text().nullable()();
  IntColumn get estimatedPrepTime =>
      integer().nullable()(); // Total prep time in minutes
  DateTimeColumn get orderTime => dateTime()();
  DateTimeColumn get acceptedAt => dateTime().nullable()();
  DateTimeColumn get cookingStartedAt => dateTime().nullable()();
  DateTimeColumn get readyAt => dateTime().nullable()();
  DateTimeColumn get servedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  BoolColumn get billRequested =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get billRequestedAt => dateTime().nullable()();
  TextColumn get billId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  // Customer review
  IntColumn get reviewRating => integer().nullable()();
  TextColumn get reviewText => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Food Order Items - Individual items in a food order
@DataClassName('FoodOrderItemEntity')
class FoodOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get menuItemId => text()();
  TextColumn get itemName => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get totalPrice => real()();
  TextColumn get specialInstructions => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  // Status: PENDING, COOKING, READY
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Restaurant Bills - Bills for food orders
@DataClassName('RestaurantBillEntity')
class RestaurantBills extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get orderId => text()();
  TextColumn get customerId => text()();
  TextColumn get tableNumber => text().nullable()();
  TextColumn get billNumber => text()(); // Sequential: BILL-001
  RealColumn get subtotal => real()();
  RealColumn get cgst => real().withDefault(const Constant(0))();
  RealColumn get sgst => real().withDefault(const Constant(0))();
  RealColumn get serviceCharge => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get grandTotal => real()();
  TextColumn get taxBreakdownJson =>
      text().nullable()(); // Detailed tax breakdown
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('PENDING'))();
  // Status: PENDING, GENERATED, PAID, CANCELLED
  TextColumn get paymentMode => text().nullable()(); // CASH, CARD, UPI
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {orderId}, // One bill per order
  ];
}

// ============================================================================
// INVOICE COUNTERS - Atomic Invoice Number Generation
// ============================================================================

/// Invoice Counters - Tracks sequential invoice numbers per vendor per financial year
/// Prevents invoice number collisions by providing atomic increment
@DataClassName('InvoiceCounterEntity')
class InvoiceCounters extends Table {
  // Composite key: userId + financialYear (e.g., "2025-26")
  TextColumn get userId => text()();

  // Financial year in format "YYYY-YY" (e.g., "2025-26")
  TextColumn get financialYear => text()();

  // Prefix for invoice numbers (e.g., "INV", "BILL", custom prefix)
  TextColumn get prefix => text().withDefault(const Constant('INV'))();

  // Current counter value (last used number)
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();

  // Padding for invoice number (e.g., 6 means 000001)
  IntColumn get numberPadding => integer().withDefault(const Constant(6))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, financialYear};
}

// ============================================================================
// MOBILE / COMPUTER SHOP TABLES
// ============================================================================
// Service/Repair Job Cards, IMEI/Serial Tracking, Product Variants
// ============================================================================

/// IMEI/Serial Numbers - Lifecycle tracking for electronics
/// Tracks each unique device from purchase to sale with warranty info
@DataClassName('IMEISerialEntity')
class IMEISerials extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get productId => text()(); // Link to Products

  // Identification
  TextColumn get imeiOrSerial => text()(); // The actual IMEI or Serial number
  TextColumn get type =>
      text().withDefault(const Constant('IMEI'))(); // IMEI, SERIAL

  // Status lifecycle: IN_STOCK -> SOLD, or IN_STOCK -> RETURNED -> IN_STOCK
  TextColumn get status => text().withDefault(const Constant('IN_STOCK'))();
  // Status values: IN_STOCK, SOLD, RETURNED, DAMAGED, IN_SERVICE

  // Purchase info
  TextColumn get purchaseOrderId =>
      text().nullable()(); // Link to PurchaseOrders
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  TextColumn get supplierName => text().nullable()();

  // Sale info
  TextColumn get billId => text().nullable()(); // Link to Bills when sold
  TextColumn get customerId => text().nullable()(); // Link to Customers
  RealColumn get soldPrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get soldDate => dateTime().nullable()();

  // Warranty
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  DateTimeColumn get warrantyStartDate => dateTime().nullable()();
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();
  BoolColumn get isUnderWarranty =>
      boolean().withDefault(const Constant(false))();

  // Device details (denormalized for quick lookup)
  TextColumn get productName => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get storage => text().nullable()(); // e.g., "256GB"
  TextColumn get ram => text().nullable()(); // e.g., "8GB"

  // Notes
  TextColumn get notes => text().nullable()();

  // Second-hand intake fields (Phase 6, v51 migration)
  // Condition: 'excellent', 'good', 'fair', 'poor'
  TextColumn get condition => text().nullable()();
  // Grade: 'A', 'B', 'C', 'D'
  TextColumn get grade => text().nullable()();
  // Valuation in integer Paise (range 1..99999999999, enforced at app layer)
  IntColumn get valuationPaise => integer().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Ensure IMEI/Serial is unique per user
  @override
  List<Set<Column>>? get uniqueKeys => [
    {userId, imeiOrSerial},
  ];
}

/// Service Jobs - Repair/Service job cards for electronics
/// Complete lifecycle from device receipt to delivery
@DataClassName('ServiceJobEntity')
class ServiceJobs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get jobNumber => text()(); // Sequential: SRV-001

  // Customer info
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get customerEmail => text().nullable()();
  TextColumn get customerAddress => text().nullable()();

  // Device info
  TextColumn get deviceType =>
      text()(); // MOBILE, LAPTOP, DESKTOP, TABLET, OTHER
  TextColumn get brand => text()();
  TextColumn get model => text()();
  TextColumn get imeiOrSerial => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get accessories =>
      text().nullable()(); // JSON: ["charger", "back cover"]
  TextColumn get deviceConditionNotes => text().nullable()();
  TextColumn get devicePhotosJson =>
      text().nullable()(); // JSON array of photo paths

  // Problem description
  TextColumn get problemDescription => text()();
  TextColumn get symptomsJson =>
      text().nullable()(); // JSON: ["No power", "Screen crack"]

  // Warranty check
  BoolColumn get isUnderWarranty =>
      boolean().withDefault(const Constant(false))();
  TextColumn get originalBillId =>
      text().nullable()(); // Link to original sale bill
  TextColumn get imeiSerialId =>
      text().nullable()(); // Link to IMEISerials for warranty lookup

  // Service workflow status
  // RECEIVED -> DIAGNOSED -> WAITING_APPROVAL -> APPROVED -> WAITING_PARTS -> IN_PROGRESS -> COMPLETED -> READY -> DELIVERED
  // Or: RECEIVED -> DIAGNOSED -> CANCELLED
  TextColumn get status => text().withDefault(const Constant('RECEIVED'))();

  // Assignment
  TextColumn get assignedTechnicianId =>
      text().nullable()(); // Link to StaffMembers
  TextColumn get assignedTechnicianName => text().nullable()();

  // Diagnosis
  TextColumn get diagnosis => text().nullable()();
  TextColumn get diagnosedAt => text().nullable()();

  // Cost estimation
  RealColumn get estimatedLaborCost =>
      real().withDefault(const Constant(0.0))();
  RealColumn get estimatedPartsCost =>
      real().withDefault(const Constant(0.0))();
  RealColumn get estimatedTotal => real().withDefault(const Constant(0.0))();
  BoolColumn get customerApproved =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get approvedAt => dateTime().nullable()();

  // Actual costs
  RealColumn get actualLaborCost => real().withDefault(const Constant(0.0))();
  RealColumn get actualPartsCost => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();

  // Work done
  TextColumn get workDone => text().nullable()();
  TextColumn get partsUsedJson => text()
      .nullable()(); // JSON: [{"name": "Screen", "qty": 1, "price": 5000}]

  // Payment
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('PENDING'))(); // PENDING, PARTIAL, PAID
  RealColumn get advanceReceived => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMode => text().nullable()(); // CASH, UPI, CARD
  TextColumn get billId =>
      text().nullable()(); // Link to Bills when service is billed

  // Timeline
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get expectedDelivery => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancellationReason => text().nullable()();

  // Customer communication
  BoolColumn get smsNotificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lastNotificationSent => text().nullable()();
  DateTimeColumn get lastNotificationAt => dateTime().nullable()();

  // Priority
  TextColumn get priority => text().withDefault(
    const Constant('NORMAL'),
  )(); // LOW, NORMAL, HIGH, URGENT

  // Internal notes
  TextColumn get internalNotes => text().nullable()();

  // Delivery
  TextColumn get deliverySignature => text().nullable()(); // Base64 signature
  TextColumn get deliveredToName => text().nullable()();
  TextColumn get deliveryNotes => text().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Unique job number per user
  @override
  List<Set<Column>>? get uniqueKeys => [
    {userId, jobNumber},
  ];
}

/// Service Job Parts - Parts used in a service job
@DataClassName('ServiceJobPartEntity')
class ServiceJobParts extends Table {
  TextColumn get id => text()();
  TextColumn get serviceJobId => text()(); // Link to ServiceJobs
  TextColumn get productId =>
      text().nullable()(); // Link to Products (if from inventory)
  TextColumn get partName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get unitCost => real()();
  RealColumn get totalCost => real()();
  BoolColumn get isFromInventory =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Service Job Status History - Audit trail for job status changes
@DataClassName('ServiceJobStatusEntity')
class ServiceJobStatusHistory extends Table {
  TextColumn get id => text()();
  TextColumn get serviceJobId => text()();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  TextColumn get changedByUserId => text().nullable()();
  TextColumn get changedByName => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Product Variants - Handle RAM/Storage/Color variations
@DataClassName('ProductVariantEntity')
class ProductVariants extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()(); // Parent product
  TextColumn get userId => text()();

  // Variant identification
  TextColumn get variantName => text()(); // e.g., "256GB Space Black"
  TextColumn get sku => text().nullable()(); // Unique SKU for variant
  TextColumn get barcode => text().nullable()();

  // Attributes as structured JSON
  // e.g., {"ram": "8GB", "storage": "256GB", "color": "Space Black"}
  TextColumn get attributesJson => text()();

  // Pricing
  RealColumn get additionalCost =>
      real().withDefault(const Constant(0.0))(); // Cost difference from base
  RealColumn get additionalPrice =>
      real().withDefault(const Constant(0.0))(); // Price difference from base
  RealColumn get sellingPrice =>
      real().nullable()(); // Override base price if set

  // Stock (for variants without IMEI tracking)
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();

  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {userId, sku},
  ];
}

/// Exchanges - Handle device exchange with price difference
@DataClassName('ExchangeEntity')
class Exchanges extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get exchangeNumber => text()(); // EXC-001

  // Customer
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();

  // Old device (being exchanged)
  TextColumn get oldDeviceType => text()();
  TextColumn get oldBrand => text()();
  TextColumn get oldModel => text()();
  TextColumn get oldImeiSerial => text().nullable()();
  TextColumn get oldCondition =>
      text()(); // EXCELLENT, GOOD, FAIR, POOR, DAMAGED
  TextColumn get oldConditionNotes => text().nullable()();
  RealColumn get oldDeviceValue => real()(); // Evaluated value

  // New device (being purchased)
  TextColumn get newProductId => text().nullable()(); // Link to Products
  TextColumn get newImeiSerialId => text().nullable()(); // Link to IMEISerials
  TextColumn get newProductName => text()();
  TextColumn get newImeiSerial => text().nullable()();
  RealColumn get newDevicePrice => real()();

  // Calculation
  RealColumn get exchangeValue => real()(); // Old device value credited
  RealColumn get priceDifference => real()(); // newPrice - exchangeValue
  RealColumn get additionalDiscount =>
      real().withDefault(const Constant(0.0))();
  RealColumn get amountToPay => real()(); // Final amount customer pays

  // Payment
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('PENDING'))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMode => text().nullable()();
  TextColumn get billId => text().nullable()(); // Link to Bills

  // Status
  TextColumn get status => text().withDefault(
    const Constant('DRAFT'),
  )(); // DRAFT, COMPLETED, CANCELLED

  // Timestamps
  DateTimeColumn get exchangeDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SECURITY & FRAUD PREVENTION TABLES
// ============================================================================

/// Security Settings - Owner-configurable security controls per business
@DataClassName('SecuritySettingsEntity')
class SecuritySettingsTable extends Table {
  /// Business ID (1:1 mapping)
  TextColumn get businessId => text()();

  /// SHA-256 hashed owner PIN
  TextColumn get ownerPinHash => text()();

  /// Maximum discount % allowed without PIN (default: 10)
  IntColumn get maxDiscountPercent =>
      integer().withDefault(const Constant(10))();

  /// Bill edit window in minutes (0 = no edits after save)
  IntColumn get billEditWindowMinutes =>
      integer().withDefault(const Constant(0))();

  /// Cash tolerance limit for daily closing (default: ₹100)
  RealColumn get cashToleranceLimit =>
      real().withDefault(const Constant(100.0))();

  /// Transaction limit requiring approval (default: ₹10,000)
  RealColumn get approvalLimitAmount =>
      real().withDefault(const Constant(10000.0))();

  /// Require PIN for refunds
  BoolColumn get requirePinForRefunds =>
      boolean().withDefault(const Constant(true))();

  /// Require PIN for stock adjustments
  BoolColumn get requirePinForStockAdjustment =>
      boolean().withDefault(const Constant(true))();

  /// Require PIN for bill deletion
  BoolColumn get requirePinForBillDelete =>
      boolean().withDefault(const Constant(true))();

  /// Require PIN for period unlock
  BoolColumn get requirePinForPeriodUnlock =>
      boolean().withDefault(const Constant(true))();

  /// Hour after which late-night alerts trigger (null = disabled)
  IntColumn get lateNightHour => integer().nullable()();

  /// Max bill edits per user per day before alert
  IntColumn get maxBillEditsPerDay =>
      integer().withDefault(const Constant(3))();

  /// Session expiry in hours
  IntColumn get sessionExpiryHours =>
      integer().withDefault(const Constant(24))();

  /// Enforce one device per user
  BoolColumn get enforceOneDevicePerUser =>
      boolean().withDefault(const Constant(false))();

  /// Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {businessId};
}

/// Cash Closings - Daily cash reconciliation records
@TableIndex(name: 'idx_cash_closing_business', columns: {#businessId})
@TableIndex(name: 'idx_cash_closing_date', columns: {#closingDate})
@DataClassName('CashClosingEntity')
class CashClosings extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();

  /// Date of closing (midnight timestamp)
  DateTimeColumn get closingDate => dateTime()();

  /// Expected cash based on transactions
  RealColumn get expectedCash => real()();

  /// Actual cash counted
  RealColumn get actualCash => real()();

  /// Variance (expected - actual)
  RealColumn get variance => real()();

  /// User who performed closing
  TextColumn get closedBy => text()();

  /// Status: MATCHED, MISMATCH_PENDING, MISMATCH_APPROVED
  TextColumn get status => text().withDefault(const Constant('MATCHED'))();

  /// Approver (if mismatch was approved)
  TextColumn get approvedBy => text().nullable()();

  /// Approval reason
  TextColumn get approvalReason => text().nullable()();

  /// Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get approvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fraud Alerts - Automated fraud detection alerts
@TableIndex(name: 'idx_fraud_alert_business', columns: {#businessId})
@TableIndex(name: 'idx_fraud_alert_user', columns: {#userId})
@TableIndex(name: 'idx_fraud_alert_created', columns: {#createdAt})
@DataClassName('FraudAlertEntity')
class FraudAlerts extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();

  /// Type of alert (HIGH_DISCOUNT, BILL_EDIT, CASH_MISMATCH, etc.)
  TextColumn get alertType => text()();

  /// Severity: LOW, MEDIUM, HIGH, CRITICAL
  TextColumn get severity => text()();

  /// User who triggered the alert
  TextColumn get userId => text()();

  /// Human-readable description
  TextColumn get description => text()();

  /// Reference ID (billId, productId, etc.)
  TextColumn get referenceId => text().nullable()();

  /// Additional metadata as JSON
  TextColumn get metadataJson => text().nullable()();

  /// Acknowledgement status
  BoolColumn get isAcknowledged =>
      boolean().withDefault(const Constant(false))();

  /// Who acknowledged
  TextColumn get acknowledgedBy => text().nullable()();

  /// Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User Sessions - Track active sessions for device control
@TableIndex(name: 'idx_session_user', columns: {#userId})
@TableIndex(name: 'idx_session_business', columns: {#businessId})
@TableIndex(name: 'idx_session_device', columns: {#deviceId})
@DataClassName('UserSessionEntity')
class UserSessions extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get businessId => text()();

  /// Device identifier
  TextColumn get deviceId => text()();

  /// Human-readable device name
  TextColumn get deviceName => text().nullable()();

  /// Device platform (android, ios, web)
  TextColumn get platform => text().nullable()();

  /// Session timestamps
  DateTimeColumn get loginAt => dateTime()();
  DateTimeColumn get lastActiveAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  /// Is session currently active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Login location (optional)
  TextColumn get loginLocation => text().nullable()();

  /// Force logout flag (set by owner)
  BoolColumn get forceLogout => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Prescriptions - Doctor prescriptions linked to customers and bills

// ============================================================================
// HIS MODULE TABLES (Phase 2)
// ============================================================================

/// Patients - Medical Profile (Linked to Customer)
/// Can exist independently or linked to a CustomerEntity for billing
@TableIndex(name: 'idx_patients_user_id', columns: {#userId})
@TableIndex(name: 'idx_patients_phone', columns: {#phone})
@TableIndex(name: 'idx_patients_customer_id', columns: {#customerId})
@DataClassName('PatientEntity')
class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // Clinic Owner ID

  // Link to existing billing customer (Optional)
  TextColumn get customerId => text().nullable()();

  // Basic Info
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  IntColumn get age => integer().nullable()();
  TextColumn get gender => text().nullable()(); // Male, Female, Other
  TextColumn get bloodGroup => text().nullable()();

  // Medical History
  TextColumn get allergies => text().nullable()(); // Comma separated or JSON
  TextColumn get chronicConditions => text().nullable()();
  TextColumn get emergencyContact => text().nullable()(); // Name | Phone

  // New Fields for Doctor/Clinic Module
  TextColumn get address => text().nullable()();
  TextColumn get qrToken =>
      text().unique().nullable()(); // Secure token for linking

  // Metrics
  TextColumn get lastVisitId => text().nullable()();
  DateTimeColumn get lastVisitDate => dateTime().nullable()();

  // Sync
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  // Device ID that last modified this record
  TextColumn get deviceId => text().nullable()();

  // PHI consent flag (clinic task 5.3 — Req 2.11).
  // Nullable: NULL = unconsented (legacy rows preserved), true = consented.
  // Added via explicit v47 migration — no data loss for existing rows.
  BoolColumn get consent => boolean().nullable()();

  // Human-readable UHID / Medical Record Number (clinic task 6.4 — Req 2.19).
  // Format: "MRN-{YYYYMMDD}-{4-char-hex}" — short, clinic-friendly, unique
  // within the tenant's patient set. Nullable: legacy rows get NULL until
  // backfilled. Added via explicit v49 migration — no data loss.
  TextColumn get uhid => text().nullable()();

  // Date of Birth (clinic task 9.1 — Req 2.30).
  // Stored as a DateTime so the app can compute current age dynamically.
  // Nullable: legacy rows preserved with NULL via explicit v50 migration.
  DateTimeColumn get dateOfBirth => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PHI ACCESS LOG (clinic task 5.3 — Req 2.11)
// ============================================================================
//
// Append-only audit table recording every read/write/update of patient or visit
// data. Enables compliance auditing and access tracking for PHI fields
// (allergies, chronicConditions, diagnosis, private notes).
//
// AT-REST PROTECTION STRATEGY (app-layer scope):
// ─────────────────────────────────────────────────────────────────────────────
// Sensitive columns in the patients table (allergies, chronicConditions) and
// visits table (diagnosis, notes) contain PHI that SHOULD be encrypted at rest
// in a future pass (column-level encryption via a key derived from the owner's
// auth credentials, stored in platform keychain). The CURRENT pass provides:
//   1. Access logging (this table) — every PHI read/write is recorded with
//      actor, timestamp, and description for compliance auditing.
//   2. Consent capture — the `consent` flag on patients ensures informed
//      consent is explicitly recorded before PHI is stored.
//   3. Role gating — clinical-role enforcement restricts who can view
//      diagnosis/private notes (task 5.2).
// Column-level encryption is flagged as a Phase 9 enhancement. The access log
// combined with consent capture and role gating provides the governance layer
// this pass requires.
// ─────────────────────────────────────────────────────────────────────────────

/// PHI Access Log — append-only audit trail for patient/visit data access.
@TableIndex(name: 'idx_patient_access_log_patient_id', columns: {#patientId})
@TableIndex(name: 'idx_patient_access_log_user_id', columns: {#userId})
@TableIndex(name: 'idx_patient_access_log_timestamp', columns: {#timestamp})
@DataClassName('PatientAccessLogEntry')
class PatientAccessLogs extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The patient whose data was accessed.
  TextColumn get patientId => text()();

  /// The user (owner/staff) who performed the access.
  TextColumn get userId => text()();

  /// Type of access: 'read', 'write', or 'update'.
  TextColumn get accessType => text()();

  /// When the access occurred.
  DateTimeColumn get timestamp => dateTime()();

  /// Optional human-readable description of the access event
  /// (e.g., "viewed visit", "created patient", "updated allergies").
  TextColumn get description => text().nullable()();
}

/// Clinical Visits - Encounters
@TableIndex(name: 'idx_visits_user_id', columns: {#userId})
@TableIndex(name: 'idx_visits_patient_id', columns: {#patientId})
@TableIndex(name: 'idx_visits_date', columns: {#visitDate})
@DataClassName('VisitEntity')
class Visits extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()(); // If multiple doctors

  DateTimeColumn get visitDate => dateTime()();

  // Clinical Data
  TextColumn get chiefComplaint => text().nullable()();
  TextColumn get symptoms => text().nullable()(); // JSON or List
  TextColumn get diagnosis => text().nullable()();
  TextColumn get notes => text().nullable()(); // Private notes

  // Vitals (JSON: BP, Pulse, Temp, Weight, SpO2)
  TextColumn get vitalsJson => text().nullable()();

  // Links
  TextColumn get prescriptionId => text().nullable()();
  TextColumn get billId => text().nullable()();

  // Status: WAITING, IN_PROGRESS, COMPLETED, CANCELLED
  TextColumn get status => text().withDefault(const Constant('WAITING'))();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Prescriptions - Rx
@TableIndex(name: 'idx_prescriptions_user_id', columns: {#userId})
@TableIndex(name: 'idx_prescriptions_visit_id', columns: {#visitId})
@TableIndex(name: 'idx_prescriptions_patient_id', columns: {#patientId})
@DataClassName('PrescriptionEntity')
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get visitId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text().nullable()();

  DateTimeColumn get date => dateTime()();

  // Medicines (JSON List of MedicineItem)
  // { name, dosage, frequency, duration, instructions }
  TextColumn get medicinesJson => text()();

  // Advice / Instructions
  TextColumn get advice => text().nullable()();
  // Lab Tests Requested
  TextColumn get labTestsJson => text().nullable()();

  // Follow up
  DateTimeColumn get nextVisitDate => dateTime().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get deviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SHORTCUT PANEL TABLES (Added in v4)
// ============================================================================

/// System shortcut definitions - Available shortcuts catalog
@DataClassName('ShortcutDefinitionEntity')
class ShortcutDefinitions extends Table {
  // Unique shortcut identifier (e.g., 'NEW_BILL', 'LOW_STOCK')
  TextColumn get id => text()();

  // Display label
  TextColumn get label => text()();

  // Icon name (Material Icon name as string)
  TextColumn get iconName => text()();

  // Navigation route or action ID
  TextColumn get route => text().nullable()();

  // NAVIGATE, FUNCTION, MODAL
  TextColumn get actionType => text()();

  // Category: DAILY_WORK, INVENTORY, REPORTS, ACCOUNTING, SETTINGS
  TextColumn get category => text()();

  // Which business types can see this shortcut (JSON array or '*' for all)
  TextColumn get allowedBusinessTypes =>
      text().withDefault(const Constant('*'))();

  // Required permission to show this shortcut
  TextColumn get requiredPermission => text().nullable()();

  // Whether this shortcut shows a real-time badge
  BoolColumn get hasBadge => boolean().withDefault(const Constant(false))();

  // Default keyboard binding (e.g., 'Ctrl+N')
  TextColumn get defaultKeyBinding => text().nullable()();

  // Sort order for default display
  IntColumn get defaultSortOrder =>
      integer().withDefault(const Constant(100))();

  // Is this a default shortcut that appears for new users
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// User shortcut configurations - Per-user customizations
@TableIndex(name: 'idx_user_shortcuts_user', columns: {#userId})
@TableIndex(name: 'idx_user_shortcuts_order', columns: {#userId, #orderIndex})
@DataClassName('UserShortcutEntity')
class UserShortcuts extends Table {
  // Unique configuration ID (UUID)
  TextColumn get id => text()();

  // User/Vendor ID
  TextColumn get userId => text()();

  // Reference to ShortcutDefinitions.id
  TextColumn get shortcutId => text()();

  // Display order (drag-drop reorder updates this)
  IntColumn get orderIndex => integer()();

  // Optional group name (e.g., 'Daily Work', 'Inventory')
  TextColumn get groupName => text().nullable()();

  // Is this shortcut enabled for this user
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  // Is this a priority/highlighted shortcut
  BoolColumn get isPriority => boolean().withDefault(const Constant(false))();

  // Custom keyboard binding (overrides default)
  TextColumn get keyboardBinding => text().nullable()();

  // Last time this shortcut was used (for analytics/sorting)
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  // Usage count
  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  // Device ID (optional, for per-device configs)
  TextColumn get deviceId => text().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {
      userId,
      shortcutId,
      deviceId,
    }, // One config per shortcut per user per device
  ];
}

// ============================================================================
// MANUFACTURING MODULE
// ============================================================================

/// Bill Of Materials (BOM) - Recipe for manufacturing
/// Links a Finished Good (Parent) to its Raw Materials (Children)
@DataClassName('BillOfMaterialEntity')
class BillOfMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  // The Finished Good (Must be a Product)
  TextColumn get finishedGoodId => text()();

  // The Raw Material (Must be a Product)
  TextColumn get rawMaterialId => text()();

  // Quantity of Raw Material needed for 1 Unit of Finished Good
  RealColumn get quantityRequired => real()();

  // Unit of measurement for the requirement (e.g. "kg", "liters")
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  // Cost allocation (optional) - % of cost to attribute
  RealColumn get costAllocationPercent =>
      real().withDefault(const Constant(100.0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {finishedGoodId, rawMaterialId},
  ];
}

/// Production Entries - Journal for Manufacturing
/// Records the conversion of Raw Materials -> Finished Goods
@DataClassName('ProductionEntryEntity')
class ProductionEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  // Reference to the BOM used (Optional, as recipes change)
  TextColumn get finishedGoodId => text()();

  // Quantity Produced
  RealColumn get quantityProduced => real()();

  // Date of Production
  DateTimeColumn get productionDate => dateTime()();

  // Notes / Batch No generated
  TextColumn get batchNumber => text().nullable()();
  TextColumn get notes => text().nullable()();

  // Costing
  RealColumn get totalCost =>
      real().withDefault(const Constant(0.0))(); // Sum of RM cost + Labor
  RealColumn get laborCost => real().withDefault(const Constant(0.0))();

  // Raw Material Consumption Snapshot (JSON)
  TextColumn get rawMaterialsJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Subscriptions - Recurring Billing Engine
@DataClassName('SubscriptionEntity')
class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text()();
  TextColumn get planName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get billingCycle =>
      text().withDefault(const Constant('MONTHLY'))();
  IntColumn get customCycleDays => integer().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get autoCancelDate => dateTime().nullable()();
  DateTimeColumn get lastBillingDate => dateTime().nullable()();
  DateTimeColumn get nextBillingDate => dateTime()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  BoolColumn get autoGenerateInvoice =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get autoSendEmail =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get autoSendWhatsapp =>
      boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  TextColumn get cancellationReason => text().nullable()();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// SubscriptionItems - Sub-items for a recurring subscription
@DataClassName('SubscriptionItemEntity')
class SubscriptionItems extends Table {
  TextColumn get id => text()();
  TextColumn get subscriptionId => text().references(Subscriptions, #id)();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get unitPrice => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// DOCTOR / CLINIC MODULE TABLES (NEW)
// ============================================================================

/// Doctor Profiles - Vendor specific details for medical practice
@DataClassName('DoctorProfileEntity')
class DoctorProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text().unique()(); // Link to standard Vendor/User
  TextColumn get specialization => text().nullable()(); // e.g. Cardiologist
  TextColumn get licenseNumber => text().nullable()();
  TextColumn get qualification => text().nullable()(); // e.g. MBBS, MD
  TextColumn get clinicName => text().nullable()();
  RealColumn get consultationFee => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Patient-Doctor Links - Many-to-Many access control
@DataClassName('PatientDoctorLinkEntity')
class PatientDoctorLinks extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id)();
  TextColumn get doctorId => text().references(DoctorProfiles, #id)();
  DateTimeColumn get linkedAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('ACTIVE'))(); // ACTIVE, ARCHIVED

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {patientId, doctorId},
  ];
}

/// Appointments - Scheduling
@DataClassName('AppointmentEntity')
class Appointments extends Table {
  TextColumn get id => text()();
  TextColumn get doctorId => text()(); // FK manually managed for flexibility
  TextColumn get patientId => text()(); // FK manually managed
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get status => text().withDefault(
    const Constant('SCHEDULED'),
  )(); // SCHEDULED, COMPLETED, CANCELLED
  TextColumn get purpose => text().nullable()(); // Consultation, Follow-up
  TextColumn get notes => text().nullable()();

  /// Slot duration in minutes. Nullable for existing rows (preserved by
  /// migration v48). Application defaults to 15 when reading NULL.
  IntColumn get slotDurationMinutes => integer().nullable()();

  // Audit
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Start of new Prescriptions logic if we want normalized items
/// Note: Prescriptions table already exists above.
/// We add PrescriptionItems for detailed tracking.

/// Prescription Items - Medicine details
@DataClassName('PrescriptionItemEntity')
class PrescriptionItems extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text().references(Prescriptions, #id)();
  TextColumn get medicineName => text()();
  TextColumn get dosage => text().nullable()(); // e.g. 500mg
  TextColumn get frequency => text().nullable()(); // e.g. 1-0-1
  TextColumn get duration => text().nullable()(); // e.g. 5 days
  TextColumn get instructions => text().nullable()(); // e.g. After food

  @override
  Set<Column> get primaryKey => {id};
}

/// Medical Records - Generic clinical notes/observations (Alternative to Visits)
/// or can be used for file attachments primarily.
@DataClassName('MedicalRecordEntity')
class MedicalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  DateTimeColumn get visitDate => dateTime()();
  TextColumn get diagnosis => text().nullable()();
  TextColumn get symptoms => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get attachmentsJson => text().nullable()(); // URLs to files/images

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lab Reports
@DataClassName('LabReportEntity')
class LabReports extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get testName => text()();
  TextColumn get reportUrl => text().nullable()();
  DateTimeColumn get uploadedAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('PENDING'))(); // PENDING, UPLOADED

  @override
  Set<Column> get primaryKey => {id};
}

/// Medical Templates - Shortcuts for Diagnosis, Rx, Advice
@DataClassName('MedicalTemplateEntity')
class MedicalTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // Doctor ID
  TextColumn get type => text()(); // 'DIAGNOSIS', 'PRESCRIPTION', 'ADVICE'
  TextColumn get title => text()(); // Name of template
  TextColumn get content => text()(); // JSON or Text content

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================
// VEGETABLE BROKER MODULE (Mandi)
// ============================================

/// Farmers - The suppliers in the broker model
@DataClassName('FarmerEntity')
class Farmers extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // The Broker (App User)
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get village => text().nullable()();
  TextColumn get bankAccountDetails => text().nullable()(); // JSON or Text

  // Ledger Summary (integer paise — migrated from double in v43)
  IntColumn get totalSales => integer().withDefault(const Constant(0))();
  IntColumn get totalCommissionDeducted =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalExpensesDeducted =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalPaid => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance =>
      integer().withDefault(const Constant(0))(); // Payable to Farmer

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync-tracking columns (Phase 1, Requirement 4.2)
  TextColumn get syncState =>
      text().withDefault(const Constant('unsynced'))(); // synced | unsynced
  DateTimeColumn get lastModifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Commission Ledger - Tracks every broker sale
@DataClassName('CommissionLedgerEntity')
class CommissionLedger extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()(); // The Broker
  TextColumn get billId => text()(); // Link to the Sale Bill (Buyer Side)
  TextColumn get farmerId => text()();

  // Transaction Details (integer paise — migrated from double in v43)
  DateTimeColumn get date => dateTime()();
  IntColumn get saleAmount => integer()();

  // Per-lot commission: 'flat' or 'percentage' (Phase 2, Requirement 5.1–5.3).
  // - 'flat': commissionAmount holds the captured flat paise, commissionRate is null.
  // - 'percentage': commissionRate holds the captured % (≥2 decimal places),
  //   commissionAmount holds the resulting paise.
  TextColumn get commissionType =>
      text().withDefault(const Constant('flat'))(); // 'flat' | 'percentage'
  RealColumn get commissionRate =>
      real().nullable()(); // Percentage rate (only for type='percentage')
  IntColumn get commissionAmount => integer()(); // Flat paise or result paise

  IntColumn get laborCharges => integer().withDefault(const Constant(0))();
  IntColumn get hamaliCharges => integer().withDefault(const Constant(0))();
  IntColumn get weighingCharges => integer().withDefault(const Constant(0))();
  IntColumn get marketFee => integer().withDefault(const Constant(0))();
  IntColumn get otherExpenses => integer().withDefault(const Constant(0))();

  // Net Payable Calculation (integer paise)
  // Net = SaleAmount - Commission - Labor - Hamali - Weighing - MarketFee - Other
  IntColumn get netPayableToFarmer => integer()();

  // Sync-tracking columns (Phase 1, Requirement 4.2)
  TextColumn get syncState =>
      text().withDefault(const Constant('unsynced'))(); // synced | unsynced
  DateTimeColumn get lastModifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vegetable Lots - The core arrival/auction unit in the Mandi model.
/// IDs follow the RID pattern `{tenantId}-{timestamp_ms}-{uuid_v4_short}` and
/// are assigned by app code at insert time (no DB-side default).
/// Money fields use integer paise (NOT double); weights are physical
/// quantities stored as `real()` like every other quantity in this schema.
@DataClassName('VegetableLotEntity')
class VegetableLots extends Table {
  TextColumn get id => text()(); // RID, assigned at insert time by app code
  TextColumn get userId => text()(); // The Broker (App User) — tenant scoping
  TextColumn get owningFarmerId => text()(); // Owning farmer (-> Farmers.id)

  // Weights are quantities, NOT money -> real() (matches BillItems.quantity etc.)
  RealColumn get grossWeight => real()();
  RealColumn get tareWeight => real()();
  RealColumn get netWeight => real()(); // = gross - tare (derived in task 2.5)

  // Money field -> integer paise per convention (NOT double).
  IntColumn get rate => integer()();

  TextColumn get grade => text()();
  TextColumn get vehicleNumber => text().nullable()();
  DateTimeColumn get arrivalDate => dateTime()();

  // Lifecycle status: exactly one of ARRIVED, AUCTIONED, SOLD, SETTLED.
  // Enforced at the DB level via a CHECK constraint; defaults to ARRIVED.
  TextColumn get status => text().withDefault(const Constant('ARRIVED'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // Constrain status to exactly the four allowed lifecycle values.
  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('ARRIVED', 'AUCTIONED', 'SOLD', 'SETTLED'))",
  ];
}

/// Mandi Settlements (Patti) - A periodic settlement aggregating a farmer's
/// deductions over a date range. IDs follow the RID pattern
/// `{tenantId}-{timestamp_ms}-{uuid_v4_short}` and are assigned by app code at
/// insert time (no DB-side default). Money fields use integer paise (NOT
/// double). Settlement generation logic is owned by Phase 3 task 15 — this
/// table only defines persistence.
@DataClassName('MandiSettlementEntity')
class MandiSettlements extends Table {
  TextColumn get id => text()(); // RID, assigned at insert time by app code
  TextColumn get userId => text()(); // The Broker (App User) — tenant scoping
  TextColumn get farmerId => text()(); // The settled farmer (-> Farmers.id)

  // Inclusive settlement period.
  DateTimeColumn get periodStartDate => dateTime()();
  DateTimeColumn get periodEndDate => dateTime()();

  // Money field -> integer paise per convention (NOT double).
  IntColumn get aggregatedDeductions => integer()();

  // List of included lot RIDs, stored as a JSON-encoded array of strings —
  // matches the schema's list-of-ids convention (cf. Shifts.assignedEmployeeIds).
  TextColumn get includedLotIds => text()();

  // Payment status: exactly one of PENDING, PARTIAL, PAID.
  // Enforced at the DB level via a CHECK constraint; defaults to PENDING.
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('PENDING'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // Constrain paymentStatus to exactly the three allowed values.
  // NOTE: the CHECK references the SQL column name `payment_status` (Drift
  // snake_cases the `paymentStatus` Dart getter). Referencing the Dart field
  // name here makes SQLite reject the CREATE TABLE ("no such column:
  // paymentStatus"), which blocks in-memory schema creation for every
  // DB-backed test. Incidental one-token correction made under clinic task 4.4
  // to unblock migration testing (outside the clinic vertical).
  @override
  List<String> get customConstraints => [
    "CHECK (payment_status IN ('PENDING', 'PARTIAL', 'PAID'))",
  ];
}

/// Rate History - Per-vegetable, per-calendar-date min/max/avg rate snapshot
/// backing the Mandi Rate Board. IDs follow the RID pattern
/// `{tenantId}-{timestamp_ms}-{uuid_v4_short}` and are assigned by app code at
/// insert time (no DB-side default). Money fields use integer paise (NOT
/// double). Rate-board UI/aggregation logic is owned by Phase 3 task 16 — this
/// table only defines persistence.
@DataClassName('RateHistoryEntity')
class RateHistory extends Table {
  TextColumn get id => text()(); // RID, assigned at insert time by app code
  TextColumn get userId => text()(); // The Broker (App User) — tenant scoping
  TextColumn get vegetable => text()();

  // Calendar date the rates apply to.
  DateTimeColumn get rateDate => dateTime()();

  // Money fields -> integer paise per convention (NOT double).
  IntColumn get minRate => integer()();
  IntColumn get maxRate => integer()();
  IntColumn get avgRate => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // At most one record per vegetable per calendar date, scoped per-tenant.
  // Column names are the generated snake_case forms (userId -> user_id,
  // rateDate -> rate_date).
  @override
  List<String> get customConstraints => [
    'UNIQUE (user_id, vegetable, rate_date)',
  ];
}

/// Buyers - Mandi buyer/commission-agent entities with credit limits and
/// outstanding dues. IDs follow the RID pattern
/// `{tenantId}-{timestamp_ms}-{uuid_v4_short}` and are assigned by app code at
/// insert time (no DB-side default). Money fields use integer paise (NOT
/// double). Buyer management UI is owned by Phase 3 — this table only defines
/// persistence.
@DataClassName('BuyerEntity')
class Buyers extends Table {
  TextColumn get id => text()(); // RID, assigned at insert time by app code
  TextColumn get userId => text()(); // The Broker (App User) — tenant scoping
  TextColumn get name => text()();

  // Money fields -> integer paise per convention (NOT double).
  IntColumn get creditLimit => integer()();
  IntColumn get outstandingDues => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================
// ACCOUNTING & REPORTING
// ============================================

/// DayBook - Daily Transaction Summary (Offline-First)
@DataClassName('DayBookEntryEntity')
class DayBook extends Table {
  TextColumn get id => text()(); // businessId_dateKey
  TextColumn get businessId => text()();
  DateTimeColumn get date => dateTime()();

  // Cash Flow
  RealColumn get openingCashBalance =>
      real().withDefault(const Constant(0.0))();
  RealColumn get closingCashBalance =>
      real().withDefault(const Constant(0.0))();
  RealColumn get computedClosingBalance => real().nullable()();

  // Summaries
  RealColumn get totalSales => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashSales => real().withDefault(const Constant(0.0))();
  RealColumn get totalCreditSales => real().withDefault(const Constant(0.0))();

  RealColumn get totalPurchases => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashPurchases =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalCreditPurchases =>
      real().withDefault(const Constant(0.0))();

  RealColumn get totalExpenses => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashExpenses => real().withDefault(const Constant(0.0))();

  RealColumn get totalPaymentsReceived =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalPaymentsMade => real().withDefault(const Constant(0.0))();

  // Counts
  IntColumn get salesCount => integer().withDefault(const Constant(0))();
  IntColumn get purchasesCount => integer().withDefault(const Constant(0))();
  IntColumn get expensesCount => integer().withDefault(const Constant(0))();
  IntColumn get paymentsReceivedCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get paymentsMadeCount => integer().withDefault(const Constant(0))();

  // Reconciliation
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reconciledAt => dateTime().nullable()();
  TextColumn get reconciledBy => text().nullable()();
  TextColumn get reconciliationNotes => text().nullable()();
  RealColumn get reconciliationDifference => real().nullable()();

  // Timestamps
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get syncOperationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PETROL PUMP - ADDITIONAL TABLES
// ============================================================================

/// Cash Deposits - Track cash deposits to bank from daily collections
@TableIndex(name: 'idx_cash_deposit_owner', columns: {#ownerId})
@TableIndex(name: 'idx_cash_deposit_date', columns: {#depositDate})
@DataClassName('CashDepositEntity')
class CashDeposits extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  // Deposit Details
  DateTimeColumn get depositDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get bankAccountId => text().nullable()(); // Link to BankAccounts
  TextColumn get bankName => text().nullable()();
  TextColumn get depositSlipNumber => text().nullable()();

  // Source Info
  TextColumn get shiftId => text().nullable()(); // If from specific shift
  DateTimeColumn get collectionDate => dateTime()(); // Date cash was collected

  // Status: PENDING, DEPOSITED, VERIFIED
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  TextColumn get depositedBy => text().nullable()();
  TextColumn get verifiedBy => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();

  TextColumn get notes => text().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lube Stock - Lubricant inventory for petrol pumps
@TableIndex(name: 'idx_lube_stock_owner', columns: {#ownerId})
@DataClassName('LubeStockEntity')
class LubeStock extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  // Product Info
  TextColumn get name => text()(); // e.g. "Engine Oil 10W-40"
  TextColumn get brand => text().nullable()(); // e.g. "Castrol"
  TextColumn get category =>
      text().nullable()(); // ENGINE_OIL, GEAR_OIL, COOLANT, etc.
  TextColumn get packSize => text().nullable()(); // e.g. "1L", "5L"
  TextColumn get barcode => text().nullable()();

  // Stock
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get minStockLevel => real().withDefault(const Constant(5.0))();

  // Pricing
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real()();
  RealColumn get mrp => real().nullable()();

  // GST
  TextColumn get hsnCode => text().nullable()();
  RealColumn get gstRate =>
      real().withDefault(const Constant(18.0))(); // Default 18%

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Density Records - Track fuel density readings for dip calculation
@TableIndex(name: 'idx_density_record_tank', columns: {#tankId})
@TableIndex(name: 'idx_density_record_date', columns: {#recordDate})
@DataClassName('DensityRecordEntity')
class DensityRecords extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get tankId => text()();

  DateTimeColumn get recordDate => dateTime()();
  RealColumn get density => real()(); // kg/l
  RealColumn get temperature =>
      real().nullable()(); // Temperature at measurement

  // Dip Reading
  RealColumn get dipReading => real().nullable()(); // mm/cm
  RealColumn get calculatedVolume => real().nullable()(); // From dip chart

  TextColumn get recordedBy => text().nullable()();
  TextColumn get notes => text().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// ENTERPRISE LICENSING SYSTEM TABLES
// ============================================================================
// These tables power the licensing, device binding, and admin control system.
// Designed for enterprise-grade security with complete audit trails.
// ============================================================================

/// License Cache - Local storage for license validation (User App)
/// Stores encrypted license data for offline-first validation
@TableIndex(name: 'idx_license_cache_license_key', columns: {#licenseKey})
@DataClassName('LicenseCacheEntity')
class LicenseCache extends Table {
  TextColumn get id => text()();
  TextColumn get licenseKey => text().unique()();

  // Business binding
  TextColumn get businessType => text()(); // Must match app business type
  TextColumn get customerId => text().nullable()();

  // License configuration
  TextColumn get licenseType => text().withDefault(
    const Constant('standard'),
  )(); // trial, standard, pro, enterprise

  // Module access (JSON array of module codes)
  TextColumn get enabledModulesJson =>
      text().withDefault(const Constant('[]'))();

  // Validity
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime()();

  // Status: active, expired, suspended, blocked
  TextColumn get status => text().withDefault(const Constant('active'))();

  // Device binding
  TextColumn get deviceFingerprint => text()();
  TextColumn get deviceId =>
      text().nullable()(); // Server-side device record ID
  IntColumn get maxDevices => integer().withDefault(const Constant(1))();

  // Offline validation
  DateTimeColumn get lastValidatedAt => dateTime()();
  IntColumn get offlineGraceDays =>
      integer().withDefault(const Constant(7))(); // Days allowed offline

  // Encrypted validation token (for offline verification)
  TextColumn get validationToken => text()();
  TextColumn get tokenSignature => text()();

  // Server sync
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Admin Users - Admin panel authentication with RBAC
/// Super Admin, Support Admin, Sales Admin roles
@TableIndex(name: 'idx_admin_users_email', columns: {#email})
@TableIndex(name: 'idx_admin_users_role', columns: {#role})
@DataClassName('AdminUserEntity')
class AdminUsers extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get salt => text()();

  // Role: super_admin, support_admin, sales_admin
  TextColumn get role => text()();
  TextColumn get displayName => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  // Permissions (JSON array of permission strings)
  TextColumn get permissionsJson => text().withDefault(const Constant('[]'))();

  // Security
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get mfaEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get mfaSecret => text().nullable()(); // Encrypted TOTP secret

  // Login tracking
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  TextColumn get lastLoginIp => text().nullable()();
  IntColumn get failedAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();

  // Audit
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Licenses - Enterprise license key management
/// Bound to business type, customer, and devices
@TableIndex(name: 'idx_licenses_customer', columns: {#customerId})
@TableIndex(name: 'idx_licenses_business_type', columns: {#businessType})
@TableIndex(name: 'idx_licenses_status', columns: {#status})
@TableIndex(name: 'idx_licenses_expiry', columns: {#expiryDate})
@DataClassName('LicenseEntity')
class Licenses extends Table {
  TextColumn get id => text()();
  TextColumn get licenseKey => text().unique()();

  // Business binding - CRITICAL: Must match exactly
  TextColumn get businessType => text()();
  TextColumn get customerId => text().nullable()(); // FK to LicenseCustomers

  // License configuration
  TextColumn get licenseType => text().withDefault(
    const Constant('standard'),
  )(); // trial, standard, pro, enterprise
  IntColumn get maxDevices => integer().withDefault(const Constant(1))();

  // Module access (JSON array of enabled module codes)
  TextColumn get enabledModulesJson =>
      text().withDefault(const Constant('[]'))();

  // Validity
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime()();

  // Status: inactive, active, expired, suspended, blocked
  TextColumn get status => text().withDefault(const Constant('inactive'))();
  DateTimeColumn get activatedAt => dateTime().nullable()();
  DateTimeColumn get lastValidatedAt => dateTime().nullable()();

  // Platform: desktop, mobile, both
  TextColumn get platform => text().withDefault(const Constant('both'))();

  // Pricing tracking
  RealColumn get pricePaid => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  // Notes
  TextColumn get internalNotes => text().nullable()();

  // Security - Emergency blocking
  BoolColumn get isBlacklisted =>
      boolean().withDefault(const Constant(false))();
  TextColumn get blacklistReason => text().nullable()();
  DateTimeColumn get blacklistedAt => dateTime().nullable()();
  TextColumn get blacklistedBy => text().nullable()();

  // Audit
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// License Modules - Feature/module catalog with business type mapping
@DataClassName('LicenseModuleEntity')
class LicenseModules extends Table {
  TextColumn get id => text()();
  TextColumn get moduleCode =>
      text().unique()(); // e.g., 'inventory', 'billing'
  TextColumn get moduleName => text()(); // Display name
  TextColumn get description => text().nullable()();

  // Business type availability (JSON object: {"petrolPump": true, "pharmacy": false})
  TextColumn get businessTypesJson =>
      text().withDefault(const Constant('{}'))();

  // Features within module (JSON array of feature codes)
  TextColumn get featuresJson => text().withDefault(const Constant('[]'))();

  // Pricing tier: basic, standard, premium, enterprise
  TextColumn get tier => text().withDefault(const Constant('standard'))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bound Devices - Device fingerprint binding to licenses
/// Tracks all devices associated with each license
@TableIndex(name: 'idx_bound_devices_license', columns: {#licenseId})
@TableIndex(
  name: 'idx_bound_devices_fingerprint',
  columns: {#deviceFingerprint},
)
@DataClassName('BoundDeviceEntity')
class BoundDevices extends Table {
  TextColumn get id => text()();
  TextColumn get licenseId => text()();

  // Device identification
  TextColumn get deviceFingerprint => text()();
  TextColumn get deviceName => text().nullable()(); // User-friendly name

  // Device info
  TextColumn get platform => text()(); // windows, macos, linux, android, ios
  TextColumn get osVersion => text().nullable()();
  TextColumn get deviceModel => text().nullable()();
  TextColumn get appVersion => text().nullable()();

  // Status: active, inactive, blocked
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();

  // Binding info
  DateTimeColumn get boundAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  TextColumn get lastIp => text().nullable()();

  // Emergency access
  BoolColumn get emergencyAllowed =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get emergencyExpiresAt => dateTime().nullable()();
  TextColumn get emergencyGrantedBy => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
    {licenseId, deviceFingerprint}, // One entry per device per license
  ];
}

/// Activation Logs - Complete audit trail for license activations
/// Records every activation attempt, success or failure
@TableIndex(name: 'idx_activation_logs_license', columns: {#licenseId})
@TableIndex(name: 'idx_activation_logs_created', columns: {#createdAt})
@TableIndex(name: 'idx_activation_logs_status', columns: {#status})
@DataClassName('ActivationLogEntity')
class ActivationLogs extends Table {
  TextColumn get id => text()();
  TextColumn get licenseId => text()();
  TextColumn get deviceId => text().nullable()();

  // Action: activation, deactivation, validation, device_change, heartbeat
  TextColumn get action => text()();

  // Result: success, failed, blocked
  TextColumn get status => text()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  // Context - Store for historical reference
  TextColumn get licenseKey => text()();
  TextColumn get deviceFingerprint => text().nullable()();

  // Request info
  TextColumn get ipAddress => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  TextColumn get appVersion => text().nullable()();
  TextColumn get platform => text().nullable()();

  // Geo info (optional)
  TextColumn get geoCountry => text().nullable()();
  TextColumn get geoCity => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Admin Audit Logs - Complete audit trail for admin actions
/// Every admin action is logged for security and compliance
@TableIndex(name: 'idx_admin_audit_admin', columns: {#adminId})
@TableIndex(name: 'idx_admin_audit_action', columns: {#action})
@TableIndex(name: 'idx_admin_audit_created', columns: {#createdAt})
@DataClassName('AdminAuditLogEntity')
class AdminAuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get adminId => text()();

  // Action details
  TextColumn get action => text()(); // e.g., 'license_create', 'device_unbind'
  TextColumn get resourceType => text()(); // license, device, customer, admin
  TextColumn get resourceId => text().nullable()();

  // Change tracking (JSON)
  TextColumn get oldValueJson => text().nullable()();
  TextColumn get newValueJson => text().nullable()();

  // Context
  TextColumn get description => text().nullable()();
  TextColumn get ipAddress => text()();
  TextColumn get userAgent => text().nullable()();

  // Session
  TextColumn get sessionId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// License Customers - Business/customer profiles for licensing
/// Separate from app customers - these are license owners
@TableIndex(
  name: 'idx_license_customers_business_type',
  columns: {#businessType},
)
@TableIndex(name: 'idx_license_customers_phone', columns: {#ownerPhone})
@DataClassName('LicenseCustomerEntity')
class LicenseCustomers extends Table {
  TextColumn get id => text()();

  // Business info
  TextColumn get businessName => text()();
  TextColumn get businessType => text()();

  // Owner info
  TextColumn get ownerName => text()();
  TextColumn get ownerPhone => text()();
  TextColumn get ownerEmail => text().nullable()();

  // Address
  TextColumn get addressLine1 => text().nullable()();
  TextColumn get addressLine2 => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get country => text().withDefault(const Constant('India'))();

  // Tax info
  TextColumn get gstin => text().nullable()();
  TextColumn get pan => text().nullable()();

  // Status: active, suspended, churned
  TextColumn get status => text().withDefault(const Constant('active'))();

  // Subscription
  TextColumn get subscriptionTier =>
      text().withDefault(const Constant('standard'))();
  DateTimeColumn get renewalDate => dateTime().nullable()();

  // Support
  BoolColumn get prioritySupport =>
      boolean().withDefault(const Constant(false))();
  TextColumn get assignedSupportAdminId => text().nullable()();

  // Notes
  TextColumn get internalNotes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Business Type Configs - Configurable business type settings
/// Defines modules, limits, and pricing per business type
@DataClassName('BusinessTypeConfigEntity')
class BusinessTypeConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()(); // e.g., 'petrolPump', 'pharmacy'
  TextColumn get displayName => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()(); // Icon name/code
  TextColumn get color => text().nullable()(); // Primary color hex

  // Configuration (JSON arrays)
  TextColumn get defaultModulesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get availableModulesJson =>
      text().withDefault(const Constant('[]'))();

  // Limits
  IntColumn get maxDevicesAllowed => integer().withDefault(const Constant(2))();

  // Pricing
  RealColumn get basePriceMonthly => real().withDefault(const Constant(0.0))();
  RealColumn get basePriceYearly => real().withDefault(const Constant(0.0))();

  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// License Blacklist - Emergency blocking system
/// Block licenses, devices, or IPs for security
@TableIndex(name: 'idx_license_blacklist_license', columns: {#licenseId})
@TableIndex(
  name: 'idx_license_blacklist_fingerprint',
  columns: {#deviceFingerprint},
)
@TableIndex(name: 'idx_license_blacklist_ip', columns: {#ipAddress})
@DataClassName('LicenseBlacklistEntity')
class LicenseBlacklist extends Table {
  TextColumn get id => text()();

  // Target (one of these must be set)
  TextColumn get licenseId => text().nullable()();
  TextColumn get licenseKeyPattern => text().nullable()(); // Pattern match
  TextColumn get deviceFingerprint => text().nullable()();
  TextColumn get ipAddress => text().nullable()();
  TextColumn get ipRange => text().nullable()(); // CIDR range

  // Reason
  TextColumn get reason => text()();
  TextColumn get severity => text().withDefault(
    const Constant('high'),
  )(); // low, medium, high, critical

  // Validity
  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get validUntil => dateTime().nullable()(); // Null = permanent

  // Status
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Audit
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Warranty Claims - Mobile/Computer Shop Module
@TableIndex(name: 'idx_warranty_claims_user_id', columns: {#userId})
@TableIndex(name: 'idx_warranty_claims_customer_id', columns: {#customerId})
@DataClassName('WarrantyClaimEntity')
class WarrantyClaims extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get claimNumber => text()();

  // Original sale reference
  TextColumn get originalBillId => text()();
  TextColumn get originalInvoiceNumber => text().nullable()();
  TextColumn get originalSaleDate => text().nullable()();

  // Device info
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get imeiOrSerial => text()();
  TextColumn get color => text().nullable()();
  TextColumn get storage => text().nullable()();

  // Customer info
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get customerEmail => text().nullable()();

  // Claim details
  TextColumn get issueDescription => text()();
  TextColumn get symptomsJson => text().nullable()();
  TextColumn get issuePhotosJson => text().nullable()();

  // Warranty verification
  DateTimeColumn get warrantyStartDate => dateTime().nullable()();
  DateTimeColumn get warrantyEndDate => dateTime().nullable()();
  IntColumn get warrantyPeriodMonths => integer().nullable()();
  BoolColumn get isUnderWarranty => boolean().nullable()();
  TextColumn get warrantyVerificationNotes => text().nullable()();

  // Status tracking
  TextColumn get status => text()();
  DateTimeColumn get filedAt => dateTime()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get closedAt => dateTime().nullable()();

  // Assignment
  TextColumn get reviewedByUserId => text().nullable()();
  TextColumn get reviewedByName => text().nullable()();
  TextColumn get assignedTechnicianId => text().nullable()();
  TextColumn get assignedTechnicianName => text().nullable()();

  // Costing
  TextColumn get partsReplacedJson => text().nullable()();
  RealColumn get totalPartsCost => real().nullable()();
  RealColumn get laborCost => real().nullable()();
  RealColumn get totalClaimCost => real().nullable()();

  // Rejection
  TextColumn get rejectionReason => text().nullable()();
  TextColumn get rejectionNotes => text().nullable()();

  // Service job linkage
  TextColumn get linkedServiceJobId => text().nullable()();

  // Resolution
  TextColumn get resolutionNotes => text().nullable()();
  TextColumn get workDone => text().nullable()();

  // Financial tracking
  BoolColumn get isReimbursedBySupplier => boolean().nullable()();
  RealColumn get reimbursementAmount => real().nullable()();
  DateTimeColumn get reimbursedAt => dateTime().nullable()();
  TextColumn get reimbursementReference => text().nullable()();

  // Sync
  BoolColumn get isSynced => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// RestaurantInventoryItems - Raw materials and stock in restaurant module
@DataClassName('RestaurantInventoryItemEntity')
class RestaurantInventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  RealColumn get currentStock => real()();
  RealColumn get minStockAlert => real()();
  RealColumn get costPerUnit => real()();
  TextColumn get supplierName => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ItemRecipes - Link menu items to raw material inventory consumption
@DataClassName('ItemRecipeEntity')
class ItemRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get menuItemId => text()();
  TextColumn get inventoryItemId => text()();
  RealColumn get quantityPerUnit => real()();
  TextColumn get variationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// RestaurantKots - Kitchen Order Tickets for tables/orders
@DataClassName('RestaurantKotEntity')
class RestaurantKots extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get orderId => text().nullable()();
  TextColumn get tableId => text().nullable()();
  TextColumn get tableNumber => text().nullable()();
  IntColumn get kotNumber => integer()();
  TextColumn get itemsJson => text()();
  TextColumn get status => text()();
  TextColumn get staffId => text().nullable()();
  TextColumn get waiterId => text().nullable()();
  TextColumn get specialInstructions => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// RestaurantFloors - Sections / zones in a restaurant
@DataClassName('RestaurantFloorEntity')
class RestaurantFloors extends Table {
  TextColumn get id => text()();
  TextColumn get vendorId => text()();
  TextColumn get name => text()();
  TextColumn get floorType => text()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// StockReservations - Hold stock during checkout/billing
@DataClassName('StockReservationEntity')
class StockReservations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get billDraftId => text()();
  TextColumn get productId => text()();
  TextColumn get batchId => text().nullable()();
  RealColumn get quantity => real()();
  DateTimeColumn get reservedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get referenceBillId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// DunningRules - Configuration for automated payment reminders
@DataClassName('DunningRuleEntity')
class DunningRules extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  IntColumn get daysAfterDue => integer()();
  IntColumn get sortOrder => integer()();
  BoolColumn get sendWhatsapp => boolean().withDefault(const Constant(false))();
  BoolColumn get sendNotification =>
      boolean().withDefault(const Constant(false))();
  TextColumn get whatsappTemplate => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get autoEscalate => boolean().withDefault(const Constant(false))();
  TextColumn get escalateToStatus => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// DunningLogs - Audit trail for dunning events and actions taken
@DataClassName('DunningLogEntity')
class DunningLogs extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get dunningRuleId => text()();
  TextColumn get channel => text()(); // WHATSAPP, EMAIL, NOTIFICATION
  TextColumn get status => text()(); // SENT, FAILED, SKIPPED
  TextColumn get messagePreview => text().nullable()();
  TextColumn get failureReason => text().nullable()();
  RealColumn get billAmount => real()();
  RealColumn get amountDue => real()();
  IntColumn get daysOverdue => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// KvStore - Simple key-value store for generic settings/migration data
@DataClassName('KvStoreEntity')
class KvStore extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ============================================================================
// OFFLINE CLOUD-ENTITY TABLES (offline-license-activation, schemaVersion v39)
// ============================================================================
//
// Requirement 8.2 mandates at minimum one table per cloud entity. The entities
// users, products, categories?, customers, sales (Bills), sale_items
// (BillItems), payments, vendors, purchases (PurchaseOrders), purchase_items
// (PurchaseItems), inventory_movements (StockMovements) and sessions
// (UserSessions) are satisfied by reusing the EXISTING tables above.
//
// The following entities had no existing table and are added here, each
// carrying the universal System_Columns (Requirement 8.1) via
// `TableSystemColumns`: roles, permissions, categories, units, inventory,
// business_settings and tax_rates.

/// Roles - RBAC role definitions (cloud entity: roles)
@DataClassName('RoleEntity')
class Roles extends Table with TableSystemColumns {
  TextColumn get id => text()();

  /// Human-readable role name, e.g. owner, manager, cashier, viewer.
  TextColumn get name => text()();

  /// Optional description of the role's purpose.
  TextColumn get description => text().nullable()();

  /// Whether this role is a built-in default role that cannot be deleted.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Permissions - Per-role module action grants (cloud entity: permissions)
@DataClassName('PermissionEntity')
class Permissions extends Table with TableSystemColumns {
  TextColumn get id => text()();

  /// Role this permission belongs to.
  TextColumn get roleId => text()();

  /// Module / resource the permission applies to, e.g. billing, inventory.
  TextColumn get module => text()();

  /// Action permitted on the module, e.g. create, read, update, delete.
  TextColumn get action => text()();

  /// Whether the action is allowed (true) or explicitly denied (false).
  BoolColumn get allowed => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories - Product / item categories (cloud entity: categories)
@DataClassName('CategoryEntity')
class Categories extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();

  /// Optional parent category id for hierarchical categories.
  TextColumn get parentId => text().nullable()();

  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Units - Units of measure (cloud entity: units)
@DataClassName('UnitEntity')
class Units extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Full unit name, e.g. "Kilogram".
  TextColumn get name => text()();

  /// Short symbol, e.g. "kg", "pcs", "ltr".
  TextColumn get symbol => text().nullable()();

  /// Decimal precision allowed for quantities in this unit.
  IntColumn get decimalPlaces => integer().withDefault(const Constant(2))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inventory - Per-product stock-on-hand snapshot (cloud entity: inventory)
///
/// Distinct from StockMovements (the immutable movement ledger mapped to the
/// inventory_movements entity): this table holds the current quantity and
/// reorder configuration per product/location.
@DataClassName('InventoryEntity')
class Inventory extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get productId => text()();

  /// Optional warehouse / location identifier.
  TextColumn get warehouseId => text().nullable()();

  /// Current quantity on hand.
  RealColumn get quantity => real().withDefault(const Constant(0.0))();

  /// Quantity reserved against open orders / drafts.
  RealColumn get reservedQuantity => real().withDefault(const Constant(0.0))();

  /// Reorder threshold for low-stock alerts.
  RealColumn get reorderLevel => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Business Settings - Per-tenant business configuration
/// (cloud entity: business_settings)
@DataClassName('BusinessSettingEntity')
class BusinessSettings extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Setting key, e.g. "currency", "invoice_prefix".
  TextColumn get settingKey => text()();

  /// Setting value, stored as text (JSON-encoded for complex values).
  TextColumn get settingValue => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// One value per (user, key).
  @override
  List<Set<Column>>? get uniqueKeys => [
    {userId, settingKey},
  ];
}

/// Tax Rates - Configurable tax-rate master (cloud entity: tax_rates)
@DataClassName('TaxRateEntity')
class TaxRates extends Table with TableSystemColumns {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Display name, e.g. "GST 18%".
  TextColumn get name => text()();

  /// Total tax rate percentage, e.g. 18.0.
  RealColumn get rate => real().withDefault(const Constant(0.0))();

  /// Split components (for GST: CGST + SGST = rate; IGST = rate).
  RealColumn get cgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get sgstRate => real().withDefault(const Constant(0.0))();
  RealColumn get igstRate => real().withDefault(const Constant(0.0))();

  /// Optional HSN/SAC code this rate is associated with.
  TextColumn get hsnCode => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SCHOOL ERP — OFFLINE CACHE TABLES (Phase 5, Requirement 8.1, 8.6)
// ============================================================================
//
// Mirrors the offline caching pattern used by other verticals (Farmers,
// CommissionLedger, VegetableLots). Every row carries `tenantId` for tenant
// isolation — a cache read MUST filter by active Tenant_Id. Currency columns
// are integer Paise (NOT double). Identifiers follow the RID pattern
// `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
//
// Mini_Gate: 3 new additive tables (school_students_cache, school_fees_cache,
// school_attendance_cache). Consumers: SchoolErpSyncHandler,
// AcDashboardScreen/offline reads. Migration plan: additive — no existing data
// affected, safe defaults on all nullable columns, applied in schema v52.

/// School Students Cache — tenant-scoped local cache of student records.
@DataClassName('SchoolStudentCacheEntity')
class SchoolStudentsCache extends Table {
  /// RID: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
  TextColumn get id => text()();

  /// Owning tenant identifier (multi-tenant isolation). NOT nullable — every
  /// cache row MUST belong to a tenant; reads are filtered by active Tenant_Id.
  TextColumn get tenantId => text()();

  /// Student display name.
  TextColumn get name => text()();

  /// Class and section, e.g. "10-A".
  TextColumn get classSection => text().withDefault(const Constant(''))();

  /// Enrollment date (nullable for students imported without a date).
  DateTimeColumn get enrollmentDate => dateTime().nullable()();

  /// Total fees assigned — integer Paise (NOT double).
  IntColumn get totalFeesPaise => integer().withDefault(const Constant(0))();

  /// Total amount paid — integer Paise (NOT double).
  IntColumn get totalPaidPaise => integer().withDefault(const Constant(0))();

  /// Outstanding balance — integer Paise (NOT double).
  /// balancePaise = totalFeesPaise - totalPaidPaise (derived, stored for
  /// offline query performance).
  IntColumn get balancePaise => integer().withDefault(const Constant(0))();

  /// Student status: active, inactive, graduated, transferred.
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Monotonic sync version from server; used for conflict resolution.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// Timestamp of last modification (server or local).
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// School Fees Cache — tenant-scoped local cache of fee/invoice records.
@DataClassName('SchoolFeeCacheEntity')
class SchoolFeesCache extends Table {
  /// RID: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
  TextColumn get id => text()();

  /// Owning tenant identifier (multi-tenant isolation). NOT nullable — every
  /// cache row MUST belong to a tenant; reads are filtered by active Tenant_Id.
  TextColumn get tenantId => text()();

  /// Reference to the student (RID from SchoolStudentsCache).
  TextColumn get studentId => text()();

  /// Invoice identifier (RID or server-assigned id).
  TextColumn get invoiceId => text().withDefault(const Constant(''))();

  /// Total invoice amount — integer Paise (NOT double).
  IntColumn get amountPaise => integer().withDefault(const Constant(0))();

  /// Amount already paid — integer Paise (NOT double).
  IntColumn get paidAmountPaise => integer().withDefault(const Constant(0))();

  /// Outstanding balance — integer Paise (NOT double).
  /// balancePaise = amountPaise - paidAmountPaise (derived, stored for
  /// offline query performance).
  IntColumn get balancePaise => integer().withDefault(const Constant(0))();

  /// Fee due date (nullable if no explicit due date set).
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Fee status: pending, partial, paid, overdue, cancelled.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Monotonic sync version from server; used for conflict resolution.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// Timestamp of last modification (server or local).
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// School Attendance Cache — tenant-scoped local cache of attendance records.
@DataClassName('SchoolAttendanceCacheEntity')
class SchoolAttendanceCache extends Table {
  /// RID: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`
  TextColumn get id => text()();

  /// Owning tenant identifier (multi-tenant isolation). NOT nullable — every
  /// cache row MUST belong to a tenant; reads are filtered by active Tenant_Id.
  TextColumn get tenantId => text()();

  /// Reference to the student (RID from SchoolStudentsCache).
  TextColumn get studentId => text()();

  /// Attendance date.
  DateTimeColumn get date => dateTime()();

  /// Attendance status: present, absent, late.
  TextColumn get status => text().withDefault(const Constant('present'))();

  /// Who marked this attendance entry (user RID or name).
  TextColumn get markedBy => text().withDefault(const Constant(''))();

  /// Monotonic sync version from server; used for conflict resolution.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// Timestamp of last modification (server or local).
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // Constrain status to the three allowed attendance values.
  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('present', 'absent', 'late'))",
  ];
}

// ============================================================================
// WHOLESALE — TRANSPORT DETAILS (Phase 5, Task 11.2)
// ============================================================================
// New entity for wholesale transport/logistics data. Scoped to active Tenant_Id
// with an RID identifier. Persists vehicle number, LR number, and transporter
// name linked to a delivery challan. Schema_Gate: new table (implicitly approved
// since it does not modify any existing table shape).

/// Transport Details — per-dispatch/challan transport record for wholesale.
///
/// RID-based, tenant-scoped. Required fields: vehicleNumber, transporterName.
/// lrNumber is optional. linkedChallanId references the DeliveryChallans table.
@DataClassName('TransportDetailEntity')
class TransportDetailsTable extends Table {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  TextColumn get id => text()();

  /// Tenant scope — every query MUST filter by this column.
  TextColumn get tenantId => text()();

  /// Vehicle registration number (required, non-empty).
  TextColumn get vehicleNumber => text()();

  /// Lorry Receipt (LR) number (optional — may be empty string).
  TextColumn get lrNumber => text().withDefault(const Constant(''))();

  /// Transporter / transport company name (required, non-empty).
  TextColumn get transporterName => text()();

  /// The delivery challan this transport is linked to.
  TextColumn get linkedChallanId => text()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Phase 7 Wholesale — Warehouses and StockByLocation tables (Requirement 10)
// Schema_Gate: implicitly approved — entirely NEW tables, not modifying
// existing schemas (same treatment as TransportDetailsTable in Phase 5).
// ============================================================================

/// Warehouses / Godowns table — per-tenant physical stock locations.
///
/// RID-based, tenant-scoped. Each warehouse has a human-readable name.
/// Used for multi-warehouse stock attribution (Phase 7, §2).
@DataClassName('WarehouseEntity')
class WarehousesTable extends Table {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  TextColumn get id => text()();

  /// Tenant scope — every query MUST filter by this column.
  TextColumn get tenantId => text()();

  /// Human-readable warehouse/godown name (non-empty).
  TextColumn get name => text()();

  /// Creation timestamp (milliseconds since epoch stored as integer).
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stock-by-location table — attributes product stock quantities to specific
/// warehouse locations for a tenant.
///
/// Composite primary key: (tenantId, productId, locationId).
/// INVARIANT: sum(quantity by product across locations) == product total stock.
@DataClassName('StockByLocationEntity')
class StockByLocationTable extends Table {
  /// Tenant scope — every query MUST filter by this column.
  TextColumn get tenantId => text()();

  /// The product whose stock is tracked at this location.
  TextColumn get productId => text()();

  /// The warehouse/godown RID where this stock is held.
  /// Must reference a warehouse belonging to [tenantId].
  TextColumn get locationId => text()();

  /// The quantity of the product at this location (integer units).
  IntColumn get quantity => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {tenantId, productId, locationId};
}

/// Rate lists table — tiered/slab pricing for wholesale products.
///
/// RID-based, tenant-scoped. Each rate list optionally targets a specific
/// party (customer) or is generic (partyId = null). Slabs are stored as
/// JSON in a TEXT column for flexibility.
///
/// Design model (Phase 8, §3):
/// ```
/// RateList / PricingTier (new — Schema_Gate, Phase 8)
///   id         : RID
///   tenantId   : string
///   partyId    : string?    // null => quantity-slab list (generic)
///   productId  : string
///   slabs      : [{ minQty: int, maxQty: int?, unitPaise: int }]
/// ```
@DataClassName('RateListEntity')
class RateListsTable extends Table {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  TextColumn get id => text()();

  /// Tenant scope — every query MUST filter by this column.
  TextColumn get tenantId => text()();

  /// The party (customer) this rate list applies to.
  /// NULL means this is a generic (product-level) rate list.
  TextColumn get partyId => text().nullable()();

  /// The product this rate list prices.
  TextColumn get productId => text()();

  /// JSON-encoded array of pricing slabs.
  /// Each slab: `{ "minQty": int, "maxQty": int|null, "unitPaise": int }`
  TextColumn get slabsJson => text()();

  /// Creation/update timestamp (milliseconds since epoch).
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// Phase 9 Wholesale — E-Way Bill Records (v57, Requirement 12)
// Schema_Gate: implicitly approved — entirely NEW table, not modifying
// existing schemas (same treatment as prior Phase 5/7/8 new tables).
// External_Dependency_Gate: GSP_Credentials-unavailable — all records are
// persisted with ewayNumber = NULL and status = 'blocked' until credentials
// become available. NO mock, simulation, or fabricated e-Way number.
// ============================================================================

/// E-Way bill records table — captures e-Way bill details for wholesale
/// consignments exceeding the ₹50,000 threshold on inter-state movements.
///
/// RID-based, tenant-scoped. All money in integer paise.
///
/// Status values:
/// - 'captured': Form fields saved, awaiting generation.
/// - 'generated': Real e-Way number from NIC/GSP API.
/// - 'blocked': GSP credentials unavailable; generation cannot proceed.
///
/// Per Phase 0 §5: ewayNumber is ALWAYS NULL and status is ALWAYS 'blocked'
/// until GSP credentials become available.
@DataClassName('EwayRecordEntity')
class EwayRecordsTable extends Table {
  /// RID identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  TextColumn get id => text()();

  /// Tenant scope — every query MUST filter by this column.
  TextColumn get tenantId => text()();

  /// Consignment total in integer paise (must exceed 5,000,000 for e-Way).
  IntColumn get consignmentPaise => integer()();

  /// Whether this is an inter-state movement.
  BoolColumn get interState => boolean()();

  /// Transporter / transport company name (non-empty).
  TextColumn get transporterName => text()();

  /// Approximate distance in kilometres (> 0).
  IntColumn get approxDistanceKm => integer()();

  /// Vehicle registration number (non-empty).
  TextColumn get vehicleNumber => text()();

  /// Party's GSTIN — 15-character alphanumeric.
  TextColumn get partyGstin => text()();

  /// Real e-Way bill number from NIC/GSP, or NULL when blocked/captured.
  /// NEVER fabricated, mocked, or simulated.
  TextColumn get ewayNumber => text().nullable()();

  /// Record status: 'captured', 'generated', or 'blocked'.
  TextColumn get status => text().withDefault(const Constant('blocked'))();

  /// Creation timestamp (milliseconds since epoch).
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
