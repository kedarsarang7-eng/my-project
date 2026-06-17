export {};
// ============================================================================
// UT-BIZ — Specialized Business Logic Unit Tests
// Coverage: IMEI, Drug schedule, Commission, Fuel delta, Crate deposit,
//           Loyalty points, KOT merge/split, Tailoring notes,
//           Consultation billing, Job sheet state machine
// ============================================================================

// ── IMEI Validation ───────────────────────────────────────────────────────────

function luhnCheck(imei: string): boolean {
  if (!/^\d{15}$/.test(imei)) return false;
  let sum = 0;
  for (let i = 0; i < 15; i++) {
    let d = parseInt(imei[i], 10);
    if (i % 2 === 1) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
  }
  return sum % 10 === 0;
}

function validateIMEI(imei: string, existingIMEIs: Set<string>): { valid: boolean; error?: string } {
  if (!imei || imei.trim() === '') return { valid: false, error: 'IMEI_REQUIRED' };
  if (!/^\d{15}$/.test(imei)) return { valid: false, error: 'IMEI_INVALID_FORMAT' };
  if (!luhnCheck(imei)) return { valid: false, error: 'IMEI_LUHN_FAIL' };
  if (existingIMEIs.has(imei)) return { valid: false, error: 'IMEI_DUPLICATE' };
  return { valid: true };
}

// ── Drug Schedule Classification ─────────────────────────────────────────────

enum DrugSchedule { H = 'H', H1 = 'H1', X = 'X', OTC = 'OTC' }

function classifyDrug(saltName: string, scheduleMap: Record<string, DrugSchedule>): DrugSchedule {
  return scheduleMap[saltName.toLowerCase()] ?? DrugSchedule.OTC;
}

function requiresPrescription(schedule: DrugSchedule): boolean {
  return [DrugSchedule.H, DrugSchedule.H1, DrugSchedule.X].includes(schedule);
}

function isNarcoticSchedule(schedule: DrugSchedule): boolean {
  return schedule === DrugSchedule.X;
}

// ── Commission Calculation (Vegetable Broker) ─────────────────────────────────

function calculateCommission(
  invoiceValuePaise: number,
  commissionRateBps: number, // basis points (1% = 100)
): { commissionPaise: number; netPaise: number } {
  const commissionPaise = Math.round(invoiceValuePaise * commissionRateBps / 10000);
  return { commissionPaise, netPaise: invoiceValuePaise - commissionPaise };
}

// ── Fuel Pump Reading Delta ───────────────────────────────────────────────────

function calculateFuelDispensed(
  opening: number,
  closing: number,
): { dispensedL: number; isValid: boolean; error?: string } {
  if (closing < opening) return { dispensedL: 0, isValid: false, error: 'CLOSING_LESS_THAN_OPENING' };
  if (closing === opening) return { dispensedL: 0, isValid: true };
  return { dispensedL: Math.round((closing - opening) * 1000) / 1000, isValid: true };
}

// ── Crate Deposit / Return (Vegetable Broker) ─────────────────────────────────

interface CrateAccount {
  sentOut: number;
  returned: number;
  depositPerCrate: number; // paise
}

function calculateCrateDeposit(account: CrateAccount): {
  outstanding: number;
  totalDepositPaise: number;
  balancePaise: number;
} {
  const outstanding = account.sentOut - account.returned;
  const totalDepositPaise = account.sentOut * account.depositPerCrate;
  const balancePaise = outstanding * account.depositPerCrate;
  return { outstanding, totalDepositPaise, balancePaise };
}

// ── Loyalty Points (Book Store) ───────────────────────────────────────────────

function accruePoints(invoiceValuePaise: number, pointsPerRupee: number): number {
  return Math.floor(invoiceValuePaise / 100 * pointsPerRupee);
}

