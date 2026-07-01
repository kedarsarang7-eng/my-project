/**
 * Security_Auditor — security test categories and Security_Audit_Report
 * (Task 12.1).
 *
 * Derives crafted security probe cases for every applicable endpoint and
 * executes them against a target environment, recording each detected
 * vulnerability as a {@link SecurityFinding} in the Security_Audit_Report
 * (Requirements 7.1–7.7).
 *
 * Categories exercised (design.md → VulnCategory):
 *   - injection / scripting / forgery: `sql-injection`, `nosql-injection`,
 *     `xss`, `csrf`                                                  (7.1)
 *   - token / authentication / authorization: `jwt`, `broken-auth`,
 *     `broken-authz`                                                 (7.2)
 *   - object-reference / traversal / header / escalation: `idor`,
 *     `path-traversal`, `header-injection`, `privilege-escalation`   (7.3)
 *   - file upload (only where the endpoint accepts uploads): `file-upload` (7.4)
 *   - response exposure: `sensitive-data-exposure`                   (7.5)
 *
 * Design contract (design.md → Security_Auditor):
 *   audit(collection, env): Promise<{ findings: SecurityFinding[] }>
 *
 * This stage owns two responsibilities:
 *   1. **Probe derivation** (pure, deterministic) — {@link deriveProbeCases}
 *      walks the generated collection (and optional catalog) and produces one
 *      {@link SecurityProbeCase} per (endpoint, category, crafted payload),
 *      gated by what the endpoint actually supports. This is the part Task 12.1
 *      centres on and is fully unit/property-testable without any live server.
 *   2. **Execution + recording** — {@link audit} runs each probe through an
 *      injectable {@link ProbeExecutor} and records a finding whenever the
 *      executor reports the endpoint as vulnerable. The default executor
 *      performs no network I/O (safe no-op); live probing against real/stub
 *      endpoints is wired by the optional integration test (Task 12.3).
 *
 * Secret safety (Requirement 7.7): a crafted payload is referenced in the
 * report by a stable, non-secret `payloadRef`. Any observed response captured
 * from the target is redacted of supplied secret values before it is placed on
 * a finding, so no captured secret is ever written into the report. (The
 * artifact write boundary redacts again as defence in depth.)
 */

import { redactString } from '../report/writeArtifact';
import {
  CatalogEntry,
  Determinable,
  Domain,
  ParamSpec,
  PostmanCollection,
  PostmanEnvironment,
  PostmanRequest,
  SecurityFinding,
  StageIssue,
  VulnCategory,
} from '../types';

/** Stage name recorded on every security-audit {@link StageIssue}. */
const STAGE_NAME = 'security';

/** Severity rating attached to a finding (design.md → SecurityFinding). */
export type Severity = SecurityFinding['severity'];

/**
 * A single crafted security probe targeting one endpoint with one payload for
 * one vulnerability category. Probe derivation is pure and deterministic; the
 * `payloadRef` is a stable, non-secret identifier recorded in the report while
 * `payload` carries the crafted attack content actually sent during execution.
 */
export interface SecurityProbeCase {
  /** Id of the catalog/inventory endpoint this probe targets. */
  endpointId: string;
  /** Vulnerability category being exercised. */
  category: VulnCategory;
  /** Severity recorded if the probe detects a vulnerability. */
  severity: Severity;
  /** Stable, non-secret reference to the crafted payload (recorded in report). */
  payloadRef: string;
  /** The crafted attack content sent during execution. */
  payload: SecurityPayload;
}

/** Where a crafted payload is injected and what content it carries. */
export interface SecurityPayload {
  /** Human-readable description of the attack the payload represents. */
  description: string;
  /** The part of the request the payload is injected into. */
  injectionPoint: 'query' | 'body' | 'path' | 'header' | 'token' | 'upload';
  /** The crafted attack string. Never a secret value. */
  value: string;
}

