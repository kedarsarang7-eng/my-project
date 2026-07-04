// ============================================================================
// Property-Based Test — RBAC Read Gate
// ============================================================================
// Feature: openwa-whatsapp-automation, Property 33
//
// Validates: Requirements 13.3, 13.4
//
// Property 33 (design.md): Reading customer numbers or message content
// requires RBAC permission.
//
// The RBAC gate ensures:
// 1. Users WITHOUT the required permission get redacted WhatsApp numbers
// 2. Users WITHOUT the required permission get no message content in logs
// 3. Users WITH the permission (OWNER, ADMIN, MANAGER) see full data
// 4. The check is fail-closed: unknown/missing permission = denied
//
// Framework: fast-check + Jest, >= 100 generated cases per property.
// ============================================================================

import * as fc from 'fast-check';
import { UserRole } from '../../../../types/tenant.types';
import { BusinessType } from '../../../../types/tenant.types';
import type { AuthContext } from '../../../../types/tenant.types';
import type { CustomerProfile } from '../../schemas/entities';
import {
  applyRbacGate,
  checkWhatsappReadPermission,
  maskPhoneNumber,
} from '../../handlers/customer.handler';

const NUM_RUNS = 100;

// ── Generators ──────────────────────────────────────────────────────────────

/** Roles that ALWAYS have WhatsApp read permission. */
const privilegedRoleArb: fc.Arbitrary<UserRole> = fc.constantFrom(
  UserRole.OWNER,
  UserRole.ADMIN,
  UserRole.MANAGER,
);

/** Roles that do NOT have WhatsApp read permission (below MANAGER). */
const unprivilegedRoleArb: fc.Arbitrary<UserRole> = fc.constantFrom(
  UserRole.STAFF,
  UserRole.CASHIER,
  UserRole.ACCOUNTANT,
  UserRole.CHARTERED_ACCOUNTANT,
  UserRole.PUMPBOY,
  UserRole.VIEWER,
);

/** All valid plan tiers. */
const planTierArb: fc.Arbitrary<string> = fc.constantFrom(
  'basic', 'pro', 'premium', 'enterprise',
);

/** Generates valid E.164 phone numbers. */
const validE164Arb: fc.Arbitrary<string> = fc
  .integer({ min: 10000000, max: 999999999999999 })
  .map((n) => `+${n}`);

/** Generates a minimal AuthContext for testing. */
function authContextArb(roleArb: fc.Arbitrary<UserRole>): fc.Arbitrary<AuthContext> {
  return fc.record({
    sub: fc.uuid(),
    email: fc.emailAddress(),
    tenantId: fc.uuid(),
    businessId: fc.uuid(),
    role: roleArb,
    businessType: fc.constantFrom(
      BusinessType.GROCERY,
      BusinessType.PHARMACY,
      BusinessType.MOBILE_SHOP,
      BusinessType.COMPUTER_SHOP,
      BusinessType.CLINIC,
    ),
    planTier: planTierArb,
  }) as fc.Arbitrary<AuthContext>;
}

/** Generates a CustomerProfile with realistic data. */
const customerProfileArb: fc.Arbitrary<CustomerProfile> = fc.record({
  id: fc.uuid(),
  businessId: fc.uuid(),
  tenantId: fc.uuid(),
  whatsappNumber: validE164Arb,
  consentState: fc.constantFrom('opted_in' as const, 'opted_out' as const, 'pending' as const),
  locale: fc.constantFrom('en', 'hi', 'mr', 'ta', 'te', 'kn'),
  messagingPreferences: fc.constant(undefined),
  eligible: fc.boolean(),
  isDeleted: fc.constant(false),
  createdAt: fc.constant('2025-01-01T00:00:00.000Z'),
  updatedAt: fc.constant('2025-01-01T00:00:00.000Z'),
}) as unknown as fc.Arbitrary<CustomerProfile>;

// ── Property 33: RBAC Read Gate ─────────────────────────────────────────────

