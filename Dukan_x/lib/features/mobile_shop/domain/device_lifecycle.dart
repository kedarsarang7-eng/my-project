/// Device Lifecycle — Domain Logic (Dart)
///
/// Pure domain logic for IMEI unit lifecycle transitions.
/// Models all states, defines the allowed transition graph,
/// validates commands against current state and version,
/// and produces immutable domain events.
///
/// Requirements: 3.5–3.6, 3.10–3.11, 4.1, 4.5–4.7, 4.9, 5.2–5.4
library;

import 'package:flutter/foundation.dart';
import '../models/common_models.dart';

// ─── Lifecycle States ────────────────────────────────────────────────────────

/// All canonical lifecycle states for an IMEI unit.
/// SECOND_HAND is an initial intake state for used devices.
enum DeviceLifecycleState {
  inStock,
  secondHand,
  reserved,
  salePending,
  sold,
  returned,
  demo,
  inService,
  exchanged,
  damaged,
  retired;

  /// Converts enum to wire format string.
  String toWireValue() {
    switch (this) {
      case DeviceLifecycleState.inStock:
        return 'IN_STOCK';
      case DeviceLifecycleState.secondHand:
        return 'SECOND_HAND';
      case DeviceLifecycleState.reserved:
        return 'RESERVED';
      case DeviceLifecycleState.salePending:
        return 'SALE_PENDING';
      case DeviceLifecycleState.sold:
        return 'SOLD';
      case DeviceLifecycleState.returned:
        return 'RETURNED';
      case DeviceLifecycleState.demo:
        return 'DEMO';
      case DeviceLifecycleState.inService:
        return 'IN_SERVICE';
      case DeviceLifecycleState.exchanged:
        return 'EXCHANGED';
      case DeviceLifecycleState.damaged:
        return 'DAMAGED';
      case DeviceLifecycleState.retired:
        return 'RETIRED';
    }
  }

  /// Parses wire format string to enum.
  static DeviceLifecycleState fromWire(String value) {
    switch (value) {
      case 'IN_STOCK':
        return DeviceLifecycleState.inStock;
      case 'SECOND_HAND':
        return DeviceLifecycleState.secondHand;
      case 'RESERVED':
        return DeviceLifecycleState.reserved;
      case 'SALE_PENDING':
        return DeviceLifecycleState.salePending;
      case 'SOLD':
        return DeviceLifecycleState.sold;
      case 'RETURNED':
        return DeviceLifecycleState.returned;
      case 'DEMO':
        return DeviceLifecycleState.demo;
      case 'IN_SERVICE':
        return DeviceLifecycleState.inService;
      case 'EXCHANGED':
        return DeviceLifecycleState.exchanged;
      case 'DAMAGED':
        return DeviceLifecycleState.damaged;
      case 'RETIRED':
        return DeviceLifecycleState.retired;
      default:
        throw ArgumentError('Unknown DeviceLifecycleState: $value');
    }
  }
}

// ─── Allowed Transitions ─────────────────────────────────────────────────────

/// Typed map defining which target states are reachable from each source state.
/// Terminal states (EXCHANGED, RETIRED) have no outgoing transitions.
const Map<DeviceLifecycleState, List<DeviceLifecycleState>> allowedTransitions =
    {
      DeviceLifecycleState.inStock: [
        DeviceLifecycleState.reserved,
        DeviceLifecycleState.salePending,
        DeviceLifecycleState.demo,
        DeviceLifecycleState.damaged,
        DeviceLifecycleState.retired,
      ],
      DeviceLifecycleState.secondHand: [
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.damaged,
        DeviceLifecycleState.retired,
      ],
      DeviceLifecycleState.reserved: [
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.salePending,
        DeviceLifecycleState.damaged,
      ],
      DeviceLifecycleState.salePending: [
        DeviceLifecycleState.sold,
        DeviceLifecycleState.inStock,
      ],
      DeviceLifecycleState.sold: [
        DeviceLifecycleState.returned,
        DeviceLifecycleState.inService,
        DeviceLifecycleState.exchanged,
      ],
      DeviceLifecycleState.returned: [
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.secondHand,
        DeviceLifecycleState.damaged,
        DeviceLifecycleState.retired,
      ],
      DeviceLifecycleState.demo: [
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.sold,
        DeviceLifecycleState.damaged,
      ],
      DeviceLifecycleState.inService: [
        DeviceLifecycleState.sold,
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.damaged,
      ],
      DeviceLifecycleState.exchanged: [],
      DeviceLifecycleState.damaged: [
        DeviceLifecycleState.inStock,
        DeviceLifecycleState.retired,
      ],
      DeviceLifecycleState.retired: [],
    };

// ─── Transition Command ──────────────────────────────────────────────────────

/// Command to request a lifecycle transition on an IMEI unit.
/// Every transition requires actor identity, reason, expected version,
/// and optional evidence references.
@immutable
class TransitionCommand {
  /// Target lifecycle state.
  final DeviceLifecycleState targetState;

  /// Expected current version of the unit (optimistic concurrency).
  final int expectedVersion;

  /// Identity of the actor performing the transition.
  final String actor;

  /// Human-readable reason for the transition.
  final String reason;

  /// Optional evidence references (photos, receipts, approvals).
  final List<EvidenceReference>? evidenceRefs;

