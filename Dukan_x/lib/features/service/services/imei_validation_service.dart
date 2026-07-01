/// IMEI Validation Service
/// Validates IMEI/Serial numbers during billing to prevent duplicates
library;

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/service/data/repositories/imei_serial_repository.dart';
import 'package:dukanx/features/service/models/imei_serial.dart';
import 'package:dukanx/features/service/services/luhn_utils.dart';
import 'package:dukanx/features/service/services/warranty_date_utils.dart';
import 'package:dukanx/models/bill.dart';

/// Result of IMEI validation
class IMEIValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, String>
  imeiToProductMap; // IMEI -> Product ID for valid IMEIs

  IMEIValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.imeiToProductMap = const {},
  });

  factory IMEIValidationResult.success({
    List<String> warnings = const [],
    Map<String, String> imeiToProductMap = const {},
  }) {
    return IMEIValidationResult(
      isValid: true,
      warnings: warnings,
      imeiToProductMap: imeiToProductMap,
    );
  }

  factory IMEIValidationResult.failure(List<String> errors) {
    return IMEIValidationResult(isValid: false, errors: errors);
  }
}

/// Result of marking IMEIs as sold
class MarkIMEIsResult {
  final List<String> failedIMEIs;
  final List<String> succeededIMEIs;

  MarkIMEIsResult({
    this.failedIMEIs = const [],
    this.succeededIMEIs = const [],
  });

  bool get hasFailures => failedIMEIs.isNotEmpty;
}

/// Result of processing an IMEI-aware return
class IMEIReturnResult {
  final bool isSuccess;
  final String? error;

  IMEIReturnResult._({required this.isSuccess, this.error});

  factory IMEIReturnResult.success() {
    return IMEIReturnResult._(isSuccess: true);
  }

  factory IMEIReturnResult.failure(String error) {
    return IMEIReturnResult._(isSuccess: false, error: error);
  }
}

/// Service for validating IMEI/Serial during billing
class IMEIValidationService {
  final AppDatabase _db;
  late final IMEISerialRepository _imeiRepository;

  IMEIValidationService(this._db) {
    _imeiRepository = IMEISerialRepository(_db);
  }

  /// Validate all IMEI/Serial numbers in bill items before sale
  /// Returns validation result with errors if any IMEI is already sold or invalid
  Future<IMEIValidationResult> validateBillItems({
    required String userId,
    required List<BillItem> items,
    required String businessType,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];
    final validImeiMap = <String, String>{};

    // Only validate for electronics-related business types
    final requiresIMEI = _requiresIMEIValidation(businessType);
    if (!requiresIMEI) {
      return IMEIValidationResult.success();
    }

    // Within-bill duplicate detection: track serials seen in this bill
    final seenSerials = <String>{};

    for (final item in items) {
      final serialNo = item.serialNo;
      if (serialNo == null || serialNo.isEmpty) {
        // For mobileShop and electronics, IMEI/Serial is required
        if (businessType.toLowerCase().contains('mobile') ||
            businessType.toLowerCase() == 'electronics') {
          errors.add('IMEI/Serial required for: ${item.productName}');
        }
        continue;
      }

      // Check for within-bill duplicates (same serial on multiple lines)
      if (seenSerials.contains(serialNo)) {
        errors.add(
          'Duplicate serial $serialNo in bill - each unit must have a unique serial',
        );
        continue;
      }
      seenSerials.add(serialNo);

      // Validate warranty months if provided: must be integer in [0, 120]
      if (item.warrantyMonths != null) {
        final wm = item.warrantyMonths!;
        if (wm < 0 || wm > 120) {
          errors.add(
            'Warranty months for ${item.productName} must be between 0 and 120, got $wm',
          );
        }
      }

      // Luhn validation: if exactly 15 numeric digits, must pass Luhn.
      // Non-15-digit values are treated as generic serials — no Luhn applied.
      if (serialNo.length == 15 && int.tryParse(serialNo) != null) {
        if (!isValidLuhn15(serialNo)) {
          errors.add('IMEI $serialNo fails Luhn checksum validation');
          continue;
        }
      }

      // Check if this IMEI is already in use
      final existingIMEI = await _imeiRepository.getByNumber(userId, serialNo);

      if (existingIMEI != null) {
        // Check status
        switch (existingIMEI.status) {
          case IMEISerialStatus.sold:
            errors.add(
              'IMEI $serialNo already sold on ${_formatDate(existingIMEI.soldDate)}',
            );
            break;
          case IMEISerialStatus.inService:
            errors.add('IMEI $serialNo is currently in service');
            break;
          case IMEISerialStatus.returned:
            warnings.add(
              'IMEI $serialNo was previously returned - verify condition',
            );
            validImeiMap[serialNo] = existingIMEI.id;
            break;
          case IMEISerialStatus.inStock:
            // Valid - available for sale
            validImeiMap[serialNo] = existingIMEI.id;
            break;
          case IMEISerialStatus.damaged:
            errors.add('IMEI $serialNo is marked as damaged');
            break;
          case IMEISerialStatus.demo:
            errors.add(
              'IMEI $serialNo is a demo unit - remove from demo status before selling',
            );
            break;
        }
      } else {
        // IMEI not in our system - add a warning but allow sale
        // (It may be a new stock item not yet added to IMEISerials)
        warnings.add(
          'IMEI $serialNo not found in inventory - will be auto-registered',
        );
      }
    }

    if (errors.isNotEmpty) {
      return IMEIValidationResult.failure(errors);
    }

    return IMEIValidationResult.success(
      warnings: warnings,
      imeiToProductMap: validImeiMap,
    );
  }

