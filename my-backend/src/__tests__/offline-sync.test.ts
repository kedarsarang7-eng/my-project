// ============================================================================
// UT-SYNC — Offline Sync & Conflict Resolution Tests
// Phase 2 → OFFLINE MODE section of QA master framework
// Coverage:
//   SYNC-001  Offline queue: enqueue, drain, idempotency on re-play
//   SYNC-002  Conflict resolution: last-write-wins vs. server-wins strategies
//   SYNC-003  Sync ordering: operations applied in enqueue order
//   SYNC-004  Sync status tracking: pending → syncing → synced / failed
//   SYNC-005  No data loss on app kill during offline period
//   SYNC-006  Network restore triggers sync automatically
//   SYNC-007  Duplicate event prevention on reconnect
//   SYNC-008  Large offline queue (500+ ops) drains without loss
// ============================================================================

// ── Offline queue model ───────────────────────────────────────────────────────

type SyncStatus = 'pending' | 'syncing' | 'synced' | 'failed';

interface OfflineOp {
  id: string;
  entityType: 'invoice' | 'product' | 'payment' | 'stock_adjustment';
  operation:  'create' | 'update' | 'delete';
  payload:    Record<string, unknown>;
  enqueuedAt: number;
  retryCount: number;
  status:     SyncStatus;
  idempotencyKey: string;
}

class OfflineQueue {
  private ops: OfflineOp[] = [];
  private syncedKeys: Set<string> = new Set();

  enqueue(op: Omit<OfflineOp, 'enqueuedAt' | 'retryCount' | 'status'>): void {
    if (this.syncedKeys.has(op.idempotencyKey)) return; // already synced
    const existing = this.ops.find(o => o.idempotencyKey === op.idempotencyKey);
    if (existing) return; // already queued
    this.ops.push({ ...op, enqueuedAt: Date.now(), retryCount: 0, status: 'pending' });
  }

  pending(): OfflineOp[] {
    return this.ops.filter(o => o.status === 'pending' || o.status === 'failed');
  }

  markSyncing(id: string): void {
    const op = this.ops.find(o => o.id === id);
    if (op) op.status = 'syncing';
  }

  markSynced(id: string): void {
    const op = this.ops.find(o => o.id === id);
    if (op) {
      op.status = 'synced';
      this.syncedKeys.add(op.idempotencyKey);
    }
  }

  markFailed(id: string): void {
    const op = this.ops.find(o => o.id === id);
    if (op) { op.status = 'failed'; op.retryCount++; }
  }

  size(): number          { return this.ops.length; }
  pendingCount(): number  { return this.pending().length; }
  syncedCount(): number   { return this.ops.filter(o => o.status === 'synced').length; }

  drain(syncFn: (op: OfflineOp) => boolean): void {
    // Process in enqueue order
    const toProcess = [...this.pending()].sort((a, b) => a.enqueuedAt - b.enqueuedAt);
    for (const op of toProcess) {
      this.markSyncing(op.id);
      const ok = syncFn(op);
      if (ok) this.markSynced(op.id);
      else    this.markFailed(op.id);
    }
  }
}

// ── Conflict resolver ─────────────────────────────────────────────────────────

interface VersionedRecord {
  id: string;
  version: number;
  data: Record<string, unknown>;
  updatedAt: number;
}

function resolveConflict(
  server: VersionedRecord,
  local: VersionedRecord,
  strategy: 'last-write-wins' | 'server-wins' | 'local-wins',
): VersionedRecord {
  if (strategy === 'server-wins') return server;
  if (strategy === 'local-wins')  return local;
  // last-write-wins: most recent timestamp wins
  return local.updatedAt > server.updatedAt ? local : server;
}

// ── Sync status machine ───────────────────────────────────────────────────────

const SYNC_TRANSITIONS: Record<SyncStatus, SyncStatus[]> = {
  pending:  ['syncing', 'failed'],
  syncing:  ['synced', 'failed'],
  synced:   [],
  failed:   ['pending', 'syncing'],
};