function redeemPoints(
  currentPoints: number,
  pointsToRedeem: number,
  pointValuePaise: number,
): { creditPaise: number; remainingPoints: number; error?: string } {
  if (pointsToRedeem > currentPoints) {
    return { creditPaise: 0, remainingPoints: currentPoints, error: 'INSUFFICIENT_POINTS' };
  }
  if (pointsToRedeem <= 0) {
    return { creditPaise: 0, remainingPoints: currentPoints, error: 'INVALID_REDEEM_QTY' };
  }
  return {
    creditPaise: pointsToRedeem * pointValuePaise,
    remainingPoints: currentPoints - pointsToRedeem,
  };
}

// ── KOT Item Merging & Splitting (Restaurant) ─────────────────────────────────

interface KOTItem { menuItemId: string; name: string; qty: number; tableId: string }

function mergeKOTItems(existing: KOTItem[], incoming: KOTItem[]): KOTItem[] {
  const merged = [...existing];
  for (const item of incoming) {
    const found = merged.find(
      m => m.menuItemId === item.menuItemId && m.tableId === item.tableId,
    );
    if (found) { found.qty += item.qty; }
    else { merged.push({ ...item }); }
  }
  return merged;
}

function splitKOTItem(item: KOTItem, splitQty: number): [KOTItem, KOTItem] | null {
  if (splitQty <= 0 || splitQty >= item.qty) return null;
  return [
    { ...item, qty: splitQty },
    { ...item, qty: item.qty - splitQty },
  ];
}

// ── Consultation Billing (Clinic) ─────────────────────────────────────────────

function calculateConsultationBill(opts: {
  consultationFeePaise: number;
  procedureFeePaise: number;
  medicinesCostPaise: number;
  discountPaise: number;
  gstRateBps: number;
}): { subtotalPaise: number; taxPaise: number; grandTotalPaise: number } {
  const subtotalPaise = opts.consultationFeePaise + opts.procedureFeePaise + opts.medicinesCostPaise - opts.discountPaise;
  const taxPaise = Math.round(subtotalPaise * opts.gstRateBps / 10000);
  return { subtotalPaise, taxPaise, grandTotalPaise: subtotalPaise + taxPaise };
}

// ── Job Sheet State Machine ───────────────────────────────────────────────────

type JobStatus = 'RECEIVED' | 'DIAGNOSED' | 'AWAITING_PARTS' | 'REPAIRING' | 'QC' | 'READY' | 'DELIVERED' | 'CANCELLED';

const JOB_TRANSITIONS: Record<JobStatus, JobStatus[]> = {
  RECEIVED:       ['DIAGNOSED', 'CANCELLED'],
  DIAGNOSED:      ['AWAITING_PARTS', 'REPAIRING', 'CANCELLED'],
  AWAITING_PARTS: ['REPAIRING', 'CANCELLED'],
  REPAIRING:      ['QC', 'CANCELLED'],
  QC:             ['READY', 'REPAIRING'],
  READY:          ['DELIVERED'],
  DELIVERED:      [],
  CANCELLED:      [],
};

function canTransition(from: JobStatus, to: JobStatus): boolean {
  return JOB_TRANSITIONS[from]?.includes(to) ?? false;
}

function transitionJob(current: JobStatus, next: JobStatus): JobStatus {
  if (!canTransition(current, next)) {
    throw new Error(`INVALID_TRANSITION: ${current} → ${next}`);
  }
  return next;
}

// ============================================================================
// IMEI TESTS
// ============================================================================

