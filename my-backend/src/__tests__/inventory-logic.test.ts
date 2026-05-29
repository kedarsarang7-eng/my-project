// ============================================================================
// UT-STOCK — Inventory Logic Unit Tests
// Coverage: Stock decrement/increment, reversal, dead-stock, low-stock boundary,
//           negative stock guard, batch FIFO deduction order
// ============================================================================

// ── Mocks ────────────────────────────────────────────────────────────────────
const mockGetItem    = jest.fn();
const mockPutItem    = jest.fn();
const mockQueryItems = jest.fn();
const mockUpdateItem = jest.fn();
const mockTransact   = jest.fn();
const mockRecordRevision = jest.fn().mockResolvedValue(undefined);

jest.mock('../config/dynamodb.config', () => ({
  Keys: {
    tenantPK:     (id: string) => `TENANT#${id}`,
    productSK:    (id: string) => `PRODUCT#${id}`,
    barcodeGSI3PK:(id: string) => `TENANT#${id}`,
    barcodeGSI3SK:(b: string)  => `BARCODE#${b}`,
    skuGSI1SK:    (s: string)  => `SKU#${s}`,
    medbatchSK:   (id: string) => `MEDBATCH#${id}`,
  },
  getItem:      (...a: any[]) => mockGetItem(...a),
  putItem:      (...a: any[]) => mockPutItem(...a),
  queryItems:   (...a: any[]) => mockQueryItems(...a),
  updateItem:   (...a: any[]) => mockUpdateItem(...a),
  transactWrite:(...a: any[]) => mockTransact(...a),
  tableName: 'DukanX-Table',
}));

jest.mock('../services/revision-history.service', () => ({
  recordRevision: (...a: any[]) => mockRecordRevision(...a),
}));

import { InventoryService } from '../services/inventory.service';

// ── Pure stock-math helpers (matching application logic) ─────────────────────
function decrementStock(current: number, requested: number): number {
  if (current < requested) throw new Error(`InsufficientStock: available=${current}, requested=${requested}`);
  return current - requested;
}

function incrementStock(current: number, received: number): number {
  if (received < 0) throw new Error('ReceivedQtyNegative');
  return current + received;
}

function reversalStock(current: number, reversalQty: number): number {
  if (reversalQty <= 0) throw new Error('ReversalQtyMustBePositive');
  return current + reversalQty;
}

function isLowStock(current: number, threshold: number): boolean {
  return current <= threshold;
}

function isDeadStock(current: number, threshold: number, daysSinceLastSale: number): boolean {
  return current > threshold && daysSinceLastSale >= 90;
}

// ── FIFO Batch deduction helper (pure logic) ──────────────────────────────────
interface Batch {
  batchNumber: string;
  expiryDate: string;
  availableQty: number;
}

function deductFIFO(batches: Batch[], requestedQty: number): { operations: { batch: string; deducted: number }[]; remaining: number } {
  // Sort by expiry date ascending (oldest expiry first = FIFO for pharma)
  const sorted = [...batches].sort((a, b) => a.expiryDate.localeCompare(b.expiryDate));
  const operations: { batch: string; deducted: number }[] = [];
  let remaining = requestedQty;

  for (const batch of sorted) {
    if (remaining <= 0) break;
    const deducted = Math.min(batch.availableQty, remaining);
    operations.push({ batch: batch.batchNumber, deducted });
    remaining -= deducted;
  }

  return { operations, remaining };
}

// ============================================================================
// 1. STOCK DECREMENT
// ============================================================================

describe('UT-STOCK-001: Stock Decrement on Invoice Creation', () => {
  test('Normal decrement: 100 - 5 = 95', () => {
    expect(decrementStock(100, 5)).toBe(95);
  });

  test('Decrement to exactly zero: 10 - 10 = 0', () => {
    expect(decrementStock(10, 10)).toBe(0);
  });

  test('Decrement by 1: 1 - 1 = 0', () => {
    expect(decrementStock(1, 1)).toBe(0);
  });

  test('Negative stock guard: throws when requested > available', () => {
    expect(() => decrementStock(5, 10)).toThrow('InsufficientStock');
    expect(() => decrementStock(5, 10)).toThrow('available=5, requested=10');
  });

  test('Negative stock guard: exactly at boundary (available=0, requested=1) throws', () => {
    expect(() => decrementStock(0, 1)).toThrow('InsufficientStock');
  });

  test('Negative stock guard: does not silently underflow to negative', () => {
    let stock = 3;
    expect(() => { stock = decrementStock(stock, 5); }).toThrow();
    expect(stock).toBe(3); // unchanged on failure
  });

  test('Fractional qty decrement: 10.5 - 2.25 = 8.25', () => {
    const result = decrementStock(10.5, 2.25);
    expect(Math.round(result * 100) / 100).toBe(8.25);
  });
});

