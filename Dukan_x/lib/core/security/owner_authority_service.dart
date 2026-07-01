// ============================================================================
// OWNER AUTHORITY SERVICE
// ============================================================================
// Unified owner action authorization - PIN + Device + Session.
// Implements the rule: Owner PIN alone is NEVER sufficient.
// ============================================================================

import 'package:flutter/foundation.dart';

import 'device/trusted_device_service.dart';
import 'time_lock/time_lock_service.dart';
import 'dual_control/dual_control_service.dart';
import 'safe_mode/safe_mode_service.dart';
import 'context/session_context_service.dart';
import 'services/owner_pin_service.dart';
import '../repository/audit_repository.dart';

/// Owner Authority Result
class OwnerAuthorityResult {
  final bool isAuthorized;
  final bool requiresTimeLock;
  final bool requiresDualControl;
  final String? pendingActionId;
  final String? dualControlRequestId;
  final String? blockedReason;
  final List<String> warnings;

  const OwnerAuthorityResult._({
    required this.isAuthorized,
    this.requiresTimeLock = false,
    this.requiresDualControl = false,
    this.pendingActionId,
    this.dualControlRequestId,
    this.blockedReason,
    this.warnings = const [],
  });

  factory OwnerAuthorityResult.authorized({List<String>? warnings}) {
    return OwnerAuthorityResult._(isAuthorized: true, warnings: warnings ?? []);
  }

  factory OwnerAuthorityResult.blocked(String reason) {
    return OwnerAuthorityResult._(isAuthorized: false, blockedReason: reason);
  }

  factory OwnerAuthorityResult.requiresTimeLock(String pendingId) {
    return OwnerAuthorityResult._(
      isAuthorized: false,
      requiresTimeLock: true,
      pendingActionId: pendingId,
      blockedReason: 'Action requires time lock confirmation',
    );
  }

  factory OwnerAuthorityResult.requiresDualControl(String requestId) {
    return OwnerAuthorityResult._(
      isAuthorized: false,
      requiresDualControl: true,
      dualControlRequestId: requestId,
      blockedReason: 'Action requires dual control approval',
    );
  }
}

/// Owner Authority Service - The Central Gatekeeper.
///
/// Enforces the rule: Owner PIN alone is NEVER sufficient.
/// All three must pass:
/// 1. Correct Owner PIN
/// 2. Approved Owner Device
/// 3. Valid Session Context
class OwnerAuthorityService {
  final OwnerPinService _pinService;
  final TrustedDeviceService _deviceService;
  final SessionContextService _sessionService;
  final TimeLockService _timeLockService;
  final DualControlService _dualControlService;
  final SafeModeService _safeModeService;
  final AuditRepository _auditRepository;

  OwnerAuthorityService({
    required OwnerPinService pinService,
    required TrustedDeviceService deviceService,
    required SessionContextService sessionService,
    required TimeLockService timeLockService,
    required DualControlService dualControlService,
    required SafeModeService safeModeService,
    required AuditRepository auditRepository,
  }) : _pinService = pinService,
       _deviceService = deviceService,
       _sessionService = sessionService,
       _timeLockService = timeLockService,
       _dualControlService = dualControlService,
       _safeModeService = safeModeService,
       _auditRepository = auditRepository;

  /// Authorize an owner action - The Central Check.
  ///
  /// Validates:
  /// 1. PIN correct
  /// 2. Device trusted (not in cooling)
  /// 3. Session context valid
  /// 4. Not in safe mode
  /// 5. Time lock (if required)
  /// 6. Dual control (if required)
  Future<OwnerAuthorityResult> authorizeAction({
    required String businessId,
    required String ownerId,
    required String pin,
    required String actionType,
    Map<String, dynamic>? actionDetails,
  }) async {
    final warnings = <String>[];

    // =========================================
    // LAYER 1: PIN VERIFICATION
    // =========================================
    try {
      final pinValid = await _pinService.verifyPin(
        businessId: businessId,
        pin: pin,
      );

      if (!pinValid) {
        await _logUnauthorized(ownerId, actionType, 'Invalid PIN');
        return OwnerAuthorityResult.blocked('Invalid PIN');
      }
    } on PinLockoutException catch (e) {
      await _logUnauthorized(ownerId, actionType, 'PIN Lockout: ${e.message}');
      return OwnerAuthorityResult.blocked(e.message);
    }

    // =========================================
    // LAYER 2: DEVICE VERIFICATION
    // =========================================
    final deviceResult = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: ownerId,
    );

    if (!deviceResult.isValid) {
      await _logUnauthorized(
        ownerId,
        actionType,
        'Device: ${deviceResult.reason}',
      );
      return OwnerAuthorityResult.blocked(
        deviceResult.reason ?? 'Device not authorized',
      );
    }