describe('UT-BIZ-001: IMEI Uniqueness Validation (mobileShop, electronics, computerShop)', () => {
  const existing = new Set(['356938035643809', '490154203237518']);

  test('Valid IMEI passes Luhn check and is unique', () => {
    const r = validateIMEI('100000000000009', existing);
    expect(r.valid).toBe(true);
  });

  test('Duplicate IMEI within tenant → IMEI_DUPLICATE', () => {
    const r = validateIMEI('356938035643809', existing);
    expect(r.valid).toBe(false);
    expect(r.error).toBe('IMEI_DUPLICATE');
  });

  test('IMEI with fewer than 15 digits → IMEI_INVALID_FORMAT', () => {
    const r = validateIMEI('35678093471', existing);
    expect(r.valid).toBe(false);
    expect(r.error).toBe('IMEI_INVALID_FORMAT');
  });

  test('IMEI with non-digit characters → IMEI_INVALID_FORMAT', () => {
    const r = validateIMEI('35678A093471897', existing);
    expect(r.valid).toBe(false);
    expect(r.error).toBe('IMEI_INVALID_FORMAT');
  });

  test('IMEI failing Luhn check → IMEI_LUHN_FAIL', () => {
    const r = validateIMEI('356938035643800', existing); // last digit changed
    expect(r.valid).toBe(false);
    expect(r.error).toBe('IMEI_LUHN_FAIL');
  });

  test('Empty IMEI → IMEI_REQUIRED', () => {
    const r = validateIMEI('', existing);
    expect(r.valid).toBe(false);
    expect(r.error).toBe('IMEI_REQUIRED');
  });

  test('Second unit of same model gets different IMEI — uniqueness is per-number not per-model', () => {
    const store = new Set<string>();
    const imei1 = '354678093471897';
    const imei2 = '356938035643809';
    store.add(imei1);
    expect(validateIMEI(imei1, store).valid).toBe(false); // duplicate
    expect(validateIMEI(imei2, store).valid).toBe(true);  // new, unique
  });
});

// ============================================================================
// DRUG SCHEDULE TESTS
// ============================================================================

describe('UT-BIZ-002: Drug Schedule Classification (pharmacy)', () => {
  const scheduleMap: Record<string, DrugSchedule> = {
    'amoxicillin': DrugSchedule.H,
    'codeine': DrugSchedule.H1,
    'alprazolam': DrugSchedule.X,
    'paracetamol': DrugSchedule.OTC,
  };

  test('Amoxicillin is Schedule H', () => {
    expect(classifyDrug('Amoxicillin', scheduleMap)).toBe(DrugSchedule.H);
  });

  test('Codeine is Schedule H1', () => {
    expect(classifyDrug('Codeine', scheduleMap)).toBe(DrugSchedule.H1);
  });

  test('Alprazolam is Schedule X (narcotic)', () => {
    expect(classifyDrug('Alprazolam', scheduleMap)).toBe(DrugSchedule.X);
  });

  test('Paracetamol is OTC (no prescription)', () => {
    expect(classifyDrug('Paracetamol', scheduleMap)).toBe(DrugSchedule.OTC);
  });

  test('Unknown salt defaults to OTC', () => {
    expect(classifyDrug('SomeSalt123', scheduleMap)).toBe(DrugSchedule.OTC);
  });

  test('Schedule H, H1, X all require prescription', () => {
    expect(requiresPrescription(DrugSchedule.H)).toBe(true);
    expect(requiresPrescription(DrugSchedule.H1)).toBe(true);
    expect(requiresPrescription(DrugSchedule.X)).toBe(true);
    expect(requiresPrescription(DrugSchedule.OTC)).toBe(false);
  });

  test('Only Schedule X is narcotic', () => {
    expect(isNarcoticSchedule(DrugSchedule.X)).toBe(true);
    expect(isNarcoticSchedule(DrugSchedule.H)).toBe(false);
    expect(isNarcoticSchedule(DrugSchedule.H1)).toBe(false);
  });
});

// ============================================================================
// COMMISSION TESTS (vegetablesBroker)
// ============================================================================