function canSyncTransition(from: SyncStatus, to: SyncStatus): boolean {
  return SYNC_TRANSITIONS[from]?.includes(to) ?? false;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
let opSeq = 0;
function makeOp(overrides: Partial<OfflineOp> = {}): Omit<OfflineOp, 'enqueuedAt' | 'retryCount' | 'status'> {
  const id = `op-${++opSeq}`;
  return {
    id,
    entityType:     'invoice',
    operation:      'create',
    payload:        { totalPaise: 100_000 },
    idempotencyKey: `idem-${id}`,
    ...overrides,
  };
}

// ============================================================================
// SYNC-001: Offline queue enqueue & drain
// ============================================================================

describe('SYNC-001: Offline Queue Enqueue & Drain', () => {
  beforeEach(() => { opSeq = 0; });

  test('Enqueuing one op: size=1, pending=1', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp());
    expect(q.size()).toBe(1);
    expect(q.pendingCount()).toBe(1);
  });

  test('Draining with successful sync: syncedCount=1, pendingCount=0', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp());
    q.drain(() => true); // sync always succeeds
    expect(q.syncedCount()).toBe(1);
    expect(q.pendingCount()).toBe(0);
  });

  test('Draining with failed sync: retryCount=1, still pending', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp());
    q.drain(() => false); // always fails
    const ops = q.pending();
    expect(ops[0].retryCount).toBe(1);
    expect(ops[0].status).toBe('failed');
  });

  test('Enqueue 10 ops, drain all: 10 synced, 0 pending', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 10; i++) q.enqueue(makeOp());
    q.drain(() => true);
    expect(q.syncedCount()).toBe(10);
    expect(q.pendingCount()).toBe(0);
  });

  test('Mixed success/failure drain: synced + failed counts correct', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 6; i++) q.enqueue(makeOp());
    let call = 0;
    q.drain(() => (++call % 2 === 1)); // odd calls succeed, even fail
    expect(q.syncedCount()).toBe(3);
    expect(q.pendingCount()).toBe(3);
  });
});

// ============================================================================
// SYNC-002: Conflict resolution strategies
// ============================================================================

describe('SYNC-002: Conflict Resolution', () => {
  const server: VersionedRecord = {
    id: 'prod-1', version: 5,
    data: { name: 'Server Version' },
    updatedAt: 1_000_000,
  };

  const local: VersionedRecord = {
    id: 'prod-1', version: 5,
    data: { name: 'Local Version' },
    updatedAt: 2_000_000, // newer
  };

  test('server-wins: always returns server record', () => {
    const resolved = resolveConflict(server, local, 'server-wins');
    expect(resolved.data.name).toBe('Server Version');
  });

  test('local-wins: always returns local record', () => {
    const resolved = resolveConflict(server, local, 'local-wins');
    expect(resolved.data.name).toBe('Local Version');
  });

  test('last-write-wins: newer timestamp wins', () => {
    const resolved = resolveConflict(server, local, 'last-write-wins');
    expect(resolved.data.name).toBe('Local Version'); // local is newer
  });

  test('last-write-wins: when server is newer, server wins', () => {
    const olderLocal: VersionedRecord = { ...local, updatedAt: 500_000 };
    const resolved = resolveConflict(server, olderLocal, 'last-write-wins');
    expect(resolved.data.name).toBe('Server Version');
  });

  test('last-write-wins: equal timestamp → server wins (conservative)', () => {
    const sameTimeLocal: VersionedRecord = { ...local, updatedAt: server.updatedAt };
    const resolved = resolveConflict(server, sameTimeLocal, 'last-write-wins');
    expect(resolved.data.name).toBe('Server Version'); // server.updatedAt >= local
  });
});

// ============================================================================
// SYNC-003: Sync ordering — FIFO
// ============================================================================

describe('SYNC-003: Sync Operation Ordering (FIFO)', () => {
  test('Operations drained in enqueue order (oldest first)', () => {
    const q = new OfflineQueue();
    const order: string[] = [];
    // Simulate time gap between enqueue calls
    const ops = ['op-first', 'op-second', 'op-third'].map((id, i) => ({
      ...makeOp(),
      id,
      idempotencyKey: `idem-${id}`,
      enqueuedAt: Date.now() + i * 1000,
    }));
    // Manually insert with controlled timestamps
    (q as any).ops = ops.map(op => ({ ...op, status: 'pending' as const, retryCount: 0 }));

    q.drain((op) => { order.push(op.id); return true; });
    expect(order[0]).toBe('op-first');
    expect(order[1]).toBe('op-second');
    expect(order[2]).toBe('op-third');
  });

  test('Invoice creation before payment: invoice comes first', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp({ entityType: 'invoice', operation: 'create', id: 'inv-001', idempotencyKey: 'idem-inv-001' }));
    q.enqueue(makeOp({ entityType: 'payment', operation: 'create', id: 'pay-001', idempotencyKey: 'idem-pay-001' }));

    const processed: string[] = [];
    q.drain(op => { processed.push(op.entityType); return true; });
    expect(processed[0]).toBe('invoice');
    expect(processed[1]).toBe('payment');
  });
});

