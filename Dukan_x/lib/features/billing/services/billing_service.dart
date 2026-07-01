import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../models/business_type.dart';
import '../../inventory/services/inventory_service.dart';
import '../../../core/error/error_handler.dart'; // Import ErrorHandler
import '../../service/data/repositories/imei_serial_repository.dart';
import '../../service/models/imei_serial.dart';
import '../../service/services/warranty_date_utils.dart';

class BillingService {
  final AppDatabase _db;
  final InventoryService _inventoryService;
  late final IMEISerialRepository _imeiRepository;

  BillingService(this._db, this._inventoryService) {
    _imeiRepository = IMEISerialRepository(_db);
  }

  /// Create a Bill with strict validation and atomic stock deduction
  Future<Result<String>> createBill({
    required BillEntity bill,
    required List<BillItemEntity> items,
  }) async {
    // Defensive Wrapper
    return runSafe(
      () async {
        return _db.transaction(() async {
          // 1. Validate Business Rules
          final validation = await _validateBillRules(bill, items);
          if (!validation.isSuccess) {
            throw validation.error!; // Will be caught by runSafe
          }

          // 2. Insert Bill Header
          await _db.insertBill(
            BillsCompanion(
              id: Value(bill.id),
              userId: Value(bill.userId),
              customerId: Value(bill.customerId),
              customerName: Value(bill.customerName),
              billDate: Value(bill.billDate),
              invoiceNumber: Value(bill.invoiceNumber),
              status: Value(bill.status),
              // ... Map other fields
              grandTotal: Value(bill.grandTotal),
              itemsJson: Value(bill.itemsJson),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
              businessType: Value(bill.businessType),
            ),
          );

          // 3. Insert Bill Items
          for (final item in items) {
            await _db
                .into(_db.billItems)
                .insert(
                  BillItemsCompanion(
                    id: Value(item.id),
                    billId: Value(bill.id),
                    productId: Value(item.productId),
                    productName: Value(item.productName),
                    quantity: Value(item.quantity),
                    unitPrice: Value(item.unitPrice),
                    totalAmount: Value(item.totalAmount),
                    // Business Specifics
                    batchId: Value(item.batchId),
                    imei: Value(item.imei),
                    createdAt: Value(DateTime.now()),
                  ),
                );

            // 4. Deduct Stock (Atomic)
            if (item.productId != null) {
              await _inventoryService.deductStockInTransaction(
                userId: bill.userId,
                productId: item.productId!,
                quantity: item.quantity,
                referenceId: bill.id,
                invoiceNumber: bill.invoiceNumber,
                date: bill.billDate,
                batchId: item.batchId,
              );
            }
          }

          // 5. Electronics: Create/link IMEISerials record for each device
          //    with a non-empty serial (warranty computation + serial inventory
          //    + serial-level stock status). The existing SKU stock deduction
          //    (step 4) is preserved unchanged.
          if (bill.businessType == 'electronics') {
            // Parse warrantyMonths per item from the bill's itemsJson blob,
            // keyed by the imei/serial value for matching.
            final warrantyMonthsBySerial = _parseWarrantyMonthsFromJson(
              bill.itemsJson,
            );

            for (final item in items) {
              final serial = item.imei;
              if (serial == null || serial.isEmpty) continue;
              if (item.productId == null) continue;

              // Look up warrantyMonths from itemsJson; fall back to 0
              final wMonths = warrantyMonthsBySerial[serial] ?? 0;

              // Compute warranty dates (task 11.1). Per design 2.11 the
              // expiry is `sale_date + warrantyMonths`; the warrantyEndDate
              // util returns the sale date unchanged when warrantyMonths == 0,
              // so a 0-month warranty persists an expiry equal to the sale date
              // (single source of truth) rather than a null.
              final wStartDate = bill.billDate;
              final wEndDate = warrantyEndDate(wStartDate, wMonths);

              // Generate RID-patterned id: {tenantId}-{timestamp_ms}-{uuid_v4_short}
              final now = DateTime.now();
              final uuidShort = const Uuid().v4().split('-').first;
              final rid =
                  '${bill.userId}-${now.millisecondsSinceEpoch}-$uuidShort';

              // Detect serial type (IMEI = 15 digits numeric; else serial)
              final serialType =
                  (serial.length == 15 && int.tryParse(serial) != null)
                  ? IMEISerialType.imei
                  : IMEISerialType.serial;

              // Create the IMEISerials record (task 11.2) with status SOLD
              // (task 11.3). This is the single point of truth for warranty
              // data feeding getImeiTrackingStatement.
              final imeiRecord = IMEISerial(
                id: rid,
                userId: bill.userId,
                productId: item.productId!,
                imeiOrSerial: serial,
                type: serialType,
                status: IMEISerialStatus.sold,
                billId: bill.id,
                customerId: bill.customerId,
                soldPrice: item.unitPrice,
                soldDate: bill.billDate,
                warrantyMonths: wMonths,
                warrantyStartDate: wStartDate,
                warrantyEndDate: wEndDate,
                isUnderWarranty: wMonths > 0,
                productName: item.productName,
                createdAt: now,
                updatedAt: now,
              );

              await _imeiRepository.createIMEISerial(imeiRecord);
            }
          }

          return bill.id;
        });
      },
      errorMessage: 'Failed to create bill',
      context: null,
    );
  }

