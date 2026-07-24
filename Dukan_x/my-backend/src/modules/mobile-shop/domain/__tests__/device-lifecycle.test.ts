/**
 * Device Lifecycle Unit Tests
 *
 * Validates: Requirements 3.10–3.11, 4.5–4.7, 5.2–5.4
 */

import {
  DeviceLifecycleState,
  ALLOWED_TRANSITIONS,
  LifecycleErrorCode,
  validateTransition,
  isTerminalState,
  getAllowedTargets,
} from '../device-lifecycle';
import type { TransitionableUnit, TransitionCommand } from '../device-lifecycle';
import {
  createImeiUnit,
  applyTransition,
  DeviceCondition,
  OwnershipSource,
} from '../imei-unit';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function makeUnit(
  state: DeviceLifecycleState,
  version = 1,
): TransitionableUnit {
  return { lifecycleState: state, version };
}

function makeCommand(
  targetState: DeviceLifecycleState,
  expectedVersion = 1,
): TransitionCommand {
  return {
    targetState,
    expectedVersion,
    actor: 'test-actor',
    reason: 'unit test',
  };
}

// ─── Allowed Transitions ─────────────────────────────────────────────────────

describe('validateTransition — allowed transitions', () => {
  // Build test cases for every allowed edge in the graph
  const allowedCases: Array<{
    from: DeviceLifecycleState;
    to: DeviceLifecycleState;
  }> = [];

  for (const [source, targets] of Object.entries(ALLOWED_TRANSITIONS)) {
    for (const target of targets) {
      allowedCases.push({
        from: source as DeviceLifecycleState,
        to: target,
      });
    }
  }

  it.each(allowedCases)(
    'allows transition from $from to $to',
    ({ from, to }) => {
      const unit = makeUnit(from);
      const command = makeCommand(to);
      const result = validateTransition(unit, command);
      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.value.previousState).toBe(from);
        expect(result.value.newState).toBe(to);
        expect(result.value.newVersion).toBe(2);
      }
    },
  );
});

// ─── Forbidden Transitions ───────────────────────────────────────────────────

describe('validateTransition — forbidden transitions', () => {
  // Build test cases for all non-terminal states with forbidden targets
  const forbiddenCases: Array<{
    from: DeviceLifecycleState;
    to: DeviceLifecycleState;
  }> = [];

  const allStates = Object.values(DeviceLifecycleState);

  for (const [source, allowed] of Object.entries(ALLOWED_TRANSITIONS)) {
    // Skip terminal states (tested separately)
    if ((allowed as readonly DeviceLifecycleState[]).length === 0) continue;

    for (const target of allStates) {
      if (!(allowed as readonly DeviceLifecycleState[]).includes(target) && target !== source) {
        forbiddenCases.push({
          from: source as DeviceLifecycleState,
          to: target,
        });
      }
    }
  }

  it.each(forbiddenCases)(
    'rejects transition from $from to $to with INVALID_TRANSITION',
    ({ from, to }) => {
      const unit = makeUnit(from);
      const command = makeCommand(to);
      const result = validateTransition(unit, command);
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe(LifecycleErrorCode.INVALID_TRANSITION);
      }
    },
  );
});

// ─── Terminal States ─────────────────────────────────────────────────────────

describe('validateTransition — terminal states', () => {
  const terminalStates = [
    DeviceLifecycleState.EXCHANGED,
    DeviceLifecycleState.RETIRED,
  ];

  it.each(terminalStates)(
    'rejects any transition from terminal state %s with TERMINAL_STATE',
    (state) => {
      const unit = makeUnit(state);
      const command = makeCommand(DeviceLifecycleState.IN_STOCK);
      const result = validateTransition(unit, command);
      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe(LifecycleErrorCode.TERMINAL_STATE);
      }
    },
  );
});

// ─── Version Mismatch ────────────────────────────────────────────────────────

describe('validateTransition — version mismatch', () => {
  it('rejects when expectedVersion does not match unit version', () => {
    const unit = makeUnit(DeviceLifecycleState.IN_STOCK, 5);
    const command = makeCommand(DeviceLifecycleState.RESERVED, 3);
    const result = validateTransition(unit, command);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe(LifecycleErrorCode.VERSION_MISMATCH);
      expect(result.error.details.expectedVersion).toBe(3);
      expect(result.error.details.actualVersion).toBe(5);
    }
  });
});

// ─── Event Production ────────────────────────────────────────────────────────

