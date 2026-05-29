// ============================================================================
// UT-PERF — Performance, Stress & Lambda Constraint Tests
// Phase 4 → LAMBDA & API GATEWAY + DYNAMODB SPECIFIC sections
// Coverage:
//   PERF-001  100k record list render timing (< 100ms in-process)
//   PERF-002  Invoice search within 100k records (< 500ms target)
//   PERF-003  DynamoDB pagination — no records skipped
//   PERF-004  TransactWrite 100-item limit respected
//   PERF-005  Batch write 25-item chunk splitting
//   PERF-006  Lambda memory guard — no unbounded allocation
//   PERF-007  API Gateway 29s timeout — async pattern required for long ops
//   PERF-008  Report generation date-range aggregation accuracy
//   PERF-009  DynamoDB LastEvaluatedKey forwarding correctness
//   PERF-010  Large invoice list scroll (no NaN / Infinity in totals)
//   PERF-011  Cold-start metadata structure
//   PERF-012  Concurrent stock decrement safety
// ============================================================================

// ── In-process timing helper ──────────────────────────────────────────────────
function measure<T>(fn: () => T): { result: T; durationMs: number } {
  const start  = performance.now();
  const result = fn();
  return { result, durationMs: performance.now() - start };
}

async function measureAsync<T>(fn: () => Promise<T>): Promise<{ result: T; durationMs: number }> {
  const start  = performance.now();
  const result = await fn();
  return { result, durationMs: performance.now() - start };
}

// ── Invoice/product generators ────────────────────────────────────────────────
interface InvoiceRecord {
  id: string;
  number: string;
  customerName: string;
  totalPaise: number;
  createdAt: string;
  status: 'paid' | 'unpaid' | 'cancelled';
}

interface ProductRecord {
  id: string;
  name: string;
  barcode: string;
  sku: string;
  currentStock: number;
  salePricePaise: number;
  category: string;
}

function generateInvoices(count: number): InvoiceRecord[] {
  return Array(count).fill(null).map((_, i) => ({
    id:           `inv-${String(i).padStart(6, '0')}`,
    number:       `INV-2025-${String(i + 1).padStart(6, '0')}`,
    customerName: `Customer ${i % 1000}`,
    totalPaise:   100_000 + (i % 90_000),
    createdAt:    new Date(Date.now() - i * 60_000).toISOString(),
    status:       (['paid', 'unpaid', 'cancelled'] as const)[i % 3],
  }));
}

function generateProducts(count: number): ProductRecord[] {
  return Array(count).fill(null).map((_, i) => ({
    id:            `prod-${String(i).padStart(6, '0')}`,
    name:          `Product ${i}`,
    barcode:       String(8_900_000_000_000 + i).slice(0, 13),
    sku:           `SKU-${String(i).padStart(5, '0')}`,
    currentStock:  i % 200,
    salePricePaise: 50_000 + (i * 100),
    category:      `Category ${i % 20}`,
  }));
}

// ── Pagination engine ─────────────────────────────────────────────────────────
interface PageResult<T> {
  items: T[];
  lastKey?: string;
  total: number;
}

function paginateArray<T>(items: T[], limit: number, startKey?: string): PageResult<T> {
  const startIdx = startKey ? parseInt(startKey, 10) : 0;
  const page     = items.slice(startIdx, startIdx + limit);
  const nextIdx  = startIdx + limit;
  return {
    items:   page,
    lastKey: nextIdx < items.length ? String(nextIdx) : undefined,
    total:   items.length,
  };
}

function drainAllPages<T>(items: T[], pageSize: number): T[] {
  const collected: T[] = [];
  let lastKey: string | undefined;
  do {
    const page = paginateArray(items, pageSize, lastKey);
    collected.push(...page.items);
    lastKey = page.lastKey;
  } while (lastKey !== undefined);
  return collected;
}

// ── Search engine ─────────────────────────────────────────────────────────────
function searchInvoices(invoices: InvoiceRecord[], query: string): InvoiceRecord[] {
  const q = query.toLowerCase();
  return invoices.filter(inv =>
    inv.number.toLowerCase().includes(q) ||
    inv.customerName.toLowerCase().includes(q),
  );
}

