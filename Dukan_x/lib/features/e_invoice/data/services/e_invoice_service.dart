import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../repositories/e_invoice_repository.dart';
import '../models/e_invoice_model.dart';
import '../models/irn_response_model.dart';
import 'nic_irp_service.dart';
import '../../../../services/audit_service.dart';

/// e-Invoice Service
///
/// Handles e-invoice generation with offline-first approach:
/// 1. Creates local record immediately
/// 2. Attempts API call when online
/// 3. Queues for retry if offline
///
/// IMPORTANT: This service REQUIRES proper NIC IRP configuration.
/// Mock IRN generation has been REMOVED for legal compliance.
class EInvoiceService {
  final EInvoiceRepository _repository;
  final AuditService? _auditService;

  EInvoiceService(this._repository, {AuditService? auditService})
    : _auditService = auditService;

  /// Check if e-Invoice is properly configured
  static Future<bool> isConfigured() async {
    return await NicIrpService.isConfigured();
  }

  /// Generate e-invoice for a bill
  ///
  /// Returns immediately with local record,
  /// actual IRN generation happens async.
  ///
  /// Throws [EInvoiceNotConfiguredException] if NIC IRP is not configured.
  Future<EInvoiceModel?> generateEInvoice({
    required String billId,
    required Map<String, dynamic> invoiceData,
  }) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      debugPrint('EInvoiceService: No user logged in');
      return null;
    }

    // COMPLIANCE CHECK: Verify NIC IRP is configured
    final isConfigured = await NicIrpService.isConfigured();
    if (!isConfigured) {
      throw EInvoiceNotConfiguredException(
        'NIC e-Invoice integration is not configured. '
        'Please configure your NIC IRP credentials in Settings > e-Invoice Configuration.',
      );
    }

    // 1. Create local record first (offline-first)
    final result = await _repository.createEInvoice(
      userId: userId,
      billId: billId,
    );

    if (!result.isSuccess) {
      debugPrint('EInvoiceService: Failed to create local record');
      return null;
    }

    final eInvoice = result.data!;

    // 2. Persist the request payload for offline retry (outbox pattern)
    //    Uses signedInvoice column as temp storage — overwritten with real
    //    signed invoice data once IRN is successfully generated.
    try {
      final payloadJson = _jsonEncode(invoiceData);
      await _repository.storeRequestPayload(
        id: eInvoice.id,
        payload: payloadJson,
      );
    } catch (e) {
      debugPrint('EInvoiceService: Warning - could not persist request payload: $e');
    }

    // 3. Try to generate IRN (if online) — async, non-blocking
    _tryGenerateIRN(eInvoice.id, invoiceData);

    return eInvoice;
  }

  /// Validates an existing IRN with NIC IRP (P0-09)
  Future<IrnData?> validateIrn(String irn) async {
    try {
      final nicIrpService = await NicIrpService.create();
      if (nicIrpService == null) return null;

      final response = await nicIrpService.getIrnDetails(irn);
      if (response != null && response.isSuccess) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('EInvoiceService: Failed to validate IRN: $e');
      return null;
    }
  }

  /// P0-10: Turnover Check & Blocking Logic
  /// Call this BEFORE finalizing the bill.
  Future<void> checkTurnoverCompliance({
    required double taxableValue,
    required bool isB2B,
  }) async {
    // 1. Get Gst Settings
    // For now, checks if NIC integration is configured.
    // In future, this should fetch turnover from GstRepository to auto-suggest enablement.
    // If turnover > 5Cr, e-invoice is mandatory for B2B.
    final isConfigured = await NicIrpService.isConfigured();

    // If not B2B, no strict blocking needed for e-invoice
    if (!isB2B) return;

    // If e-Invoice is configured (implies >5Cr turnover compliance is active)
    if (isConfigured) {
      // We do not block here, but we ensure the caller knows e-invoice is mandatory.
      // The generateEInvoice method will throw if config is missing.
    }
  }

  /// Retry failed e-invoices (P0-11 / P2 outbox pattern)
  ///
  /// Reads the persisted request payload from each PENDING/FAILED record
  /// and re-attempts IRN generation. Called by WorkmanagerJobProvider
  /// when connectivity is restored.
  Future<void> retryFailedEInvoices() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    final result = await _repository.getPendingEInvoices(userId);
    if (!result.isSuccess) return;

    final pending = result.data!;
    debugPrint(
      'EInvoiceService: Processing ${pending.length} pending e-invoices',
    );

    for (final eInvoice in pending) {
      if (eInvoice.retryCount >= 3) {
        debugPrint('EInvoiceService: Skipping ${eInvoice.id} — max retries reached');
        continue;
      }

      // Read back the stored request payload
      final payload = await _repository.getStoredPayload(eInvoice.id);
      if (payload == null || payload.isEmpty) {
        debugPrint('EInvoiceService: Skipping ${eInvoice.id} — no stored payload');
        continue;
      }

      try {
        final invoiceData = _jsonDecode(payload);
        await _tryGenerateIRN(eInvoice.id, invoiceData);
        debugPrint('EInvoiceService: Retry succeeded for ${eInvoice.id}');
      } catch (e) {
        debugPrint('EInvoiceService: Retry failed for ${eInvoice.id}: $e');
      }
    }
  }

  /// Attempt to generate IRN from NIC IRP
  ///
  /// SECURITY: No mock fallback - real IRN required for legal validity
  Future<void> _tryGenerateIRN(
    String eInvoiceId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Create NIC IRP service instance
      final nicIrpService = await NicIrpService.create();

      if (nicIrpService == null) {
        // If not configured, we fail permanently
        throw EInvoiceNotConfiguredException(
          'NIC IRP service could not be initialized. Please verify your credentials.',
        );
      }

      // Generate IRN via NIC API
      final response = await nicIrpService.generateIrn(data);

      if (response != null && response.isSuccess && response.data != null) {
        final irn = response.data!.irn;
        final signedQrCode = response.data!.signedQrCode;
        final ackNumber = response.data!.ackNo;
        DateTime ackDate;
        try {
          ackDate = DateTime.parse(response.data!.ackDt);
        } catch (_) {
          ackDate = DateTime.now();
        }

        debugPrint('EInvoiceService: IRN generated successfully: $irn');

        await _repository.updateWithIRN(
          id: eInvoiceId,
          irn: irn,
          ackNumber: ackNumber,
          ackDate: ackDate,
          qrCode: signedQrCode,
        );

        // AUDIT LOG
        if (_auditService != null) {
          final userId = sl<SessionManager>().ownerId ?? 'unknown';
          // eInvoiceId corresponds to the billId in e_invoices usually,
          // or we can use eInvoiceId as recordId.
          // audit_service.dart expects (userId, billId, irn, status)
          // We'll use eInvoiceId as billId proxy or fetched from context if map has it.
          // The data map has 'billId' probably?
          // data passed to generateIrn is standard JSON payload.
          // But safer to just use eInvoiceId as the record ID.

          _auditService.logIrnGeneration(userId, eInvoiceId, irn, 'SUCCESS');
        }
      } else {
        final errorMessage =
            response?.error?.errorMessage ?? 'Unknown NIC API Error';

        // P0-11: Handle Network Errors vs Logic Errors
        // If error is related to connectivity, we should queue for retry
        // But for now, we mark as failed. The retry logic needs the request body.
        await _repository.markFailed(id: eInvoiceId, error: errorMessage);

        throw EInvoiceGenerationException(errorMessage);
      }
    } catch (e) {
      debugPrint('EInvoiceService: Failed to generate IRN: $e');

      // Update retry count and last error
      await _repository.markFailed(id: eInvoiceId, error: e.toString());

      // Re-throw for caller to handle
      if (e is EInvoiceNotConfiguredException ||
          e is EInvoiceGenerationException) {
        rethrow;
      }
    }
  }

  /// Cancel an e-invoice
  Future<bool> cancelEInvoice({
    required String eInvoiceId,
    required String reason,
  }) async {
    final result = await _repository.cancelEInvoice(
      id: eInvoiceId,
      reason: reason,
    );
    return result.isSuccess;
  }

  /// Check if a bill has an e-invoice
  Future<EInvoiceModel?> getEInvoiceForBill(String billId) async {
    final result = await _repository.getEInvoiceByBillId(billId);
    return result.data;
  }

  /// Get all e-invoices for current user
  Future<List<EInvoiceModel>> getAllEInvoices({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return [];

    final result = await _repository.getAllEInvoices(
      userId: userId,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
    );

    return result.data ?? [];
  }

  // ==========================================================================
  // JSON HELPERS (outbox payload serialization)
  // ==========================================================================

  String _jsonEncode(Map<String, dynamic> data) => jsonEncode(data);

  Map<String, dynamic> _jsonDecode(String payload) {
    final decoded = jsonDecode(payload);
    return Map<String, dynamic>.from(decoded as Map);
  }
}

/// Exception thrown when e-Invoice is not configured
class EInvoiceNotConfiguredException implements Exception {
  final String message;

  EInvoiceNotConfiguredException(this.message);

  @override
  String toString() => 'EInvoiceNotConfiguredException: $message';
}

/// Exception thrown when e-Invoice generation fails
class EInvoiceGenerationException implements Exception {
  final String message;

  EInvoiceGenerationException(this.message);

  @override
  String toString() => 'EInvoiceGenerationException: $message';
}