  const TransitionCommand({
    required this.targetState,
    required this.expectedVersion,
    required this.actor,
    required this.reason,
    this.evidenceRefs,
  });
}

// ─── Domain Event ────────────────────────────────────────────────────────────

/// Immutable domain event produced by a successful lifecycle transition.
/// This event is persisted as an audit trail and used to update the unit.
@immutable
class DeviceLifecycleEvent {
  /// State before the transition.
  final DeviceLifecycleState previousState;

  /// State after the transition.
  final DeviceLifecycleState newState;

  /// Actor who performed the transition.
  final String actor;

  /// Reason for the transition.
  final String reason;

  /// When the transition occurred (ISO 8601).
  final String occurredAt;

  /// Evidence references associated with this transition.
  final List<EvidenceReference> evidenceRefs;

  /// The new version number after transition.
  final int newVersion;

  const DeviceLifecycleEvent({
    required this.previousState,
    required this.newState,
    required this.actor,
    required this.reason,
    required this.occurredAt,
    required this.evidenceRefs,
    required this.newVersion,
  });
}

// ─── Domain Errors ───────────────────────────────────────────────────────────

/// Lifecycle error codes.
enum LifecycleErrorCode { versionMismatch, invalidTransition, terminalState }

/// Lifecycle transition error with structured details.
@immutable
class LifecycleError {
  final LifecycleErrorCode code;
  final String message;
  final DeviceLifecycleState? currentState;
  final DeviceLifecycleState? targetState;
  final int? expectedVersion;
  final int? actualVersion;

  const LifecycleError({
    required this.code,
    required this.message,
    this.currentState,
    this.targetState,
    this.expectedVersion,
    this.actualVersion,
  });

  @override
  String toString() => 'LifecycleError(${code.name}: $message)';
}

// ─── Result Type ─────────────────────────────────────────────────────────────

/// Sealed result for lifecycle transition validation.
sealed class TransitionResult {
  const TransitionResult();
}

/// Successful transition result containing the domain event.
@immutable
class TransitionSuccess extends TransitionResult {
  final DeviceLifecycleEvent event;
  const TransitionSuccess(this.event);
}

/// Failed transition result containing the error.
@immutable
class TransitionFailure extends TransitionResult {
  final LifecycleError error;
  const TransitionFailure(this.error);
}

// ─── Minimal Unit Shape ──────────────────────────────────────────────────────

/// Minimal unit shape required for transition validation.
/// Avoids coupling to the full ImeiUnit type.
abstract interface class TransitionableUnit {
  DeviceLifecycleState get lifecycleState;
  int get version;
}

// ─── Validation Function ─────────────────────────────────────────────────────

/// Validates a lifecycle transition command against the current unit state.
///
/// Checks:
/// 1. Expected version matches actual unit version (optimistic concurrency)
/// 2. Current state is not terminal (has outgoing transitions)
/// 3. Target state is in the allowed transitions from current state
///
/// Returns [TransitionSuccess] with a [DeviceLifecycleEvent] on success,
/// or [TransitionFailure] with a [LifecycleError] on failure.
TransitionResult validateTransition(
  TransitionableUnit unit,
  TransitionCommand command,
) {
  // 1. Version check — optimistic concurrency
  if (command.expectedVersion != unit.version) {
    return TransitionFailure(
      LifecycleError(
        code: LifecycleErrorCode.versionMismatch,
        message:
            'Expected version ${command.expectedVersion} but unit is at version ${unit.version}',
        expectedVersion: command.expectedVersion,
        actualVersion: unit.version,
        currentState: unit.lifecycleState,
        targetState: command.targetState,
      ),
    );
  }

  // 2. Check current state has outgoing transitions
  final allowed = allowedTransitions[unit.lifecycleState]!;
  if (allowed.isEmpty) {
    return TransitionFailure(
      LifecycleError(
        code: LifecycleErrorCode.terminalState,
        message:
            'Cannot transition from terminal state ${unit.lifecycleState.toWireValue()}',
        currentState: unit.lifecycleState,
        targetState: command.targetState,
      ),
    );
  }

  // 3. Check target is in allowed transitions
  if (!allowed.contains(command.targetState)) {
    return TransitionFailure(
      LifecycleError(
        code: LifecycleErrorCode.invalidTransition,
        message:
            'Transition from ${unit.lifecycleState.toWireValue()} to ${command.targetState.toWireValue()} is not allowed',
        currentState: unit.lifecycleState,
        targetState: command.targetState,
      ),
    );
  }

  // Transition is valid — produce event
  final event = DeviceLifecycleEvent(
    previousState: unit.lifecycleState,
    newState: command.targetState,
    actor: command.actor,
    reason: command.reason,
    occurredAt: DateTime.now().toUtc().toIso8601String(),
    evidenceRefs: command.evidenceRefs ?? const [],
    newVersion: unit.version + 1,
  );

  return TransitionSuccess(event);
}

/// Checks whether a given state is terminal (no outgoing transitions).
bool isTerminalState(DeviceLifecycleState state) {
  return allowedTransitions[state]?.isEmpty ?? true;
}

/// Returns the list of allowed target states from a given source state.
List<DeviceLifecycleState> getAllowedTargets(DeviceLifecycleState state) {
  return allowedTransitions[state] ?? const [];
}
