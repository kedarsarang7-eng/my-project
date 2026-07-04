// ============================================================================
// Property-Based Test — Template Version Recoverability
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 17
//
// Validates: Requirements 7.7
//
// Property 17 (design.md): Template version used by a message is exactly
// recoverable.
//
// Verifies:
// 1. Every template version that is stored can be retrieved by (templateId, version)
// 2. The retrieved version's body matches what was stored
// 3. Version numbers are monotonically increasing
// 4. Given an Outbound_Message referencing (templateId, templateVersion), the
//    exact version is recoverable
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  MessageTemplateRepository,
  MessageTemplateCreateInput,
  MessageTemplateUpdateInput,
} from '../../repositories/message-template.repository';
import { messageTemplateVersionSK, WATMPLV_SK_PREFIX } from '../../keys';

const NUM_RUNS = 100;

// ── In-memory DynamoDB mock ─────────────────────────────────────────────────
// We mock the DynamoDB operations at the config level to create a functional
// in-memory store, so we can test the repository logic (version creation,
// retrieval, monotonicity) without a real database.

const store: Map<string, Record<string, unknown>> = new Map();

jest.mock('../../../../config/dynamodb.config', () => ({
  putItem: jest.fn(async (item: Record<string, unknown>) => {
    const key = `${item.PK}#${item.SK}`;
    store.set(key, { ...item });
    return item;
  }),
  getItem: jest.fn(async <T>(pk: string, sk: string): Promise<T | null> => {
    const key = `${pk}#${sk}`;
    const item = store.get(key);
    return (item as T) ?? null;
  }),
  queryItems: jest.fn(async <T>(pk: string, skPrefix: string, opts?: Record<string, unknown>) => {
    const items: T[] = [];
    for (const [key, value] of store.entries()) {
      if (key.startsWith(`${pk}#${skPrefix}`)) {
        const item = value as Record<string, unknown>;
        // Apply filter expression for isDeleted if present
        if (opts?.filterExpression && typeof opts.filterExpression === 'string') {
          if (opts.filterExpression.includes('isDeleted') && item.isDeleted === true) {
            continue;
          }
        }
        items.push(value as T);
      }
    }
    // Sort by SK for consistent ordering
    items.sort((a, b) => {
      const skA = (a as Record<string, unknown>).SK as string;
      const skB = (b as Record<string, unknown>).SK as string;
      return opts?.scanIndexForward === false
        ? skB.localeCompare(skA)
        : skA.localeCompare(skB);
    });
    const limit = opts?.limit as number | undefined;
    return { items: limit ? items.slice(0, limit) : items };
  }),
  updateItem: jest.fn(async (pk: string, sk: string, opts: Record<string, unknown>) => {
    const key = `${pk}#${sk}`;
    const existing = store.get(key);
    if (!existing) return null;

    // Parse simple SET expressions
    const updateExpr = opts.updateExpression as string;
    const values = (opts.expressionAttributeValues ?? {}) as Record<string, unknown>;
    const names = (opts.expressionAttributeNames ?? {}) as Record<string, string>;

    if (updateExpr?.startsWith('SET ')) {
      const assignments = updateExpr.slice(4).split(',').map((s: string) => s.trim());
      for (const assignment of assignments) {
        const [left, right] = assignment.split('=').map((s: string) => s.trim());
        const fieldName = names[left] ?? left;
        const fieldValue = values[right] ?? right;
        (existing as Record<string, unknown>)[fieldName] = fieldValue;
      }
    }

    store.set(key, existing);
    return existing;
  }),
}));

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a valid template body (1–4096 chars). */
const templateBodyArb: fc.Arbitrary<string> = fc
  .string({ minLength: 1, maxLength: 200 })
  .filter((s) => s.trim().length > 0);

/** Generates a valid template name. */
const templateNameArb: fc.Arbitrary<string> = fc
  .string({ minLength: 1, maxLength: 50 })
  .filter((s) => s.trim().length > 0);

/** Generates valid placeholder arrays (0–5 placeholders for brevity). */
const placeholdersArb: fc.Arbitrary<string[]> = fc.array(
  fc.string({ minLength: 1, maxLength: 30 }).filter((s) => s.trim().length > 0),
  { minLength: 0, maxLength: 5 },
);

/** Generates a valid locale (2–10 chars). */
const localeArb: fc.Arbitrary<string> = fc.constantFrom('en', 'hi', 'mr', 'ta', 'te', 'bn', 'gu', 'kn');

/** Generates a valid business type. */
const businessTypeArb: fc.Arbitrary<string> = fc.constantFrom(
  'grocery', 'mobile_store', 'clinic', 'school_erp', 'petrol_pump', 'jewellery',
);

