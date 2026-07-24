/**
 * Device Lifecycle — Domain Logic
 *
 * Pure domain logic for IMEI unit lifecycle transitions.
 * Models all states, defines the allowed transition graph,
 * validates commands against current state and version,
 * and produces immutable domain events.
 *
 * Requirements: 3.5–3.6, 3.10–3.11, 4.1, 4.5–4.7, 4.9, 5.2–5.4
 */

import type { EvidenceReference } from '../schemas/common.schema';

// ─── Lifecycle States ────────────────────────────────────────────────────────

/**
 * All canonical lifecycle states for an IMEI unit.
 * SECOND_HAND is an initial intake state for used devices.
 */
export enum DeviceLifecycleState {
  IN_STOCK = 'IN_STOCK',
  SECOND_HAND = 'SECOND_HAND',
  RESERVED = 'RESERVED',
  SALE_PENDING = 'SALE_PENDING',
  SOLD = 'SOLD',
  RETURNED = 'RETURNED',
  DEMO = 'DEMO',
  IN_SERVICE = 'IN_SERVICE',
  EXCHANGED = 'EXCHANGED',
  DAMAGED = 'DAMAGED',
  RETIRED = 'RETIRED',
}

// ─── Allowed Transitions ─────────────────────────────────────────────────────

/**
 * Typed map defining which target states are reachable from each source state.
 * Terminal states (EXCHANGED, RETIRED) have no outgoing transitions.
 */
export const ALLOWED_TRANSITIONS: Readonly<
  Record<DeviceLifecycleState, readonly DeviceLifecycleState[]>
> = {
  [DeviceLifecycleState.IN_STOCK]: [
    DeviceLifecycleState.RESERVED,
    DeviceLifecycleState.SALE_PENDING,
    DeviceLifecycleState.DEMO,
    DeviceLifecycleState.DAMAGED,
    DeviceLifecycleState.RETIRED,
  ],
  [DeviceLifecycleState.SECOND_HAND]: [
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.DAMAGED,
    DeviceLifecycleState.RETIRED,
  ],
  [DeviceLifecycleState.RESERVED]: [
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.SALE_PENDING,
    DeviceLifecycleState.DAMAGED,
  ],
  [DeviceLifecycleState.SALE_PENDING]: [
    DeviceLifecycleState.SOLD,
    DeviceLifecycleState.IN_STOCK,
  ],
  [DeviceLifecycleState.SOLD]: [
    DeviceLifecycleState.RETURNED,
    DeviceLifecycleState.IN_SERVICE,
    DeviceLifecycleState.EXCHANGED,
  ],
  [DeviceLifecycleState.RETURNED]: [
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.SECOND_HAND,
    DeviceLifecycleState.DAMAGED,
    DeviceLifecycleState.RETIRED,
  ],
  [DeviceLifecycleState.DEMO]: [
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.SOLD,
    DeviceLifecycleState.DAMAGED,
  ],
  [DeviceLifecycleState.IN_SERVICE]: [
    DeviceLifecycleState.SOLD,
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.DAMAGED,
  ],
  [DeviceLifecycleState.EXCHANGED]: [],
  [DeviceLifecycleState.DAMAGED]: [
    DeviceLifecycleState.IN_STOCK,
    DeviceLifecycleState.RETIRED,
  ],
  [DeviceLifecycleState.RETIRED]: [],
};

// ─── Transition Command ──────────────────────────────────────────────────────

/**
 * Command to request a lifecycle transition on an IMEI unit.
 * Every transition requires actor identity, reason, expected version,
 * and optional evidence references.
 */
export interface TransitionCommand {
  /** Target lifecycle state */
  readonly targetState: DeviceLifecycleState;
  /** Expected current version of the unit (optimistic concurrency) */
  readonly expectedVersion: number;
  /** Identity of the actor performing the transition */
  readonly actor: string;
  /** Human-readable reason for the transition */
  readonly reason: string;
  /** Optional evidence references (photos, receipts, approvals) */
  readonly evidenceRefs?: readonly EvidenceReference[];
}

// ─── Domain Event ────────────────────────────────────────────────────────────

/**
 * Immutable domain event produced by a successful lifecycle transition.
 * This event is persisted as an audit trail and used to update the unit.
 */