  /// Mark IMEIs as sold after successful bill creation
  /// Should be called within the same transaction as bill creation
  Future<void> markIMEIsAsSold({
    required String userId,
    required String billId,
    required String customerId,
    required List<BillItem> items,
    int defaultWarrantyMonths = 12,
  }) async {
    for (final item in items) {
      final serialNo = item.serialNo;
      if (serialNo == null || serialNo.isEmpty) continue;

      final existingIMEI = await _imeiRepository.getByNumber(userId, serialNo);

      // Validate and clamp warranty months to [0, 120]
      final rawWarranty = item.warrantyMonths ?? defaultWarrantyMonths;
      final warrantyMonthsClamped = rawWarranty.clamp(0, 120);

      if (existingIMEI != null) {
        // Mark as sold
        await _imeiRepository.markAsSold(
          id: existingIMEI.id,
          userId: userId,
          billId: billId,
          customerId: customerId,
          soldPrice: item.price,
          warrantyMonths: warrantyMonthsClamped,
        );
      } else {
        // Auto-register new IMEI and mark as sold
        final now = DateTime.now();
        final warrantyMonths = warrantyMonthsClamped;
        final imei = IMEISerial(
          id: '',
          userId: userId,
          productId: item.productId,
          imeiOrSerial: serialNo,
          type: _guessIMEIType(serialNo),
          status: IMEISerialStatus.sold,
          billId: billId,
          customerId: customerId,
          soldPrice: item.price,
          soldDate: now,
          warrantyMonths: warrantyMonths,
          warrantyStartDate: now,
          warrantyEndDate: warrantyEndDate(now, warrantyMonths),
          isUnderWarranty: warrantyMonths > 0,
          productName: item.productName,
          createdAt: now,
          updatedAt: now,
        );
        await _imeiRepository.createIMEISerial(imei);
      }
    }
  }