describe('UT-BIZ-003: Commission Calculation (vegetablesBroker)', () => {
  test('2% commission on ₹10,000 → ₹200 commission, ₹9,800 net', () => {
    const r = calculateCommission(1_000_000, 200); // 1,000,000 paise = ₹10,000; 200bps = 2%
    expect(r.commissionPaise).toBe(20_000);         // ₹200
    expect(r.netPaise).toBe(980_000);               // ₹9,800
  });

  test('Zero commission rate → 0 commission, full net', () => {
    const r = calculateCommission(500_000, 0);
    expect(r.commissionPaise).toBe(0);
    expect(r.netPaise).toBe(500_000);
  });

  test('Commission rounds correctly for odd paise amounts', () => {
    // ₹1 × 3% = 0.03 → 3 paise (floor)
    const r = calculateCommission(100, 300); // 100 paise × 3%
    expect(r.commissionPaise).toBe(3);
    expect(r.netPaise).toBe(97);
  });

  test('100% commission rate → full amount as commission, net = 0', () => {
    const r = calculateCommission(50_000, 10_000); // 10000 bps = 100%
    expect(r.commissionPaise).toBe(50_000);
    expect(r.netPaise).toBe(0);
  });
});

// ============================================================================
// FUEL PUMP READING TESTS
// ============================================================================

describe('UT-BIZ-004: Fuel Pump Reading Delta (petrolPump)', () => {
  test('Opening 1234.5, Closing 1289.3 → dispensed 54.8L', () => {
    const r = calculateFuelDispensed(1234.5, 1289.3);
    expect(r.isValid).toBe(true);
    expect(r.dispensedL).toBeCloseTo(54.8, 1);
  });

  test('Closing < Opening → invalid reading', () => {
    const r = calculateFuelDispensed(1500, 1400);
    expect(r.isValid).toBe(false);
    expect(r.error).toBe('CLOSING_LESS_THAN_OPENING');
  });

  test('Opening = Closing → 0L dispensed (valid, shift just started)', () => {
    const r = calculateFuelDispensed(2000, 2000);
    expect(r.isValid).toBe(true);
    expect(r.dispensedL).toBe(0);
  });

  test('Large dispense (tanker refill shift) → accurate delta', () => {
    const r = calculateFuelDispensed(10000.0, 10987.654);
    expect(r.isValid).toBe(true);
    expect(r.dispensedL).toBeCloseTo(987.654, 3);
  });
});

// ============================================================================
// CRATE DEPOSIT TESTS (vegetablesBroker)
// ============================================================================

describe('UT-BIZ-005: Crate Deposit and Return (vegetablesBroker)', () => {
  test('50 crates out, 30 returned → 20 outstanding, balance = 20 × deposit', () => {
    const r = calculateCrateDeposit({ sentOut: 50, returned: 30, depositPerCrate: 500 });
    expect(r.outstanding).toBe(20);
    expect(r.totalDepositPaise).toBe(25_000);
    expect(r.balancePaise).toBe(10_000);
  });

  test('All crates returned → outstanding = 0, balance = 0', () => {
    const r = calculateCrateDeposit({ sentOut: 10, returned: 10, depositPerCrate: 300 });
    expect(r.outstanding).toBe(0);
    expect(r.balancePaise).toBe(0);
  });

  test('No crates returned → full deposit balance outstanding', () => {
    const r = calculateCrateDeposit({ sentOut: 5, returned: 0, depositPerCrate: 1000 });
    expect(r.outstanding).toBe(5);
    expect(r.balancePaise).toBe(5000);
  });
});

// ============================================================================
// LOYALTY POINTS TESTS (bookStore)
// ============================================================================

