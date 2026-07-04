/**
 * Property-Based Tests: Business Scoping and Cross-Business Denial at Repository Level
 *
 * Feature: openwa-whatsapp-automation, Property 30
 *
 * **Validates: Requirements 7.1, 7.5, 12.1, 12.2**
 *
 * Property 30: Every stored record and message is business-scoped, and
 *   cross-business access is denied.
 *
 * This test verifies the REPOSITORY layer enforces scoping:
 *  1. Every repository operation passes the correct businessPK to DynamoDB operations
 *  2. A repository called with business A credentials cannot see/modify business B records
 *  3. Cross-business queries (PK mismatch) return empty / null
 *  4. All CRUD operations (create, get, list, update, deactivate) enforce the partition key
 *
 * Strategy: We mock the DynamoDB config module and capture the PK/SK arguments
 * passed to getItem, putItem, queryItems, and updateItem. We then verify
 * that every invocation includes the correct TENANT#{tenantId}#BIZ#{businessId}
 * partition key — meaning the repository structurally cannot cross business boundaries.
 */

import * as fc from 'fast-check';

// ── Mock DynamoDB operations ─────────────────────────────────────────────────

const mockPutItem = jest.fn().mockResolvedValue(undefined);
const mockGetItem = jest.fn().mockResolvedValue(null);
const mockQueryItems = jest.fn().mockResolvedValue({ items: [], lastKey: undefined });
const mockUpdateItem = jest.fn().mockResolvedValue(null);

jest.mock('../../../../config/dynamodb.config', () => ({
  putItem: (...args: unknown[]) => mockPutItem(...args),
  getItem: (...args: unknown[]) => mockGetItem(...args),
  queryItems: (...args: unknown[]) => mockQueryItems(...args),
  updateItem: (...args: unknown[]) => mockUpdateItem(...args),
}));

import { CustomerProfileRepository } from '../../repositories/customer-profile.repository';
import { AutomationRuleRepository } from '../../repositories/automation-rule.repository';
import { businessPK } from '../../../../dynamodb/keys';

// ── Generators ───────────────────────────────────────────────────────────────

/** Characters safe for DynamoDB key segments (excludes '#') */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

/** Generate a valid ID segment: non-empty, no '#', no whitespace-only */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 32 },
);

/** Generate two distinct safe IDs (for cross-business tests) */
const twoDistinctIds = fc.tuple(safeIdArb, safeIdArb).filter(([a, b]) => a !== b);

/** Generate a valid E.164 number */
const e164Arb = fc.tuple(
  fc.integer({ min: 1, max: 999 }), // country code
  fc.integer({ min: 1000000, max: 9999999999 }), // subscriber
).map(([cc, sub]) => `+${cc}${sub}`);

// ── Helpers ──────────────────────────────────────────────────────────────────

function expectedPK(tenantId: string, businessId: string): string {
  return `TENANT#${tenantId}#BIZ#${businessId}`;
}

