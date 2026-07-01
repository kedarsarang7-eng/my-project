// ============================================================================
// BILLS REPOSITORY - OFFLINE-FIRST
// ============================================================================
// Manages sales invoices (Bills) with Drift persistence
//
// Author: DukanX Engineering
// Version: 2.1.0
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import '../../models/bill.dart'; // Unified Model
import '../../models/business_type.dart'; // Business type enum
import '../../features/accounting/accounting.dart' as acc;

import '../../features/inventory/services/inventory_service.dart';
import '../../features/ai_assistant/services/customer_recommendation_service.dart';
import '../../features/service/services/imei_validation_service.dart';
import '../../services/audit_service.dart';
import '../../services/daybook_service.dart'; // DayBook for real-time updates
import '../monitoring/business_analytics_service.dart';
import '../services/pharmacy_validation_service.dart'; // Pharmacy compliance
import '../error/pharmacy_compliance_exception.dart'; // Pharmacy exceptions
import '../../utils/mrp_enforcement_validator.dart'; // Pharmacy MRP ceiling (R8.3, R8.4)
import '../pharmacy/paise.dart'; // Integer-paise money helper (R2)
import '../error/credit_limit_exception.dart'; // Petrol pump credit limit
import '../../core/isolation/business_capability.dart';
import '../../core/isolation/feature_resolver.dart';

// Re-export Bill and BillItem for convenience
export '../../models/bill.dart' show Bill, BillItem;

import '../../features/inventory/data/product_batch_repository.dart';

import '../../features/inventory/services/batch_allocation_service.dart';
import '../services/event_dispatcher.dart';
import '../../features/gst/repositories/gst_repository.dart';
import '../../features/gst/services/gst_service.dart'; // GstService & LineItemForGst
import '../../features/billing/services/broker_billing_service.dart'; // Mandi
import '../../features/billing/services/commission_input.dart'; // Per-lot commission model
import '../monitoring/monitoring_service.dart'; // monitoring global // GstRepository Import
import '../../security/grace_period_gate.dart'; // Task 5.3: Read_Only/Locked gating
import '../security/store/store_forensic_gate.dart'; // Task 18.2: tamper read-only forensic mode

/// Bills Repository
class BillsRepository {
  final AppDatabase database;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final acc.AccountingService? accountingService;
  final InventoryService?
  inventoryService; // Optional for now to ease transition
  final CustomerRecommendationService? customerRecommendationService;
  final AuditService? auditService;
  final DayBookService? dayBookService; // For real-time daybook updates
  final IMEIValidationService?
  imeiValidationService; // IMEI validation for mobile/computer shops
  final ProductBatchRepository? productBatchRepository;
  final BatchAllocationService? batchAllocationService;
  final EventDispatcher eventDispatcher;
  final GstRepository? gstRepository; // Optional for transition
  final BrokerBillingService? brokerBillingService; // Mandi

  BillsRepository({
    required this.database,
    required this.syncManager,
    required this.errorHandler,
    this.accountingService,
    this.inventoryService,
    this.customerRecommendationService,
    this.auditService,
    this.dayBookService,
    this.imeiValidationService,
    this.productBatchRepository,
    this.batchAllocationService,
    this.gstRepository,
    this.brokerBillingService,
    EventDispatcher? eventDispatcher,
  }) : eventDispatcher = eventDispatcher ?? EventDispatcher.instance;

  static const String collectionName = 'bills';

  // --- Mandi helper: round-half-away-from-zero conversion ---
  // Consistent with the convention used throughout the Mandi vertical.
  static int _toPaise(double rupees) {
    final raw = rupees * 100.0;
    return (rupees >= 0)
        ? (raw.abs() + 0.5).floor()
        : -(raw.abs() + 0.5).floor();
  }

  // ... existing methods ...