    if (deviceResult.isInCoolingPeriod) {
      await _logUnauthorized(ownerId, actionType, 'Device in cooling period');
      return OwnerAuthorityResult.blocked(
        'Device is in 7-day cooling period. Critical actions not allowed.',
      );
    }

    // =========================================
    // LAYER 3: SESSION CONTEXT
    // =========================================
    final session = _sessionService.currentContext;
    if (session == null) {
      await _logUnauthorized(ownerId, actionType, 'No active session');
      return OwnerAuthorityResult.blocked(
        'No active session. Please log in again.',
      );
    }

    if (!_sessionService.isCriticalActionAllowed()) {
      final reason = _sessionService.getRestrictionReason();
      await _logUnauthorized(
        ownerId,
        actionType,
        'Session restricted: $reason',
      );
      return OwnerAuthorityResult.blocked(
        reason ?? 'Session restrictions active',
      );
    }

    // =========================================
    // LAYER 4: SAFE MODE CHECK
    // =========================================
    final safeModeState = await _safeModeService.getState(businessId);
    if (safeModeState.isActive) {
      await _logUnauthorized(ownerId, actionType, 'Safe mode active');
      return OwnerAuthorityResult.blocked(
        'System is in safe mode: ${safeModeState.triggerReason}. '
        'Only viewing allowed.',
      );
    }

    // =========================================
    // LAYER 5: DUAL CONTROL CHECK
    // =========================================
    if (_dualControlService.requiresDualControl(actionType)) {
      // Check for existing approved request
      final pendingRequests = await _dualControlService.getPendingRequests(
        businessId,
      );
      final existingRequest = pendingRequests
          .where((r) => r.actionType == actionType && r.isComplete)
          .firstOrNull;

      if (existingRequest == null) {
        // Create new dual control request
        final request = await _dualControlService.createRequest(
          businessId: businessId,
          requestedBy: ownerId,
          actionType: actionType,
          actionDetails: actionDetails ?? {},
        );
        return OwnerAuthorityResult.requiresDualControl(request.id);
      }
    }

    // =========================================
    // LAYER 6: TIME LOCK CHECK
    // =========================================
    if (_timeLockService.requiresTimeLock(actionType)) {
      // Check for confirmed pending action
      final pendingActions = await _timeLockService.getPendingActions(
        businessId,
      );
      final confirmedAction = pendingActions
          .where(
            (a) =>
                a.actionType == actionType &&
                a.status == PendingActionStatus.confirmed,
          )
          .firstOrNull;

      if (confirmedAction == null) {
        // Create new time-locked action
        final action = await _timeLockService.requestAction(
          businessId: businessId,
          requestedBy: ownerId,
          actionType: actionType,
          actionDetails: actionDetails ?? {},
        );
        return OwnerAuthorityResult.requiresTimeLock(action.id);
      }
    }

    // =========================================
    // ALL CHECKS PASSED - AUTHORIZED
    // =========================================

    // Record action for safe mode monitoring
    await _safeModeService.recordAndCheck(
      businessId: businessId,
      userId: ownerId,
      actionType: actionType,
      isPinOverride: false,
    );

    // Record session action
    await _sessionService.recordAction();

    // Audit log success
    await _auditRepository.logAction(
      userId: ownerId,
      targetTableName: 'owner_authority',
      recordId: businessId,
      action: 'OWNER_ACTION_AUTHORIZED',
      newValueJson: '{"actionType": "$actionType"}',
    );

    debugPrint('OwnerAuthorityService: Action $actionType AUTHORIZED');
    return OwnerAuthorityResult.authorized(warnings: warnings);
  }

  /// Quick check if action would be allowed (without PIN)
  Future<bool> wouldActionBeAllowed({
    required String businessId,
    required String ownerId,
    required String actionType,
  }) async {
    // Check device
    final deviceResult = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: ownerId,
    );
    if (!deviceResult.isValid || deviceResult.isInCoolingPeriod) {
      return false;
    }

    // Check session
    if (!_sessionService.isCriticalActionAllowed()) {
      return false;
    }

    // Check safe mode
    final safeModeState = await _safeModeService.getState(businessId);
    if (safeModeState.isActive) {
      return false;
    }

    return true;
  }

  Future<void> _logUnauthorized(
    String userId,
    String actionType,
    String reason,
  ) async {
    await _auditRepository.logAction(
      userId: userId,
      targetTableName: 'owner_authority',
      recordId: 'DENIED',
      action: 'OWNER_ACTION_DENIED',
      newValueJson: '{"actionType": "$actionType", "reason": "$reason"}',
    );

    debugPrint('OwnerAuthorityService: Action $actionType DENIED - $reason');
  }
}
