// ============================================================================
// WhatsApp Module — Route Configuration (Task 16.2)
// ============================================================================
// Wires all /whatsapp/* API Gateway routes with Cognito + authorizedHandler,
// fail-closed checkPermission, session-derived BusinessID, 401 for
// missing/expired/invalid tokens, and 403 with no data/existence disclosure
// for cross-business access.
//
// ROUTE MAP:
//
//   CUSTOMERS
//   POST   /whatsapp/customers              → customerHandler (create)
//   GET    /whatsapp/customers              → customerHandler (list)
//   GET    /whatsapp/customers/{id}         → customerHandler (get)
//   PUT    /whatsapp/customers/{id}         → customerHandler (update)
//   POST   /whatsapp/customers/{id}/consent → customerHandler (set consent)
//   PUT    /whatsapp/customers/{id}/consent → customerHandler (set consent)
//
//   TEMPLATES
//   POST   /whatsapp/templates              → templateHandler (create)
//   GET    /whatsapp/templates              → templateHandler (list)
//   GET    /whatsapp/templates/{id}         → templateHandler (get)
//   PUT    /whatsapp/templates/{id}         → templateHandler (update)
//   DELETE /whatsapp/templates/{id}         → templateHandler (deactivate)
//   GET    /whatsapp/templates/{id}/versions → templateHandler (list versions)
//
//   RULES
//   POST   /whatsapp/rules                  → ruleHandler (create)
//   GET    /whatsapp/rules                  → ruleHandler (list)
//   GET    /whatsapp/rules/{id}             → ruleHandler (get)
//   PUT    /whatsapp/rules/{id}             → ruleHandler (update)
//   PATCH  /whatsapp/rules/{id}             → ruleHandler (toggle)
//   DELETE /whatsapp/rules/{id}             → ruleHandler (deactivate)
//   POST   /whatsapp/rules/{id}/enable      → ruleHandler (enable)
//   POST   /whatsapp/rules/{id}/disable     → ruleHandler (disable)
//
//   CONFIG
//   GET    /whatsapp/config                 → getConfigHandler
//   PUT    /whatsapp/config                 → putConfigHandler
//
//   LOGS
//   GET    /whatsapp/logs/delivery          → deliveryLogHandler
//   GET    /whatsapp/logs/audit             → auditLogHandler
//
//   INBOUND
//   POST   /whatsapp/inbound               → inboundHandler
//
//   WEBHOOK (PUBLIC — signature-only auth, NO Cognito)
//   POST   /whatsapp/webhook               → webhookHandler
//
// SECURITY:
// - All routes (except /whatsapp/webhook) require Cognito authentication
// - All authenticated routes use `authorizedHandler` with fail-closed
//   `checkPermission` and session-derived BusinessID (Req 12.2, 12.3, 12.4)
// - 401 for missing, expired, or invalid token
// - 403 with no data/existence disclosure for cross-business access
// - /whatsapp/webhook is PUBLIC with HMAC-SHA256 signature-only auth (Req 10.4)
//
// Requirements: 12.2, 12.3, 13.2
// ============================================================================

import { customerHandler } from './handlers/customer.handler';
import { templateHandler } from './handlers/template.handler';
import { ruleHandler } from './handlers/rule.handler';
import { getConfigHandler, putConfigHandler } from './handlers/config.handler';
import { deliveryLogHandler, auditLogHandler } from './handlers/log.handler';
import { inboundHandler } from './handlers/inbound.handler';
import { webhookHandler } from './handlers/webhook.handler';
import {
  saveProvisioningConfig,
  getProvisioningConfig,
  verifyProvisioningConfig,
  deleteProvisioningConfig,
} from './handlers/provisioning.handler';

// ── Route Definition Type ─────────────────────────────────────────────────────

export interface WhatsAppRouteDefinition {
  /** HTTP method (GET, POST, PUT, PATCH, DELETE). */
  method: string;
  /** API Gateway path pattern (e.g., /whatsapp/customers/{id}). */
  path: string;
  /** The Lambda handler function to invoke. */
  handler: Function;
  /**
   * Authentication mode:
   * - 'cognito': Requires Cognito JWT; authorizedHandler enforces RBAC + BusinessID
   * - 'signature': Public route; authentication via HMAC-SHA256 signature only
   */
  auth: 'cognito' | 'signature';
  /** Human-readable description for documentation/serverless config. */
  description: string;
}

// ── Route Definitions ─────────────────────────────────────────────────────────

/**
 * All /whatsapp/* routes registered with the API Gateway.
 *
 * SECURITY INVARIANTS:
 * 1. Every 'cognito' route goes through `authorizedHandler` which:
 *    - Verifies the Cognito JWT (401 on missing/expired/invalid)
 *    - Checks RBAC roles (403 on insufficient permissions)
 *    - Derives BusinessID from the session ONLY (Req 12.4)
 *    - Calls `checkPermission` fail-closed (Req 12.2)
 *    - Returns 403 with no data/existence disclosure on cross-business (Req 12.3)
 * 2. The webhook route uses 'signature' auth — no Cognito, HMAC-SHA256 only
 */
