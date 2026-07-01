// ============================================================================
// SAFE MODE SERVICE
// ============================================================================
// Auto-triggers restricted mode on suspicious activity patterns.
// Fraud fails when friction is unavoidable.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../../repository/audit_repository.dart';
import '../device/trusted_device_service.dart';

/// Safe Mode Status
enum SafeModeStatus {
  /// Normal operation
  normal,

  /// Safe mode active - restricted operations
  active,

  /// Manual lock by owner (panic mode)
  panicLock,
}

/// Safe Mode State
class SafeModeState {
  final String businessId;
  final SafeModeStatus status;
  final String? triggeredBy;
  final String? triggerReason;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final bool requiresManualExit;

  const SafeModeState({
    required this.businessId,
    this.status = SafeModeStatus.normal,
    this.triggeredBy,
    this.triggerReason,
    this.activatedAt,
    this.expiresAt,
    this.requiresManualExit = false,
  });

  bool get isActive => status != SafeModeStatus.normal;

  bool get isPanicLock => status == SafeModeStatus.panicLock;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Duration get timeRemaining {
    if (expiresAt == null || isExpired) return Duration.zero;
    return expiresAt!.difference(DateTime.now());
  }

  Map<String, dynamic> toMap() => {
    'businessId': businessId,
    'status': status.name,
    'triggeredBy': triggeredBy,
    'triggerReason': triggerReason,
    'activatedAt': activatedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'requiresManualExit': requiresManualExit,
  };

  factory SafeModeState.fromMap(Map<String, dynamic> map) {
    return SafeModeState(
      businessId: map['businessId'] as String,
      status: SafeModeStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SafeModeStatus.normal,
      ),
      triggeredBy: map['triggeredBy'] as String?,
      triggerReason: map['triggerReason'] as String?,
      activatedAt: map['activatedAt'] != null
          ? DateTime.parse(map['activatedAt'] as String)
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      requiresManualExit: map['requiresManualExit'] as bool? ?? false,
    );
  }
}

/// Activity Tracking for suspicious pattern detection
class ActivityTracker {
  final Map<String, List<DateTime>> _actionTimestamps = {};
  final Map<String, int> _actionCounts = {};

  /// Record an action
  void recordAction(String businessId, String actionType) {
    final key = '$businessId:$actionType';
    _actionTimestamps.putIfAbsent(key, () => []);
    _actionTimestamps[key]!.add(DateTime.now());

    // Clean old entries (older than 1 hour)
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _actionTimestamps[key]!.removeWhere((t) => t.isBefore(cutoff));

    _actionCounts[key] = _actionTimestamps[key]!.length;
  }

  /// Get action count in last N minutes
  int getActionCount(String businessId, String actionType, int minutes) {
    final key = '$businessId:$actionType';
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _actionTimestamps[key]?.where((t) => t.isAfter(cutoff)).length ?? 0;
  }

  /// Get total owner actions in last hour
  int getTotalOwnerActions(String businessId) {
    int total = 0;
    for (final entry in _actionTimestamps.entries) {
      if (entry.key.startsWith(businessId)) {
        total += entry.value.length;
      }
    }
    return total;
  }

  void clear(String businessId) {
    _actionTimestamps.removeWhere((key, _) => key.startsWith(businessId));
    _actionCounts.removeWhere((key, _) => key.startsWith(businessId));
  }
}

/// Safe Mode Service - Auto-restricts on suspicious patterns.
///
/// Triggers on:
/// - >10 owner actions in 1 hour
/// - >3 PIN overrides in 30 min
/// - Repeated same action (>5)
/// - Device mismatch detected
class SafeModeService {
  final FirebaseFirestore _firestore;
  final TrustedDeviceService _deviceService;
  final AuditRepository _auditRepository;
  final ActivityTracker _tracker = ActivityTracker();

  /// Stream controller for safe mode changes
  final StreamController<SafeModeState> _stateController =
      StreamController<SafeModeState>.broadcast();

  /// Cached states
  final Map<String, SafeModeState> _stateCache = {};

  /// Trigger thresholds
  static const int maxOwnerActionsPerHour = 10;
  static const int maxPinOverridesIn30Min = 3;
  static const int maxRepeatedSameAction = 5;

  /// Safe mode durations
  static const Duration autoSafeModeDuration = Duration(hours: 2);
  static const Duration panicLockCoolingPeriod = Duration(hours: 4);