/** The outcome of executing a single probe against a live target. */
export interface ProbeResult {
  /** True when the probe detected the endpoint to be vulnerable. */
  vulnerable: boolean;
  /** Observed response text, when available (redacted before recording). */
  observedResponse?: string;
  /** Optional severity override for this specific result. */
  severity?: Severity;
}

/**
 * Executes one probe against a live (or stubbed) target and reports whether the
 * endpoint is vulnerable. Injected so the deterministic derivation/recording
 * logic can be exercised without a server; live wiring is supplied by the
 * integration test (Task 12.3).
 */
export type ProbeExecutor = (
  probe: SecurityProbeCase,
  request: PostmanRequest,
  env: PostmanEnvironment
) => Promise<ProbeResult> | ProbeResult;

/** Options controlling a security audit run. */
export interface SecurityAuditorOptions {
  /**
   * Executor used to run each derived probe. Defaults to a safe no-op that
   * performs no network I/O and reports nothing vulnerable, so an audit is
   * fully functional before live probing is wired (Task 12.3).
   */
  probeExecutor?: ProbeExecutor;
  /**
   * Catalog entries keyed by endpoint id, used to refine probe applicability
   * (for example, restricting file-upload probes to endpoints that actually
   * accept uploads — Requirement 7.4). Optional: when absent, applicability is
   * inferred from the collection request and its domain folder.
   */
  catalog?: CatalogEntry[];
  /**
   * Secret values (typically resolved from the environment) to redact from any
   * observed response before it is recorded on a finding (Requirement 7.7).
   */
  secretValues?: string[];
}

/** The Security_Audit_Report: the recorded findings plus any non-fatal issues. */
export interface SecurityAuditResult {
  /** Every detected vulnerability, well-formed per Property 15. */
  findings: SecurityFinding[];
  /** Non-fatal issues (for example, a probe executor that threw). */
  issues: StageIssue[];
}

/**
 * The Security_Auditor derives and executes security probes against a
 * collection and emits the Security_Audit_Report (Requirements 7.1–7.7).
 */
export interface SecurityAuditor {
  audit(
    collection: PostmanCollection,
    env: PostmanEnvironment,
    options?: SecurityAuditorOptions
  ): Promise<SecurityAuditResult>;
}

// ---------------------------------------------------------------------------
// Severity table (design.md → SecurityFinding.severity)
// ---------------------------------------------------------------------------

/**
 * Default severity per vulnerability category. Injection and privilege
 * escalation are the most damaging (data loss / full account takeover) and are
 * rated highest; reflected/forgery/header issues are rated lower.
 */
const CATEGORY_SEVERITY: Record<VulnCategory, Severity> = {
  'sql-injection': 'critical',
  'nosql-injection': 'critical',
  'privilege-escalation': 'critical',
  xss: 'high',
  jwt: 'high',
  'broken-auth': 'high',
  'broken-authz': 'high',
  idor: 'high',
  'path-traversal': 'high',
  'file-upload': 'high',
  'sensitive-data-exposure': 'high',
  csrf: 'medium',
  'header-injection': 'medium',
};

// ---------------------------------------------------------------------------
// Crafted payload catalogue (stable refs, never secrets)
// ---------------------------------------------------------------------------

/**
 * The crafted payloads exercised per category. Each carries a stable
 * `ref` recorded in the report and a benign-but-representative attack `value`.
 * Values are fixed constants (never secrets) so the derived probe set is
 * deterministic across runs.
 */