export const whatsappRoutes: WhatsAppRouteDefinition[] = [
  // ────────────────────────────────────────────────────────────────────────────
  // CUSTOMERS — WA_CORE feature-gated
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/customers',
    handler: customerHandler,
    auth: 'cognito',
    description: 'Create a customer profile with E.164 validation and consent',
  },
  {
    method: 'GET',
    path: '/whatsapp/customers',
    handler: customerHandler,
    auth: 'cognito',
    description: 'List customer profiles for the authenticated business',
  },
  {
    method: 'GET',
    path: '/whatsapp/customers/{id}',
    handler: customerHandler,
    auth: 'cognito',
    description: 'Get a single customer profile by ID',
  },
  {
    method: 'PUT',
    path: '/whatsapp/customers/{id}',
    handler: customerHandler,
    auth: 'cognito',
    description: 'Update a customer profile (E.164 validation on number change)',
  },
  {
    method: 'POST',
    path: '/whatsapp/customers/{id}/consent',
    handler: customerHandler,
    auth: 'cognito',
    description: 'Set consent state for a customer with audit logging',
  },
  {
    method: 'PUT',
    path: '/whatsapp/customers/{id}/consent',
    handler: customerHandler,
    auth: 'cognito',
    description: 'Set consent state for a customer (PUT variant)',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // TEMPLATES — WA_CORE feature-gated
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/templates',
    handler: templateHandler,
    auth: 'cognito',
    description: 'Create a message template with version history',
  },
  {
    method: 'GET',
    path: '/whatsapp/templates',
    handler: templateHandler,
    auth: 'cognito',
    description: 'List message templates for the authenticated business',
  },
  {
    method: 'GET',
    path: '/whatsapp/templates/{id}',
    handler: templateHandler,
    auth: 'cognito',
    description: 'Get a single message template by ID',
  },
  {
    method: 'PUT',
    path: '/whatsapp/templates/{id}',
    handler: templateHandler,
    auth: 'cognito',
    description: 'Update a message template (creates new version)',
  },
  {
    method: 'DELETE',
    path: '/whatsapp/templates/{id}',
    handler: templateHandler,
    auth: 'cognito',
    description: 'Deactivate a message template (soft-delete)',
  },
  {
    method: 'GET',
    path: '/whatsapp/templates/{id}/versions',
    handler: templateHandler,
    auth: 'cognito',
    description: 'List all version snapshots for a message template',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // RULES — WA_AUTOMATION feature-gated
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/rules',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Create an automation rule',
  },
  {
    method: 'GET',
    path: '/whatsapp/rules',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'List automation rules for the authenticated business',
  },
  {
    method: 'GET',
    path: '/whatsapp/rules/{id}',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Get a single automation rule by ID',
  },
  {
    method: 'PUT',
    path: '/whatsapp/rules/{id}',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Update an automation rule',
  },
  {
    method: 'PATCH',
    path: '/whatsapp/rules/{id}',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Toggle or partial-update an automation rule',
  },
  {
    method: 'DELETE',
    path: '/whatsapp/rules/{id}',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Deactivate an automation rule (soft-delete)',
  },
  {
    method: 'POST',
    path: '/whatsapp/rules/{id}/enable',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Enable an automation rule',
  },
  {
    method: 'POST',
    path: '/whatsapp/rules/{id}/disable',
    handler: ruleHandler,
    auth: 'cognito',
    description: 'Disable an automation rule',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // CONFIG — WA_CORE feature-gated
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'GET',
    path: '/whatsapp/config',
    handler: getConfigHandler,
    auth: 'cognito',
    description: 'Get automation config for the authenticated business',
  },
  {
    method: 'PUT',
    path: '/whatsapp/config',
    handler: putConfigHandler,
    auth: 'cognito',
    description: 'Upsert automation config (schema validation, last-valid retention)',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // PROVISIONING — OpenWA credential onboarding (Owner/Admin only)
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/provisioning',
    handler: saveProvisioningConfig,
    auth: 'cognito',
    description: 'Save OpenWA gateway credentials (pending_verification)',
  },
  {
    method: 'GET',
    path: '/whatsapp/provisioning',
    handler: getProvisioningConfig,
    auth: 'cognito',
    description: 'Get OpenWA provisioning status for the authenticated business (no secrets)',
  },
  {
    method: 'POST',
    path: '/whatsapp/provisioning/verify',
    handler: verifyProvisioningConfig,
    auth: 'cognito',
    description: 'Verify OpenWA session reachability, register webhook, and activate',
  },
  {
    method: 'DELETE',
    path: '/whatsapp/provisioning',
    handler: deleteProvisioningConfig,
    auth: 'cognito',
    description: 'Remove OpenWA credentials and the registered webhook',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // LOGS — WA_CORE feature-gated (read-only)
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'GET',
    path: '/whatsapp/logs/delivery',
    handler: deliveryLogHandler,
    auth: 'cognito',
    description: 'Query delivery log entries (append-only, 365-day retention)',
  },
  {
    method: 'GET',
    path: '/whatsapp/logs/audit',
    handler: auditLogHandler,
    auth: 'cognito',
    description: 'Query audit log entries (append-only, 365-day retention)',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // INBOUND — WA_CORE feature-gated
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/inbound',
    handler: inboundHandler,
    auth: 'cognito',
    description: 'Process inbound WhatsApp message (opt-out + AI dispatch)',
  },

  // ────────────────────────────────────────────────────────────────────────────
  // WEBHOOK — PUBLIC route (signature-only auth, NO Cognito)
  // ────────────────────────────────────────────────────────────────────────────
  {
    method: 'POST',
    path: '/whatsapp/webhook',
    handler: webhookHandler,
    auth: 'signature',
    description: 'OpenWA status webhook receiver (HMAC-SHA256 signature-only auth)',
  },
];