// ============================================================================
// 2. STOCK INCREMENT (Purchase Entry / GRN)
// ============================================================================

describe('UT-STOCK-002: Stock Increment on Purchase Entry', () => {
  test('Normal increment: 50 + 100 = 150', () => {
    expect(incrementStock(50, 100)).toBe(150);
  });

  test('Increment from zero: 0 + 200 = 200', () => {
    expect(incrementStock(0, 200)).toBe(200);
  });

  test('Increment with fractional qty: 10.5 + 4.75 = 15.25', () => {
    expect(incrementStock(10.5, 4.75)).toBe(15.25);
  });

  test('Zero received quantity is allowed (no-op): 50 + 0 = 50', () => {
    expect(incrementStock(50, 0)).toBe(50);
  });

  test('Negative received quantity throws (guards against reverse PO)', () => {
    expect(() => incrementStock(50, -10)).toThrow('ReceivedQtyNegative');
  });
});

// ============================================================================
// 3. STOCK REVERSAL
// ============================================================================

describe('UT-STOCK-003: Stock Reversal Correctness', () => {
  test('Reversal restores stock: 95 + 5 = 100', () => {
    expect(reversalStock(95, 5)).toBe(100);
  });

  test('Full reversal of emptied stock: 0 + 50 = 50', () => {
    expect(reversalStock(0, 50)).toBe(50);
  });

  test('Partial reversal: 80 + 3 = 83', () => {
    expect(reversalStock(80, 3)).toBe(83);
  });

  test('Reversal qty must be positive — zero throws', () => {
    expect(() => reversalStock(10, 0)).toThrow('ReversalQtyMustBePositive');
  });

  test('Reversal qty must be positive — negative throws', () => {
    expect(() => reversalStock(10, -5)).toThrow('ReversalQtyMustBePositive');
  });
});

// ============================================================================
// 4. DEAD STOCK THRESHOLD
// ============================================================================

describe('UT-STOCK-004: Dead Stock Threshold Crossing', () => {
  test('isDeadStock: stock=100, threshold=5, days=90 → true', () => {
    expect(isDeadStock(100, 5, 90)).toBe(true);
  });

  test('isDeadStock: exactly 90 days (boundary) → true', () => {
    expect(isDeadStock(50, 10, 90)).toBe(true);
  });

  test('isDeadStock: 89 days (one below boundary) → false', () => {
    expect(isDeadStock(50, 10, 89)).toBe(false);
  });

  test('isDeadStock: stock <= threshold → false (still selling)', () => {
    expect(isDeadStock(5, 5, 180)).toBe(false);
  });

  test('isDeadStock: zero stock → false (nothing to mark dead)', () => {
    expect(isDeadStock(0, 5, 180)).toBe(false);
  });
});

// ============================================================================
// 5. LOW STOCK ALERT BOUNDARY
// ============================================================================

describe('UT-STOCK-005: Low Stock Alert Trigger Boundary', () => {
  const threshold = 10;

  test('Exactly at threshold (10) → low stock = true', () => {
    expect(isLowStock(10, threshold)).toBe(true);
  });

  test('One above threshold (11) → low stock = false', () => {
    expect(isLowStock(11, threshold)).toBe(false);
  });

  test('One below threshold (9) → low stock = true', () => {
    expect(isLowStock(9, threshold)).toBe(true);
  });

  test('Zero stock → low stock = true', () => {
    expect(isLowStock(0, threshold)).toBe(true);
  });

  test('After decrement crossing threshold triggers alert', () => {
    let stock = 11;
    stock = decrementStock(stock, 2); // → 9, crosses threshold of 10
    expect(isLowStock(stock, threshold)).toBe(true);
  });

  test('After decrement still above threshold → no alert', () => {
    let stock = 20;
    stock = decrementStock(stock, 5); // → 15, above threshold 10
    expect(isLowStock(stock, threshold)).toBe(false);
  });

  test('Custom threshold 0 → alert only at zero', () => {
    expect(isLowStock(1, 0)).toBe(false);
    expect(isLowStock(0, 0)).toBe(true);
  });
});

// ============================================================================
// 6. BATCH & EXPIRY FIFO DEDUCTION
// ============================================================================

