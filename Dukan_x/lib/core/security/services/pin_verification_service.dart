// ============================================================================
// PIN VERIFICATION SERVICE
// ============================================================================
// Central service for PIN-protected action authorization.
// Integrates with OwnerPinService and AuditRepository.
// ============================================================================

import 'package:flutter/foundation.dart';

import '../models/pin_protected_actions.dart';
import 'owner_pin_service.dart';
import '../../repository/audit_repository.dart';

/// PIN Verification Service - Central authorization for critical actions.
///
/// This service:
/// - Checks if action requires PIN based on settings
/// - Verifies PIN with OwnerPinService
/// - Logs all authorization attempts to audit trail
/// - Returns authorization result for use in repositories/services
class PinVerificationService {
  final OwnerPinService _pinService;
  final AuditRepository _auditRepository;

  PinVerificationService({
    required OwnerPinService pinService,
    required AuditRepository auditRepository,
  }) : _pinService = pinService,
       _auditRepository = auditRepository;

  /// Check if an action requires PIN for a specific business
  Future<bool> requiresPinFor({
    required String businessId,
    required PinProtectedAction action,
    double? discountPercent,
  }) async {
    final settings = await _pinService.getSecuritySettings(businessId);

    // If no settings, default to requiring PIN for critical actions
    if (settings == null) {
      return action.severity == Severity.critical;
    }

    switch (action) {
      case PinProtectedAction.billDelete:
        return settings.requirePinForBillDelete;

      case PinProtectedAction.billEditAfterPayment:
        return true; // Always require for paid bills

      case PinProtectedAction.highDiscount:
        if (discountPercent == null) return false;
        return settings.requiresPinForDiscount(discountPercent);

      case PinProtectedAction.refund:
        return settings.requirePinForRefunds;

      case PinProtectedAction.stockAdjustment:
        return settings.requirePinForStockAdjustment;

      case PinProtectedAction.periodUnlock:
        return settings.requirePinForPeriodUnlock;

      case PinProtectedAction.cashMismatchAcceptance:
        return true; // Always require

      case PinProtectedAction.forceLogoutUser:
        return true; // Always require

      case PinProtectedAction.changeUserRole:
        return true; // Always require (owner only)

      case PinProtectedAction.viewSensitiveData:
        return false; // Not required by default

      case PinProtectedAction.exportAuditLogs:
        return false; // Not required by default

      case PinProtectedAction.closeFinancialYear:
        return true; // Always require (owner only)

      case PinProtectedAction.editGstData:
        return true; // Always require (critical)

      case PinProtectedAction.overrideSystemCalculation:
        return true; // Always require (critical)
    }
  }

  /// Verify PIN and authorize action
  ///
  /// Returns authorization result with audit trail.
  Future<PinVerificationResult> verifyAndAuthorize({
    required String businessId,
    required String performingUserId,
    required String pin,
    required PinProtectedAction action,
    String? reason,
    String? referenceId, // billId, productId, etc.
  }) async {
    try {
      // Verify PIN
      final isValid = await _pinService.verifyPin(
        businessId: businessId,
        pin: pin,
      );

      if (!isValid) {
        // Log failed attempt
        await _logAuthorizationAttempt(
          businessId: businessId,
          userId: performingUserId,
          action: action,
          success: false,
          referenceId: referenceId,
        );

        return PinVerificationResult.denied(action);
      }

      // Log successful authorization
      await _logAuthorizationAttempt(
        businessId: businessId,
        userId: performingUserId,
        action: action,
        success: true,
        reason: reason,
        referenceId: referenceId,
      );

      // Create fraud alert for critical actions
      if (action.createsFraudAlert) {
        await _createFraudAlert(
          businessId: businessId,
          userId: performingUserId,
          action: action,
          referenceId: referenceId,
        );
      }

      return PinVerificationResult.authorized(
        action: action,
        authorizedBy: performingUserId,
        reason: reason,
      );
    } on PinLockoutException catch (e) {
      // Log lockout
      await _logAuthorizationAttempt(
        businessId: businessId,
        userId: performingUserId,
        action: action,
        success: false,
        reason: 'LOCKOUT: ${e.message}',
        referenceId: referenceId,
      );
      rethrow;
    } catch (e) {
      debugPrint('PinVerificationService: Error during verification: $e');
      return PinVerificationResult.denied(action);
    }
  }

  /// Check if user is owner (can authorize owner-only actions)
  Future<bool> canAuthorizeOwnerOnly({
    required String businessId,
    required String userId,
  }) async {
    // In a full implementation, this would check the user's role
    // For now, we assume if they have the PIN, they can authorize
    return true;
  }

  /// Log authorization attempt to audit trail
  Future<void> _logAuthorizationAttempt({
    required String businessId,
    required String userId,
    required PinProtectedAction action,
    required bool success,
    String? reason,
    String? referenceId,
  }) async {
    try {
      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'pin_authorization',
        recordId: referenceId ?? businessId,
        action: success ? 'AUTHORIZE' : 'DENY',
        newValueJson:
            '''{
          "action": "${action.name}",
          "success": $success,
          "severity": "${action.severity.name}",
          "reason": ${reason != null ? '"$reason"' : 'null'}
        }''',
      );
    } catch (e) {
      debugPrint('PinVerificationService: Failed to log authorization: $e');
    }
  }

  /// Create fraud alert for critical actions
  Future<void> _createFraudAlert({
    required String businessId,
    required String userId,
    required PinProtectedAction action,
    String? referenceId,
  }) async {
    // This would integrate with FraudDetectionService
    // For now, just log it
    try {
      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'fraud_alerts',
        recordId: referenceId ?? businessId,
        action: 'CREATE',
        newValueJson:
            '''{
          "alertType": "CRITICAL_ACTION",
          "action": "${action.name}",
          "severity": "HIGH",
          "description": "Critical action performed: ${action.displayName}"
        }''',
      );
    } catch (e) {
      debugPrint('PinVerificationService: Failed to create fraud alert: $e');
    }
  }
}

/// Extension for easy result checking
extension PinVerificationResultX on PinVerificationResult {
  /// Throw exception if not authorized
  void requireAuthorization() {
    if (!isAuthorized) {
      throw UnauthorizedActionException(action);
    }
  }
}

/// Exception for unauthorized actions
class UnauthorizedActionException implements Exception {
  final PinProtectedAction action;

  UnauthorizedActionException(this.action);

  @override
  String toString() =>
      'UnauthorizedActionException: ${action.displayName} requires PIN authorization';
}