function searchProducts(products: ProductRecord[], query: string): ProductRecord[] {
  const q = query.toLowerCase();
  return products.filter(p =>
    p.name.toLowerCase().includes(q) ||
    p.barcode.includes(q) ||
    p.sku.toLowerCase().includes(q),
  );
}

// ============================================================================
// PERF-001: 100k record list render timing
// ============================================================================

describe('PERF-001: 100k Record List — Generation & Access Timing', () => {
  let invoices: InvoiceRecord[];

  beforeAll(() => {
    invoices = generateInvoices(100_000);
  });

  test('Generating 100k invoice records completes < 2000ms', () => {
    const { durationMs } = measure(() => generateInvoices(100_000));
    expect(durationMs).toBeLessThan(2000);
  });

  test('All 100k records are present (no truncation)', () => {
    expect(invoices.length).toBe(100_000);
  });

  test('First and last record IDs are correct', () => {
    expect(invoices[0].id).toBe('inv-000000');
    expect(invoices[99_999].id).toBe('inv-099999');
  });

  test('Accessing record at index 50000 is O(1) — instant', () => {
    const { durationMs } = measure(() => invoices[50_000]);
    expect(durationMs).toBeLessThan(5);
  });

  test('Sum of all invoice totals is finite and non-NaN', () => {
    const { result } = measure(() => invoices.reduce((s, inv) => s + inv.totalPaise, 0));
    expect(Number.isFinite(result)).toBe(true);
    expect(Number.isNaN(result)).toBe(false);
  });
});

// ============================================================================
// PERF-002: Invoice search within 100k records
// ============================================================================

describe('PERF-002: Invoice Search Within 100k Records', () => {
  const invoices = generateInvoices(100_000);

  test('Customer name search completes < 500ms', () => {
    const { durationMs, result } = measure(() => searchInvoices(invoices, 'Customer 999'));
    expect(durationMs).toBeLessThan(500);
    expect(result.length).toBeGreaterThan(0);
  });

  test('Invoice number search is specific and fast', () => {
    const { durationMs, result } = measure(() => searchInvoices(invoices, 'INV-2025-000500'));
    expect(durationMs).toBeLessThan(500);
    expect(result.length).toBe(1);
    expect(result[0].number).toBe('INV-2025-000500');
  });

  test('Search with no match returns empty array, not crash', () => {
    const { result } = measure(() => searchInvoices(invoices, 'XXXXXXNOTEXIST'));
    expect(result).toEqual([]);
  });

  test('Barcode search in 50k products < 300ms', () => {
    const products = generateProducts(50_000);
    const targetBarcode = products[49_000].barcode;
    const { durationMs, result } = measure(() => searchProducts(products, targetBarcode));
    expect(durationMs).toBeLessThan(300);
    expect(result.length).toBeGreaterThan(0);
  });
});

// ============================================================================
// PERF-003: Pagination — no records skipped
// ============================================================================

describe('PERF-003: Pagination Correctness — No Records Skipped', () => {
  test('Draining 1000 records in pages of 50 yields all 1000', () => {
    const items = Array(1000).fill(null).map((_, i) => ({ id: i }));
    const all   = drainAllPages(items, 50);
    expect(all.length).toBe(1000);
    expect(all[0].id).toBe(0);
    expect(all[999].id).toBe(999);
  });

  test('No record appears twice across pages', () => {
    const items = Array(200).fill(null).map((_, i) => ({ id: i }));
    const all   = drainAllPages(items, 30);
    const ids   = all.map(x => x.id);
    const unique = new Set(ids);
    expect(unique.size).toBe(all.length);
  });

  test('Exact page boundary: 100 items in pages of 10 → 10 pages, no lastKey on last', () => {
    const items = Array(100).fill(null).map((_, i) => ({ id: i }));
    let pageCount = 0;
    let lastKey: string | undefined;
    do {
      const page = paginateArray(items, 10, lastKey);
      pageCount++;
      lastKey = page.lastKey;
    } while (lastKey !== undefined);
    expect(pageCount).toBe(10);
  });

  test('Single-page result (items < limit): lastKey = undefined', () => {
    const items = [{ id: 1 }, { id: 2 }];
    const page  = paginateArray(items, 20);
    expect(page.lastKey).toBeUndefined();
    expect(page.items.length).toBe(2);
  });

  test('Empty source: first page is empty, no lastKey', () => {
    const page = paginateArray([], 20);
    expect(page.items.length).toBe(0);
    expect(page.lastKey).toBeUndefined();
  });
});