describe('UT-STOCK-006: Batch & Expiry FIFO Deduction Order', () => {
  const batches: Batch[] = [
    { batchNumber: 'B001', expiryDate: '2025-06-30', availableQty: 10 },
    { batchNumber: 'B002', expiryDate: '2025-03-15', availableQty: 20 }, // oldest expiry
    { batchNumber: 'B003', expiryDate: '2026-01-01', availableQty: 30 },
  ];

  test('FIFO: deducts from earliest-expiry batch first', () => {
    const result = deductFIFO(batches, 5);
    expect(result.operations[0].batch).toBe('B002'); // oldest expiry
    expect(result.operations[0].deducted).toBe(5);
    expect(result.remaining).toBe(0);
  });

  test('FIFO: exhausts first batch then moves to next oldest', () => {
    const result = deductFIFO(batches, 25);
    expect(result.operations[0].batch).toBe('B002');
    expect(result.operations[0].deducted).toBe(20); // exhausts B002
    expect(result.operations[1].batch).toBe('B001');
    expect(result.operations[1].deducted).toBe(5); // takes remainder from B001
    expect(result.remaining).toBe(0);
  });

  test('FIFO: request exactly equal to first batch qty', () => {
    const result = deductFIFO(batches, 20);
    expect(result.operations.length).toBe(1);
    expect(result.operations[0].batch).toBe('B002');
    expect(result.operations[0].deducted).toBe(20);
    expect(result.remaining).toBe(0);
  });

  test('FIFO: partial fulfillment returns remaining > 0', () => {
    const smallBatches: Batch[] = [
      { batchNumber: 'X001', expiryDate: '2025-01-01', availableQty: 3 },
      { batchNumber: 'X002', expiryDate: '2025-02-01', availableQty: 2 },
    ];
    const result = deductFIFO(smallBatches, 10);
    expect(result.remaining).toBe(5); // only 5 available, 10 requested
  });

  test('FIFO: single batch sufficient → one operation', () => {
    const singleBatch: Batch[] = [
      { batchNumber: 'S001', expiryDate: '2025-12-31', availableQty: 100 },
    ];
    const result = deductFIFO(singleBatch, 30);
    expect(result.operations.length).toBe(1);
    expect(result.operations[0].deducted).toBe(30);
    expect(result.remaining).toBe(0);
  });

  test('FIFO: three batches needed to fulfil large order', () => {
    const multiBatches: Batch[] = [
      { batchNumber: 'M001', expiryDate: '2025-01-10', availableQty: 10 },
      { batchNumber: 'M002', expiryDate: '2025-02-10', availableQty: 10 },
      { batchNumber: 'M003', expiryDate: '2025-03-10', availableQty: 10 },
    ];
    const result = deductFIFO(multiBatches, 30);
    expect(result.operations.length).toBe(3);
    expect(result.remaining).toBe(0);
    // Verify FIFO order
    expect(result.operations[0].batch).toBe('M001');
    expect(result.operations[1].batch).toBe('M002');
    expect(result.operations[2].batch).toBe('M003');
  });

  test('FIFO: empty batches array → all remaining unmet', () => {
    const result = deductFIFO([], 10);
    expect(result.operations.length).toBe(0);
    expect(result.remaining).toBe(10);
  });
});

// ============================================================================
// 7. INVENTORY SERVICE — createItem via DynamoDB mock
// ============================================================================

describe('UT-STOCK-007: InventoryService.createItem (DynamoDB mock)', () => {
  const service = new InventoryService();

  beforeEach(() => {
    jest.clearAllMocks();
    mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    mockPutItem.mockResolvedValue(undefined);
  });

  test('Creates item with correct PK/SK structure', async () => {
    await service.createItem('tenant-1', {
      name: 'Paracetamol 500mg',
      sku: 'SKU-001',
      currentStock: 100,
      lowStockThreshold: 20,
      salePriceCents: 500,
    }, 'user-1');

    expect(mockPutItem).toHaveBeenCalledWith(
      expect.objectContaining({
        PK: 'TENANT#tenant-1',
        SK: expect.stringMatching(/^PRODUCT#/),
        name: 'Paracetamol 500mg',
        currentStock: 100,
        lowStockThreshold: 20,
      }),
      'attribute_not_exists(PK)',
    );
  });

  test('Rejects duplicate barcode within same tenant', async () => {
    mockQueryItems.mockResolvedValueOnce({
      items: [{ id: 'existing-product', name: 'Another Item' }],
    });

    await expect(service.createItem('tenant-1', {
      name: 'New Item',
      barcode: '1234567890123',
    })).rejects.toThrow();
  });

  test('Records revision on create', async () => {
    await service.createItem('tenant-1', { name: 'Widget', currentStock: 50 }, 'actor-1');
    expect(mockRecordRevision).toHaveBeenCalledWith(
      'tenant-1', 'inventory', expect.any(String), 'create', 'actor-1',
      null,
      expect.objectContaining({ name: 'Widget', currentStock: 50 }),
      expect.any(Object),
    );
  });
});