// ── Serverless Configuration Helper ──────────────────────────────────────────

/**
 * Generate the serverless.yml `functions` fragment for the WhatsApp module.
 *
 * Groups routes by handler into Lambda functions and emits the API Gateway
 * event bindings. Each function entry carries the correct authorizer config:
 * - 'cognito' routes → httpApi with `authorizer: { name: cognitoAuthorizer }`
 * - 'signature' routes → httpApi without authorizer (public)
 *
 * Usage: import and spread into the serverless config, or use as documentation
 * for the serverless.module.yml file.
 */
export function generateServerlessRoutes(): Record<string, unknown> {
  return {
    whatsappApi: {
      handler: 'dist/modules/whatsapp/handlers/index.handler',
      description: 'WhatsApp module — authenticated API routes (Cognito + RBAC)',
      timeout: 29,
      events: whatsappRoutes
        .filter((r) => r.auth === 'cognito')
        .map((r) => ({
          httpApi: {
            path: r.path,
            method: r.method,
            authorizer: { name: 'cognitoAuthorizer' },
          },
        })),
    },
    whatsappWebhook: {
      handler: 'dist/modules/whatsapp/handlers/webhook.handler.webhookHandler',
      description: 'WhatsApp module — OpenWA status webhook (public, HMAC-SHA256 auth)',
      timeout: 29,
      events: whatsappRoutes
        .filter((r) => r.auth === 'signature')
        .map((r) => ({
          httpApi: {
            path: r.path,
            method: r.method,
            // No authorizer — public endpoint, signature-verified in handler code
          },
        })),
    },
  };
}

// ── Cognito-Protected Route Predicate ─────────────────────────────────────────

/**
 * Returns all routes that require Cognito authentication.
 * Useful for integration tests and route auditing.
 */
export function getCognitoProtectedRoutes(): WhatsAppRouteDefinition[] {
  return whatsappRoutes.filter((r) => r.auth === 'cognito');
}

/**
 * Returns all public (signature-only) routes.
 * Useful for integration tests and route auditing.
 */
export function getPublicRoutes(): WhatsAppRouteDefinition[] {
  return whatsappRoutes.filter((r) => r.auth === 'signature');
}

// ── Route Count Validation ────────────────────────────────────────────────────

/**
 * Validates that the route configuration covers all expected endpoints.
 * Throws if any expected route is missing. Useful for CI/CD gate checks.
 */
export function validateRouteCompleteness(): void {
  const expectedPaths = [
    'POST /whatsapp/customers',
    'GET /whatsapp/customers',
    'GET /whatsapp/customers/{id}',
    'PUT /whatsapp/customers/{id}',
    'POST /whatsapp/customers/{id}/consent',
    'POST /whatsapp/templates',
    'GET /whatsapp/templates',
    'GET /whatsapp/templates/{id}',
    'PUT /whatsapp/templates/{id}',
    'DELETE /whatsapp/templates/{id}',
    'GET /whatsapp/templates/{id}/versions',
    'POST /whatsapp/rules',
    'GET /whatsapp/rules',
    'GET /whatsapp/rules/{id}',
    'PUT /whatsapp/rules/{id}',
    'PATCH /whatsapp/rules/{id}',
    'DELETE /whatsapp/rules/{id}',
    'POST /whatsapp/rules/{id}/enable',
    'POST /whatsapp/rules/{id}/disable',
    'GET /whatsapp/config',
    'PUT /whatsapp/config',
    'POST /whatsapp/provisioning',
    'GET /whatsapp/provisioning',
    'POST /whatsapp/provisioning/verify',
    'DELETE /whatsapp/provisioning',
    'GET /whatsapp/logs/delivery',
    'GET /whatsapp/logs/audit',
    'POST /whatsapp/inbound',
    'POST /whatsapp/webhook',
  ];

  const registered = new Set(
    whatsappRoutes.map((r) => `${r.method} ${r.path}`),
  );

  const missing = expectedPaths.filter((p) => !registered.has(p));
  if (missing.length > 0) {
    throw new Error(
      `WhatsApp route completeness check failed. Missing routes:\n  - ${missing.join('\n  - ')}`,
    );
  }
}