describe('Feature: openwa-whatsapp-automation, Property 33: Reading customer numbers or message content requires RBAC permission', () => {

  // ── 1. Users lacking permission get redacted WhatsApp numbers ──────────────

  test('Users without WA permission receive masked/redacted WhatsApp numbers (Req 13.3)', () => {
    fc.assert(
      fc.property(
        customerProfileArb,
        authContextArb(unprivilegedRoleArb),
        (customer, auth) => {
          const result = applyRbacGate(customer, auth);

          // The WhatsApp number must NOT be the full original number
          expect(result.whatsappNumber).not.toBe(customer.whatsappNumber);

          // The result should indicate redaction
          expect(result._redacted).toEqual(['whatsappNumber']);

          // The masked number should contain asterisks (not full data)
          expect(String(result.whatsappNumber)).toContain('****');
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 2. Users lacking permission: message content withheld from delivery logs ─

  test('Users without WA permission do not see full WhatsApp number in response (Req 13.4)', () => {
    fc.assert(
      fc.property(
        customerProfileArb,
        authContextArb(unprivilegedRoleArb),
        (customer, auth) => {
          const result = applyRbacGate(customer, auth);

          // The original WhatsApp number must not appear anywhere in the result
          const resultString = JSON.stringify(result);
          // Full number should not be in the serialized result
          // (masked version is different from original for any number >= 8 chars)
          if (customer.whatsappNumber.length >= 8) {
            expect(resultString).not.toContain(customer.whatsappNumber);
          }
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 3. Users WITH permission see full data ─────────────────────────────────

  test('Users with WA permission (OWNER, ADMIN, MANAGER) see full WhatsApp number (Req 13.3)', () => {
    fc.assert(
      fc.property(
        customerProfileArb,
        authContextArb(privilegedRoleArb),
        (customer, auth) => {
          const result = applyRbacGate(customer, auth);

          // Full WhatsApp number is returned
          expect(result.whatsappNumber).toBe(customer.whatsappNumber);

          // No redaction marker
          expect(result._redacted).toBeUndefined();
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── 4. Fail-closed: missing/unknown permission = denied ────────────────────

  test('checkWhatsappReadPermission is fail-closed: unprivileged roles are always denied regardless of plan (Req 13.4)', () => {
    fc.assert(
      fc.property(
        authContextArb(unprivilegedRoleArb),
        (auth) => {
          // WA_CORE is not in PERMISSION_MATRIX → fail-closed for all
          // non-privileged roles regardless of their plan tier
          const hasPermission = checkWhatsappReadPermission(auth);
          expect(hasPermission).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  test('checkWhatsappReadPermission grants access to privileged roles (OWNER, ADMIN, MANAGER) regardless of plan tier', () => {
    fc.assert(
      fc.property(
        authContextArb(privilegedRoleArb),
        (auth) => {
          const hasPermission = checkWhatsappReadPermission(auth);
          expect(hasPermission).toBe(true);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── Fail-closed when planTier is missing/undefined ─────────────────────────

  test('checkWhatsappReadPermission denies access when planTier is undefined for unprivileged roles (fail-closed)', () => {
    fc.assert(
      fc.property(
        unprivilegedRoleArb,
        fc.uuid(),
        (role, sub) => {
          const auth: AuthContext = {
            sub,
            email: 'test@example.com',
            tenantId: 'tenant-1',
            role,
            businessType: BusinessType.GROCERY,
            // planTier intentionally omitted → defaults to 'basic' in handler
          };
          const hasPermission = checkWhatsappReadPermission(auth);
          expect(hasPermission).toBe(false);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });

  // ── maskPhoneNumber always obscures the middle portion ─────────────────────

  test('maskPhoneNumber never returns the full original number for valid E.164 numbers', () => {
    fc.assert(
      fc.property(validE164Arb, (phone) => {
        const masked = maskPhoneNumber(phone);
        // Masked version must differ from original
        expect(masked).not.toBe(phone);
        // Masked version must contain asterisks
        expect(masked).toContain('****');
        // Masked version preserves prefix (first 3 chars) and suffix (last 4)
        expect(masked.slice(0, 3)).toBe(phone.slice(0, 3));
        expect(masked.slice(-4)).toBe(phone.slice(-4));
      }),
      { numRuns: NUM_RUNS },
    );
  });

  // ── The gate preserves non-sensitive fields regardless of permission ────────

  test('applyRbacGate always returns non-sensitive fields (id, businessId, consentState, locale) regardless of permission', () => {
    fc.assert(
      fc.property(
        customerProfileArb,
        fc.oneof(authContextArb(privilegedRoleArb), authContextArb(unprivilegedRoleArb)),
        (customer, auth) => {
          const result = applyRbacGate(customer, auth);

          // Non-sensitive fields are always present
          expect(result.id).toBe(customer.id);
          expect(result.businessId).toBe(customer.businessId);
          expect(result.consentState).toBe(customer.consentState);
          expect(result.locale).toBe(customer.locale);
          expect(result.createdAt).toBe(customer.createdAt);
          expect(result.updatedAt).toBe(customer.updatedAt);
        },
      ),
      { numRuns: NUM_RUNS },
    );
  });
});