function clearMocks() {
  mockPutItem.mockClear();
  mockGetItem.mockClear();
  mockQueryItems.mockClear();
  mockUpdateItem.mockClear();
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 30 — Repository business scoping and cross-business denial', () => {
  beforeEach(() => {
    clearMocks();
  });

  describe('CustomerProfileRepository — all operations are business-scoped', () => {
    const repo = new CustomerProfileRepository();

    it('create() always stores a record under the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          e164Arb,   // whatsappNumber
          async (tenantId, businessId, whatsappNumber) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            await repo.create(tenantId, businessId, { whatsappNumber });

            expect(mockPutItem).toHaveBeenCalledTimes(1);
            const item = mockPutItem.mock.calls[0][0];

            // PK MUST be the business-scoped partition key
            expect(item.PK).toBe(expectedPK(tenantId, businessId));
            // businessId and tenantId stored in the item for traceability
            expect(item.businessId).toBe(businessId);
            expect(item.tenantId).toBe(tenantId);
            // SK must start with the customer prefix
            expect(item.SK).toMatch(/^WACUST#/);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('get() queries using the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // customerId
          async (tenantId, businessId, customerId) => {
            clearMocks();
            mockGetItem.mockResolvedValue(null);

            await repo.get(tenantId, businessId, customerId);

            expect(mockGetItem).toHaveBeenCalledTimes(1);
            const [pk, sk] = mockGetItem.mock.calls[0];

            // PK MUST be the business-scoped partition key
            expect(pk).toBe(expectedPK(tenantId, businessId));
            // SK identifies the specific customer within that business
            expect(sk).toBe(`WACUST#${customerId}`);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('list() queries using the correct businessPK and SK prefix', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          async (tenantId, businessId) => {
            clearMocks();
            mockQueryItems.mockResolvedValue({ items: [] });

            await repo.list(tenantId, businessId);

            expect(mockQueryItems).toHaveBeenCalledTimes(1);
            const [pk, skPrefix] = mockQueryItems.mock.calls[0];

            // PK MUST be business-scoped
            expect(pk).toBe(expectedPK(tenantId, businessId));
            // SK prefix scopes to customer entities only
            expect(skPrefix).toBe('WACUST#');
          },
        ),
        { numRuns: 100 },
      );
    });

    it('update() targets the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // customerId
          async (tenantId, businessId, customerId) => {
            clearMocks();
            // Mock get (for eligibility recompute) and update
            mockGetItem.mockResolvedValue({
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: '+1234567890',
              consentState: 'pending',
              locale: 'en',
              eligible: false,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            });
            mockUpdateItem.mockResolvedValue({
              PK: expectedPK(tenantId, businessId),
              SK: `WACUST#${customerId}`,
              id: customerId,
              businessId,
              tenantId,
              whatsappNumber: '+1234567890',
              consentState: 'opted_in',
              locale: 'en',
              eligible: true,
              isDeleted: false,
              createdAt: '2024-01-01T00:00:00.000Z',
              updatedAt: '2024-01-01T00:00:00.000Z',
            });

            await repo.update(tenantId, businessId, customerId, {
              consentState: 'opted_in',
            });

            expect(mockUpdateItem).toHaveBeenCalledTimes(1);
            const [pk, sk] = mockUpdateItem.mock.calls[0];

            // PK MUST be business-scoped
            expect(pk).toBe(expectedPK(tenantId, businessId));
            expect(sk).toBe(`WACUST#${customerId}`);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('deactivate() targets the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // customerId
          async (tenantId, businessId, customerId) => {
            clearMocks();
            mockUpdateItem.mockResolvedValue({});

            await repo.deactivate(tenantId, businessId, customerId);

            expect(mockUpdateItem).toHaveBeenCalledTimes(1);
            const [pk, sk] = mockUpdateItem.mock.calls[0];

            expect(pk).toBe(expectedPK(tenantId, businessId));
            expect(sk).toBe(`WACUST#${customerId}`);
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('AutomationRuleRepository — all operations are business-scoped', () => {
    const repo = new AutomationRuleRepository();

    it('create() always stores a rule under the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // eventType
          safeIdArb, // templateId
          async (tenantId, businessId, eventType, templateId) => {
            clearMocks();
            mockPutItem.mockResolvedValue(undefined);

            await repo.create(tenantId, businessId, {
              eventType,
              conditions: [],
              templateId,
              recipients: { type: 'customer' } as any,
              category: 'transactional',
              enabled: true,
            });

            expect(mockPutItem).toHaveBeenCalledTimes(1);
            const item = mockPutItem.mock.calls[0][0];

            expect(item.PK).toBe(expectedPK(tenantId, businessId));
            expect(item.businessId).toBe(businessId);
            expect(item.tenantId).toBe(tenantId);
            expect(item.SK).toMatch(/^WARULE#/);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('get() queries using the correct businessPK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // ruleId
          async (tenantId, businessId, ruleId) => {
            clearMocks();
            mockGetItem.mockResolvedValue(null);

            await repo.get(tenantId, businessId, ruleId);

            expect(mockGetItem).toHaveBeenCalledTimes(1);
            const [pk, sk] = mockGetItem.mock.calls[0];

            expect(pk).toBe(expectedPK(tenantId, businessId));
            expect(sk).toBe(`WARULE#${ruleId}`);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('list() queries using the correct businessPK and WARULE# prefix', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          async (tenantId, businessId) => {
            clearMocks();
            mockQueryItems.mockResolvedValue({ items: [] });

            await repo.list(tenantId, businessId);

            expect(mockQueryItems).toHaveBeenCalledTimes(1);
            const [pk, skPrefix] = mockQueryItems.mock.calls[0];

            expect(pk).toBe(expectedPK(tenantId, businessId));
            expect(skPrefix).toBe('WARULE#');
          },
        ),
        { numRuns: 100 },
      );
    });
  });

  describe('Cross-business access denial — structural isolation', () => {
    const customerRepo = new CustomerProfileRepository();
    const ruleRepo = new AutomationRuleRepository();

    it('get() with business B credentials cannot retrieve a record stored under business A', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          twoDistinctIds, // [businessIdA, businessIdB]
          safeIdArb, // customerId
          async (tenantId, [businessIdA, businessIdB], customerId) => {
            clearMocks();

            // Simulate: record exists under business A, business B tries to read it
            mockGetItem.mockImplementation(async (pk: string, sk: string) => {
              // Only return the record if the PK matches business A's partition
              if (pk === expectedPK(tenantId, businessIdA) && sk === `WACUST#${customerId}`) {
                return {
                  PK: pk,
                  SK: sk,
                  id: customerId,
                  businessId: businessIdA,
                  tenantId,
                  whatsappNumber: '+1234567890',
                  consentState: 'opted_in',
                  locale: 'en',
                  eligible: true,
                  isDeleted: false,
                  createdAt: '2024-01-01T00:00:00.000Z',
                  updatedAt: '2024-01-01T00:00:00.000Z',
                };
              }
              return null;
            });

            // Business A can find the record
            const resultA = await customerRepo.get(tenantId, businessIdA, customerId);
            expect(resultA).not.toBeNull();
            expect(resultA!.businessId).toBe(businessIdA);

            // Business B CANNOT find the same record — PK differs
            const resultB = await customerRepo.get(tenantId, businessIdB, customerId);
            expect(resultB).toBeNull();

            // Verify: Business B's get used a DIFFERENT PK
            const calls = mockGetItem.mock.calls;
            const bizAcall = calls.find(([pk]) => pk === expectedPK(tenantId, businessIdA));
            const bizBcall = calls.find(([pk]) => pk === expectedPK(tenantId, businessIdB));

            expect(bizAcall).toBeDefined();
            expect(bizBcall).toBeDefined();
            expect(bizAcall![0]).not.toBe(bizBcall![0]); // PKs differ
          },
        ),
        { numRuns: 100 },
      );
    });

    it('list() with business B credentials returns empty — cannot see business A records', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          twoDistinctIds, // [businessIdA, businessIdB]
          async (tenantId, [businessIdA, businessIdB]) => {
            clearMocks();

            // Simulate: records exist under business A
            mockQueryItems.mockImplementation(async (pk: string) => {
              if (pk === expectedPK(tenantId, businessIdA)) {
                return {
                  items: [{
                    PK: pk,
                    SK: 'WARULE#rule-1',
                    id: 'rule-1',
                    businessId: businessIdA,
                    tenantId,
                    eventType: 'invoice.generated',
                    conditions: [],
                    templateId: 'tmpl-1',
                    recipients: { type: 'customer' },
                    category: 'transactional',
                    enabled: true,
                    isDeleted: false,
                    createdAt: '2024-01-01T00:00:00.000Z',
                    updatedAt: '2024-01-01T00:00:00.000Z',
                  }],
                };
              }
              // Any other PK returns empty (simulates different partition = no access)
              return { items: [] };
            });

            // Business A can see its rules
            const rulesA = await ruleRepo.list(tenantId, businessIdA);
            expect(rulesA.length).toBe(1);

            // Business B cannot see A's rules — different partition
            const rulesB = await ruleRepo.list(tenantId, businessIdB);
            expect(rulesB.length).toBe(0);

            // Verify different PKs were used
            const pkCallsUsed = mockQueryItems.mock.calls.map(([pk]) => pk);
            expect(pkCallsUsed).toContain(expectedPK(tenantId, businessIdA));
            expect(pkCallsUsed).toContain(expectedPK(tenantId, businessIdB));
          },
        ),
        { numRuns: 100 },
      );
    });

    it('create() under business A cannot be retrieved by business B — partition isolation', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          twoDistinctIds, // [businessIdA, businessIdB]
          e164Arb,   // phone
          async (tenantId, [businessIdA, businessIdB], phone) => {
            clearMocks();

            // Track all putItem calls to capture what was stored
            const storedItems: Record<string, unknown>[] = [];
            mockPutItem.mockImplementation(async (item: Record<string, unknown>) => {
              storedItems.push(item);
            });

            // Create a customer under business A
            await customerRepo.create(tenantId, businessIdA, { whatsappNumber: phone });

            expect(storedItems.length).toBe(1);
            const storedItem = storedItems[0];

            // The stored PK is business A's partition
            expect(storedItem.PK).toBe(expectedPK(tenantId, businessIdA));

            // If business B queries with its own PK, it cannot find the record
            // because the PKs are fundamentally different
            const businessBPK = expectedPK(tenantId, businessIdB);
            expect(storedItem.PK).not.toBe(businessBPK);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('update() with business B PK cannot modify a record stored under business A PK', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          twoDistinctIds, // [businessIdA, businessIdB]
          safeIdArb, // ruleId
          async (tenantId, [businessIdA, businessIdB], ruleId) => {
            clearMocks();

            // Simulate: updateItem only succeeds if condition passes (record exists)
            mockUpdateItem.mockImplementation(async (pk: string, sk: string) => {
              // Record only exists under business A's partition
              if (pk === expectedPK(tenantId, businessIdA) && sk === `WARULE#${ruleId}`) {
                return {
                  PK: pk,
                  SK: sk,
                  id: ruleId,
                  businessId: businessIdA,
                  tenantId,
                  eventType: 'invoice.generated',
                  conditions: [],
                  templateId: 'tmpl-1',
                  recipients: { type: 'customer' },
                  category: 'transactional',
                  enabled: false,
                  isDeleted: false,
                  createdAt: '2024-01-01T00:00:00.000Z',
                  updatedAt: '2024-01-01T00:00:00.000Z',
                };
              }
              // Condition fails for any other PK (record doesn't exist there)
              return null;
            });

            // Business A can update its own rule
            const resultA = await ruleRepo.update(tenantId, businessIdA, ruleId, { enabled: false });
            expect(resultA).not.toBeNull();

            // Business B CANNOT update the same rule — different PK means no match
            const resultB = await ruleRepo.update(tenantId, businessIdB, ruleId, { enabled: false });
            expect(resultB).toBeNull();

            // Verify different PKs were used in the updateItem calls
            const updateCalls = mockUpdateItem.mock.calls;
            const aCallPK = updateCalls.find(([pk]) => pk === expectedPK(tenantId, businessIdA));
            const bCallPK = updateCalls.find(([pk]) => pk === expectedPK(tenantId, businessIdB));
            expect(aCallPK).toBeDefined();
            expect(bCallPK).toBeDefined();
            expect(aCallPK![0]).not.toBe(bCallPK![0]);
          },
        ),
        { numRuns: 100 },
      );
    });

    it('the PK used by every repository operation matches businessPK() output exactly', async () => {
      await fc.assert(
        fc.asyncProperty(
          safeIdArb, // tenantId
          safeIdArb, // businessId
          safeIdArb, // entityId
          async (tenantId, businessId, entityId) => {
            clearMocks();
            mockGetItem.mockResolvedValue(null);
            mockQueryItems.mockResolvedValue({ items: [] });

            const expected = businessPK(tenantId, businessId);

            // Verify get uses businessPK
            await customerRepo.get(tenantId, businessId, entityId);
            expect(mockGetItem.mock.calls[0][0]).toBe(expected);

            // Verify list uses businessPK
            await customerRepo.list(tenantId, businessId);
            expect(mockQueryItems.mock.calls[0][0]).toBe(expected);
          },
        ),
        { numRuns: 100 },
      );
    });
  });
});
