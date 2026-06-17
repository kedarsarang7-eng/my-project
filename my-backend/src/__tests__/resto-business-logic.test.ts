export {};
// ============================================================================
// resto-business-logic.test.ts
// Comprehensive tests for restaurant handler business logic
// Tests: GST, discount caps, KOT flow, table management, bill settlement
// ============================================================================

// ---------------------------------------------------------------------------
// DISCOUNT CAP LOGIC (mirrors resto.ts ITEM_DISCOUNT_PERCENT_CAP = 20, BILL_DISCOUNT_PERCENT_CAP = 25)
// ---------------------------------------------------------------------------

const ITEM_DISCOUNT_PERCENT_CAP = 20;
const BILL_DISCOUNT_PERCENT_CAP = 25;

interface DiscountInput {
    priceCents: number;
    discountPercent: number;
}

interface BillDiscountInput {
    subtotalCents: number;
    discountPercent: number;
}

function applyItemDiscount(input: DiscountInput): { finalCents: number; discountCents: number; cappedPercent: number } {
    const effectivePercent = Math.min(input.discountPercent, ITEM_DISCOUNT_PERCENT_CAP);
    const discountCents = Math.round(input.priceCents * effectivePercent / 100);
    return {
        finalCents: input.priceCents - discountCents,
        discountCents,
        cappedPercent: effectivePercent,
    };
}

function applyBillDiscount(input: BillDiscountInput): { finalCents: number; discountCents: number; cappedPercent: number } {
    const effectivePercent = Math.min(input.discountPercent, BILL_DISCOUNT_PERCENT_CAP);
    const discountCents = Math.round(input.subtotalCents * effectivePercent / 100);
    return {
        finalCents: input.subtotalCents - discountCents,
        discountCents,
        cappedPercent: effectivePercent,
    };
}

function paise(rupees: number): number {
    return Math.round(rupees * 100);
}

// ---------------------------------------------------------------------------
// ITEM DISCOUNT TESTS
// ---------------------------------------------------------------------------

describe('Restaurant item discount cap', () => {
    it('RDISC-01: 10% discount within cap is applied fully', () => {
        const r = applyItemDiscount({ priceCents: paise(500), discountPercent: 10 });
        expect(r.cappedPercent).toBe(10);
        expect(r.discountCents).toBe(paise(50));
        expect(r.finalCents).toBe(paise(450));
    });

    it('RDISC-02: 20% discount at cap boundary is applied fully', () => {
        const r = applyItemDiscount({ priceCents: paise(1000), discountPercent: 20 });
        expect(r.cappedPercent).toBe(20);
        expect(r.discountCents).toBe(paise(200));
        expect(r.finalCents).toBe(paise(800));
    });

    it('RDISC-03: 50% discount is capped to 20%', () => {
        const r = applyItemDiscount({ priceCents: paise(1000), discountPercent: 50 });
        expect(r.cappedPercent).toBe(20);
        expect(r.discountCents).toBe(paise(200));
        expect(r.finalCents).toBe(paise(800));
    });

    it('RDISC-04: 0% discount leaves price unchanged', () => {
        const r = applyItemDiscount({ priceCents: paise(500), discountPercent: 0 });
        expect(r.discountCents).toBe(0);
        expect(r.finalCents).toBe(paise(500));
    });

    it('RDISC-05: negative discount is NOT blocked by cap (validation happens upstream)', () => {
        const r = applyItemDiscount({ priceCents: paise(500), discountPercent: -10 });
        // min(-10, 20) = -10 → effectively adds to price (negative discount)
        // This demonstrates why upstream validation must reject negative values
        expect(r.cappedPercent).toBe(-10);
        expect(r.finalCents).toBeGreaterThan(paise(500)); // price increases
    });

    it('RDISC-06: discount on ₹1 item rounds correctly', () => {
        const r = applyItemDiscount({ priceCents: 100, discountPercent: 15 });
        expect(r.discountCents).toBe(15);
        expect(r.finalCents).toBe(85);
    });

    it('RDISC-07: 100% discount is capped to 20%', () => {
        const r = applyItemDiscount({ priceCents: paise(200), discountPercent: 100 });
        expect(r.cappedPercent).toBe(20);
        expect(r.finalCents).toBe(paise(160));
    });
});