const PAYLOADS: Record<VulnCategory, SecurityPayload[]> = {
  'sql-injection': [
    {
      description: 'SQL boolean tautology injection',
      injectionPoint: 'query',
      value: "' OR '1'='1",
    },
    {
      description: 'SQL statement termination / comment injection',
      injectionPoint: 'query',
      value: "'; DROP TABLE users; --",
    },
  ],
  'nosql-injection': [
    {
      description: 'NoSQL always-true operator injection',
      injectionPoint: 'body',
      value: '{"$gt": ""}',
    },
  ],
  xss: [
    {
      description: 'Reflected script tag injection',
      injectionPoint: 'body',
      value: '<script>alert(1)</script>',
    },
    {
      description: 'Attribute-breakout event-handler injection',
      injectionPoint: 'query',
      value: '"><img src=x onerror=alert(1)>',
    },
  ],
  csrf: [
    {
      description: 'State-changing request with no anti-CSRF token',
      injectionPoint: 'header',
      value: 'Origin: https://evil.example',
    },
  ],
  jwt: [
    {
      description: 'JWT "alg":"none" unsigned-token forgery',
      injectionPoint: 'token',
      value: 'eyJhbGciOiJub25lIn0.eyJzdWIiOiJhdHRhY2tlciJ9.',
    },
    {
      description: 'JWT signature-stripping (tampered payload)',
      injectionPoint: 'token',
      value: 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYWRtaW4ifQ.invalid',
    },
  ],
  'broken-auth': [
    {
      description: 'Protected endpoint accessed with no credentials',
      injectionPoint: 'header',
      value: '<no-authorization-header>',
    },
  ],
  'broken-authz': [
    {
      description: 'Lower-privileged token accessing a protected action',
      injectionPoint: 'header',
      value: 'Authorization: Bearer <low-privilege-token>',
    },
  ],
  idor: [
    {
      description: 'Object identifier swapped to another tenant/user',
      injectionPoint: 'path',
      value: '../1',
    },
    {
      description: 'Sequential identifier enumeration',
      injectionPoint: 'path',
      value: '0',
    },
  ],
  'path-traversal': [
    {
      description: 'Directory traversal to a system file',
      injectionPoint: 'path',
      value: '../../../../etc/passwd',
    },
    {
      description: 'Encoded directory traversal',
      injectionPoint: 'path',
      value: '..%2f..%2f..%2fetc%2fpasswd',
    },
  ],
  'header-injection': [
    {
      description: 'CRLF response-splitting in a request header',
      injectionPoint: 'header',
      value: 'X-Injected: test\r\nSet-Cookie: session=hijacked',
    },
  ],
  'privilege-escalation': [
    {
      description: 'Role/permission elevation via injected field',
      injectionPoint: 'body',
      value: '{"role": "admin", "isAdmin": true}',
    },
  ],
  'file-upload': [
    {
      description: 'Executable disguised with a content-type mismatch',
      injectionPoint: 'upload',
      value: 'filename="shell.php"; content="<?php system($_GET[0]); ?>"',
    },
    {
      description: 'Oversized / disallowed extension upload',
      injectionPoint: 'upload',
      value: 'filename="payload.svg"; content="<svg onload=alert(1)>"',
    },
  ],
  'sensitive-data-exposure': [
    {
      description: 'Inspect response for secrets/PII/stack traces',
      injectionPoint: 'body',
      value: '<observe-response-only>',
    },
  ],
};

// ---------------------------------------------------------------------------
// Endpoint capability derivation
// ---------------------------------------------------------------------------

/** What an endpoint supports, used to gate which probes apply to it. */
interface EndpointCapabilities {
  /** Accepts caller-supplied input (body/query/path) that could be injected. */
  acceptsInput: boolean;
  /** Mutating HTTP method (POST/PUT/PATCH/DELETE) — relevant to CSRF. */
  isStateChanging: boolean;
  /** Requires authentication (auth/JWT probes apply). */
  requiresAuth: boolean;
  /** Requires authorization (authz/privilege-escalation probes apply). */
  requiresAuthz: boolean;
  /** Accepts an object identifier (IDOR probes apply). */
  acceptsIdentifier: boolean;
  /** Path/file-oriented endpoint (path-traversal probes apply). */
  acceptsPathLike: boolean;
  /** Accepts file uploads (file-upload probes apply — Requirement 7.4). */
  acceptsFileUpload: boolean;
}