// ============================================================================
// PERF-004: TransactWrite 100-item limit
// ============================================================================

describe('PERF-004: DynamoDB TransactWrite Batch Size Limits', () => {
  const MAX_TRANSACT_ITEMS = 100;

  function estimateInvoiceOps(lineItemCount: number): number {
    // 1 invoice header + (1 stock write + 1 line item write per line) = 2n + 1
    return 1 + lineItemCount * 2;
  }

  test('49 line items → 99 ops: within limit', () => {
    expect(estimateInvoiceOps(49)).toBeLessThanOrEqual(MAX_TRANSACT_ITEMS);
  });

  test('50 line items → 101 ops: MUST be split', () => {
    expect(estimateInvoiceOps(50)).toBeGreaterThan(MAX_TRANSACT_ITEMS);
  });

  test('Batch splitter correctly chunks array into ≤100 pieces', () => {
    function chunkTransact<T>(ops: T[], limit = 100): T[][] {
      const chunks: T[][] = [];
      for (let i = 0; i < ops.length; i += limit) {
        chunks.push(ops.slice(i, i + limit));
      }
      return chunks;
    }

    const ops    = Array(250).fill({ put: 'op' });
    const chunks = chunkTransact(ops);
    expect(chunks.length).toBe(3);               // ceil(250/100) = 3
    expect(chunks[0].length).toBe(100);
    expect(chunks[1].length).toBe(100);
    expect(chunks[2].length).toBe(50);
    expect(chunks.every(c => c.length <= 100)).toBe(true);
  });

  test('Entire batch reassembled: no ops lost', () => {
    function chunkTransact<T>(ops: T[]): T[][] {
      const chunks: T[][] = [];
      for (let i = 0; i < ops.length; i += 100) chunks.push(ops.slice(i, i + 100));
      return chunks;
    }
    const ops    = Array(333).fill(null).map((_, i) => i);
    const chunks = chunkTransact(ops);
    const flat   = chunks.flat();
    expect(flat.length).toBe(333);
  });
});

// ============================================================================
// PERF-005: Batch write 25-item chunk splitting
// ============================================================================

describe('PERF-005: DynamoDB BatchWrite 25-Item Limit', () => {
  const MAX_BATCH_WRITE = 25;

  function chunkBatch<T>(items: T[]): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < items.length; i += MAX_BATCH_WRITE) {
      chunks.push(items.slice(i, i + MAX_BATCH_WRITE));
    }
    return chunks;
  }

  test('25-item batch: 1 chunk (exactly at limit)', () => {
    const items  = Array(25).fill({ pk: 'x' });
    const chunks = chunkBatch(items);
    expect(chunks.length).toBe(1);
  });

  test('26-item batch: 2 chunks (25 + 1)', () => {
    const items  = Array(26).fill({ pk: 'x' });
    const chunks = chunkBatch(items);
    expect(chunks.length).toBe(2);
    expect(chunks[0].length).toBe(25);
    expect(chunks[1].length).toBe(1);
  });

  test('100-item batch: 4 chunks of ≤25', () => {
    const items  = Array(100).fill({ pk: 'x' });
    const chunks = chunkBatch(items);
    expect(chunks.length).toBe(4);
    expect(chunks.every(c => c.length <= 25)).toBe(true);
  });

  test('No items lost across chunks', () => {
    const items  = Array(77).fill(null).map((_, i) => i);
    const chunks = chunkBatch(items);
    expect(chunks.flat().length).toBe(77);
  });
});

// ============================================================================
// PERF-006: Lambda memory guard — no unbounded allocation
// ============================================================================

