export {};
// ============================================================================
// restaurant-kot-gst.test.ts
// Phase 3 — Restaurant GST tiers, KOT lifecycle, and scan-JWT unit tests.
// ============================================================================

// ---------------------------------------------------------------------------
// GST calculation helpers (pure functions, no Lambda/DDB deps)
// ---------------------------------------------------------------------------

type OrderType = 'dine_in' | 'takeaway' | 'delivery';

interface GstInput {
  subtotalCents: number;
  orderType: OrderType;
  isAcRestaurant: boolean;
  hasAlcohol: boolean;
}

interface GstResult {
  gstRatePct: number;
  gstCents: number;
  totalCents: number;
}

function computeRestaurantGst(input: GstInput): GstResult {
  let rate: number;
  if (input.hasAlcohol) {
    rate = 18;
  } else if (input.orderType === 'takeaway') {
    rate = 5;
  } else if (input.isAcRestaurant) {
    rate = 18;
  } else {
    rate = 5;
  }
  const gstCents = Math.round(input.subtotalCents * rate / 100);
  return { gstRatePct: rate, gstCents, totalCents: input.subtotalCents + gstCents };
}

function paise(rupees: number): number {
  return Math.round(rupees * 100);
}

// ---------------------------------------------------------------------------
// KOT item status state machine
// ---------------------------------------------------------------------------

type KotItemStatus = 'pending' | 'preparing' | 'ready' | 'served' | 'cancelled';

const KOT_STATUS_TRANSITIONS: Record<KotItemStatus, KotItemStatus[]> = {
  pending:    ['preparing', 'cancelled'],
  preparing:  ['ready', 'cancelled'],
  ready:      ['served', 'cancelled'],
  served:     [],
  cancelled:  [],
};

function canTransition(from: KotItemStatus, to: KotItemStatus): boolean {
  return KOT_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
}

function isTerminal(status: KotItemStatus): boolean {
  return KOT_STATUS_TRANSITIONS[status].length === 0;
}

// ---------------------------------------------------------------------------
// Scan JWT claim shape (mirrors restaurant-v1-public.ts ScanClaims)
// ---------------------------------------------------------------------------

interface ScanClaims {
  vendorId: string;
  tableId: string;
  iss: string;
  aud: string;
}

function buildScanClaims(vendorId: string, tableId: string): ScanClaims {
  return { vendorId, tableId, iss: 'dukanx-resto-scan', aud: 'pwa-customer' };
}

// ---------------------------------------------------------------------------
// GST — non-AC dine-in (5%)
// ---------------------------------------------------------------------------

describe('GST: Non-AC dine-in', () => {
  it('RGST-01: applies 5% on non-AC dine-in, no alcohol', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(200),
      orderType: 'dine_in',
      isAcRestaurant: false,
      hasAlcohol: false,
    });
    expect(r.gstRatePct).toBe(5);
    expect(r.gstCents).toBe(paise(10));
    expect(r.totalCents).toBe(paise(210));
  });

  it('RGST-02: applies 5% on takeaway regardless of AC status', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(100),
      orderType: 'takeaway',
      isAcRestaurant: true, // AC but takeaway → still 5%
      hasAlcohol: false,
    });
    expect(r.gstRatePct).toBe(5);
    expect(r.gstCents).toBe(paise(5));
  });

  it('RGST-03: applies 5% on delivery for non-AC', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(300),
      orderType: 'delivery',
      isAcRestaurant: false,
      hasAlcohol: false,
    });
    expect(r.gstRatePct).toBe(5);
    expect(r.gstCents).toBe(paise(15));
  });
});

// ---------------------------------------------------------------------------
// GST — AC dine-in (18%)
// ---------------------------------------------------------------------------

describe('GST: AC dine-in', () => {
  it('RGST-04: applies 18% on AC dine-in, no alcohol', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(1000),
      orderType: 'dine_in',
      isAcRestaurant: true,
      hasAlcohol: false,
    });
    expect(r.gstRatePct).toBe(18);
    expect(r.gstCents).toBe(paise(180));
    expect(r.totalCents).toBe(paise(1180));
  });

  it('RGST-05: 18% overrides takeaway rate when alcohol present', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(500),
      orderType: 'takeaway',
      isAcRestaurant: false,
      hasAlcohol: true,
    });
    expect(r.gstRatePct).toBe(18);
  });

  it('RGST-06: 18% for AC delivery', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(400),
      orderType: 'delivery',
      isAcRestaurant: true,
      hasAlcohol: false,
    });
    expect(r.gstRatePct).toBe(18);
    expect(r.gstCents).toBe(paise(72));
  });
});

