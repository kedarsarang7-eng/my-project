import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/repository/audit_repository.dart';
import '../core/services/device_id_service.dart';
import '../models/bill.dart';
// import '../features/payment/domain/entities/payment_entity.dart'; // Assuming Payment Entity/Model exists

class AuditService {
  final AuditRepository _auditRepository;
  final DeviceIdService _deviceIdService;

  String? _cachedAppVersion;

  AuditService(this._auditRepository, this._deviceIdService);

  /// Get App Version (Cached)
  Future<String> _getAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      _cachedAppVersion = 'unknown';
    }
    return _cachedAppVersion!;
  }

  /// Get Device ID
  Future<String> _getDeviceId() async {
    return await _deviceIdService.getDeviceId();
  }

  // ============================================
  // BILLING AUDIT
  // ============================================

  Future<void> logInvoiceCreation(Bill bill) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: bill.ownerId, // Using ownerId as userId
        targetTableName: 'bills',
        recordId: bill.id,
        action: 'CREATE',
        newValueJson: jsonEncode(bill.toMap()), // Assuming toMap exists
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log invoice creation: $e');
    }
  }

  Future<void> logInvoiceUpdate(Bill oldBill, Bill newBill) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: newBill.ownerId, // Using ownerId as userId
        targetTableName: 'bills',
        recordId: newBill.id,
        action: 'UPDATE',
        oldValueJson: jsonEncode(oldBill.toMap()),
        newValueJson: jsonEncode(newBill.toMap()),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log invoice update: $e');
    }
  }

  Future<void> logInvoiceDeletion(
    String userId,
    String billId,
    String reason,
  ) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'bills',
        recordId: billId,
        action: 'DELETE',
        oldValueJson: jsonEncode({'reason': reason}),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log invoice deletion: $e');
    }
  }

  // ============================================
  // SECURITY AUDIT
  // ============================================

  Future<void> logSecurityEvent({
    required String userId,
    required String severity, // LOW, MEDIUM, HIGH, CRITICAL
    required String message,
    Map<String, dynamic>? details,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'security_events',
        recordId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'SECURITY_ALERT',
        newValueJson: jsonEncode({
          'severity': severity,
          'message': message,
          'details': ?details,
        }),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log security event: $e');
    }
  }

  // ============================================
  // PAYMENT AUDIT
  // ============================================

  Future<void> logPaymentCreation({
    required String userId,
    required String billId,
    required double amount,
    required String paymentMode,
    String? paymentId,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'payments',
        recordId:
            paymentId ?? billId, // Use paymentId if available, else billId
        action: 'CREATE',
        newValueJson: jsonEncode({
          'billId': billId,
          'amount': amount,
          'paymentMode': paymentMode,
        }),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log payment creation: $e');
    }
  }

  Future<void> logPaymentUpdate({
    required String userId,
    required String paymentId,
    required String billId,
    required double oldAmount,
    required double newAmount,
    required String reason,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'payments',
        recordId: paymentId,
        action: 'UPDATE',
        oldValueJson: jsonEncode({'amount': oldAmount}),
        newValueJson: jsonEncode({
          'billId': billId,
          'amount': newAmount,
          'reason': reason,
        }),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log payment update: $e');
    }
  }

  Future<void> logPaymentVoid({
    required String userId,
    required String paymentId,
    required String billId,
    required double amount,
    required String reason,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'payments',
        recordId: paymentId,
        action: 'VOID',
        oldValueJson: jsonEncode({
          'billId': billId,
          'amount': amount,
          'status': 'ACTIVE',
        }),
        newValueJson: jsonEncode({'status': 'VOID', 'reason': reason}),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log payment void: $e');
    }
  }

  /// Log payment deletion with reversal
  Future<void> logPaymentDeletion({
    required String userId,
    required String paymentId,
    required String reason,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'payments',
        recordId: paymentId,
        action: 'DELETE',
        oldValueJson: jsonEncode({
          'reason': reason,
          'deletedAt': DateTime.now().toIso8601String(),
        }),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log payment deletion: $e');
    }
  }

  // ============================================
  // NIC / IRP AUDIT
  // ============================================

  Future<void> logIrnGeneration(
    String userId,
    String billId,
    String irn,
    String status,
  ) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'e_invoices',
        recordId: billId,
        action: 'IRN_GENERATE',
        newValueJson: jsonEncode({'irn': irn, 'status': status}),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log IRN generation: $e');
    }
  }

  Future<void> logIrnCancellation({
    required String userId,
    required String billId,
    required String irn,
    required String cancellationReason,
    required String cancelledBy,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final appVersion = await _getAppVersion();

      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'e_invoices',
        recordId: billId,
        action: 'IRN_CANCEL',
        oldValueJson: jsonEncode({'irn': irn, 'status': 'ACTIVE'}),
        newValueJson: jsonEncode({
          'irn': irn,
          'status': 'CANCELLED',
          'cancellationReason': cancellationReason,
          'cancelledBy': cancelledBy,
          'cancelledAt': DateTime.now().toIso8601String(),
        }),
        deviceId: deviceId,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('AuditService: Failed to log IRN cancellation: $e');
    }
  }
}
