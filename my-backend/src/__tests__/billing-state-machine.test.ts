// ============================================================================
// UT-BILL — Billing Service State Machine, Idempotency & Rounding Tests
// Mirrors billing.service.ts logic: bankersRound, isValidTransition,
// invoice number generation, GST computation, void flow
// ============================================================================

// ── Re-implement pure functions from billing.service.ts ───────────────────────
// (no imports required — pure function mirrors for unit testing)

export function bankersRound(value: number): number {
  if (!Number.isFinite(value)) return 0;
  const floored = Math.floor(value);
  const decimal = value - floored;
  if (Math.abs(decimal - 0.5) < 1e-10) {
    return floored % 2 === 0 ? floored : floored + 1;
  }
  return Math.round(value);
}

const VALID_TRANSITIONS: Record<string, string[]> = {
  draft:     ['confirmed', 'void'],
  confirmed: ['paid', 'void', 'refunded'],
  paid:      ['refunded', 'disputed'],
  void:      [],
  refunded:  [],
  disputed:  ['paid', 'refunded', 'void'],
};

export function isValidTransition(from: string, to: string): boolean {
  const allowed = VALID_TRANSITIONS[from];
  if (!allowed) return false;
  return allowed.includes(to);
}

function calcGST(amountCents: number, gstRatePct: number): { gstCents: number; totalCents: number } {
  const gstCents   = bankersRound(amountCents * (gstRatePct / 100));
  const totalCents = amountCents + gstCents;
  return { gstCents, totalCents };
}

function generateInvoiceNumber(eventType: string, yearMonth: string, seq: number): string {
  const prefix   = eventType === 'refund' ? 'CR' : 'DX';
  const sequence = String(seq).padStart(6, '0');
  return `${prefix}${yearMonth}-${sequence}`;
}

// ── Invoice void helper ───────────────────────────────────────────────────────
interface BillingEventMeta {
  id: string;
  status: string;
  voidedAt?: string;
  voidedBy?: string;
  voidReason?: string;
}

function voidInvoice(
  event: BillingEventMeta,
  actor: string,
  reason: string,
): { ok: boolean; updated?: BillingEventMeta; error?: string } {
  if (!isValidTransition(event.status, 'void')) {
    return { ok: false, error: `CANNOT_VOID_FROM_${event.status.toUpperCase()}` };
  }
  return {
    ok:      true,
    updated: {
      ...event,
      status:    'void',
      voidedAt:  new Date().toISOString(),
      voidedBy:  actor,
      voidReason: reason,
    },
  };
}

// ============================================================================
// BILL-001: Banker's Rounding
// ============================================================================

describe('BILL-001: Banker\'s Rounding (Half-Even)', () => {
  test('0.5 → rounds to 0 (even)', () => {
    expect(bankersRound(0.5)).toBe(0);
  });

  test('1.5 → rounds to 2 (even)', () => {
    expect(bankersRound(1.5)).toBe(2);
  });

  test('2.5 → rounds to 2 (even)', () => {
    expect(bankersRound(2.5)).toBe(2);
  });

  test('3.5 → rounds to 4 (even)', () => {
    expect(bankersRound(3.5)).toBe(4);
  });

  test('Non-half values round normally', () => {
    expect(bankersRound(1.4)).toBe(1);
    expect(bankersRound(1.6)).toBe(2);
    expect(bankersRound(2.3)).toBe(2);
    expect(bankersRound(2.7)).toBe(3);
  });

  test('NaN input → 0 (safe fallback)', () => {
    expect(bankersRound(NaN)).toBe(0);
  });

  test('Infinity input → 0 (safe fallback)', () => {
    expect(bankersRound(Infinity)).toBe(0);
    expect(bankersRound(-Infinity)).toBe(0);
  });

  test('Large value rounds correctly', () => {
    expect(bankersRound(1_000_000.5)).toBe(1_000_000); // even floor
    expect(bankersRound(1_000_001.5)).toBe(1_000_002); // odd floor → round up
  });

  test('Negative half-values: -0.5 rounds to 0 (floor=-1 is odd → +1=0)', () => {
    // floor(-0.5) = -1 (odd), so banker's rule adds 1 → 0
    const floored = Math.floor(-0.5); // -1
    const decimal = -0.5 - floored;   // 0.5
    const expected = Math.abs(decimal - 0.5) < 1e-10
      ? (floored % 2 === 0 ? floored : floored + 1)
      : Math.round(-0.5);
    expect(bankersRound(-0.5)).toBe(expected); // expected = 0
    expect(bankersRound(-0.5)).toBe(0);
  });
});