describe('validateTransition — event production', () => {
  it('produces correct event with previousState, newState, newVersion', () => {
    const unit = makeUnit(DeviceLifecycleState.IN_STOCK, 3);
    const command: TransitionCommand = {
      targetState: DeviceLifecycleState.RESERVED,
      expectedVersion: 3,
      actor: 'shop-owner',
      reason: 'Customer reserved',
      evidenceRefs: [{
        referenceId: 'ref-1',
        storageKey: 's3://bucket/key',
        contentType: 'image/jpeg',
        digest: 'abc123',
        uploadedAt: '2024-06-15T09:00:00.000Z',
      }],
    };
    const result = validateTransition(unit, command);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.previousState).toBe(DeviceLifecycleState.IN_STOCK);
      expect(result.value.newState).toBe(DeviceLifecycleState.RESERVED);
      expect(result.value.newVersion).toBe(4);
      expect(result.value.actor).toBe('shop-owner');
      expect(result.value.reason).toBe('Customer reserved');
      expect(result.value.evidenceRefs).toHaveLength(1);
      expect(result.value.occurredAt).toBeTruthy();
    }
  });
});

// ─── applyTransition ─────────────────────────────────────────────────────────

describe('applyTransition', () => {
  it('produces unit with new state and incremented version', () => {
    const baseParams = {
      tenantId: 'tenant-1',
      entityId: 'entity-1',
      imei: '490154203237518',
      condition: DeviceCondition.NEW,
      ownershipSource: OwnershipSource.PURCHASED_NEW,
      brand: 'Samsung',
      model: 'Galaxy S24',
      acquisitionCost: { amountMinorUnits: 5000000, currency: 'INR' },
      salePrice: { amountMinorUnits: 6000000, currency: 'INR' },
    };

    const unit = createImeiUnit(baseParams);
    expect(unit.lifecycleState).toBe(DeviceLifecycleState.IN_STOCK);
    expect(unit.version).toBe(1);

    const event = {
      previousState: DeviceLifecycleState.IN_STOCK,
      newState: DeviceLifecycleState.RESERVED,
      actor: 'test',
      reason: 'test',
      occurredAt: '2024-06-15T10:00:00.000Z',
      evidenceRefs: [] as const,
      newVersion: 2,
    };

    const updated = applyTransition(unit, event);
    expect(updated.lifecycleState).toBe(DeviceLifecycleState.RESERVED);
    expect(updated.version).toBe(2);
    expect(updated.updatedAt).toBe('2024-06-15T10:00:00.000Z');
    // Unchanged fields
    expect(updated.imei).toBe(unit.imei);
    expect(updated.tenantId).toBe(unit.tenantId);
  });
});

// ─── createImeiUnit factory ──────────────────────────────────────────────────

describe('createImeiUnit', () => {
  const baseParams = {
    tenantId: 'tenant-1',
    entityId: 'entity-1',
    imei: '490154203237518',
    condition: DeviceCondition.NEW,
    ownershipSource: OwnershipSource.PURCHASED_NEW,
    brand: 'Samsung',
    model: 'Galaxy S24',
    acquisitionCost: { amountMinorUnits: 5000000, currency: 'INR' },
    salePrice: { amountMinorUnits: 6000000, currency: 'INR' },
  };

  it('defaults to IN_STOCK state', () => {
    const unit = createImeiUnit(baseParams);
    expect(unit.lifecycleState).toBe(DeviceLifecycleState.IN_STOCK);
  });

  it('uses SECOND_HAND state when isSecondHand is true', () => {
    const unit = createImeiUnit({ ...baseParams, isSecondHand: true });
    expect(unit.lifecycleState).toBe(DeviceLifecycleState.SECOND_HAND);
  });

  it('starts at version 1', () => {
    const unit = createImeiUnit(baseParams);
    expect(unit.version).toBe(1);
  });
});

// ─── isTerminalState ─────────────────────────────────────────────────────────

describe('isTerminalState', () => {
  it('returns true for EXCHANGED', () => {
    expect(isTerminalState(DeviceLifecycleState.EXCHANGED)).toBe(true);
  });

  it('returns true for RETIRED', () => {
    expect(isTerminalState(DeviceLifecycleState.RETIRED)).toBe(true);
  });

  const nonTerminalStates = Object.values(DeviceLifecycleState).filter(
    (s) => s !== DeviceLifecycleState.EXCHANGED && s !== DeviceLifecycleState.RETIRED,
  );

  it.each(nonTerminalStates)('returns false for %s', (state) => {
    expect(isTerminalState(state)).toBe(false);
  });
});

// ─── getAllowedTargets ───────────────────────────────────────────────────────

describe('getAllowedTargets', () => {
  it.each(Object.values(DeviceLifecycleState))(
    'returns correct list for %s',
    (state) => {
      const targets = getAllowedTargets(state);
      expect(targets).toEqual(ALLOWED_TRANSITIONS[state]);
    },
  );
});