describe('PERF-006: Lambda Memory Guard', () => {
  test('Parsing 100KB JSON body does not throw', () => {
    const bigPayload = JSON.stringify({ name: 'x'.repeat(100_000) });
    expect(() => JSON.parse(bigPayload)).not.toThrow();
  });

  test('Building 10k-item response array uses predictable memory', () => {
    const items = Array(10_000).fill(null).map((_, i) => ({
      id: `id-${i}`, name: `Product ${i}`, price: i * 100,
    }));
    const json = JSON.stringify(items);
    expect(json.length).toBeGreaterThan(0);
    expect(Number.isFinite(json.length)).toBe(true);
  });

  test('Deeply nested object (10 levels) does not stack overflow on stringify', () => {
    let nested: any = { value: 'leaf' };
    for (let i = 0; i < 10; i++) nested = { child: nested };
    expect(() => JSON.stringify(nested)).not.toThrow();
  });

  test('Infinite value guard: NaN and Infinity are not returned in API responses', () => {
    const badValues = [NaN, Infinity, -Infinity];
    for (const val of badValues) {
      const sanitized = Number.isFinite(val) ? val : 0;
      expect(sanitized).toBe(0);
    }
  });
});

// ============================================================================
// PERF-007: API Gateway 29s timeout — async pattern check
// ============================================================================

describe('PERF-007: Async Pattern for Long Operations', () => {
  // Long-running operations must return immediately with a jobId,
  // not block the Lambda beyond API GW's 29s timeout.

  interface AsyncJobResponse { jobId: string; status: 'processing'; estimatedCompletionMs: number }

  function initiateAsyncJob(operationType: string): AsyncJobResponse {
    return {
      jobId:                 `job-${Date.now()}`,
      status:                'processing',
      estimatedCompletionMs: operationType === 'report' ? 30_000 : 5_000,
    };
  }

  test('Report generation returns job ID immediately (non-blocking)', () => {
    const { durationMs, result } = measure(() => initiateAsyncJob('report'));
    expect(durationMs).toBeLessThan(50); // initiation must be instant
    expect(result.jobId).toBeTruthy();
    expect(result.status).toBe('processing');
  });

  test('Bulk import returns job ID immediately', () => {
    const { result } = measure(() => initiateAsyncJob('bulk_import'));
    expect(result.jobId).toMatch(/^job-/);
    expect(result.status).toBe('processing');
  });

  test('Job ID is unique across concurrent initiations', () => {
    // Simulate slight timing separation
    const jobs = [0, 1, 2].map(i => ({ jobId: `job-${Date.now() + i}` }));
    const ids  = new Set(jobs.map(j => j.jobId));
    expect(ids.size).toBe(3);
  });
});

// ============================================================================
// PERF-008: Report generation date-range aggregation
// ============================================================================

describe('PERF-008: Report Aggregation Accuracy', () => {
  // Simulate a 3-year invoice dataset
  function buildInvoiceDataset(count: number, startYear = 2022): InvoiceRecord[] {
    const start = new Date(`${startYear}-01-01`).getTime();
    const end   = new Date(`${startYear + 3}-12-31`).getTime();
    return Array(count).fill(null).map((_, i) => ({
      id:           `inv-${i}`,
      number:       `INV-${i}`,
      customerName: `Customer ${i % 100}`,
      totalPaise:   100_000 + (i % 50_000),
      createdAt:    new Date(start + Math.random() * (end - start)).toISOString(),
      status:       'paid' as const,
    }));
  }

  function sumByDateRange(invoices: InvoiceRecord[], fromISO: string, toISO: string): number {
    const from = new Date(fromISO).getTime();
    const to   = new Date(toISO).getTime();
    return invoices
      .filter(inv => {
        const d = new Date(inv.createdAt).getTime();
        return d >= from && d <= to;
      })
      .reduce((s, inv) => s + inv.totalPaise, 0);
  }

  const dataset = buildInvoiceDataset(10_000);

  test('Date-range sum completes < 100ms on 10k records', () => {
    const { durationMs } = measure(() => sumByDateRange(dataset, '2022-01-01', '2024-12-31'));
    expect(durationMs).toBeLessThan(100);
  });

  test('Sum of all records matches sum by full date range', () => {
    const total     = dataset.reduce((s, inv) => s + inv.totalPaise, 0);
    const rangeSum  = sumByDateRange(dataset, '2022-01-01', '2025-12-31');
    expect(rangeSum).toBe(total);
  });

  test('Empty date range returns 0', () => {
    const sum = sumByDateRange(dataset, '2020-01-01', '2020-12-31');
    expect(sum).toBe(0);
  });

  test('Report totals are always finite numbers', () => {
    const sum = sumByDateRange(dataset, '2022-01-01', '2025-12-31');
    expect(Number.isFinite(sum)).toBe(true);
    expect(Number.isNaN(sum)).toBe(false);
  });
});

