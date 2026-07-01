// ============================================================================
// SECURITY REPOSITORY MIXIN
// ============================================================================
// Mixin for repositories to integrate security checks.
// ============================================================================

import 'package:flutter/foundation.dart';

import '../security/models/bill_state.dart';
import '../security/models/pin_protected_actions.dart';
import '../security/services/owner_pin_service.dart';
import '../security/services/pin_verification_service.dart';
import '../services/period_lock_service.dart';
import 'audit_repository.dart';

/// Security context for repository operations
class SecurityContext {
  final String businessId;
  final String userId;
  final String? pin;
  final String? approvalReason;

  const SecurityContext({
    required this.businessId,
    required this.userId,
    this.pin,
    this.approvalReason,
  });

  bool get hasPin => pin != null && pin!.isNotEmpty;
  bool get hasReason => approvalReason != null && approvalReason!.isNotEmpty;
}

/// Security check result
class SecurityCheckResult {
  final bool isAllowed;
  final String? blockedReason;
  final bool requiresPin;
  final PinProtectedAction? requiredAction;

  const SecurityCheckResult._({
    required this.isAllowed,
    this.blockedReason,
    this.requiresPin = false,
    this.requiredAction,
  });

  factory SecurityCheckResult.allowed() {
    return const SecurityCheckResult._(isAllowed: true);
  }

  factory SecurityCheckResult.blocked(String reason) {
    return SecurityCheckResult._(isAllowed: false, blockedReason: reason);
  }

  factory SecurityCheckResult.pinRequired(PinProtectedAction action) {
    return SecurityCheckResult._(
      isAllowed: false,
      requiresPin: true,
      requiredAction: action,
      blockedReason: '${action.displayName} requires PIN verification',
    );
  }
}

/// Security helper for repository operations
class RepositorySecurityHelper {
  final PinVerificationService? _pinService;
  final PeriodLockService? _periodLockService;
  final AuditRepository? _auditRepository;

  RepositorySecurityHelper({
    PinVerificationService? pinService,
    PeriodLockService? periodLockService,
    AuditRepository? auditRepository,
  }) : _pinService = pinService,
       _periodLockService = periodLockService,
       _auditRepository = auditRepository;

  /// Check if period is locked for a date
  Future<SecurityCheckResult> checkPeriodLock({
    required String businessId,
    required DateTime date,
    required String operation,
  }) async {
    if (_periodLockService == null) {
      return SecurityCheckResult.allowed();
    }

    try {
      final isLocked = await _periodLockService.isDateLocked(
        businessId: businessId,
        date: date,
      );

      if (isLocked) {
        return SecurityCheckResult.blocked(
          'Cannot $operation: Accounting period for ${date.month}/${date.year} is locked.',
        );
      }

      return SecurityCheckResult.allowed();
    } catch (e) {
      debugPrint('RepositorySecurityHelper: Period lock check failed: $e');
      return SecurityCheckResult.allowed(); // Fail open for now
    }
  }

  /// Check bill immutability
  Future<SecurityCheckResult> checkBillImmutability({
    required String status,
    required int printCount,
    required double paidAmount,
    required DateTime billDate,
    required int editWindowMinutes,
    required bool isDelete,
    SecurityContext? context,
  }) async {
    final check = isDelete
        ? BillImmutabilityService.canDelete(
            status: status,
            printCount: printCount,
            paidAmount: paidAmount,
            hasOwnerPin: context?.hasPin ?? false,
          )
        : BillImmutabilityService.canEdit(
            status: status,
            printCount: printCount,
            paidAmount: paidAmount,
            billDate: billDate,
            editWindowMinutes: editWindowMinutes,
            hasOwnerPin: context?.hasPin ?? false,
          );

    if (check.isAllowed) {
      return SecurityCheckResult.allowed();
    }

    if (check.canOverrideWithPin) {
      return SecurityCheckResult.pinRequired(
        isDelete
            ? PinProtectedAction.billDelete
            : PinProtectedAction.billEditAfterPayment,
      );
    }

    return SecurityCheckResult.blocked(check.reason ?? 'Operation not allowed');
  }

  /// Verify PIN for an action
  Future<SecurityCheckResult> verifyPinForAction({
    required SecurityContext context,
    required PinProtectedAction action,
    String? referenceId,
  }) async {
    if (_pinService == null) {
      return SecurityCheckResult.allowed();
    }

    if (!context.hasPin) {
      return SecurityCheckResult.pinRequired(action);
    }

    try {
      final result = await _pinService.verifyAndAuthorize(
        businessId: context.businessId,
        performingUserId: context.userId,
        pin: context.pin!,
        action: action,
        reason: context.approvalReason,
        referenceId: referenceId,
      );

      if (result.isAuthorized) {
        return SecurityCheckResult.allowed();
      }

      return SecurityCheckResult.blocked('Invalid PIN');
    } catch (e) {
      if (e is PinLockoutException) {
        return SecurityCheckResult.blocked('PIN locked: ${e.message}');
      }
      debugPrint('RepositorySecurityHelper: PIN verification failed: $e');
      return SecurityCheckResult.blocked('PIN verification failed');
    }
  }

  /// Log security event
  Future<void> logSecurityEvent({
    required String userId,
    required String action,
    required String referenceId,
    String? details,
  }) async {
    if (_auditRepository == null) return;

    try {
      await _auditRepository.logAction(
        userId: userId,
        targetTableName: 'security_events',
        recordId: referenceId,
        action: action,
        newValueJson: details ?? '{}',
      );
    } catch (e) {
      debugPrint('RepositorySecurityHelper: Failed to log security event: $e');
    }
  }
}