/** Generates a UUID-like ID. */
const uuidArb: fc.Arbitrary<string> = fc
  .hexaString({ minLength: 32, maxLength: 32 })
  .map((hex) =>
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`,
  );

/** Generates the number of updates (1–5) to simulate version progression. */
const updateCountArb: fc.Arbitrary<number> = fc.integer({ min: 1, max: 5 });

/** Generates a sequence of template bodies for version progression. */
const bodySequenceArb = (count: number): fc.Arbitrary<string[]> =>
  fc.array(templateBodyArb, { minLength: count, maxLength: count });

// ── Test Suite ──────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 17: Template version used by a message is exactly recoverable', () => {
  const repo = new MessageTemplateRepository();
  const tenantId = 'test-tenant';
  const businessId = 'test-business';

  beforeEach(() => {
    store.clear();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-property 1: Every template version stored can be retrieved by
  // (templateId, version)
  // ──────────────────────────────────────────────────────────────────────────

  test('every stored version is retrievable by (templateId, version) (Req 7.7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        templateNameArb,
        templateBodyArb,
        businessTypeArb,
        localeArb,
        placeholdersArb,
        async (name, body, businessType, locale, placeholders) => {
          store.clear();

          const template = await repo.create(tenantId, businessId, {
            name,
            businessType,
            locale,
            body,
            placeholders,
            createdBy: 'test-actor',
          });

          // Version 1 should be retrievable
          const version1 = await repo.getVersion(tenantId, businessId, template.id, 1);
          expect(version1).not.toBeNull();
          expect(version1!.templateId).toBe(template.id);
          expect(version1!.version).toBe(1);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-property 2: Retrieved version's body matches what was stored
  // ──────────────────────────────────────────────────────────────────────────

  test('retrieved version body matches the body that was stored (Req 7.7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        templateNameArb,
        templateBodyArb,
        businessTypeArb,
        localeArb,
        placeholdersArb,
        async (name, body, businessType, locale, placeholders) => {
          store.clear();

          const template = await repo.create(tenantId, businessId, {
            name,
            businessType,
            locale,
            body,
            placeholders,
            createdBy: 'test-actor',
          });

          const version1 = await repo.getVersion(tenantId, businessId, template.id, 1);
          expect(version1).not.toBeNull();
          expect(version1!.body).toBe(body);
          expect(version1!.placeholders).toEqual(placeholders);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-property 3: Version numbers are monotonically increasing
  // ──────────────────────────────────────────────────────────────────────────

  test('version numbers are monotonically increasing across updates (Req 7.7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        templateNameArb,
        templateBodyArb,
        businessTypeArb,
        localeArb,
        placeholdersArb,
        updateCountArb,
        async (name, initialBody, businessType, locale, placeholders, updateCount) => {
          store.clear();

          // Create version 1
          const template = await repo.create(tenantId, businessId, {
            name,
            businessType,
            locale,
            body: initialBody,
            placeholders,
            createdBy: 'test-actor',
          });

          let prevVersion = 1;

          // Perform sequential updates
          for (let i = 0; i < updateCount; i++) {
            const updated = await repo.update(tenantId, businessId, template.id, {
              body: `${initialBody}-v${i + 2}`,
              updatedBy: 'test-actor',
            });

            if (updated) {
              expect(updated.currentVersion).toBe(prevVersion + 1);
              expect(updated.currentVersion).toBeGreaterThan(prevVersion);
              prevVersion = updated.currentVersion;
            }
          }

          // Verify all versions exist and are monotonically ordered
          const versions = await repo.listVersions(tenantId, businessId, template.id);
          expect(versions.length).toBe(1 + updateCount);

          for (let i = 1; i < versions.length; i++) {
            expect(versions[i].version).toBeGreaterThan(versions[i - 1].version);
            expect(versions[i].version).toBe(versions[i - 1].version + 1);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-property 4: Given an Outbound_Message referencing (templateId,
  // templateVersion), the exact version is recoverable
  // ──────────────────────────────────────────────────────────────────────────

  test('Outbound_Message (templateId, templateVersion) reference resolves to the exact version used (Req 7.7)', async () => {
    await fc.assert(
      fc.asyncProperty(
        templateNameArb,
        templateBodyArb,
        businessTypeArb,
        localeArb,
        placeholdersArb,
        updateCountArb,
        fc.integer({ min: 0, max: 4 }),
        async (name, initialBody, businessType, locale, placeholders, updateCount, targetIdx) => {
          store.clear();

          // Create template with initial version
          const template = await repo.create(tenantId, businessId, {
            name,
            businessType,
            locale,
            body: initialBody,
            placeholders,
            createdBy: 'test-actor',
          });

          // Track bodies per version
          const versionBodies: Map<number, string> = new Map();
          versionBodies.set(1, initialBody);

          // Perform updates to create more versions
          for (let i = 0; i < updateCount; i++) {
            const newBody = `${initialBody}-updated-v${i + 2}`;
            const updated = await repo.update(tenantId, businessId, template.id, {
              body: newBody,
              updatedBy: 'test-actor',
            });
            if (updated) {
              versionBodies.set(updated.currentVersion, newBody);
            }
          }

          // Simulate an Outbound_Message that references a specific version
          const totalVersions = 1 + updateCount;
          const selectedVersion = (targetIdx % totalVersions) + 1;
          const expectedBody = versionBodies.get(selectedVersion);

          // This simulates the recoverability requirement:
          // Given (templateId, templateVersion) from an OutboundMessage,
          // retrieve the exact template version used.
          const recoveredVersion = await repo.getVersion(
            tenantId,
            businessId,
            template.id,
            selectedVersion,
          );

          expect(recoveredVersion).not.toBeNull();
          expect(recoveredVersion!.templateId).toBe(template.id);
          expect(recoveredVersion!.version).toBe(selectedVersion);
          expect(recoveredVersion!.body).toBe(expectedBody);
          expect(recoveredVersion!.businessId).toBe(businessId);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Anchored example checks (unit) ─────────────────────────────────────────

  test('example: version SK is correctly structured as WATMPLV#{templateId}#{version}', () => {
    const sk = messageTemplateVersionSK('tmpl-abc', 3);
    expect(sk).toBe(`${WATMPLV_SK_PREFIX}tmpl-abc#3`);
  });

  test('example: creating a template produces version 1 retrievable by (id, 1)', async () => {
    store.clear();
    const template = await repo.create(tenantId, businessId, {
      name: 'Invoice Template',
      businessType: 'grocery',
      locale: 'en',
      body: 'Hello {{customerName}}, your invoice #{{invoiceNo}} is ready.',
      placeholders: ['customerName', 'invoiceNo'],
      createdBy: 'admin-user',
    });

    expect(template.currentVersion).toBe(1);
    const v1 = await repo.getVersion(tenantId, businessId, template.id, 1);
    expect(v1).not.toBeNull();
    expect(v1!.body).toBe('Hello {{customerName}}, your invoice #{{invoiceNo}} is ready.');
    expect(v1!.placeholders).toEqual(['customerName', 'invoiceNo']);
    expect(v1!.createdBy).toBe('admin-user');
  });

  test('example: updating a template preserves old version and creates new one', async () => {
    store.clear();
    const template = await repo.create(tenantId, businessId, {
      name: 'Payment Reminder',
      businessType: 'grocery',
      locale: 'en',
      body: 'Dear {{name}}, please pay {{amount}}.',
      placeholders: ['name', 'amount'],
      createdBy: 'admin-user',
    });

    await repo.update(tenantId, businessId, template.id, {
      body: 'Hi {{name}}, your outstanding balance is {{amount}}. Due: {{dueDate}}.',
      placeholders: ['name', 'amount', 'dueDate'],
      updatedBy: 'admin-user',
    });

    // Version 1 is still recoverable with original body
    const v1 = await repo.getVersion(tenantId, businessId, template.id, 1);
    expect(v1!.body).toBe('Dear {{name}}, please pay {{amount}}.');
    expect(v1!.placeholders).toEqual(['name', 'amount']);

    // Version 2 has the updated body
    const v2 = await repo.getVersion(tenantId, businessId, template.id, 2);
    expect(v2!.body).toBe('Hi {{name}}, your outstanding balance is {{amount}}. Due: {{dueDate}}.');
    expect(v2!.placeholders).toEqual(['name', 'amount', 'dueDate']);
  });

  test('example: simulated OutboundMessage version reference is recoverable after multiple updates', async () => {
    store.clear();
    const template = await repo.create(tenantId, businessId, {
      name: 'Order Confirmation',
      businessType: 'mobile_store',
      locale: 'hi',
      body: 'Order {{orderId}} confirmed.',
      placeholders: ['orderId'],
      createdBy: 'shop-owner',
    });

    // Simulate multiple updates
    await repo.update(tenantId, businessId, template.id, {
      body: 'Order {{orderId}} confirmed. ETA: {{eta}}.',
      placeholders: ['orderId', 'eta'],
      updatedBy: 'shop-owner',
    });

    await repo.update(tenantId, businessId, template.id, {
      body: 'Order {{orderId}} confirmed. ETA: {{eta}}. Track: {{trackUrl}}.',
      placeholders: ['orderId', 'eta', 'trackUrl'],
      updatedBy: 'shop-owner',
    });

    // A message sent at version 2 should still resolve to version 2's body
    const outboundMessageRef = { templateId: template.id, templateVersion: 2 };
    const recovered = await repo.getVersion(
      tenantId,
      businessId,
      outboundMessageRef.templateId,
      outboundMessageRef.templateVersion,
    );

    expect(recovered).not.toBeNull();
    expect(recovered!.version).toBe(2);
    expect(recovered!.body).toBe('Order {{orderId}} confirmed. ETA: {{eta}}.');
    expect(recovered!.placeholders).toEqual(['orderId', 'eta']);
  });
});