/** HTTP methods that mutate server state. */
const STATE_CHANGING_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/** Path tokens that signal a file/transfer-oriented endpoint. */
const FILE_PATH_TOKENS = ['upload', 'download', 'file', 'attachment', 'document', 'media'];

/** Param/path tokens that signal an object identifier. */
const IDENTIFIER_TOKENS = ['id', 'uuid', 'key', 'slug'];

/**
 * Derives an endpoint's capabilities from its generated request, its domain
 * folder, and (when available) its catalog entry. The catalog refines
 * applicability; without it, capabilities are inferred from the request URL,
 * method, headers, and body.
 */
function deriveCapabilities(
  request: PostmanRequest,
  domain: Domain,
  entry?: CatalogEntry
): EndpointCapabilities {
  const method = request.method.toUpperCase();
  const url = request.url.toLowerCase();

  const hasCatalogInput =
    entry !== undefined &&
    (isNonEmptyParams(entry.requestBodyParams) ||
      isNonEmptyParams(entry.queryParams) ||
      isNonEmptyParams(entry.pathParams));

  const hasRequestInput =
    request.body !== undefined ||
    url.includes('?') ||
    hasPathPlaceholder(request.url);

  const requiresAuth =
    entry !== undefined
      ? entry.security.enforcement !== 'public'
      : hasAuthorizationHeader(request);

  const requiresAuthz =
    entry !== undefined ? entry.security.enforcement === 'authorized' : false;

  const acceptsIdentifier =
    (entry !== undefined && isNonEmptyParams(entry.pathParams)) ||
    hasPathPlaceholder(request.url) ||
    IDENTIFIER_TOKENS.some((token) => urlSegmentMatches(url, token));

  const fileFromCatalog =
    entry !== undefined && catalogIndicatesFileUpload(entry);
  const fileFromPath = FILE_PATH_TOKENS.some((token) => url.includes(token));
  const acceptsFileUpload =
    domain === 'File-Transfer' || fileFromCatalog || fileFromPath;

  const acceptsPathLike = acceptsFileUpload || acceptsIdentifier;

  return {
    acceptsInput: hasCatalogInput || hasRequestInput,
    isStateChanging: STATE_CHANGING_METHODS.has(method),
    requiresAuth,
    requiresAuthz,
    acceptsIdentifier,
    acceptsPathLike,
    acceptsFileUpload,
  };
}

/** Predicate selecting which categories apply given an endpoint's capabilities. */
function categoryApplies(
  category: VulnCategory,
  caps: EndpointCapabilities
): boolean {
  switch (category) {
    case 'sql-injection':
    case 'nosql-injection':
    case 'xss':
      // Injection/scripting probes need a caller-controlled input to inject.
      return caps.acceptsInput;
    case 'csrf':
      // CSRF only matters for state-changing operations.
      return caps.isStateChanging;
    case 'jwt':
    case 'broken-auth':
      // Token and authentication probes apply to protected endpoints.
      return caps.requiresAuth;
    case 'broken-authz':
    case 'privilege-escalation':
      // Authorization and escalation probes apply to role-gated endpoints.
      return caps.requiresAuthz;
    case 'idor':
      return caps.acceptsIdentifier;
    case 'path-traversal':
      return caps.acceptsPathLike;
    case 'file-upload':
      // Requirement 7.4 — only where the endpoint accepts file uploads.
      return caps.acceptsFileUpload;
    case 'header-injection':
    case 'sensitive-data-exposure':
      // Every request carries headers and returns a response, so these always
      // apply to a reachable endpoint.
      return true;
    default:
      return false;
  }
}

// ---------------------------------------------------------------------------
// Probe derivation (pure, deterministic)
// ---------------------------------------------------------------------------

/**
 * Deterministic order categories are emitted in, so a repeated derivation over
 * an unchanged collection produces an equivalent probe set.
 */
const CATEGORY_ORDER: VulnCategory[] = [
  'sql-injection',
  'nosql-injection',
  'xss',
  'csrf',
  'jwt',
  'broken-auth',
  'broken-authz',
  'idor',
  'path-traversal',
  'header-injection',
  'privilege-escalation',
  'file-upload',
  'sensitive-data-exposure',
];