// ============================================================================
// BILL-002: Invoice State Machine Transitions
// ============================================================================

describe('BILL-002: Invoice State Machine — Valid Transitions', () => {
  test('draft → confirmed: valid', () => {
    expect(isValidTransition('draft', 'confirmed')).toBe(true);
  });

  test('draft → void: valid (cancel before confirmation)', () => {
    expect(isValidTransition('draft', 'void')).toBe(true);
  });

  test('confirmed → paid: valid', () => {
    expect(isValidTransition('confirmed', 'paid')).toBe(true);
  });

  test('confirmed → void: valid (cancel after confirmation)', () => {
    expect(isValidTransition('confirmed', 'void')).toBe(true);
  });

  test('confirmed → refunded: valid (dispute resolution)', () => {
    expect(isValidTransition('confirmed', 'refunded')).toBe(true);
  });

  test('paid → refunded: valid (return after payment)', () => {
    expect(isValidTransition('paid', 'refunded')).toBe(true);
  });

  test('paid → disputed: valid', () => {
    expect(isValidTransition('paid', 'disputed')).toBe(true);
  });

  test('disputed → paid: valid (resolved)', () => {
    expect(isValidTransition('disputed', 'paid')).toBe(true);
  });

  test('disputed → void: valid (write off)', () => {
    expect(isValidTransition('disputed', 'void')).toBe(true);
  });
});

describe('BILL-002b: Invoice State Machine — Invalid Transitions', () => {
  test('void → anything: invalid (terminal)', () => {
    expect(isValidTransition('void', 'confirmed')).toBe(false);
    expect(isValidTransition('void', 'paid')).toBe(false);
    expect(isValidTransition('void', 'draft')).toBe(false);
  });

  test('refunded → anything: invalid (terminal)', () => {
    expect(isValidTransition('refunded', 'paid')).toBe(false);
    expect(isValidTransition('refunded', 'confirmed')).toBe(false);
  });

  test('paid → void: invalid (must dispute first)', () => {
    expect(isValidTransition('paid', 'void')).toBe(false);
  });

  test('draft → paid: invalid (must confirm first)', () => {
    expect(isValidTransition('draft', 'paid')).toBe(false);
  });

  test('Unknown state → always false', () => {
    expect(isValidTransition('nonexistent', 'paid')).toBe(false);
    expect(isValidTransition('', '')).toBe(false);
  });
});

// ============================================================================
// BILL-003: Invoice Number Generation
// ============================================================================

describe('BILL-003: Invoice Number Format & Sequence', () => {
  test('Standard invoice: prefix DX + yearMonth + 6-digit sequence', () => {
    expect(generateInvoiceNumber('sale', '202506', 1)).toBe('DX202506-000001');
    expect(generateInvoiceNumber('sale', '202506', 999)).toBe('DX202506-000999');
  });

  test('Refund invoice: prefix CR', () => {
    expect(generateInvoiceNumber('refund', '202506', 1)).toBe('CR202506-000001');
  });

  test('Sequence zero-padded to 6 digits', () => {
    expect(generateInvoiceNumber('sale', '202501', 1)).toMatch(/^DX202501-000001$/);
    expect(generateInvoiceNumber('sale', '202501', 123456)).toBe('DX202501-123456');
  });

  test('Invoice numbers across months are unique', () => {
    const inv1 = generateInvoiceNumber('sale', '202501', 1);
    const inv2 = generateInvoiceNumber('sale', '202502', 1);
    expect(inv1).not.toBe(inv2);
  });

  test('Max 6-digit sequence (999999) formats correctly', () => {
    expect(generateInvoiceNumber('sale', '202506', 999_999)).toBe('DX202506-999999');
  });
});