// ============================================================================
// SYNC-004: Sync status machine transitions
// ============================================================================

describe('SYNC-004: Sync Status State Machine', () => {
  test('pending → syncing: valid', () => {
    expect(canSyncTransition('pending', 'syncing')).toBe(true);
  });

  test('syncing → synced: valid', () => {
    expect(canSyncTransition('syncing', 'synced')).toBe(true);
  });

  test('syncing → failed: valid', () => {
    expect(canSyncTransition('syncing', 'failed')).toBe(true);
  });

  test('failed → pending (retry): valid', () => {
    expect(canSyncTransition('failed', 'pending')).toBe(true);
  });

  test('synced → anything: invalid (terminal)', () => {
    expect(canSyncTransition('synced', 'pending')).toBe(false);
    expect(canSyncTransition('synced', 'syncing')).toBe(false);
    expect(canSyncTransition('synced', 'failed')).toBe(false);
  });

  test('pending → synced (skipping syncing): invalid', () => {
    expect(canSyncTransition('pending', 'synced')).toBe(false);
  });
});

// ============================================================================
// SYNC-005: No data loss on app kill (queue persistence)
// ============================================================================

describe('SYNC-005: Queue Persistence (No Data Loss on Kill)', () => {
  test('Serialized queue deserializes with all ops intact', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 5; i++) q.enqueue(makeOp());

    // Simulate serialize → persist → deserialize
    const serialized = JSON.stringify((q as any).ops);
    const restored   = JSON.parse(serialized) as OfflineOp[];

    expect(restored.length).toBe(5);
    expect(restored.every(op => op.status === 'pending')).toBe(true);
  });

  test('Partially synced queue: synced ops not re-sent on restore', () => {
    const q = new OfflineQueue();
    const op = makeOp();
    q.enqueue(op);
    q.drain(() => true); // sync succeeds

    // Try to enqueue same op again (simulating re-queued after restore)
    q.enqueue(op); // idempotency key is in syncedKeys — should be rejected

    // Size stays at 1 (not 2)
    expect(q.size()).toBe(1);
    expect(q.syncedCount()).toBe(1);
  });

  test('Pending ops survive simulated restart and drain correctly', () => {
    const ops: OfflineOp[] = Array(3).fill(null).map((_, i) => ({
      id:             `op-kill-${i}`,
      entityType:     'invoice' as const,
      operation:      'create' as const,
      payload:        { i },
      enqueuedAt:     Date.now() + i,
      retryCount:     0,
      status:         'pending' as SyncStatus,
      idempotencyKey: `idem-kill-${i}`,
    }));

    // Simulate restoring queue from persistent storage
    const q = new OfflineQueue();
    (q as any).ops = ops;

    q.drain(() => true);
    expect(q.syncedCount()).toBe(3);
  });
});

// ============================================================================
// SYNC-006: Network restore triggers sync
// ============================================================================