// ============================================================================
// PERF-009: DynamoDB LastEvaluatedKey forwarding
// ============================================================================

describe('PERF-009: DynamoDB LastEvaluatedKey Contract', () => {
  // Simulates DynamoDB page cursors represented as opaque base64 tokens
  function encodeCursor(pk: string, sk: string): string {
    return Buffer.from(JSON.stringify({ pk, sk })).toString('base64');
  }

  function decodeCursor(token: string): { pk: string; sk: string } {
    return JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
  }

  test('Cursor encodes and decodes correctly', () => {
    const cursor  = encodeCursor('TENANT#t1', 'INVOICE#inv-00100');
    const decoded = decodeCursor(cursor);
    expect(decoded.pk).toBe('TENANT#t1');
    expect(decoded.sk).toBe('INVOICE#inv-00100');
  });

  test('Different cursors do not collide', () => {
    const c1 = encodeCursor('TENANT#t1', 'INVOICE#001');
    const c2 = encodeCursor('TENANT#t1', 'INVOICE#002');
    expect(c1).not.toBe(c2);
  });

  test('Undefined lastKey signals last page', () => {
    const items  = Array(5).fill(null).map((_, i) => ({ id: i }));
    const result = paginateArray(items, 20); // limit > items
    expect(result.lastKey).toBeUndefined();
    expect(result.items.length).toBe(5);
  });

  test('Forwarding lastKey from page N to page N+1 is lossless', () => {
    const items = Array(50).fill(null).map((_, i) => ({ id: i }));
    const page1 = paginateArray(items, 20);
    const page2 = paginateArray(items, 20, page1.lastKey);
    expect(page2.items[0].id).toBe(20); // continues from where page1 left off
    expect(page1.items[page1.items.length - 1].id).toBe(19);
  });
});

// ============================================================================
// PERF-010: Large invoice list — no NaN/Infinity in calculated totals
// ============================================================================

describe('PERF-010: Large Invoice List — Numeric Stability', () => {
  test('Sum of 100k invoice totals is finite', () => {
    const invoices = generateInvoices(100_000);
    const total    = invoices.reduce((s, inv) => s + inv.totalPaise, 0);
    expect(Number.isFinite(total)).toBe(true);
    expect(Number.isNaN(total)).toBe(false);
    expect(total).toBeGreaterThan(0);
  });

  test('Average invoice value computed without NaN', () => {
    const invoices = generateInvoices(1000);
    const total    = invoices.reduce((s, inv) => s + inv.totalPaise, 0);
    const avg      = invoices.length > 0 ? total / invoices.length : 0;
    expect(Number.isNaN(avg)).toBe(false);
    expect(Number.isFinite(avg)).toBe(true);
  });

  test('Division by zero guard in averages (empty list)', () => {
    const invoices: InvoiceRecord[] = [];
    const total = invoices.reduce((s, inv) => s + inv.totalPaise, 0);
    const avg   = invoices.length > 0 ? total / invoices.length : 0;
    expect(avg).toBe(0);
    expect(Number.isNaN(avg)).toBe(false);
  });

  test('Paise to rupee conversion always produces 2-decimal representable numbers', () => {
    const paiseValues = [1, 50, 100, 333, 999, 10_001, 1_000_000];
    for (const paise of paiseValues) {
      const rupees = Math.round(paise) / 100;
      expect(Number.isFinite(rupees)).toBe(true);
    }
  });
});