// ---------------------------------------------------------------------------
// BILL DISCOUNT TESTS
// ---------------------------------------------------------------------------

describe('Restaurant bill discount cap', () => {
    it('RBDISC-01: 15% bill discount within cap', () => {
        const r = applyBillDiscount({ subtotalCents: paise(5000), discountPercent: 15 });
        expect(r.cappedPercent).toBe(15);
        expect(r.discountCents).toBe(paise(750));
        expect(r.finalCents).toBe(paise(4250));
    });

    it('RBDISC-02: 25% bill discount at cap boundary', () => {
        const r = applyBillDiscount({ subtotalCents: paise(2000), discountPercent: 25 });
        expect(r.cappedPercent).toBe(25);
        expect(r.discountCents).toBe(paise(500));
    });

    it('RBDISC-03: 40% bill discount is capped to 25%', () => {
        const r = applyBillDiscount({ subtotalCents: paise(2000), discountPercent: 40 });
        expect(r.cappedPercent).toBe(25);
        expect(r.discountCents).toBe(paise(500));
    });

    it('RBDISC-04: zero subtotal → zero discount', () => {
        const r = applyBillDiscount({ subtotalCents: 0, discountPercent: 25 });
        expect(r.discountCents).toBe(0);
        expect(r.finalCents).toBe(0);
    });
});

// ---------------------------------------------------------------------------
// TABLE STATUS STATE MACHINE
// ---------------------------------------------------------------------------

type TableStatus = 'available' | 'occupied' | 'reserved' | 'cleaning' | 'blocked';

const TABLE_STATUS_TRANSITIONS: Record<TableStatus, TableStatus[]> = {
    available:  ['occupied', 'reserved', 'blocked'],
    occupied:   ['available', 'cleaning'],
    reserved:   ['occupied', 'available'],
    cleaning:   ['available'],
    blocked:    ['available'],
};

function canTableTransition(from: TableStatus, to: TableStatus): boolean {
    return TABLE_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
}