describe('UT-BIZ-006: Loyalty Point Accrual and Redemption (bookStore)', () => {
  test('Purchase ₹500 at 1 point/rupee → 500 points', () => {
    expect(accruePoints(50_000, 1)).toBe(500);
  });

  test('Purchase ₹99.50 at 1 point/rupee → 99 points (floor)', () => {
    expect(accruePoints(9_950, 1)).toBe(99);
  });

  test('Double points promotion: ₹100 at 2pts/rupee → 200 points', () => {
    expect(accruePoints(10_000, 2)).toBe(200);
  });

  test('Redeem 100 points at ₹0.50/point → ₹50 credit (5000 paise)', () => {
    const r = redeemPoints(500, 100, 50); // 50 paise per point
    expect(r.creditPaise).toBe(5000);
    expect(r.remainingPoints).toBe(400);
  });

  test('Redeem more points than available → INSUFFICIENT_POINTS', () => {
    const r = redeemPoints(50, 100, 50);
    expect(r.error).toBe('INSUFFICIENT_POINTS');
    expect(r.creditPaise).toBe(0);
    expect(r.remainingPoints).toBe(50);
  });

  test('Redeem zero points → INVALID_REDEEM_QTY', () => {
    const r = redeemPoints(100, 0, 50);
    expect(r.error).toBe('INVALID_REDEEM_QTY');
  });

  test('Redeem all points → remaining = 0', () => {
    const r = redeemPoints(100, 100, 50);
    expect(r.remainingPoints).toBe(0);
    expect(r.creditPaise).toBe(5000);
  });
});

// ============================================================================
// KOT MERGE / SPLIT TESTS (restaurant)
// ============================================================================

describe('UT-BIZ-007: KOT Item Merging and Splitting (restaurant)', () => {
  // Fresh base per test — avoids mutation leakage between tests
  function makeBase(): KOTItem[] {
    return [
      { menuItemId: 'M01', name: 'Butter Chicken', qty: 2, tableId: 'T5' },
      { menuItemId: 'M02', name: 'Naan', qty: 3, tableId: 'T5' },
    ];
  }

  test('Merge same item → qty adds up', () => {
    const incoming: KOTItem[] = [{ menuItemId: 'M01', name: 'Butter Chicken', qty: 1, tableId: 'T5' }];
    const merged = mergeKOTItems(makeBase(), incoming);
    const butterChicken = merged.find(i => i.menuItemId === 'M01');
    expect(butterChicken?.qty).toBe(3);
  });

  test('Merge new item → appended without altering existing', () => {
    const incoming: KOTItem[] = [{ menuItemId: 'M03', name: 'Dal Makhani', qty: 1, tableId: 'T5' }];
    const merged = mergeKOTItems(makeBase(), incoming);
    expect(merged.length).toBe(3);
    expect(merged.find(i => i.menuItemId === 'M03')).toBeDefined();
    expect(merged.find(i => i.menuItemId === 'M01')?.qty).toBe(2); // unchanged
  });

  test('Merge does not affect different table same item', () => {
    const incoming: KOTItem[] = [{ menuItemId: 'M01', name: 'Butter Chicken', qty: 1, tableId: 'T7' }];
    const merged = mergeKOTItems(makeBase(), incoming);
    const t5Item = merged.find(i => i.menuItemId === 'M01' && i.tableId === 'T5');
    const t7Item = merged.find(i => i.menuItemId === 'M01' && i.tableId === 'T7');
    expect(t5Item?.qty).toBe(2); // unchanged
    expect(t7Item?.qty).toBe(1); // new entry
  });

  test('Split 3 Naan into 1 + 2', () => {
    const naan: KOTItem = { menuItemId: 'M02', name: 'Naan', qty: 3, tableId: 'T5' };
    const result = splitKOTItem(naan, 1);
    expect(result).not.toBeNull();
    expect(result![0].qty).toBe(1);
    expect(result![1].qty).toBe(2);
  });

  test('Split qty >= total qty → returns null (invalid)', () => {
    const naan: KOTItem = { menuItemId: 'M02', name: 'Naan', qty: 3, tableId: 'T5' };
    expect(splitKOTItem(naan, 3)).toBeNull();
    expect(splitKOTItem(naan, 4)).toBeNull();
  });

  test('Split qty = 0 → returns null (invalid)', () => {
    const naan: KOTItem = { menuItemId: 'M02', name: 'Naan', qty: 3, tableId: 'T5' };
    expect(splitKOTItem(naan, 0)).toBeNull();
  });
});

