// ============================================================================
// Property-Based Test — Audit Completeness
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 8
//
// Validates: Requirements 2.7, 7.6
//
// Property 8 (design.md): Consent and configuration/template/rule changes
// produce complete audit entries.
//
// For any Consent_State change or any create/update/deactivate/enable/disable
// of a Message_Template, Automation_Rule, or Automation_Config, an append-only
// Audit_Log entry is produced containing the actor, action, target, the before
// and after values of the changed fields, and a UTC timestamp.
//
// Verifies:
// 1. Every audit entry contains: actor, action, target, before, after, timestamp (UTC ISO-8601)
// 2. Consent changes produce audit entries with correct before/after consent states
// 3. Config/template/rule changes produce audit entries with change details
// 4. No audit entry is missing any required field
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import {
  WaAuditService,
  AUDIT_ACTIONS,
  buildAuditTarget,
  type AuditContext,
  type ConsentChangeAuditInput,
  type ConfigChangeAuditInput,
  type TemplateChangeAuditInput,
  type RuleChangeAuditInput,
} from '../../services/wa-audit.service';
import type { AuditLogEntry } from '../../schemas/entities';

const NUM_RUNS = 100;

// ── ISO-8601 UTC pattern ────────────────────────────────────────────────────

/** Verifies a string is a valid ISO-8601 UTC timestamp. */
function isValidIso8601Utc(ts: string): boolean {
  if (!ts || typeof ts !== 'string') return false;
  const date = new Date(ts);
  if (isNaN(date.getTime())) return false;
  // Must end with Z or have explicit UTC offset
  return ts.endsWith('Z') || /[+-]\d{2}:\d{2}$/.test(ts);
}

// ── Mock Repository ─────────────────────────────────────────────────────────

/**
 * In-memory mock of AuditLogRepository that captures the entry as produced
 * by the service. This lets us test the service logic in isolation without
 * DynamoDB while verifying the audit entry shape.
 */
function createMockRepo() {
  const entries: AuditLogEntry[] = [];

  const repo = {
    create: jest.fn(
      async (
        tenantId: string,
        businessId: string,
        data: { actor: string; action: string; target: string; before?: unknown; after?: unknown },
      ): Promise<AuditLogEntry> => {
        const entry: AuditLogEntry = {
          id: `audit-${entries.length + 1}`,
          tenantId,
          businessId,
          actor: data.actor,
          action: data.action,
          target: data.target,
          before: data.before,
          after: data.after,
          timestamp: new Date().toISOString(),
        };
        entries.push(entry);
        return entry;
      },
    ),
    entries,
  };

  return repo;
}

// ── Generators ──────────────────────────────────────────────────────────────

/** Generates a non-empty alphanumeric ID string (no '#' to avoid key injection). */
const idArb: fc.Arbitrary<string> = fc
  .stringOf(fc.constantFrom(...'abcdefghijklmnopqrstuvwxyz0123456789'.split('')), {
    minLength: 1,
    maxLength: 36,
  });

/** Generates a valid audit context. */
const auditContextArb: fc.Arbitrary<AuditContext> = fc.record({
  tenantId: idArb,
  businessId: idArb,
  actor: idArb.map((id) => `user:${id}`),
});

/** Generates one of the three legal consent states. */
const consentStateArb: fc.Arbitrary<string> = fc.constantFrom(
  'opted_in',
  'opted_out',
  'pending',
);

/** Generates consent change input. */
const consentChangeArb: fc.Arbitrary<ConsentChangeAuditInput> = fc.record({
  customerId: idArb,
  previousState: consentStateArb,
  newState: consentStateArb,
  source: fc.constantFrom('user_action', 'opt_out_keyword', 'api'),
});

/** Generates config change input. */
const configChangeArb: fc.Arbitrary<ConfigChangeAuditInput> = fc.record({
  configId: idArb,
  action: fc.constantFrom('created', 'updated') as fc.Arbitrary<'created' | 'updated'>,
  before: fc.option(fc.jsonValue(), { nil: undefined }),
  after: fc.jsonValue(),
});

/** Generates template change input. */
const templateChangeArb: fc.Arbitrary<TemplateChangeAuditInput> = fc.record({
  templateId: idArb,
  action: fc.constantFrom('created', 'updated', 'deactivated', 'version_created') as fc.Arbitrary<
    'created' | 'updated' | 'deactivated' | 'version_created'
  >,
  before: fc.option(fc.jsonValue(), { nil: undefined }),
  after: fc.option(fc.jsonValue(), { nil: undefined }),
});

/** Generates rule change input. */
const ruleChangeArb: fc.Arbitrary<RuleChangeAuditInput> = fc.record({
  ruleId: idArb,
  action: fc.constantFrom('created', 'updated', 'enabled', 'disabled') as fc.Arbitrary<
    'created' | 'updated' | 'enabled' | 'disabled'
  >,
  before: fc.option(fc.jsonValue(), { nil: undefined }),
  after: fc.option(fc.jsonValue(), { nil: undefined }),
});