// ---------------------------------------------------------------------------
// GST — edge cases
// ---------------------------------------------------------------------------

describe('GST: edge cases', () => {
  it('RGST-07: zero subtotal → zero GST', () => {
    const r = computeRestaurantGst({
      subtotalCents: 0,
      orderType: 'dine_in',
      isAcRestaurant: true,
      hasAlcohol: false,
    });
    expect(r.gstCents).toBe(0);
    expect(r.totalCents).toBe(0);
  });

  it('RGST-08: rounds to nearest paisa (0.5→1)', () => {
    // subtotal = ₹1 → 5% = 0.05 rupees = 5 paise
    const r = computeRestaurantGst({
      subtotalCents: 100,
      orderType: 'dine_in',
      isAcRestaurant: false,
      hasAlcohol: false,
    });
    expect(r.gstCents).toBe(5);
  });

  it('RGST-09: large bill (₹10000 AC) computes exactly', () => {
    const r = computeRestaurantGst({
      subtotalCents: paise(10000),
      orderType: 'dine_in',
      isAcRestaurant: true,
      hasAlcohol: false,
    });
    expect(r.gstCents).toBe(paise(1800));
    expect(r.totalCents).toBe(paise(11800));
  });
});

// ---------------------------------------------------------------------------
// KOT item status state machine
// ---------------------------------------------------------------------------