// ============================================================================
// CONSULTATION BILLING TESTS (clinic)
// ============================================================================

describe('UT-BIZ-008: Consultation Billing Formula (clinic)', () => {
  test('Consultation ₹300 + procedure ₹500 + medicines ₹200 - discount ₹100 = subtotal ₹900', () => {
    const r = calculateConsultationBill({
      consultationFeePaise: 30_000,
      procedureFeePaise:    50_000,
      medicinesCostPaise:   20_000,
      discountPaise:        10_000,
      gstRateBps:           0,
    });
    expect(r.subtotalPaise).toBe(90_000);
    expect(r.taxPaise).toBe(0);
    expect(r.grandTotalPaise).toBe(90_000);
  });

  test('With 18% GST on consultation fee', () => {
    const r = calculateConsultationBill({
      consultationFeePaise: 100_000,
      procedureFeePaise:    0,
      medicinesCostPaise:   0,
      discountPaise:        0,
      gstRateBps:           1800, // 18%
    });
    expect(r.taxPaise).toBe(18_000);
    expect(r.grandTotalPaise).toBe(118_000);
  });

  test('Zero consultation fee (complimentary visit)', () => {
    const r = calculateConsultationBill({
      consultationFeePaise: 0,
      procedureFeePaise:    0,
      medicinesCostPaise:   0,
      discountPaise:        0,
      gstRateBps:           0,
    });
    expect(r.grandTotalPaise).toBe(0);
  });
});

// ============================================================================
// JOB SHEET STATE MACHINE TESTS
// ============================================================================

describe('UT-BIZ-009: Job Sheet Status Machine (service, mobileShop, autoParts)', () => {
  test('RECEIVED → DIAGNOSED is valid', () => {
    expect(transitionJob('RECEIVED', 'DIAGNOSED')).toBe('DIAGNOSED');
  });

  test('RECEIVED → CANCELLED is valid', () => {
    expect(transitionJob('RECEIVED', 'CANCELLED')).toBe('CANCELLED');
  });

  test('DIAGNOSED → REPAIRING is valid', () => {
    expect(transitionJob('DIAGNOSED', 'REPAIRING')).toBe('REPAIRING');
  });

  test('REPAIRING → QC is valid', () => {
    expect(transitionJob('REPAIRING', 'QC')).toBe('QC');
  });

  test('QC → READY is valid', () => {
    expect(transitionJob('QC', 'READY')).toBe('READY');
  });

  test('QC → REPAIRING is valid (failed QC, back to repair)', () => {
    expect(transitionJob('QC', 'REPAIRING')).toBe('REPAIRING');
  });

  test('READY → DELIVERED is valid', () => {
    expect(transitionJob('READY', 'DELIVERED')).toBe('DELIVERED');
  });

  test('DELIVERED → any state is INVALID (terminal state)', () => {
    expect(() => transitionJob('DELIVERED', 'REPAIRING')).toThrow('INVALID_TRANSITION');
    expect(() => transitionJob('DELIVERED', 'READY')).toThrow('INVALID_TRANSITION');
    expect(() => transitionJob('DELIVERED', 'CANCELLED')).toThrow('INVALID_TRANSITION');
  });

  test('CANCELLED → any state is INVALID (terminal state)', () => {
    expect(() => transitionJob('CANCELLED', 'DIAGNOSED')).toThrow('INVALID_TRANSITION');
  });

  test('Skipping states is INVALID: RECEIVED → REPAIRING', () => {
    expect(() => transitionJob('RECEIVED', 'REPAIRING')).toThrow('INVALID_TRANSITION');
  });

  test('canTransition returns false for backward skips', () => {
    expect(canTransition('READY', 'RECEIVED')).toBe(false);
    expect(canTransition('REPAIRING', 'RECEIVED')).toBe(false);
  });
});