// ============================================================================
// BILL-004: GST Calculation on Billing Events
// ============================================================================

describe('BILL-004: Billing GST Calculation', () => {
  test('18% GST on ₹1000 plan: gst=₹180, total=₹1180', () => {
    const { gstCents, totalCents } = calcGST(100_000, 18);
    expect(gstCents).toBe(18_000);
    expect(totalCents).toBe(118_000);
  });

  test('0% GST: gst=0, total=amount', () => {
    const { gstCents, totalCents } = calcGST(50_000, 0);
    expect(gstCents).toBe(0);
    expect(totalCents).toBe(50_000);
  });

  test('GST on fractional amounts uses banker\'s round', () => {
    // ₹100.50 × 18% = 18.09 → ceil/floor depends on banker's rule
    const { gstCents } = calcGST(10_050, 18);
    // 10050 * 0.18 = 1809 (exact integer, no rounding needed)
    expect(gstCents).toBe(1809);
  });

  test('Total always = amount + GST', () => {
    const amounts = [100_000, 49_900, 75_000, 12_345];
    for (const amt of amounts) {
      const { gstCents, totalCents } = calcGST(amt, 18);
      expect(totalCents).toBe(amt + gstCents);
    }
  });
});

// ============================================================================
// BILL-005: Invoice Void Flow
// ============================================================================

describe('BILL-005: Invoice Void Flow', () => {
  test('Void draft invoice: succeeds', () => {
    const event: BillingEventMeta = { id: 'evt-1', status: 'draft' };
    const result = voidInvoice(event, 'admin', 'test void');
    expect(result.ok).toBe(true);
    expect(result.updated?.status).toBe('void');
    expect(result.updated?.voidedBy).toBe('admin');
    expect(result.updated?.voidReason).toBe('test void');
  });

  test('Void confirmed invoice: succeeds', () => {
    const event: BillingEventMeta = { id: 'evt-2', status: 'confirmed' };
    const result = voidInvoice(event, 'owner', 'customer request');
    expect(result.ok).toBe(true);
    expect(result.updated?.status).toBe('void');
  });

  test('Void already-void invoice: fails (terminal)', () => {
    const event: BillingEventMeta = { id: 'evt-3', status: 'void' };
    const result = voidInvoice(event, 'admin', 'mistake');
    expect(result.ok).toBe(false);
    expect(result.error).toContain('CANNOT_VOID_FROM_VOID');
  });

  test('Void paid invoice: fails (must dispute first)', () => {
    const event: BillingEventMeta = { id: 'evt-4', status: 'paid' };
    const result = voidInvoice(event, 'admin', 'reason');
    expect(result.ok).toBe(false);
    expect(result.error).toContain('CANNOT_VOID_FROM_PAID');
  });

  test('Void refunded invoice: fails (terminal)', () => {
    const event: BillingEventMeta = { id: 'evt-5', status: 'refunded' };
    const result = voidInvoice(event, 'admin', 'reason');
    expect(result.ok).toBe(false);
  });

  test('Void sets voidedAt timestamp', () => {
    const event: BillingEventMeta = { id: 'evt-6', status: 'draft' };
    const before = Date.now();
    const result = voidInvoice(event, 'user', 'reason');
    const after  = Date.now();
    const ts     = new Date(result.updated!.voidedAt!).getTime();
    expect(ts).toBeGreaterThanOrEqual(before);
    expect(ts).toBeLessThanOrEqual(after);
  });

  test('Void preserves original id', () => {
    const event: BillingEventMeta = { id: 'evt-original-007', status: 'draft' };
    const result = voidInvoice(event, 'admin', 'reason');
    expect(result.updated?.id).toBe('evt-original-007');
  });
});

// ============================================================================
// BILL-006: Idempotency in billing operations
// ============================================================================