  /// Safe version of markIMEIsAsSold that catches per-IMEI failures
  /// and returns a result naming the IMEIs that could not be marked sold.
  /// Called AFTER persistence so the bill is kept even on failure (Req 4.9).
  Future<MarkIMEIsResult> markIMEIsAsSoldSafe({
    required String userId,
    required String billId,
    required String customerId,
    required List<BillItem> items,
    int defaultWarrantyMonths = 12,
  }) async {
    // Tenant-Id guard: abort before any read/write if userId is missing
    if (userId.isEmpty) {
      final allIMEIs = items
          .where((i) => i.serialNo != null && i.serialNo!.isNotEmpty)
          .map((i) => i.serialNo!)
          .toList();
      return MarkIMEIsResult(failedIMEIs: allIMEIs);
    }

    final failedIMEIs = <String>[];
    final succeededIMEIs = <String>[];

    for (final item in items) {
      final serialNo = item.serialNo;
      if (serialNo == null || serialNo.isEmpty) continue;

      try {
        final existingIMEI = await _imeiRepository.getByNumber(
          userId,
          serialNo,
        );

        if (existingIMEI != null) {
          // Mark as sold
          await _imeiRepository.markAsSold(
            id: existingIMEI.id,
            userId: userId,
            billId: billId,
            customerId: customerId,
            soldPrice: item.price,
            warrantyMonths: (item.warrantyMonths ?? defaultWarrantyMonths)
                .clamp(0, 120),
          );
        } else {
          // Auto-register new IMEI and mark as sold
          final now = DateTime.now();
          final warrantyMonths = (item.warrantyMonths ?? defaultWarrantyMonths)
              .clamp(0, 120);
          final imei = IMEISerial(
            id: '',
            userId: userId,
            productId: item.productId,
            imeiOrSerial: serialNo,
            type: _guessIMEIType(serialNo),
            status: IMEISerialStatus.sold,
            billId: billId,
            customerId: customerId,
            soldPrice: item.price,
            soldDate: now,
            warrantyMonths: warrantyMonths,
            warrantyStartDate: now,
            warrantyEndDate: warrantyEndDate(now, warrantyMonths),
            isUnderWarranty: warrantyMonths > 0,
            productName: item.productName,
            createdAt: now,
            updatedAt: now,
          );
          await _imeiRepository.createIMEISerial(imei);
        }
        succeededIMEIs.add(serialNo);
      } catch (e) {
        failedIMEIs.add(serialNo);
      }
    }

    return MarkIMEIsResult(
      failedIMEIs: failedIMEIs,
      succeededIMEIs: succeededIMEIs,
    );
  }

  /// Check if a business type requires IMEI validation
  bool _requiresIMEIValidation(String businessType) {
    final normalizedType = businessType.toLowerCase();
    return normalizedType.contains('mobile') ||
        normalizedType.contains('computer') ||
        normalizedType.contains('electronics') ||
        normalizedType.contains('phone') ||
        normalizedType.contains('laptop');
  }

  /// Guess IMEI type from format.
  /// A 15-digit numeric value that passes the Luhn checksum is classified as
  /// an IMEI; a 15-digit numeric value that fails Luhn is treated as a generic
  /// serial. Non-15-digit values are always generic serials.
  IMEISerialType _guessIMEIType(String serial) {
    // IMEI is typically 15 digits AND must pass Luhn to be classified as IMEI
    if (serial.length == 15 && int.tryParse(serial) != null) {
      if (isValidLuhn15(serial)) {
        return IMEISerialType.imei;
      }
      // 15 numeric digits but fails Luhn → generic serial
      return IMEISerialType.serial;
    }
    return IMEISerialType.serial;
  }

  /// Process an IMEI-aware return for a sold unit.
  ///
  /// Confirms the return for a `sold` [IMEISerial] within the requesting
  /// tenant, reverting its status to `returned` (scoped to that tenant only).
  ///
  /// - If [userId] is empty, returns a tenant-missing error (no read/write).
  /// - If the IMEI is not found within the tenant, returns an error.
  /// - If found but status is not `sold`, returns an error naming the reason.
  /// - If found and status is `sold`, marks as returned and returns success.
  /// - No [IMEISerial] belonging to a different tenant is ever accessed.
  ///
  /// Requirements: 11.4, 11.5, 11.6
  Future<IMEIReturnResult> processIMEIReturn({
    required String userId,
    required String imeiOrSerial,
  }) async {
    // Tenant-Id guard: abort before any read/write if userId is missing
    if (userId.isEmpty) {
      return IMEIReturnResult.failure(
        'Tenant ID is missing or unresolved — cannot process return',
      );
    }

    // Lookup scoped by tenant (userId) — never touches other tenants' records
    final existing = await _imeiRepository.getByNumber(userId, imeiOrSerial);

    if (existing == null) {
      return IMEIReturnResult.failure('IMEI not found for this tenant');
    }

    if (existing.status != IMEISerialStatus.sold) {
      return IMEIReturnResult.failure(
        "IMEI has status '${existing.status.value}' — can only return sold items",
      );
    }

    // Status is sold — revert to returned, scoped to this tenant only
    await _imeiRepository.markAsReturned(existing.id, userId: userId);

    return IMEIReturnResult.success();
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.day}/${date.month}/${date.year}';
  }
}
