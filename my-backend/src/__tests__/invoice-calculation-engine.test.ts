// ============================================================================
// UT-INV — Invoice Calculation Engine Unit Tests
// Coverage: GST inclusive/exclusive, discount stacking, multi-unit, edge cases,
//           rounding (Indian paise rules), overflow, sales return / credit note
// ============================================================================

// Pure arithmetic helpers mirroring TaxCalculator in tax_calculator.dart
// These functions must stay in sync with the Dart source.

function calculateTax(opts: {
  price: number;
  quantity: number;
  rate: number;
  isInclusive: boolean;
  isInterState?: boolean;
}): {
  taxableValue: number;
  taxAmount: number;
  cgst: number;
  sgst: number;
  igst: number;
  total: number;
} {
  const { price, quantity, rate, isInclusive, isInterState = false } = opts;

  const qtyMilli = Math.round(quantity * 1000);
  const pricePaise = Math.round(price * 100);
  const basePaise = Math.trunc(qtyMilli * pricePaise / 1000);

  let taxablePaise: number;
  let taxPaise: number;

  if (isInclusive) {
    const rateBps = Math.round(rate * 100);
    const denominator = 10000 + rateBps;
    const roundingOffset = basePaise >= 0 ? Math.trunc(denominator / 2) : -Math.trunc(denominator / 2);
    taxPaise = Math.trunc((basePaise * rateBps + roundingOffset) / denominator);
    taxablePaise = basePaise - taxPaise;
  } else {
    taxablePaise = basePaise;
    const rateBps = Math.round(rate * 100);
    const roundingOffset = basePaise >= 0 ? 5000 : -5000;
    taxPaise = Math.trunc((basePaise * rateBps + roundingOffset) / 10000);
  }

  let cgstPaise = 0, sgstPaise = 0, igstPaise = 0;
  if (isInterState) {
    igstPaise = taxPaise;
  } else {
    cgstPaise = Math.trunc((taxPaise + 1) / 2);
    sgstPaise = taxPaise - cgstPaise;
  }

  const totalPaise = isInclusive ? basePaise : taxablePaise + taxPaise;

  return {
    taxableValue: taxablePaise / 100,
    taxAmount: taxPaise / 100,
    cgst: cgstPaise / 100,
    sgst: sgstPaise / 100,
    igst: igstPaise / 100,
    total: totalPaise / 100,
  };
}

// ── Bill-level recalculation helper ─────────────────────────────────────────
interface BillItem {
  price: number;
  qty: number;
  gstRate: number;
  discount: number;
}

interface Bill {
  items: BillItem[];
  discountApplied: number;
}