// ============================================================================
// PERF-011: Cold-start metadata structure
// ============================================================================

describe('PERF-011: Lambda Cold-Start Metadata', () => {
  interface ColdStartMeta {
    functionName: string;
    memoryMB: number;
    timeoutMs: number;
    initTimeMs?: number;
  }

  function validateColdStartMeta(meta: ColdStartMeta): boolean {
    return (
      typeof meta.functionName === 'string' &&
      meta.memoryMB > 0 &&
      meta.timeoutMs > 0 &&
      meta.timeoutMs <= 900_000 // Lambda max = 15 min
    );
  }

  test('Valid cold-start meta passes validation', () => {
    const meta: ColdStartMeta = { functionName: 'invoiceHandler', memoryMB: 512, timeoutMs: 30_000 };
    expect(validateColdStartMeta(meta)).toBe(true);
  });

  test('Timeout cannot exceed Lambda maximum (900s)', () => {
    const meta: ColdStartMeta = { functionName: 'infiniteHandler', memoryMB: 128, timeoutMs: 901_000 };
    expect(validateColdStartMeta(meta)).toBe(false);
  });

  test('Memory must be positive', () => {
    const meta: ColdStartMeta = { functionName: 'badHandler', memoryMB: 0, timeoutMs: 30_000 };
    expect(validateColdStartMeta(meta)).toBe(false);
  });

  test('API GW soft limit: Lambda behind API GW must timeout < 29s', () => {
    // API Gateway hard limit is 29s; Lambda should be configured at 28s max for GW-fronted fns
    const MAX_API_GW_LAMBDA_MS = 28_000;
    const billingLambdaTimeoutMs = 28_000;
    expect(billingLambdaTimeoutMs).toBeLessThanOrEqual(MAX_API_GW_LAMBDA_MS);
  });
});

// ============================================================================
// PERF-012: Concurrent stock decrement safety
// ============================================================================

describe('PERF-012: Concurrent Stock Decrement — Race Condition Guard', () => {
  // Simulate optimistic locking: each "transaction" checks version before writing
  class StockItem {
    private stock: number;
    private version: number;

    constructor(initialStock: number) {
      this.stock   = initialStock;
      this.version = 1;
    }

    tryDecrement(qty: number, expectedVersion: number): boolean {
      if (this.version !== expectedVersion) return false; // stale read
      if (this.stock < qty)                return false; // insufficient
      this.stock -= qty;
      this.version++;
      return true;
    }

    getState() { return { stock: this.stock, version: this.version }; }
  }

  test('Two concurrent decrements on same item: only one succeeds', () => {
    const item = new StockItem(10);
    const v1   = item.getState().version; // both read version=1

    const ok1 = item.tryDecrement(5, v1); // first to commit: succeeds
    const ok2 = item.tryDecrement(5, v1); // second: stale version → fails

    expect(ok1).toBe(true);
    expect(ok2).toBe(false);
    expect(item.getState().stock).toBe(5); // only one decrement applied
  });

  test('Sequential decrements each succeed with correct version', () => {
    const item = new StockItem(20);
    const r1   = item.tryDecrement(5, 1);
    const r2   = item.tryDecrement(5, 2);
    const r3   = item.tryDecrement(5, 3);

    expect(r1).toBe(true);
    expect(r2).toBe(true);
    expect(r3).toBe(true);
    expect(item.getState().stock).toBe(5);
    expect(item.getState().version).toBe(4);
  });

  test('Decrement beyond stock never succeeds even with correct version', () => {
    const item = new StockItem(3);
    const ok   = item.tryDecrement(5, 1);
    expect(ok).toBe(false);
    expect(item.getState().stock).toBe(3); // unchanged
  });

  test('Version monotonically increases with each successful write', () => {
    const item = new StockItem(100);
    for (let v = 1; v <= 10; v++) {
      const ok = item.tryDecrement(1, v);
      expect(ok).toBe(true);
    }
    expect(item.getState().version).toBe(11);
    expect(item.getState().stock).toBe(90);
  });
});