  Future<Result<void>> _validateBillRules(
    BillEntity bill,
    List<BillItemEntity> items,
  ) async {
    final businessType = bill.businessType;

    // PHARMACY: Strict Expiry Check
    if (businessType == 'pharmacy' || businessType == 'medical_store') {
      for (final item in items) {
        if (item.batchId != null) {
          final batch = await (_db.select(
            _db.productBatches,
          )..where((t) => t.id.equals(item.batchId!))).getSingleOrNull();

          if (batch != null && batch.expiryDate != null) {
            if (batch.expiryDate!.isBefore(DateTime.now())) {
              return Result.failure(
                AppError(
                  message:
                      'Cannot sell expired item: ${item.productName} (Expiry: ${batch.expiryDate})',
                  category: ErrorCategory.validation,
                  severity: ErrorSeverity.medium,
                ),
              );
            }
          }
        }
      }
    }

    // ELECTRONICS: Tenant-scoped serial/IMEI uniqueness check
    // Mirrors the proven mobileShop pattern in IMEIValidationService.validateBillItems
    if (businessType == 'electronics' ||
        businessType == BusinessType.mobileShop.name) {
      // Within-bill duplicate detection: reject if the same serial appears on
      // multiple lines in one bill (applies to electronics only; mobileShop
      // already has its own async check in manual_item_entry_sheet.dart)
      if (businessType == 'electronics') {
        final serialsSeen = <String>{};
        for (final item in items) {
          final serial = item.imei;
          if (serial != null && serial.isNotEmpty) {
            if (serialsSeen.contains(serial)) {
              return Result.failure(
                AppError(
                  message:
                      'Duplicate serial/IMEI "$serial" used on multiple lines in this bill',
                  category: ErrorCategory.validation,
                  severity: ErrorSeverity.medium,
                ),
              );
            }
            serialsSeen.add(serial);
          }
        }

        // Tenant-scoped uniqueness: check each serial against IMEISerials DB
        for (final item in items) {
          final serial = item.imei;
          if (serial != null && serial.isNotEmpty) {
            final existing = await _imeiRepository.getByNumber(
              bill.userId,
              serial,
            );
            if (existing != null) {
              // Reject if status is sold or in-service (conflict statuses)
              if (existing.status == IMEISerialStatus.sold ||
                  existing.status == IMEISerialStatus.inService) {
                return Result.failure(
                  AppError(
                    message:
                        'Serial/IMEI "$serial" is already ${existing.status == IMEISerialStatus.sold ? "sold" : "in service"} '
                        'for this tenant — cannot bill a duplicate',
                    category: ErrorCategory.validation,
                    severity: ErrorSeverity.medium,
                  ),
                );
              }
            }
          }
        }
      }
    }

    // Check Credit Limit (if Credit Bill)
    if (bill.paymentMode == 'CREDIT' && bill.customerId != null) {
      final customer = await _db.getCustomerById(bill.customerId!);
      if (customer != null && customer.creditLimit > 0) {
        if (customer.totalDues + bill.grandTotal > customer.creditLimit) {
          return Result.failure(
            AppError(
              message:
                  'Credit Limit Exceeded for ${customer.name}. Limit: ${customer.creditLimit}',
              category: ErrorCategory.validation,
              severity: ErrorSeverity.medium,
            ),
          );
        }
      }
    }

    return Result.success(null);
  }

  /// Parses warrantyMonths from the bill's itemsJson blob, returning a map
  /// keyed by serialNo (the `BillItem.serialNo` field which corresponds to
  /// `BillItemEntity.imei`). Falls back gracefully on malformed JSON.
  Map<String, int> _parseWarrantyMonthsFromJson(String itemsJson) {
    final result = <String, int>{};
    try {
      final decoded = jsonDecode(itemsJson) as List<dynamic>;
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;
        final serial = raw['serialNo']?.toString();
        if (serial == null || serial.isEmpty) continue;
        final wm = raw['warrantyMonths'];
        if (wm is int) {
          result[serial] = wm;
        } else if (wm is num) {
          result[serial] = wm.toInt();
        }
      }
    } catch (_) {
      // Graceful fallback: if itemsJson is malformed or empty, return empty map.
      // Warranty months will default to 0 for all items.
    }
    return result;
  }
}