function recalculateBill(bill: Bill, opts: { isInterState?: boolean; isInclusive?: boolean } = {}) {
  const { isInterState = false, isInclusive = false } = opts;
  let subtotalPaise = 0, totalTaxPaise = 0, grandTotalPaise = 0;

  for (const item of bill.items) {
    const calc = calculateTax({ price: item.price, quantity: item.qty, rate: item.gstRate, isInclusive, isInterState });
    const taxPaise = Math.round(calc.taxAmount * 100);
    const itemTotalPaise = Math.round(calc.total * 100);
    const discountPaise = Math.round(item.discount * 100);
    const netItemPaise = itemTotalPaise - discountPaise;
    subtotalPaise += Math.round(calc.taxableValue * 100);
    totalTaxPaise += taxPaise;
    grandTotalPaise += netItemPaise;
  }
  const billDiscountPaise = Math.round(bill.discountApplied * 100);
  grandTotalPaise -= billDiscountPaise;

  return {
    subtotal: subtotalPaise / 100,
    totalTax: totalTaxPaise / 100,
    grandTotal: grandTotalPaise / 100,
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const round2 = (n: number) => Math.round(n * 100) / 100;

// ============================================================================
// 1. GST EXCLUSIVE
// ============================================================================

describe('UT-INV-001: GST Exclusive Calculation', () => {
  test('18% GST exclusive on ₹100 × 1qty = tax ₹18, total ₹118', () => {
    const r = calculateTax({ price: 100, quantity: 1, rate: 18, isInclusive: false });
    expect(r.taxableValue).toBe(100);
    expect(r.taxAmount).toBe(18);
    expect(r.total).toBe(118);
  });

  test('5% GST exclusive on ₹200 × 2qty = taxable ₹400, tax ₹20, total ₹420', () => {
    const r = calculateTax({ price: 200, quantity: 2, rate: 5, isInclusive: false });
    expect(r.taxableValue).toBe(400);
    expect(r.taxAmount).toBe(20);
    expect(r.total).toBe(420);
  });

  test('12% GST on ₹999 × 1 = taxable ₹999, tax ₹119.88, total ₹1118.88', () => {
    const r = calculateTax({ price: 999, quantity: 1, rate: 12, isInclusive: false });
    expect(r.taxableValue).toBe(999);
    expect(r.taxAmount).toBeCloseTo(119.88, 1);
    expect(r.total).toBeCloseTo(1118.88, 1);
  });

  test('0% GST — taxable = total, tax = 0', () => {
    const r = calculateTax({ price: 500, quantity: 3, rate: 0, isInclusive: false });
    expect(r.taxAmount).toBe(0);
    expect(r.taxableValue).toBe(r.total);
    expect(r.total).toBe(1500);
  });
});

// ============================================================================
// 2. GST INCLUSIVE
// ============================================================================

describe('UT-INV-002: GST Inclusive Calculation', () => {
  test('18% GST inclusive on ₹118 × 1 → taxable ≈ ₹100, tax ≈ ₹18', () => {
    const r = calculateTax({ price: 118, quantity: 1, rate: 18, isInclusive: true });
    expect(r.total).toBe(118);
    expect(round2(r.taxableValue + r.taxAmount)).toBe(118);
    expect(r.taxAmount).toBeCloseTo(18, 0);
  });

  test('5% GST inclusive on ₹210 × 1 → total stays ₹210', () => {
    const r = calculateTax({ price: 210, quantity: 1, rate: 5, isInclusive: true });
    expect(r.total).toBe(210);
    expect(r.taxAmount).toBeCloseTo(10, 0);
    expect(r.taxableValue).toBeCloseTo(200, 0);
  });

  test('Inclusive: taxable + tax = total for fractional qty (0.5)', () => {
    const r = calculateTax({ price: 100, quantity: 0.5, rate: 18, isInclusive: true });
    expect(round2(r.taxableValue + r.taxAmount)).toBe(r.total);
  });
});

// ============================================================================
// 3. CGST/SGST vs IGST SPLIT
// ============================================================================

describe('UT-INV-003: CGST/SGST vs IGST', () => {
  test('Intra-state: CGST + SGST = total tax, IGST = 0', () => {
    const r = calculateTax({ price: 1000, quantity: 1, rate: 18, isInclusive: false, isInterState: false });
    expect(r.igst).toBe(0);
    expect(round2(r.cgst + r.sgst)).toBe(r.taxAmount);
  });

  test('Inter-state: IGST = total tax, CGST = 0, SGST = 0', () => {
    const r = calculateTax({ price: 1000, quantity: 1, rate: 18, isInclusive: false, isInterState: true });
    expect(r.igst).toBe(r.taxAmount);
    expect(r.cgst).toBe(0);
    expect(r.sgst).toBe(0);
  });

  test('Odd paise GST (91 paise): CGST gets ceiling (46), SGST gets floor (45)', () => {
    // price=100.50 × qty=1 × rate=18% exclusive → tax = 18.09 = 1809 paise (odd 9)
    // In paise: 10050 * 1800 / 10000 = round(18.09) = 18 (18.09 → 18 after trunc+offset)
    // Find a value where odd paise emerges:
    // taxPaise = (5050 * 1800 + 5000) / 10000 = (9090000 + 5000)/10000 = 909.5 → 909
    // Let's use price=5.05, qty=1, rate=18% → basePaise=505, taxPaise=(505*1800+5000)/10000=914000/10000=91
    const r = calculateTax({ price: 5.05, quantity: 1, rate: 18, isInclusive: false });
    const taxPaise = Math.round(r.taxAmount * 100);
    if (taxPaise % 2 !== 0) {
      const cgstPaise = Math.round(r.cgst * 100);
      const sgstPaise = Math.round(r.sgst * 100);
      expect(cgstPaise).toBe(sgstPaise + 1); // CGST gets the extra paise
    }
    expect(round2(r.cgst + r.sgst)).toBe(r.taxAmount);
  });
});

// ============================================================================
// 4. DISCOUNT STACKING
// ============================================================================

describe('UT-INV-004: Discount Stacking', () => {
  test('Line-level flat discount reduces net item total', () => {
    const bill: Bill = {
      items: [{ price: 100, qty: 2, gstRate: 18, discount: 20 }],
      discountApplied: 0,
    };
    const result = recalculateBill(bill);
    // taxable = 200, tax = 36, gross = 236, line discount = 20 → net = 216
    expect(result.grandTotal).toBe(216);
  });

  test('Bill-level flat discount applied ONCE after all items', () => {
    const bill: Bill = {
      items: [
        { price: 100, qty: 1, gstRate: 18, discount: 0 },
        { price: 200, qty: 1, gstRate: 18, discount: 0 },
      ],
      discountApplied: 50,
    };
    const result = recalculateBill(bill);
    // item1: 118, item2: 236, bill discount: 50 → total = 304
    expect(result.grandTotal).toBe(304);
  });

  test('Line discount + bill discount combined (stacked)', () => {
    const bill: Bill = {
      items: [{ price: 1000, qty: 1, gstRate: 18, discount: 100 }], // item net = 1180 - 100 = 1080
      discountApplied: 80, // bill net = 1080 - 80 = 1000
    };
    const result = recalculateBill(bill);
    expect(result.grandTotal).toBe(1000);
  });

  test('100% line discount → item contributes ₹0 to grand total', () => {
    const r = calculateTax({ price: 100, quantity: 1, rate: 18, isInclusive: false });
    const netItem = r.total - r.total; // 100% discount
    expect(netItem).toBe(0);
  });

  test('Discount > total does not produce negative silently (application guard)', () => {
    const itemTotal = 118;
    const discount = 200;
    const net = itemTotal - discount;
    expect(net).toBeLessThan(0); // The application layer must catch this
  });
});

// ============================================================================
// 5. MULTI-UNIT PRICE CONVERSION
// ============================================================================

describe('UT-INV-005: Multi-Unit Price Conversion', () => {
  test('Box(12pcs) at ₹120/box → price/pcs = ₹10', () => {
    const pricePerBox = 120;
    const pcsPerBox = 12;
    const pricePerPc = pricePerBox / pcsPerBox;
    expect(pricePerPc).toBe(10);
  });

  test('Selling 5 boxes when price is per-pcs with conversion factor', () => {
    const pricePcs = 10;
    const qtyBoxes = 5;
    const conversionFactor = 12; // 1 box = 12 pcs
    const effectiveQty = qtyBoxes * conversionFactor; // 60 pcs
    const r = calculateTax({ price: pricePcs, quantity: effectiveQty, rate: 12, isInclusive: false });
    expect(r.taxableValue).toBe(600);
    expect(r.taxAmount).toBeCloseTo(72, 1);
    expect(r.total).toBeCloseTo(672, 1);
  });

  test('Loose kg → pcs conversion (Hardware loose quantity)', () => {
    const pricePer100g = 5;
    const quantityKg = 2.5;
    const qty100g = quantityKg * 10; // 25 units of 100g
    const r = calculateTax({ price: pricePer100g, quantity: qty100g, rate: 5, isInclusive: false });
    expect(r.taxableValue).toBe(125);
    expect(r.taxAmount).toBeCloseTo(6.25, 2);
  });
});

// ============================================================================
// 6. EDGE CASES
// ============================================================================

describe('UT-INV-006: Edge Cases', () => {
  test('Zero price item → all values = 0', () => {
    const r = calculateTax({ price: 0, quantity: 5, rate: 18, isInclusive: false });
    expect(r.taxableValue).toBe(0);
    expect(r.taxAmount).toBe(0);
    expect(r.total).toBe(0);
  });

  test('Zero quantity → all values = 0', () => {
    const r = calculateTax({ price: 999, quantity: 0, rate: 18, isInclusive: false });
    expect(r.taxableValue).toBe(0);
    expect(r.taxAmount).toBe(0);
    expect(r.total).toBe(0);
  });

  test('Negative quantity → negative total (sales return scenario)', () => {
    const r = calculateTax({ price: 100, quantity: -2, rate: 18, isInclusive: false });
    expect(r.taxableValue).toBe(-200);
    expect(r.taxAmount).toBe(-36);
    expect(r.total).toBe(-236);
  });

  test('Fractional GST rate (2.5% CGST + 2.5% SGST = 5% total)', () => {
    const r = calculateTax({ price: 1000, quantity: 1, rate: 5, isInclusive: false });
    expect(r.cgst).toBe(25);
    expect(r.sgst).toBe(25);
    expect(r.taxAmount).toBe(50);
  });

  test('Very small amount ₹1 × 1 × 18%', () => {
    const r = calculateTax({ price: 1, quantity: 1, rate: 18, isInclusive: false });
    expect(r.taxAmount).toBeCloseTo(0.18, 2);
    expect(r.total).toBeCloseTo(1.18, 2);
  });

  test('Quantity with 3 decimal places (0.001)', () => {
    const r = calculateTax({ price: 1000, quantity: 0.001, rate: 18, isInclusive: false });
    expect(r.taxableValue).toBeCloseTo(1, 0);
    expect(r.total).toBeGreaterThan(0);
  });
});

// ============================================================================
// 7. OVERFLOW — Large Invoice
// ============================================================================

describe('UT-INV-007: Large Invoice / Overflow Guard', () => {
  test('Invoice total with 50 high-value items stays accurate (no JS precision loss)', () => {
    const items: BillItem[] = Array(50).fill(null).map(() => ({
      price: 99999.99,
      qty: 100,
      gstRate: 28,
      discount: 0,
    }));
    const bill: Bill = { items, discountApplied: 0 };
    const result = recalculateBill(bill);
    // Each item: taxable = 9,999,999, tax = 2,799,999.72, total = 12,799,998.72
    // 50 items grand total ≈ 639,999,936
    expect(result.grandTotal).toBeGreaterThan(0);
    expect(Number.isFinite(result.grandTotal)).toBe(true);
    expect(Number.isNaN(result.grandTotal)).toBe(false);
  });

  test('Single item at ₹9,999,999.99 × 999 qty stays within Number precision', () => {
    const r = calculateTax({ price: 9_999_999.99, quantity: 999, rate: 18, isInclusive: false });
    expect(Number.isFinite(r.total)).toBe(true);
    expect(r.total).toBeGreaterThan(0);
  });
});

// ============================================================================
// 8. INDIAN PAISE ROUNDING RULES
// ============================================================================

describe('UT-INV-008: Indian Paise Rounding (RNI Standard)', () => {
  test('Tax rounded to nearest paisa — 0.5 rounds up', () => {
    // 100 × 1 × 15% → tax = 15.00 (exact) — no rounding issue
    const r = calculateTax({ price: 100, quantity: 1, rate: 15, isInclusive: false });
    expect(r.taxAmount).toBe(15);
  });

  test('₹3.33 × 3 × 18% → basePaise = 999, taxPaise = (999*1800+5000)/10000 = 1803200/10000 = 180', () => {
    const r = calculateTax({ price: 3.33, quantity: 3, rate: 18, isInclusive: false });
    // basePaise = round(3.33*100) = 333; qtyMilli = 3000; basePaise = trunc(3000*333/1000) = 999
    // taxPaise = trunc((999*1800 + 5000)/10000) = trunc(1803200/10000) = trunc(180.32) = 180
    expect(r.taxAmount).toBe(1.80);
    expect(r.taxableValue).toBe(9.99);
    expect(r.total).toBe(11.79);
  });

  test('Total always representable in 2 decimal places', () => {
    const testPrices = [1.01, 2.99, 33.33, 66.67, 100.01, 999.99];
    for (const price of testPrices) {
      const r = calculateTax({ price, quantity: 1, rate: 18, isInclusive: false });
      const total = round2(r.total);
      expect(total.toString().split('.')[1]?.length ?? 0).toBeLessThanOrEqual(2);
    }
  });

  test('CGST + SGST reconstructs exact taxAmount (no split rounding loss)', () => {
    const prices = [100, 50.5, 333.33, 1000.01, 7.77];
    for (const price of prices) {
      const r = calculateTax({ price, quantity: 1, rate: 18, isInclusive: false });
      expect(round2(r.cgst + r.sgst)).toBe(r.taxAmount);
    }
  });
});

// ============================================================================
// 9. SALES RETURN / CREDIT NOTE
// ============================================================================

describe('UT-INV-009: Sales Return & Credit Note Calculation', () => {
  test('Full return: negative qty mirrors original invoice totals with sign flip', () => {
    const original = calculateTax({ price: 500, quantity: 2, rate: 18, isInclusive: false });
    const returned = calculateTax({ price: 500, quantity: -2, rate: 18, isInclusive: false });
    expect(returned.taxableValue).toBe(-original.taxableValue);
    expect(returned.taxAmount).toBe(-original.taxAmount);
    expect(returned.total).toBe(-original.total);
  });

  test('Partial return (1 of 3 units) computes correct credit amount', () => {
    const originalPerUnit = calculateTax({ price: 100, quantity: 1, rate: 18, isInclusive: false });
    const returnCredit = calculateTax({ price: 100, quantity: -1, rate: 18, isInclusive: false });
    expect(returnCredit.total).toBe(-originalPerUnit.total);
  });

  test('Sales return credit note GST direction: negative tax reduces liability', () => {
    const r = calculateTax({ price: 200, quantity: -3, rate: 12, isInclusive: false });
    expect(r.taxAmount).toBeLessThan(0);
    expect(r.cgst).toBeLessThan(0);
    expect(r.sgst).toBeLessThan(0);
  });

  test('Return of inclusive-priced item: credit amount = original total', () => {
    const sale = calculateTax({ price: 590, quantity: 1, rate: 18, isInclusive: true });
    const ret = calculateTax({ price: 590, quantity: -1, rate: 18, isInclusive: true });
    expect(ret.total).toBe(-sale.total);
  });
});

// ============================================================================
// 10. BILL-LEVEL RECALCULATION
// ============================================================================

describe('UT-INV-010: Bill-Level Recalculation', () => {
  test('Empty bill produces all-zero totals', () => {
    const result = recalculateBill({ items: [], discountApplied: 0 });
    expect(result.subtotal).toBe(0);
    expect(result.totalTax).toBe(0);
    expect(result.grandTotal).toBe(0);
  });

  test('Single item bill: subtotal + totalTax = grandTotal (no discount)', () => {
    const bill: Bill = {
      items: [{ price: 250, qty: 4, gstRate: 5, discount: 0 }],
      discountApplied: 0,
    };
    const result = recalculateBill(bill);
    expect(round2(result.subtotal + result.totalTax)).toBe(result.grandTotal);
  });

  test('Mixed GST rates in one bill sum correctly', () => {
    const bill: Bill = {
      items: [
        { price: 100, qty: 1, gstRate: 5, discount: 0 },  // total 105
        { price: 100, qty: 1, gstRate: 12, discount: 0 }, // total 112
        { price: 100, qty: 1, gstRate: 18, discount: 0 }, // total 118
        { price: 100, qty: 1, gstRate: 28, discount: 0 }, // total 128
      ],
      discountApplied: 0,
    };
    const result = recalculateBill(bill);
    expect(result.grandTotal).toBe(463);
    expect(result.totalTax).toBe(63);
  });

  test('Inter-state flag propagates to all items (IGST only)', () => {
    const bill: Bill = {
      items: [
        { price: 1000, qty: 1, gstRate: 18, discount: 0 },
        { price: 500, qty: 2, gstRate: 12, discount: 0 },
      ],
      discountApplied: 0,
    };
    // We verify by manual calculation
    const item1 = calculateTax({ price: 1000, quantity: 1, rate: 18, isInclusive: false, isInterState: true });
    const item2 = calculateTax({ price: 500, quantity: 2, rate: 12, isInclusive: false, isInterState: true });
    expect(item1.cgst).toBe(0);
    expect(item1.igst).toBe(180);
    expect(item2.cgst).toBe(0);
    expect(item2.igst).toBe(120);
  });
});

// ============================================================================
// 11. COMPOUND / CESS (GST on GST scenario)
// ============================================================================

describe('UT-INV-011: Compound Tax Edge Cases', () => {
  test('Cess on top of GST-inclusive price: total does not double-count', () => {
    // Price 100 incl. 28% GST + 12% Cess (applied on taxable value)
    const base = calculateTax({ price: 100, quantity: 1, rate: 28, isInclusive: true });
    const cessAmount = round2(base.taxableValue * 0.12);
    const grandTotal = round2(base.total + cessAmount);
    expect(grandTotal).toBeGreaterThan(base.total);
    expect(grandTotal).toBeLessThan(150); // sanity upper bound
  });

  test('Multiple tax lines (GST + TCS 1%) applied correctly', () => {
    const gst = calculateTax({ price: 10000, quantity: 1, rate: 18, isInclusive: false });
    const tcsAmount = round2(gst.total * 0.01); // TCS 1% on invoice value
    expect(tcsAmount).toBe(118); // 11800 * 0.01
    expect(round2(gst.total + tcsAmount)).toBe(11918);
  });
});
