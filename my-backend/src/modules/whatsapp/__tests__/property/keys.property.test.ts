/**
 * Property-Based Tests: WhatsApp Key Builders — Business Scoping & Session Authority
 *
 * Feature: openwa-whatsapp-automation, Property 30, Property 31
 *
 * **Validates: Requirements 12.1, 12.2, 12.4**
 *
 * Property 30: Every stored record and message is business-scoped, and
 *   cross-business access is denied (BusinessID leading-scope portion).
 *   - Every key produced by buildXxxKeys always starts with the correct
 *     business scope (TENANT#...#BIZ#...).
 *   - Different businessIds always produce non-overlapping key spaces.
 *
 * Property 31: BusinessID is session-authoritative (key derivation ignores
 *   client input).
 *   - Key derivation is purely a function of (tenantId, businessId) and
 *     ignores any other client-supplied fields.
 *
 * Additionally verifies that IDs containing '#' are rejected.
 */

import * as fc from 'fast-check';
import {
  buildAutomationConfigKeys,
  buildMessageTemplateKeys,
  buildMessageTemplateVersionKeys,
  buildAutomationRuleKeys,
  buildCustomerProfileKeys,
  buildOutboundMessageKeys,
  buildDeliveryLogKeys,
  buildAuditLogKeys,
  buildProcessingMarkerKeys,
  buildScheduledDispatchKeys,
  buildLowStockMarkerKeys,
  buildCollectionWorkflowKeys,
  buildOpenWaProvisioningKeys,
} from '../../keys';

// ── Generators ───────────────────────────────────────────────────────────────

/** Characters safe for DynamoDB key segments (excludes '#') */
const SAFE_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

/** Generate a valid ID segment: non-empty, no '#', no whitespace-only */
const safeIdArb = fc.stringOf(
  fc.constantFrom(...SAFE_CHARS.split('')),
  { minLength: 1, maxLength: 64 },
);

/** Generate a valid ISO date string for GSI sort keys */
const isoDateArb = fc
  .date({ min: new Date('2020-01-01'), max: new Date('2030-12-31') })
  .map((d) => d.toISOString());

/** Generate a positive integer for version numbers */
const versionArb = fc.integer({ min: 1, max: 9999 });

/** Generate a string that definitely contains '#' (injection attempt) */
const injectedIdArb = fc
  .tuple(
    fc.stringOf(fc.constantFrom(...SAFE_CHARS.split('')), { minLength: 0, maxLength: 20 }),
    fc.stringOf(fc.constantFrom(...SAFE_CHARS.split('')), { minLength: 0, maxLength: 20 }),
  )
  .map(([prefix, suffix]) => `${prefix}#${suffix}`);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Expected PK prefix for a given tenant+business pair */
function expectedPKPrefix(tenantId: string, businessId: string): string {
  return `TENANT#${tenantId}#BIZ#${businessId}`;
}

/**
 * Calls every buildXxxKeys function with the given (tenantId, businessId) and
 * returns all resulting key sets. This centralizes the key builder invocations
 * so property assertions apply uniformly.
 */
function allKeyBuilders(tenantId: string, businessId: string, extras: {
  businessType: string;
  tier: string;
  templateId: string;
  version: number;
  ruleId: string;
  customerId: string;
  messageId: string;
  isoTimestamp: string;
  logId: string;
  eventId: string;
  recipientId: string;
  dueTimestamp: string;
  productId: string;
  invoiceId: string;
}) {
  return [
    { name: 'AutomationConfig', keys: buildAutomationConfigKeys(tenantId, businessId, extras.businessType, extras.tier) },
    { name: 'MessageTemplate', keys: buildMessageTemplateKeys(tenantId, businessId, extras.templateId, extras.isoTimestamp) },
    { name: 'MessageTemplateVersion', keys: buildMessageTemplateVersionKeys(tenantId, businessId, extras.templateId, extras.version, extras.isoTimestamp) },
    { name: 'AutomationRule', keys: buildAutomationRuleKeys(tenantId, businessId, extras.ruleId, extras.isoTimestamp) },
    { name: 'CustomerProfile', keys: buildCustomerProfileKeys(tenantId, businessId, extras.customerId, extras.isoTimestamp) },
    { name: 'OutboundMessage', keys: buildOutboundMessageKeys(tenantId, businessId, extras.messageId, extras.isoTimestamp) },
    { name: 'DeliveryLog', keys: buildDeliveryLogKeys(tenantId, businessId, extras.isoTimestamp, extras.logId) },
    { name: 'AuditLog', keys: buildAuditLogKeys(tenantId, businessId, extras.isoTimestamp, extras.eventId) },
    { name: 'ProcessingMarker', keys: buildProcessingMarkerKeys(tenantId, businessId, extras.eventId, extras.recipientId) },
    { name: 'ScheduledDispatch', keys: buildScheduledDispatchKeys(tenantId, businessId, extras.dueTimestamp, extras.messageId) },
    { name: 'LowStockMarker', keys: buildLowStockMarkerKeys(tenantId, businessId, extras.productId) },
    { name: 'CollectionWorkflow', keys: buildCollectionWorkflowKeys(tenantId, businessId, extras.invoiceId, extras.customerId) },
    { name: 'OpenWaProvisioning', keys: buildOpenWaProvisioningKeys(tenantId, businessId) },
  ];
}