  /// Create a new bill
  Future<RepositoryResult<Bill>> createBill(Bill bill) async {
    return await errorHandler.runSafe<Bill>(() async {
      final now = DateTime.now();

      // ============================================================
      // TASK 5.3: GRACE-PERIOD GATE (Read_Only / Locked)
      // ============================================================
      // While the License_Validator reports Read_Only (Req 7.8, 7.9) or
      // Locked (Req 7.13), new bills must not be created. The gate is the
      // single service-layer seam fed by the validator's Grace_Period_State.
      // Blocking here covers EVERY caller of createBill, with zero UI changes.
      if (GracePeriodGate.instance.isBillCreationBlocked) {
        throw Exception(GracePeriodGate.billCreationBlockedReason);
      }

      // ============================================================
      // TASK 18.2: READ-ONLY FORENSIC MODE (Local_Store tamper — Req 17.12)
      // ============================================================
      // If the Security_Layer detected the Local_Store as swapped/tampered,
      // the installation is read-only for forensics: reads stay allowed but
      // all writes are blocked.
      if (StoreForensicGate.instance.isWriteBlocked) {
        throw Exception(StoreForensicGate.writeBlockedReason);
      }

      // ============================================================
      // SECURITY GUARD: Business Type Isolation
      // ============================================================
      final shop = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(bill.ownerId))).getSingleOrNull();

      if (shop != null &&
          shop.businessType != null &&
          shop.businessType!.isNotEmpty &&
          shop.businessType != 'other' &&
          shop.businessType != bill.businessType) {
        throw Exception(
          'Security Violation: Cannot create ${bill.businessType} bill for ${shop.businessType} business. '
          'Business Type is locked.',
        );
      }

      // ============================================================
      // HARD ISOLATION: Feature Resolver Validation
      // ============================================================
      // 1. Prescription Check (Pharmacy/Clinic)
      if (bill.prescriptionId != null && bill.prescriptionId!.isNotEmpty) {
        FeatureResolver.enforceAccess(
          bill.businessType,
          BusinessCapability.usePrescription,
        );
      }

      // 2. Table Management (Restaurant)
      if (bill.tableNumber != null && bill.tableNumber!.isNotEmpty) {
        FeatureResolver.enforceAccess(
          bill.businessType,
          BusinessCapability.useTableManagement,
        );
      }

      // 3. Vehicle / Fuel (Petrol Pump / Garage)
      if ((bill.vehicleNumber != null && bill.vehicleNumber!.isNotEmpty) ||
          (bill.fuelType != null && bill.fuelType!.isNotEmpty)) {
        FeatureResolver.enforceAccess(
          bill.businessType,
          BusinessCapability.useVehicleDetails,
        );
      }

      // 4. Broker / Mandi
      if (bill.brokerId != null && bill.brokerId!.isNotEmpty) {
        FeatureResolver.enforceAccess(
          bill.businessType,
          BusinessCapability.useCommission,
        );
      }

      // 5. Item Level - IMEI (Electronics)
      // Check if ANY item has Serial/IMEI
      if (bill.items.any((i) => i.serialNo != null && i.serialNo!.isNotEmpty)) {
        FeatureResolver.enforceAccess(
          bill.businessType,
          BusinessCapability.useIMEI,
        );
      }

      // ============================================================
      // PHARMACY COMPLIANCE: FEFO Batch Allocation
      // ============================================================
      // If pharmacy, automatically select best batches (FEFO)
      // and split bill items if necessary.
      // ============================================================
      // ============================================================
      // PHARMACY COMPLIANCE: FEFO Batch Allocation
      // ============================================================
      // If pharmacy, automatically select best batches (FEFO)
      // and split bill items if necessary.
      // ============================================================
      if (batchAllocationService != null &&
          (bill.businessType == 'pharmacy' ||
              bill.businessType == 'medical_store')) {
        bill = await batchAllocationService!.allocateBatches(bill);
        // Recalculate totals after split to ensure consistency
        bill = _recalculateBillTotals(bill);
      }

      // ============================================================
      // PHARMACY COMPLIANCE: Validate bill items before sale
      // ============================================================
      // Block sale if:
      // - Any item is expired (expiryDate < now)
      // - Pharmacy/Wholesale: Missing batch number or expiry date
      //
      // SAFETY: This check happens BEFORE any database operations.
      // Backward compatible: Non-pharmacy businesses unaffected unless
      // they have items with expired expiryDate set.
      // ============================================================
      // Backward compatible: Non-pharmacy businesses unaffected unless
      // they have items with expired expiryDate set.
      // ============================================================
      await _validatePharmacyCompliance(bill);

      // IMEI Validation Step (for mobile/computer shops)
      // Validates all serial numbers before proceeding
      if (imeiValidationService != null) {
        // Tenant-Id guard: abort before any read/write if userId is missing
        if (bill.ownerId.isEmpty) {
          throw Exception(
            'IMEI Validation Aborted: Tenant_Id (userId) is missing or unresolved. '
            'No read or write was performed.',
          );
        }
        final validation = await imeiValidationService!.validateBillItems(
          userId: bill.ownerId,
          items: bill.items,
          businessType: bill.businessType,
        );
        if (!validation.isValid) {
          throw Exception(
            'IMEI Validation Failed: ${validation.errors.join(", ")}',
          );
        }
      }

      // INVOICE NUMBER UNIQUENESS CHECK
      // Prevents duplicate invoice numbers for the same user
      if (bill.invoiceNumber.isNotEmpty) {
        final existingBill =
            await (database.select(database.bills)..where(
                  (t) =>
                      t.userId.equals(bill.ownerId) &
                      t.invoiceNumber.equals(bill.invoiceNumber) &
                      t.deletedAt.isNull(),
                ))
                .getSingleOrNull();

        if (existingBill != null) {
          throw Exception(
            'Invoice number ${bill.invoiceNumber} already exists. Please use a unique invoice number.',
          );
        }
      }

      // ============================================================
      // SAFETY PATCH: Explicit Period Lock Check (Risk 3)
      // ============================================================
      // Block bill creation if the date falls in a locked accounting period.
      // This is an EXPLICIT guard - not relying on implicit AccountingService call.
      // BACKWARD COMPATIBLE: Only blocks if period is EXPLICITLY locked.
      // ============================================================
      if (accountingService != null) {
        try {
          final isLocked = await accountingService!.isPeriodLocked(
            userId: bill.ownerId,
            date: bill.date,
          );
          if (isLocked) {
            throw Exception(
              'Cannot create bill: Accounting period for ${bill.date.month}/${bill.date.year} is locked. '
              'Contact your accountant to unlock the period before creating backdated bills.',
            );
          }
        } catch (e) {
          // FAIL SECURE: If we cannot verify period status, BLOCK creation
          // This prevents bills from being created in locked periods during outages
          final errorMessage = e.toString();
          if (errorMessage.contains('Cannot create bill')) {
            // This is our intentional period lock exception - rethrow it
            rethrow;
          }
          // Any other error (DB connection, network, service down) blocks creation
          throw Exception(
            'Unable to verify accounting period status. Bill creation blocked for data integrity. '
            'Please try again or contact support if the issue persists. Error: $errorMessage',
          );
        }
      }

      // ============================================================
      // PETROL PUMP FRAUD PREVENTION: Credit Limit Enforcement
      // ============================================================
      // Block credit sales that would exceed customer's credit limit.
      // This is MANDATORY for petrol pumps to prevent unauthorized credit.
      //
      // Formula: projectedDues = currentDues + billAmount
      // If projectedDues > creditLimit → BLOCK
      //
      // BACKWARD COMPATIBLE: Only enforces for petrolPump business type.
      // ============================================================
      if (bill.businessType == 'petrolPump' &&
          bill.paymentType == 'Credit' &&
          bill.customerId.isNotEmpty) {
        try {
          final customer = await (database.select(
            database.customers,
          )..where((t) => t.id.equals(bill.customerId))).getSingleOrNull();

          if (customer != null && customer.creditLimit > 0) {
            final projectedDues = customer.totalDues + bill.grandTotal;

            if (projectedDues > customer.creditLimit) {
              // Audit log: Credit limit exceeded attempt
              try {
                if (auditService != null) {
                  auditService!.logSecurityEvent(
                    userId: bill.ownerId,
                    severity: 'HIGH',
                    message: 'Credit Limit Exceeded - Sale Blocked',
                    details: {
                      'customerId': bill.customerId,
                      'customerName': customer.name,
                      'currentDues': customer.totalDues,
                      'billAmount': bill.grandTotal,
                      'projectedDues': projectedDues,
                      'creditLimit': customer.creditLimit,
                    },
                  );
                }
              } catch (_) {}

              throw CreditLimitExceededException(
                currentDues: customer.totalDues,
                billAmount: bill.grandTotal,
                creditLimit: customer.creditLimit,
                customerName: customer.name,
              );
            }
          }
        } catch (e) {
          // If it's our credit limit exception, rethrow
          if (e is CreditLimitExceededException) rethrow;
          // Otherwise log and continue (don't block for service errors)
          debugPrint('[CREDIT_LIMIT] Check failed, allowing sale: $e');
        }
      }

      // Execute transaction and capture collected sync operations
      final collectedSyncOps = await database.transaction<List<SyncQueueItem>>(
        () async {
          // Collect sync operations inside transaction
          final syncOps = <SyncQueueItem>[];

          // 1. CALCULATE COGS (Cost of Goods Sold) at sale time
          // This captures the historical cost for accurate profit tracking
          double totalCogs = 0;
          for (final item in bill.items) {
            if (item.productId.isNotEmpty) {
              final product = await (database.select(
                database.products,
              )..where((t) => t.id.equals(item.productId))).getSingleOrNull();

              if (product != null) {
                totalCogs += item.qty * product.costPrice;
              }
            }
          }

          // Calculate gross profit (grandTotal - tax - COGS)
          // Note: grandTotal includes tax, so we need subtotal for net revenue
          final grossProfit = bill.subtotal - totalCogs;

          // 2. Insert into local DB with COGS data
          await database
              .into(database.bills)
              .insert(
                BillsCompanion.insert(
                  id: bill.id,
                  userId: bill.ownerId.isNotEmpty ? bill.ownerId : 'unknown',
                  invoiceNumber: bill.invoiceNumber,
                  customerId: Value(bill.customerId),
                  customerName: Value(bill.customerName),
                  billDate: bill.date,
                  subtotal: Value(bill.subtotal),
                  taxAmount: Value(bill.totalTax),
                  discountAmount: Value(bill.discountApplied),
                  grandTotal: Value(bill.grandTotal),
                  paidAmount: Value(bill.paidAmount),
                  cashPaid: Value(bill.cashPaid),
                  onlinePaid: Value(bill.onlinePaid),
                  businessType: Value(bill.businessType),
                  businessId: Value(bill.businessId),
                  serviceCharge: Value(bill.serviceCharge),
                  costOfGoodsSold: Value(totalCogs),
                  grossProfit: Value(grossProfit),
                  prescriptionId: Value(bill.prescriptionId),
                  itemsJson: jsonEncode(
                    bill.items.map((i) => i.toMap()).toList(),
                  ),
                  status: Value(bill.status),
                  paymentMode: Value(bill.paymentType),
                  source: Value(bill.source),
                  createdAt: now,
                  updatedAt: now,
                  // Restaurant
                  tableNumber: Value(bill.tableNumber),
                  waiterId: Value(bill.waiterId),
                  kotId: Value(bill.kotId),
                  // Petrol Pump
                  vehicleNumber: Value(bill.vehicleNumber),
                  driverName: Value(bill.driverName),
                  attendantId: Value(bill.attendantId),
                  fuelType: Value(bill.fuelType),
                  pumpReadingStart: Value(bill.pumpReadingStart),
                  pumpReadingEnd: Value(bill.pumpReadingEnd),
                  // Mandi
                  brokerId: Value(bill.brokerId),
                  marketCess: Value(bill.marketCess),
                  commissionAmount: Value(bill.commissionAmount),
                ),
              );

          // 2. ATOMIC Stock Deduction (within SAME transaction - no nested tx)
          if (inventoryService != null) {
            for (final item in bill.items) {
              if (item.productId.isNotEmpty && item.qty > 0) {
                // CHECK FOR RECIPE (BOM)
                // If recipe exists, we deduct RAW MATERIALS instead of the product itself.
                final recipe = await (database.select(
                  database.billOfMaterials,
                )..where((t) => t.finishedGoodId.equals(item.productId))).get();

                if (recipe.isNotEmpty) {
                  // DEDUCT INGREDIENTS based on Recipe
                  for (final ingredient in recipe) {
                    final qtyNeeded = ingredient.quantityRequired * item.qty;
                    final ops = await inventoryService!
                        .deductStockInTransaction(
                          userId: bill.ownerId,
                          productId: ingredient.rawMaterialId,
                          quantity: qtyNeeded,
                          referenceId: bill.id,
                          invoiceNumber: bill.invoiceNumber,
                          date: bill.date,
                          reason: 'SALE_INGREDIENT', // Distinct reason
                          description: 'Used in ${item.productName}',
                        );
                    syncOps.addAll(ops);
                  }
                  // NOTE: We do NOT deduct the finished good (service item) stock
                } else {
                  // NORMAL DEDUCTION (Finish Good / Trading Item)
                  final ops = await inventoryService!.deductStockInTransaction(
                    userId: bill.ownerId,
                    productId: item.productId,
                    quantity: item.qty,
                    referenceId: bill.id,
                    invoiceNumber: bill.invoiceNumber,
                    date: bill.date,
                    batchId: item.batchId,
                    batchNumber: item.batchNo,
                  );
                  syncOps.addAll(ops);
                }
              }
            }
          }

          // 2a. Mark IMEIs as Sold — moved OUTSIDE the transaction (see below).
          // If markIMEIsAsSold fails, the bill stays persisted (Req 4.9).

          // 2b. ATOMIC Payment Recording (Fixes Ghost Payments)
          if (bill.paidAmount > 0) {
            final paymentId = const Uuid().v4();
            await database
                .into(database.payments)
                .insert(
                  PaymentsCompanion.insert(
                    id: paymentId,
                    userId: bill.ownerId,
                    billId: bill.id,
                    customerId: Value(bill.customerId),
                    amount: bill.paidAmount,
                    paymentMode: bill.paymentType,
                    referenceNumber: const Value('Initial Payment'),
                    notes: const Value('Payment at time of bill creation'),
                    paymentDate: bill.date,
                    createdAt: now,
                    isSynced: const Value(false),
                    version: const Value(1),
                  ),
                );

            // Queue Payment Sync
            syncOps.add(
              SyncQueueItem.create(
                userId: bill.ownerId,
                operationType: SyncOperationType.create,
                targetCollection: 'payments',
                documentId: paymentId,
                payload: {
                  'id': paymentId,
                  'userId': bill.ownerId,
                  'billId': bill.id,
                  'customerId': bill.customerId,
                  'amount': bill.paidAmount,
                  'paymentMode': bill.paymentType,
                  'referenceNumber': 'Initial Payment',
                  'notes': 'Payment at time of bill creation',
                  'paymentDate': bill.date.toIso8601String(),
                  'createdAt': now.toIso8601String(),
                },
              ),
            );
          }

          // 3. Update Customer Balance if applicable
          if (bill.customerId.isNotEmpty) {
            final customer = await (database.select(
              database.customers,
            )..where((t) => t.id.equals(bill.customerId))).getSingleOrNull();

            if (customer != null) {
              final newTotalBilled = customer.totalBilled + bill.grandTotal;
              final newTotalDues =
                  customer.totalDues + (bill.grandTotal - bill.paidAmount);

              await (database.update(
                database.customers,
              )..where((t) => t.id.equals(bill.customerId))).write(
                CustomersCompanion(
                  totalBilled: Value(newTotalBilled),
                  totalDues: Value(newTotalDues),
                  updatedAt: Value(now),
                  isSynced: const Value(false),
                ),
              );

              // Collect customer sync for after transaction
              syncOps.add(
                SyncQueueItem.create(
                  userId: bill.ownerId,
                  operationType: SyncOperationType.update,
                  targetCollection: 'customers',
                  documentId: bill.customerId,
                  payload: {
                    'totalBilled': newTotalBilled,
                    'totalDues': newTotalDues,
                    'updatedAt': now.toIso8601String(),
                  },
                ),
              );
            }
          }

          // 4. Create Accounting Journal Entry (will THROW if period locked)
          if (accountingService != null) {
            await accountingService!.createSalesEntry(
              userId: bill.ownerId,
              billId: bill.id,
              customerId: bill.customerId.isNotEmpty ? bill.customerId : 'CASH',
              customerName: bill.customerName.isNotEmpty
                  ? bill.customerName
                  : 'Walk-in Customer',
              totalAmount: bill.grandTotal,
              taxableAmount: bill.subtotal,
              cgstAmount: 0,
              sgstAmount: 0,
              igstAmount: 0,
              discountAmount: bill.discountApplied,
              invoiceDate: bill.date,
              invoiceNumber: bill.invoiceNumber,
            );
          }

          return syncOps;
        },
      );

      // 5. Queue ALL collected sync operations AFTER transaction commits
      // If transaction failed, we never reach here - atomic guarantee!
      for (final syncOp in collectedSyncOps) {
        await syncManager.enqueue(syncOp);
      }

      // 6. Queue bill for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: bill.ownerId,
          operationType: SyncOperationType.create,
          targetCollection: collectionName,
          documentId: bill.id,
          payload: bill.toMap(),
        ),
      );

      // 6a. Mark IMEIs as Sold AFTER persistence (Req 4.2, 4.3, 4.9)
      // On failure, the bill stays persisted and an error naming
      // the unmarked IMEIs is returned to the caller.
      if (imeiValidationService != null) {
        final markResult = await imeiValidationService!.markIMEIsAsSoldSafe(
          userId: bill.ownerId,
          billId: bill.id,
          customerId: bill.customerId,
          items: bill.items,
        );
        if (markResult.hasFailures) {
          // Bill is persisted — return success with a warning about unmarked IMEIs
          debugPrint(
            '[IMEI_MARK] Bill ${bill.id} persisted but some IMEIs not marked sold: '
            '${markResult.failedIMEIs.join(", ")}',
          );
          throw Exception(
            'Bill saved successfully but failed to mark IMEIs as sold: '
            '${markResult.failedIMEIs.join(", ")}. '
            'Please update these manually.',
          );
        }
      }

      // 7. Track Customer Visit for Recommendation Engine (non-blocking)
      if (customerRecommendationService != null && bill.customerId.isNotEmpty) {
        try {
          await customerRecommendationService!.trackVisit(
            userId: bill.ownerId,
            customerId: bill.customerId,
            billAmount: bill.grandTotal,
          );
        } catch (e) {
          debugPrint('Error tracking visit: $e');
        }
      }

      // 8. Audit Log (non-blocking)
      if (auditService != null) {
        // Fire and forget, don't await blocking the UI
        auditService!.logInvoiceCreation(bill);
      }

      // 9. Track business analytics event (non-blocking)
      try {
        businessAnalytics.trackBillCreated(
          billId: bill.id,
          amount: bill.grandTotal,
          paymentStatus: bill.status,
          customerId: bill.customerId.isNotEmpty ? bill.customerId : null,
          businessId: bill.ownerId,
          itemCount: bill.items.length,
        );
      } catch (e) {
        debugPrint('[Analytics] Failed to track bill_created: $e');
      }

      // 10. Event Dispatcher: Trigger side effects
      eventDispatcher.invoiceCreated(
        billId: bill.id,
        customerId: bill.customerId,
        amount: bill.grandTotal,
        userId: bill.ownerId,
      );

      // ============================================================
      // GST PERSISTENCE (GAP-3 PATCH)
      // ============================================================
      // Calculate and save detailed GST breakdown for reports
      // This ensures GSTR-1 and GSTR-3B have data to work with.
      // ============================================================
      if (gstRepository != null && bill.totalTax > 0) {
        try {
          // 1. Get GST Settings to find seller state
          final gstSettings = await gstRepository!.getGstSettings(bill.ownerId);
          final sellerStateCode = gstSettings?.stateCode ?? '27'; // Default MH

          // 2. Prepare Items for Calculation
          final gstItems = bill.items
              .where((i) => i.taxAmount > 0 || i.gstRate > 0)
              .map(
                (i) => LineItemForGst(
                  hsnCode: i.hsn.isNotEmpty ? i.hsn : null,
                  description: i.productName,
                  quantity: i.qty,
                  unit: i.unit,
                  taxableValue: (i.qty * i.price) - i.discount, // Excludes tax
                  gstRate: i.gstRate,
                ),
              )
              .toList();

          if (gstItems.isNotEmpty) {
            // 3. Calculate GST Summary
            // We need customer state code. If customer has GSTIN, extract it.
            // If not, use '27' (Intrastate) by default for now unless address has state.
            // For MVP, we'll assume Intrastate if no GSTIN or explicit state.
            String? customerStateCode = sellerStateCode; // Default Intra
            String? customerGstin = bill.customerGst;

            if (customerGstin.length >= 2) {
              customerStateCode = customerGstin.substring(0, 2);
            }

            final gstSummary = GstService.calculateInvoiceGst(
              items: gstItems,
              sellerStateCode: sellerStateCode,
              customerStateCode: customerStateCode,
              customerGstin: customerGstin.isNotEmpty ? customerGstin : null,
            );

            // 4. Create and Save Invoice Detail
            final gstDetail = GstService.createGstInvoiceDetail(
              billId: bill.id,
              summary: gstSummary,
              placeOfSupply: customerStateCode,
            );

            await gstRepository!.saveGstInvoiceDetail(gstDetail);
          }
        } catch (e) {
          // Log but don't fail the bill creation
          monitoring.error('BillsRepository', 'Failed to save GST details: $e');
        }
      }

      if (bill.paidAmount > 0) {
        // Note: Actual payment ID was generated inside transaction
        eventDispatcher.paymentReceived(
          receiptId: 'BILL_PAYMENT_${bill.id}',
          billId: bill.id,
          customerId: bill.customerId,
          amount: bill.paidAmount,
          paymentMode: bill.paymentType,
          userId: bill.ownerId,
        );
      }

      // ============================================================
      // MANDI / BROKER LOGIC
      // ============================================================
      // Persist the captured commission directly per lot/per farmer.
      // No flat→%→flat back-conversion (Requirement 5.1).
      if (bill.brokerId != null && bill.commissionAmount > 0) {
        if (brokerBillingService != null) {
          try {
            // The entry sheet captures a flat ₹ commission amount.
            // Convert to integer paise (round-half-away-from-zero) and persist
            // directly as FlatCommission — no percentage recomputation.
            final commissionPaise = _toPaise(bill.commissionAmount);

            final error = await brokerBillingService!.recordBrokerSale(
              userId: bill.ownerId,
              billId: bill.id,
              farmerId: bill.brokerId!,
              saleAmountPaise: _toPaise(bill.grandTotal),
              commission: FlatCommission(commissionPaise),
            );
            if (error != null) {
              debugPrint('Broker sale rejected: $error');
            }
          } catch (e) {
            debugPrint('Failed to record broker sale: $e');
            // Non-blocking, but should be logged
          }
        }
      }

      return bill;
    }, 'createBill');
  }

  /// Update an existing bill with FULL RECOMPUTATION
  ///
  /// CRITICAL FIX: This method now:
  /// 1. RECALCULATES all totals from items (never trusts frontend values)
  /// 2. ADJUSTS STOCK based on quantity changes (old vs new)
  /// 3. Updates customer ledger with proper deltas
  /// 4. Creates audit trail for all changes
  ///
  /// FRAUD PREVENTION:
  /// - Throws Exception if bill is LOCKED (Paid/Printed) and no approval provided.
  /// - Optimistic locking via expectedUpdatedAt (optional, backward compatible)
  Future<RepositoryResult<Bill>> updateBill(
    Bill bill, {
    String? approverId,
    String? editReason,
    DateTime? expectedUpdatedAt, // Control 1: Optimistic locking
  }) async {
    return await errorHandler.runSafe<Bill>(() async {
      final now = DateTime.now();

      // ============================================================
      // TASK 5.3: GRACE-PERIOD GATE (Locked)
      // ============================================================
      // While Locked, all record editing is blocked until reactivation
      // completes (Req 7.13). Read_Only still permits editing existing
      // records, so only Locked is gated here.
      if (GracePeriodGate.instance.isLocked) {
        throw Exception(GracePeriodGate.lockedWriteBlockedReason);
      }

      // ============================================================
      // TASK 18.2: READ-ONLY FORENSIC MODE (Local_Store tamper — Req 17.12)
      // ============================================================
      if (StoreForensicGate.instance.isWriteBlocked) {
        throw Exception(StoreForensicGate.writeBlockedReason);
      }

      // ============================================================
      // SECURITY GUARD: Business Type Isolation
      // ============================================================
      final shop = await (database.select(
        database.shops,
      )..where((t) => t.id.equals(bill.ownerId))).getSingleOrNull();

      if (shop != null &&
          shop.businessType != null &&
          shop.businessType!.isNotEmpty &&
          shop.businessType != 'other' &&
          shop.businessType != bill.businessType) {
        throw Exception(
          'Security Violation: Cannot update bill to ${bill.businessType} for ${shop.businessType} business. Type is locked.',
        );
      }

      // ============================================================
      // GAP-2 PATCH: Period Lock Check (Audit Compliance)
      // ============================================================
      // Block modification if the bill date falls in a locked period.
      // This ensures audit compliance after month/year close.
      //
      // BACKWARD COMPATIBLE: Only blocks if period is EXPLICITLY locked.
      // If accountingService is null or method fails, allow modification.
      // ============================================================
      if (accountingService != null) {
        try {
          final isLocked = await accountingService!.isPeriodLocked(
            userId: bill.ownerId,
            date: bill.date,
          );
          if (isLocked) {
            throw Exception(
              'Cannot modify bill: Accounting period for ${bill.date.month}/${bill.date.year} is locked. '
              'Contact your accountant to unlock the period.',
            );
          }
        } catch (e) {
          // If it's our period lock exception, rethrow
          if (e.toString().contains('Cannot modify bill')) rethrow;
          // Otherwise log and continue (don't block for service errors)
          debugPrint('[PERIOD_LOCK] Check failed, allowing modification: $e');
        }
      }

      // Lift oldEntity and oldItems outside transaction for audit logging
      late BillEntity oldEntity;
      late List<BillItem> oldItems;
      late Bill recalculatedBill;

      // Collect sync operations for queuing after transaction
      final collectedSyncOps = await database.transaction<List<SyncQueueItem>>(
        () async {
          final syncOps = <SyncQueueItem>[];

          // 1. Fetch old bill to calculate deltas
          final fetchedEntity = await (database.select(
            database.bills,
          )..where((t) => t.id.equals(bill.id))).getSingleOrNull();

          if (fetchedEntity == null) throw Exception('Bill not found');
          oldEntity = fetchedEntity;

          // ============================================================
          // SAFETY PATCH: Optimistic Locking (Control 1)
          // ============================================================
          // Prevent race conditions by comparing updatedAt timestamps.
          // If expectedUpdatedAt is provided and doesn't match DB's updatedAt,
          // it means another process modified the bill after client loaded it.
          // Uses existing updatedAt column - NO SCHEMA CHANGE.
          // BACKWARD COMPATIBLE: Only enforces if expectedUpdatedAt is provided.
          // ============================================================
          if (expectedUpdatedAt != null) {
            final dbUpdatedAt = oldEntity.updatedAt;
            // Allow 2 second tolerance for clock skew
            final difference = dbUpdatedAt
                .difference(expectedUpdatedAt)
                .inSeconds
                .abs();
            if (difference > 2) {
              throw Exception(
                'Concurrent edit detected: This bill was modified by another user or device. '
                'Please refresh and try again. (Expected: ${expectedUpdatedAt.toIso8601String()}, '
                'Found: ${dbUpdatedAt.toIso8601String()})',
              );
            }
          }

          // ============================================================
          // GAP-1 PATCH: Ghost Return / Edit Prevention
          // ============================================================
          // Check if the bill is LOCKED (Printed or Paid)
          final isLocked =
              (oldEntity.printCount > 0) ||
              (oldEntity.paidAmount > 0 && oldEntity.status != 'DRAFT') ||
              (oldEntity.status == 'Paid');

          if (isLocked) {
            // Require Authorization
            if (approverId == null ||
                editReason == null ||
                editReason.isEmpty) {
              throw Exception(
                'Bill is LOCKED (Printed/Paid). Manager Approval & Reason required to edit.',
              );
            }

            // If authorized, we will log a special audit event later
          }
          // ============================================================

          // Parse old items for stock comparison
          try {
            final decoded = jsonDecode(oldEntity.itemsJson) as List;
            oldItems = decoded
                .map((i) => BillItem.fromMap(i as Map<String, dynamic>))
                .toList();
          } catch (_) {
            oldItems = [];
          }

          // 2. RECALCULATE totals from items (NEVER trust frontend values)
          recalculatedBill = _recalculateBillTotals(bill);

          // 3. STOCK ADJUSTMENT for quantity changes
          if (inventoryService != null) {
            // Build maps for efficient lookup
            final oldItemMap = <String, double>{};
            for (final item in oldItems) {
              if (item.productId.isNotEmpty) {
                oldItemMap[item.productId] =
                    (oldItemMap[item.productId] ?? 0) + item.qty;
              }
            }

            final newItemMap = <String, double>{};
            for (final item in bill.items) {
              if (item.productId.isNotEmpty) {
                newItemMap[item.productId] =
                    (newItemMap[item.productId] ?? 0) + item.qty;
              }
            }

            // Get all unique product IDs
            final allProductIds = {...oldItemMap.keys, ...newItemMap.keys};

            for (final productId in allProductIds) {
              final oldQty = oldItemMap[productId] ?? 0;
              final newQty = newItemMap[productId] ?? 0;
              final qtyDelta =
                  oldQty - newQty; // Positive = need to restore stock

              if (qtyDelta.abs() > 0.001) {
                // Use small threshold for floating point
                if (qtyDelta > 0) {
                  // Restore stock (qty reduced in edit or item removed)
                  await inventoryService!.addStockMovement(
                    userId: bill.ownerId,
                    productId: productId,
                    type: 'IN',
                    reason: 'BILL_EDIT_REVERSAL',
                    quantity: qtyDelta.abs(),
                    referenceId: bill.id,
                    description:
                        'Stock restored due to bill edit: ${bill.invoiceNumber}',
                    createdBy: 'SYSTEM',
                  );
                } else {
                  // Deduct more stock (qty increased in edit or new item added)
                  final ops = await inventoryService!.deductStockInTransaction(
                    userId: bill.ownerId,
                    productId: productId,
                    quantity: qtyDelta.abs(),
                    referenceId: bill.id,
                    invoiceNumber: bill.invoiceNumber,
                    date: bill.date,
                  );
                  syncOps.addAll(ops);
                }
              }
            }
          }

          // 4. Calculate customer ledger deltas
          final oldGrandTotal = oldEntity.grandTotal;
          final oldPending = (oldGrandTotal - oldEntity.paidAmount).clamp(
            0.0,
            double.infinity,
          );
          final newPending =
              (recalculatedBill.grandTotal - recalculatedBill.paidAmount).clamp(
                0.0,
                double.infinity,
              );
          final duesDelta = newPending - oldPending;
          final billedDelta = recalculatedBill.grandTotal - oldGrandTotal;

          // 5. Update Bill in Local DB with RECALCULATED values
          await (database.update(
            database.bills,
          )..where((t) => t.id.equals(bill.id))).write(
            BillsCompanion(
              invoiceNumber: Value(recalculatedBill.invoiceNumber),
              customerId: Value(recalculatedBill.customerId),
              customerName: Value(recalculatedBill.customerName),
              billDate: Value(recalculatedBill.date),
              subtotal: Value(recalculatedBill.subtotal),
              taxAmount: Value(recalculatedBill.totalTax),
              discountAmount: Value(recalculatedBill.discountApplied),
              grandTotal: Value(recalculatedBill.grandTotal),
              paidAmount: Value(recalculatedBill.paidAmount),
              cashPaid: Value(recalculatedBill.cashPaid),
              onlinePaid: Value(recalculatedBill.onlinePaid),
              businessType: Value(recalculatedBill.businessType),
              businessId: Value(recalculatedBill.businessId),
              serviceCharge: Value(recalculatedBill.serviceCharge),
              prescriptionId: Value(recalculatedBill.prescriptionId),
              itemsJson: Value(
                jsonEncode(
                  recalculatedBill.items.map((i) => i.toMap()).toList(),
                ),
              ),
              status: Value(recalculatedBill.status),
              paymentMode: Value(recalculatedBill.paymentType),
              source: Value(recalculatedBill.source),
              updatedAt: Value(now),
              isSynced: const Value(false),
              printCount: Value(recalculatedBill.printCount),
              // Restaurant
              tableNumber: Value(recalculatedBill.tableNumber),
              waiterId: Value(recalculatedBill.waiterId),
              kotId: Value(recalculatedBill.kotId),
              // Petrol Pump
              vehicleNumber: Value(recalculatedBill.vehicleNumber),
              driverName: Value(recalculatedBill.driverName),
              attendantId: Value(recalculatedBill.attendantId),
              fuelType: Value(recalculatedBill.fuelType),
              pumpReadingStart: Value(recalculatedBill.pumpReadingStart),
              pumpReadingEnd: Value(recalculatedBill.pumpReadingEnd),
              // Mandi
              brokerId: Value(recalculatedBill.brokerId),
              marketCess: Value(recalculatedBill.marketCess),
              commissionAmount: Value(recalculatedBill.commissionAmount),
            ),
          );

          // 6. Update Customer Ledger with deltas
          if (recalculatedBill.customerId.isNotEmpty &&
              (duesDelta.abs() > 0.001 || billedDelta.abs() > 0.001)) {
            final customer =
                await (database.select(database.customers)
                      ..where((t) => t.id.equals(recalculatedBill.customerId)))
                    .getSingleOrNull();

            if (customer != null) {
              final newTotalDues = (customer.totalDues + duesDelta).clamp(
                0.0,
                double.infinity,
              );
              final newTotalBilled = (customer.totalBilled + billedDelta).clamp(
                0.0,
                double.infinity,
              );

              await (database.update(
                database.customers,
              )..where((t) => t.id.equals(recalculatedBill.customerId))).write(
                CustomersCompanion(
                  totalDues: Value(newTotalDues),
                  totalBilled: Value(newTotalBilled),
                  updatedAt: Value(now),
                  isSynced: const Value(false),
                ),
              );

              // Queue customer sync
              syncOps.add(
                SyncQueueItem.create(
                  userId: recalculatedBill.ownerId,
                  operationType: SyncOperationType.update,
                  targetCollection: 'customers',
                  documentId: recalculatedBill.customerId,
                  payload: {
                    'totalDues': newTotalDues,
                    'totalBilled': newTotalBilled,
                    'updatedAt': now.toIso8601String(),
                  },
                ),
              );
            }
          }

          return syncOps;
        },
      );

      // 7. Queue all collected sync operations AFTER transaction commits
      for (final syncOp in collectedSyncOps) {
        await syncManager.enqueue(syncOp);
      }

      // 8. Queue bill sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: recalculatedBill.ownerId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: recalculatedBill.id,
          payload: recalculatedBill.toMap(),
        ),
      );

      // 9. DAYBOOK UPDATE - Record delta for bill edit (non-blocking)
      // If amounts changed, we need to adjust the daybook
      if (dayBookService != null) {
        try {
          final amountDelta =
              recalculatedBill.grandTotal - oldEntity.grandTotal;
          if (amountDelta.abs() > 0.01) {
            // Only update if there's a meaningful change
            final isCashSale =
                recalculatedBill.paymentType.toUpperCase() == 'CASH';
            await dayBookService!.recordSaleRealtime(
              businessId: recalculatedBill.ownerId,
              saleDate: recalculatedBill.date,
              amount: amountDelta, // Positive = increase, Negative = decrease
              isCashSale: isCashSale,
              cgst: 0, // Tax delta handled separately if needed
              sgst: 0,
              igst: 0,
            );
          }
        } catch (e) {
          debugPrint('[DAYBOOK] Update failed for bill edit: $e');
          // Non-blocking - daybook can be reconciled later
        }
      }

      // 10. Audit Log (non-blocking)

      if (auditService != null) {
        try {
          final oldBill = _entityToBill(oldEntity);
          auditService!.logInvoiceUpdate(oldBill, recalculatedBill);
        } catch (e) {
          debugPrint('Failed to log audit update: $e');
        }

        // Special Audit for Forced Edit
        if (approverId != null && auditService != null) {
          try {
            auditService!.logSecurityEvent(
              userId: bill.ownerId,
              severity: 'HIGH',
              message: 'Bill Force Edit Authorized',
              details: {
                'billId': bill.id,
                'approverId': approverId,
                'reason': editReason,
                'oldGrandTotal': oldEntity.grandTotal,
                'newGrandTotal': recalculatedBill.grandTotal,
              },
            );
          } catch (_) {}
        }
      }

      return recalculatedBill;
    }, 'updateBill');
  }

  /// Recalculate bill totals from items
  /// CRITICAL: This ensures we NEVER trust frontend-calculated totals
  Bill _recalculateBillTotals(Bill bill) {
    double subtotal = 0;
    double totalTax = 0;
    double totalDiscount = 0;

    for (final item in bill.items) {
      // Calculate line amounts
      final lineBase = item.qty * item.price;
      final lineDiscount = item.discount;
      final lineNet = lineBase - lineDiscount;

      // Tax is calculated on net amount (after discount)
      final lineCgst = item.cgst; // Already calculated tax amount
      final lineSgst = item.sgst;
      final lineIgst = item.igst;

      // Additional charges
      final laborCharge = item.laborCharge ?? 0;
      final partsCharge = item.partsCharge ?? 0;
      final commission = item.commission ?? 0;
      final marketFee = item.marketFee ?? 0;

      subtotal += lineNet + laborCharge + partsCharge + commission + marketFee;
      totalTax += lineCgst + lineSgst + lineIgst;
      totalDiscount += lineDiscount;
    }

    // Add service charge if applicable
    final serviceCharge = bill.serviceCharge;
    final grandTotal = subtotal + totalTax + serviceCharge;

    // Derive status based on payment
    final status = _deriveBillStatus(bill.paidAmount, grandTotal);

    return bill.copyWith(
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      totalTax: double.parse(totalTax.toStringAsFixed(2)),
      discountApplied: double.parse(totalDiscount.toStringAsFixed(2)),
      grandTotal: double.parse(grandTotal.toStringAsFixed(2)),
      status: status,
    );
  }

  /// Derive bill status from payment amounts
  String _deriveBillStatus(double paidAmount, double grandTotal) {
    if (grandTotal <= 0) return 'Unpaid';
    if ((grandTotal - paidAmount).abs() <= 0.01) return 'Paid';
    if (paidAmount <= 0) return 'Unpaid';
    return 'Partial';
  }

  /// Get bill by ID
  Future<RepositoryResult<Bill>> getById(String id) async {
    return await errorHandler.runSafe<Bill>(() async {
      final entity = await (database.select(
        database.bills,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) throw Exception('Bill not found');
      return _entityToBill(entity);
    }, 'getById');
  }

  /// Get all bills
  Future<RepositoryResult<List<Bill>>> getAll({
    required String userId,
    String? customerId,
    String? businessId,
  }) async {
    return await errorHandler.runSafe<List<Bill>>(() async {
      final query = database.select(database.bills)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());

      if (businessId != null) {
        query.where((t) => t.businessId.equals(businessId));
      }

      if (customerId != null) {
        query.where((t) => t.customerId.equals(customerId));
      }

      query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      final results = await query.get();
      return results.map(_entityToBill).toList();
    }, 'getAll');
  }

  /// Watch all bills
  Stream<List<Bill>> watchAll({
    required String userId,
    String? customerId,
    String? businessId,
  }) {
    final query = database.select(database.bills)
      ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull());

    if (businessId != null) {
      query.where((t) => t.businessId.equals(businessId));
    }

    if (customerId != null) {
      query.where((t) => t.customerId.equals(customerId));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) => rows.map(_entityToBill).toList());
  }

  /// Record payment for a bill
  Future<RepositoryResult<bool>> recordPayment({
    required String userId,
    required String billId,
    required double amount,
    required String paymentMode, // 'Cash' or 'Online'
    String? notes,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();
      String? customerId; // Lift variable for access outside transaction

      await database.transaction(() async {
        final entity = await (database.select(
          database.bills,
        )..where((t) => t.id.equals(billId))).getSingleOrNull();

        if (entity == null) throw Exception('Bill not found');

        // Capture customerId for later
        customerId = entity.customerId;

        final newPaidAmount = entity.paidAmount + amount;
        final isFullyPaid =
            newPaidAmount >= entity.grandTotal; // Using grandTotal from entity

        // Status Update Logic
        final newStatus = isFullyPaid
            ? 'Paid'
            : (newPaidAmount > 0 ? 'Partial' : 'Unpaid');

        double newCashPaid = entity.cashPaid;
        double newOnlinePaid = entity.onlinePaid;

        if (paymentMode.toLowerCase() == 'cash') {
          newCashPaid += amount;
        } else {
          newOnlinePaid += amount;
        }

        // 1. Update Bill
        await (database.update(
          database.bills,
        )..where((t) => t.id.equals(billId))).write(
          BillsCompanion(
            paidAmount: Value(newPaidAmount),
            cashPaid: Value(newCashPaid),
            onlinePaid: Value(newOnlinePaid),
            status: Value(newStatus),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

        // Queue bill update
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.update,
            targetCollection: collectionName,
            documentId: billId,
            payload: {
              'paidAmount': newPaidAmount,
              'cashPaid': newCashPaid,
              'onlinePaid': newOnlinePaid,
              'status': newStatus,
              'updatedAt': now.toIso8601String(),
            },
          ),
        );

        // 2. Add Revenue Record (Receipt) - Creates Payment Entity
        final paymentId = const Uuid().v4();
        await database
            .into(database.payments)
            .insert(
              PaymentsCompanion.insert(
                id: paymentId,
                userId: userId,
                billId: billId,
                customerId: entity.customerId != null
                    ? Value(entity.customerId)
                    : const Value.absent(),
                amount: amount,
                paymentMode: paymentMode,
                notes: notes != null ? Value(notes) : const Value.absent(),
                paymentDate: now,
                createdAt: now,
                isSynced: const Value(false),
                version: const Value(1),
              ),
            );

        // Queue Payment Sync
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.create,
            targetCollection: 'payments',
            documentId: paymentId,
            payload: {
              'id': paymentId,
              'userId': userId,
              'billId': billId,
              'customerId': entity.customerId,
              'amount': amount,
              'paymentMode': paymentMode,
              'notes': notes,
              'paymentDate': now.toIso8601String(),
              'createdAt': now.toIso8601String(),
            },
          ),
        );

        // 3. Update Customer Ledger
        if (entity.customerId != null && entity.customerId!.isNotEmpty) {
          final customer = await (database.select(
            database.customers,
          )..where((t) => t.id.equals(entity.customerId!))).getSingleOrNull();

          if (customer != null) {
            final newTotalPaid = customer.totalPaid + amount;
            // Clamp to 0 to prevent negative dues if paidAmount > dues
            final newTotalDues = (customer.totalDues - amount).clamp(
              0.0,
              double.infinity,
            );

            await (database.update(
              database.customers,
            )..where((t) => t.id.equals(entity.customerId!))).write(
              CustomersCompanion(
                totalPaid: Value(newTotalPaid),
                totalDues: Value(newTotalDues),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            await syncManager.enqueue(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'customers',
                documentId: entity.customerId!,
                payload: {
                  'totalPaid': newTotalPaid,
                  'totalDues': newTotalDues,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }
      });

      // 4. Create Accounting Entry
      if (accountingService != null) {
        try {
          // Using synthetic paymentId as it's not easily exposed from transaction yet
          await accountingService!.createReceiptEntry(
            userId: userId,
            paymentId:
                'PAY-${billId.substring(0, 8)}-${now.millisecondsSinceEpoch}',
            customerId: customerId ?? 'CUST',
            customerName: '',
            amount: amount,
            paymentDate: now,
            paymentMode: paymentMode,
            billId: billId,
          );
        } catch (e) {
          debugPrint('Accounting entry failed for payment: $e');
        }
      }

      // 5. Audit Logging (non-blocking)
      if (auditService != null) {
        auditService!.logPaymentCreation(
          userId: userId,
          billId: billId,
          amount: amount,
          paymentMode: paymentMode,
          paymentId: null,
        );
      }

      return true;
    }, 'recordPayment');
  }

  /// Delete a payment with FULL REVERSAL
  ///
  /// CRITICAL FIX: This method:
  /// 1. Reverses the bill paid amount
  /// 2. Reverses customer ledger (totalPaid, totalDues)
  /// 3. Soft deletes the payment (keeps for audit trail)
  /// 4. Queues sync operations
  Future<RepositoryResult<bool>> deletePayment({
    required String userId,
    required String paymentId,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();

      await database.transaction(() async {
        // 1. Fetch the payment
        final payment =
            await (database.select(database.payments)
                  ..where((t) => t.id.equals(paymentId) & t.deletedAt.isNull()))
                .getSingleOrNull();

        if (payment == null) {
          throw Exception('Payment not found or already deleted: $paymentId');
        }

        // 2. Fetch and update the bill
        final bill = await (database.select(
          database.bills,
        )..where((t) => t.id.equals(payment.billId))).getSingleOrNull();

        if (bill != null) {
          final newPaidAmount = (bill.paidAmount - payment.amount).clamp(
            0.0,
            double.infinity,
          );
          final newStatus = newPaidAmount >= bill.grandTotal
              ? 'Paid'
              : (newPaidAmount > 0 ? 'Partial' : 'Unpaid');

          // Reverse cash/online paid amounts
          double newCashPaid = bill.cashPaid;
          double newOnlinePaid = bill.onlinePaid;

          if (payment.paymentMode.toLowerCase() == 'cash') {
            newCashPaid = (newCashPaid - payment.amount).clamp(
              0.0,
              double.infinity,
            );
          } else {
            newOnlinePaid = (newOnlinePaid - payment.amount).clamp(
              0.0,
              double.infinity,
            );
          }

          await (database.update(
            database.bills,
          )..where((t) => t.id.equals(payment.billId))).write(
            BillsCompanion(
              paidAmount: Value(newPaidAmount),
              cashPaid: Value(newCashPaid),
              onlinePaid: Value(newOnlinePaid),
              status: Value(newStatus),
              updatedAt: Value(now),
              isSynced: const Value(false),
            ),
          );

          // Queue bill update for sync
          await syncManager.enqueue(
            SyncQueueItem.create(
              userId: userId,
              operationType: SyncOperationType.update,
              targetCollection: 'bills',
              documentId: payment.billId,
              payload: {
                'paidAmount': newPaidAmount,
                'cashPaid': newCashPaid,
                'onlinePaid': newOnlinePaid,
                'status': newStatus,
                'updatedAt': now.toIso8601String(),
              },
            ),
          );
        }

        // 3. Reverse customer ledger
        if (payment.customerId != null && payment.customerId!.isNotEmpty) {
          final customer = await (database.select(
            database.customers,
          )..where((t) => t.id.equals(payment.customerId!))).getSingleOrNull();

          if (customer != null) {
            // Reverse: totalPaid decreases, totalDues increases
            final newTotalPaid = (customer.totalPaid - payment.amount).clamp(
              0.0,
              double.infinity,
            );
            final newTotalDues = customer.totalDues + payment.amount;

            await (database.update(
              database.customers,
            )..where((t) => t.id.equals(payment.customerId!))).write(
              CustomersCompanion(
                totalPaid: Value(newTotalPaid),
                totalDues: Value(newTotalDues),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            // Queue customer sync
            await syncManager.enqueue(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'customers',
                documentId: payment.customerId!,
                payload: {
                  'totalPaid': newTotalPaid,
                  'totalDues': newTotalDues,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }

        // 4. Soft delete the payment (keep for audit trail)
        await (database.update(
          database.payments,
        )..where((t) => t.id.equals(paymentId))).write(
          PaymentsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

        // 5. Queue payment deletion for sync
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.delete,
            targetCollection: 'payments',
            documentId: paymentId,
            payload: {'deletedAt': now.toIso8601String()},
          ),
        );
      });

      // 6. Audit Logging (non-blocking)
      if (auditService != null) {
        try {
          auditService!.logPaymentDeletion(
            userId: userId,
            paymentId: paymentId,
            reason: 'User Deleted - Ledger Reversed',
          );
        } catch (e) {
          debugPrint('Failed to log payment deletion audit: $e');
        }
      }

      // 7. REVERSE JOURNAL ENTRIES (Acid Compliant)
      if (accountingService != null) {
        await accountingService!.reverseTransaction(
          userId: userId,
          sourceType: 'PAYMENT',
          sourceId: paymentId,
          reason: 'Payment Deleted',
          reversalDate: now,
        );
      }

      return true;
    }, 'deletePayment');
  }

  /// Update Bill Status (Generic Update)
  /// Used when specific fields need updates beyond just payment
  Future<RepositoryResult<bool>> updateBillStatus({
    required String billId,
    required String status,
    required double paidAmount,
    double? cashPaid,
    double? onlinePaid,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();
      // Fetch to get ownerId if needed, but assuming calling context knows or we just update
      final entity = await (database.select(
        database.bills,
      )..where((t) => t.id.equals(billId))).getSingleOrNull();
      if (entity == null) throw Exception('Bill not found');

      final updates = BillsCompanion(
        status: Value(status),
        paidAmount: Value(paidAmount),
        cashPaid: cashPaid != null ? Value(cashPaid) : const Value.absent(),
        onlinePaid: onlinePaid != null
            ? Value(onlinePaid)
            : const Value.absent(),
        updatedAt: Value(now),
        isSynced: const Value(false),
      );

      await (database.update(
        database.bills,
      )..where((t) => t.id.equals(billId))).write(updates);

      // Queue sync
      final payload = {
        'status': status,
        'paidAmount': paidAmount,
        'updatedAt': now.toIso8601String(),
      };
      if (cashPaid != null) payload['cashPaid'] = cashPaid;
      if (onlinePaid != null) payload['onlinePaid'] = onlinePaid;

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: entity.userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: billId,
          payload: payload,
        ),
      );

      return true;
    }, 'updateBillStatus');
  }

  // ============================================
  // CORRECTION REQUESTS
  // ============================================

  /// Create a correction request for a bill
  Future<RepositoryResult<bool>> createCorrectionRequest({
    required String billId,
    required String customerId,
    required String message,
    required double billAmount,
  }) async {
    return await errorHandler.runSafe<bool>(() async {
      final now = DateTime.now();
      final requestId =
          '${now.millisecondsSinceEpoch}_${billId.substring(0, 4)}';

      await syncManager.enqueue(
        SyncQueueItem.create(
          userId: customerId,
          operationType: SyncOperationType.create,
          targetCollection: 'bill_corrections',
          documentId: requestId,
          payload: {
            'billId': billId,
            'customerId': customerId,
            'message': message,
            'billAmount': billAmount,
            'createdAt': now.toIso8601String(),
            'status': 'PENDING',
            '_targetPath':
                'customers/$customerId/bills/$billId/corrections/$requestId',
          },
        ),
      );

      return true;
    }, 'createCorrectionRequest');
  }

  // ============================================
  // HELPERS
  // ============================================

  Bill _entityToBill(BillEntity e) {
    List<BillItem> items = [];
    try {
      final decoded = jsonDecode(e.itemsJson) as List;
      items = decoded
          .map((i) => BillItem.fromMap(i as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    return Bill(
      id: e.id,
      ownerId: e.userId,
      invoiceNumber: e.invoiceNumber,
      customerId: e.customerId ?? '',
      customerName: e.customerName ?? '',
      // customerPhone: '', // Not stored in Bills table
      // customerAddress: '', // Not stored in Bills table
      date: e.billDate,
      items: items,
      subtotal: e.subtotal,
      totalTax: e.taxAmount, // Mapping taxAmount -> totalTax
      grandTotal: e.grandTotal,
      paidAmount: e.paidAmount,
      cashPaid: e.cashPaid,
      onlinePaid: e.onlinePaid,
      status: e.status,
      paymentType: e.paymentMode ?? 'Cash',
      discountApplied:
          e.discountAmount, // Mapping discountAmount -> discountApplied
      source: e.source,
      businessType: e.businessType,
      businessId: e.businessId,
      serviceCharge: e.serviceCharge,
      updatedAt: e.updatedAt,
      attendantId: e.attendantId,
    );
  }

  // ============================================
  // ANALYTICS & INSIGHTS (LOCAL)
  // ============================================

  /// Get today's summary stats
  Future<RepositoryResult<Map<String, dynamic>>> getTodaySummary(
    String userId,
  ) async {
    return await errorHandler.runSafe<Map<String, dynamic>>(() async {
      final stats = await database.getDashboardStats(userId);

      // Calculate profit using actual COGS data from database
      // This uses getTodayProfit() which calculates: Sales Revenue - Cost of Goods Sold
      // based on stock movements and product cost prices at time of sale.

      double totalSales = stats['todaySales'] ?? 0.0;
      double totalProfit = await database.getTodayProfit(userId);

      // Calculate actual items sold count from today's bills
      int itemsSoldCount = 0;
      final todayBillsCount = stats['todayBillsCount'] as int? ?? 0;
      if (todayBillsCount > 0) {
        // Query bill items for today's bills
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        itemsSoldCount =
            await database.getTodayItemsSoldCount(userId, today) ?? 0;
      }

      return {
        'total_sales': totalSales,
        'profit_loss': totalProfit,
        'items_sold_count': itemsSoldCount,
        'profit_status': totalProfit > 0 ? 'Healthy' : 'Lookout',
        'pending_bills': stats['totalDues'] ?? 0.0,
      };
    }, 'getTodaySummary');
  }

  /// Get Purchase vs Sale stats
  Future<RepositoryResult<Map<String, dynamic>>> getPurchaseVsSaleStats(
    String userId,
  ) async {
    return await errorHandler.runSafe<Map<String, dynamic>>(() async {
      final stats = await database.getDashboardStats(userId);
      // We need actual purchase data.
      // Since PurchaseOrders table exists, we should query it.
      // For now, we will return Sales data and 0 for purchases
      // UNTIL PurchaseRepository is fully audited/linked.
      // (Step 2 of Audit will fix Purchase flow).

      return {
        'sale_amount': stats['monthlySales'] ?? 0.0,
        // FIXED: Linked to Actual Purchase Orders
        'purchase_amount': stats['monthlyPurchaseAmount'] ?? 0.0,
      };
    }, 'getPurchaseVsSaleStats');
  }

  /// Soft delete a bill with STOCK REVERSAL
  ///
  /// CRITICAL FIX: This method now:
  /// 1. RESTORES STOCK for all items in the bill
  /// 2. Reverses customer balance updates
  /// 3. Creates audit trail with reason
  Future<RepositoryResult<void>> deleteBill(
    String billId,
    String userId,
  ) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // ============================================================
      // TASK 5.3: GRACE-PERIOD GATE (Locked)
      // ============================================================
      // While Locked, all record editing/deletion is blocked until
      // reactivation completes (Req 7.13).
      if (GracePeriodGate.instance.isLocked) {
        throw Exception(GracePeriodGate.lockedWriteBlockedReason);
      }

      // ============================================================
      // TASK 18.2: READ-ONLY FORENSIC MODE (Local_Store tamper — Req 17.12)
      // ============================================================
      if (StoreForensicGate.instance.isWriteBlocked) {
        throw Exception(StoreForensicGate.writeBlockedReason);
      }

      // ============================================================
      // GAP-2 PATCH: Period Lock Check (Audit Compliance)
      // ============================================================
      // Block deletion if the bill date falls in a locked period.
      // Must fetch bill first to get the date for period check.
      // ============================================================
      if (accountingService != null) {
        final billForCheck = await (database.select(
          database.bills,
        )..where((t) => t.id.equals(billId))).getSingleOrNull();

        if (billForCheck != null) {
          try {
            final isLocked = await accountingService!.isPeriodLocked(
              userId: userId,
              date: billForCheck.billDate,
            );
            if (isLocked) {
              throw Exception(
                'Cannot delete bill: Accounting period for ${billForCheck.billDate.month}/${billForCheck.billDate.year} is locked. '
                'Contact your accountant to unlock the period.',
              );
            }
          } catch (e) {
            if (e.toString().contains('Cannot delete bill')) rethrow;
            debugPrint('[PERIOD_LOCK] Check failed, allowing deletion: $e');
          }
        }
      }

      await database.transaction(() async {
        // 1. Fetch the bill to get amounts and items for reversal
        final bill = await (database.select(
          database.bills,
        )..where((t) => t.id.equals(billId))).getSingleOrNull();

        if (bill == null) {
          throw Exception('Bill not found: $billId');
        }

        // 2. Parse items for stock restoration
        List<BillItem> items = [];
        try {
          final decoded = jsonDecode(bill.itemsJson) as List;
          items = decoded
              .map((i) => BillItem.fromMap(i as Map<String, dynamic>))
              .toList();
        } catch (_) {
          debugPrint('Failed to parse bill items for stock restoration');
        }

        // 3. STOCK RESTORATION - Restore stock for each item
        if (inventoryService != null && items.isNotEmpty) {
          for (final item in items) {
            if (item.productId.isNotEmpty && item.qty > 0) {
              await inventoryService!.addStockMovement(
                userId: userId,
                productId: item.productId,
                type: 'IN',
                reason: 'BILL_DELETE_REVERSAL',
                quantity: item.qty,
                referenceId: billId,
                description:
                    'Stock restored due to bill deletion: ${bill.invoiceNumber}',
                createdBy: 'SYSTEM',
              );
            }
          }
        }

        // 4. Reverse customer balance if applicable
        if (bill.customerId != null && bill.customerId!.isNotEmpty) {
          final customer = await (database.select(
            database.customers,
          )..where((t) => t.id.equals(bill.customerId!))).getSingleOrNull();

          if (customer != null) {
            // Reverse the balance updates made during bill creation
            // totalBilled -= grandTotal
            // totalDues -= (grandTotal - paidAmount)
            final reversedTotalBilled = (customer.totalBilled - bill.grandTotal)
                .clamp(0.0, double.infinity);
            final reversedTotalDues =
                (customer.totalDues - (bill.grandTotal - bill.paidAmount))
                    .clamp(0.0, double.infinity);

            await (database.update(
              database.customers,
            )..where((t) => t.id.equals(bill.customerId!))).write(
              CustomersCompanion(
                totalBilled: Value(reversedTotalBilled),
                totalDues: Value(reversedTotalDues),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            // Queue customer sync
            await syncManager.enqueue(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'customers',
                documentId: bill.customerId!,
                payload: {
                  'totalBilled': reversedTotalBilled,
                  'totalDues': reversedTotalDues,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }

        // 5. Mark bill as deleted locally
        await (database.update(
          database.bills,
        )..where((t) => t.id.equals(billId))).write(
          BillsCompanion(
            deletedAt: Value(now),
            isSynced: const Value(false),
            updatedAt: Value(now),
          ),
        );

        // 6. Queue bill deletion for sync
        await syncManager.enqueue(
          SyncQueueItem.create(
            userId: userId,
            operationType: SyncOperationType.delete,
            targetCollection: 'bills',
            documentId: billId,
            payload: {'deletedAt': now.toIso8601String()},
          ),
        );

        // 7. DAYBOOK REVERSAL - Reverse the sale from daybook (non-blocking)
        if (dayBookService != null) {
          try {
            final isCashSale = bill.paymentMode?.toUpperCase() == 'CASH';
            await dayBookService!.recordSaleRealtime(
              businessId: userId,
              saleDate: bill.billDate,
              amount: -bill.grandTotal, // Negative = reversal
              isCashSale: isCashSale,
              cgst: 0, // Tax reversal handled via accounting entries
              sgst: 0,
              igst: 0,
            );
          } catch (e) {
            debugPrint('[DAYBOOK] Reversal failed for bill delete: $e');
            // Non-blocking - daybook can be reconciled later
          }
        }

        // 8. Audit Log

        if (auditService != null) {
          try {
            auditService!.logInvoiceDeletion(
              userId,
              billId,
              'User Deleted - Stock Restored',
            );
          } catch (e) {
            debugPrint('Failed to log deletion audit: $e');
          }
        }

        // 8. REVERSE JOURNAL ENTRIES (Acid Compliant)
        if (accountingService != null) {
          await accountingService!.reverseTransaction(
            userId: userId,
            sourceType: 'BILL',
            sourceId: billId,
            reason: 'Bill Deleted',
            reversalDate: now,
          );
        }
      });
    }, 'deleteBill');
  }

  // ============================================================
  // PHARMACY COMPLIANCE VALIDATION
  // ============================================================
  // Validates bill items for pharmacy/wholesale compliance.
  // Called at the start of createBill() before any DB operations.
  //
  // BACKWARD COMPATIBLE:
  // - Only blocks if expiryDate is set AND expired
  // - Only enforces batch/expiry for pharmacy/wholesale types
  // - Other business types are NOT affected
  // ============================================================

  /// Validates bill items for pharmacy compliance
  ///
  /// Throws [PharmacyComplianceException] if:
  /// - Any item has an expired expiryDate (all business types)
  /// - Pharmacy/Wholesale items missing batch number
  /// - Pharmacy/Wholesale items missing expiry date
  /// - A scheduled drug (H/H1/X) is sold without a captured prescription id
  ///   (`MISSING_PRESCRIPTION`, Requirements 7.5, 7.6)
  /// - Any pharmacy line item is sold above its MRP ceiling
  ///   (`MRP_CEILING_VIOLATION`, Requirements 8.3, 8.4)
  ///
  /// This runs BEFORE any database write, so a thrown exception leaves the bill
  /// unsaved with all in-progress content retained.
  Future<void> _validatePharmacyCompliance(Bill bill) async {
    // Determine business type from bill
    final businessType = BusinessType.values.firstWhere(
      (t) => t.name == bill.businessType,
      orElse: () => BusinessType.other,
    );

    // Use centralized validation service (expiry, batch, prescription).
    // The prescription rule rejects scheduled-drug bills lacking a non-empty
    // prescriptionId with MISSING_PRESCRIPTION (R7.6) and accepts those that
    // carry one (R7.5).
    final validator = PharmacyValidationService();

    try {
      validator.validateBillItems(
        bill.items,
        businessType,
        prescriptionId: bill.prescriptionId,
      );
    } on PharmacyComplianceException catch (e) {
      // Log the compliance violation for audit
      debugPrint(
        '[PHARMACY_COMPLIANCE] Blocked sale: ${e.code} - ${e.message}',
      );
      rethrow;
    }

    // ============================================================
    // PHARMACY MRP CEILING (Requirements 8.3, 8.4)
    // ============================================================
    // Pharmacy-gated: only the pharmacy/medical_store path runs this check, so
    // the other 18 verticals stay behaviourally unchanged (R5.3).
    //
    // No medicine may be sold above its MRP. Every line item is validated; on
    // ANY violation the whole bill is rejected (left unsaved) and the offending
    // line items are listed back to the caller (R8.4).
    if (bill.businessType == 'pharmacy' ||
        bill.businessType == 'medical_store') {
      final mrpResult = MrpEnforcementValidator.validateBill(
        bill,
        await _buildMrpLookup(bill),
      );

      if (!mrpResult.isCompliant) {
        final violators = [
          for (final v in mrpResult.violations)
            {
              'productId': v.productId,
              'itemName': v.itemName,
              'sellingPaise': v.sellingPaise,
              'mrpPaise': v.mrpPaise,
              'message': v.message,
            },
        ];
        debugPrint(
          '[PHARMACY_COMPLIANCE] Blocked sale: MRP_CEILING_VIOLATION - '
          '${mrpResult.violations.length} item(s) above MRP',
        );
        throw PharmacyComplianceException.mrpCeilingViolation(
          violators: violators,
        );
      }
    }
  }

  /// Builds an [MrpLookup] for [bill] by reading each line item's MRP from its
  /// linked product batch (`ProductBatches.mrp`, rupees) and converting it to
  /// integer paise via the shared [Paise] helper (round-half-up, R2).
  ///
  /// MRP is a batch-level attribute (the Products table carries none), so the
  /// lookup is keyed by `BillItem.batchId`. An item without a resolvable batch
  /// MRP (no batchId, missing batch, or a 0 MRP) resolves to an unknown MRP,
  /// which the validator treats as non-blocking.
  Future<MrpLookup> _buildMrpLookup(Bill bill) async {
    final batchIds = bill.items
        .map((i) => i.batchId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final mrpPaiseByBatchId = <String, int?>{};
    if (batchIds.isNotEmpty) {
      final rows = await (database.select(
        database.productBatches,
      )..where((t) => t.id.isIn(batchIds))).get();
      for (final batch in rows) {
        mrpPaiseByBatchId[batch.id] = Paise.fromRupees(batch.mrp);
      }
    }

    return MrpLookup((item) {
      final id = item.batchId;
      if (id == null || id.isEmpty) return null;
      return mrpPaiseByBatchId[id];
    });
  }

  // The _allocateBatchesForFefo method has been removed as its logic is now
  // encapsulated within BatchAllocationService and will be called from createBill.
}