  SafeModeService({
    FirebaseFirestore? firestore,
    required TrustedDeviceService deviceService,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _deviceService = deviceService,
       _auditRepository = auditRepository;

  /// Stream of safe mode state changes
  Stream<SafeModeState> get stateChanges => _stateController.stream;

  /// Get current safe mode state
  Future<SafeModeState> getState(String businessId) async {
    // Check cache
    if (_stateCache.containsKey(businessId)) {
      final cached = _stateCache[businessId]!;

      // Auto-exit if expired
      if (cached.isActive && cached.isExpired && !cached.requiresManualExit) {
        await _exitSafeMode(businessId, 'AUTO_EXPIRED');
        return SafeModeState(businessId: businessId);
      }

      return cached;
    }

    // Fetch from Firestore
    try {
      final doc = await _firestore
          .collection('safe_mode_states')
          .doc(businessId)
          .get();

      if (!doc.exists) {
        return SafeModeState(businessId: businessId);
      }

      final state = SafeModeState.fromMap(doc.data()!);
      _stateCache[businessId] = state;
      return state;
    } catch (e) {
      debugPrint('SafeModeService: Error fetching state: $e');
      return SafeModeState(businessId: businessId);
    }
  }

  /// Check if operation is allowed (returns false if in safe mode)
  Future<bool> isOperationAllowed({
    required String businessId,
    required String operationType,
  }) async {
    final state = await getState(businessId);

    if (!state.isActive) return true;

    // In safe mode, only allow read operations
    const allowedOperations = ['VIEW', 'READ', 'EXPORT_REPORT', 'LIST'];
    return allowedOperations.contains(operationType.toUpperCase());
  }

  /// Record action and check for triggers
  Future<void> recordAndCheck({
    required String businessId,
    required String userId,
    required String actionType,
    bool isPinOverride = false,
  }) async {
    _tracker.recordAction(businessId, actionType);

    // Check trigger conditions
    final triggers = <String>[];

    // Check: >10 owner actions in 1 hour
    final totalActions = _tracker.getTotalOwnerActions(businessId);
    if (totalActions > maxOwnerActionsPerHour) {
      triggers.add('Too many owner actions ($totalActions in last hour)');
    }

    // Check: >3 PIN overrides in 30 min
    if (isPinOverride) {
      _tracker.recordAction(businessId, 'PIN_OVERRIDE');
      final pinOverrides = _tracker.getActionCount(
        businessId,
        'PIN_OVERRIDE',
        30,
      );
      if (pinOverrides > maxPinOverridesIn30Min) {
        triggers.add('Too many PIN overrides ($pinOverrides in 30 minutes)');
      }
    }

    // Check: Repeated same action
    final sameActionCount = _tracker.getActionCount(businessId, actionType, 60);
    if (sameActionCount > maxRepeatedSameAction) {
      triggers.add('Repeated action $actionType ($sameActionCount times)');
    }

    // Trigger safe mode if any conditions met
    if (triggers.isNotEmpty) {
      await activateSafeMode(
        businessId: businessId,
        triggeredBy: 'SYSTEM',
        reason: triggers.join('; '),
        duration: autoSafeModeDuration,
      );
    }
  }

  /// Activate safe mode
  Future<SafeModeState> activateSafeMode({
    required String businessId,
    required String triggeredBy,
    required String reason,
    Duration? duration,
    bool isPanicLock = false,
  }) async {
    final now = DateTime.now();
    final effectiveDuration = isPanicLock
        ? panicLockCoolingPeriod
        : (duration ?? autoSafeModeDuration);

    final state = SafeModeState(
      businessId: businessId,
      status: isPanicLock ? SafeModeStatus.panicLock : SafeModeStatus.active,
      triggeredBy: triggeredBy,
      triggerReason: reason,
      activatedAt: now,
      expiresAt: now.add(effectiveDuration),
      requiresManualExit: isPanicLock,
    );

    // Save to Firestore
    await _firestore
        .collection('safe_mode_states')
        .doc(businessId)
        .set(state.toMap());

    // Update cache
    _stateCache[businessId] = state;

    // Emit state change
    _stateController.add(state);

    // Audit log
    await _auditRepository.logAction(
      userId: triggeredBy,
      targetTableName: 'safe_mode_states',
      recordId: businessId,
      action: isPanicLock ? 'PANIC_LOCK' : 'SAFE_MODE_ACTIVATED',
      newValueJson: jsonEncode({
        'reason': reason,
        'expiresAt': state.expiresAt?.toIso8601String(),
        'requiresManualExit': state.requiresManualExit,
      }),
    );

    debugPrint(
      'SafeModeService: ${isPanicLock ? "PANIC LOCK" : "Safe mode"} activated. '
      'Reason: $reason. Duration: ${effectiveDuration.inMinutes} minutes.',
    );

    return state;
  }

  /// Panic Lock - Emergency one-tap system freeze
  Future<SafeModeState> activatePanicLock({
    required String businessId,
    required String activatedBy,
  }) async {
    // Validate device
    final deviceResult = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: activatedBy,
    );

    if (!deviceResult.isValid) {
      throw SafeModeException(
        'Panic lock can only be activated from trusted device',
      );
    }

    return activateSafeMode(
      businessId: businessId,
      triggeredBy: activatedBy,
      reason: 'Emergency panic lock activated',
      isPanicLock: true,
    );
  }

  /// Exit safe mode (requires validation)
  Future<void> exitSafeMode({
    required String businessId,
    required String requestedBy,
    required String reason,
  }) async {
    final state = await getState(businessId);

    if (!state.isActive) return;

    // Validate device
    final deviceResult = await _deviceService.validateCurrentDevice(
      businessId: businessId,
      ownerId: requestedBy,
    );

    if (!deviceResult.isValid) {
      throw SafeModeException(
        'Safe mode can only be exited from trusted device',
      );
    }

    // Check cooling period for panic lock
    if (state.isPanicLock && !state.isExpired) {
      final remaining = state.timeRemaining;
      throw SafeModeException(
        'Panic lock cooling period not complete. '
        'Wait ${remaining.inMinutes} more minutes.',
      );
    }

    await _exitSafeMode(businessId, reason);
  }

  Future<void> _exitSafeMode(String businessId, String reason) async {
    final normalState = SafeModeState(businessId: businessId);

    await _firestore
        .collection('safe_mode_states')
        .doc(businessId)
        .set(normalState.toMap());

    _stateCache[businessId] = normalState;
    _stateController.add(normalState);
    _tracker.clear(businessId);

    await _auditRepository.logAction(
      userId: 'SYSTEM',
      targetTableName: 'safe_mode_states',
      recordId: businessId,
      action: 'SAFE_MODE_EXITED',
      newValueJson: jsonEncode({'reason': reason}),
    );

    debugPrint('SafeModeService: Safe mode exited. Reason: $reason');
  }

  void dispose() {
    _stateController.close();
  }
}

/// Exception for safe mode errors
class SafeModeException implements Exception {
  final String message;
  SafeModeException(this.message);

  @override
  String toString() => 'SafeModeException: $message';
}