// ── Tests ────────────────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 30 — Every stored record is business-scoped and cross-business access is denied', () => {
  it('every key builder produces PK starting with TENANT#{tenantId}#BIZ#{businessId}', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        safeIdArb, // businessId
        safeIdArb, // businessType
        safeIdArb, // tier
        safeIdArb, // templateId
        versionArb,
        safeIdArb, // ruleId
        safeIdArb, // customerId
        safeIdArb, // messageId
        isoDateArb,
        safeIdArb, // logId
        safeIdArb, // eventId
        safeIdArb, // recipientId
        isoDateArb, // dueTimestamp
        safeIdArb, // productId
        safeIdArb, // invoiceId
        (tenantId, businessId, businessType, tier, templateId, version, ruleId, customerId, messageId, isoTimestamp, logId, eventId, recipientId, dueTimestamp, productId, invoiceId) => {
          const prefix = expectedPKPrefix(tenantId, businessId);
          const builders = allKeyBuilders(tenantId, businessId, {
            businessType, tier, templateId, version, ruleId, customerId,
            messageId, isoTimestamp, logId, eventId, recipientId,
            dueTimestamp, productId, invoiceId,
          });

          for (const { name, keys } of builders) {
            expect(keys.PK).toBe(prefix);
            // GSI1PK also carries the business scope
            if (keys.GSI1PK) {
              expect(keys.GSI1PK.startsWith(prefix)).toBe(true);
            }
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('different businessIds produce non-overlapping key spaces (PK differs)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        safeIdArb, // businessId A
        safeIdArb.filter((id) => id.length >= 1), // businessId B (ensure non-empty)
        safeIdArb, // templateId
        isoDateArb,
        (tenantId, businessIdA, businessIdB, templateId, isoTimestamp) => {
          // Only test when IDs are actually different
          fc.pre(businessIdA !== businessIdB);

          const keysA = buildMessageTemplateKeys(tenantId, businessIdA, templateId, isoTimestamp);
          const keysB = buildMessageTemplateKeys(tenantId, businessIdB, templateId, isoTimestamp);

          // PKs must differ — they live in different partitions
          expect(keysA.PK).not.toBe(keysB.PK);

          // Even the same entity in business A and B cannot share a partition
          expect(keysA.PK).toBe(expectedPKPrefix(tenantId, businessIdA));
          expect(keysB.PK).toBe(expectedPKPrefix(tenantId, businessIdB));

          // GSI1PK also differs (cross-business queries impossible)
          if (keysA.GSI1PK && keysB.GSI1PK) {
            expect(keysA.GSI1PK).not.toBe(keysB.GSI1PK);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  it('different tenantIds produce non-overlapping key spaces even with same businessId', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId A
        safeIdArb, // tenantId B
        safeIdArb, // businessId (same)
        safeIdArb, // ruleId
        isoDateArb,
        (tenantIdA, tenantIdB, businessId, ruleId, isoTimestamp) => {
          fc.pre(tenantIdA !== tenantIdB);

          const keysA = buildAutomationRuleKeys(tenantIdA, businessId, ruleId, isoTimestamp);
          const keysB = buildAutomationRuleKeys(tenantIdB, businessId, ruleId, isoTimestamp);

          expect(keysA.PK).not.toBe(keysB.PK);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('IDs containing "#" are rejected with a security error', () => {
    fc.assert(
      fc.property(
        injectedIdArb, // malicious tenantId
        safeIdArb, // businessId
        (maliciousTenantId, businessId) => {
          expect(() => buildOpenWaProvisioningKeys(maliciousTenantId, businessId)).toThrow(
            /SECURITY.*#/,
          );
        },
      ),
      { numRuns: 100 },
    );

    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        injectedIdArb, // malicious businessId
        (tenantId, maliciousBusinessId) => {
          expect(() => buildOpenWaProvisioningKeys(tenantId, maliciousBusinessId)).toThrow(
            /SECURITY.*#/,
          );
        },
      ),
      { numRuns: 100 },
    );
  });

  it('empty or whitespace-only IDs are rejected with a security error', () => {
    const emptyishArb = fc.constantFrom('', ' ', '  ', '\t', '\n');

    fc.assert(
      fc.property(
        emptyishArb,
        safeIdArb,
        (emptyTenantId, businessId) => {
          expect(() => buildOpenWaProvisioningKeys(emptyTenantId, businessId)).toThrow(/SECURITY/);
        },
      ),
      { numRuns: 20 },
    );

    fc.assert(
      fc.property(
        safeIdArb,
        emptyishArb,
        (tenantId, emptyBusinessId) => {
          expect(() => buildOpenWaProvisioningKeys(tenantId, emptyBusinessId)).toThrow(/SECURITY/);
        },
      ),
      { numRuns: 20 },
    );
  });
});

describe('Feature: openwa-whatsapp-automation, Property 31 — BusinessID is session-authoritative (key derivation ignores client input)', () => {
  it('key PK is determined solely by (tenantId, businessId) — varying other fields does not change PK', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId (fixed)
        safeIdArb, // businessId (fixed)
        // Two different sets of "client-supplied" fields
        safeIdArb, safeIdArb, // templateIdA, templateIdB
        isoDateArb, isoDateArb, // dateA, dateB
        (tenantId, businessId, templateIdA, templateIdB, dateA, dateB) => {
          const keysA = buildMessageTemplateKeys(tenantId, businessId, templateIdA, dateA);
          const keysB = buildMessageTemplateKeys(tenantId, businessId, templateIdB, dateB);

          // PK is the same regardless of other parameters
          expect(keysA.PK).toBe(keysB.PK);
          expect(keysA.PK).toBe(expectedPKPrefix(tenantId, businessId));
        },
      ),
      { numRuns: 100 },
    );
  });

  it('key PK is unchanged regardless of which entity builder is used for the same (tenantId, businessId)', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        safeIdArb, // businessId
        safeIdArb, // arbitrary extra field 1
        safeIdArb, // arbitrary extra field 2
        isoDateArb,
        versionArb,
        (tenantId, businessId, extraA, extraB, date, version) => {
          const prefix = expectedPKPrefix(tenantId, businessId);

          // All different entity builders should produce the same PK
          expect(buildAutomationConfigKeys(tenantId, businessId, extraA, extraB).PK).toBe(prefix);
          expect(buildMessageTemplateKeys(tenantId, businessId, extraA, date).PK).toBe(prefix);
          expect(buildMessageTemplateVersionKeys(tenantId, businessId, extraA, version, date).PK).toBe(prefix);
          expect(buildAutomationRuleKeys(tenantId, businessId, extraA, date).PK).toBe(prefix);
          expect(buildCustomerProfileKeys(tenantId, businessId, extraA, date).PK).toBe(prefix);
          expect(buildOutboundMessageKeys(tenantId, businessId, extraA, date).PK).toBe(prefix);
          expect(buildDeliveryLogKeys(tenantId, businessId, date, extraA).PK).toBe(prefix);
          expect(buildAuditLogKeys(tenantId, businessId, date, extraA).PK).toBe(prefix);
          expect(buildProcessingMarkerKeys(tenantId, businessId, extraA, extraB).PK).toBe(prefix);
          expect(buildScheduledDispatchKeys(tenantId, businessId, date, extraA).PK).toBe(prefix);
          expect(buildLowStockMarkerKeys(tenantId, businessId, extraA).PK).toBe(prefix);
          expect(buildCollectionWorkflowKeys(tenantId, businessId, extraA, extraB).PK).toBe(prefix);
          expect(buildOpenWaProvisioningKeys(tenantId, businessId).PK).toBe(prefix);
        },
      ),
      { numRuns: 100 },
    );
  });

  it('a client-supplied businessId (different from the session one) would produce a different partition — proving session authority matters', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        safeIdArb, // session businessId (authoritative)
        safeIdArb, // client-supplied businessId (attacker)
        safeIdArb, // customerId
        isoDateArb,
        (tenantId, sessionBizId, clientBizId, customerId, date) => {
          fc.pre(sessionBizId !== clientBizId);

          // Keys derived from session businessId
          const sessionKeys = buildCustomerProfileKeys(tenantId, sessionBizId, customerId, date);
          // Keys that would result from using a client-supplied businessId
          const clientKeys = buildCustomerProfileKeys(tenantId, clientBizId, customerId, date);

          // They are in completely different partitions — proving that using
          // the session-derived ID vs a client-supplied ID matters critically
          expect(sessionKeys.PK).not.toBe(clientKeys.PK);

          // The PK is derived from (tenantId, businessId) — if the handler
          // uses session businessId, the client cannot access another business
          expect(sessionKeys.PK).toBe(expectedPKPrefix(tenantId, sessionBizId));
          expect(clientKeys.PK).toBe(expectedPKPrefix(tenantId, clientBizId));
        },
      ),
      { numRuns: 100 },
    );
  });

  it('GSI1PK also carries the business scope — cross-business GSI queries are impossible', () => {
    fc.assert(
      fc.property(
        safeIdArb, // tenantId
        safeIdArb, // businessId A
        safeIdArb, // businessId B
        safeIdArb, // customerId
        isoDateArb,
        (tenantId, bizA, bizB, customerId, date) => {
          fc.pre(bizA !== bizB);

          const keysA = buildCustomerProfileKeys(tenantId, bizA, customerId, date);
          const keysB = buildCustomerProfileKeys(tenantId, bizB, customerId, date);

          // GSI1PK is also business-scoped (no way to cross-query)
          expect(keysA.GSI1PK).not.toBe(keysB.GSI1PK);
          expect(keysA.GSI1PK!.startsWith(expectedPKPrefix(tenantId, bizA))).toBe(true);
          expect(keysB.GSI1PK!.startsWith(expectedPKPrefix(tenantId, bizB))).toBe(true);
        },
      ),
      { numRuns: 100 },
    );
  });
});
