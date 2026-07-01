import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../features/revenue/models/revenue_models.dart';
import '../database/app_database.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_state_machine.dart';
import '../error/error_handler.dart';
import '../../features/inventory/services/inventory_service.dart';
import '../../features/accounting/accounting.dart' as acc;
import '../../services/daybook_service.dart';
import '../../features/service/data/repositories/imei_serial_repository.dart';
import '../../features/service/models/imei_serial.dart';

class RevenueRepository {
  final AppDatabase db;
  final SyncManager syncManager;
  final ErrorHandler errorHandler;
  final InventoryService? inventoryService;
  final acc.AccountingService? accountingService;
  final DayBookService? dayBookService;
  final _uuid = const Uuid();

  RevenueRepository({
    required this.db,
    required this.syncManager,
    required this.errorHandler,
    this.inventoryService,
    this.accountingService,
    this.dayBookService,
  });

  // ==================== RECEIPTS ====================

  /// Add a receipt (payment received from customer)
  ///
  /// CRITICAL VALIDATION: Receipt must be either:
  /// - Linked to a bill (billId provided), OR
  /// - Marked as advance payment (isAdvancePayment = true)
  ///
  /// This prevents orphan receipts that aren't linked to invoices,
  /// which could cause ledger mismatches.
  Future<RepositoryResult<String>> addReceipt({
    required String userId,
    required String customerId,
    required double amount,
    String? billId,
    String? paymentMode,
    String? notes,
    bool isAdvancePayment = false,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      // VALIDATION: Receipt must be linked to bill OR marked as advance
      if ((billId == null || billId.isEmpty) && !isAdvancePayment) {
        throw Exception(
          'Receipt must be linked to a bill OR marked as advance payment. '
          'Orphan receipts could cause ledger mismatches. '
          'Set isAdvancePayment=true for advance receipts.',
        );
      }

      final id = _uuid.v4();
      final now = DateTime.now();

      final companion = ReceiptsCompanion.insert(
        id: id,
        userId: userId,
        customerId: Value(customerId),
        amount: amount,
        billId: Value(billId),
        paymentMode: Value(paymentMode ?? 'Cash'),
        notes: Value(notes),
        isAdvancePayment: Value(isAdvancePayment),
        date: now,
        createdAt: now,
      );

      await db.into(db.receipts).insert(companion);

      // Queue for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.create,
          targetCollection: 'receipts',
          documentId: id,
          payload: {
            'id': id,
            'userId': userId,
            'customerId': customerId,
            'amount': amount,
            'billId': billId,
            'paymentMode': paymentMode,
            'notes': notes,
            'isAdvancePayment': isAdvancePayment,
            'date': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );

      // 4. Create Accounting Entry (Journal)
      if (accountingService != null) {
        try {
          await accountingService!.createReceiptEntry(
            userId: userId,
            paymentId: id, // Use the receipt ID as payment ID
            customerId: customerId,
            customerName: '', // Service will resolve name if needed
            amount: amount,
            paymentDate: now,
            paymentMode: paymentMode ?? 'Cash',
            billId: billId,
            // notes: notes, // If supported by service
          );
        } catch (e) {
          debugPrint('Accounting entry failed for receipt: $e');
          // Non-blocking
        }
      }

      return id;
    }, 'addReceipt');
  }

  Stream<List<Receipt>> watchReceipts(String userId) {
    return (db.select(
      db.receipts,
    )..where((t) => t.userId.equals(userId))).watch().map(
      (rows) => rows
          .map(
            (r) => Receipt(
              id: r.id,
              ownerId: r.userId,
              customerId: r.customerId ?? '',
              customerName: r.customerName ?? '',
              amount: r.amount,
              paymentMode: r.paymentMode ?? 'Cash',
              notes: r.notes ?? '',
              date: r.date,
              createdAt: r.createdAt,
              isAdvancePayment: r.isAdvancePayment,
              billId: r.billId,
            ),
          )
          .toList(),
    );
  }

  /// Get total collections (receipts) for a given user and date range
  Future<RepositoryResult<double>> getTotalCollections({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    return await errorHandler.runSafe<double>(() async {
      final receipts =
          await (db.select(db.receipts)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.date.isBiggerOrEqualValue(from) &
                    t.date.isSmallerOrEqualValue(to),
              ))
              .get();

      double total = 0;
      for (final r in receipts) {
        total += r.amount;
      }
      return total;
    }, 'getTotalCollections');
  }

  // ==================== PROFORMAS ====================

  Future<RepositoryResult<String>> addProforma({
    required String userId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    double taxAmount = 0,
    double discountAmount = 0,
    required double totalAmount,
    DateTime? validUntil,
    String? terms,
    String? notes,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final proformaNumber = 'PRO-${now.millisecondsSinceEpoch}';

      final companion = ProformasCompanion.insert(
        id: id,
        userId: userId,
        amount: totalAmount, // Required field
        customerId: Value(customerId),
        proformaNumber: Value(proformaNumber),
        subtotal: Value(subtotal),
        taxAmount: Value(taxAmount),
        discountAmount: Value(discountAmount),
        totalAmount: Value(totalAmount),
        validUntil: Value(validUntil),
        itemsJson: Value(jsonEncode(items)),
        terms: Value(terms),
        notes: Value(notes),
        date: now,
        createdAt: now,
      );

      await db.into(db.proformas).insert(companion);

      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.create,
          targetCollection: 'proformas',
          documentId: id,
          payload: {
            'id': id,
            'userId': userId,
            'customerId': customerId,
            'proformaNumber': proformaNumber,
            'items': items,
            'subtotal': subtotal,
            'taxAmount': taxAmount,
            'discountAmount': discountAmount,
            'totalAmount': totalAmount,
            'validUntil': validUntil?.toIso8601String(),
            'terms': terms,
            'notes': notes,
            'date': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );

      return id;
    }, 'addProforma');
  }

  Stream<List<ProformaInvoice>> watchProformas(String userId) {
    return (db.select(
      db.proformas,
    )..where((t) => t.userId.equals(userId))).watch().map(
      (rows) => rows
          .map(
            (r) => ProformaInvoice(
              id: r.id,
              ownerId: r.userId,
              customerId: r.customerId ?? '',
              customerName: r.customerName ?? '',
              proformaNumber: r.proformaNumber ?? '',
              items: r.itemsJson != null
                  ? (jsonDecode(r.itemsJson!) as List)
                        .map((i) => ProformaItem.fromMap(i))
                        .toList()
                  : [],
              subtotal: r.subtotal,
              taxAmount: r.taxAmount,
              discountAmount: r.discountAmount,
              totalAmount: r.totalAmount,
              validUntil:
                  r.validUntil ?? DateTime.now().add(const Duration(days: 30)),
              status: ProformaStatus.values.firstWhere(
                (e) => e.name.toUpperCase() == r.status,
                orElse: () => ProformaStatus.draft,
              ),
              terms: r.terms ?? '',
              notes: r.notes ?? '',
              date: r.date,
              createdAt: r.createdAt,
            ),
          )
          .toList(),
    );
  }

  // ==================== BOOKINGS ====================

  Future<RepositoryResult<String>> addBooking({
    required String userId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    double advanceAmount = 0,
    double balanceAmount = 0,
    DateTime? deliveryDate,
    String? deliveryAddress,
    String? notes,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final bookingNumber = 'BK-${now.millisecondsSinceEpoch}';

      final companion = BookingsCompanion.insert(
        id: id,
        userId: userId,
        amount: totalAmount, // Required field
        customerId: Value(customerId),
        bookingNumber: Value(bookingNumber),
        totalAmount: Value(totalAmount),
        advanceAmount: Value(advanceAmount),
        balanceAmount: Value(balanceAmount),
        deliveryDate: Value(deliveryDate),
        itemsJson: Value(jsonEncode(items)),
        deliveryAddress: Value(deliveryAddress),
        notes: Value(notes),
        date: now,
        createdAt: now,
      );

      await db.into(db.bookings).insert(companion);

      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.create,
          targetCollection: 'bookings',
          documentId: id,
          payload: {
            'id': id,
            'userId': userId,
            'customerId': customerId,
            'bookingNumber': bookingNumber,
            'items': items,
            'totalAmount': totalAmount,
            'advanceAmount': advanceAmount,
            'balanceAmount': balanceAmount,
            'deliveryDate': deliveryDate?.toIso8601String(),
            'deliveryAddress': deliveryAddress,
            'notes': notes,
            'date': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );

      return id;
    }, 'addBooking');
  }

  Stream<List<BookingOrder>> watchBookings(String userId) {
    return (db.select(
      db.bookings,
    )..where((t) => t.userId.equals(userId))).watch().map(
      (rows) => rows
          .map(
            (r) => BookingOrder(
              id: r.id,
              ownerId: r.userId,
              customerId: r.customerId ?? '',
              customerName: r.customerName ?? '',
              bookingNumber: r.bookingNumber ?? '',
              items: r.itemsJson != null
                  ? (jsonDecode(r.itemsJson!) as List)
                        .map((i) => BookingItem.fromMap(i))
                        .toList()
                  : [],
              totalAmount: r.totalAmount,
              advanceAmount: r.advanceAmount,
              balanceAmount: r.balanceAmount,
              deliveryDate: r.deliveryDate ?? DateTime.now(),
              deliveryAddress: r.deliveryAddress ?? '',
              status: BookingStatus.values.firstWhere(
                (e) => e.name.toUpperCase() == r.status,
                orElse: () => BookingStatus.pending,
              ),
              notes: r.notes ?? '',
              date: r.date,
              createdAt: r.createdAt,
            ),
          )
          .toList(),
    );
  }

  /// Update booking status with AUTO-CONVERSION to Invoice
  ///
  /// IMPROVEMENT: When status changes to DELIVERED, automatically:
  /// 1. Creates a Bill from the booking items
  /// 2. Sets paidAmount = advanceAmount (already received)
  /// 3. Updates booking with convertedBillId
  /// 4. Changes status to CONVERTED
  ///
  /// This ensures every delivered booking has a proper invoice for:
  /// - GST compliance
  /// - Customer ledger accuracy
  /// - Financial reporting
  Future<RepositoryResult<void>> updateBookingStatus({
    required String userId,
    required String bookingId,
    required BookingStatus status,
    bool autoConvertOnDelivery = true,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      // AUTO-CONVERSION: When marked as delivered, create invoice
      if (status == BookingStatus.delivered && autoConvertOnDelivery) {
        // Get the booking details
        final booking = await (db.select(
          db.bookings,
        )..where((t) => t.id.equals(bookingId))).getSingleOrNull();

        if (booking != null && booking.convertedBillId == null) {
          // Create Bill from booking
          final billId = _uuid.v4();

          final invoiceNumber = 'INV-${now.millisecondsSinceEpoch}';

          await db
              .into(db.bills)
              .insert(
                BillsCompanion.insert(
                  id: billId,
                  userId: userId,
                  invoiceNumber: invoiceNumber,
                  customerId: Value(booking.customerId ?? ''),
                  customerName: Value(booking.customerName ?? ''),
                  billDate: now,
                  subtotal: Value(booking.totalAmount),
                  grandTotal: Value(booking.totalAmount),
                  paidAmount: Value(booking.advanceAmount), // Already paid
                  status: Value(
                    booking.advanceAmount >= booking.totalAmount
                        ? 'Paid'
                        : 'Partial',
                  ),
                  paymentMode: const Value('Cash'),
                  source: const Value('BOOKING_CONVERSION'),
                  itemsJson: booking.itemsJson ?? '[]',
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // Update booking as CONVERTED with bill reference
          await (db.update(
            db.bookings,
          )..where((t) => t.id.equals(bookingId))).write(
            BookingsCompanion(
              status: const Value('CONVERTED'),
              convertedBillId: Value(billId),
              isSynced: const Value(false),
            ),
          );

          // Queue booking sync
          await syncManager.enqueue(
            SyncQueueItem.create(
              operationType: SyncOperationType.update,
              targetCollection: 'bookings',
              documentId: bookingId,
              payload: {
                'status': 'CONVERTED',
                'convertedBillId': billId,
                'updatedAt': now.toIso8601String(),
              },
              userId: userId,
            ),
          );

          // Queue bill sync
          await syncManager.enqueue(
            SyncQueueItem.create(
              operationType: SyncOperationType.create,
              targetCollection: 'bills',
              documentId: billId,
              payload: {
                'id': billId,
                'userId': userId,
                'invoiceNumber': invoiceNumber,
                'customerId': booking.customerId,
                'customerName': booking.customerName,
                'grandTotal': booking.totalAmount,
                'paidAmount': booking.advanceAmount,
                'source': 'BOOKING_CONVERSION',
                'bookingId': bookingId,
                'bookingNumber': booking.bookingNumber,
                'createdAt': now.toIso8601String(),
              },
              userId: userId,
            ),
          );

          debugPrint(
            '[BOOKING→INVOICE] Auto-converted booking $bookingId to bill $billId',
          );
          return; // Exit early - conversion done
        }
      }

      // Standard status update (no auto-conversion)
      await (db.update(
        db.bookings,
      )..where((t) => t.id.equals(bookingId))).write(
        BookingsCompanion(
          status: Value(status.name.toUpperCase()),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.update,
          targetCollection: 'bookings',
          documentId: bookingId,
          payload: {
            'status': status.name.toUpperCase(),
            'updatedAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );
    }, 'updateBookingStatus');
  }

  /// Get a single booking by ID
  Future<RepositoryResult<BookingOrder?>> getBookingById(
    String bookingId,
  ) async {
    return await errorHandler.runSafe<BookingOrder?>(() async {
      final row = await (db.select(
        db.bookings,
      )..where((t) => t.id.equals(bookingId))).getSingleOrNull();

      if (row == null) return null;

      return BookingOrder(
        id: row.id,
        ownerId: row.userId,
        customerId: row.customerId ?? '',
        customerName: row.customerName ?? '',
        bookingNumber: row.bookingNumber ?? '',
        items: row.itemsJson != null
            ? (jsonDecode(row.itemsJson!) as List)
                  .map((i) => BookingItem.fromMap(i))
                  .toList()
            : [],
        totalAmount: row.totalAmount,
        advanceAmount: row.advanceAmount,
        balanceAmount: row.balanceAmount,
        deliveryDate: row.deliveryDate ?? DateTime.now(),
        deliveryAddress: row.deliveryAddress ?? '',
        status: BookingStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == row.status,
          orElse: () => BookingStatus.pending,
        ),
        notes: row.notes ?? '',
        date: row.date,
        createdAt: row.createdAt,
      );
    }, 'getBookingById');
  }

  /// Get a single proforma by ID
  Future<RepositoryResult<ProformaInvoice?>> getProformaById(
    String proformaId,
  ) async {
    return await errorHandler.runSafe<ProformaInvoice?>(() async {
      final row = await (db.select(
        db.proformas,
      )..where((t) => t.id.equals(proformaId))).getSingleOrNull();

      if (row == null) return null;

      return ProformaInvoice(
        id: row.id,
        ownerId: row.userId,
        customerId: row.customerId ?? '',
        customerName: row.customerName ?? '',
        proformaNumber: row.proformaNumber ?? '',
        items: row.itemsJson != null
            ? (jsonDecode(row.itemsJson!) as List)
                  .map((i) => ProformaItem.fromMap(i))
                  .toList()
            : [],
        subtotal: row.subtotal,
        taxAmount: row.taxAmount,
        discountAmount: row.discountAmount,
        totalAmount: row.totalAmount,
        validUntil:
            row.validUntil ?? DateTime.now().add(const Duration(days: 30)),
        status: ProformaStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == row.status,
          orElse: () => ProformaStatus.draft,
        ),
        terms: row.terms ?? '',
        notes: row.notes ?? '',
        date: row.date,
        createdAt: row.createdAt,
      );
    }, 'getProformaById');
  }

  /// Update proforma status to converted
  Future<RepositoryResult<void>> markProformaConverted({
    required String userId,
    required String proformaId,
    required String billId,
  }) async {
    return await errorHandler.runSafe<void>(() async {
      final now = DateTime.now();

      await (db.update(
        db.proformas,
      )..where((t) => t.id.equals(proformaId))).write(
        ProformasCompanion(
          status: const Value('CONVERTED'),
          isSynced: const Value(false),
        ),
      );

      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.update,
          targetCollection: 'proformas',
          documentId: proformaId,
          payload: {
            'status': 'CONVERTED',
            'convertedBillId': billId,
            'updatedAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );
    }, 'markProformaConverted');
  }

  /// Create a return inward with COMPLETE INVENTORY & LEDGER UPDATES
  ///
  /// CRITICAL FIX: This method now:
  /// 1. Creates return inward record with credit note number
  /// 2. RESTORES STOCK for all returned items (IN movement)
  /// 3. UPDATES CUSTOMER LEDGER (reduces totalBilled and totalDues)
  /// 4. Creates ACCOUNTING REVERSAL entry for audit trail
  /// 5. Updates DAYBOOK with return transaction
  ///
  /// This ensures returns are fully reflected in:
  /// - Inventory (stock increased)
  /// - Customer ledger (receivable reduced)
  /// - Financial reports (sales reduced)
  /// - GSTR (automatic on next generation)
  Future<RepositoryResult<String>> addReturnInward({
    required String userId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double totalReturnAmount,
    String? billId,
    String? billNumber,
    String? reason,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final creditNoteNumber = 'CN-${now.millisecondsSinceEpoch}';

      // ---------------------------------------------------------------
      // SERIAL VALIDATION FOR ELECTRONICS DEVICE RETURNS (Phase 7, Task
      // 23.1 — Requirement 2.22). For items that carry a serial number,
      // validate against IMEISerials: the serial must exist, be
      // tenant-scoped (userId), and have status == SOLD. On accept,
      // transition the unit's status to RETURNED. If serial is blank,
      // invalid, not-found, or not-sold, reject the return item with an
      // error. Generic returns for other verticals (items without serial)
      // pass through unchanged (Preservation 3.7).
      // ---------------------------------------------------------------
      final imeiRepo = IMEISerialRepository(db);
      for (final item in items) {
        final serial =
            (item['serialNo'] as String?)?.trim() ??
            (item['imeiOrSerial'] as String?)?.trim() ??
            '';
        final isDeviceLine =
            item['isDevice'] == true ||
            item['hasSerial'] == true ||
            serial.isNotEmpty;

        if (isDeviceLine && serial.isNotEmpty) {
          // Look up the serial in IMEISerials (tenant-scoped)
          final imeiRecord = await imeiRepo.getByNumber(userId, serial);
          if (imeiRecord == null) {
            throw Exception(
              'Return rejected: serial "$serial" not found in inventory for this tenant.',
            );
          }
          if (imeiRecord.status != IMEISerialStatus.sold) {
            throw Exception(
              'Return rejected: serial "$serial" has status '
              '"${imeiRecord.status.value}" — only SOLD units can be returned.',
            );
          }
        } else if (isDeviceLine && serial.isEmpty) {
          throw Exception(
            'Return rejected: device line requires a valid serial number.',
          );
        }
      }

      // After validation passes, mark returned serials as RETURNED
      for (final item in items) {
        final serial =
            (item['serialNo'] as String?)?.trim() ??
            (item['imeiOrSerial'] as String?)?.trim() ??
            '';
        final isDeviceLine =
            item['isDevice'] == true ||
            item['hasSerial'] == true ||
            serial.isNotEmpty;

        if (isDeviceLine && serial.isNotEmpty) {
          final imeiRecord = await imeiRepo.getByNumber(userId, serial);
          if (imeiRecord != null) {
            await imeiRepo.markAsReturned(imeiRecord.id, userId: userId);
          }
        }
      }

      // Execute all updates in a transaction for atomicity
      final collectedSyncOps = await db.transaction<List<SyncQueueItem>>(() async {
        final syncOps = <SyncQueueItem>[];

        // 1. Create Return Inward Record
        final companion = ReturnInwardsCompanion.insert(
          id: id,
          userId: userId,
          amount: totalReturnAmount,
          customerId: Value(customerId),
          billId: Value(billId),
          billNumber: Value(billNumber),
          creditNoteNumber: Value(creditNoteNumber),
          totalReturnAmount: Value(totalReturnAmount),
          reason: Value(reason),
          itemsJson: Value(jsonEncode(items)),
          status: const Value('APPROVED'), // Mark as approved immediately
          date: now,
          createdAt: now,
        );

        await db.into(db.returnInwards).insert(companion);

        // 2. STOCK RESTORATION - Add stock back for each returned item
        if (inventoryService != null) {
          for (final item in items) {
            final productId = item['productId'] as String?;
            final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
            final batchId = item['batchId'] as String?;
            final batchNumber = item['batchNumber'] as String?;

            if (productId != null && productId.isNotEmpty && quantity > 0) {
              try {
                await inventoryService!.addStockMovement(
                  userId: userId,
                  productId: productId,
                  type: 'IN',
                  reason: 'RETURN_INWARD',
                  quantity: quantity,
                  referenceId: id,
                  description:
                      'Stock restored from return: $creditNoteNumber${billNumber != null ? ' (Original: $billNumber)' : ''}',
                  createdBy: 'SYSTEM',
                  batchId: batchId,
                  batchNumber: batchNumber,
                );
              } catch (e) {
                debugPrint(
                  '[RETURN_INWARD] Stock restoration failed for $productId: $e',
                );
                // Continue with other items - don't fail entire return
              }
            }
          }
        }

        // 3. CUSTOMER LEDGER UPDATE - Reduce receivable
        if (customerId.isNotEmpty) {
          final customer = await (db.select(
            db.customers,
          )..where((t) => t.id.equals(customerId))).getSingleOrNull();

          if (customer != null) {
            // Reduce totalBilled and totalDues by return amount
            final newTotalBilled = (customer.totalBilled - totalReturnAmount)
                .clamp(0.0, double.infinity);
            final newTotalDues = (customer.totalDues - totalReturnAmount).clamp(
              0.0,
              double.infinity,
            );

            await (db.update(
              db.customers,
            )..where((t) => t.id.equals(customerId))).write(
              CustomersCompanion(
                totalBilled: Value(newTotalBilled),
                totalDues: Value(newTotalDues),
                updatedAt: Value(now),
                isSynced: const Value(false),
              ),
            );

            // Queue customer sync
            syncOps.add(
              SyncQueueItem.create(
                userId: userId,
                operationType: SyncOperationType.update,
                targetCollection: 'customers',
                documentId: customerId,
                payload: {
                  'totalBilled': newTotalBilled,
                  'totalDues': newTotalDues,
                  'updatedAt': now.toIso8601String(),
                },
              ),
            );
          }
        }

        // 4. ACCOUNTING ENTRY - Create reversal/credit note entry
        if (accountingService != null) {
          try {
            await accountingService!.createReturnEntry(
              userId: userId,
              returnId: id,
              customerId: customerId.isNotEmpty ? customerId : 'CASH',
              customerName: '', // Will be resolved by accounting service
              amount: totalReturnAmount,
              returnDate: now,
              creditNoteNumber: creditNoteNumber,
              originalBillId: billId,
            );
          } catch (e) {
            debugPrint('[RETURN_INWARD] Accounting entry failed: $e');
            // Non-blocking - accounting can be reconciled later
          }
        }

        // 5. DAYBOOK UPDATE - Record return transaction
        if (dayBookService != null) {
          try {
            // Returns reduce sales, so we record as negative sale
            await dayBookService!.recordSaleRealtime(
              businessId: userId,
              saleDate: now,
              amount: -totalReturnAmount, // Negative = reduces sales
              isCashSale: true, // Will be adjusted based on original bill
              cgst: 0, // Tax reversal handled separately
              sgst: 0,
              igst: 0,
            );
          } catch (e) {
            debugPrint('[RETURN_INWARD] DayBook update failed: $e');
          }
        }

        return syncOps;
      });

      // Queue all collected sync operations after transaction commits
      for (final syncOp in collectedSyncOps) {
        await syncManager.enqueue(syncOp);
      }

      // Queue return inward for sync
      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.create,
          targetCollection: 'returnInwards',
          documentId: id,
          payload: {
            'id': id,
            'userId': userId,
            'customerId': customerId,
            'items': items,
            'totalReturnAmount': totalReturnAmount,
            'billId': billId,
            'billNumber': billNumber,
            'creditNoteNumber': creditNoteNumber,
            'reason': reason,
            'status': 'APPROVED',
            'date': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );

      return id;
    }, 'addReturnInward');
  }

  // ==================== DISPATCHES ====================

  Future<RepositoryResult<String>> addDispatch({
    required String userId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? billId,
    String? billNumber,
    String? vehicleNumber,
    String? driverName,
    String? driverPhone,
    String? deliveryAddress,
    String? notes,
  }) async {
    return await errorHandler.runSafe<String>(() async {
      final id = _uuid.v4();
      final now = DateTime.now();
      final dispatchNumber = 'DC-${now.millisecondsSinceEpoch}';

      final companion = DispatchesCompanion.insert(
        id: id,
        userId: userId,
        customerId: Value(customerId),
        billId: Value(billId),
        billNumber: Value(billNumber),
        dispatchNumber: Value(dispatchNumber),
        vehicleNumber: Value(vehicleNumber),
        driverName: Value(driverName),
        driverPhone: Value(driverPhone),
        deliveryAddress: Value(deliveryAddress),
        itemsJson: Value(jsonEncode(items)),
        notes: Value(notes),
        date: now,
        createdAt: now,
      );

      await db.into(db.dispatches).insert(companion);

      await syncManager.enqueue(
        SyncQueueItem.create(
          operationType: SyncOperationType.create,
          targetCollection: 'dispatches',
          documentId: id,
          payload: {
            'id': id,
            'userId': userId,
            'customerId': customerId,
            'items': items,
            'billId': billId,
            'billNumber': billNumber,
            'dispatchNumber': dispatchNumber,
            'vehicleNumber': vehicleNumber,
            'driverName': driverName,
            'driverPhone': driverPhone,
            'deliveryAddress': deliveryAddress,
            'notes': notes,
            'date': now.toIso8601String(),
            'createdAt': now.toIso8601String(),
          },
          userId: userId,
        ),
      );

      return id;
    }, 'addDispatch');
  }

  Stream<List<ReturnInward>> watchReturns(String userId) {
    return (db.select(
      db.returnInwards,
    )..where((t) => t.userId.equals(userId))).watch().map(
      (rows) => rows
          .map(
            (r) => ReturnInward(
              id: r.id,
              ownerId: r.userId,
              customerId: r.customerId ?? '',
              customerName: '', // Will be matched by UI or joined if needed
              billId: r.billId ?? '',
              billNumber: r.billNumber ?? '',
              items: r.itemsJson != null
                  ? (jsonDecode(r.itemsJson!) as List)
                        .map((i) => ReturnItem.fromMap(i))
                        .toList()
                  : [],
              totalReturnAmount: r.totalReturnAmount,
              reason: r.reason ?? '',
              creditNoteNumber: r.creditNoteNumber ?? '',
              status: ReturnStatus.values.firstWhere(
                (e) => e.name.toUpperCase() == r.status,
                orElse: () => ReturnStatus.pending,
              ),
              date: r.date,
              createdAt: r.createdAt,
            ),
          )
          .toList(),
    );
  }

  Stream<List<DispatchNote>> watchDispatches(String userId) {
    return (db.select(
      db.dispatches,
    )..where((t) => t.userId.equals(userId))).watch().map(
      (rows) => rows
          .map(
            (r) => DispatchNote(
              id: r.id,
              ownerId: r.userId,
              customerId: r.customerId ?? '',
              customerName: '', // Will be matched by UI or joined if needed
              billId: r.billId ?? '',
              billNumber: r.billNumber ?? '',
              dispatchNumber: r.dispatchNumber ?? '',
              items: r.itemsJson != null
                  ? (jsonDecode(r.itemsJson!) as List)
                        .map((i) => DispatchItem.fromMap(i))
                        .toList()
                  : [],
              vehicleNumber: r.vehicleNumber ?? '',
              driverName: r.driverName ?? '',
              driverPhone: r.driverPhone ?? '',
              deliveryAddress: r.deliveryAddress ?? '',
              status: DispatchStatus.values.firstWhere(
                (e) => e.name.toUpperCase() == r.status,
                orElse: () => DispatchStatus.pending,
              ),
              notes: r.notes ?? '',
              date: r.date,
              createdAt: r.createdAt,
            ),
          )
          .toList(),
    );
  }
}