// ── Helper: assert required fields present ──────────────────────────────────

function assertAuditEntryComplete(entry: AuditLogEntry): void {
  // Required fields: actor, action, target, timestamp
  expect(entry.actor).toBeDefined();
  expect(typeof entry.actor).toBe('string');
  expect(entry.actor.length).toBeGreaterThan(0);

  expect(entry.action).toBeDefined();
  expect(typeof entry.action).toBe('string');
  expect(entry.action.length).toBeGreaterThan(0);

  expect(entry.target).toBeDefined();
  expect(typeof entry.target).toBe('string');
  expect(entry.target.length).toBeGreaterThan(0);

  expect(entry.timestamp).toBeDefined();
  expect(typeof entry.timestamp).toBe('string');
  expect(isValidIso8601Utc(entry.timestamp)).toBe(true);

  // before and after must be present as keys (may be undefined for creations/deletions)
  expect('before' in entry).toBe(true);
  expect('after' in entry).toBe(true);
}

// ── Property 8 Tests ────────────────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 8: Consent and configuration/template/rule changes produce complete audit entries', () => {
  // ── Sub-property: Consent changes produce complete audit entries (Req 2.7) ─

  test('consent changes produce audit entries with all required fields (Req 2.7)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, consentChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordConsentChange(ctx, input);

        // All required fields are present
        assertAuditEntryComplete(entry);

        // Actor matches the context
        expect(entry.actor).toBe(ctx.actor);

        // Action is the consent.changed constant
        expect(entry.action).toBe(AUDIT_ACTIONS.CONSENT_CHANGED);

        // Target identifies the customer
        expect(entry.target).toBe(buildAuditTarget('customer', input.customerId));
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('consent changes record correct before/after consent states (Req 2.7)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, consentChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordConsentChange(ctx, input);

        // Before captures the previous consent state
        expect(entry.before).toEqual({ consentState: input.previousState });

        // After captures the new consent state and the source
        expect(entry.after).toEqual({
          consentState: input.newState,
          source: input.source,
        });
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Config changes produce complete audit entries (Req 7.6) ──

  test('config changes produce audit entries with all required fields (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, configChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordConfigChange(ctx, input);

        assertAuditEntryComplete(entry);
        expect(entry.actor).toBe(ctx.actor);
        expect(entry.target).toBe(buildAuditTarget('config', input.configId));

        // Action matches the config action type
        const expectedAction = input.action === 'created'
          ? AUDIT_ACTIONS.CONFIG_CREATED
          : AUDIT_ACTIONS.CONFIG_UPDATED;
        expect(entry.action).toBe(expectedAction);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('config changes record the before/after change details (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, configChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordConfigChange(ctx, input);

        // Before/after are passed through to the audit entry
        expect(entry.before).toEqual(input.before);
        expect(entry.after).toEqual(input.after);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Template changes produce complete audit entries (Req 7.6) ─

  test('template changes produce audit entries with all required fields (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, templateChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordTemplateChange(ctx, input);

        assertAuditEntryComplete(entry);
        expect(entry.actor).toBe(ctx.actor);
        expect(entry.target).toBe(buildAuditTarget('template', input.templateId));

        // Action maps correctly
        const actionMap: Record<string, string> = {
          created: AUDIT_ACTIONS.TEMPLATE_CREATED,
          updated: AUDIT_ACTIONS.TEMPLATE_UPDATED,
          deactivated: AUDIT_ACTIONS.TEMPLATE_DEACTIVATED,
          version_created: AUDIT_ACTIONS.TEMPLATE_VERSION_CREATED,
        };
        expect(entry.action).toBe(actionMap[input.action]);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('template changes record the before/after change details (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, templateChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordTemplateChange(ctx, input);

        expect(entry.before).toEqual(input.before);
        expect(entry.after).toEqual(input.after);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Rule changes produce complete audit entries (Req 7.6) ────

  test('rule changes produce audit entries with all required fields (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, ruleChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordRuleChange(ctx, input);

        assertAuditEntryComplete(entry);
        expect(entry.actor).toBe(ctx.actor);
        expect(entry.target).toBe(buildAuditTarget('rule', input.ruleId));

        // Action maps correctly
        const actionMap: Record<string, string> = {
          created: AUDIT_ACTIONS.RULE_CREATED,
          updated: AUDIT_ACTIONS.RULE_UPDATED,
          enabled: AUDIT_ACTIONS.RULE_ENABLED,
          disabled: AUDIT_ACTIONS.RULE_DISABLED,
        };
        expect(entry.action).toBe(actionMap[input.action]);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  test('rule changes record the before/after change details (Req 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, ruleChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordRuleChange(ctx, input);

        expect(entry.before).toEqual(input.before);
        expect(entry.after).toEqual(input.after);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: No audit entry is ever missing a required field ──────────

  test('all audit entry types never omit actor, action, target, or timestamp (Req 2.7, 7.6)', async () => {
    // Generate a random choice among the four audit types and verify completeness
    const auditCallArb = fc.oneof(
      fc.record({ type: fc.constant('consent' as const), ctx: auditContextArb, input: consentChangeArb }),
      fc.record({ type: fc.constant('config' as const), ctx: auditContextArb, input: configChangeArb }),
      fc.record({ type: fc.constant('template' as const), ctx: auditContextArb, input: templateChangeArb }),
      fc.record({ type: fc.constant('rule' as const), ctx: auditContextArb, input: ruleChangeArb }),
    );

    await fc.assert(
      fc.asyncProperty(auditCallArb, async ({ type, ctx, input }) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        let entry: AuditLogEntry;
        switch (type) {
          case 'consent':
            entry = await service.recordConsentChange(ctx, input as ConsentChangeAuditInput);
            break;
          case 'config':
            entry = await service.recordConfigChange(ctx, input as ConfigChangeAuditInput);
            break;
          case 'template':
            entry = await service.recordTemplateChange(ctx, input as TemplateChangeAuditInput);
            break;
          case 'rule':
            entry = await service.recordRuleChange(ctx, input as RuleChangeAuditInput);
            break;
        }

        // Core invariant: no required field is ever missing
        assertAuditEntryComplete(entry!);

        // Business context is passed to the repository
        expect(mockRepo.create).toHaveBeenCalledWith(
          ctx.tenantId,
          ctx.businessId,
          expect.objectContaining({
            actor: expect.any(String),
            action: expect.any(String),
            target: expect.any(String),
          }),
        );
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Sub-property: Timestamp is always UTC ISO-8601 ─────────────────────────

  test('audit entry timestamp is always a valid UTC ISO-8601 string (Req 2.7, 7.6)', async () => {
    await fc.assert(
      fc.asyncProperty(auditContextArb, consentChangeArb, async (ctx, input) => {
        const mockRepo = createMockRepo();
        const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

        const entry = await service.recordConsentChange(ctx, input);

        // Timestamp must be parseable and in UTC (ends with Z)
        expect(isValidIso8601Utc(entry.timestamp)).toBe(true);
        const parsed = new Date(entry.timestamp);
        expect(parsed.getTime()).not.toBeNaN();
        // ISO string from Date always ends with Z (UTC)
        expect(entry.timestamp).toMatch(/Z$/);
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Anchored examples ─────────────────────────────────────────────────────

  test('example: consent change audit entry has complete shape', async () => {
    const mockRepo = createMockRepo();
    const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

    const entry = await service.recordConsentChange(
      { tenantId: 'tenant1', businessId: 'biz1', actor: 'user:admin1' },
      { customerId: 'cust123', previousState: 'pending', newState: 'opted_in', source: 'user_action' },
    );

    expect(entry.actor).toBe('user:admin1');
    expect(entry.action).toBe('consent.changed');
    expect(entry.target).toBe('customer:cust123');
    expect(entry.before).toEqual({ consentState: 'pending' });
    expect(entry.after).toEqual({ consentState: 'opted_in', source: 'user_action' });
    expect(isValidIso8601Utc(entry.timestamp)).toBe(true);
  });

  test('example: template deactivation audit entry has complete shape', async () => {
    const mockRepo = createMockRepo();
    const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

    const entry = await service.recordTemplateChange(
      { tenantId: 'tenant1', businessId: 'biz1', actor: 'user:editor5' },
      { templateId: 'tmpl42', action: 'deactivated', before: { active: true }, after: { active: false } },
    );

    expect(entry.actor).toBe('user:editor5');
    expect(entry.action).toBe('template.deactivated');
    expect(entry.target).toBe('template:tmpl42');
    expect(entry.before).toEqual({ active: true });
    expect(entry.after).toEqual({ active: false });
    expect(isValidIso8601Utc(entry.timestamp)).toBe(true);
  });

  test('example: rule enable audit entry has complete shape', async () => {
    const mockRepo = createMockRepo();
    const service = new WaAuditService(mockRepo as unknown as ConstructorParameters<typeof WaAuditService>[0]);

    const entry = await service.recordRuleChange(
      { tenantId: 'tenant1', businessId: 'biz1', actor: 'user:owner2' },
      { ruleId: 'rule99', action: 'enabled', before: { enabled: false }, after: { enabled: true } },
    );

    expect(entry.actor).toBe('user:owner2');
    expect(entry.action).toBe('rule.enabled');
    expect(entry.target).toBe('rule:rule99');
    expect(entry.before).toEqual({ enabled: false });
    expect(entry.after).toEqual({ enabled: true });
    expect(isValidIso8601Utc(entry.timestamp)).toBe(true);
  });
});