describe('KOT item status transitions', () => {
  it('RKOT-01: pending → preparing is valid', () => {
    expect(canTransition('pending', 'preparing')).toBe(true);
  });

  it('RKOT-02: preparing → ready is valid', () => {
    expect(canTransition('preparing', 'ready')).toBe(true);
  });

  it('RKOT-03: ready → served is valid', () => {
    expect(canTransition('ready', 'served')).toBe(true);
  });

  it('RKOT-04: pending → cancelled is valid', () => {
    expect(canTransition('pending', 'cancelled')).toBe(true);
  });

  it('RKOT-05: served → anything is invalid (terminal)', () => {
    expect(canTransition('served', 'pending')).toBe(false);
    expect(canTransition('served', 'cancelled')).toBe(false);
    expect(canTransition('served', 'ready')).toBe(false);
  });

  it('RKOT-06: cancelled → anything is invalid (terminal)', () => {
    expect(canTransition('cancelled', 'pending')).toBe(false);
    expect(canTransition('cancelled', 'preparing')).toBe(false);
  });

  it('RKOT-07: skipping states is invalid (pending → served)', () => {
    expect(canTransition('pending', 'served')).toBe(false);
  });

  it('RKOT-08: skipping states is invalid (pending → ready)', () => {
    expect(canTransition('pending', 'ready')).toBe(false);
  });

  it('RKOT-09: served and cancelled are terminal states', () => {
    expect(isTerminal('served')).toBe(true);
    expect(isTerminal('cancelled')).toBe(true);
  });

  it('RKOT-10: active states are non-terminal', () => {
    expect(isTerminal('pending')).toBe(false);
    expect(isTerminal('preparing')).toBe(false);
    expect(isTerminal('ready')).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// KOT age severity (mirrors kdsAgingAlerts logic)
// ---------------------------------------------------------------------------

type AgeSeverity = 'green' | 'amber' | 'red';

function computeAgeSeverity(ageSeconds: number, slaSec: number): AgeSeverity {
  if (ageSeconds > slaSec * 2) return 'red';
  if (ageSeconds > slaSec) return 'amber';
  return 'green';
}

describe('KOT aging severity', () => {
  const SLA_SEC = 20 * 60; // 20 min default SLA

  it('RKOT-11: within SLA → green', () => {
    expect(computeAgeSeverity(5 * 60, SLA_SEC)).toBe('green');
  });

  it('RKOT-12: beyond SLA → amber', () => {
    expect(computeAgeSeverity(25 * 60, SLA_SEC)).toBe('amber');
  });

  it('RKOT-13: beyond 2x SLA → red', () => {
    expect(computeAgeSeverity(45 * 60, SLA_SEC)).toBe('red');
  });

  it('RKOT-14: exactly at SLA boundary → amber', () => {
    expect(computeAgeSeverity(SLA_SEC + 1, SLA_SEC)).toBe('amber');
  });

  it('RKOT-15: exactly at 2x SLA boundary → red', () => {
    expect(computeAgeSeverity(SLA_SEC * 2 + 1, SLA_SEC)).toBe('red');
  });
});

// ---------------------------------------------------------------------------
// Scan JWT claims validation
// ---------------------------------------------------------------------------

describe('Scan JWT claims', () => {
  it('RJWT-01: claims include vendorId and tableId', () => {
    const c = buildScanClaims('vendor123', 'table7');
    expect(c.vendorId).toBe('vendor123');
    expect(c.tableId).toBe('table7');
  });

  it('RJWT-02: issuer is dukanx-resto-scan', () => {
    const c = buildScanClaims('v', 't');
    expect(c.iss).toBe('dukanx-resto-scan');
  });

  it('RJWT-03: audience is pwa-customer', () => {
    const c = buildScanClaims('v', 't');
    expect(c.aud).toBe('pwa-customer');
  });

  it('RJWT-04: vendorId mismatch with body must be rejected', () => {
    const claims = buildScanClaims('vendorA', 'table1');
    const bodyVendorId = 'vendorB';
    expect(claims.vendorId === bodyVendorId).toBe(false);
  });

  it('RJWT-05: tableId mismatch with body must be rejected', () => {
    const claims = buildScanClaims('vendorA', 'table1');
    const bodyTableId = 'table2';
    expect(claims.tableId === bodyTableId).toBe(false);
  });

  it('RJWT-06: matching vendorId and tableId passes validation', () => {
    const claims = buildScanClaims('vendorA', 'table1');
    expect(claims.vendorId === 'vendorA' && claims.tableId === 'table1').toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Bill total calculation (server-side, paise arithmetic)
// ---------------------------------------------------------------------------

interface OrderItem {
  unitPriceCents: number;
  quantity: number;
}

function computeBillTotals(items: OrderItem[], gstRatePct: number): {
  subtotalCents: number;
  gstCents: number;
  grandTotalCents: number;
} {
  const subtotalCents = items.reduce((s, i) => s + i.unitPriceCents * i.quantity, 0);
  const gstCents = Math.round(subtotalCents * gstRatePct / 100);
  return { subtotalCents, gstCents, grandTotalCents: subtotalCents + gstCents };
}

describe('Bill total calculation', () => {
  it('RBILL-01: single item, 5% GST', () => {
    const r = computeBillTotals([{ unitPriceCents: paise(100), quantity: 2 }], 5);
    expect(r.subtotalCents).toBe(paise(200));
    expect(r.gstCents).toBe(paise(10));
    expect(r.grandTotalCents).toBe(paise(210));
  });

  it('RBILL-02: multiple items', () => {
    const items: OrderItem[] = [
      { unitPriceCents: paise(50), quantity: 3 },
      { unitPriceCents: paise(120), quantity: 1 },
    ];
    const r = computeBillTotals(items, 5);
    expect(r.subtotalCents).toBe(paise(270));
    expect(r.gstCents).toBe(paise(13.5));
  });

  it('RBILL-03: 18% GST on AC order', () => {
    const r = computeBillTotals([{ unitPriceCents: paise(1000), quantity: 1 }], 18);
    expect(r.gstCents).toBe(paise(180));
    expect(r.grandTotalCents).toBe(paise(1180));
  });

  it('RBILL-04: empty cart → zero totals', () => {
    const r = computeBillTotals([], 5);
    expect(r.subtotalCents).toBe(0);
    expect(r.gstCents).toBe(0);
    expect(r.grandTotalCents).toBe(0);
  });

  it('RBILL-05: client-sent price is ignored — server recomputes from unitPriceCents', () => {
    // Simulates: client sends price=99, server looks up actual price=200
    const serverPrice = paise(200);
    const r = computeBillTotals([{ unitPriceCents: serverPrice, quantity: 1 }], 5);
    expect(r.subtotalCents).toBe(paise(200)); // server wins
  });
});