/**
 * Derives the full set of security probe cases for a collection. For every
 * request, every applicable category contributes one probe per crafted payload
 * in that category. The result is deterministic: requests are visited in
 * collection order and categories in {@link CATEGORY_ORDER}.
 *
 * @param collection - The generated Postman collection to probe.
 * @param catalog - Optional catalog entries (keyed internally by id) used to
 *   refine applicability (notably file-upload gating, Requirement 7.4).
 */
export function deriveProbeCases(
  collection: PostmanCollection,
  catalog?: CatalogEntry[]
): SecurityProbeCase[] {
  const catalogById = indexCatalog(catalog);
  const probes: SecurityProbeCase[] = [];

  for (const folder of collection.folders) {
    for (const request of folder.items) {
      const entry = catalogById.get(request.endpointId);
      const caps = deriveCapabilities(request, folder.name, entry);

      for (const category of CATEGORY_ORDER) {
        if (!categoryApplies(category, caps)) {
          continue;
        }
        for (const payload of PAYLOADS[category]) {
          probes.push({
            endpointId: request.endpointId,
            category,
            severity: CATEGORY_SEVERITY[category],
            payloadRef: buildPayloadRef(category, payload),
            payload,
          });
        }
      }
    }
  }

  return probes;
}

// ---------------------------------------------------------------------------
// Audit execution + report recording
// ---------------------------------------------------------------------------

/**
 * The default probe executor: performs no network I/O and reports nothing
 * vulnerable. This keeps an audit fully functional before live probing is
 * wired (the integration test in Task 12.3 injects a real executor).
 */
export const noopProbeExecutor: ProbeExecutor = () => ({ vulnerable: false });

/**
 * Runs a security audit: derives probe cases for the collection, executes each
 * via the (injectable) probe executor, and records a {@link SecurityFinding}
 * for every probe the executor reports as vulnerable (Requirements 7.1–7.7).
 *
 * Each finding records the affected endpoint, the vulnerability category, a
 * severity rating, and the crafted payload's stable `payloadRef` (Requirement
 * 7.6). When the executor returns an observed response, it is recorded after
 * redacting any supplied secret values, so no captured secret is ever written
 * into the report (Requirement 7.7).
 *
 * Execution is failure-resilient: if the executor throws for a probe, the audit
 * records a non-fatal {@link StageIssue} and continues with the next probe.
 */
export async function auditSecurity(
  collection: PostmanCollection,
  env: PostmanEnvironment,
  options: SecurityAuditorOptions = {}
): Promise<SecurityAuditResult> {
  const executor = options.probeExecutor ?? noopProbeExecutor;
  const secretValues = options.secretValues ?? [];

  const requestById = indexRequests(collection);
  const probes = deriveProbeCases(collection, options.catalog);

  const findings: SecurityFinding[] = [];
  const issues: StageIssue[] = [];

  for (const probe of probes) {
    const request = requestById.get(probe.endpointId);
    if (!request) {
      // A probe with no backing request cannot be executed; record and skip.
      issues.push({
        stage: STAGE_NAME,
        endpointId: probe.endpointId,
        reason: `No request found for endpoint ${probe.endpointId}; probe skipped.`,
      });
      continue;
    }

    let result: ProbeResult;
    try {
      result = await executor(probe, request, env);
    } catch (error) {
      issues.push({
        stage: STAGE_NAME,
        endpointId: probe.endpointId,
        reason: `Probe execution failed for ${probe.category}: ${errorMessage(error)}`,
      });
      continue;
    }

    if (!result.vulnerable) {
      continue;
    }

    findings.push(buildFinding(probe, result, secretValues));
  }

  return { findings, issues };
}

/** Default implementation of the {@link SecurityAuditor} interface. */
export class DefaultSecurityAuditor implements SecurityAuditor {
  constructor(private readonly defaults: SecurityAuditorOptions = {}) {}