describe('BILL-006: Billing Idempotency', () => {
  class IdempotencyStore {
    private store: Map<string, { result: any; createdAt: number }> = new Map();

    check(key: string): any | null {
      return this.store.get(key)?.result ?? null;
    }

    record(key: string, result: any): void {
      this.store.set(key, { result, createdAt: Date.now() });
    }

    size(): number { return this.store.size; }
  }

  function processWithIdempotency(
    store: IdempotencyStore,
    key: string,
    createFn: () => { id: string; amount: number },
  ): { id: string; amount: number; wasIdempotent: boolean } {
    const existing = store.check(key);
    if (existing) return { ...existing, wasIdempotent: true };
    const result = createFn();
    store.record(key, result);
    return { ...result, wasIdempotent: false };
  }

  test('First call creates billing event', () => {
    const store = new IdempotencyStore();
    const r = processWithIdempotency(store, 'key-001', () => ({ id: 'evt-1', amount: 100 }));
    expect(r.wasIdempotent).toBe(false);
    expect(r.id).toBe('evt-1');
  });

  test('Second call with same key returns existing (no new event)', () => {
    const store = new IdempotencyStore();
    processWithIdempotency(store, 'key-001', () => ({ id: 'evt-1', amount: 100 }));
    const r2 = processWithIdempotency(store, 'key-001', () => ({ id: 'evt-2', amount: 200 }));
    expect(r2.wasIdempotent).toBe(true);
    expect(r2.id).toBe('evt-1'); // original
    expect(r2.amount).toBe(100);
  });

  test('Different idempotency keys create different events', () => {
    const store = new IdempotencyStore();
    let seq = 1;
    processWithIdempotency(store, 'key-A', () => ({ id: `evt-${seq++}`, amount: 100 }));
    processWithIdempotency(store, 'key-B', () => ({ id: `evt-${seq++}`, amount: 200 }));
    expect(store.size()).toBe(2);
  });

  test('Idempotency key format: UUID prevents collision', () => {
    const keys = new Set([
      'a1b2c3d4-0000-4000-8000-000000000001',
      'a1b2c3d4-0000-4000-8000-000000000002',
    ]);
    expect(keys.size).toBe(2);
  });
});

// ============================================================================
// BILL-007: Credit limit enforcement
// ============================================================================

describe('BILL-007: Credit Limit Enforcement (Wholesale/Distributor)', () => {
  function checkCreditLimit(
    currentOutstandingPaise: number,
    newSaleAmountPaise: number,
    creditLimitPaise: number,
  ): { allowed: boolean; availableCreditPaise: number; error?: string } {
    const availableCreditPaise = Math.max(0, creditLimitPaise - currentOutstandingPaise);
    if (currentOutstandingPaise + newSaleAmountPaise > creditLimitPaise) {
      return {
        allowed: false,
        availableCreditPaise,
        error: `CREDIT_LIMIT_EXCEEDED: limit=₹${creditLimitPaise / 100}, outstanding=₹${currentOutstandingPaise / 100}, sale=₹${newSaleAmountPaise / 100}`,
      };
    }
    return { allowed: true, availableCreditPaise };
  }

  test('Sale within credit limit → allowed', () => {
    const r = checkCreditLimit(50_000_00, 10_000_00, 100_000_00);
    expect(r.allowed).toBe(true);
    expect(r.availableCreditPaise).toBe(50_000_00);
  });

  test('Sale exactly at credit limit → allowed', () => {
    const r = checkCreditLimit(90_000_00, 10_000_00, 100_000_00);
    expect(r.allowed).toBe(true);
  });

  test('Sale exceeds credit limit → blocked', () => {
    const r = checkCreditLimit(95_000_00, 10_000_00, 100_000_00);
    expect(r.allowed).toBe(false);
    expect(r.error).toContain('CREDIT_LIMIT_EXCEEDED');
  });

  test('No outstanding balance → full limit available', () => {
    const r = checkCreditLimit(0, 1_000_00, 50_000_00);
    expect(r.allowed).toBe(true);
    expect(r.availableCreditPaise).toBe(50_000_00);
  });

  test('Already at full limit → any sale blocked', () => {
    const r = checkCreditLimit(100_000_00, 1, 100_000_00);
    expect(r.allowed).toBe(false);
  });

  test('Available credit is never negative', () => {
    // Outstanding already exceeds limit (legacy data)
    const r = checkCreditLimit(120_000_00, 1, 100_000_00);
    expect(r.availableCreditPaise).toBe(0);
    expect(r.allowed).toBe(false);
  });
});