describe('SYNC-006: Network State & Auto-Sync Trigger', () => {
  type NetworkState = 'online' | 'offline';

  class SyncManager {
    private network: NetworkState = 'online';
    private q: OfflineQueue;
    syncTriggered = false;

    constructor(q: OfflineQueue) { this.q = q; }

    setNetwork(state: NetworkState): void {
      const wasOffline = this.network === 'offline';
      this.network = state;
      if (state === 'online' && wasOffline && this.q.pendingCount() > 0) {
        this.syncTriggered = true;
        this.q.drain(() => true);
      }
    }

    isOnline(): boolean { return this.network === 'online'; }
  }

  test('Going offline does not trigger sync', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp());
    const mgr = new SyncManager(q);
    mgr.setNetwork('offline');
    expect(mgr.syncTriggered).toBe(false);
  });

  test('Restoring network triggers sync of pending ops', () => {
    const q = new OfflineQueue();
    q.enqueue(makeOp());
    const mgr = new SyncManager(q);
    mgr.setNetwork('offline');
    mgr.setNetwork('online'); // restore
    expect(mgr.syncTriggered).toBe(true);
    expect(q.syncedCount()).toBe(1);
  });

  test('Network restore with empty queue: no sync triggered', () => {
    const q = new OfflineQueue(); // no pending ops
    const mgr = new SyncManager(q);
    mgr.setNetwork('offline');
    mgr.setNetwork('online');
    expect(mgr.syncTriggered).toBe(false);
  });
});

// ============================================================================
// SYNC-007: Duplicate event prevention on reconnect
// ============================================================================

describe('SYNC-007: Duplicate WebSocket Event Prevention', () => {
  class WsEventDeduplicator {
    private seen: Set<string> = new Set();

    process(eventId: string, handler: () => void): boolean {
      if (this.seen.has(eventId)) return false; // duplicate — skip
      this.seen.add(eventId);
      handler();
      return true;
    }

    processedCount(): number { return this.seen.size; }
  }

  test('First event is processed', () => {
    const dedup = new WsEventDeduplicator();
    let called = 0;
    const ok = dedup.process('evt-001', () => called++);
    expect(ok).toBe(true);
    expect(called).toBe(1);
  });

  test('Duplicate event (same ID) is skipped', () => {
    const dedup = new WsEventDeduplicator();
    let called = 0;
    dedup.process('evt-001', () => called++);
    const ok2 = dedup.process('evt-001', () => called++);
    expect(ok2).toBe(false);
    expect(called).toBe(1); // handler called only once
  });

  test('Different event IDs are all processed', () => {
    const dedup = new WsEventDeduplicator();
    let called = 0;
    ['evt-001', 'evt-002', 'evt-003'].forEach(id => dedup.process(id, () => called++));
    expect(called).toBe(3);
    expect(dedup.processedCount()).toBe(3);
  });

  test('Reconnect replays: 100 events with 20 duplicates — only 100 unique processed', () => {
    const dedup = new WsEventDeduplicator();
    let called = 0;
    // 100 unique events
    for (let i = 0; i < 100; i++) dedup.process(`evt-${i}`, () => called++);
    // 20 duplicates replayed on reconnect
    for (let i = 0; i < 20; i++) dedup.process(`evt-${i}`, () => called++);

    expect(called).toBe(100); // duplicates skipped
    expect(dedup.processedCount()).toBe(100);
  });
});

// ============================================================================
// SYNC-008: Large offline queue (500+ ops)
// ============================================================================

describe('SYNC-008: Large Offline Queue — 500+ Operations', () => {
  beforeEach(() => { opSeq = 0; });

  test('500 ops enqueued: size=500', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 500; i++) q.enqueue(makeOp());
    expect(q.size()).toBe(500);
  });

  test('500 ops drain: all synced, none lost', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 500; i++) q.enqueue(makeOp());
    q.drain(() => true);
    expect(q.syncedCount()).toBe(500);
    expect(q.pendingCount()).toBe(0);
  });

  test('500 ops drain completes in < 500ms (in-process)', async () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 500; i++) q.enqueue(makeOp());
    const start = performance.now();
    q.drain(() => true);
    expect(performance.now() - start).toBeLessThan(500);
  });

  test('Duplicate idempotency keys not double-enqueued', () => {
    const q = new OfflineQueue();
    const op = makeOp();
    for (let i = 0; i < 10; i++) q.enqueue(op); // same op 10 times
    expect(q.size()).toBe(1);
  });

  test('No ops lost even with mixed success/failure', () => {
    const q = new OfflineQueue();
    for (let i = 0; i < 100; i++) q.enqueue(makeOp());
    // First drain: 50% fail
    let call = 0;
    q.drain(() => ++call % 2 === 1);

    // Second drain: all remaining succeed
    q.drain(() => true);

    expect(q.syncedCount()).toBe(100);
    expect(q.pendingCount()).toBe(0);
  });
});