  audit(
    collection: PostmanCollection,
    env: PostmanEnvironment,
    options?: SecurityAuditorOptions
  ): Promise<SecurityAuditResult> {
    return auditSecurity(collection, env, { ...this.defaults, ...options });
  }
}

// ---------------------------------------------------------------------------
// Finding construction
// ---------------------------------------------------------------------------

/**
 * Builds a well-formed {@link SecurityFinding} from a probe and its result. The
 * payload itself is never embedded — only its stable `payloadRef` — and the
 * observed response is redacted of secret values before being recorded
 * (Requirements 7.6, 7.7).
 */
function buildFinding(
  probe: SecurityProbeCase,
  result: ProbeResult,
  secretValues: string[]
): SecurityFinding {
  const finding: SecurityFinding = {
    endpointId: probe.endpointId,
    category: probe.category,
    severity: result.severity ?? probe.severity,
    payloadRef: probe.payloadRef,
  };

  if (result.observedResponse !== undefined) {
    finding.observedResponse = redactString(result.observedResponse, secretValues);
  }

  return finding;
}

/**
 * Builds a stable, non-secret payload reference for the report, of the form
 * `category/slug` (for example `sql-injection/sql-boolean-tautology-injection`).
 */
function buildPayloadRef(
  category: VulnCategory,
  payload: SecurityPayload
): string {
  return `${category}/${slugify(payload.description)}`;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Indexes catalog entries by id for capability lookup. */
function indexCatalog(catalog?: CatalogEntry[]): Map<string, CatalogEntry> {
  const map = new Map<string, CatalogEntry>();
  if (!catalog) {
    return map;
  }
  for (const entry of catalog) {
    map.set(entry.id, entry);
  }
  return map;
}

/** Indexes the first request seen per endpoint id across all folders. */
function indexRequests(
  collection: PostmanCollection
): Map<string, PostmanRequest> {
  const map = new Map<string, PostmanRequest>();
  for (const folder of collection.folders) {
    for (const request of folder.items) {
      if (!map.has(request.endpointId)) {
        map.set(request.endpointId, request);
      }
    }
  }
  return map;
}

/** True when a `Determinable` param list is a concrete, non-empty array. */
function isNonEmptyParams(value: Determinable<ParamSpec[]>): value is ParamSpec[] {
  return value !== 'undetermined' && Array.isArray(value) && value.length > 0;
}

/**
 * True when the catalog entry indicates a file upload: a body parameter whose
 * declared type names a file/binary/multipart form, or a name suggesting a file.
 */
function catalogIndicatesFileUpload(entry: CatalogEntry): boolean {
  if (!isNonEmptyParams(entry.requestBodyParams)) {
    return false;
  }
  return entry.requestBodyParams.some((param) => {
    const type = (param.type ?? '').toLowerCase();
    const name = param.name.toLowerCase();
    return (
      type.includes('file') ||
      type.includes('binary') ||
      type.includes('multipart') ||
      type === 'blob' ||
      name.includes('file') ||
      name.includes('upload') ||
      name.includes('attachment')
    );
  });
}

/** True when a request URL contains a Postman/Express/OpenAPI path placeholder. */
function hasPathPlaceholder(url: string): boolean {
  return /:[A-Za-z_]/.test(url) || /\{[^}]+\}/.test(url);
}

/** True when a request carries an Authorization header. */
function hasAuthorizationHeader(request: PostmanRequest): boolean {
  return (request.headers ?? []).some(
    (h) => h.key.toLowerCase() === 'authorization'
  );
}

/** True when a URL contains the token as a delimited path/word segment. */
function urlSegmentMatches(url: string, token: string): boolean {
  return new RegExp(`(^|[/_:{?&=-])${token}([/_:}?&=-]|$)`).test(url);
}

/** Converts a description into a lowercase, dash-delimited slug. */
function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** Extracts a readable message from an unknown thrown value. */
function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