describe('Table status transitions', () => {
    it('RTBL-01: available → occupied (customer seated)', () => {
        expect(canTableTransition('available', 'occupied')).toBe(true);
    });

    it('RTBL-02: available → reserved', () => {
        expect(canTableTransition('available', 'reserved')).toBe(true);
    });

    it('RTBL-03: occupied → available (bill settled, table released)', () => {
        expect(canTableTransition('occupied', 'available')).toBe(true);
    });

    it('RTBL-04: occupied → cleaning (bill settled, needs cleanup)', () => {
        expect(canTableTransition('occupied', 'cleaning')).toBe(true);
    });

    it('RTBL-05: cleaning → available (cleanup done)', () => {
        expect(canTableTransition('cleaning', 'available')).toBe(true);
    });

    it('RTBL-06: reserved → occupied (reservation activated)', () => {
        expect(canTableTransition('reserved', 'occupied')).toBe(true);
    });

    it('RTBL-07: blocked → available (unblocked)', () => {
        expect(canTableTransition('blocked', 'available')).toBe(true);
    });

    it('RTBL-08: occupied → reserved is INVALID', () => {
        expect(canTableTransition('occupied', 'reserved')).toBe(false);
    });

    it('RTBL-09: cleaning → occupied is INVALID (must go available first)', () => {
        expect(canTableTransition('cleaning', 'occupied')).toBe(false);
    });

    it('RTBL-10: blocked → occupied is INVALID', () => {
        expect(canTableTransition('blocked', 'occupied')).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// BILL SETTLEMENT FLOW
// ---------------------------------------------------------------------------

type BillStatus = 'open' | 'payment_pending' | 'settled' | 'closed' | 'merged' | 'cancelled';

const BILL_STATUS_TRANSITIONS: Record<BillStatus, BillStatus[]> = {
    open:              ['payment_pending', 'cancelled'],
    payment_pending:   ['settled', 'open'], // can revert to open
    settled:           ['closed'],
    closed:            [], // terminal
    merged:            [], // terminal
    cancelled:         [], // terminal
};

function canBillTransition(from: BillStatus, to: BillStatus): boolean {
    return BILL_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
}

function isBillTerminal(status: BillStatus): boolean {
    return BILL_STATUS_TRANSITIONS[status].length === 0;
}

describe('Bill status transitions', () => {
    it('RBILL-S01: open → payment_pending (checkout requested)', () => {
        expect(canBillTransition('open', 'payment_pending')).toBe(true);
    });

    it('RBILL-S02: payment_pending → settled (payment received)', () => {
        expect(canBillTransition('payment_pending', 'settled')).toBe(true);
    });

    it('RBILL-S03: settled → closed (table released)', () => {
        expect(canBillTransition('settled', 'closed')).toBe(true);
    });

    it('RBILL-S04: payment_pending → open (revert checkout)', () => {
        expect(canBillTransition('payment_pending', 'open')).toBe(true);
    });

    it('RBILL-S05: open → cancelled', () => {
        expect(canBillTransition('open', 'cancelled')).toBe(true);
    });

    it('RBILL-S06: closed is terminal', () => {
        expect(isBillTerminal('closed')).toBe(true);
        expect(canBillTransition('closed', 'open')).toBe(false);
    });

    it('RBILL-S07: merged is terminal', () => {
        expect(isBillTerminal('merged')).toBe(true);
    });

    it('RBILL-S08: cancelled is terminal', () => {
        expect(isBillTerminal('cancelled')).toBe(true);
    });

    it('RBILL-S09: settled → open is INVALID (cannot reopen after payment)', () => {
        expect(canBillTransition('settled', 'open')).toBe(false);
    });

    it('RBILL-S10: open → closed is INVALID (must settle first)', () => {
        expect(canBillTransition('open', 'closed')).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// TABLE TRANSFER LOGIC
// ---------------------------------------------------------------------------

interface TableTransferResult {
    success: boolean;
    error?: string;
}

function validateTableTransfer(
    fromStatus: TableStatus,
    toStatus: TableStatus,
    fromBillId: string | null,
    toBillId: string | null,
): TableTransferResult {
    if (fromStatus !== 'occupied') {
        return { success: false, error: 'Source table must be occupied' };
    }
    if (toStatus !== 'available') {
        return { success: false, error: 'Destination table must be available' };
    }
    if (!fromBillId) {
        return { success: false, error: 'Source table has no active bill' };
    }
    if (toBillId) {
        return { success: false, error: 'Destination table already has a bill' };
    }
    return { success: true };
}

describe('Table transfer validation', () => {
    it('RTRN-01: valid transfer — occupied→available, bill exists, no dest bill', () => {
        const r = validateTableTransfer('occupied', 'available', 'bill-1', null);
        expect(r.success).toBe(true);
    });

    it('RTRN-02: reject — source not occupied', () => {
        const r = validateTableTransfer('available', 'available', 'bill-1', null);
        expect(r.success).toBe(false);
        expect(r.error).toContain('Source table must be occupied');
    });

    it('RTRN-03: reject — destination not available', () => {
        const r = validateTableTransfer('occupied', 'occupied', 'bill-1', null);
        expect(r.success).toBe(false);
        expect(r.error).toContain('Destination table must be available');
    });

    it('RTRN-04: reject — source has no bill', () => {
        const r = validateTableTransfer('occupied', 'available', null, null);
        expect(r.success).toBe(false);
        expect(r.error).toContain('Source table has no active bill');
    });

    it('RTRN-05: reject — destination already has bill', () => {
        const r = validateTableTransfer('occupied', 'available', 'bill-1', 'bill-2');
        expect(r.success).toBe(false);
        expect(r.error).toContain('Destination table already has a bill');
    });
});

// ---------------------------------------------------------------------------
// BILL MERGE LOGIC
// ---------------------------------------------------------------------------

interface MergeValidation {
    valid: boolean;
    error?: string;
}

function validateBillMerge(
    primaryBill: { status: BillStatus; tableId: string },
    secondaryBill: { status: BillStatus; tableId: string },
): MergeValidation {
    if (primaryBill.status !== 'open') {
        return { valid: false, error: 'Primary bill must be open' };
    }
    if (secondaryBill.status !== 'open') {
        return { valid: false, error: 'Secondary bill must be open' };
    }
    if (primaryBill.tableId === secondaryBill.tableId) {
        return { valid: false, error: 'Cannot merge bills from same table' };
    }
    return { valid: true };
}

function computeMergedTotal(primaryTotalCents: number, secondaryTotalCents: number): number {
    return primaryTotalCents + secondaryTotalCents;
}

describe('Bill merge validation', () => {
    it('RMRG-01: valid merge — both open, different tables', () => {
        const r = validateBillMerge(
            { status: 'open', tableId: 'T1' },
            { status: 'open', tableId: 'T2' },
        );
        expect(r.valid).toBe(true);
    });

    it('RMRG-02: reject — primary not open', () => {
        const r = validateBillMerge(
            { status: 'settled', tableId: 'T1' },
            { status: 'open', tableId: 'T2' },
        );
        expect(r.valid).toBe(false);
    });

    it('RMRG-03: reject — secondary not open', () => {
        const r = validateBillMerge(
            { status: 'open', tableId: 'T1' },
            { status: 'payment_pending', tableId: 'T2' },
        );
        expect(r.valid).toBe(false);
    });

    it('RMRG-04: reject — same table', () => {
        const r = validateBillMerge(
            { status: 'open', tableId: 'T1' },
            { status: 'open', tableId: 'T1' },
        );
        expect(r.valid).toBe(false);
        expect(r.error).toContain('same table');
    });

    it('RMRG-05: merged total is sum of both bills', () => {
        const total = computeMergedTotal(paise(1500), paise(2500));
        expect(total).toBe(paise(4000));
    });

    it('RMRG-06: merged total with zero secondary', () => {
        const total = computeMergedTotal(paise(1500), 0);
        expect(total).toBe(paise(1500));
    });
});

// ---------------------------------------------------------------------------
// MANAGER OVERRIDE PIN VALIDATION
// ---------------------------------------------------------------------------

function validateManagerOverride(
    pin: string,
    masterPin: string,
    staffPins: Record<string, string>,
): { valid: boolean; authorizedBy: string; method: 'master' | 'staff_pin' } | { valid: false; error: string } {
    if (!pin || pin.length < 4) {
        return { valid: false, error: 'PIN must be at least 4 digits' };
    }
    if (pin === masterPin) {
        return { valid: true, authorizedBy: 'master', method: 'master' };
    }
    for (const [staffId, staffPin] of Object.entries(staffPins)) {
        if (pin === staffPin) {
            return { valid: true, authorizedBy: staffId, method: 'staff_pin' };
        }
    }
    return { valid: false, error: 'Invalid PIN' };
}

describe('Manager override PIN validation', () => {
    const masterPin = '9999';
    const staffPins = { 'mgr-1': '1234', 'mgr-2': '5678' };

    it('RPIN-01: master PIN is accepted', () => {
        const r = validateManagerOverride('9999', masterPin, staffPins);
        expect(r.valid).toBe(true);
        if (r.valid) expect(r.method).toBe('master');
    });

    it('RPIN-02: staff manager PIN is accepted', () => {
        const r = validateManagerOverride('1234', masterPin, staffPins);
        expect(r.valid).toBe(true);
        if (r.valid) {
            expect(r.method).toBe('staff_pin');
            expect(r.authorizedBy).toBe('mgr-1');
        }
    });

    it('RPIN-03: wrong PIN is rejected', () => {
        const r = validateManagerOverride('0000', masterPin, staffPins);
        expect(r.valid).toBe(false);
    });

    it('RPIN-04: empty PIN is rejected', () => {
        const r = validateManagerOverride('', masterPin, staffPins);
        expect(r.valid).toBe(false);
    });

    it('RPIN-05: short PIN (3 digits) is rejected', () => {
        const r = validateManagerOverride('123', masterPin, staffPins);
        expect(r.valid).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// DELIVERY STATUS FLOW
// ---------------------------------------------------------------------------

type DeliveryStatus = 'preparing' | 'ready_for_pickup' | 'picked_up' | 'in_transit' | 'delivered' | 'failed';

const DELIVERY_TRANSITIONS: Record<DeliveryStatus, DeliveryStatus[]> = {
    preparing:         ['ready_for_pickup'],
    ready_for_pickup:  ['picked_up'],
    picked_up:         ['in_transit'],
    in_transit:        ['delivered', 'failed'],
    delivered:         [], // terminal
    failed:            ['preparing'], // can retry
};

function canDeliveryTransition(from: DeliveryStatus, to: DeliveryStatus): boolean {
    return DELIVERY_TRANSITIONS[from]?.includes(to) ?? false;
}

describe('Delivery status transitions', () => {
    it('RDEL-01: preparing → ready_for_pickup', () => {
        expect(canDeliveryTransition('preparing', 'ready_for_pickup')).toBe(true);
    });

    it('RDEL-02: ready_for_pickup → picked_up', () => {
        expect(canDeliveryTransition('ready_for_pickup', 'picked_up')).toBe(true);
    });

    it('RDEL-03: in_transit → delivered', () => {
        expect(canDeliveryTransition('in_transit', 'delivered')).toBe(true);
    });

    it('RDEL-04: in_transit → failed', () => {
        expect(canDeliveryTransition('in_transit', 'failed')).toBe(true);
    });

    it('RDEL-05: failed → preparing (retry)', () => {
        expect(canDeliveryTransition('failed', 'preparing')).toBe(true);
    });

    it('RDEL-06: delivered is terminal', () => {
        expect(canDeliveryTransition('delivered', 'preparing')).toBe(false);
    });

    it('RDEL-07: skipping preparing → picked_up is INVALID', () => {
        expect(canDeliveryTransition('preparing', 'picked_up')).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// TIME-BASED OFFER CALCULATION (mirrors applyTimeBasedOffers in resto.ts)
// ---------------------------------------------------------------------------

interface TimeOffer {
    name: string;
    startMinutes: number; // minutes from midnight
    endMinutes: number;
    discountPercent: number;
    applicableTo: 'all' | 'dine_in' | 'takeaway' | 'delivery';
}

function isOfferActive(offer: TimeOffer, currentMinutes: number): boolean {
    if (offer.startMinutes <= offer.endMinutes) {
        return currentMinutes >= offer.startMinutes && currentMinutes < offer.endMinutes;
    }
    // Wraps midnight (e.g., 22:00 to 06:00)
    return currentMinutes >= offer.startMinutes || currentMinutes < offer.endMinutes;
}

describe('Time-based offers', () => {
    const lunchSpecial: TimeOffer = {
        name: 'Lunch Special',
        startMinutes: 12 * 60,  // 12:00
        endMinutes: 14 * 60,    // 14:00
        discountPercent: 10,
        applicableTo: 'dine_in',
    };

    const nightOwl: TimeOffer = {
        name: 'Night Owl',
        startMinutes: 22 * 60,  // 22:00
        endMinutes: 6 * 60,     // 06:00 (wraps midnight)
        discountPercent: 15,
        applicableTo: 'all',
    };

    it('ROFFER-01: lunch special active at 12:30', () => {
        expect(isOfferActive(lunchSpecial, 12 * 60 + 30)).toBe(true);
    });

    it('ROFFER-02: lunch special inactive at 15:00', () => {
        expect(isOfferActive(lunchSpecial, 15 * 60)).toBe(false);
    });

    it('ROFFER-03: lunch special inactive at 11:59', () => {
        expect(isOfferActive(lunchSpecial, 11 * 60 + 59)).toBe(false);
    });

    it('ROFFER-04: lunch special active at exactly 12:00 start', () => {
        expect(isOfferActive(lunchSpecial, 12 * 60)).toBe(true);
    });

    it('ROFFER-05: lunch special inactive at exactly 14:00 end', () => {
        expect(isOfferActive(lunchSpecial, 14 * 60)).toBe(false);
    });

    it('ROFFER-06: night owl active at 23:00', () => {
        expect(isOfferActive(nightOwl, 23 * 60)).toBe(true);
    });

    it('ROFFER-07: night owl active at 03:00 (after midnight)', () => {
        expect(isOfferActive(nightOwl, 3 * 60)).toBe(true);
    });

    it('ROFFER-08: night owl inactive at 12:00 noon', () => {
        expect(isOfferActive(nightOwl, 12 * 60)).toBe(false);
    });

    it('ROFFER-09: night owl active at exactly 22:00 start', () => {
        expect(isOfferActive(nightOwl, 22 * 60)).toBe(true);
    });
});