export interface DeviceLifecycleEvent {
  /** State before the transition */
  readonly previousState: DeviceLifecycleState;
  /** State after the transition */
  readonly newState: DeviceLifecycleState;
  /** Actor who performed the transition */
  readonly actor: string;
  /** Reason for the transition */
  readonly reason: string;
  /** When the transition occurred (ISO 8601) */
  readonly occurredAt: string;
  /** Evidence references associated with this transition */
  readonly evidenceRefs: readonly EvidenceReference[];
  /** The new version number after transition */
  readonly newVersion: number;
}

// ─── Domain Errors ───────────────────────────────────────────────────────────

export enum LifecycleErrorCode {
  VERSION_MISMATCH = 'VERSION_MISMATCH',
  INVALID_TRANSITION = 'INVALID_TRANSITION',
  TERMINAL_STATE = 'TERMINAL_STATE',
}

export interface LifecycleError {
  readonly code: LifecycleErrorCode;
  readonly message: string;
  readonly details: {
    readonly currentState?: DeviceLifecycleState;
    readonly targetState?: DeviceLifecycleState;
    readonly expectedVersion?: number;
    readonly actualVersion?: number;
  };
}

// ─── Result Type ─────────────────────────────────────────────────────────────

export type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

// ─── Validation Function ─────────────────────────────────────────────────────

/**
 * Minimal unit shape required for transition validation.
 * This avoids coupling to the full ImeiUnit type.
 */
export interface TransitionableUnit {
  readonly lifecycleState: DeviceLifecycleState;
  readonly version: number;
}

/**
 * Validates a lifecycle transition command against the current unit state.
 *
 * Checks:
 * 1. Expected version matches actual unit version (optimistic concurrency)
 * 2. Current state is not terminal (has outgoing transitions)
 * 3. Target state is in the allowed transitions from current state
 *
 * Returns a DeviceLifecycleEvent on success, or a LifecycleError on failure.
 */
export function validateTransition(
  unit: TransitionableUnit,
  command: TransitionCommand,
): Result<DeviceLifecycleEvent, LifecycleError> {
  // 1. Version check — optimistic concurrency
  if (command.expectedVersion !== unit.version) {
    return {
      ok: false,
      error: {
        code: LifecycleErrorCode.VERSION_MISMATCH,
        message: `Expected version ${command.expectedVersion} but unit is at version ${unit.version}`,
        details: {
          expectedVersion: command.expectedVersion,
          actualVersion: unit.version,
          currentState: unit.lifecycleState,
          targetState: command.targetState,
        },
      },
    };
  }

  // 2. Check current state has outgoing transitions
  const allowed = ALLOWED_TRANSITIONS[unit.lifecycleState];
  if (allowed.length === 0) {
    return {
      ok: false,
      error: {
        code: LifecycleErrorCode.TERMINAL_STATE,
        message: `Cannot transition from terminal state ${unit.lifecycleState}`,
        details: {
          currentState: unit.lifecycleState,
          targetState: command.targetState,
        },
      },
    };
  }

  // 3. Check target is in allowed transitions
  if (!allowed.includes(command.targetState)) {
    return {
      ok: false,
      error: {
        code: LifecycleErrorCode.INVALID_TRANSITION,
        message: `Transition from ${unit.lifecycleState} to ${command.targetState} is not allowed`,
        details: {
          currentState: unit.lifecycleState,
          targetState: command.targetState,
        },
      },
    };
  }

  // Transition is valid — produce event
  const event: DeviceLifecycleEvent = {
    previousState: unit.lifecycleState,
    newState: command.targetState,
    actor: command.actor,
    reason: command.reason,
    occurredAt: new Date().toISOString(),
    evidenceRefs: command.evidenceRefs ?? [],
    newVersion: unit.version + 1,
  };

  return { ok: true, value: event };
}

/**
 * Checks whether a given state is terminal (no outgoing transitions).
 */
export function isTerminalState(state: DeviceLifecycleState): boolean {
  return ALLOWED_TRANSITIONS[state].length === 0;
}

/**
 * Returns the list of allowed target states from a given source state.
 */
export function getAllowedTargets(
  state: DeviceLifecycleState,
): readonly DeviceLifecycleState[] {
  return ALLOWED_TRANSITIONS[state];
}
